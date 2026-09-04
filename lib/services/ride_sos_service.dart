import 'package:cloud_firestore/cloud_firestore.dart';

class RideSosService {
  RideSosService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createAlert({
    required Map<String, dynamic> ride,
    required String triggeredBy,
    required String triggeredByUid,
    required String reason,
    required double? latitude,
    required double? longitude,
    required String locationAddress,
  }) async {
    final String rideRequestId =
        ride['rideRequestId']?.toString().trim() ?? '';
    final String driverId = ride['driverId']?.toString().trim() ?? '';
    final String customerAuthUid =
        ride['customerAuthUid']?.toString().trim() ?? '';
    final String customerId =
        ride['customerId']?.toString().trim() ?? '';
    final String rideStatus =
        ride['status']?.toString().trim().toLowerCase() ?? '';

    if (rideRequestId.isEmpty ||
        driverId.isEmpty ||
        customerAuthUid.isEmpty ||
        customerId.isEmpty ||
        triggeredByUid.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw StateError('Required SOS ride information is missing.');
    }

    if (!<String>['accepted', 'arrived', 'in_progress'].contains(rideStatus)) {
      throw StateError('SOS is available only during an active ride.');
    }

    final String cleanTriggeredBy = triggeredBy.trim().toLowerCase();
    if (!<String>['customer', 'driver'].contains(cleanTriggeredBy)) {
      throw StateError('Invalid SOS sender role.');
    }

    // One active SOS slot per ride + sender role. Repeated taps cannot create
    // multiple active alerts for the same customer/driver ride.
    final String alertId = '${rideRequestId}__$cleanTriggeredBy';
    final DocumentReference<Map<String, dynamic>> alertRef =
        _firestore.collection('ride_sos_alerts').doc(alertId);

    final Map<String, dynamic> payload = <String, dynamic>{
        'rideRequestId': rideRequestId,
        'customerAuthUid': customerAuthUid,
        'customerId': customerId,
        'driverId': driverId,
        'triggeredBy': cleanTriggeredBy,
        'triggeredByUid': triggeredByUid.trim(),
        'reason': reason.trim(),
        'status': 'active',
        'customerName':
            ride['customerName']?.toString().trim() ?? '',
        'customerPhone':
            ride['customerPhone']?.toString().trim() ?? '',
        'driverName':
            ride['driverName']?.toString().trim() ?? '',
        'driverPhone':
            ride['driverPhone']?.toString().trim() ?? '',
        'rideStatusSnapshot': rideStatus,
        'pickupAddress':
            ride['pickupAddress']?.toString().trim() ?? '',
        'destinationAddress':
            ride['destinationAddress']?.toString().trim() ?? '',
        'latitude': latitude,
        'longitude': longitude,
        'locationAddress': locationAddress.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
      };

    // Do not read the SOS document before writing it. A transaction read on a
    // not-yet-existing SOS document requires read permission and can cause
    // PERMISSION_DENIED for Customer/Driver. The deterministic document ID
    // already guarantees one SOS slot per ride + sender role.
    await alertRef.set(payload);

    return alertRef.id;
  }
}
