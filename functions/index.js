/**
 * RD Online Shop
 * Firebase Cloud Functions
 *
 * Payment backend foundation:
 * - Khalti payment initiation
 * - Khalti payment verification
 *
 * Notification backend:
 * - Push notification when an order status changes
 */

const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const KHALTI_BASE_URL = "https://dev.khalti.com/api/v2";
const KHALTI_SECRET_KEY = process.env.KHALTI_SECRET_KEY || "";
const REGION = "asia-south1";

/**
 * Send a JSON response.
 *
 * @param {object} res Express response.
 * @param {number} statusCode HTTP status code.
 * @param {object} data Response data.
 */
function sendJson(res, statusCode, data) {
  res.status(statusCode).json(data);
}

/**
 * Check whether a value is empty.
 *
 * @param {*} value Value to check.
 * @return {boolean} True when empty.
 */
function isEmpty(value) {
  return value === undefined ||
    value === null ||
    String(value).trim() === "";
}

/**
 * Convert rupees to paisa.
 *
 * @param {*} amount Amount in rupees.
 * @return {number|null} Amount in paisa.
 */
function rupeesToPaisa(amount) {
  const parsedAmount = Number(amount);

  if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
    return null;
  }

  return Math.round(parsedAmount * 100);
}

/**
 * Khalti authorization headers.
 *
 * @return {object} Request headers.
 */
function khaltiHeaders() {
  return {
    "Authorization": `Key ${KHALTI_SECRET_KEY}`,
    "Content-Type": "application/json",
  };
}

/**
 * Build notification title and body for an order status.
 *
 * @param {string} status Current order status.
 * @param {string} orderId Order ID.
 * @return {{title: string, body: string}} Notification text.
 */
function orderStatusNotificationText(status, orderId) {
  const cleanStatus = String(status || "").trim();
  const cleanOrderId = String(orderId || "").trim();

  switch (cleanStatus.toLowerCase()) {
    case "confirmed":
      return {
        title: "Order Confirmed",
        body: `Your order ${cleanOrderId} has been confirmed.`,
      };

    case "processing":
      return {
        title: "Order Processing",
        body: `Your order ${cleanOrderId} is being prepared.`,
      };

    case "shipped":
      return {
        title: "Order Shipped",
        body: `Your order ${cleanOrderId} has been shipped.`,
      };

    case "delivered":
      return {
        title: "Order Delivered",
        body: `Your order ${cleanOrderId} has been delivered.`,
      };

    case "cancelled":
    case "canceled":
      return {
        title: "Order Cancelled",
        body: `Your order ${cleanOrderId} has been cancelled.`,
      };

    case "returned":
      return {
        title: "Order Returned",
        body: `Your order ${cleanOrderId} has been marked returned.`,
      };

    case "refunded":
      return {
        title: "Refund Completed",
        body: `Refund for order ${cleanOrderId} has been completed.`,
      };

    default:
      return {
        title: "Order Update",
        body: `Order ${cleanOrderId} status is now ${cleanStatus}.`,
      };
  }
}

/**
 * Collect active FCM tokens for a stable customer ID.
 *
 * @param {string} customerId Stable RD customer ID.
 * @return {Promise<string[]>} Unique FCM tokens.
 */
async function getCustomerFcmTokens(customerId) {
  const cleanCustomerId = String(customerId || "").trim();

  if (!cleanCustomerId) {
    return [];
  }

  const snapshot = await getFirestore()
      .collection("customers")
      .where("customerId", "==", cleanCustomerId)
      .get();

  const tokens = new Set();

  for (const document of snapshot.docs) {
    const data = document.data() || {};

    if (data.isActive === false) {
      continue;
    }

    if (data.notificationsEnabled === false) {
      continue;
    }

    const singleToken = String(data.fcmToken || "").trim();

    if (singleToken) {
      tokens.add(singleToken);
    }

    if (Array.isArray(data.fcmTokens)) {
      for (const rawToken of data.fcmTokens) {
        const token = String(rawToken || "").trim();

        if (token) {
          tokens.add(token);
        }
      }
    }
  }

  return Array.from(tokens);
}

/**
 * Send an order status push notification to customer devices.
 *
 * @param {string[]} tokens FCM device tokens.
 * @param {string} title Notification title.
 * @param {string} body Notification body.
 * @param {string} orderId Order ID.
 * @param {string} status New order status.
 * @return {Promise<{successCount: number, failureCount: number}>}
 *   Delivery summary.
 */
