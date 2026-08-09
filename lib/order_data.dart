import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> orderHistory = [];

const List<String> orderStatuses = [
  "Pending",
  "Confirmed",
  "Packed",
  "Shipped",
  "Out for Delivery",
  "Delivered",
];

// LOAD ORDERS
Future<void> loadOrders() async {
  final prefs = await SharedPreferences.getInstance();

  final String? savedOrders =
      prefs.getString("orderHistory");

  if (savedOrders != null &&
      savedOrders.isNotEmpty) {
    try {
      final List<dynamic> decoded =
          jsonDecode(savedOrders);

      orderHistory = decoded
          .map(
            (item) =>
                Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      orderHistory = [];
    }
  }
}

// SAVE ORDERS
Future<void> saveOrders() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setString(
    "orderHistory",
    jsonEncode(orderHistory),
  );
}

// ADD NEW ORDER
Future<void> addOrder(
  Map<String, dynamic> order,
) async {
  orderHistory.insert(0, order);

  await saveOrders();
}

// UPDATE ORDER STATUS
Future<void> updateOrderStatus(
  String orderId,
  String newStatus,
) async {
  final index = orderHistory.indexWhere(
    (order) =>
        order["id"].toString() == orderId,
  );

  if (index != -1) {
    orderHistory[index]["status"] =
        newStatus;

    await saveOrders();
  }
}