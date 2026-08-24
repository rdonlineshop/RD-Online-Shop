/**
 * RD Online Shop
 * Firebase Cloud Functions
 *
 * Payment backend foundation:
 * - Khalti payment initiation
 * - Khalti payment verification
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

const KHALTI_BASE_URL = "https://dev.khalti.com/api/v2";
const KHALTI_SECRET_KEY = process.env.KHALTI_SECRET_KEY || "";

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
 * Khalti payment initiation endpoint.
 */
exports.initiateKhaltiPayment = onRequest(
    {
      region: "asia-south1",
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
          message: "Khalti payment is not configured on the server.",
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
          purchase_order_name: `RD Online Shop - ${orderId}`,
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
          message: "Khalti payment initiated successfully.",
          pidx: data.pidx || "",
          paymentUrl: data.payment_url || "",
          expiresAt: data.expires_at || "",
          expiresIn: data.expires_in || 0,
        });
      } catch (error) {
        logger.error("initiateKhaltiPayment error", error);

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
      region: "asia-south1",
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
          message: "Khalti payment is not configured on the server.",
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
            message: "Khalti payment verification failed.",
            khalti: data,
          });
          return;
        }

        const paymentStatus = String(data.status || "");
        const verified = paymentStatus === "Completed";

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
          purchaseOrderId: data.purchase_order_id || "",
          purchaseOrderName: data.purchase_order_name || "",
        });
      } catch (error) {
        logger.error("verifyKhaltiPayment error", error);

        sendJson(res, 500, {
          success: false,
          verified: false,
          message: "Unable to verify Khalti payment.",
        });
      }
    },
);
