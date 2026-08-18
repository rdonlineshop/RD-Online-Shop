import 'package:flutter/material.dart';

import 'admin_order_page.dart';
import 'admin_product_page.dart';
import 'admin_seller_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _dashboardCard(
            context,
            icon: Icons.shopping_bag,
            title: 'Orders',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminOrderPage()),
            ),
          ),
          _dashboardCard(
            context,
            icon: Icons.inventory_2,
            title: 'Products',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProductPage()),
            ),
          ),
          _dashboardCard(
            context,
            icon: Icons.store,
            title: 'Sellers',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSellerPage()),
            ),
          ),
          _dashboardCard(
            context,
            icon: Icons.people,
            title: 'Customers',
            onTap: () => _comingSoon(context, 'Customer Management'),
          ),
          _dashboardCard(
            context,
            icon: Icons.payment,
            title: 'Payments',
            onTap: () => _comingSoon(context, 'Payment Management'),
          ),
          _dashboardCard(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _comingSoon(context, 'Admin Settings'),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon.')),
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
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
          children: [
            Icon(icon, size: 45),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
