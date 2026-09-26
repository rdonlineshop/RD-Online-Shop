import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_krishi_seller_page.dart';

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
                  trailing: Switch(
                    value: active,
                    onChanged: (bool value) {
                      _toggle(doc.id, value);
                    },
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
                        '${deliveryOnly ? '\nDriver: ${data['driverName'] ?? ''}' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        'Rs. ${data['amount'] ?? data['finalTotal'] ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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

class _AdminKrishiEarningsPage extends StatelessWidget {
  final Future<Set<String>> Function() sellerIdsLoader;
  final bool Function(
    Map<String, dynamic>,
    Set<String>,
  ) isKrishiOrder;

  const _AdminKrishiEarningsPage({
    required this.sellerIdsLoader,
    required this.isKrishiOrder,
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Earnings'),
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

              int orderCount = 0;
              int deliveredCount = 0;
              double gross = 0;
              double deliveredGross = 0;

              for (final doc in snapshot.data!.docs) {
                final data = doc.data();

                if (!isKrishiOrder(
                  data,
                  sellerSnapshot.data!,
                )) {
                  continue;
                }

                orderCount++;
                final double amount = _money(
                  data['amount'] ??
                      data['finalTotal'],
                );
                gross += amount;

                if (data['status']
                        ?.toString()
                        .toLowerCase() ==
                    'delivered') {
                  deliveredCount++;
                  deliveredGross += amount;
                }
              }

              return ListView(
                padding:
                    const EdgeInsets.all(16),
                children: <Widget>[
                  _metric(
                    'Total Krishi Orders',
                    orderCount.toString(),
                    Icons.receipt_long_rounded,
                  ),
                  _metric(
                    'Gross Order Value',
                    'Rs. ${gross.toStringAsFixed(0)}',
                    Icons.payments_rounded,
                  ),
                  _metric(
                    'Delivered Orders',
                    deliveredCount.toString(),
                    Icons.check_circle_rounded,
                  ),
                  _metric(
                    'Delivered Gross Value',
                    'Rs. ${deliveredGross.toStringAsFixed(0)}',
                    Icons
                        .account_balance_wallet_rounded,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _metric(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
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
}
