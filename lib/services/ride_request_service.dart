import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ride_commission_service.dart';
import 'ride_driver_service.dart';

class RideRequestService {
  RideRequestService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rideRequests =>
      _firestore.collection('ride_requests');

  double _calculateFare({
    required double distanceKm,
    required double baseFare,
    required double perKm,
    required double minimumFare,
  }) {
    final double rawFare = baseFare + (distanceKm * perKm);
    final double minimumApplied =
        rawFare < minimumFare ? minimumFare : rawFare;
    return (minimumApplied / 5).ceil() * 5.0;
  }


  Future<Map<String, String>> _loadCustomerContact(
    User user,
    String customerId,
  ) async {
    String name = '';
    String phone = '';

    Future<void> readCustomerDocument(String documentId) async {
      final String cleanId = documentId.trim();
      if (cleanId.isEmpty || (name.isNotEmpty && phone.isNotEmpty)) {
        return;
      }

      try {
        final DocumentSnapshot<Map<String, dynamic>> document =
            await _firestore.collection('customers').doc(cleanId).get();
        final Map<String, dynamic> data =
            document.data() ?? <String, dynamic>{};

        if (name.isEmpty) {
          name = data['name']?.toString().trim() ?? '';
        }
        if (phone.isEmpty) {
          phone = data['phone']?.toString().trim() ?? '';
        }
      } catch (_) {
        // Local profile fallback below keeps ride booking usable.
      }
    }

    await readCustomerDocument(user.uid);
    if (customerId != user.uid) {
      await readCustomerDocument(customerId);
    }

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (name.isEmpty) {
        name = prefs.getString('name')?.trim() ?? '';
      }
      if (phone.isEmpty) {
        phone = prefs.getString('phone')?.trim() ?? '';
      }
    } catch (_) {
      // Contact details are optional for chat; call button can be unavailable.
    }

