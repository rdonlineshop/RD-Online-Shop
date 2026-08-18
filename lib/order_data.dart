import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// ORDER HISTORY
// ============================================================

List<Map<String, dynamic>> orderHistory =
    <Map<String, dynamic>>[];

// ============================================================
// CUSTOMER ID
// ============================================================

const String _customerIdPreferenceKey = 'rd_customer_id';

Future<String> getOrCreateCustomerId() async {
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  final String savedId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (savedId.isNotEmpty) {
    return savedId;
  }

  final Random random = Random.secure();

  final String randomPart =
      random.nextInt(1000000).toString().padLeft(6, '0');

  final String customerId =
      'RDC${DateTime.now().microsecondsSinceEpoch}$randomPart';

  await prefs.setString(
    _customerIdPreferenceKey,
    customerId,
  );

  return customerId;
}

Future<String?> getSavedCustomerId() async {
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  final String customerId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (customerId.isEmpty) {
    return null;
  }

  return customerId;
}

// ============================================================
// ORDER STATUS
// ============================================================

const List<String> orderStatuses = <String>[
  'Pending',
  'Confirmed',
  'Processing',
  'Shipped',
  'Delivered',
];

// ============================================================
// FIRESTORE
// ============================================================

CollectionReference<Map<String, dynamic>>
    get _ordersCollection =>
        FirebaseFirestore.instance.collection('orders');

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    _ordersSubscription;

bool _ordersListenerStarted = false;

// ============================================================
// SAFE FIRESTORE / JSON VALUE
// ============================================================

dynamic _safeValue(dynamic value) {
  if (value == null ||
      value is String ||
      value is num ||
      value is bool) {
    return value;
  }

  if (value is DateTime) {
    return value.toIso8601String();
  }

  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  }

  if (value is GeoPoint) {
    return <String, dynamic>{
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  }

  if (value is List) {
    return value.map(_safeValue).toList();
  }

  if (value is Map) {
    return value.map(
      (
        dynamic key,
        dynamic mapValue,
      ) {
        return MapEntry<String, dynamic>(
          key.toString(),
          _safeValue(mapValue),
        );
      },
    );
  }

  return value.toString();
}

Map<String, dynamic> _safeMap(
  Map<String, dynamic> data,
) {
  return data.map(
    (
      String key,
      dynamic value,
    ) {
      return MapEntry<String, dynamic>(
        key,
        _safeValue(value),
      );
    },
  );
}

// ============================================================
// TRACKING STATUS FROM ORDER STATUS
// ============================================================

String _trackingStatusForOrderStatus(
  String status,
) {
  switch (status) {
    case 'Pending':
      return 'Order Placed';

    case 'Confirmed':
      return 'Order Confirmed';

    case 'Processing':
      return 'Preparing Order';

    case 'Shipped':
      return 'Out for Delivery';

    case 'Delivered':
      return 'Delivered';

    default:
      return status;
  }
}

// ============================================================
// NORMALIZE ORDER
// ============================================================

