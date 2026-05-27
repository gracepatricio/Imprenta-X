const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.inventoryLowStockAlert = onDocumentUpdated(
  "RawMaterials/{materialId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    const prevStock = before?.current_stock ?? 0;
    const newStock = after?.current_stock ?? 0;
    const restockLevel = after?.restock_level ?? 0;
    const materialName = after?.material_name ?? "Unknown Material";

    // Only trigger if stock actually changed
    if (prevStock === newStock) return null;

    // Determine status
    let status = null;
    if (newStock <= 0) {
      status = "Out of Stock";
    } else if (newStock <= restockLevel * 0.5) {
      status = "Critical";
    } else if (newStock <= restockLevel) {
      status = "Low Stock";
    }

    // Only notify if it's a bad status
    if (!status) return null;

    const title = status === "Out of Stock"
      ? `🚨 Out of Stock: ${materialName}`
      : status === "Critical"
      ? `⚠️ Critical Stock: ${materialName}`
      : `📦 Low Stock: ${materialName}`;

    const body = newStock <= 0
      ? `${materialName} is completely out of stock. Restock immediately!`
      : `${materialName} has only ${newStock} units left (restock at ${restockLevel}).`;

    // Get all admin and employee FCM tokens
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

    // Send to all tokens
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