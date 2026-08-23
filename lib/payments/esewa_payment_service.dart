import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class EsewaConfig {
  static const String productCode = 'EPAYTEST';
  static const String uatSecretKey = '8gBm/:&EnhH.1/q';
  static const String paymentUrl =
      'https://rc-epay.esewa.com.np/api/epay/main/v2/form';
  static const String statusUrl =
      'https://rc.esewa.com.np/api/epay/transaction/status/';
  static const String successUrl =
      'https://example.com/rd-online-shop/esewa/success';
  static const String failureUrl =
      'https://example.com/rd-online-shop/esewa/failure';
}

class EsewaResult {
  final bool success;
  final bool cancelled;
  final String status;
  final String transactionUuid;
  final String transactionCode;
  final String referenceId;
  final double totalAmount;
  final String message;

  const EsewaResult({
    required this.success,
    required this.cancelled,
    required this.status,
    required this.transactionUuid,
    required this.transactionCode,
    required this.referenceId,
    required this.totalAmount,
    required this.message,
  });

  factory EsewaResult.failure({
    required String transactionUuid,
    required String message,
    String status = 'FAILED',
  }) {
    return EsewaResult(
      success: false,
      cancelled: false,
      status: status,
      transactionUuid: transactionUuid,
      transactionCode: '',
      referenceId: '',
      totalAmount: 0,
      message: message,
    );
  }

  factory EsewaResult.cancelled(String transactionUuid) {
    return EsewaResult(
      success: false,
      cancelled: true,
      status: 'CANCELED',
      transactionUuid: transactionUuid,
      transactionCode: '',
      referenceId: '',
      totalAmount: 0,
      message: 'eSewa payment was cancelled.',
    );
  }
}

class EsewaPaymentService {
  static String formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _sign(String message) {
    final Hmac hmac =
        Hmac(sha256, utf8.encode(EsewaConfig.uatSecretKey));
    return base64Encode(hmac.convert(utf8.encode(message)).bytes);
  }

  static Map<String, String> createFormFields({
    required String transactionUuid,
    required double totalAmount,
  }) {
    final String amount = formatAmount(totalAmount);
    final String message =
        'total_amount=$amount,transaction_uuid=$transactionUuid,'
        'product_code=${EsewaConfig.productCode}';

    return <String, String>{
      'amount': amount,
      'tax_amount': '0',
      'total_amount': amount,
      'transaction_uuid': transactionUuid,
      'product_code': EsewaConfig.productCode,
      'product_service_charge': '0',
      'product_delivery_charge': '0',
      'success_url': EsewaConfig.successUrl,
      'failure_url': EsewaConfig.failureUrl,
      'signed_field_names':
          'total_amount,transaction_uuid,product_code',
      'signature': _sign(message),
    };
  }

  static String createAutoSubmitHtml({
    required String transactionUuid,
    required double totalAmount,
  }) {
    final Map<String, String> fields = createFormFields(
      transactionUuid: transactionUuid,
      totalAmount: totalAmount,
    );

    String escape(String value) =>
        const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

    final String inputs = fields.entries
        .map((entry) =>
            '<input type="hidden" name="${escape(entry.key)}" '
            'value="${escape(entry.value)}">')
        .join();

    return '''
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
<form id="esewaForm" method="POST" action="${EsewaConfig.paymentUrl}">
$inputs
</form>
<script>
window.onload = function() {
  document.getElementById('esewaForm').submit();
};
</script>
</body>
</html>
''';
  }

  static Map<String, dynamic>? decodeCallback(Uri uri) {
    final String? encoded = uri.queryParameters['data'];
    if (encoded == null || encoded.trim().isEmpty) return null;

    try {
      String normalized = encoded.trim().replaceAll(' ', '+');
      normalized = base64.normalize(normalized);
      final dynamic decoded =
          jsonDecode(utf8.decode(base64Decode(normalized)));
      if (decoded is Map) {
        return decoded.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static bool verifyCallbackSignature(Map<String, dynamic> data) {
    final String received =
        data['signature']?.toString().trim() ?? '';
    final String signedNames =
        data['signed_field_names']?.toString().trim() ?? '';
    if (received.isEmpty || signedNames.isEmpty) return false;

    final List<String> parts = <String>[];
    for (final String name
        in signedNames.split(',').map((value) => value.trim())) {
      if (name.isEmpty || !data.containsKey(name)) return false;
      parts.add('$name=${data[name]}');
    }
    return _constantTimeEquals(_sign(parts.join(',')), received);
  }

  static bool _constantTimeEquals(String left, String right) {
    final List<int> a = utf8.encode(left);
    final List<int> b = utf8.encode(right);
    if (a.length != b.length) return false;

    int difference = 0;
    for (int i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static Future<EsewaResult> verifyStatus({
    required String transactionUuid,
    required double totalAmount,
    String transactionCode = '',
  }) async {
    final Uri uri = Uri.parse(EsewaConfig.statusUrl).replace(
      queryParameters: <String, String>{
        'product_code': EsewaConfig.productCode,
        'total_amount': formatAmount(totalAmount),
        'transaction_uuid': transactionUuid,
      },
    );

    try {
      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return EsewaResult.failure(
          transactionUuid: transactionUuid,
          status: 'VERIFY_ERROR',
          message: 'eSewa verification failed (${response.statusCode}).',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return EsewaResult.failure(
          transactionUuid: transactionUuid,
          status: 'VERIFY_ERROR',
          message: 'Invalid eSewa verification response.',
        );
      }

      final Map<String, dynamic> data = decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );

      final String status =
          data['status']?.toString().trim().toUpperCase() ?? '';
      final String responseUuid =
          (data['transaction_uuid'] ?? data['pid'])
                  ?.toString()
                  .trim() ??
              '';
      final double responseAmount = double.tryParse(
            (data['total_amount'] ?? data['totalAmount'])
                    ?.toString()
                    .replaceAll(',', '')
                    .trim() ??
                '',
          ) ??
          0;
      final String refId =
          (data['ref_id'] ?? data['refId'])?.toString().trim() ?? '';

      final bool uuidOk =
          responseUuid.isEmpty || responseUuid == transactionUuid;
      final bool amountOk = (responseAmount - totalAmount).abs() < 0.01;

      if (status == 'COMPLETE' && uuidOk && amountOk) {
        return EsewaResult(
          success: true,
          cancelled: false,
          status: status,
          transactionUuid: transactionUuid,
          transactionCode: transactionCode,
          referenceId: refId,
          totalAmount: responseAmount,
          message: 'eSewa payment verified successfully.',
        );
      }

      return EsewaResult.failure(
        transactionUuid: transactionUuid,
        status: status.isEmpty ? 'UNKNOWN' : status,
        message: status == 'PENDING'
            ? 'eSewa payment is still pending.'
            : 'eSewa payment status: ${status.isEmpty ? 'UNKNOWN' : status}.',
      );
    } catch (error) {
      return EsewaResult.failure(
        transactionUuid: transactionUuid,
        status: 'VERIFY_ERROR',
        message: 'Could not verify eSewa payment: $error',
      );
    }
  }
}