Map<String, dynamic> _normalizeOrder(
  Map<String, dynamic> source,
) {
  final Map<String, dynamic> order =
      _safeMap(source);

  order['id'] =
      order['id']?.toString().trim() ?? '';

  order['customerId'] =
      order['customerId']?.toString().trim() ?? '';

  order['status'] =
      order['status']?.toString().trim() ?? 'Pending';

  if (order['status'].toString().isEmpty) {
    order['status'] = 'Pending';
  }

  order['trackingEnabled'] =
      order['trackingEnabled'] != false;

  final String existingTrackingStatus =
      order['trackingStatus']?.toString().trim() ?? '';

  order['trackingStatus'] =
      existingTrackingStatus.isNotEmpty
          ? existingTrackingStatus
          : _trackingStatusForOrderStatus(
              order['status'].toString(),
            );

  // ==========================================================
  // SELLER IDS
  // ==========================================================

  if (order['sellerIds'] is List) {
    order['sellerIds'] = List<String>.from(
      (order['sellerIds'] as List)
          .map(
            (dynamic value) => value.toString().trim(),
          )
          .where(
            (String value) => value.isNotEmpty,
          ),
    );
  } else {
    order['sellerIds'] = <String>[];
  }

  // ==========================================================
  // ITEMS
  // ==========================================================

  if (order['items'] is List) {
    order['items'] = (order['items'] as List)
        .whereType<Map>()
        .map(
          (Map item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  } else {
    order['items'] = <Map<String, dynamic>>[];
  }

  // ==========================================================
  // ORDER DATE
  // ==========================================================

  final String orderDate =
      order['orderDateTime']?.toString().trim() ?? '';

  if (orderDate.isEmpty) {
    order['orderDateTime'] =
        DateTime.now().toIso8601String();
  }

  return order;
}

// ============================================================
// SORT ORDERS
// NEWEST FIRST
// ============================================================

void _sortOrders() {
  orderHistory.sort(
    (
      Map<String, dynamic> first,
      Map<String, dynamic> second,
    ) {
      final DateTime? firstDate =
          DateTime.tryParse(
        first['orderDateTime']?.toString() ?? '',
      );

      final DateTime? secondDate =
          DateTime.tryParse(
        second['orderDateTime']?.toString() ?? '',
      );

      if (firstDate == null && secondDate == null) {
        return 0;
      }

      if (firstDate == null) {
        return 1;
      }

      if (secondDate == null) {
        return -1;
      }

      return secondDate.compareTo(firstDate);
    },
  );
}

// ============================================================
// LOAD ORDERS
// ============================================================

Future<void> loadOrders() async {
  await _loadLocalOrders();

  await _migrateLocalOrdersToFirestore();

  _startOrdersListener();
}

// ============================================================
// LOAD LOCAL BACKUP
// ============================================================

Future<void> _loadLocalOrders() async {
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  final String? savedOrders =
      prefs.getString('orderHistory');

  if (savedOrders == null || savedOrders.isEmpty) {
    orderHistory = <Map<String, dynamic>>[];
    return;
  }

  try {
    final dynamic decoded =
        jsonDecode(savedOrders);

    if (decoded is! List) {
      orderHistory = <Map<String, dynamic>>[];
      return;
    }

    orderHistory = decoded
        .whereType<Map>()
        .map(
          (Map item) => _normalizeOrder(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    _sortOrders();
  } catch (_) {
    orderHistory = <Map<String, dynamic>>[];
  }
}

// ============================================================
// SAVE LOCAL BACKUP
// ============================================================

Future<void> saveOrders() async {
  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  final List<Map<String, dynamic>> safeOrders =
      orderHistory
          .map(
            (Map<String, dynamic> order) =>
                _safeMap(order),
          )
          .toList();

  await prefs.setString(
    'orderHistory',
    jsonEncode(safeOrders),
  );
}

// ============================================================
// MIGRATE LOCAL ORDERS TO FIRESTORE
// ============================================================

Future<void> _migrateLocalOrdersToFirestore() async {
  if (orderHistory.isEmpty) {
    return;
  }

  for (final Map<String, dynamic> order
      in orderHistory) {
    final String orderId =
        order['id']?.toString().trim() ?? '';

    if (orderId.isEmpty) {
      continue;
    }

    final Map<String, dynamic> uploadData =
        _safeMap(order);

    // Old orders did not have customerId.
    // Do not overwrite a valid Firestore customerId
    // with an empty value.
    final String customerId =
        uploadData['customerId']?.toString().trim() ?? '';

    if (customerId.isEmpty) {
      uploadData.remove('customerId');
    }

    try {
      await _ordersCollection
          .doc(orderId)
          .set(
        uploadData,
        SetOptions(
          merge: true,
        ),
      );
    } catch (_) {
      // Local backup remains available.
    }
  }
}

// ============================================================
// FIRESTORE REALTIME LISTENER
// ============================================================

void _startOrdersListener() {
  if (_ordersListenerStarted) {
    return;
  }

  _ordersListenerStarted = true;

  _ordersSubscription =
      _ordersCollection.snapshots().listen(
    (
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final List<Map<String, dynamic>> cloudOrders =
          snapshot.docs.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
        ) {
          return _normalizeOrder(
            <String, dynamic>{
              ...document.data(),
              'id': document.id,
            },
          );
        },
      ).toList();

      orderHistory = cloudOrders;

      _sortOrders();

      await saveOrders();
    },
    onError: (Object error) {
      // Keep local backup if Firestore is unavailable.
    },
  );
}

// ============================================================
// ADD ORDER
// ============================================================

Future<void> addOrder(
  Map<String, dynamic> newOrder,
) async {
  final Map<String, dynamic> order =
      _normalizeOrder(
    Map<String, dynamic>.from(newOrder),
  );

  final String orderId =
      order['id']?.toString().trim() ?? '';

  if (orderId.isEmpty) {
    return;
  }

  // ==========================================================
  // CUSTOMER ID
  // ==========================================================

  String customerId =
      order['customerId']?.toString().trim() ?? '';

  if (customerId.isEmpty) {
    customerId = await getOrCreateCustomerId();

    order['customerId'] = customerId;
  }

  // ==========================================================
  // DEFAULT STATUS
  // ==========================================================

  final String currentStatus =
      order['status']?.toString().trim() ?? '';

  if (currentStatus.isEmpty) {
    order['status'] = 'Pending';
  }

  final String orderDate =
      order['orderDateTime']?.toString().trim() ?? '';

  if (orderDate.isEmpty) {
    order['orderDateTime'] =
        DateTime.now().toIso8601String();
  }

  final String address =
      order['address']?.toString().trim() ?? '';

  if (address.isEmpty) {
    order['address'] =
        'Address not available';
  }

  order['trackingEnabled'] =
      order['trackingEnabled'] != false;

  final String trackingStatus =
      order['trackingStatus']?.toString().trim() ?? '';

  if (trackingStatus.isEmpty) {
    order['trackingStatus'] =
        'Order Placed';
  }

  order['createdAt'] ??=
      DateTime.now().toIso8601String();

  order['updatedAt'] =
      DateTime.now().toIso8601String();

  // ==========================================================
  // LOCAL UPDATE
  // ==========================================================

  final int existingIndex =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> oldOrder,
    ) {
      return oldOrder['id']?.toString() ==
          orderId;
    },
  );

  if (existingIndex >= 0) {
    orderHistory[existingIndex] = order;
  } else {
    orderHistory.insert(
      0,
      order,
    );
  }

  _sortOrders();

  await saveOrders();

  // ==========================================================
  // FIRESTORE UPDATE
  // ==========================================================

  try {
    await _ordersCollection
        .doc(orderId)
        .set(
      _safeMap(order),
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Order already exists in local backup.
  }
}

// ============================================================
// UPDATE ORDER STATUS
// SELLER / ADMIN
// ============================================================

Future<void> updateOrderStatus(
  String orderId,
  String newStatus,
) async {
  final String cleanOrderId =
      orderId.trim();

  final String cleanStatus =
      newStatus.trim();

  if (cleanOrderId.isEmpty) {
    return;
  }

  if (!orderStatuses.contains(cleanStatus)) {
    return;
  }

  final String trackingStatus =
      _trackingStatusForOrderStatus(
    cleanStatus,
  );

  final String now =
      DateTime.now().toIso8601String();

  final int index =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> order,
    ) {
      return order['id']?.toString() ==
          cleanOrderId;
    },
  );

  if (index >= 0) {
    orderHistory[index]['status'] =
        cleanStatus;

    orderHistory[index]['trackingStatus'] =
        trackingStatus;

    orderHistory[index]['updatedAt'] =
        now;

    if (cleanStatus == 'Shipped') {
      final dynamic startedAt =
          orderHistory[index]['deliveryStartedAt'];

      if (startedAt == null ||
          startedAt.toString().trim().isEmpty) {
        orderHistory[index]['deliveryStartedAt'] =
            now;
      }
    }

    if (cleanStatus == 'Delivered') {
      orderHistory[index]['deliveredAt'] =
          now;
    }

    await saveOrders();
  }

  final Map<String, dynamic> update =
      <String, dynamic>{
    'status': cleanStatus,
    'trackingStatus': trackingStatus,
    'updatedAt': now,
  };

  if (cleanStatus == 'Shipped') {
    update['deliveryStartedAt'] = now;
  }

  if (cleanStatus == 'Delivered') {
    update['deliveredAt'] = now;
  }

  try {
    await _ordersCollection
        .doc(cleanOrderId)
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Local status remains saved.
  }
}

