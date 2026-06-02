/**
 * Imprenta X – Cloud Functions
 *
 * 1. pmCreateLink   – proxies PayMongo link creation (fixes CORS on web)
 * 2. pmGetStatus    – proxies PayMongo link status check (fixes CORS on web)
 * 3. paymongoWebhook – receives link.payment.paid events from PayMongo
 *
 * Deploy: firebase deploy --only functions
 * Register webhook URL in PayMongo Dashboard → Developers → Webhooks
 * Events: link.payment.paid
 */

const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp }  = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

initializeApp();
const db = getFirestore();

// ---------------------------------------------------------------------------
// PayMongo config
// ---------------------------------------------------------------------------

const PM_SK   = process.env.PM_SK;   // set in functions/.env (never commit that file)
const PM_BASE = 'https://api.paymongo.com/v1';

function pmAuth() {
  return 'Basic ' + Buffer.from(`${PM_SK}:`).toString('base64');
}

// ---------------------------------------------------------------------------
// pmCreateLink – proxy so mobile AND web apps can create PayMongo links
// without hitting CORS.  Flutter calls THIS function, not PayMongo directly.
// ---------------------------------------------------------------------------

exports.pmCreateLink = onRequest(
  { cors: true, invoker: 'public' },
  async (req, res) => {
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST')   return res.status(405).send('Method Not Allowed');

    const { amount, description } = req.body ?? {};
    if (!amount || !description) {
      return res.status(400).json({ error: 'amount and description are required' });
    }

    const centavos = Math.round(Number(amount) * 100);
    console.log('[pmCreateLink] amount_pesos=' + amount + ' centavos=' + centavos + ' desc=' + description);

    // PayMongo minimum is ₱1.00 (100 centavos) in live mode.
    const isLive = PM_SK && PM_SK.startsWith('sk_live');
    if (isLive && centavos < 100) {
      return res.status(400).json({ error: 'Minimum payment amount is ₱1.00 (PayMongo requirement).' });
    }

    const r = await fetch(`${PM_BASE}/links`, {
      method:  'POST',
      headers: { Authorization: pmAuth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        data: {
          attributes: {
            amount:      centavos,
            description: String(description),
            remarks:     'Imprenta X',
          },
        },
      }),
    });

    const json = await r.json();
    if (!r.ok) {
      console.error('[pmCreateLink] PayMongo error:', JSON.stringify(json));
      return res.status(r.status).json({ error: json });
    }

    const d = json.data;
    const a = d.attributes;
    console.log('[pmCreateLink] OK id=' + d.id + ' url=' + a.checkout_url + ' livemode=' + a.livemode);

    return res.status(200).json({
      id:              d.id,
      checkoutUrl:     a.checkout_url,
      referenceNumber: a.reference_number ?? '',
    });
  }
);

// ---------------------------------------------------------------------------
// pmGetStatus – proxy for polling payment link status
// ---------------------------------------------------------------------------

exports.pmGetStatus = onRequest(
  { cors: true, invoker: 'public' },
  async (req, res) => {
    if (req.method === 'OPTIONS') return res.status(204).send('');

    const linkId = req.query.id ?? req.body?.id;
    if (!linkId) return res.status(400).json({ error: 'id is required' });

    const r = await fetch(`${PM_BASE}/links/${linkId}`, {
      headers: { Authorization: pmAuth() },
    });

    const json = await r.json();
    if (!r.ok) {
      console.error('pmGetStatus error:', JSON.stringify(json));
      return res.status(r.status).json({ error: json });
    }

    return res.status(200).json({ status: json.data.attributes.status });
  }
);

// ---------------------------------------------------------------------------
// Webhook endpoint
// ---------------------------------------------------------------------------

