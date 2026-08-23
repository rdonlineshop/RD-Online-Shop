import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> orderHistory = <Map<String, dynamic>>[];

const String _customerIdPreferenceKey = 'rd_customer_id';

String _orderHistoryKey(String customerId) => 'orderHistory_$customerId';

CollectionReference<Map<String, dynamic>> get _ordersCollection =>
    FirebaseFirestore.instance.collection('orders');

CollectionReference<Map<String, dynamic>> get _customersCollection =>
    FirebaseFirestore.instance.collection('customers');

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;
bool _ordersListenerStarted = false;
String _ordersListenerCustomerId = '';

const List<String> orderStatuses = <String>[
  'Pending',
  'Confirmed',
  'Processing',
  'Shipped',
  'Delivered',
];

String normalizeOrderRecoveryPhone(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

Future<void> _ensureCustomerSessionDocument(String customerId) async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null || !user.isAnonymous || customerId.trim().isEmpty) {
    return;
  }

  await _customersCollection.doc(user.uid).set(
    <String, dynamic>{
      'authUid': user.uid,
      'customerId': customerId.trim(),
      'role': 'customer',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}

Future<String> getOrCreateCustomerId() async {
  // IMPORTANT: Never sign out an active Admin/Seller/Delivery account here.
  // The previous version forced every non-anonymous account to sign out, which
  // caused Admin Order Management to flash the orders and then immediately lose
  // Firestore permission when a customer helper finished in the background.
  User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    final UserCredential credential =
        await FirebaseAuth.instance.signInAnonymously();
    user = credential.user;
  }

  if (user == null) {
    throw StateError('Could not start customer session.');
  }

  if (!user.isAnonymous) {
    // Customer action requested while a staff account is active. Switch only
    // at this explicit customer action point; background listeners never do it.
    await FirebaseAuth.instance.signOut();
    final UserCredential credential =
        await FirebaseAuth.instance.signInAnonymously();
    user = credential.user;

    if (user == null) {
      throw StateError('Could not start customer session.');
    }
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // IMPORTANT: Always prefer the already-saved customer ID.
  // Seller/driver login signs the anonymous customer out and later creates a
  // new anonymous Firebase UID. Keeping this saved ID stable prevents
  // "My Orders" from disappearing after role login/logout.
  final String savedId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (savedId.isNotEmpty) {
    await _ensureCustomerSessionDocument(savedId);
    return savedId;
  }

  String customerId;
  if (user.isAnonymous) {
    // First-time customer: using the first anonymous UID keeps old data
    // compatible while the value remains stable in SharedPreferences.
    customerId = user.uid;
  } else {
    final Random random = Random.secure();
    final String randomPart =
        random.nextInt(1000000).toString().padLeft(6, '0');
    customerId =
        'RDC${DateTime.now().microsecondsSinceEpoch}$randomPart';
  }

  await prefs.setString(_customerIdPreferenceKey, customerId);
  await _ensureCustomerSessionDocument(customerId);
  return customerId;
}

Future<String?> getSavedCustomerId() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String savedId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (savedId.isNotEmpty) {
    return savedId;
  }

  final User? user = FirebaseAuth.instance.currentUser;
  if (user != null && user.isAnonymous) {
    return user.uid;
  }

  return null;
}

dynamic _safeValue(dynamic value) {
  if (value == null || value is String || value is num || value is bool) {
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
    return value.map<dynamic>(_safeValue).toList();
  }

  if (value is Map) {
    return value.map<String, dynamic>(
      (dynamic key, dynamic mapValue) => MapEntry<String, dynamic>(
        key.toString(),
        _safeValue(mapValue),
      ),
    );
  }

  return value.toString();
}

Map<String, dynamic> _safeMap(Map<String, dynamic> data) {
  return data.map<String, dynamic>(
    (String key, dynamic value) =>
        MapEntry<String, dynamic>(key, _safeValue(value)),
  );
}

