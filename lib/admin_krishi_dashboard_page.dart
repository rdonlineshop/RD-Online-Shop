import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_krishi_seller_page.dart';
import 'order_data.dart';

class AdminKrishiDashboardPage extends StatelessWidget {
  const AdminKrishiDashboardPage({super.key});

  bool _isKrishiProduct(Map<String, dynamic> data) {
    final String marketplace =
        data['marketplace']?.toString().trim().toLowerCase() ?? '';
    final String productType =
        data['productType']?.toString().trim().toLowerCase() ?? '';

    return marketplace == 'krishi' ||
        productType == 'krishi' ||
        productType == 'agriculture';
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 42,
                color: Colors.green,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Set<String>> _krishiSellerIds() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('sellers')
            .where(
              'sellerType',
              isEqualTo: 'krishi',
            )
            .get();

    return snapshot.docs
        .map(
          (
            QueryDocumentSnapshot<Map<String, dynamic>>
                doc,
          ) =>
              doc.id,
        )
        .toSet();
  }

  bool _isKrishiOrder(
    Map<String, dynamic> order,
    Set<String> sellerIds,
  ) {
    final dynamic rawSellerIds = order['sellerIds'];
    if (rawSellerIds is List) {
      for (final dynamic value in rawSellerIds) {
        if (sellerIds.contains(value?.toString())) {
          return true;
        }
      }
    }

    final String directSeller =
        order['sellerId']?.toString().trim() ?? '';
    if (sellerIds.contains(directSeller)) {
      return true;
    }

    final dynamic items = order['items'];
    if (items is List) {
      for (final dynamic raw in items) {
        if (raw is Map) {
          final String sellerId =
              raw['sellerId']?.toString().trim() ?? '';
          if (sellerIds.contains(sellerId)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  void _openProducts(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AdminKrishiProductsPage(
          isKrishiProduct: _isKrishiProduct,
        ),
      ),
    );
  }

  void _openOrders(
    BuildContext context, {
    bool deliveryOnly = false,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AdminKrishiOrdersPage(
          sellerIdsLoader: _krishiSellerIds,
          isKrishiOrder: _isKrishiOrder,
          deliveryOnly: deliveryOnly,
        ),
      ),
    );
  }

  void _openCustomers(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AdminKrishiCustomersPage(
          sellerIdsLoader: _krishiSellerIds,
          isKrishiOrder: _isKrishiOrder,
        ),
      ),
    );
  }

