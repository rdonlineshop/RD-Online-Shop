import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_auth_page.dart';
import 'order_data.dart';
import 'order_details_page.dart';

class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({super.key});

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  final TextEditingController searchController = TextEditingController();
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    searchController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Shipped':
        return Colors.deepPurple;
      case 'Delivered':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _filtered(
    List<Map<String, dynamic>> orders,
  ) {
    final String search = searchController.text.trim().toLowerCase();

    return orders.where((Map<String, dynamic> order) {
      final String status = order['status']?.toString() ?? 'Pending';
      final String id = order['id']?.toString().toLowerCase() ?? '';
      final String name = (order['customerName'] ?? order['name'] ?? '')
          .toString()
          .toLowerCase();
      final String phone = order['phone']?.toString().toLowerCase() ?? '';

      final bool matchesSearch = search.isEmpty ||
          id.contains(search) ||
          name.contains(search) ||
          phone.contains(search);

      final bool matchesFilter =
          selectedFilter == 'All' || status == selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int _countStatus(List<Map<String, dynamic>> orders, String status) {
    return orders
        .where((Map<String, dynamic> order) =>
            (order['status'] ?? 'Pending').toString() == status)
        .length;
  }

  Future<void> _changeStatus(String orderId, String newStatus) async {
    try {
      await updateOrderStatus(orderId, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status changed to $newStatus')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update order: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget _statusChip(
    List<Map<String, dynamic>> orders,
    String status,
    IconData icon,
  ) {
    final Color color = _statusColor(status);
    final int count = _countStatus(orders, status);
    final bool selected = selectedFilter == status;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          selectedFilter = selected ? 'All' : status;
        });
      },
      avatar: Icon(icon, size: 18, color: color),
      label: Text('$status ($count)'),
    );
  }

  Future<bool> _hasAdminAccess() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

    if (!doc.exists) {
      return false;
    }

    final Map<String, dynamic> data =
        doc.data() ?? <String, dynamic>{};
    final String role = data['role']?.toString().trim() ?? '';

    return data['isActive'] == true &&
        (role == 'admin' || role == 'superAdmin');
  }

  Widget _adminLoginRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 72,
              color: Colors.orange,
            ),
            const SizedBox(height: 14),
            const Text(
              'Admin login required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please login with an active RD Online Shop Admin account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AdminAuthPage(),
                  ),
                );

                if (mounted) {
                  setState(() {});
                }
              },
              icon: const Icon(Icons.login),
              label: const Text('Admin Login'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (
          BuildContext context,
          AsyncSnapshot<User?> authSnapshot,
        ) {
          final User? user = authSnapshot.data;

          if (user == null || user.isAnonymous) {
            return _adminLoginRequired(context);
          }

          return FutureBuilder<bool>(
            future: _hasAdminAccess(),
            builder: (
              BuildContext context,
              AsyncSnapshot<bool> accessSnapshot,
            ) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (accessSnapshot.hasError || accessSnapshot.data != true) {
                return _adminLoginRequired(context);
              }

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: adminOrdersStream(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not load all orders.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<Map<String, dynamic>> allOrders =
              snapshot.data ?? <Map<String, dynamic>>[];
          final List<Map<String, dynamic>> orders = _filtered(allOrders);

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Order ID, Customer or Mobile',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    ChoiceChip(
                      selected: selectedFilter == 'All',
                      onSelected: (_) {
                        setState(() => selectedFilter = 'All');
                      },
                      avatar: const Icon(Icons.list_alt, size: 18),
                      label: Text('All (${allOrders.length})'),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Pending', Icons.pending_actions),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Confirmed', Icons.check_circle),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Processing', Icons.sync),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Shipped', Icons.local_shipping),
                    const SizedBox(width: 8),
                    _statusChip(allOrders, 'Delivered', Icons.inventory_2),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: allOrders.isEmpty
                    ? const Center(child: Text('No Orders Yet'))
                    : orders.isEmpty
                        ? const Center(child: Text('No matching orders'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: orders.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Map<String, dynamic> order = orders[index];
                              final String status =
                                  order['status']?.toString() ?? 'Pending';
                              final Color color = _statusColor(status);
                              final String customerName =
                                  (order['customerName'] ??
                                          order['name'] ??
                                          'Customer')
                                      .toString();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Order ID: ${order['id'] ?? '-'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Customer: $customerName'),
                                      Text('Mobile: ${order['phone'] ?? '-'}'),
                                      Text('Amount: Rs. ${order['amount'] ?? '0'}'),
                                      Text('Payment: ${order['payment'] ?? '-'}'),
                                      Text(
                                        'Address: ${order['address'] ?? 'Address not available'}',
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: color),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: color.withValues(alpha: 0.08),
                                        ),
                                        child: Text(
                                          'Current Status: $status',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        key: ValueKey<String>(
                                          '${order['id']}_$status',
                                        ),
                                        initialValue:
                                            orderStatuses.contains(status)
                                                ? status
                                                : 'Pending',
                                        decoration: const InputDecoration(
                                          labelText: 'Change Order Status',
                                          border: OutlineInputBorder(),
                                          prefixIcon:
                                              Icon(Icons.local_shipping),
                                        ),
                                        items: orderStatuses
                                            .map(
                                              (String item) =>
                                                  DropdownMenuItem<String>(
                                                value: item,
                                                child: Text(item),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (String? value) {
                                          if (value == null || value == status) {
                                            return;
                                          }
                                          _changeStatus(
                                            order['id'].toString(),
                                            value,
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push<void>(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    OrderDetailsPage(
                                                  order: order,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.visibility),
                                          label:
                                              const Text('View Order Details'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
