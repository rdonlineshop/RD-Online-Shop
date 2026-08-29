import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_data.dart';
import 'order_details_page.dart';

const String _readOrderNotificationsPrefix = 'rd_read_order_notifications_';
const String _readAdminNotificationsPrefix = 'rd_read_admin_notifications_';

String orderNotificationKey(Map<String, dynamic> order) {
  final String orderId = order['id']?.toString().trim() ?? '';
  final String status = order['status']?.toString().trim() ?? 'Pending';
  return '$orderId|$status';
}

Future<Set<String>> loadReadOrderNotificationKeys(
  String customerId,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String> saved =
      prefs.getStringList('$_readOrderNotificationsPrefix$customerId') ??
          <String>[];
  return saved.toSet();
}

Future<void> saveReadOrderNotificationKeys(
  String customerId,
  Set<String> keys,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String> sorted = keys.toList()..sort();
  await prefs.setStringList(
    '$_readOrderNotificationsPrefix$customerId',
    sorted,
  );
}

Future<int> countUnreadOrderNotifications(
  String customerId,
  List<Map<String, dynamic>> orders,
) async {
  if (customerId.trim().isEmpty) {
    return 0;
  }

  final Set<String> readKeys =
      await loadReadOrderNotificationKeys(customerId);

  return orders.where((Map<String, dynamic> order) {
    final String orderId = order['id']?.toString().trim() ?? '';
    if (orderId.isEmpty) {
      return false;
    }
    return !readKeys.contains(orderNotificationKey(order));
  }).length;
}

Future<Set<String>> _loadReadAdminNotificationKeys(
  String customerId,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String> saved =
      prefs.getStringList('$_readAdminNotificationsPrefix$customerId') ??
          <String>[];
  return saved.toSet();
}