String _trackingStatusForOrderStatus(String status) {
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

Map<String, dynamic> _normalizeOrder(Map<String, dynamic> source) {
  final Map<String, dynamic> order = _safeMap(source);

  order['id'] = order['id']?.toString().trim() ?? '';
  order['customerId'] = order['customerId']?.toString().trim() ?? '';

  String status = order['status']?.toString().trim() ?? '';
  if (status.isEmpty) {
    status = 'Pending';
  }
  order['status'] = status;

  order['trackingEnabled'] = order['trackingEnabled'] != false;

  final String existingTrackingStatus =
      order['trackingStatus']?.toString().trim() ?? '';
  order['trackingStatus'] = existingTrackingStatus.isNotEmpty
      ? existingTrackingStatus
      : _trackingStatusForOrderStatus(status);

  final dynamic rawSellerIds = order['sellerIds'];
  if (rawSellerIds is List) {
    order['sellerIds'] = rawSellerIds
        .map<String>((dynamic value) => value?.toString().trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList();
  } else {
    order['sellerIds'] = <String>[];
  }

  final dynamic rawItems = order['items'];
  if (rawItems is List) {
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

    for (final dynamic rawItem in rawItems) {
      if (rawItem is Map) {
        final Map<String, dynamic> item = <String, dynamic>{};
        rawItem.forEach((dynamic key, dynamic value) {
          item[key.toString()] = _safeValue(value);
        });
        items.add(item);
      }
    }

    order['items'] = items;
  } else {
    order['items'] = <Map<String, dynamic>>[];
  }

  final String orderDate = order['orderDateTime']?.toString().trim() ?? '';
  if (orderDate.isEmpty) {
    order['orderDateTime'] = DateTime.now().toIso8601String();
  }

  return order;
}

int _orderSort(Map<String, dynamic> first, Map<String, dynamic> second) {
  final DateTime? firstDate =
      DateTime.tryParse(first['orderDateTime']?.toString() ?? '');
  final DateTime? secondDate =
      DateTime.tryParse(second['orderDateTime']?.toString() ?? '');

  if (firstDate == null && secondDate == null) return 0;
  if (firstDate == null) return 1;
  if (secondDate == null) return -1;
  return secondDate.compareTo(firstDate);
}

void _sortOrders() {
  orderHistory.sort(_orderSort);
}

Future<void> loadOrders() async {
  await _loadLocalOrders();
  await _migrateLocalOrdersToFirestore();
  await _startOrdersListener();
}

Future<void> _loadLocalOrders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? customerId = await getSavedCustomerId();

  if (customerId == null || customerId.isEmpty) {
    orderHistory = <Map<String, dynamic>>[];
    return;
  }

  final String? savedOrders = prefs.getString(_orderHistoryKey(customerId)) ??
      prefs.getString('orderHistory');

  if (savedOrders == null || savedOrders.trim().isEmpty) {
    orderHistory = <Map<String, dynamic>>[];
    return;
  }

  try {
    final dynamic decoded = jsonDecode(savedOrders);
    if (decoded is! List) {
      orderHistory = <Map<String, dynamic>>[];
      return;
    }

    final List<Map<String, dynamic>> loadedOrders = <Map<String, dynamic>>[];

    for (final dynamic rawOrder in decoded) {
      if (rawOrder is Map) {
        final Map<String, dynamic> order = <String, dynamic>{};
        rawOrder.forEach((dynamic key, dynamic value) {
          order[key.toString()] = value;
        });

        final Map<String, dynamic> normalized = _normalizeOrder(order);
        if (normalized['customerId']?.toString().trim() == customerId) {
          loadedOrders.add(normalized);
        }
      }
    }

    orderHistory = loadedOrders;
    _sortOrders();
  } catch (_) {
    orderHistory = <Map<String, dynamic>>[];
  }
}

Future<void> saveOrders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? customerId = await getSavedCustomerId();

  if (customerId == null || customerId.isEmpty) {
    return;
  }

  final List<Map<String, dynamic>> safeOrders = orderHistory
      .where(
        (Map<String, dynamic> order) =>
            order['customerId']?.toString().trim() == customerId,
      )
      .map<Map<String, dynamic>>(_safeMap)
      .toList();

  final String encoded = jsonEncode(safeOrders);

  await prefs.setString(_orderHistoryKey(customerId), encoded);

  // Keep a generic device backup too. This helps migration from older builds.
  await prefs.setString('orderHistory', encoded);
}

