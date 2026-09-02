import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    final DocumentReference<Map<String, dynamic>> ref =
        _rideRequests.doc();

    await ref.set(
      <String, dynamic>{
        'rideRequestId': ref.id,

        // Customer
        'customerId': cleanCustomerId,
        'customerAuthUid': user.uid,

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

        // Tracking foundation
        'tripStartedAt': null,
        'tripCompletedAt': null,
        'cancelledAt': null,

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

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
