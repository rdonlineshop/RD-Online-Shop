"use strict";

const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// ============================================================
// ORDER STATUS MESSAGE
// ============================================================

function notificationForStatus(status, orderId) {
  switch (status) {
    case "Confirmed":
      return {
        title: "Order Confirmed ✅",
        body: `Your order ${orderId} has been confirmed.`,
      };

    case "Processing":
      return {
        title: "Order Processing 📦",
        body: `Your order ${orderId} is being prepared.`,
      };

    case "Shipped":
      return {
        title: "Order Shipped 🚚",
        body: `Your order ${orderId} is on the way.`,
      };

    case "Delivered":
      return {
        title: "Order Delivered 🎉",
        body: `Your order ${orderId} has been delivered.`,
      };

    case "Cancelled":
      return {
        title: "Order Cancelled",
        body: `Your order ${orderId} has been cancelled.`,
      };

    case "Pending":
      return {
        title: "Order Pending",
        body: `Your order ${orderId} is pending.`,
      };

    default:
      return {
        title: "RD Online Shop",
        body: `Order ${orderId} status changed to ${status}.`,
      };
  }
}

// ============================================================
// CLEAN TOKEN
// ============================================================

function cleanToken(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

// ============================================================
// GET CUSTOMER DEVICES
// ============================================================

async function getCustomerDevices(customerId) {
  const snapshot = await db
      .collection("customers")
      .where("customerId", "==", customerId)
      .get();

  const tokenOwners = new Map();

  for (const document of snapshot.docs) {
    const data = document.data() || {};

    if (data.role !== "customer") {
      continue;
    }

    if (data.isActive === false) {
      continue;
    }

    if (data.notificationsEnabled === false) {
      continue;
    }

    const tokens = new Set();

    const primaryToken = cleanToken(data.fcmToken);

    if (primaryToken) {
      tokens.add(primaryToken);
    }

    if (Array.isArray(data.fcmTokens)) {
      for (const item of data.fcmTokens) {
        const token = cleanToken(item);

        if (token) {
          tokens.add(token);
        }
      }
    }

    for (const token of tokens) {
      if (!tokenOwners.has(token)) {
        tokenOwners.set(token, new Set());
      }

      tokenOwners.get(token).add(document.ref);
    }
  }

  return tokenOwners;
}

// ============================================================
// INVALID TOKEN CHECK
// ============================================================

function isInvalidTokenError(errorCode) {
  return errorCode ===
          "messaging/registration-token-not-registered" ||
      errorCode ===
          "messaging/invalid-registration-token";
}

// ============================================================
// REMOVE INVALID TOKEN
// ============================================================

async function removeInvalidToken(token, documentRefs) {
  const writes = [];

  for (const documentRef of documentRefs) {
    writes.push(
        documentRef.set(
            {
              fcmTokens: FieldValue.arrayRemove(token),
              fcmTokenUpdatedAt:
                  FieldValue.serverTimestamp(),
              updatedAt:
                  FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
        ),
    );
  }

  await Promise.all(writes);
}

// ============================================================
// SEND IN CHUNKS
// Firebase multicast supports max 500 recipients.
// ============================================================

async function sendNotifications({
  tokens,
  tokenOwners,
  title,
  body,
  orderId,
  status,
  customerId,
}) {
  const chunkSize = 500;

  let successCount = 0;
  let failureCount = 0;

  for (
    let start = 0;
    start < tokens.length;
    start += chunkSize
  ) {
    const chunk =
        tokens.slice(start, start + chunkSize);

    const response =
        await getMessaging().sendEachForMulticast({
          tokens: chunk,

          notification: {
            title,
            body,
          },

          data: {
            type: "order_status",
            orderId,
            status,
            customerId,
          },

          android: {
            priority: "high",

            notification: {
              sound: "default",
            },
          },

          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });

    successCount += response.successCount;
    failureCount += response.failureCount;

    const cleanupPromises = [];

    response.responses.forEach((result, index) => {
      if (result.success) {
        return;
      }

      const token = chunk[index];
      const errorCode =
          result.error?.code || "";

      logger.warn(
          "FCM send failure",
          {
            orderId,
            tokenSuffix:
                token.slice(-8),
            errorCode,
          },
      );

      if (!isInvalidTokenError(errorCode)) {
        return;
      }

      const owners =
          tokenOwners.get(token);

      if (!owners || owners.size === 0) {
        return;
      }

      cleanupPromises.push(
          removeInvalidToken(
              token,
              Array.from(owners),
          ),
      );
    });

    await Promise.all(cleanupPromises);
  }

  return {
    successCount,
    failureCount,
  };
}

// ============================================================
// ORDER STATUS → CUSTOMER PUSH NOTIFICATION
// ============================================================

exports.onOrderStatusChanged =
    onDocumentUpdated(
        "orders/{orderId}",
        async (event) => {
          if (!event.data) {
            logger.warn(
                "Order update event had no data.",
            );
            return;
          }

          const before =
              event.data.before.data() || {};

          const after =
              event.data.after.data() || {};

          const oldStatus =
              String(before.status || "").trim();

          const newStatus =
              String(after.status || "").trim();

          // Ignore updates that did not change order status.
          if (
            !newStatus ||
            oldStatus === newStatus
          ) {
            return;
          }

          const orderId =
              String(
                  after.id ||
                  event.params.orderId ||
                  "",
              ).trim();

          const customerId =
              String(
                  after.customerId || "",
              ).trim();

          if (!orderId) {
            logger.warn(
                "Order has no order ID.",
            );
            return;
          }

          if (!customerId) {
            logger.warn(
                "Order has no customerId.",
                {
                  orderId,
                },
            );
            return;
          }

          logger.info(
              "Order status changed",
              {
                orderId,
                customerId,
                oldStatus,
                newStatus,
              },
          );

          const tokenOwners =
              await getCustomerDevices(
                  customerId,
              );

          const tokens =
              Array.from(
                  tokenOwners.keys(),
              );

          if (tokens.length === 0) {
            logger.info(
                "No FCM device token found for customer.",
                {
                  orderId,
                  customerId,
                },
            );
            return;
          }

          const message =
              notificationForStatus(
                  newStatus,
                  orderId,
              );

          const result =
              await sendNotifications({
                tokens,
                tokenOwners,
                title: message.title,
                body: message.body,
                orderId,
                status: newStatus,
                customerId,
              });

          logger.info(
              "Order notification completed.",
              {
                orderId,
                customerId,
                status: newStatus,
                successCount:
                    result.successCount,
                failureCount:
                    result.failureCount,
              },
          );
        },
    );