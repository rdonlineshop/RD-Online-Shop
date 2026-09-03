import 'package:cloud_firestore/cloud_firestore.dart';

class RideFareRule {
  const RideFareRule({
    required this.vehicleType,
    required this.baseFare,
    required this.perKm,
    required this.minimumFare,
    required this.fallbackAverageSpeedKmh,
    required this.currency,
    required this.isActive,
    this.isFallback = false,
  });

  final String vehicleType;
  final double baseFare;
  final double perKm;
  final double minimumFare;
  final double fallbackAverageSpeedKmh;
  final String currency;
  final bool isActive;
  final bool isFallback;

  RideFareRule copyWith({
    String? vehicleType,
    double? baseFare,
    double? perKm,
    double? minimumFare,
    double? fallbackAverageSpeedKmh,
    String? currency,
    bool? isActive,
    bool? isFallback,
  }) {
    return RideFareRule(
      vehicleType: vehicleType ?? this.vehicleType,
      baseFare: baseFare ?? this.baseFare,
      perKm: perKm ?? this.perKm,
      minimumFare: minimumFare ?? this.minimumFare,
      fallbackAverageSpeedKmh:
          fallbackAverageSpeedKmh ?? this.fallbackAverageSpeedKmh,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  Map<String, dynamic> toFirestore({String? updatedByUid}) {
    return <String, dynamic>{
      'vehicleType': vehicleType,
      'baseFare': baseFare,
      'perKm': perKm,
      'minimumFare': minimumFare,
      'fallbackAverageSpeedKmh': fallbackAverageSpeedKmh,
      'currency': currency,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedByUid != null && updatedByUid.trim().isNotEmpty)
        'updatedByUid': updatedByUid.trim(),
    };
  }
}

class RideFareService {
  RideFareService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ride_fare_settings');

  static const List<RideFareRule> defaultRules = <RideFareRule>[
    RideFareRule(
      vehicleType: 'Bike',
      baseFare: 40,
      perKm: 18,
      minimumFare: 80,
      fallbackAverageSpeedKmh: 30,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Auto',
      baseFare: 60,
      perKm: 25,
      minimumFare: 120,
      fallbackAverageSpeedKmh: 28,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Taxi',
      baseFare: 100,
      perKm: 35,
      minimumFare: 180,
      fallbackAverageSpeedKmh: 32,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Car',
      baseFare: 120,
      perKm: 40,
      minimumFare: 220,
      fallbackAverageSpeedKmh: 34,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Jeep / SUV',
      baseFare: 180,
      perKm: 55,
      minimumFare: 300,
      fallbackAverageSpeedKmh: 34,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Van / Hiace',
      baseFare: 250,
      perKm: 70,
      minimumFare: 450,
      fallbackAverageSpeedKmh: 32,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Microbus',
      baseFare: 350,
      perKm: 90,
      minimumFare: 650,
      fallbackAverageSpeedKmh: 30,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Mini Bus',
      baseFare: 500,
      perKm: 120,
      minimumFare: 900,
      fallbackAverageSpeedKmh: 28,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Bus',
      baseFare: 700,
      perKm: 150,
      minimumFare: 1200,
      fallbackAverageSpeedKmh: 27,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Ambulance',
      baseFare: 300,
      perKm: 75,
      minimumFare: 500,
      fallbackAverageSpeedKmh: 38,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Pickup',
      baseFare: 350,
      perKm: 85,
      minimumFare: 600,
      fallbackAverageSpeedKmh: 30,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
    RideFareRule(
      vehicleType: 'Truck',
      baseFare: 600,
      perKm: 140,
      minimumFare: 1000,
      fallbackAverageSpeedKmh: 26,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    ),
  ];

  static String documentIdFor(String vehicleType) {
    final String normalized = vehicleType
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'ride' : normalized;
  }

  static RideFareRule defaultRuleFor(String vehicleType) {
    final String clean = vehicleType.trim().toLowerCase();
    for (final RideFareRule rule in defaultRules) {
      if (rule.vehicleType.toLowerCase() == clean) {
        return rule;
      }
    }
    return const RideFareRule(
      vehicleType: 'Ride',
      baseFare: 120,
      perKm: 40,
      minimumFare: 220,
      fallbackAverageSpeedKmh: 30,
      currency: 'Rs.',
      isActive: true,
      isFallback: true,
    );
  }

  RideFareRule _fromSnapshot(
    String requestedVehicleType,
    Map<String, dynamic> data,
  ) {
    final RideFareRule fallback = defaultRuleFor(requestedVehicleType);

    double number(String key, double fallbackValue) {
      final dynamic value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString().trim() ?? '') ?? fallbackValue;
    }

    final String vehicleType =
        data['vehicleType']?.toString().trim().isNotEmpty == true
            ? data['vehicleType'].toString().trim()
            : fallback.vehicleType;
    final String currency =
        data['currency']?.toString().trim().isNotEmpty == true
            ? data['currency'].toString().trim()
            : fallback.currency;

    final double baseFare = number('baseFare', fallback.baseFare);
    final double perKm = number('perKm', fallback.perKm);
    final double minimumFare = number('minimumFare', fallback.minimumFare);
    final double speed = number(
      'fallbackAverageSpeedKmh',
      fallback.fallbackAverageSpeedKmh,
    );

    return RideFareRule(
      vehicleType: vehicleType,
      baseFare: baseFare > 0 ? baseFare : fallback.baseFare,
      perKm: perKm > 0 ? perKm : fallback.perKm,
      minimumFare: minimumFare > 0 ? minimumFare : fallback.minimumFare,
      fallbackAverageSpeedKmh:
          speed > 0 ? speed : fallback.fallbackAverageSpeedKmh,
      currency: currency,
      isActive: data['isActive'] is bool
          ? data['isActive'] as bool
          : fallback.isActive,
      isFallback: false,
    );
  }