Future<void> _migrateLocalOrdersToFirestore() async {
  if (orderHistory.isEmpty) {
    return;
  }

  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null || !user.isAnonymous) {
    return;
  }

  final String customerId = await getOrCreateCustomerId();

  for (final Map<String, dynamic> order in orderHistory) {
    final String orderId = order['id']?.toString().trim() ?? '';
    if (orderId.isEmpty) continue;

    final Map<String, dynamic> uploadData = _safeMap(order);
    if (uploadData['customerId']?.toString().trim() != customerId) {
      continue;
    }

    try {
      await _ordersCollection.doc(orderId).set(
            uploadData,
            SetOptions(merge: true),
          );
    } catch (_) {
      // Local backup remains available.
    }
  }
}

Future<void> _startOrdersListener() async {
  final User? user = FirebaseAuth.instance.currentUser;

  // Customer realtime listener should only run in the anonymous customer
  // session. Seller/driver/admin pages use their own streams.
  if (user == null || !user.isAnonymous) {
    return;
  }

  final String customerId = await getOrCreateCustomerId();

  if (_ordersListenerStarted && _ordersListenerCustomerId == customerId) {
    return;
  }

  await _ordersSubscription?.cancel();
  _ordersSubscription = null;
  _ordersListenerStarted = true;
  _ordersListenerCustomerId = customerId;

  _ordersSubscription = _ordersCollection
      .where('customerId', isEqualTo: customerId)
      .snapshots()
      .listen(
    (QuerySnapshot<Map<String, dynamic>> snapshot) async {
      final List<Map<String, dynamic>> cloudOrders = snapshot.docs
          .map<Map<String, dynamic>>(
            (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                _normalizeOrder(<String, dynamic>{
              ...document.data(),
              'id': document.id,
            }),
          )
          .toList();

      orderHistory = cloudOrders;
      _sortOrders();
      await saveOrders();
    },
    onError: (Object error) {
      // Keep local backup visible if Firestore is temporarily unavailable.
    },
  );
}

Future<void> reloadOrdersForCurrentCustomer() async {
  await _ordersSubscription?.cancel();
  _ordersSubscription = null;
  _ordersListenerStarted = false;
  _ordersListenerCustomerId = '';
  orderHistory = <Map<String, dynamic>>[];
  await loadOrders();
}

Future<void> addOrder(Map<String, dynamic> newOrder) async {
  final Map<String, dynamic> order =
      _normalizeOrder(Map<String, dynamic>.from(newOrder));

  final String orderId = order['id']?.toString().trim() ?? '';
  if (orderId.isEmpty) {
    throw ArgumentError('Order ID cannot be empty.');
  }

  String customerId = order['customerId']?.toString().trim() ?? '';
  if (customerId.isEmpty) {
    customerId = await getOrCreateCustomerId();
    order['customerId'] = customerId;
  } else {
    await _ensureCustomerSessionDocument(customerId);
  }

  String currentStatus = order['status']?.toString().trim() ?? '';
  if (currentStatus.isEmpty) {
    currentStatus = 'Pending';
    order['status'] = currentStatus;
  }

  if ((order['orderDateTime']?.toString().trim() ?? '').isEmpty) {
    order['orderDateTime'] = DateTime.now().toIso8601String();
  }

  if ((order['address']?.toString().trim() ?? '').isEmpty) {
    order['address'] = 'Address not available';
  }

  order['trackingEnabled'] = order['trackingEnabled'] != false;

  if ((order['trackingStatus']?.toString().trim() ?? '').isEmpty) {
    order['trackingStatus'] = _trackingStatusForOrderStatus(currentStatus);
  }

  final String now = DateTime.now().toIso8601String();
  order['createdAt'] ??= now;
  order['updatedAt'] = now;

  final String recoveryPhoneKey =
      normalizeOrderRecoveryPhone(order['phone']?.toString() ?? '');
  if (recoveryPhoneKey.isNotEmpty) {
    order['recoveryPhoneKey'] = recoveryPhoneKey;
  }

  final int existingIndex = orderHistory.indexWhere(
    (Map<String, dynamic> oldOrder) =>
        oldOrder['id']?.toString() == orderId,
  );

  if (existingIndex >= 0) {
    orderHistory[existingIndex] = order;
  } else {
    orderHistory.insert(0, order);
  }

  _sortOrders();
  await saveOrders();

  await _ordersCollection.doc(orderId).set(
        _safeMap(order),
        SetOptions(merge: true),
      );
}

Future<void> updateOrderStatus(String orderId, String newStatus) async {
  final String cleanOrderId = orderId.trim();
  final String cleanStatus = newStatus.trim();

  if (cleanOrderId.isEmpty || !orderStatuses.contains(cleanStatus)) {
    return;
  }

  final String trackingStatus = _trackingStatusForOrderStatus(cleanStatus);
  final String now = DateTime.now().toIso8601String();

  final Map<String, dynamic> update = <String, dynamic>{
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

  await _ordersCollection.doc(cleanOrderId).set(
        update,
        SetOptions(merge: true),
      );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) => order['id']?.toString() == cleanOrderId,
  );

  if (index >= 0) {
    orderHistory[index].addAll(update);
    await saveOrders();
  }
}

