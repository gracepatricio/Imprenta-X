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

    const r = await fetch(`${PM_BASE}/links`, {
      method:  'POST',
      headers: { Authorization: pmAuth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        data: {
          attributes: {
            amount:      Math.round(Number(amount) * 100),
            description: String(description),
            remarks:     'Imprenta X',
          },
        },
      }),
    });

    const json = await r.json();
    if (!r.ok) {
      console.error('pmCreateLink error:', JSON.stringify(json));
      return res.status(r.status).json({ error: json });
    }

    const d = json.data;
    const a = d.attributes;
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