exports.paymongoWebhook = onRequest(
  { cors: false, invoker: 'public' },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    try {
      const event     = req.body;
      const eventType = event?.data?.attributes?.type;

      // Only handle payment link paid events
      if (eventType !== 'link.payment.paid') {
        return res.status(200).json({ received: true, skipped: true });
      }

      const linkData      = event.data.attributes.data;
      const linkId        = linkData.id;
      const amountCentavos = linkData.attributes.amount;
      const amountPhp     = amountCentavos / 100;
      const payments      = linkData.attributes.payments ?? [];
      const paymentMethod = payments[0]?.attributes?.payment_method_used ?? 'online';

      console.log(`[paymongoWebhook] link=${linkId} amount=₱${amountPhp} method=${paymentMethod}`);

      // ── 1. Fetch the link→order mapping ──────────────────────────────────
      const linkRef = db.collection('PayMongoLinks').doc(linkId);
      const linkDoc = await linkRef.get();

      if (!linkDoc.exists) {
        console.warn(`[paymongoWebhook] No mapping for link ${linkId}`);
        return res.status(200).json({ received: true, warning: 'link_not_found' });
      }

      const linkInfo = linkDoc.data();

      // Idempotency: skip if already processed
      if (linkInfo.processed === true) {
        console.log(`[paymongoWebhook] Link ${linkId} already processed – skipping`);
        return res.status(200).json({ received: true, skipped: 'already_processed' });
      }

      const { order_id: orderId, purpose } = linkInfo;

      // ── 2. Load the order ─────────────────────────────────────────────────
      const orderRef = db.collection('Orders').doc(orderId);
      const orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        console.error(`[paymongoWebhook] Order not found: ${orderId}`);
        return res.status(200).json({ received: true, error: 'order_not_found' });
      }

      const order      = orderDoc.data();
      const total      = order.total_price ?? 0;
      const prevPaid   = order.amount_paid ?? 0;
      const newPaid    = Math.min(prevPaid + amountPhp, total);
      const remaining  = Math.max(0, total - newPaid);
      const fullyPaid  = remaining < 0.01;

      const batch = db.batch();

      // Mark link as processed
      batch.update(linkRef, {
        processed:    true,
        processed_at: FieldValue.serverTimestamp(),
        payment_method_used: paymentMethod,
      });

      // ── 3a. First / downpayment ───────────────────────────────────────────
      if (purpose === 'downpayment' && !order.invoice_id) {
        // Generate invoice ID (transaction to avoid duplicate)
        const counterRef = db.collection('Counters').doc('invoice');
        const invoiceId  = await db.runTransaction(async (tx) => {
          const snap = await tx.get(counterRef);
          const next = ((snap.data()?.last_id) ?? 0) + 1;
          tx.set(counterRef, { last_id: next }, { merge: true });
          return `INV-${String(next).padStart(4, '0')}`;
        });

        // Update order
        batch.update(orderRef, {
          status:               'pending',
          amount_paid:          newPaid,
          remaining_balance:    remaining,
          payment_status:       fullyPaid ? 'paid' : 'partial',
          invoice_id:           invoiceId,
          paid_at:              FieldValue.serverTimestamp(),
          payment_method_used:  paymentMethod,
        });

        // Create invoice
        batch.set(db.collection('Invoices').doc(invoiceId), {
          invoice_id:        invoiceId,
          order_id:          orderId,
          customer_name:     order.customer_name ?? '',
          customer_email:    order.customer_email ?? '',
          issued_date:       FieldValue.serverTimestamp(),
          items:             order.products ?? [],
          total_amount:      total,
          amount_paid:       newPaid,
          remaining_balance: remaining,
          payment_method:    paymentMethod,
          transaction_ref:   linkId,
        });

        // Sales record for downpayment
        batch.set(db.collection('Sales_Records').doc(), {
          order_id:              orderId,
          customer_name:         order.customer_name ?? '',
          payment_type:          fullyPaid ? 'full' : 'downpayment',
          payment_method:        paymentMethod,
          transaction_reference: linkId,
          sale_amount:           newPaid,
          order_total:           total,
          sale_date:             FieldValue.serverTimestamp(),
        });

        // Create Order_Queue entry (FIFO by created_at = payment time)
        batch.set(db.collection('Order_Queue').doc(), {
          order_id:        orderId,
          customer_uid:    order.customer_uid ?? '',
          customer_name:   order.customer_name ?? '',
          job_status:      'pending',
          turnaround_days: order.turnaround_days ?? 3,
          products:        order.products ?? [],
          total_price:     total,
          created_at:      FieldValue.serverTimestamp(),
        });

        console.log(`[paymongoWebhook] Order confirmed: ${orderId}, invoice: ${invoiceId}`);

      // ── 3b. Downpayment already created (duplicate webhook / already processed by app)
      } else if (purpose === 'downpayment' && order.invoice_id) {
        // Order was already confirmed by app polling — just update amounts
        batch.update(orderRef, {
          amount_paid:       newPaid,
          remaining_balance: remaining,
          payment_status:    fullyPaid ? 'paid' : 'partial',
          payment_method_used: paymentMethod,
        });
        batch.update(db.collection('Invoices').doc(order.invoice_id), {
          amount_paid:       newPaid,
          remaining_balance: remaining,
        });
        console.log(`[paymongoWebhook] Order ${orderId} already had invoice – amounts updated`);

      // ── 3c. Balance payment ───────────────────────────────────────────────
      } else {
        batch.update(orderRef, {
          amount_paid:           newPaid,
          remaining_balance:     remaining,
          payment_status:        fullyPaid ? 'paid' : 'partial',
          payment_method_used:   paymentMethod,
          // Clear persisted balance link — it has been paid
          balance_link_id:       FieldValue.delete(),
          balance_checkout_url:  FieldValue.delete(),
          balance_link_amount:   FieldValue.delete(),
          ...(fullyPaid ? { fully_paid_at: FieldValue.serverTimestamp() } : {}),
        });

        if (order.invoice_id) {
          batch.update(db.collection('Invoices').doc(order.invoice_id), {
            amount_paid:       newPaid,
            remaining_balance: remaining,
          });
        }

        // Log payment record
        batch.set(db.collection('Payments').doc(), {
          order_id:              orderId,
          amount:                amountPhp,
          payment_type:          'balance',
          payment_method:        paymentMethod,
          transaction_reference: linkId,
          payment_date:          FieldValue.serverTimestamp(),
          status:                'paid',
        });

        // Sales record for balance payment
        batch.set(db.collection('Sales_Records').doc(), {
          order_id:              orderId,
          customer_name:         order.customer_name ?? '',
          payment_type:          'balance',
          payment_method:        paymentMethod,
          transaction_reference: linkId,
          sale_amount:           amountPhp,
          order_total:           total,
          sale_date:             FieldValue.serverTimestamp(),
        });

        console.log(`[paymongoWebhook] Balance ₱${amountPhp} recorded for order ${orderId}`);
      }

      await batch.commit();
      return res.status(200).json({ received: true, success: true });

    } catch (err) {
      console.error('[paymongoWebhook] Error:', err);
      return res.status(500).json({ error: 'internal_error' });
    }
  }
);