Future<void> updateTrackingStatus(
  String orderId,
  String trackingStatus,
) async {
  final String cleanOrderId = orderId.trim();
  final String cleanTrackingStatus = trackingStatus.trim();

  if (cleanOrderId.isEmpty || cleanTrackingStatus.isEmpty) return;

  final Map<String, dynamic> update = <String, dynamic>{
    'trackingStatus': cleanTrackingStatus,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  await _ordersCollection.doc(cleanOrderId).set(
        update,
        SetOptions(merge: true),
      );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) => order['id']?.toString() == cleanOrderId,
  );
  if (index >= 0) {
    orderHistory[index].addAll(update);
    await saveOrders();
  }
}

Future<void> updateDriverLocation({
  required String orderId,
  required double latitude,
  required double longitude,
  String? driverId,
  String? driverName,
  String? driverPhone,
}) async {
  final String cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty) return;

  final String now = DateTime.now().toIso8601String();
  final Map<String, dynamic> update = <String, dynamic>{
    'driverLat': latitude,
    'driverLng': longitude,
    'driverLocationUpdatedAt': now,
    'trackingEnabled': true,
    'updatedAt': now,
  };

  if (driverId != null && driverId.trim().isNotEmpty) {
    update['driverId'] = driverId.trim();
  }
  if (driverName != null && driverName.trim().isNotEmpty) {
    update['driverName'] = driverName.trim();
  }
  if (driverPhone != null && driverPhone.trim().isNotEmpty) {
    update['driverPhone'] = driverPhone.trim();
  }

  await _ordersCollection.doc(cleanOrderId).set(
        update,
        SetOptions(merge: true),
      );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) => order['id']?.toString() == cleanOrderId,
  );
  if (index >= 0) {
    orderHistory[index].addAll(update);
    await saveOrders();
  }
}

Future<void> updateCustomerLocation({
  required String orderId,
  required double latitude,
  required double longitude,
  String? address,
}) async {
  final String cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty) return;

  final String now = DateTime.now().toIso8601String();
  final Map<String, dynamic> update = <String, dynamic>{
    'customerLat': latitude,
    'customerLng': longitude,
    'customerLocationUpdatedAt': now,
    'updatedAt': now,
  };

  if (address != null && address.trim().isNotEmpty) {
    update['customerAddress'] = address.trim();
    update['address'] = address.trim();
  }

  await _ordersCollection.doc(cleanOrderId).set(
        update,
        SetOptions(merge: true),
      );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) => order['id']?.toString() == cleanOrderId,
  );
  if (index >= 0) {
    orderHistory[index].addAll(update);
    await saveOrders();
  }
}

Future<void> updateOrderTrackingFields(
  String orderId,
  Map<String, dynamic> fields,
) async {
  final String cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty || fields.isEmpty) return;

  final Map<String, dynamic> update = _safeMap(<String, dynamic>{
    ...fields,
    'updatedAt': DateTime.now().toIso8601String(),
  });

  await _ordersCollection.doc(cleanOrderId).set(
        update,
        SetOptions(merge: true),
      );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) => order['id']?.toString() == cleanOrderId,
  );
  if (index >= 0) {
    orderHistory[index].addAll(update);
    await saveOrders();
  }
}

Stream<Map<String, dynamic>?> orderStream(String orderId) {
  final String cleanOrderId = orderId.trim();
  if (cleanOrderId.isEmpty) {
    return Stream<Map<String, dynamic>?>.value(null);
  }

  return _ordersCollection.doc(cleanOrderId).snapshots().map(
    (DocumentSnapshot<Map<String, dynamic>> snapshot) {
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return _normalizeOrder(<String, dynamic>{
        ...data,
        'id': snapshot.id,
      });
    },
  );
}

