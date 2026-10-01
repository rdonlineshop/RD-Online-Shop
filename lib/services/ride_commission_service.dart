import 'package:cloud_firestore/cloud_firestore.dart';

class RideCommissionSettings {
  const RideCommissionSettings({
    required this.commissionPercent,
    required this.esewaNumber,
    required this.khaltiNumber,
    required this.bankName,
    required this.bankAccountHolder,
    required this.bankAccountNumber,
    required this.paymentQrUrl,
  });

  final double commissionPercent;
  final String esewaNumber;
  final String khaltiNumber;
  final String bankName;
  final String bankAccountHolder;
  final String bankAccountNumber;
  final String paymentQrUrl;

  bool get hasReceivingAccount =>
      esewaNumber.trim().isNotEmpty ||
      khaltiNumber.trim().isNotEmpty ||
      bankAccountNumber.trim().isNotEmpty ||
      paymentQrUrl.trim().isNotEmpty;
}

class RideCommissionService {
  RideCommissionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const double fallbackPercent = 10.0;
  static const double maximumPercent = 50.0;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('ride_business_settings').doc('main');

  double _safePercent(dynamic value) {
    final double? parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString().trim() ?? '');

    if (parsed == null || parsed < 0 || parsed > maximumPercent) {
      return fallbackPercent;
    }

    return parsed;
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  RideCommissionSettings _settingsFromData(Map<String, dynamic>? data) {
    final Map<String, dynamic> value = data ?? <String, dynamic>{};

    return RideCommissionSettings(
      commissionPercent: _safePercent(value['commissionPercent']),
      esewaNumber: _text(value['commissionEsewaNumber']),
      khaltiNumber: _text(value['commissionKhaltiNumber']),
      bankName: _text(value['commissionBankName']),
      bankAccountHolder: _text(value['commissionBankAccountHolder']),
      bankAccountNumber: _text(value['commissionBankAccountNumber']),
      paymentQrUrl: _text(value['commissionPaymentQrUrl']),
    );
  }

  Future<RideCommissionSettings> loadSettings() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _settingsRef.get();
      return _settingsFromData(snapshot.data());
    } catch (_) {
      return _settingsFromData(null);
    }
  }

  Stream<RideCommissionSettings> watchSettings() {
    return _settingsRef.snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              _settingsFromData(snapshot.data()),
        );
  }

  Future<double> loadCommissionPercent() async {
    final RideCommissionSettings settings = await loadSettings();
    return settings.commissionPercent;
  }

  Stream<double> watchCommissionPercent() {
    return watchSettings().map(
      (RideCommissionSettings settings) => settings.commissionPercent,
    );
  }

  Future<void> saveCommissionPercent(double percent) async {
    if (percent < 0 || percent > maximumPercent) {
      throw ArgumentError(
        'Ride commission must be between 0 and '
        '${maximumPercent.toStringAsFixed(0)} percent.',
      );
    }

    await _settingsRef.set(
      <String, dynamic>{
        'commissionPercent': percent,
        'currency': 'Rs.',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveCommissionReceivingAccount({
    required String esewaNumber,
    required String khaltiNumber,
    required String bankName,
    required String bankAccountHolder,
    required String bankAccountNumber,
    required String paymentQrUrl,
  }) async {
    await _settingsRef.set(
      <String, dynamic>{
        'commissionEsewaNumber': esewaNumber.trim(),
        'commissionKhaltiNumber': khaltiNumber.trim(),
        'commissionBankName': bankName.trim(),
        'commissionBankAccountHolder': bankAccountHolder.trim(),
        'commissionBankAccountNumber': bankAccountNumber.trim(),
        'commissionPaymentQrUrl': paymentQrUrl.trim(),
        'currency': 'Rs.',
        'commissionPaymentUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