    return <String, String>{
      'name': name,
      'phone': phone,
    };
  }

  String _generateTripStartOtp() {
    final Random random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _hashTripStartOtp(String otp) {
    return sha256.convert(utf8.encode(otp)).toString();
  }

  Future<String> createRideRequest({
    required String customerId,
    required RideDriverNearby driver,
    required String vehicleType,
    required String pickupAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
    required double routeDistanceKm,
    required int routeDurationMinutes,
    required double estimatedFare,
    required String currency,
    required bool fareUsesRoadRoute,
    required double fareBaseFare,
    required double farePerKm,
    required double fareMinimumFare,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'Customer session is not available.',
      );
    }

    final String cleanCustomerId = customerId.trim();
    final String cleanVehicleType = vehicleType.trim();
    final String cleanPickupAddress = pickupAddress.trim();
    final String cleanDestinationAddress =
        destinationAddress.trim();
    final String cleanCurrency = currency.trim();

    if (cleanCustomerId.isEmpty) {
      throw ArgumentError(
        'customerId cannot be empty.',
      );
    }

    if (cleanVehicleType.isEmpty) {
      throw ArgumentError(
        'vehicleType cannot be empty.',
      );
    }

    if (cleanPickupAddress.isEmpty) {
      throw ArgumentError(
        'pickupAddress cannot be empty.',
      );
    }

    if (cleanDestinationAddress.isEmpty) {
      throw ArgumentError(
        'destinationAddress cannot be empty.',
      );
    }

    if (routeDistanceKm <= 0) {
      throw ArgumentError(
        'routeDistanceKm must be greater than zero.',
      );
    }

    if (routeDurationMinutes <= 0) {
      throw ArgumentError(
        'routeDurationMinutes must be greater than zero.',
      );
    }

    if (estimatedFare <= 0) {
      throw ArgumentError(
        'estimatedFare must be greater than zero.',
      );
    }

    if (cleanCurrency.isEmpty) {
      throw ArgumentError(
        'currency cannot be empty.',
      );
    }

    if (fareBaseFare <= 0 ||
        farePerKm <= 0 ||
        fareMinimumFare <= 0) {
      throw ArgumentError(
        'Fare rate snapshot must be greater than zero.',
      );
    }

    final double startingLiveFare = _calculateFare(
      distanceKm: 0,
      baseFare: fareBaseFare,
      perKm: farePerKm,
      minimumFare: fareMinimumFare,
    );

    final Map<String, String> customerContact =
        await _loadCustomerContact(user, cleanCustomerId);
    final double rdCommissionPercent =
        await RideCommissionService(
          firestore: _firestore,
        ).loadCommissionPercent();
    final double estimatedRdCommission =
        estimatedFare * rdCommissionPercent / 100.0;
    final double estimatedDriverIncome =
        (estimatedFare - estimatedRdCommission)
            .clamp(0.0, estimatedFare)
            .toDouble();
    final String tripStartOtp = _generateTripStartOtp();
    final String tripStartOtpHash = _hashTripStartOtp(tripStartOtp);

    final DocumentReference<Map<String, dynamic>> ref =
        _rideRequests.doc();
    final DocumentReference<Map<String, dynamic>> customerPrivateRef =
        ref.collection('private').doc('customer');
    final WriteBatch batch = _firestore.batch();

    batch.set(
      ref,
      <String, dynamic>{
        'rideRequestId': ref.id,

        // Customer
        'customerId': cleanCustomerId,
        'customerAuthUid': user.uid,
        'customerName': customerContact['name'] ?? '',
        'customerPhone': customerContact['phone'] ?? '',

        // Selected ride driver
        'driverId': driver.driverId,
        'driverName': driver.name,
        'driverPhone': driver.phone,
        'driverPhotoUrl': driver.photoUrl,

        // Vehicle
        'vehicleType': cleanVehicleType,
        'vehicleNumber': driver.vehicleNumber,

        // Pickup
        'pickupAddress': cleanPickupAddress,
        'pickupLatitude': pickupLatitude,
        'pickupLongitude': pickupLongitude,

        // Destination
        'destinationAddress': cleanDestinationAddress,
        'destinationLatitude': destinationLatitude,
        'destinationLongitude': destinationLongitude,

        // Request status
        'status': 'pending',
        'requestType': 'ride_now',
        'driverResponse': 'waiting',

        // Route + fare snapshot from the customer booking screen.
        // Keep this immutable estimate available to both customer and driver.
        'routeDistanceKm': routeDistanceKm,
        'routeDurationMinutes': routeDurationMinutes,
        'estimatedFare': estimatedFare,
        'finalFare': null,
        'currency': cleanCurrency,
        'fareUsesRoadRoute': fareUsesRoadRoute,
        'fareEstimateSource':
            fareUsesRoadRoute ? 'road_route' : 'fallback_approximation',

        // Immutable fare-rate snapshot for this ride.
        // A later Admin rate change must not change an existing ride.
        'fareBaseFare': fareBaseFare,
        'farePerKm': farePerKm,
        'fareMinimumFare': fareMinimumFare,
        'fareRoundingStep': 5.0,

        // Immutable RD commission snapshot for this ride.
        // Later Admin commission changes must not change old ride earnings.
        'rdCommissionPercent': rdCommissionPercent,
        'estimatedRdCommission': estimatedRdCommission,
        'estimatedDriverIncome': estimatedDriverIncome,
        'finalRdCommission': null,
        'driverNetIncome': null,

        // Live actual trip fare. Distance starts at zero and only increases
        // after the Ride Driver presses Start Trip.
        'actualDistanceKm': 0.0,
        'liveFare': startingLiveFare,
        'finalDistanceKm': null,
        'tripDistanceLastLatitude': null,
        'tripDistanceLastLongitude': null,
        'tripDistanceLastPositionAt': null,
        'tripDistanceUpdatedAt': null,

        // Trip start OTP. Only the hash is visible to the Ride Driver.
        // The actual 6-digit OTP is stored in the customer-private subdocument.
        'tripStartOtpRequired': true,
        'tripStartOtpHash': tripStartOtpHash,
        'tripStartOtpVerifiedAt': null,

        // Tracking foundation
        'tripStartedAt': null,
        'tripCompletedAt': null,
        'cancelledAt': null,
        'arrivedAt': null,

        // Cancellation snapshot.
        // Before driver acceptance the customer cancellation fee is 0.
        // After acceptance, RD uses this ride's immutable base fare snapshot.
        'cancelledBy': null,
        'cancellationReason': null,
        'cancellationPreviousStatus': null,
        'cancellationFee': 0.0,
        'cancellationCurrency': cleanCurrency,
        'cancellationFeeStatus': 'not_required',

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      customerPrivateRef,
      <String, dynamic>{
        'rideRequestId': ref.id,
        'tripStartOtp': tripStartOtp,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return ref.id;
  }


  double _cancellationFeeForStatus(
    Map<String, dynamic> ride,
    String status,
  ) {
    if (status != 'accepted' && status != 'arrived') {
      return 0.0;
    }

    final dynamic rawBaseFare = ride['fareBaseFare'];
    final double baseFare = rawBaseFare is num
        ? rawBaseFare.toDouble()
        : double.tryParse(rawBaseFare?.toString().trim() ?? '') ?? 0.0;

    return baseFare > 0 ? baseFare : 0.0;
  }

  Future<RideCancellationResult> cancelCustomerRide({
    required String rideRequestId,
    required String reason,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Customer session is not available.');
    }

    final String cleanId = rideRequestId.trim();
    final String cleanReason = reason.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('rideRequestId cannot be empty.');
    }
    if (cleanReason.isEmpty || cleanReason.length > 200) {
      throw ArgumentError('A cancellation reason is required.');
    }

    final DocumentReference<Map<String, dynamic>> rideRef =
        _rideRequests.doc(cleanId);
    final DocumentReference<Map<String, dynamic>> privateRef =
        rideRef.collection('private').doc('customer');

    return _firestore.runTransaction<RideCancellationResult>(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(rideRef);
        final Map<String, dynamic>? ride = snapshot.data();

        if (!snapshot.exists || ride == null) {
          throw StateError('Ride request was not found.');
        }

        if (ride['customerAuthUid']?.toString().trim() != user.uid) {
          throw StateError('This ride does not belong to the current customer.');
        }

        final String status =
            ride['status']?.toString().trim().toLowerCase() ?? '';

        if (status != 'pending' &&
            status != 'accepted' &&
            status != 'arrived') {
          throw StateError(
            status == 'in_progress' || status == 'started'
                ? 'A trip that has already started cannot be cancelled here.'
                : 'This ride can no longer be cancelled.',
          );
        }

        final double fee = _cancellationFeeForStatus(ride, status);
        final String currency =
            ride['currency']?.toString().trim().isNotEmpty == true
                ? ride['currency'].toString().trim()
                : 'Rs.';

        transaction.update(
          rideRef,
          <String, dynamic>{
            'status': 'cancelled',
            'cancelledBy': 'customer',
            'cancellationReason': cleanReason,
            'cancellationPreviousStatus': status,
            'cancellationFee': fee,
            'cancellationCurrency': currency,
            'cancellationFeeStatus': fee > 0 ? 'due' : 'not_required',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        // The real Trip Start OTP is no longer needed after cancellation.
        transaction.delete(privateRef);

        return RideCancellationResult(
          previousStatus: status,
          fee: fee,
          currency: currency,
        );
      },
    );
  }

  Future<RideCancellationResult> cancelDriverRide({
    required String rideRequestId,
    required String reason,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Ride Driver session is not available.');
    }

    final String cleanId = rideRequestId.trim();
    final String cleanReason = reason.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('rideRequestId cannot be empty.');
    }
    if (cleanReason.isEmpty || cleanReason.length > 200) {
      throw ArgumentError('A cancellation reason is required.');
    }

    final DocumentReference<Map<String, dynamic>> rideRef =
        _rideRequests.doc(cleanId);
    final DocumentReference<Map<String, dynamic>> privateRef =
        rideRef.collection('private').doc('customer');
    final DocumentReference<Map<String, dynamic>> driverRef =
        _firestore.collection('ride_drivers').doc(user.uid);

    return _firestore.runTransaction<RideCancellationResult>(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(rideRef);
        final Map<String, dynamic>? ride = snapshot.data();

        if (!snapshot.exists || ride == null) {
          throw StateError('Ride request was not found.');
        }

        if (ride['driverId']?.toString().trim() != user.uid) {
          throw StateError('This ride is not assigned to the current driver.');
        }

        final String status =
            ride['status']?.toString().trim().toLowerCase() ?? '';

        if (status != 'accepted' && status != 'arrived') {
          throw StateError(
            status == 'in_progress' || status == 'started'
                ? 'A trip that has already started cannot be cancelled here.'
                : 'Only an accepted or arrived ride can be cancelled by the driver.',
          );
        }

        final String currency =
            ride['currency']?.toString().trim().isNotEmpty == true
                ? ride['currency'].toString().trim()
                : 'Rs.';

        transaction.update(
          rideRef,
          <String, dynamic>{
            'status': 'cancelled',
            'cancelledBy': 'driver',
            'cancellationReason': cleanReason,
            'cancellationPreviousStatus': status,
            'cancellationFee': 0.0,
            'cancellationCurrency': currency,
            'cancellationFeeStatus': 'not_required',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.update(
          driverRef,
          <String, dynamic>{
            'currentRideRequestId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        transaction.delete(privateRef);

        return RideCancellationResult(
          previousStatus: status,
          fee: 0.0,
          currency: currency,
        );
      },
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>
      watchRideRequest(
    String rideRequestId,
  ) {
    final String cleanId = rideRequestId.trim();

    if (cleanId.isEmpty) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }

    return _rideRequests.doc(cleanId).snapshots();
  }
}

class RideCancellationResult {
  const RideCancellationResult({
    required this.previousStatus,
    required this.fee,
    required this.currency,
  });

  final String previousStatus;
  final double fee;
  final String currency;
}
