import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_earnings_page.dart';
import 'admin_notification_center_page.dart';
import 'admin_order_page.dart';
import 'admin_product_page.dart';
import 'admin_ride_driver_management_page.dart';
import 'admin_ride_history_page.dart';
import 'admin_ride_fare_settings_page.dart';
import 'admin_seller_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Admin Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!context.mounted) return;
    Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
  }

  bool _isAllowedAdmin(Map<String, dynamic> admin) {
    final String role = admin['role']?.toString().trim() ?? '';
    return admin['isActive'] == true &&
        (role == 'admin' || role == 'superAdmin');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return _accessDenied(context, 'Admin login required.');
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _accessDenied(
            context,
            'Could not verify Admin access.\n${snapshot.error}',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>>? document =
            snapshot.data;
        final Map<String, dynamic> admin =
            document?.data() ?? <String, dynamic>{};

        if (document == null ||
            !document.exists ||
            !_isAllowedAdmin(admin)) {
          return _accessDenied(context, 'Active Admin access required.');
        }

        return _dashboard(context);
      },
    );
  }

  Widget _dashboard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Admin Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: <Widget>[
          _dashboardCard(
            icon: Icons.shopping_bag,
            title: 'Orders',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminOrderPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.inventory_2,
            title: 'Products',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminProductPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.store,
            title: 'Sellers',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminSellerPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.people,
            title: 'Customers',
            onTap: () => _comingSoon(context, 'Customer Management'),
          ),
          _dashboardCard(
            icon: Icons.account_balance_wallet,
            title: 'Earnings',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminEarningsPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.notifications_active,
            title: 'Notifications',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminNotificationCenterPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.drive_eta_rounded,
            title: 'Ride Drivers',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminRideDriverManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.payments_rounded,
            title: 'Ride Fares',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideFareSettingsPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.route_rounded,
            title: 'Ride History',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideHistoryPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _comingSoon(context, 'Admin Settings'),
          ),
        ],
      ),
    );
  }

  Widget _accessDenied(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon.')),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 45),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