// ---------------------------------------------------------------------------
// deleteAuthUser – hard-delete a Firebase Auth account (Admin SDK only).
// Called by the admin panel. Also writes a FreedEmails marker so that
// freeEmail can clean up if this call ever fails.
// ---------------------------------------------------------------------------

exports.deleteAuthUser = onRequest(
  { cors: true, invoker: 'public' },
  async (req, res) => {
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');

    const authHeader = req.headers.authorization ?? '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) return res.status(401).json({ error: 'Missing auth token' });

    let decoded;
    try {
      decoded = await getAuth().verifyIdToken(idToken);
    } catch (e) {
      return res.status(401).json({ error: 'Invalid auth token' });
    }

    const callerDoc = await db.collection('User').doc(decoded.uid).get();
    if (callerDoc.data()?.user_role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const uid = req.body?.uid;
    if (!uid || typeof uid !== 'string') {
      return res.status(400).json({ error: 'uid is required' });
    }

    try {
      const userRecord = await getAuth().getUser(uid);
      const email = userRecord.email;
      await getAuth().deleteUser(uid);
      // Clean up the FreedEmails marker now that auth is truly deleted
      if (email) await db.collection('FreedEmails').doc(email).delete().catch(() => {});
      return res.status(200).json({ success: true });
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        return res.status(200).json({ success: true, note: 'already_deleted' });
      }
      console.error('deleteAuthUser error:', e);
      return res.status(500).json({ error: e.message });
    }
  }
);

// ---------------------------------------------------------------------------
// freeEmail – called during registration when "email-already-in-use" is
// detected for an email that an admin deleted. Looks up the FreedEmails
// marker (written by the Flutter deleteUser flow) to confirm the email was
// legitimately freed, then removes the Firebase Auth account so the caller
// can complete registration. No user auth required — the Firestore marker
// is the proof.
// ---------------------------------------------------------------------------

exports.freeEmail = onRequest(
  { cors: true, invoker: 'public' },
  async (req, res) => {
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');

    const email = req.body?.email;
    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'email is required' });
    }

    // Confirm this email was legitimately freed before touching Firebase Auth.
    // Any one of these three conditions is sufficient:
    //   (a) explicit FreedEmails marker written by the Flutter deleteUser flow
    //   (b) a User doc with is_deleted: true (old soft-delete)
    //   (c) Firebase Auth has the email but no Firestore User doc exists
    //       (manual deletion directly from Firebase Console)
    const marker = await db.collection('FreedEmails').doc(email).get();
    if (!marker.exists) {
      const oldSnap = await db.collection('User')
        .where('email', '==', email)
        .where('is_deleted', '==', true)
        .limit(1)
        .get();
      if (oldSnap.empty) {
        // Check case (c): Firebase Auth account exists but Firestore doc is gone
        try {
          const authUser = await getAuth().getUserByEmail(email);
          const userDoc = await db.collection('User').doc(authUser.uid).get();
          if (userDoc.exists) {
            // Firestore doc is still there and not deleted — block this request
            return res.status(403).json({ error: 'Email is in use by an active account' });
          }
          // No Firestore doc → account was cleaned up externally, allow freeing
        } catch (lookupErr) {
          if (lookupErr.code !== 'auth/user-not-found') {
            return res.status(403).json({ error: 'Email was not freed by admin' });
          }
          // auth/user-not-found means Firebase Auth is already clean — nothing to do
          return res.status(200).json({ success: true, note: 'already_clean' });
        }
      }
    }

    try {
      const userRecord = await getAuth().getUserByEmail(email);
      await getAuth().deleteUser(userRecord.uid);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        // Fallback: rename email to a placeholder so the real email is freed
        try {
          const userRecord = await getAuth().getUserByEmail(email);
          await getAuth().updateUser(userRecord.uid, {
            email: `_freed_${Date.now()}@imprenta.internal`,
          });
        } catch (_) {
          return res.status(500).json({ error: 'Could not free email' });
        }
      }
      // auth/user-not-found means it's already gone — that's fine
    }

    // Remove the marker (one-time use)
    await marker.ref.delete().catch(() => {});
    return res.status(200).json({ success: true });
  }
);
