const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// ── Inventory Low Stock Alert ─────────────────────────────────────────────
exports.inventoryLowStockAlert = onDocumentUpdated(
  "RawMaterials/{materialId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const prevStock = before?.current_stock ?? 0;
    const newStock = after?.current_stock ?? 0;
    const restockLevel = after?.restock_level ?? 0;
    const materialName = after?.material_name ?? "Unknown Material";

    if (prevStock === newStock) return null;

    let status = null;
    if (newStock <= 0) {
      status = "Out of Stock";
    } else if (newStock <= restockLevel * 0.5) {
      status = "Critical";
    } else if (newStock <= restockLevel) {
      status = "Low Stock";
    }

    if (!status) return null;

    const title = status === "Out of Stock"
      ? `🚨 Out of Stock: ${materialName}`
      : status === "Critical"
      ? `⚠️ Critical Stock: ${materialName}`
      : `📦 Low Stock: ${materialName}`;

    const body = newStock <= 0
      ? `${materialName} is completely out of stock. Restock immediately!`
      : `${materialName} has only ${newStock} units left (restock at ${restockLevel}).`;

    const db = getFirestore();
    const usersSnap = await db.collection("User")
      .where("user_role", "in", ["admin", "employee"])
      .get();

    const tokens = [];
    usersSnap.forEach((doc) => {
      const token = doc.data().fcm_token;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) return null;

    const messages = tokens.map((token) => ({
      token,
      notification: { title, body },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    }));

    const results = await getMessaging().sendEach(messages);
    console.log(`Sent ${results.successCount} notifications for ${materialName} (${status})`);
    return null;
  }
);

// ── Order Status Update ───────────────────────────────────────────────────
exports.orderStatusUpdate = onDocumentUpdated(
  "Orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const prevStatus = before?.status;
    const newStatus = after?.status;
    const customerUid = after?.customer_uid;

    // Skip if status didn't change or no customer (walk-in)
    if (prevStatus === newStatus) return null;
    if (!customerUid || customerUid === "") return null;

    const orderId = after?.order_id ?? "Your order";

    const statusMessages = {
      pending: {
        title: `🧾 Order Confirmed: ${orderId}`,
        body: `Your order has been confirmed and is now in the queue!`,
      },
      in_production: {
        title: `🔧 In Production: ${orderId}`,
        body: `Your order is now being printed and processed.`,
      },
      ready: {
        title: `✅ Ready for Pickup: ${orderId}`,
        body: `Your order is ready! Please come pick it up.`,
      },
      completed: {
        title: `🎉 Order Completed: ${orderId}`,
        body: `Your order has been completed. Thank you for choosing Imprenta!`,
      },
      cancelled: {
        title: `❌ Order Cancelled: ${orderId}`,
        body: after?.amount_paid > 0
          ? `Your order has been cancelled. A refund of ₱${after.amount_paid} will be available for pickup.`
          : `Your order has been cancelled. Please contact us for details.`,
      },
    };

    const message = statusMessages[newStatus];
    if (!message) return null;

    const db = getFirestore();
    const userDoc = await db.collection("User").doc(customerUid).get();
    const token = userDoc.data()?.fcm_token;

    if (!token) return null;

    await getMessaging().send({
      token,
      notification: { title: message.title, body: message.body },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    console.log(`Order status notification sent to ${customerUid} for ${orderId} (${newStatus})`);
    return null;
  }
);

// ── Payment Confirmation ──────────────────────────────────────────────────
exports.paymentConfirmation = onDocumentUpdated(
  "Orders/{orderId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const prevPaymentStatus = before?.payment_status;
    const newPaymentStatus = after?.payment_status;
    const customerUid = after?.customer_uid;

    // Skip if payment status didn't change or no customer (walk-in)
    if (prevPaymentStatus === newPaymentStatus) return null;
    if (!customerUid || customerUid === "") return null;

    if (newPaymentStatus !== "paid") return null;

    const orderId = after?.order_id ?? "Your order";
    const totalPrice = after?.total_price ?? 0;

    const db = getFirestore();
    const userDoc = await db.collection("User").doc(customerUid).get();
    const token = userDoc.data()?.fcm_token;

    if (!token) return null;

    await getMessaging().send({
      token,
      notification: {
        title: `💳 Payment Confirmed: ${orderId}`,
        body: `Your full payment of ₱${totalPrice} has been received. Thank you!`,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    console.log(`Payment confirmation sent to ${customerUid} for ${orderId}`);
    return null;
  }
);

// ── Refund Notification ───────────────────────────────────────────────────
exports.refundNotification = require("firebase-functions/v2/firestore").onDocumentCreated(
  "Notifications/{notifId}",
  async (event) => {
    const data = event.data.data();

    if (data?.type !== "refund_confirmed") return null;

    const customerUid = data?.customer_uid;
    if (!customerUid) return null;

    const db = getFirestore();
    const userDoc = await db.collection("User").doc(customerUid).get();
    const token = userDoc.data()?.fcm_token;
    if (!token) return null;

    const orderId = data?.order_id ?? "Your order";
    const amount = data?.amount ?? 0;

    await getMessaging().send({
      token,
      notification: {
        title: `💸 Refund Confirmed: ${orderId}`,
        body: amount > 0
          ? `Your refund of ₱${amount} for order ${orderId} has been processed and is ready for pickup.`
          : `Your refund for order ${orderId} has been confirmed.`,
      },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });

    console.log(`Refund notification sent to ${customerUid} for ${orderId}`);
    return null;
  }
);