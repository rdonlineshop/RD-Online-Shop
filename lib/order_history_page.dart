import 'package:flutter/material.dart';

import 'order_data.dart';

class OrderHistoryPage
    extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() =>
      _OrderHistoryPageState();
}

class _OrderHistoryPageState
    extends State<OrderHistoryPage> {

  bool isLoading = true;

  // ==========================================
  // LOAD SAVED ORDERS
  // ==========================================

  @override
  void initState() {
    super.initState();

    _loadOrders();
  }

  Future<void> _loadOrders() async {
    await loadOrders();

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==========================================
  // GET STATUS INDEX
  // ==========================================

  int getStatusIndex(
    String status,
  ) {
    final String value =
        status.toLowerCase().trim();

    if (value == "pending") {
      return 0;
    }

    if (value == "confirmed") {
      return 1;
    }

    if (value == "packed") {
      return 2;
    }

    if (value == "shipped") {
      return 3;
    }

    if (value ==
        "out for delivery") {
      return 4;
    }

    if (value == "delivered") {
      return 5;
    }

    return 0;
  }

  // ==========================================
  // ORDER STATUS
  // ==========================================

  String getOrderStatus(
    Map<String, dynamic> order,
  ) {
    final status =
        order["status"];

    if (status == null ||
        status
            .toString()
            .trim()
            .isEmpty) {
      return "Pending";
    }

    return status.toString();
  }

  // ==========================================
  // ORDER ID
  // ==========================================

  String getOrderId(
    Map<String, dynamic> order,
  ) {
    return (order["id"] ??
            order["orderId"] ??
            "RD000000")
        .toString();
  }

  // ==========================================
  // AMOUNT
  // ==========================================

  String getAmount(
    Map<String, dynamic> order,
  ) {
    return (order["amount"] ?? "0")
        .toString();
  }

  // ==========================================
  // CUSTOMER
  // ==========================================

  String getCustomer(
    Map<String, dynamic> order,
  ) {
    return (order["name"] ??
            "Customer")
        .toString();
  }

  // ==========================================
  // PHONE
  // ==========================================

  String getMobile(
    Map<String, dynamic> order,
  ) {
    return (order["phone"] ?? "")
        .toString();
  }

  // ==========================================
  // PAYMENT
  // ==========================================

  String getPayment(
    Map<String, dynamic> order,
  ) {
    return (order["payment"] ??
            "Cash on Delivery")
        .toString();
  }

  // ==========================================
  // ADDRESS
  // ==========================================

  String getAddress(
    Map<String, dynamic> order,
  ) {
    return (order["address"] ??
            "Address not available")
        .toString();
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xfffcf5fc),

      appBar: AppBar(
        backgroundColor:
            const Color(0xfffcf5fc),

        elevation: 0,

        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
            size: 30,
          ),

          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "My Orders",

          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : orderHistory.isEmpty
              ? const Center(
                  child: Text(
                    "No orders yet",

                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  itemCount:
                      orderHistory.length,

                  itemBuilder:
                      (context, index) {
                    final order =
                        orderHistory[index];

                    return _buildOrderCard(
                      context,
                      order,
                    );
                  },
                ),
    );
  }

  // ==========================================
  // ORDER CARD
  // ==========================================

  Widget _buildOrderCard(
    BuildContext context,
    Map<String, dynamic> order,
  ) {
    final String currentStatus =
        getOrderStatus(order);

    final int currentIndex =
        getStatusIndex(
      currentStatus,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),

      padding:
          const EdgeInsets.all(28),

      decoration:
          BoxDecoration(
        color:
            const Color(0xfffaf5fa),

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.15),

            blurRadius: 8,

            offset:
                const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // ORDER ID
          Text(
            "Order ID: ${getOrderId(order)}",

            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 14),

          // AMOUNT
          Text(
            "Amount: Rs. ${getAmount(order)}",

            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 22),

          const Divider(
            thickness: 1,
            color: Colors.black26,
          ),

          const SizedBox(height: 24),

          // ORDER STATUS
          const Text(
            "Order Status",

            style:
                TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 25),

          // TIMELINE
          _buildStatusTimeline(
            currentIndex,
          ),

          const SizedBox(height: 25),

          // CUSTOMER
          Text(
            "Customer: ${getCustomer(order)}",

            style:
                const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          // MOBILE
          if (getMobile(order)
              .isNotEmpty)
            Text(
              "Mobile: ${getMobile(order)}",

              style:
                  const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
            ),

          const SizedBox(height: 10),

          // PAYMENT
          Text(
            "Payment: ${getPayment(order)}",

            style:
                const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          // ADDRESS
          Text(
            "Address: ${getAddress(order)}",

            style:
                const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATUS TIMELINE
  // ==========================================

  Widget _buildStatusTimeline(
    int currentIndex,
  ) {
    return Column(
      children:
          List.generate(
        orderStatuses.length,
        (index) {

          final bool completed =
              index <= currentIndex;

          final bool isLast =
              index ==
                  orderStatuses.length - 1;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // LEFT TIMELINE
              SizedBox(
                width: 64,

                child: Column(
                  children: [

                    // CIRCLE
                    Container(
                      width: 44,
                      height: 44,

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,

                        color: completed
                            ? Colors.green
                            : Colors.grey
                                .shade300,
                      ),

                      child: completed
                          ? const Icon(
                              Icons.check,
                              color:
                                  Colors.white,
                              size: 28,
                            )
                          : Icon(
                              Icons.circle,
                              color: Colors
                                  .grey
                                  .shade500,
                              size: 12,
                            ),
                    ),

                    // LINE
                    if (!isLast)
                      Container(
                        width: 4,
                        height: 55,

                        color: index <
                                currentIndex
                            ? Colors.green
                            : Colors.grey
                                .shade300,
                      ),
                  ],
                ),
              ),

              // STATUS TEXT
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 7,
                    left: 2,
                  ),

                  child: Text(
                    orderStatuses[index],

                    style:
                        TextStyle(
                      fontSize: 21,

                      fontWeight:
                          completed
                              ? FontWeight.bold
                              : FontWeight.w500,

                      color: completed
                          ? Colors.black
                          : Colors.grey
                              .shade600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}