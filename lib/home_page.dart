import 'package:flutter/material.dart';
import 'cart_page.dart';
import 'product_card.dart';
import 'profile_page.dart';
import 'order_history_page.dart';
import 'admin_dashboard_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "RD Online Shop",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,

        actions: [
          // CART
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: "Cart",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartPage(),
                ),
              );
            },
          ),

          // MY ORDERS
          IconButton(
            icon: const Icon(Icons.local_shipping),
            tooltip: "My Orders",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const OrderHistoryPage(),
                ),
              );
            },
          ),

          // PROFILE
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
            },
          ),

          // ADMIN DASHBOARD
          IconButton(
            icon: const Icon(
              Icons.admin_panel_settings,
            ),
            tooltip: "Admin Dashboard",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const AdminDashboardPage(),
                ),
              );
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(10),
        children: const [
          ProductCard(
            name: "Samsung Galaxy A56",
            price: "Rs. 45,000",
            icon: Icons.phone_android,
          ),

          ProductCard(
            name: "iPhone 16 Pro Max",
            price: "Rs. 210,000",
            icon: Icons.phone_iphone,
          ),

          ProductCard(
            name: "Redmi Note 14",
            price: "Rs. 32,000",
            icon: Icons.smartphone,
          ),

          ProductCard(
            name: "Vivo V50",
            price: "Rs. 52,000",
            icon: Icons.smartphone,
          ),
        ],
      ),
    );
  }
}