// ============================================================
// UPDATE TRACKING STATUS
// ============================================================

Future<void> updateTrackingStatus(
  String orderId,
  String trackingStatus,
) async {
  final String cleanOrderId =
      orderId.trim();

  final String cleanTrackingStatus =
      trackingStatus.trim();

  if (cleanOrderId.isEmpty ||
      cleanTrackingStatus.isEmpty) {
    return;
  }

  final String now =
      DateTime.now().toIso8601String();

  final int index =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> order,
    ) {
      return order['id']?.toString() ==
          cleanOrderId;
    },
  );

  if (index >= 0) {
    orderHistory[index]['trackingStatus'] =
        cleanTrackingStatus;

    orderHistory[index]['updatedAt'] =
        now;

    await saveOrders();
  }

  try {
    await _ordersCollection
        .doc(cleanOrderId)
        .set(
      <String, dynamic>{
        'trackingStatus':
            cleanTrackingStatus,
        'updatedAt': now,
      },
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Keep local tracking data.
  }
}

// ============================================================
// DELIVERY PERSON LIVE LOCATION
// ============================================================

Future<void> updateDriverLocation({
  required String orderId,
  required double latitude,
  required double longitude,
  String? driverId,
  String? driverName,
  String? driverPhone,
}) async {
  final String cleanOrderId =
      orderId.trim();

  if (cleanOrderId.isEmpty) {
    return;
  }

  final String now =
      DateTime.now().toIso8601String();

  final Map<String, dynamic> update =
      <String, dynamic>{
    'driverLat': latitude,
    'driverLng': longitude,
    'driverLocationUpdatedAt': now,
    'trackingEnabled': true,
    'updatedAt': now,
  };

  if (driverId != null &&
      driverId.trim().isNotEmpty) {
    update['driverId'] =
        driverId.trim();
  }

  if (driverName != null &&
      driverName.trim().isNotEmpty) {
    update['driverName'] =
        driverName.trim();
  }

  if (driverPhone != null &&
      driverPhone.trim().isNotEmpty) {
    update['driverPhone'] =
        driverPhone.trim();
  }

  final int index =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> order,
    ) {
      return order['id']?.toString() ==
          cleanOrderId;
    },
  );

  if (index >= 0) {
    orderHistory[index].addAll(update);

    await saveOrders();
  }

  try {
    await _ordersCollection
        .doc(cleanOrderId)
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Local location remains saved.
  }
}

