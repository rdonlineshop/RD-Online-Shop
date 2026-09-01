import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class RideDriverNearby {
  const RideDriverNearby({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.isOnline,
    required this.isActive,
    required this.rating,
    required this.photoUrl,
  });

  final String driverId;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;

  final double latitude;
  final double longitude;
  final double distanceKm;

  final bool isOnline;
  final bool isActive;

  final double rating;
  final String photoUrl;
}

class RideDriverService {
  RideDriverService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _drivers =>
      _firestore.collection('ride_drivers');

  Stream<List<RideDriverNearby>> nearbyDriversStream({
    required String vehicleType,
    required double pickupLatitude,
    required double pickupLongitude,
    double radiusKm = 10,
  }) {
    final String selectedVehicle = vehicleType.trim();

    if (selectedVehicle.isEmpty) {
      return Stream<List<RideDriverNearby>>.value(
        <RideDriverNearby>[],
      );
    }

    return _drivers
        .where('isActive', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .where('vehicleType', isEqualTo: selectedVehicle)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<RideDriverNearby> nearby =
            <RideDriverNearby>[];

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final Map<String, dynamic> data = doc.data();

          final double? latitude = _asDouble(
            data['latitude'] ?? data['lat'],
          );

          final double? longitude = _asDouble(
            data['longitude'] ?? data['lng'],
          );

          if (latitude == null || longitude == null) {
            continue;
          }

          final double distanceMeters =
              Geolocator.distanceBetween(
            pickupLatitude,
            pickupLongitude,
            latitude,
            longitude,
          );

          final double distanceKm =
              distanceMeters / 1000;

          if (distanceKm > radiusKm) {
            continue;
          }

          nearby.add(
            RideDriverNearby(
              driverId:
                  data['driverId']?.toString().trim().isNotEmpty ==
                          true
                      ? data['driverId'].toString().trim()
                      : doc.id,
              name:
                  data['name']?.toString().trim().isNotEmpty ==
                          true
                      ? data['name'].toString().trim()
                      : 'Ride Driver',
              phone:
                  data['phone']?.toString().trim() ?? '',
              vehicleType:
                  data['vehicleType']?.toString().trim() ??
                      selectedVehicle,
              vehicleNumber:
                  data['vehicleNumber']
                          ?.toString()
                          .trim() ??
                      '',
              latitude: latitude,
              longitude: longitude,
              distanceKm: distanceKm,
              isOnline: data['isOnline'] == true,
              isActive: data['isActive'] == true,
              rating:
                  _asDouble(data['rating']) ?? 0,
              photoUrl:
                  data['photoUrl']?.toString().trim() ?? '',
            ),
          );
        }

        nearby.sort(
          (
            RideDriverNearby first,
            RideDriverNearby second,
          ) =>
              first.distanceKm.compareTo(
            second.distanceKm,
          ),
        );

        return nearby;
      },
    );
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }
}