  Future<RideFareRule> loadFareRule(String vehicleType) async {
    final RideFareRule fallback = defaultRuleFor(vehicleType);
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _collection.doc(documentIdFor(vehicleType)).get();
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return fallback;
      }
      return _fromSnapshot(vehicleType, data);
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RideFareRule>> loadAllFareRules() async {
    return Future.wait<RideFareRule>(
      defaultRules.map(
        (RideFareRule rule) => loadFareRule(rule.vehicleType),
      ),
    );
  }

  Future<void> ensureDefaults({String? updatedByUid}) async {
    final List<DocumentReference<Map<String, dynamic>>> refs = defaultRules
        .map(
          (RideFareRule rule) =>
              _collection.doc(documentIdFor(rule.vehicleType)),
        )
        .toList(growable: false);

    final List<DocumentSnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
      refs.map(
        (DocumentReference<Map<String, dynamic>> ref) => ref.get(),
      ),
    );

    final WriteBatch batch = _firestore.batch();
    int pendingWrites = 0;

    for (int index = 0; index < defaultRules.length; index += 1) {
      if (!snapshots[index].exists) {
        batch.set(
          refs[index],
          defaultRules[index].toFirestore(updatedByUid: updatedByUid),
        );
        pendingWrites += 1;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }
  }

  Future<void> saveFareRule(
    RideFareRule rule, {
    String? updatedByUid,
  }) async {
    if (rule.baseFare <= 0 ||
        rule.perKm <= 0 ||
        rule.minimumFare <= 0 ||
        rule.fallbackAverageSpeedKmh <= 0 ||
        rule.currency.trim().isEmpty) {
      throw ArgumentError('Fare values must be greater than zero.');
    }

    await _collection.doc(documentIdFor(rule.vehicleType)).set(
          rule.copyWith(isFallback: false).toFirestore(
                updatedByUid: updatedByUid,
              ),
          SetOptions(merge: true),
        );
  }
}