  void _openEarnings(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AdminKrishiEarningsPage(
          sellerIdsLoader: _krishiSellerIds,
          isKrishiOrder: _isKrishiOrder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final int columns =
              constraints.maxWidth >= 900 ? 3 : 2;

          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                constraints.maxWidth >= 900 ? 1.2 : 1.0,
            children: <Widget>[
              _card(
                icon: Icons.receipt_long_rounded,
                title: 'Orders',
                subtitle: 'Krishi orders only',
                onTap: () {
                  _openOrders(context);
                },
              ),
              _card(
                icon: Icons.inventory_2_rounded,
                title: 'Products',
                subtitle: 'Krishi product catalog',
                onTap: () {
                  _openProducts(context);
                },
              ),
              _card(
                icon: Icons.agriculture_rounded,
                title: 'Krishi Sellers',
                subtitle:
                    'Documents • Verify • Approve • Activate',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AdminKrishiSellerPage(),
                    ),
                  );
                },
              ),
              _card(
                icon: Icons.delivery_dining_rounded,
                title: 'Delivery',
                subtitle:
                    'Assigned Krishi deliveries and status',
                onTap: () {
                  _openOrders(
                    context,
                    deliveryOnly: true,
                  );
                },
              ),
              _card(
                icon: Icons.people_alt_rounded,
                title: 'Customers',
                subtitle: 'Krishi order customers',
                onTap: () {
                  _openCustomers(context);
                },
              ),
              _card(
                icon:
                    Icons.account_balance_wallet_rounded,
                title: 'Earnings',
                subtitle: 'Krishi sales totals',
                onTap: () {
                  _openEarnings(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminKrishiProductsPage extends StatelessWidget {
  final bool Function(Map<String, dynamic>) isKrishiProduct;

  const _AdminKrishiProductsPage({
    required this.isKrishiProduct,
  });

  Future<void> _toggle(
    String id,
    bool active,
  ) {
    return FirebaseFirestore.instance
        .collection('products')
        .doc(id)
        .set(
      <String, dynamic>{
        'productStatus': active ? 'active' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }


  Future<void> _deleteProduct(
    BuildContext context,
    String productId,
    String productName,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Krishi Product?'),
          content: Text(
            '$productName will be permanently removed from the Krishi catalog '
            'and will no longer appear to customers or the seller.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Permanent Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$productName permanently deleted.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Products'),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load products:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs
              .where(
                (doc) => isKrishiProduct(doc.data()),
              )
              .toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text('No Krishi products yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final doc = docs[index];
              final data = doc.data();
              final bool active =
                  data['productStatus']
                          ?.toString()
                          .toLowerCase() !=
                      'inactive';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.agriculture_rounded,
                    ),
                  ),
                  title: Text(
                    data['name']?.toString() ??
                        'Krishi Product',
                  ),
                  subtitle: Text(
                    '${data['sellerShopName'] ?? ''}\n'
                    '${data['price'] ?? ''} • '
                    'Stock: ${data['stockQuantity'] ?? 0}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Switch(
                        value: active,
                        onChanged: (bool value) {
                          _toggle(doc.id, value);
                        },
                      ),
                      IconButton(
                        tooltip: 'Permanent Delete',
                        onPressed: () {
                          _deleteProduct(
                            context,
                            doc.id,
                            data['name']?.toString() ??
                                'Krishi Product',
                          );
                        },
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminKrishiOrdersPage extends StatelessWidget {
  final Future<Set<String>> Function() sellerIdsLoader;
  final bool Function(
    Map<String, dynamic>,
    Set<String>,
  ) isKrishiOrder;
  final bool deliveryOnly;

  const _AdminKrishiOrdersPage({
    required this.sellerIdsLoader,
    required this.isKrishiOrder,
    required this.deliveryOnly,
  });


  Future<void> _deleteOrder(
    BuildContext context,
    String orderId,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Krishi Order?'),
          content: Text(
            'Order $orderId will be permanently removed from active Krishi '
            'orders, customer history, seller views, delivery views and earnings. '
            'This cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Permanent Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await adminPermanentlyDeleteOrder(orderId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $orderId permanently deleted.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $error'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          deliveryOnly
              ? 'Krishi Delivery'
              : 'Krishi Orders',
        ),
      ),
      body: FutureBuilder<Set<String>>(
        future: sellerIdsLoader(),
        builder: (
          BuildContext context,
          AsyncSnapshot<Set<String>> sellerSnapshot,
        ) {
          if (!sellerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<
                      QuerySnapshot<
                          Map<String, dynamic>>>
                  snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load orders:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final Set<String> sellerIds =
                  sellerSnapshot.data!;

              final docs = snapshot.data!.docs.where(
                (doc) {
                  final data = doc.data();

                  if (!isKrishiOrder(
                    data,
                    sellerIds,
                  )) {
                    return false;
                  }

                  if (deliveryOnly) {
                    return (data['driverId']
                                    ?.toString()
                                    .trim() ??
                                '')
                            .isNotEmpty ||
                        (data['status']
                                    ?.toString()
                                    .toLowerCase() ??
                                '')
                            .contains('ship') ||
                        (data['trackingStatus']
                                    ?.toString()
                                    .toLowerCase() ??
                                '')
                            .contains('delivery');
                  }

                  return true;
                },
              ).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    deliveryOnly
                        ? 'No Krishi deliveries yet.'
                        : 'No Krishi orders yet.',
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  final doc = docs[index];
                  final data = doc.data();

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        deliveryOnly
                            ? Icons
                                .delivery_dining_rounded
                            : Icons
                                .receipt_long_rounded,
                        color: Colors.green,
                      ),
                      title: Text(
                        'Order #${doc.id.length > 10 ? doc.id.substring(0, 10) : doc.id}',
                      ),
                      subtitle: Text(
                        'Customer: ${data['customerName'] ?? data['customer'] ?? ''}\n'
                        'Status: ${data['status'] ?? ''}'
                        '${deliveryOnly ? '\nDriver: ${data['driverName'] ?? ''}' : ''}\n'
                        'Amount: Rs. ${data['amount'] ?? data['finalTotal'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Permanent Delete',
                        onPressed: () {
                          _deleteOrder(
                            context,
                            doc.id,
                          );
                        },
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminKrishiCustomersPage extends StatelessWidget {
  final Future<Set<String>> Function() sellerIdsLoader;
  final bool Function(
    Map<String, dynamic>,
    Set<String>,
  ) isKrishiOrder;

  const _AdminKrishiCustomersPage({
    required this.sellerIdsLoader,
    required this.isKrishiOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Customers'),
      ),
      body: FutureBuilder<Set<String>>(
        future: sellerIdsLoader(),
        builder: (
          BuildContext context,
          AsyncSnapshot<Set<String>> sellerSnapshot,
        ) {
          if (!sellerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<
                      QuerySnapshot<
                          Map<String, dynamic>>>
                  snapshot,
            ) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final Map<String, Map<String, dynamic>>
                  customers =
                  <String, Map<String, dynamic>>{};

              for (final doc in snapshot.data!.docs) {
                final data = doc.data();

                if (!isKrishiOrder(
                  data,
                  sellerSnapshot.data!,
                )) {
                  continue;
                }

                final String id =
                    data['customerId']
                            ?.toString()
                            .trim() ??
                        data['customerPhone']
                            ?.toString()
                            .trim() ??
                        doc.id;

                customers[id] = data;
              }

              if (customers.isEmpty) {
                return const Center(
                  child: Text(
                    'No Krishi customers yet.',
                  ),
                );
              }

              final entries =
                  customers.entries.toList();

              return ListView.builder(
                padding:
                    const EdgeInsets.all(12),
                itemCount: entries.length,
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  final data =
                      entries[index].value;

                  return Card(
                    child: ListTile(
                      leading:
                          const CircleAvatar(
                        child: Icon(
                          Icons.person_rounded,
                        ),
                      ),
                      title: Text(
                        data['customerName']
                                ?.toString() ??
                            data['customer']
                                ?.toString() ??
                            'Customer',
                      ),
                      subtitle: Text(
                        '${data['customerPhone'] ?? data['phone'] ?? ''}\n'
                        '${data['customerAddress'] ?? data['address'] ?? ''}',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminKrishiEarningsPage extends StatefulWidget {
  final Future<Set<String>> Function() sellerIdsLoader;
  final bool Function(
    Map<String, dynamic>,
    Set<String>,
  ) isKrishiOrder;

  const _AdminKrishiEarningsPage({
    required this.sellerIdsLoader,
    required this.isKrishiOrder,
  });

  @override
  State<_AdminKrishiEarningsPage> createState() =>
      _AdminKrishiEarningsPageState();
}

class _AdminKrishiEarningsPageState
    extends State<_AdminKrishiEarningsPage> {
  String _selectedPeriod = 'Today';

  static const List<String> _periods = <String>[
    'Today',
    'This Week',
    'This Month',
    'This Year',
    'All Time',
  ];

  double _money(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value
              ?.toString()
              .replaceAll('Rs.', '')
              .replaceAll('Rs', '')
              .replaceAll(',', '')
              .trim() ??
              '',
        ) ??
        0;
  }

  String _moneyText(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    if (value is DateTime) {
      return value.toLocal();
    }

    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(text)?.toLocal();
  }

  DateTime? _orderDate(Map<String, dynamic> order) {
    return _parseDate(
      order['orderDateTime'] ??
          order['createdAt'] ??
          order['updatedAt'],
    );
  }

  DateTime? _deliveredDate(Map<String, dynamic> order) {
    return _parseDate(
      order['deliveredAt'] ??
          order['deliveryOtpVerifiedAt'] ??
          order['updatedAt'] ??
          order['orderDateTime'] ??
          order['createdAt'],
    );
  }

  bool _matchesPeriod(
    DateTime? date,
    String period,
  ) {
    if (period == 'All Time') {
      return true;
    }

    if (date == null) {
      return false;
    }

    final DateTime now = DateTime.now();
    final DateTime local = date.toLocal();

    if (period == 'Today') {
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }

    if (period == 'This Week') {
      final DateTime startOfToday = DateTime(
        now.year,
        now.month,
        now.day,
      );
      final DateTime weekStart = startOfToday.subtract(
        Duration(days: now.weekday - DateTime.monday),
      );
      final DateTime nextWeek =
          weekStart.add(const Duration(days: 7));

      return !local.isBefore(weekStart) &&
          local.isBefore(nextWeek);
    }

    if (period == 'This Month') {
      return local.year == now.year &&
          local.month == now.month;
    }

    if (period == 'This Year') {
      return local.year == now.year;
    }

    return true;
  }

  bool _isDelivered(Map<String, dynamic> order) {
    final String status =
        order['status']?.toString().trim().toLowerCase() ?? '';
    final String trackingStatus = order['trackingStatus']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    return status == 'delivered' ||
        trackingStatus == 'delivered' ||
        order['deliveryOtpVerified'] == true;
  }

  double _commissionForOrder(Map<String, dynamic> order) {
    final double direct = _money(
      order['platformCommission'] ??
          order['commissionAmount'] ??
          order['nrdCommission'] ??
          order['adminCommission'],
    );

    if (direct > 0) {
      return direct;
    }

    final dynamic rawSettlements = order['sellerSettlements'];
    if (rawSettlements is! Map) {
      return 0;
    }

    double total = 0;

    rawSettlements.forEach((dynamic key, dynamic rawValue) {
      if (rawValue is! Map) {
        return;
      }

      final Map<String, dynamic> settlement =
          Map<String, dynamic>.from(rawValue);

      final double recordedCommission = _money(
        settlement['commissionAmount'] ??
            settlement['platformCommission'] ??
            settlement['nrdCommission'],
      );

      if (recordedCommission > 0) {
        total += recordedCommission;
        return;
      }

      final double gross = _money(
        settlement['grossAmount'] ??
            settlement['amount'],
      );
      final double percent =
          _money(settlement['commissionPercent']);

      if (gross > 0 && percent > 0) {
        total += gross * percent / 100;
      }
    });

    return total;
  }

  double _sellerPayableForOrder(
    Map<String, dynamic> order,
    double deliveredGross,
    double commission,
  ) {
    final dynamic rawSettlements = order['sellerSettlements'];

    if (rawSettlements is Map) {
      double total = 0;
      bool found = false;

      rawSettlements.forEach((dynamic key, dynamic rawValue) {
        if (rawValue is! Map) {
          return;
        }

        final Map<String, dynamic> settlement =
            Map<String, dynamic>.from(rawValue);

        final dynamic rawPayable = settlement['sellerPayable'];
        if (rawPayable != null) {
          total += _money(rawPayable);
          found = true;
        }
      });

      if (found) {
        return total;
      }
    }

    final double direct = _money(
      order['sellerPayable'] ??
          order['sellerNetAmount'],
    );

    if (direct > 0) {
      return direct;
    }

    final double fallback = deliveredGross - commission;
    return fallback < 0 ? 0 : fallback;
  }

  _KrishiEarningsSummary _summaryFor(
    List<Map<String, dynamic>> orders,
    String period,
  ) {
    int totalOrders = 0;
    int deliveredOrders = 0;
    double gross = 0;
    double deliveredGross = 0;
    double commission = 0;
    double sellerPayable = 0;

    for (final Map<String, dynamic> order in orders) {
      final DateTime? orderDate = _orderDate(order);

      if (_matchesPeriod(orderDate, period)) {
        totalOrders++;
        gross += _money(
          order['amount'] ??
              order['finalTotal'] ??
              order['subtotal'],
        );
      }

      if (!_isDelivered(order)) {
        continue;
      }

      final DateTime? deliveryDate =
          _deliveredDate(order);

      if (!_matchesPeriod(deliveryDate, period)) {
        continue;
      }

      deliveredOrders++;

      final double amount = _money(
        order['amount'] ??
            order['finalTotal'] ??
            order['subtotal'],
      );

      deliveredGross += amount;

      final double orderCommission =
          _commissionForOrder(order);
      commission += orderCommission;
      sellerPayable += _sellerPayableForOrder(
        order,
        amount,
        orderCommission,
      );
    }

    return _KrishiEarningsSummary(
      totalOrders: totalOrders,
      deliveredOrders: deliveredOrders,
      gross: gross,
      deliveredGross: deliveredGross,
      commission: commission,
      sellerPayable: sellerPayable,
    );
  }

  Widget _periodCard(
    String title,
    _KrishiEarningsSummary summary,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor:
                      Colors.green.withValues(alpha: 0.12),
                  child: Icon(
                    icon,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Delivered Sales',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Rs. ${_moneyText(summary.deliveredGross)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.deliveredOrders} delivered / '
              '${summary.totalOrders} orders',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gross: Rs. ${_moneyText(summary.gross)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String title,
    String value,
    IconData icon, {
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Colors.green.withValues(alpha: 0.12),
          child: Icon(
            icon,
            color: Colors.green,
          ),
        ),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periods.map<Widget>((String period) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: _selectedPeriod == period,
              onSelected: (_) {
                setState(() {
                  _selectedPeriod = period;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Earnings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: FutureBuilder<Set<String>>(
        future: widget.sellerIdsLoader(),
        builder: (
          BuildContext context,
          AsyncSnapshot<Set<String>> sellerSnapshot,
        ) {
          if (sellerSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Krishi sellers.\n'
                  '${sellerSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!sellerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<
                      QuerySnapshot<Map<String, dynamic>>>
                  snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load Krishi earnings.\n'
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final List<Map<String, dynamic>> orders =
                  <Map<String, dynamic>>[];

              for (final QueryDocumentSnapshot<
                      Map<String, dynamic>> doc
                  in snapshot.data!.docs) {
                final Map<String, dynamic> data =
                    <String, dynamic>{
                  ...doc.data(),
                  '_documentId': doc.id,
                };

                if (!widget.isKrishiOrder(
                  data,
                  sellerSnapshot.data!,
                )) {
                  continue;
                }

                orders.add(data);
              }

              final _KrishiEarningsSummary today =
                  _summaryFor(orders, 'Today');
              final _KrishiEarningsSummary week =
                  _summaryFor(orders, 'This Week');
              final _KrishiEarningsSummary month =
                  _summaryFor(orders, 'This Month');
              final _KrishiEarningsSummary year =
                  _summaryFor(orders, 'This Year');
              final _KrishiEarningsSummary allTime =
                  _summaryFor(orders, 'All Time');
              final _KrishiEarningsSummary selected =
                  _summaryFor(orders, _selectedPeriod);

              return LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final int columns =
                      constraints.maxWidth >= 1100
                          ? 5
                          : constraints.maxWidth >= 760
                              ? 3
                              : constraints.maxWidth >= 520
                                  ? 2
                                  : 1;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      const Text(
                        'Earnings Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Krishi orders only • Delivered sales are counted on the delivery date.',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio:
                            constraints.maxWidth >= 1100
                                ? 1.15
                                : 1.35,
                        children: <Widget>[
                          _periodCard(
                            'Today',
                            today,
                            Icons.today_rounded,
                          ),
                          _periodCard(
                            'This Week',
                            week,
                            Icons.view_week_rounded,
                          ),
                          _periodCard(
                            'This Month',
                            month,
                            Icons.calendar_month_rounded,
                          ),
                          _periodCard(
                            'This Year',
                            year,
                            Icons.calendar_today_rounded,
                          ),
                          _periodCard(
                            'All Time',
                            allTime,
                            Icons
                                .account_balance_wallet_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Detailed Breakdown',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _periodSelector(),
                      const SizedBox(height: 12),
                      _metric(
                        'Total Orders',
                        selected.totalOrders.toString(),
                        Icons.receipt_long_rounded,
                      ),
                      _metric(
                        'Gross Order Value',
                        'Rs. ${_moneyText(selected.gross)}',
                        Icons.payments_rounded,
                        subtitle:
                            'All Krishi orders in $_selectedPeriod',
                      ),
                      _metric(
                        'Delivered Orders',
                        selected.deliveredOrders.toString(),
                        Icons.check_circle_rounded,
                      ),
                      _metric(
                        'Delivered Sales',
                        'Rs. ${_moneyText(selected.deliveredGross)}',
                        Icons
                            .account_balance_wallet_rounded,
                        subtitle:
                            'Completed deliveries in $_selectedPeriod',
                      ),
                      _metric(
                        'NRD Platform Earnings',
                        'Rs. ${_moneyText(selected.commission)}',
                        Icons.trending_up_rounded,
                        subtitle:
                            'Recorded commission from delivered Krishi orders',
                      ),
                      _metric(
                        'Seller Payable',
                        'Rs. ${_moneyText(selected.sellerPayable)}',
                        Icons.storefront_rounded,
                        subtitle:
                            'Delivered sales minus recorded platform commission',
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selected.commission > 0
                                      ? 'NRD Platform Earnings uses the commission values already saved in each delivered order.'
                                      : 'No commission value is saved in these delivered Krishi orders yet, so NRD Platform Earnings is Rs. 0. Net Profit is not shown because business expense data is not recorded.',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _KrishiEarningsSummary {
  final int totalOrders;
  final int deliveredOrders;
  final double gross;
  final double deliveredGross;
  final double commission;
  final double sellerPayable;

  const _KrishiEarningsSummary({
    required this.totalOrders,
    required this.deliveredOrders,
    required this.gross,
    required this.deliveredGross,
    required this.commission,
    required this.sellerPayable,
  });
}