Future<void> _saveReadAdminNotificationKeys(
  String customerId,
  Set<String> keys,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final List<String> sorted = keys.toList()..sort();
  await prefs.setStringList(
    '$_readAdminNotificationsPrefix$customerId',
    sorted,
  );
}

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  static const Color _rdRed = Color(0xFFE50914);

  String _customerId = '';
  Set<String> _readOrderKeys = <String>{};
  Set<String> _readAdminKeys = <String>{};
  bool _isLoading = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final String customerId = (await getOrCreateCustomerId()).trim();

      final Set<String> readOrderKeys =
          await loadReadOrderNotificationKeys(customerId);
      final Set<String> readAdminKeys =
          await _loadReadAdminNotificationKeys(customerId);

      if (!mounted) {
        return;
      }

      setState(() {
        _customerId = customerId;
        _readOrderKeys = readOrderKeys;
        _readAdminKeys = readAdminKeys;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _broadcastNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('isActive', isEqualTo: true)
        .where(
          'audience',
          whereIn: <String>['customers', 'both'],
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _targetedNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('isActive', isEqualTo: true)
        .where('audience', isEqualTo: 'customer')
        .where('targetCustomerId', isEqualTo: _customerId)
        .snapshots();
  }

  Future<void> _markOrderRead(
    Map<String, dynamic> order,
  ) async {
    final String key = orderNotificationKey(order);

    if (_readOrderKeys.contains(key)) {
      return;
    }

    final Set<String> updated = <String>{..._readOrderKeys, key};
    await saveReadOrderNotificationKeys(_customerId, updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readOrderKeys = updated;
    });
  }

  Future<void> _markAdminRead(
    String notificationId,
  ) async {
    final String key = notificationId.trim();

    if (key.isEmpty || _readAdminKeys.contains(key)) {
      return;
    }

    final Set<String> updated = <String>{..._readAdminKeys, key};
    await _saveReadAdminNotificationKeys(_customerId, updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readAdminKeys = updated;
    });
  }

  Future<void> _markAllRead(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> adminNotifications,
  ) async {
    final Set<String> updatedOrderKeys = <String>{..._readOrderKeys};
    final Set<String> updatedAdminKeys = <String>{..._readAdminKeys};

    for (final Map<String, dynamic> order in orders) {
      final String orderId = order['id']?.toString().trim() ?? '';
      if (orderId.isNotEmpty) {
        updatedOrderKeys.add(orderNotificationKey(order));
      }
    }

    for (final Map<String, dynamic> notification in adminNotifications) {
      final String notificationId =
          notification['notificationId']?.toString().trim() ?? '';
      if (notificationId.isNotEmpty) {
        updatedAdminKeys.add(notificationId);
      }
    }

    await Future.wait<void>(<Future<void>>[
      saveReadOrderNotificationKeys(_customerId, updatedOrderKeys),
      _saveReadAdminNotificationKeys(_customerId, updatedAdminKeys),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _readOrderKeys = updatedOrderKeys;
      _readAdminKeys = updatedAdminKeys;
    });
  }

  Future<void> _openOrder(
    Map<String, dynamic> order,
  ) async {
    await _markOrderRead(order);

    if (!mounted) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsPage(order: order),
      ),
    );
  }

  Future<void> _openAdminNotification(
    Map<String, dynamic> notification,
  ) async {
    final String notificationId =
        notification['notificationId']?.toString().trim() ?? '';
    await _markAdminRead(notificationId);

    if (!mounted) {
      return;
    }

    final String title =
        notification['title']?.toString().trim() ?? 'RD Online Shop';
    final String message = notification['message']?.toString().trim() ?? '';
    final String mediaUrl = notification['mediaUrl']?.toString().trim() ?? '';
    final String actionUrl = notification['actionUrl']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (message.isNotEmpty) Text(message),
                if (mediaUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Media:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(mediaUrl),
                ],
                if (actionUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Link:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(actionUrl),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _titleForStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return 'Order placed';
      case 'confirmed':
        return 'Order confirmed';
      case 'processing':
        return 'Order is being prepared';
      case 'shipped':
        return 'Order shipped';
      case 'delivered':
        return 'Order delivered';
      case 'cancelled':
      case 'canceled':
        return 'Order cancelled';
      case 'returned':
        return 'Order returned';
      case 'refunded':
        return 'Refund completed';
      default:
        return 'Order update';
    }
  }

  IconData _iconForStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return Icons.receipt_long_rounded;
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'processing':
        return Icons.inventory_2_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.task_alt_rounded;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel_rounded;
      case 'returned':
        return Icons.assignment_return_rounded;
      case 'refunded':
        return Icons.currency_exchange_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.deepPurple;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'returned':
        return Colors.brown;
      case 'refunded':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    final String raw = value.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  DateTime? _orderNotificationDate(Map<String, dynamic> order) {
    for (final dynamic value in <dynamic>[
      order['updatedAt'],
      order['deliveredAt'],
      order['deliveryStartedAt'],
      order['orderDateTime'],
      order['createdAt'],
    ]) {
      final DateTime? date = _dateFromValue(value);
      if (date != null) {
        return date;
      }
    }

    return null;
  }

  DateTime? _adminNotificationDate(
    Map<String, dynamic> notification,
  ) {
    return _dateFromValue(
      notification['createdAt'] ?? notification['updatedAt'],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final DateTime local = date.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final int rawHour = local.hour % 12;
    final int hour = rawHour == 0 ? 12 : rawHour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${local.year}  $hour:$minute $period';
  }

  List<Map<String, dynamic>> _adminDocumentsToMaps(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(
      (QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(document.data());

        final String notificationId =
            data['notificationId']?.toString().trim() ?? '';

        if (notificationId.isEmpty) {
          data['notificationId'] = document.id;
        }

        return data;
      },
    ).toList();
  }

  List<Map<String, dynamic>> _mergeAdminNotifications(
    List<Map<String, dynamic>> broadcasts,
    List<Map<String, dynamic>> targeted,
  ) {
    final Map<String, Map<String, dynamic>> unique =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> notification
        in <Map<String, dynamic>>[...broadcasts, ...targeted]) {
      final String notificationId =
          notification['notificationId']?.toString().trim() ?? '';

      if (notificationId.isNotEmpty) {
        unique[notificationId] = notification;
      }
    }

    final List<Map<String, dynamic>> result = unique.values.toList();

    result.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime aDate =
            _adminNotificationDate(a) ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            _adminNotificationDate(b) ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      },
    );

    return result;
  }

  List<Map<String, dynamic>> _combinedFeed(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> adminNotifications,
  ) {
    final List<Map<String, dynamic>> feed = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> notification in adminNotifications) {
      feed.add(<String, dynamic>{
        'kind': 'admin',
        'data': notification,
        'date': _adminNotificationDate(notification),
      });
    }

    for (final Map<String, dynamic> order in orders) {
      feed.add(<String, dynamic>{
        'kind': 'order',
        'data': order,
        'date': _orderNotificationDate(order),
      });
    }

    feed.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime aDate =
            a['date'] is DateTime
                ? a['date'] as DateTime
                : DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            b['date'] is DateTime
                ? b['date'] as DateTime
                : DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      },
    );

    return feed;
  }

  int _unreadCount(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> adminNotifications,
  ) {
    final int unreadOrders = orders.where(
      (Map<String, dynamic> order) {
        return !_readOrderKeys.contains(orderNotificationKey(order));
      },
    ).length;

    final int unreadAdmin = adminNotifications.where(
      (Map<String, dynamic> notification) {
        final String notificationId =
            notification['notificationId']?.toString().trim() ?? '';
        return notificationId.isNotEmpty &&
            !_readAdminKeys.contains(notificationId);
      },
    ).length;

    return unreadOrders + unreadAdmin;
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 14),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Order updates and RD Online Shop announcements will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderNotificationCard(
    Map<String, dynamic> order,
  ) {
    final String orderId = order['id']?.toString().trim() ?? '';
    final String status = order['status']?.toString().trim() ?? 'Pending';
    final String key = orderNotificationKey(order);
    final bool unread = !_readOrderKeys.contains(key);
    final Color statusColor = _colorForStatus(status);
    final DateTime? date = _orderNotificationDate(order);

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      elevation: unread ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: unread
              ? _rdRed.withValues(alpha: 0.28)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openOrder(order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForStatus(status),
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _titleForStatus(status),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: _rdRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Order $orderId is now $status.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    if (_formatDate(date).isNotEmpty) ...<Widget>[
                      const SizedBox(height: 7),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminNotificationCard(
    Map<String, dynamic> notification,
  ) {
    final String notificationId =
        notification['notificationId']?.toString().trim() ?? '';
    final String title =
        notification['title']?.toString().trim() ?? 'RD Online Shop';
    final String message = notification['message']?.toString().trim() ?? '';
    final String contentType =
        notification['contentType']?.toString().trim() ?? 'general';
    final bool unread = !_readAdminKeys.contains(notificationId);
    final DateTime? date = _adminNotificationDate(notification);

    IconData icon = Icons.campaign_rounded;
    Color color = _rdRed;

    switch (contentType) {
      case 'promotion':
        icon = Icons.local_offer_rounded;
        color = Colors.deepOrange;
        break;
      case 'order':
        icon = Icons.shopping_bag_rounded;
        color = Colors.blue;
        break;
      case 'system':
        icon = Icons.info_rounded;
        color = Colors.indigo;
        break;
      case 'announcement':
        icon = Icons.campaign_rounded;
        color = _rdRed;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = Colors.deepPurple;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      elevation: unread ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: unread
              ? color.withValues(alpha: 0.32)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openAdminNotification(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: _rdRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          'RD Online Shop',
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_formatDate(date).isNotEmpty)
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feed(
    List<Map<String, dynamic>> orders,
    List<Map<String, dynamic>> adminNotifications,
  ) {
    final List<Map<String, dynamic>> feed =
        _combinedFeed(orders, adminNotifications);

    if (feed.isEmpty) {
      return _emptyState();
    }

    final int unreadCount = _unreadCount(orders, adminNotifications);

    return Column(
      children: <Widget>[
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$unreadCount unread notification'
                    '${unreadCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _markAllRead(
                    orders,
                    adminNotifications,
                  ),
                  icon: const Icon(
                    Icons.done_all_rounded,
                    size: 18,
                  ),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 24,
            ),
            itemCount: feed.length,
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final Map<String, dynamic> item = feed[index];
              final String kind = item['kind']?.toString() ?? '';
              final Map<String, dynamic> data =
                  Map<String, dynamic>.from(
                item['data'] as Map<String, dynamic>,
              );

              if (kind == 'admin') {
                return _adminNotificationCard(data);
              }

              return _orderNotificationCard(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _notificationStreams(
    List<Map<String, dynamic>> orders,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _broadcastNotificationsStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> broadcastSnapshot,
      ) {
        if (broadcastSnapshot.connectionState == ConnectionState.waiting &&
            !broadcastSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (broadcastSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load RD announcements.\n'
                '${broadcastSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> broadcasts =
            broadcastSnapshot.hasData
                ? _adminDocumentsToMaps(broadcastSnapshot.data!)
                : <Map<String, dynamic>>[];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _targetedNotificationsStream(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> targetedSnapshot,
          ) {
            if (targetedSnapshot.connectionState == ConnectionState.waiting &&
                !targetedSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (targetedSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load personal notifications.\n'
                    '${targetedSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<Map<String, dynamic>> targeted =
                targetedSnapshot.hasData
                    ? _adminDocumentsToMaps(targetedSnapshot.data!)
                    : <Map<String, dynamic>>[];

            final List<Map<String, dynamic>> adminNotifications =
                _mergeAdminNotifications(
              broadcasts,
              targeted,
            );

            return _feed(
              orders,
              adminNotifications,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load notifications.\n$_loadError',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: customerOrdersStream(_customerId),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Notifications are not available in the current account mode.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final List<Map<String, dynamic>> orders =
                        snapshot.data ?? <Map<String, dynamic>>[];

                    return _notificationStreams(orders);
                  },
                ),
    );
  }
}
