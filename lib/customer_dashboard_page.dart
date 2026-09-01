import 'package:flutter/material.dart';

import 'cart_page.dart';
import 'order_data.dart';
import 'order_history_page.dart';
import 'wishlist_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  State<CustomerDashboardPage> createState() =>
      _CustomerDashboardPageState();
}

class _CustomerDashboardPageState
    extends State<CustomerDashboardPage> {
  static const Color _rdRed = Color(0xFFE50914);

  String _customerId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    try {
      final String id = await getOrCreateCustomerId();
      await loadOrders();

      if (!mounted) return;

      setState(() {
        _customerId = id;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _customerId = '';
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _dashboardButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: _rdRed.withValues(alpha: 0.10),
          child: Icon(
            icon,
            color: _rdRed,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadCustomer,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: _rdRed,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 64,
                          height: 64,
                          decoration:
                              const BoxDecoration(
                            color: _rdRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'RD Customer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Opens automatically — no ID or password needed.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (_customerId.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  'Customer ID: $_customerId',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _dashboardButton(
                    icon: Icons.inventory_2_outlined,
                    title: 'My Orders',
                    subtitle:
                        'See only this customer’s orders and tracking.',
                    onTap: () {
                      _open(
                        const OrderHistoryPage(),
                      );
                    },
                  ),
                  _dashboardButton(
                    icon: Icons.favorite_border_rounded,
                    title: 'Wishlist',
                    subtitle:
                        'Products saved for later.',
                    onTap: () {
                      _open(
                        const WishlistPage(),
                      );
                    },
                  ),
                  _dashboardButton(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart',
                    subtitle:
                        'Products ready for checkout.',
                    onTap: () {
                      _open(
                        const CartPage(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          color: _rdRed,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Customer Dashboard does not ask for a Seller ID, customer ID, or password. The app keeps the customer identity automatically on this device.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
