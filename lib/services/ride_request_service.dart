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