// ============================================================
// CUSTOMER LOCATION UPDATE
// ============================================================

Future<void> updateCustomerLocation({
  required String orderId,
  required double latitude,
  required double longitude,
  String? address,
}) async {
  final String cleanOrderId =
      orderId.trim();

  if (cleanOrderId.isEmpty) {
    return;
  }

  final String now =
      DateTime.now().toIso8601String();

  final Map<String, dynamic> update =
      <String, dynamic>{
    'customerLat': latitude,
    'customerLng': longitude,
    'customerLocationUpdatedAt': now,
    'updatedAt': now,
  };

  if (address != null &&
      address.trim().isNotEmpty) {
    update['customerAddress'] =
        address.trim();

    update['address'] =
        address.trim();
  }

  final int index =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> order,
    ) {
      return order['id']?.toString() ==
          cleanOrderId;
    },
  );

  if (index >= 0) {
    orderHistory[index].addAll(update);

    await saveOrders();
  }

  try {
    await _ordersCollection
        .doc(cleanOrderId)
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Local location remains saved.
  }
}

// ============================================================
// GENERIC TRACKING UPDATE
// ============================================================

Future<void> updateOrderTrackingFields(
  String orderId,
  Map<String, dynamic> fields,
) async {
  final String cleanOrderId =
      orderId.trim();

  if (cleanOrderId.isEmpty ||
      fields.isEmpty) {
    return;
  }

  final Map<String, dynamic> update =
      _safeMap(
    <String, dynamic>{
      ...fields,
      'updatedAt':
          DateTime.now().toIso8601String(),
    },
  );

  final int index =
      orderHistory.indexWhere(
    (
      Map<String, dynamic> order,
    ) {
      return order['id']?.toString() ==
          cleanOrderId;
    },
  );

  if (index >= 0) {
    orderHistory[index].addAll(update);

    await saveOrders();
  }

  try {
    await _ordersCollection
        .doc(cleanOrderId)
        .set(
      update,
      SetOptions(
        merge: true,
      ),
    );
  } catch (_) {
    // Keep local backup.
  }
}

