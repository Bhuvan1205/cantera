const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Syncs Firestore User role changes to Firebase Auth Custom Claims (P-08).
 * Enables instantaneous, zero-cost role evaluation in Firestore Security Rules.
 */
exports.syncUserClaims = onDocumentWritten("Users/{userId}", async (event) => {
  const userId = event.params.userId;
  const beforeData = event.data?.before?.data();
  const afterData = event.data?.after?.data();

  // If document was deleted, clear custom claims
  if (!afterData) {
    console.log(`User ${userId} deleted. Clearing custom claims.`);
    try {
      await admin.auth().setCustomUserClaims(userId, null);
    } catch (err) {
      console.error(`Error clearing claims for ${userId}:`, err);
    }
    return;
  }

  const newIsAdmin = afterData.isAdmin === true || afterData.role === "admin";
  const newRole = afterData.role || (newIsAdmin ? "admin" : "customer");
  const isStaff = newRole === "staff" || newIsAdmin;

  const oldIsAdmin = beforeData?.isAdmin === true || beforeData?.role === "admin";
  const oldRole = beforeData?.role || (oldIsAdmin ? "admin" : "customer");

  // Only update if role/admin status actually changed
  if (beforeData && newRole === oldRole && newIsAdmin === oldIsAdmin) {
    return;
  }

  console.log(`Setting custom claims for user ${userId}: role=${newRole}, admin=${newIsAdmin}, staff=${isStaff}`);

  try {
    await admin.auth().setCustomUserClaims(userId, {
      role: newRole,
      admin: newIsAdmin,
      staff: isStaff,
    });
  } catch (err) {
    console.error(`Failed to set custom claims for user ${userId}:`, err);
  }
});

/**
 * Sends multi-device push notifications on order lifecycle transitions (P-10).
 * Handles invalid/stale token removal automatically.
 */
exports.onOrderStatusChanged = onDocumentWritten("Orders/{orderId}", async (event) => {
  const orderId = event.params.orderId;
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();

  if (!before || !after) return;

  const oldStatus = before.status;
  const newStatus = after.status;

  if (oldStatus === newStatus) return;

  const userId = after.userId;
  if (!userId) return;

  let title = "";
  let body = "";

  if (newStatus === "preparing") {
    title = "Order in Preparation! 🍳";
    body = `Your order #${orderId.slice(-6)} is now being prepared at the counter.`;
  } else if (newStatus === "delivered") {
    title = "Order Delivered! 🎉";
    body = `Your order #${orderId.slice(-6)} has been collected. Enjoy your meal!`;
  } else if (newStatus === "refunded") {
    title = "Refund Credited 💰";
    body = `A refund of ₹${after.total || 0} has been credited back to your canteen wallet.`;
  } else {
    return;
  }

  // Fetch all registered device tokens for user
  const tokensSnap = await admin.firestore()
    .collection("Users")
    .doc(userId)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) {
    console.log(`No active FCM tokens for user ${userId}`);
    return;
  }

  const tokenDocs = tokensSnap.docs;
  const registrationTokens = tokenDocs.map((d) => d.data().token).filter(Boolean);

  if (registrationTokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: {
      orderId: orderId,
      status: newStatus,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    tokens: registrationTokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);

    // Clean up invalid/stale tokens
    const deleteBatch = admin.firestore().batch();
    let deadTokensCount = 0;

    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errCode = resp.error?.code;
        if (
          errCode === "messaging/registration-token-not-registered" ||
          errCode === "messaging/invalid-registration-token"
        ) {
          deleteBatch.delete(tokenDocs[idx].ref);
          deadTokensCount++;
        }
      }
    });

    if (deadTokensCount > 0) {
      await deleteBatch.commit();
      console.log(`Purged ${deadTokensCount} expired FCM tokens for user ${userId}`);
    }
  } catch (err) {
    console.error(`Error sending push notification for order ${orderId}:`, err);
  }
});

/**
 * Scheduled operational task running daily at midnight IST (P-11).
 * Purges stale queue items and cleans expired idempotency records.
 */
exports.dailyOperationalMaintenance = onSchedule("59 18 * * *", async (event) => {
  console.log("Starting daily canteen maintenance tasks...");

  const db = admin.firestore();

  // 1. Clean up stale mess queue items
  try {
    const staleQueues = await db.collection("queues").get();
    for (const doc of staleQueues.docs) {
      const data = doc.data();
      const queue = data.queue || [];
      const filtered = queue.filter((item) => {
        return item.status === "waiting" || item.status === "preparing";
      });
      if (filtered.length !== queue.length) {
        await doc.ref.update({
          queue: filtered,
          total_prep_units_ahead: filtered.reduce((acc, i) => acc + (i.prep_units || 1), 0),
        });
        console.log(`Pruned ${queue.length - filtered.length} stale items from queue ${doc.id}`);
      }
    }
  } catch (err) {
    console.error("Error during queue maintenance:", err);
  }

  // 2. Clean up stale idempotency keys older than 7 days
  try {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const staleKeys = await db.collection("idempotency_keys")
      .where("created_at", "<", sevenDaysAgo)
      .limit(500)
      .get();

    const batch = db.batch();
    staleKeys.docs.forEach((d) => batch.delete(d.ref));
    if (!staleKeys.empty) {
      await batch.commit();
      console.log(`Purged ${staleKeys.size} expired idempotency keys.`);
    }
  } catch (err) {
    console.error("Error purging idempotency keys:", err);
  }

  console.log("Daily maintenance complete.");
});

