import 'package:flutter/material.dart';
import 'admin_order_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [

          // ORDERS
          _dashboardCard(
            context,
            icon: Icons.shopping_bag,
            title: "Orders",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminOrderPage(),
                ),
              );
            },
          ),

          // PRODUCTS
          _dashboardCard(
            context,
            icon: Icons.inventory_2,
            title: "Products",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Product Management coming soon.",
                  ),
                ),
              );
            },
          ),

          // SELLERS
          _dashboardCard(
            context,
            icon: Icons.store,
            title: "Sellers",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Seller Management coming soon.",
                  ),
                ),
              );
            },
          ),

          // CUSTOMERS
          _dashboardCard(
            context,
            icon: Icons.people,
            title: "Customers",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Customer Management coming soon.",
                  ),
                ),
              );
            },
          ),

          // PAYMENTS
          _dashboardCard(
            context,
            icon: Icons.payment,
            title: "Payments",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Payment Management coming soon.",
                  ),
                ),
              );
            },
          ),

          // SETTINGS
          _dashboardCard(
            context,
            icon: Icons.settings,
            title: "Settings",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Admin Settings coming soon.",
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
            Icon(
              icon,
              size: 45,
            ),

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