// ============================================================
// ONE ORDER REALTIME STREAM
// TRACK ORDER PAGE
// ============================================================

Stream<Map<String, dynamic>?> orderStream(
  String orderId,
) {
  final String cleanOrderId =
      orderId.trim();

  if (cleanOrderId.isEmpty) {
    return Stream<Map<String, dynamic>?>.value(
      null,
    );
  }

  return _ordersCollection
      .doc(cleanOrderId)
      .snapshots()
      .map(
    (
      DocumentSnapshot<Map<String, dynamic>>
          snapshot,
    ) {
      if (!snapshot.exists ||
          snapshot.data() == null) {
        return null;
      }

      return _normalizeOrder(
        <String, dynamic>{
          ...snapshot.data()!,
          'id': snapshot.id,
        },
      );
    },
  );
}

// ============================================================
// CUSTOMER OWN ORDERS STREAM
// IMPORTANT:
// Customer sees ONLY their own orders.
// ============================================================

Stream<List<Map<String, dynamic>>>
    customerOrdersStream(
  String customerId,
) {
  final String cleanCustomerId =
      customerId.trim();

  if (cleanCustomerId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[],
    );
  }

  return _ordersCollection
      .where(
        'customerId',
        isEqualTo: cleanCustomerId,
      )
      .snapshots()
      .map(
    (
      QuerySnapshot<Map<String, dynamic>>
          snapshot,
    ) {
      final List<Map<String, dynamic>> orders =
          snapshot.docs.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
        ) {
          return _normalizeOrder(
            <String, dynamic>{
              ...document.data(),
              'id': document.id,
            },
          );
        },
      ).toList();

      orders.sort(
        (
          Map<String, dynamic> first,
          Map<String, dynamic> second,
        ) {
          final DateTime? firstDate =
              DateTime.tryParse(
            first['orderDateTime']
                    ?.toString() ??
                '',
          );

          final DateTime? secondDate =
              DateTime.tryParse(
            second['orderDateTime']
                    ?.toString() ??
                '',
          );

          if (firstDate == null &&
              secondDate == null) {
            return 0;
          }

          if (firstDate == null) {
            return 1;
          }

          if (secondDate == null) {
            return -1;
          }

          return secondDate.compareTo(
            firstDate,
          );
        },
      );

      return orders;
    },
  );
}

// ============================================================
// SELLER OWN ORDERS STREAM
// IMPORTANT:
// Seller sees ONLY orders containing their sellerId.
// ============================================================

Stream<List<Map<String, dynamic>>>
    sellerOrdersStream(
  String sellerId,
) {
  final String cleanSellerId =
      sellerId.trim();

  if (cleanSellerId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[],
    );
  }

  return _ordersCollection
      .where(
        'sellerIds',
        arrayContains: cleanSellerId,
      )
      .snapshots()
      .map(
    (
      QuerySnapshot<Map<String, dynamic>>
          snapshot,
    ) {
      final List<Map<String, dynamic>> orders =
          snapshot.docs.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
        ) {
          return _normalizeOrder(
            <String, dynamic>{
              ...document.data(),
              'id': document.id,
            },
          );
        },
      ).toList();

      orders.sort(
        (
          Map<String, dynamic> first,
          Map<String, dynamic> second,
        ) {
          final DateTime? firstDate =
              DateTime.tryParse(
            first['orderDateTime']
                    ?.toString() ??
                '',
          );

          final DateTime? secondDate =
              DateTime.tryParse(
            second['orderDateTime']
                    ?.toString() ??
                '',
          );

          if (firstDate == null &&
              secondDate == null) {
            return 0;
          }

          if (firstDate == null) {
            return 1;
          }

          if (secondDate == null) {
            return -1;
          }

          return secondDate.compareTo(
            firstDate,
          );
        },
      );

      return orders;
    },
  );
}

// ============================================================
// DISPOSE FIRESTORE LISTENER
// ============================================================

Future<void> disposeOrderListener() async {
  await _ordersSubscription?.cancel();

  _ordersSubscription = null;

  _ordersListenerStarted = false;
}