Stream<List<Map<String, dynamic>>> customerOrdersStream(String customerId) {
  final String cleanCustomerId = customerId.trim();
  if (cleanCustomerId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[],
    );
  }

  return _ordersCollection
      .where('customerId', isEqualTo: cleanCustomerId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<Map<String, dynamic>> orders = snapshot.docs
        .map<Map<String, dynamic>>(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              _normalizeOrder(<String, dynamic>{
            ...document.data(),
            'id': document.id,
          }),
        )
        .toList();
    orders.sort(_orderSort);
    return orders;
  });
}

Stream<List<Map<String, dynamic>>> sellerOrdersStream(String sellerId) {
  final String cleanSellerId = sellerId.trim();
  if (cleanSellerId.isEmpty) {
    return Stream<List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[],
    );
  }

  return _ordersCollection
      .where('sellerIds', arrayContains: cleanSellerId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<Map<String, dynamic>> orders = snapshot.docs
        .map<Map<String, dynamic>>(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
              _normalizeOrder(<String, dynamic>{
            ...document.data(),
            'id': document.id,
          }),
        )
        .toList();
    orders.sort(_orderSort);
    return orders;
  });
}

// Admin must read ALL orders directly from Firestore, not customer orderHistory.
Stream<List<Map<String, dynamic>>> adminOrdersStream() {
  return _ordersCollection.snapshots().map(
    (QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<Map<String, dynamic>> orders = snapshot.docs
          .map<Map<String, dynamic>>(
            (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                _normalizeOrder(<String, dynamic>{
              ...document.data(),
              'id': document.id,
            }),
          )
          .toList();
      orders.sort(_orderSort);
      return orders;
    },
  );
}


/// Saves or updates one seller's settlement record inside an order.
///
/// Settlement data is stored seller-wise in:
/// orders/{orderId}.sellerSettlements.{sellerId}
///
/// This supports multi-seller orders because every seller has an independent
/// settlement status, amount, method, reference ID, and timestamps.
Future<void> updateSellerSettlement({
  required String orderId,
  required String sellerId,
  required String sellerName,
  required double amount,
  required String status,
  double grossAmount = 0,
  double commissionPercent = 0,
  double commissionAmount = 0,
  double sellerPayable = 0,
  String paymentMethod = '',
  String referenceId = '',
  String note = '',
}) async {
  final String cleanOrderId = orderId.trim();
  final String cleanSellerId = sellerId.trim();
  final String cleanSellerName = sellerName.trim();
  final String cleanStatus = status.trim();
  final String cleanPaymentMethod = paymentMethod.trim();
  final String cleanReferenceId = referenceId.trim();
  final String cleanNote = note.trim();

  if (cleanOrderId.isEmpty) {
    throw ArgumentError('Order ID cannot be empty.');
  }

  if (cleanSellerId.isEmpty) {
    throw ArgumentError('Seller ID cannot be empty.');
  }

  if (amount < 0) {
    throw ArgumentError('Settlement amount cannot be negative.');
  }

  if (grossAmount < 0 ||
      commissionPercent < 0 ||
      commissionPercent > 100 ||
      commissionAmount < 0 ||
      sellerPayable < 0) {
    throw ArgumentError('Invalid seller commission values.');
  }

  const List<String> allowedStatuses = <String>[
    'Pending',
    'Ready to Pay',
    'Paid',
    'On Hold',
  ];

  if (!allowedStatuses.contains(cleanStatus)) {
    throw ArgumentError('Invalid seller settlement status.');
  }

  final String now = DateTime.now().toIso8601String();
  final User? adminUser = FirebaseAuth.instance.currentUser;

  final Map<String, dynamic> settlement = <String, dynamic>{
    'sellerId': cleanSellerId,
    'sellerName': cleanSellerName,
    'amount': amount,
    'grossAmount': grossAmount,
    'commissionPercent': commissionPercent,
    'commissionAmount': commissionAmount,
    'sellerPayable': sellerPayable,
    'status': cleanStatus,
    'paymentMethod': cleanPaymentMethod,
    'referenceId': cleanReferenceId,
    'note': cleanNote,
    'updatedAt': now,
    'updatedBy': adminUser?.uid ?? '',
  };

  if (cleanStatus == 'Paid') {
    if (cleanPaymentMethod.isEmpty) {
      throw ArgumentError(
        'Payment method is required before marking seller as Paid.',
      );
    }

    if (cleanReferenceId.isEmpty) {
      throw ArgumentError(
        'Transaction / Reference ID is required before marking seller as Paid.',
      );
    }

    settlement['paidAt'] = now;
    settlement['paidBy'] = adminUser?.uid ?? '';
  }

  final DocumentReference<Map<String, dynamic>> orderRef =
      _ordersCollection.doc(cleanOrderId);

  await FirebaseFirestore.instance.runTransaction(
    (Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await transaction.get(orderRef);

      if (!snapshot.exists) {
        throw StateError('Order was not found.');
      }

      final Map<String, dynamic> orderData =
          snapshot.data() ?? <String, dynamic>{};

      final Map<String, dynamic> sellerSettlements =
          <String, dynamic>{};

      final dynamic existingSettlements =
          orderData['sellerSettlements'];

      if (existingSettlements is Map) {
        existingSettlements.forEach(
          (dynamic key, dynamic value) {
            sellerSettlements[key.toString()] = _safeValue(value);
          },
        );
      }

      final dynamic existingSellerSettlement =
          sellerSettlements[cleanSellerId];

      if (existingSellerSettlement is Map) {
        final String createdAt =
            existingSellerSettlement['createdAt']
                    ?.toString()
                    .trim() ??
                '';

        if (createdAt.isNotEmpty) {
          settlement['createdAt'] = createdAt;
        }
      }

      settlement['createdAt'] ??= now;
      sellerSettlements[cleanSellerId] = settlement;

      bool allPaid = sellerSettlements.isNotEmpty;

      for (final dynamic value in sellerSettlements.values) {
        if (value is! Map ||
            value['status']?.toString().trim() != 'Paid') {
          allPaid = false;
          break;
        }
      }

      transaction.set(
        orderRef,
        <String, dynamic>{
          'sellerSettlements': sellerSettlements,
          'sellerSettlementUpdatedAt': now,
          'sellerSettlementAllPaid': allPaid,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    },
  );

  final int index = orderHistory.indexWhere(
    (Map<String, dynamic> order) =>
        order['id']?.toString() == cleanOrderId,
  );

  if (index >= 0) {
    final Map<String, dynamic> localSettlements =
        <String, dynamic>{};

    final dynamic existing =
        orderHistory[index]['sellerSettlements'];

    if (existing is Map) {
      existing.forEach(
        (dynamic key, dynamic value) {
          localSettlements[key.toString()] = _safeValue(value);
        },
      );
    }

    localSettlements[cleanSellerId] =
        _safeMap(settlement);

    orderHistory[index]['sellerSettlements'] =
        localSettlements;
    orderHistory[index]['sellerSettlementUpdatedAt'] =
        now;

    bool allPaid = localSettlements.isNotEmpty;
    for (final dynamic value in localSettlements.values) {
      if (value is! Map ||
          value['status']?.toString().trim() != 'Paid') {
        allPaid = false;
        break;
      }
    }

    orderHistory[index]['sellerSettlementAllPaid'] =
        allPaid;
    orderHistory[index]['updatedAt'] = now;

    await saveOrders();
  }
}

Future<void> disposeOrderListener() async {
  await _ordersSubscription?.cancel();
  _ordersSubscription = null;
  _ordersListenerStarted = false;
  _ordersListenerCustomerId = '';
}

Future<void> recoverCustomerOrder({
  required String orderId,
  required String phone,
}) async {
  final String cleanOrderId = orderId.trim().toUpperCase();
  final String recoveryProof = normalizeOrderRecoveryPhone(phone);

  if (cleanOrderId.isEmpty) {
    throw ArgumentError('Please enter the Order ID.');
  }
  if (recoveryProof.length < 6) {
    throw ArgumentError('Please enter the phone number used for this order.');
  }

  final String customerId = await getOrCreateCustomerId();

  await _ordersCollection.doc(cleanOrderId).update(
    <String, dynamic>{
      'customerId': customerId,
      'recoveryProof': recoveryProof,
      'recoveredAt': FieldValue.serverTimestamp(),
    },
  );
}
