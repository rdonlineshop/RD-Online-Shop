import 'package:flutter/material.dart';
import 'order_data.dart';

class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({super.key});

  @override
  State<AdminOrderPage> createState() => _AdminOrderPageState();
}

class _AdminOrderPageState extends State<AdminOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Order Management",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: orderHistory.isEmpty
          ? const Center(
              child: Text(
                "No Orders Yet",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orderHistory.length,
              itemBuilder: (context, index) {
                final order = orderHistory[index];

                String currentStatus =
                    order["status"] ?? "Pending";

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order ID: ${order["id"]}",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Customer: ${order["name"]}",
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Mobile: ${order["phone"]}",
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Amount: Rs. ${order["amount"]}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          "Payment: ${order["payment"]}",
                        ),

                        const Divider(height: 25),

                        const Text(
                          "Change Order Status",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          value: currentStatus,
                          decoration:
                              const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon:
                                Icon(Icons.local_shipping),
                          ),
                          items: orderStatuses
                              .map(
                                (status) =>
                                    DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (newStatus) {
                            if (newStatus == null) {
                              return;
                            }

                            setState(() {
                              order["status"] = newStatus;
                            });

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Order status changed to $newStatus",
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 15),

                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(10),
                            color: Colors.grey.shade100,
                          ),
                          child: Text(
                            "Current Status: $currentStatus",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}