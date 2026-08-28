import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_data.dart';
import 'order_details_page.dart';

const String _readNotificationsPrefix = 'rd_read_order_notifications_';

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
      prefs.getStringList('$_readNotificationsPrefix$customerId') ??
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
    '$_readNotificationsPrefix$customerId',
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

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends State<CustomerNotificationsPage> {
  String _customerId = '';
  Set<String> _readKeys = <String>{};
  bool _isLoading = true;
  String _loadError = '';

  static const Color _rdRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final String customerId =
          (await getOrCreateCustomerId()).trim();

      final Set<String> readKeys =
          await loadReadOrderNotificationKeys(customerId);

      if (!mounted) {
        return;
      }

      setState(() {
        _customerId = customerId;
        _readKeys = readKeys;
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

  Future<void> _markOneRead(
    Map<String, dynamic> order,
  ) async {
    final String key = orderNotificationKey(order);

    if (_readKeys.contains(key)) {
      return;
    }

    final Set<String> updated = <String>{..._readKeys, key};
    await saveReadOrderNotificationKeys(_customerId, updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readKeys = updated;
    });
  }

  Future<void> _markAllRead(
    List<Map<String, dynamic>> orders,
  ) async {
    final Set<String> updated = <String>{..._readKeys};

    for (final Map<String, dynamic> order in orders) {
      final String orderId = order['id']?.toString().trim() ?? '';
      if (orderId.isNotEmpty) {
        updated.add(orderNotificationKey(order));
      }
    }

    await saveReadOrderNotificationKeys(_customerId, updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readKeys = updated;
    });
  }

  Future<void> _openOrder(
    Map<String, dynamic> order,
  ) async {
    await _markOneRead(order);

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

  DateTime? _notificationDate(Map<String, dynamic> order) {
    for (final dynamic value in <dynamic>[
      order['updatedAt'],
      order['deliveredAt'],
      order['deliveryStartedAt'],
      order['orderDateTime'],
      order['createdAt'],
    ]) {
      if (value == null) {
        continue;
      }

      if (value is DateTime) {
        return value;
      }

      final String raw = value.toString().trim();
      if (raw.isEmpty || raw.toLowerCase() == 'null') {
        continue;
      }

      final DateTime? parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
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
              'Your order status updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(
    Map<String, dynamic> order,
  ) {
    final String orderId = order['id']?.toString().trim() ?? '';
    final String status = order['status']?.toString().trim() ?? 'Pending';
    final String key = orderNotificationKey(order);
    final bool unread = !_readKeys.contains(key);
    final Color statusColor = _colorForStatus(status);
    final DateTime? date = _notificationDate(order);

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

                    if (orders.isEmpty) {
                      return _emptyState();
                    }

                    final int unreadCount =
                        orders.where((Map<String, dynamic> order) {
                      return !_readKeys.contains(orderNotificationKey(order));
                    }).length;

                    return Column(
                      children: <Widget>[
                        if (unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _markAllRead(orders),
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
                            itemCount: orders.length,
                            itemBuilder: (
                              BuildContext context,
                              int index,
                            ) {
                              return _notificationCard(orders[index]);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
