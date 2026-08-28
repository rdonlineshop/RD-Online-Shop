import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> orderHistory = <Map<String, dynamic>>[];

const String _customerIdPreferenceKey = 'rd_customer_id';

String _orderHistoryKey(String customerId) => 'orderHistory_$customerId';

CollectionReference<Map<String, dynamic>> get _ordersCollection =>
    FirebaseFirestore.instance.collection('orders');

CollectionReference<Map<String, dynamic>> get _customersCollection =>
    FirebaseFirestore.instance.collection('customers');

CollectionReference<Map<String, dynamic>> get _customerDeviceLinksCollection =>
    FirebaseFirestore.instance.collection('customer_device_links');

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

String _normalizeCustomerDeviceLinkCode(String value) {
  return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String _generateCustomerDeviceLinkCode() {
  const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final Random random = Random.secure();

  return List<String>.generate(
    12,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

String _displayCustomerDeviceLinkCode(String code) {
  if (code.length != 12) {
    return code;
  }

  return '${code.substring(0, 4)}-'
      '${code.substring(4, 8)}-'
      '${code.substring(8, 12)}';
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

Future<Map<String, dynamic>?> _registeredCustomerDocument(
  User user,
) async {
  if (user.isAnonymous) {
    return null;
  }

  try {
    final DocumentSnapshot<Map<String, dynamic>> document =
        await _customersCollection.doc(user.uid).get();

    if (!document.exists) {
      return null;
    }

    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    if (data['role']?.toString().trim() != 'customer' ||
        data['isActive'] == false) {
      return null;
    }

    return data;
  } catch (_) {
    return null;
  }
}

Future<String> getOrCreateCustomerId() async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    final UserCredential credential =
        await FirebaseAuth.instance.signInAnonymously();
    user = credential.user;
  }

  if (user == null) {
    throw StateError('Could not start customer session.');
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Registered customer:
  // customers/{authUid}.customerId is the permanent RD customer identity.
  // It may be an older guest ID so existing orders survive registration.
  if (!user.isAnonymous) {
    final Map<String, dynamic>? customer =
        await _registeredCustomerDocument(user);

    if (customer != null) {
      String customerId =
          customer['customerId']?.toString().trim() ?? '';

      if (customerId.isEmpty) {
        customerId = user.uid;

        await _customersCollection.doc(user.uid).set(
          <String, dynamic>{
            'authUid': user.uid,
            'customerId': customerId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await prefs.setString(_customerIdPreferenceKey, customerId);
      return customerId;
    }

    // Admin/Seller/Delivery account is active.
    // Never sign it out from a background customer helper.
    final String savedId =
        prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

    if (savedId.isNotEmpty) {
      return savedId;
    }

    final Random random = Random.secure();
    final String randomPart =
        random.nextInt(1000000).toString().padLeft(6, '0');
    final String localCustomerId =
        'RDC${DateTime.now().microsecondsSinceEpoch}$randomPart';

    await prefs.setString(
      _customerIdPreferenceKey,
      localCustomerId,
    );

    return localCustomerId;
  }

  // Guest customer: preserve the already-saved ID across anonymous Firebase
  // UID changes caused by explicit Seller/Admin/Driver login/logout.
  final String savedId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (savedId.isNotEmpty) {
    await _ensureCustomerSessionDocument(savedId);
    return savedId;
  }

  final String customerId = user.uid;

  await prefs.setString(
    _customerIdPreferenceKey,
    customerId,
  );

  await _ensureCustomerSessionDocument(customerId);
  return customerId;
}

Future<String?> getSavedCustomerId() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final User? user = FirebaseAuth.instance.currentUser;

  if (user != null && !user.isAnonymous) {
    final Map<String, dynamic>? customer =
        await _registeredCustomerDocument(user);

    if (customer != null) {
      final String registeredId =
          customer['customerId']?.toString().trim() ?? '';

      if (registeredId.isNotEmpty) {
        await prefs.setString(
          _customerIdPreferenceKey,
          registeredId,
        );
        return registeredId;
      }

      await prefs.setString(
        _customerIdPreferenceKey,
        user.uid,
      );
      return user.uid;
    }
  }

  final String savedId =
      prefs.getString(_customerIdPreferenceKey)?.trim() ?? '';

  if (savedId.isNotEmpty) {
    return savedId;
  }

  if (user != null && user.isAnonymous) {
    return user.uid;
  }

  return null;
}

Future<String> activateRegisteredCustomerSession(
  User user,
) async {
  if (user.isAnonymous) {
    throw StateError('Registered customer account is required.');
  }

  final DocumentSnapshot<Map<String, dynamic>> document =
      await _customersCollection.doc(user.uid).get();

  if (!document.exists) {
    throw StateError('Customer profile was not found.');
  }

  final Map<String, dynamic> data =
      document.data() ?? <String, dynamic>{};

  if (data['role']?.toString().trim() != 'customer' ||
      data['isActive'] == false) {
    throw StateError('This account is not an active customer account.');
  }

  String customerId =
      data['customerId']?.toString().trim() ?? '';

  if (customerId.isEmpty) {
    customerId = user.uid;

    await _customersCollection.doc(user.uid).set(
      <String, dynamic>{
        'authUid': user.uid,
        'customerId': customerId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_customerIdPreferenceKey, customerId);

  await reloadOrdersForCurrentCustomer();
  return customerId;
}

Future<String> switchToGuestCustomerSession({
  String? preferredCustomerId,
}) async {
  final FirebaseAuth auth = FirebaseAuth.instance;

  await _ordersSubscription?.cancel();
  _ordersSubscription = null;
  _ordersListenerStarted = false;
  _ordersListenerCustomerId = '';

  if (auth.currentUser != null && auth.currentUser!.isAnonymous) {
    // Keep the current anonymous Firebase user.
  } else {
    await auth.signOut();
    await auth.signInAnonymously();
  }

  final User? guest = auth.currentUser;
  if (guest == null || !guest.isAnonymous) {
    throw StateError('Could not restore guest customer session.');
  }

  final String preferred = preferredCustomerId?.trim() ?? '';
  final String customerId =
      preferred.isNotEmpty ? preferred : guest.uid;

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_customerIdPreferenceKey, customerId);

  await _ensureCustomerSessionDocument(customerId);
  await reloadOrdersForCurrentCustomer();

  return customerId;
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

  // Do not replay every locally saved/legacy order back to Firestore on app
  // startup. New orders are already written by addOrder(), while device linking
  // and recovery have their own explicit Firestore flows. Replaying old local
  // backups can repeatedly try to update historical orders that this current
  // customer session is not allowed to modify, which creates permission-denied
  // WriteStream warnings.
  await _startOrdersListener();
}

Future<void> _loadLocalOrders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  String? customerId = await getSavedCustomerId();
  if (customerId == null || customerId.trim().isEmpty) {
    customerId = await getOrCreateCustomerId();
  }

  final String cleanCustomerId = customerId.trim();
  if (cleanCustomerId.isEmpty) {
    orderHistory = <Map<String, dynamic>>[];
    return;
  }

  final String scopedKey = _orderHistoryKey(cleanCustomerId);
  final String scopedRaw = prefs.getString(scopedKey)?.trim() ?? '';
  final String legacyRaw = prefs.getString('orderHistory')?.trim() ?? '';

  final Map<String, Map<String, dynamic>> mergedById =
      <String, Map<String, dynamic>>{};

  bool recoveredLegacyData = false;

  void decodeAndMerge(
    String raw, {
    required bool isLegacyBackup,
  }) {
    if (raw.isEmpty) {
      return;
    }

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      for (final dynamic rawOrder in decoded) {
        if (rawOrder is! Map) {
          continue;
        }

        final Map<String, dynamic> copied = <String, dynamic>{};
        rawOrder.forEach((dynamic key, dynamic value) {
          copied[key.toString()] = value;
        });

        final Map<String, dynamic> normalized = _normalizeOrder(copied);

        final String orderId = normalized['id']?.toString().trim() ?? '';
        if (orderId.isEmpty) {
          continue;
        }

        String orderCustomerId =
            normalized['customerId']?.toString().trim() ?? '';

        // Legacy RD builds used a single device-wide "orderHistory" key and
        // some builds either had no customerId or used an older anonymous UID.
        // When reading that legacy device backup, attach the order to the
        // stable customer ID used by this device now.
        if (isLegacyBackup && orderCustomerId != cleanCustomerId) {
          normalized['customerId'] = cleanCustomerId;
          orderCustomerId = cleanCustomerId;
          recoveredLegacyData = true;
        } else if (orderCustomerId.isEmpty) {
          normalized['customerId'] = cleanCustomerId;
          orderCustomerId = cleanCustomerId;
          recoveredLegacyData = true;
        }

        if (orderCustomerId != cleanCustomerId) {
          continue;
        }

        // Scoped/current data wins over the legacy copy when IDs match.
        if (!mergedById.containsKey(orderId) || !isLegacyBackup) {
          mergedById[orderId] = normalized;
        }
      }
    } catch (error) {
      // A broken legacy backup must never hide valid scoped orders.
      debugPrint('Could not decode saved orders: $error');
    }
  }

  // Read legacy first, then the current customer-specific backup so the
  // current copy wins if the same order exists in both.
  decodeAndMerge(legacyRaw, isLegacyBackup: true);
  decodeAndMerge(scopedRaw, isLegacyBackup: false);

  orderHistory = mergedById.values.toList();
  _sortOrders();

  if (orderHistory.isNotEmpty &&
      (recoveredLegacyData || scopedRaw.isEmpty)) {
    final String encoded = jsonEncode(
      orderHistory.map<Map<String, dynamic>>(_safeMap).toList(),
    );
    await prefs.setString(scopedKey, encoded);
  }
}

Future<void> saveOrders() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? customerId = await getSavedCustomerId();

  if (customerId == null || customerId.trim().isEmpty) {
    return;
  }

  final String cleanCustomerId = customerId.trim();

  final List<Map<String, dynamic>> safeOrders = orderHistory
      .where(
        (Map<String, dynamic> order) =>
            order['customerId']?.toString().trim() == cleanCustomerId,
      )
      .map<Map<String, dynamic>>(_safeMap)
      .toList();

  final String encoded = jsonEncode(safeOrders);

  // Main/current backup: customer-specific and safe across role logins.
  await prefs.setString(_orderHistoryKey(cleanCustomerId), encoded);

  // Do NOT overwrite the old device-wide "orderHistory" key here.
  // Older RD builds may still have recoverable orders in that legacy backup.
}

Future<void> _startOrdersListener() async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return;
  }

  final String customerId = await getOrCreateCustomerId();

  // Run customer realtime sync for anonymous guests and registered customers.
  // Never attach this listener while Admin/Seller/Delivery auth is active.
  if (!user.isAnonymous) {
    final Map<String, dynamic>? customer =
        await _registeredCustomerDocument(user);

    if (customer == null) {
      return;
    }
  }

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

      final Map<String, Map<String, dynamic>> mergedById =
          <String, Map<String, dynamic>>{};

      // Keep local/recovered orders first.
      for (final Map<String, dynamic> localOrder in orderHistory) {
        if (localOrder['customerId']?.toString().trim() != customerId) {
          continue;
        }

        final String id = localOrder['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          mergedById[id] = _normalizeOrder(localOrder);
        }
      }

      // Firestore is authoritative for an order that exists in both places.
      for (final Map<String, dynamic> cloudOrder in cloudOrders) {
        final String id = cloudOrder['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) {
          mergedById[id] = cloudOrder;
        }
      }

      orderHistory = mergedById.values.toList();
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

  String recoveryPhoneKey = '';

  for (final dynamic candidate in <dynamic>[
    order['phone'],
    order['customerPhone'],
    order['mobile'],
  ]) {
    final String normalized =
        normalizeOrderRecoveryPhone(candidate?.toString() ?? '');

    if (normalized.isNotEmpty) {
      recoveryPhoneKey = normalized;
      break;
    }
  }

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

Future<String> createCustomerDeviceLinkCode() async {
  final String customerId = await getOrCreateCustomerId();
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null || customerId.trim().isEmpty) {
    throw StateError('Customer session is not available.');
  }

  if (!user.isAnonymous) {
    final Map<String, dynamic>? customer =
        await _registeredCustomerDocument(user);

    if (customer == null) {
      throw StateError(
        'Please use Customer mode before linking devices.',
      );
    }
  }

  final DateTime expiresAt =
      DateTime.now().toUtc().add(const Duration(minutes: 10));

  for (int attempt = 0; attempt < 5; attempt++) {
    final String code = _generateCustomerDeviceLinkCode();
    final DocumentReference<Map<String, dynamic>> linkRef =
        _customerDeviceLinksCollection.doc(code);

    final DocumentSnapshot<Map<String, dynamic>> existing =
        await linkRef.get();

    if (existing.exists) {
      continue;
    }

    try {
      await linkRef.set(
        <String, dynamic>{
          'customerId': customerId.trim(),
          'createdByUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'used': false,
        },
      );

      return _displayCustomerDeviceLinkCode(code);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        rethrow;
      }
    }
  }

  throw StateError(
    'Could not create a device link code. Please try again.',
  );
}