async function sendOrderStatusPush(
    tokens,
    title,
    body,
    orderId,
    status,
) {
  let successCount = 0;
  let failureCount = 0;

  for (let start = 0; start < tokens.length; start += 500) {
    const batch = tokens.slice(start, start + 500);

    const response = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: {
        title,
        body,
      },
      data: {
        type: "order_status",
        orderId: String(orderId),
        status: String(status),
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

    response.responses.forEach((result, index) => {
      if (!result.success) {
        logger.warn("FCM send failed", {
          orderId: String(orderId),
          tokenIndex: start + index,
          errorCode: (result.error && result.error.code) || "unknown",
          errorMessage:
            (result.error && result.error.message) || "Unknown FCM error",
        });
      }
    });
  }

  return {
    successCount,
    failureCount,
  };
}

/**
 * Khalti payment initiation endpoint.
 */
exports.initiateKhaltiPayment = onRequest(
    {
      region: REGION,
      cors: true,
    },
    async (req, res) => {
      if (req.method !== "POST") {
        sendJson(res, 405, {
          success: false,
          message: "Only POST requests are allowed.",
        });
        return;
      }

      if (isEmpty(KHALTI_SECRET_KEY)) {
        logger.error("KHALTI_SECRET_KEY is not configured.");

        sendJson(res, 500, {
          success: false,
          message:
            "Khalti payment is not configured on the server.",
        });
        return;
      }

      try {
        const {
          amount,
          orderId,
          customerName,
          customerEmail,
          customerPhone,
          returnUrl,
          websiteUrl,
        } = req.body || {};

        const amountInPaisa = rupeesToPaisa(amount);

        if (amountInPaisa === null) {
          sendJson(res, 400, {
            success: false,
            message: "A valid payment amount is required.",
          });
          return;
        }

        if (isEmpty(orderId)) {
          sendJson(res, 400, {
            success: false,
            message: "Order ID is required.",
          });
          return;
        }

        if (isEmpty(returnUrl)) {
          sendJson(res, 400, {
            success: false,
            message: "Return URL is required.",
          });
          return;
        }

        if (isEmpty(websiteUrl)) {
          sendJson(res, 400, {
            success: false,
            message: "Website URL is required.",
          });
          return;
        }

        const payload = {
          return_url: String(returnUrl),
          website_url: String(websiteUrl),
          amount: amountInPaisa,
          purchase_order_id: String(orderId),
          purchase_order_name:
            `RD Online Shop - ${orderId}`,
        };

        const customerInfo = {};

        if (!isEmpty(customerName)) {
          customerInfo.name = String(customerName);
        }

        if (!isEmpty(customerEmail)) {
          customerInfo.email = String(customerEmail);
        }

        if (!isEmpty(customerPhone)) {
          customerInfo.phone = String(customerPhone);
        }

        if (Object.keys(customerInfo).length > 0) {
          payload.customer_info = customerInfo;
        }

        logger.info("Initiating Khalti payment", {
          orderId: String(orderId),
          amountInPaisa,
        });

        const response = await fetch(
            `${KHALTI_BASE_URL}/epayment/initiate/`,
            {
              method: "POST",
              headers: khaltiHeaders(),
              body: JSON.stringify(payload),
            },
        );

        const responseText = await response.text();

        let data;

        try {
          data = JSON.parse(responseText);
        } catch (_) {
          data = {
            detail: responseText,
          };
        }

        if (!response.ok) {
          logger.error("Khalti initiation failed", {
            status: response.status,
            data,
          });

          sendJson(res, response.status, {
            success: false,
            message: "Khalti payment initiation failed.",
            khalti: data,
          });
          return;
        }

        sendJson(res, 200, {
          success: true,
          message:
            "Khalti payment initiated successfully.",
          pidx: data.pidx || "",
          paymentUrl: data.payment_url || "",
          expiresAt: data.expires_at || "",
          expiresIn: data.expires_in || 0,
        });
      } catch (error) {
        logger.error(
            "initiateKhaltiPayment error",
            error,
        );

        sendJson(res, 500, {
          success: false,
          message: "Unable to initiate Khalti payment.",
        });
      }
    },
);

/**
 * Khalti payment verification endpoint.
 */
exports.verifyKhaltiPayment = onRequest(
    {
      region: REGION,
      cors: true,
    },
    async (req, res) => {
      if (req.method !== "POST") {
        sendJson(res, 405, {
          success: false,
          message: "Only POST requests are allowed.",
        });
        return;
      }

      if (isEmpty(KHALTI_SECRET_KEY)) {
        logger.error("KHALTI_SECRET_KEY is not configured.");

        sendJson(res, 500, {
          success: false,
          message:
            "Khalti payment is not configured on the server.",
        });
        return;
      }

      try {
        const {pidx} = req.body || {};

        if (isEmpty(pidx)) {
          sendJson(res, 400, {
            success: false,
            message: "Khalti PIDX is required.",
          });
          return;
        }

        logger.info("Verifying Khalti payment", {
          pidx: String(pidx),
        });

        const response = await fetch(
            `${KHALTI_BASE_URL}/epayment/lookup/`,
            {
              method: "POST",
              headers: khaltiHeaders(),
              body: JSON.stringify({
                pidx: String(pidx),
              }),
            },
        );

        const responseText = await response.text();

        let data;

        try {
          data = JSON.parse(responseText);
        } catch (_) {
          data = {
            detail: responseText,
          };
        }

        if (!response.ok) {
          logger.error("Khalti verification failed", {
            status: response.status,
            data,
          });

          sendJson(res, response.status, {
            success: false,
            verified: false,
            message:
              "Khalti payment verification failed.",
            khalti: data,
          });
          return;
        }

        const paymentStatus = String(data.status || "");
        const verified =
          paymentStatus === "Completed";

        sendJson(res, 200, {
          success: true,
          verified,
          message: verified ?
            "Khalti payment verified successfully." :
            `Khalti payment status: ${paymentStatus}`,
          pidx: data.pidx || String(pidx),
          status: paymentStatus,
          transactionId: data.transaction_id || "",
          totalAmount: data.total_amount || 0,
          fee: data.fee || 0,
          refunded: data.refunded || false,
          purchaseOrderId:
            data.purchase_order_id || "",
          purchaseOrderName:
            data.purchase_order_name || "",
        });
      } catch (error) {
        logger.error(
            "verifyKhaltiPayment error",
            error,
        );

        sendJson(res, 500, {
          success: false,
          verified: false,
          message: "Unable to verify Khalti payment.",
        });
      }
    },
);

/**
 * Send a real push notification when an order status changes.
 */
exports.orderStatusPushNotification = onDocumentUpdated(
    {
      document: "orders/{orderId}",
      region: REGION,
    },
    async (event) => {
      if (!event.data) {
        return;
      }

      const beforeData =
        event.data.before.data() || {};

      const afterData =
        event.data.after.data() || {};

      const oldStatus =
        String(beforeData.status || "").trim();

      const newStatus =
        String(afterData.status || "").trim();

      if (!newStatus || oldStatus === newStatus) {
        return;
      }

      const orderId = String(
          event.params.orderId ||
          afterData.id ||
          "",
      ).trim();

      const customerId = String(
          afterData.customerId || "",
      ).trim();

      if (!customerId) {
        logger.warn(
            "Order status changed without customerId",
            {
              orderId,
              oldStatus,
              newStatus,
            },
        );

        return;
      }

      try {
        const tokens =
          await getCustomerFcmTokens(customerId);

        if (tokens.length === 0) {
          logger.warn(
              "No FCM token found for order customer",
              {
                orderId,
                customerId,
                oldStatus,
                newStatus,
              },
          );

          return;
        }

        const notification =
          orderStatusNotificationText(
              newStatus,
              orderId,
          );

        const result =
          await sendOrderStatusPush(
              tokens,
              notification.title,
              notification.body,
              orderId,
              newStatus,
          );

        logger.info(
            "Order status push completed",
            {
              orderId,
              customerId,
              oldStatus,
              newStatus,
              tokenCount: tokens.length,
              successCount:
                result.successCount,
              failureCount:
                result.failureCount,
            },
        );
      } catch (error) {
        logger.error(
            "orderStatusPushNotification error",
            {
              orderId,
              customerId,
              oldStatus,
              newStatus,
              errorMessage:
                (error && error.message) ||
                String(error),
              errorStack:
                (error && error.stack) || "",
            },
        );
      }
    },
);