/**
 * Triggers alerts when menu item inventory drops below minimum threshold (P-11).
 */
exports.onStockLevelChanged = onDocumentWritten("Menu/{itemId}", async (event) => {
  const itemId = event.params.itemId;
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();

  if (!after) return;

  const currentStock = Number(after.stock ?? 100);
  const previousStock = Number(before?.stock ?? 100);

  // If stock crossed below low-stock threshold of 5
  if (currentStock <= 5 && previousStock > 5) {
    const itemName = after.name || itemId;
    console.warn(`[LOW STOCK ALERT] Item '${itemName}' (${itemId}) stock is down to ${currentStock}!`);

    await admin.firestore().collection("audit_logs").add({
      action: "LOW_STOCK_ALERT",
      target: `Menu/${itemId}`,
      details: { itemName, stock: currentStock },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Automatically discards Mess tokens that have exceeded their 15-minute pickup window.
 * Runs every minute.
 */
exports.expireReadyOrders = onSchedule("* * * * *", async (event) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  const expiredTokens = await db.collectionGroup("tokens")
    .where("token_status", "==", "ready_for_pickup")
    .where("collection_deadline", "<=", now)
    .get();

  if (expiredTokens.empty) return;

  console.log(`Found ${expiredTokens.size} expired ready_for_pickup tokens.`);

  for (const doc of expiredTokens.docs) {
    try {
      await db.runTransaction(async (transaction) => {
        const tokenSnap = await transaction.get(doc.ref);
        const data = tokenSnap.data();

        // 1. Concurrency Protection
        if (data.token_status !== "ready_for_pickup" || !data.collection_deadline) {
          return; // State changed since query
        }

        if (data.collection_deadline.toMillis() > Date.now()) {
          return; // Deadline is actually in the future (safety check)
        }

        // 2. Safe transition to discarded
        transaction.update(doc.ref, {
          token_status: "discarded",
          discarded_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 3. Queue Cleanup (if stale queue entry exists)
        const queueName = data.queue_name;
        const prepUnits = data.prep_units_in_queue;
        const tokenId = doc.id;
        const orderId = doc.ref.parent.parent.id;

        if (queueName && prepUnits) {
          const queueRef = db.collection("queues").doc(queueName);
          const queueSnap = await transaction.get(queueRef);
          
          if (queueSnap.exists) {
            const queueData = queueSnap.data();
            const queueArr = queueData.queue || [];
            const hasEntry = queueArr.some(q => q.token_id === tokenId);
            
            if (hasEntry) {
                transaction.update(queueRef, {
                    queue: admin.firestore.FieldValue.arrayRemove({
                        token_id: tokenId,
                        order_id: orderId,
                        prep_units: prepUnits,
                        token_number: data.token_number || 0,
                        status: "preparing",
                    }, {
                        token_id: tokenId,
                        order_id: orderId,
                        prep_units: prepUnits,
                        token_number: data.token_number || 0,
                        status: "waiting",
                    }),
                    total_prep_units_ahead: admin.firestore.FieldValue.increment(-prepUnits),
                });
            }
          }
        }
      });
    } catch (err) {
      console.error(`Failed to expire token ${doc.id}:`, err);
    }
  }
});

/**
 * Triggers push notifications for token-level status changes (like discarded).
 */
exports.onTokenStatusChanged = onDocumentWritten("Orders/{orderId}/tokens/{tokenId}", async (event) => {
  const orderId = event.params.orderId;
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();

  if (!before || !after) return;

  const oldStatus = before.token_status;
  const newStatus = after.token_status;

  if (oldStatus === newStatus || newStatus !== "discarded") return;

  const orderSnap = await admin.firestore().collection("Orders").doc(orderId).get();
  if (!orderSnap.exists) return;
  const userId = orderSnap.data().userId;
  if (!userId) return;

  const title = "Order Discarded";
  const body = "Your prepared food was not collected within 15 minutes and has been discarded. No refund will be issued.";

  const tokensSnap = await admin.firestore()
    .collection("Users")
    .doc(userId)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) return;

  const tokenDocs = tokensSnap.docs;
  const registrationTokens = tokenDocs.map((d) => d.data().token).filter(Boolean);

  if (registrationTokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: {
      orderId: orderId,
      status: "discarded",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    tokens: registrationTokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    const deleteBatch = admin.firestore().batch();
    
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errCode = resp.error?.code;
        if (
          errCode === "messaging/registration-token-not-registered" ||
          errCode === "messaging/invalid-registration-token"
        ) {
          deleteBatch.delete(tokenDocs[idx].ref);
        }
      }
    });
    
    await deleteBatch.commit();
  } catch (err) {
    console.error(`Error sending discard notification for token ${event.params.tokenId}:`, err);
  }
});