Future<String> linkThisDeviceToCustomer(String linkCode) async {
  final String cleanCode =
      _normalizeCustomerDeviceLinkCode(linkCode.trim());

  if (cleanCode.length != 12) {
    throw ArgumentError('Please enter the full 12-character link code.');
  }

  final FirebaseAuth auth = FirebaseAuth.instance;
  User? user = auth.currentUser;

  if (user == null) {
    final UserCredential credential = await auth.signInAnonymously();
    user = credential.user;
  }

  if (user == null) {
    throw StateError('Could not start customer session.');
  }

  if (!user.isAnonymous) {
    final Map<String, dynamic>? customer =
        await _registeredCustomerDocument(user);

    if (customer == null) {
      throw StateError(
        'Please use Customer mode before linking devices.',
      );
    }
  }

  final String currentCustomerId = await getOrCreateCustomerId();

  if (user.isAnonymous) {
    await _ensureCustomerSessionDocument(currentCustomerId);
  }

  final DocumentReference<Map<String, dynamic>> linkRef =
      _customerDeviceLinksCollection.doc(cleanCode);

  String targetCustomerId = '';

  await FirebaseFirestore.instance.runTransaction(
    (Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await transaction.get(linkRef);

      if (!snapshot.exists) {
        throw StateError('Link code was not found.');
      }

      final Map<String, dynamic> data =
          snapshot.data() ?? <String, dynamic>{};

      if (data['used'] == true) {
        throw StateError('This link code has already been used.');
      }

      final dynamic rawExpiresAt = data['expiresAt'];
      DateTime? expiresAt;

      if (rawExpiresAt is Timestamp) {
        expiresAt = rawExpiresAt.toDate().toUtc();
      } else if (rawExpiresAt is DateTime) {
        expiresAt = rawExpiresAt.toUtc();
      }

      if (expiresAt == null ||
          !expiresAt.isAfter(DateTime.now().toUtc())) {
        throw StateError('This link code has expired.');
      }

      targetCustomerId =
          data['customerId']?.toString().trim() ?? '';

      if (targetCustomerId.isEmpty) {
        throw StateError('Link code is invalid.');
      }

      transaction.update(
        linkRef,
        <String, dynamic>{
          'used': true,
          'usedByUid': user!.uid,
          'usedAt': FieldValue.serverTimestamp(),
        },
      );
    },
  );

  // Merge orders already owned by this device into the target customer ID.
  if (currentCustomerId != targetCustomerId) {
    final QuerySnapshot<Map<String, dynamic>> currentOrders =
        await _ordersCollection
            .where('customerId', isEqualTo: currentCustomerId)
            .get();

    const int batchSize = 400;
    for (int start = 0; start < currentOrders.docs.length; start += batchSize) {
      final int end = (start + batchSize < currentOrders.docs.length)
          ? start + batchSize
          : currentOrders.docs.length;

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in currentOrders.docs.sublist(start, end)) {
        batch.update(
          document.reference,
          <String, dynamic>{
            'customerId': targetCustomerId,
            'linkedViaCode': cleanCode,
            'linkedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();
    }
  }

  await _customersCollection.doc(user.uid).update(
    <String, dynamic>{
      'customerId': targetCustomerId,
      'linkedViaCode': cleanCode,
      'linkedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
  );

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_customerIdPreferenceKey, targetCustomerId);

  await reloadOrdersForCurrentCustomer();
  return targetCustomerId;
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

  // Do not read the old order first.
  // Firestore Security Rules intentionally block another device from reading
  // an order until ownership recovery succeeds.
  final String customerId = await getOrCreateCustomerId();

  final DocumentReference<Map<String, dynamic>> orderRef =
      _ordersCollection.doc(cleanOrderId);

  await orderRef.update(
    <String, dynamic>{
      'customerId': customerId,
      'recoveryProof': recoveryProof,
      'recoveryPhoneKey': recoveryProof,
      'recoveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
  );

  await reloadOrdersForCurrentCustomer();
}
