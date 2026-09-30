import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cart_page.dart';
import 'customer_auth_page.dart';
import 'order_data.dart';
import 'order_history_page.dart';
import 'wishlist_page.dart';

class CustomerDashboardPage extends StatefulWidget {
  const CustomerDashboardPage({
    super.key,
    this.krishiOnly = false,
  });

  final bool krishiOnly;

  @override
  State<CustomerDashboardPage> createState() =>
      _CustomerDashboardPageState();
}

class _CustomerDashboardPageState
    extends State<CustomerDashboardPage> {
  static const Color _rdRed = Color(0xFFE50914);

  String _customerEmail = '';
  bool _customerLoggedIn = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.isAnonymous) {
        if (!mounted) return;

        setState(() {
          _customerEmail = '';
          _customerLoggedIn = false;
          _loading = false;
        });
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> customerDocument =
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> customer =
          customerDocument.data() ?? <String, dynamic>{};

      final bool validCustomer =
          customerDocument.exists &&
          customer['role']?.toString().trim() == 'customer' &&
          customer['isActive'] != false;

      if (!validCustomer) {
        if (!mounted) return;

        setState(() {
          _customerEmail = '';
          _customerLoggedIn = false;
          _loading = false;
        });
        return;
      }

      await activateRegisteredCustomerSession(user);
      await loadOrders();

      if (!mounted) return;

      setState(() {
        _customerEmail =
            user.email?.trim().isNotEmpty == true
                ? user.email!.trim()
                : customer['email']?.toString().trim() ?? '';
        _customerLoggedIn = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _customerEmail = '';
        _customerLoggedIn = false;
        _loading = false;
      });
    }
  }

  Future<void> _openCustomerLogin() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => const CustomerAuthPage(),
      ),
    );

    if (!mounted) return;
    await _loadCustomer();
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
        title: Text(
          widget.krishiOnly
              ? 'Krishi Customer Dashboard'
              : 'Customer Dashboard',
          style: const TextStyle(
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
                              Text(
                                widget.krishiOnly
                                    ? 'NRD Krishi Customer'
                                    : 'NRD Customer',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _customerLoggedIn
                                    ? 'Orders are linked to your Customer Email account.'
                                    : 'Login with your Customer Email to see and track your orders.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (_customerLoggedIn &&
                                  _customerEmail.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  _customerEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ] else ...<Widget>[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _openCustomerLogin,
                                  icon: const Icon(
                                    Icons.login_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Customer Login'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
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
                    subtitle: widget.krishiOnly
                        ? 'See only this customer’s Krishi orders and tracking.'
                        : 'See only this customer’s orders and tracking.',
                    onTap: () {
                      if (!_customerLoggedIn) {
                        _openCustomerLogin();
                        return;
                      }

                      _open(
                        OrderHistoryPage(
                          krishiOnly: widget.krishiOnly,
                        ),
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
                            'Your orders are linked to your Customer Email account. No separate Customer ID is required. If Seller, Admin or Delivery was used, login again with the same Customer Email to open My Orders.',
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
