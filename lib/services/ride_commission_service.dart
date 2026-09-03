import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<double> loadCommissionPercent() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _settingsRef.get();
      return _safePercent(snapshot.data()?['commissionPercent']);
    } catch (_) {
      return fallbackPercent;
    }
  }

  Stream<double> watchCommissionPercent() {
    return _settingsRef.snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
              _safePercent(snapshot.data()?['commissionPercent']),
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
}
