import 'package:flutter/material.dart';
import 'order_data.dart';
import 'order_details_page.dart';

class AdminOrderPage extends StatefulWidget {
  const AdminOrderPage({super.key});

  @override
  State<AdminOrderPage> createState() =>
      _AdminOrderPageState();
}

class _AdminOrderPageState
    extends State<AdminOrderPage> {
  bool isLoading = true;

  final TextEditingController searchController =
      TextEditingController();

  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();

    _loadOrders();

    searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==========================================
  // LOAD ORDERS
  // ==========================================

  Future<void> _loadOrders() async {
    await loadOrders();

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ==========================================
  // UPDATE STATUS
  // ==========================================

  Future<void> _changeStatus(
    String orderId,
    String newStatus,
  ) async {
    await updateOrderStatus(
      orderId,
      newStatus,
    );

    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Order status changed to $newStatus',
          ),
        ),
      );
    }
  }

  // ==========================================
  // COUNT ORDERS
  // ==========================================

  int _countStatus(String status) {
    return orderHistory.where((order) {
      final currentStatus =
          (order['status'] ?? 'Pending')
              .toString();

      return currentStatus == status;
    }).length;
  }

  // ==========================================
  // SEARCH + FILTER
  // ==========================================

  List<Map<String, dynamic>>
      get filteredOrders {
    final search =
        searchController.text
            .toLowerCase()
            .trim();

    return orderHistory.where((order) {
      final status =
          (order['status'] ?? 'Pending')
              .toString();

      final id =
          (order['id'] ?? '')
              .toString()
              .toLowerCase();

      final name =
          (order['name'] ?? '')
              .toString()
              .toLowerCase();

      final phone =
          (order['phone'] ?? '')
              .toString()
              .toLowerCase();

      final matchesSearch =
          search.isEmpty ||
              id.contains(search) ||
              name.contains(search) ||
              phone.contains(search);

      final matchesFilter =
          selectedFilter == 'All' ||
              status == selectedFilter;

      return matchesSearch &&
          matchesFilter;
    }).toList();
  }

  // ==========================================
  // STATUS COLOR
  // ==========================================

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

  // ==========================================
  // STATUS CARD
  // ==========================================

  Widget _statusCard(
    String title,
    String status,
    IconData icon,
  ) {
    final count =
        _countStatus(status);

    final color =
        _statusColor(status);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedFilter = status;
          });
        },
        child: Container(
          margin:
              const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          padding:
              const EdgeInsets.all(12),
          decoration:
              BoxDecoration(
            color:
                color.withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(14),
            border:
                Border.all(
              color:
                  color.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                  color: color,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Management',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : orderHistory.isEmpty
              ? const Center(
                  child: Text(
                    'No Orders Yet',
                    style:
                        TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                )
              : Column(
                  children: [

                    // ==================================
                    // DASHBOARD
                    // ==================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .all(10),

                      child: Row(
                        children: [

                          _statusCard(
                            'Pending',
                            'Pending',
                            Icons
                                .pending_actions,
                          ),

                          _statusCard(
                            'Confirmed',
                            'Confirmed',
                            Icons
                                .check_circle,
                          ),

                          _statusCard(
                            'Processing',
                            'Processing',
                            Icons.sync,
                          ),

                          _statusCard(
                            'Shipped',
                            'Shipped',
                            Icons
                                .local_shipping,
                          ),

                          _statusCard(
                            'Delivered',
                            'Delivered',
                            Icons
                                .inventory_2,
                          ),
                        ],
                      ),
                    ),

                    // ==================================
                    // SEARCH
                    // ==================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                      ),

                      child: TextField(
                        controller:
                            searchController,

                        decoration:
                            InputDecoration(
                          hintText:
                              'Search Order ID, Customer or Mobile',

                          prefixIcon:
                              const Icon(
                            Icons.search,
                          ),

                          suffixIcon:
                              searchController
                                      .text
                                      .isNotEmpty
                                  ? IconButton(
                                      icon:
                                          const Icon(
                                        Icons
                                            .clear,
                                      ),
                                      onPressed:
                                          () {
                                        searchController
                                            .clear();
                                      },
                                    )
                                  : null,

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ==================================
                    // FILTER
                    // ==================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                      ),

                      child:
                          DropdownButtonFormField<
                              String>(
                        initialValue:
                            selectedFilter,

                        decoration:
                            const InputDecoration(
                          labelText:
                              'Filter Orders',

                          border:
                              OutlineInputBorder(),

                          prefixIcon:
                              Icon(
                            Icons
                                .filter_list,
                          ),
                        ),

                        items: [
                          'All',
                          ...orderStatuses,
                        ].map(
                          (filter) {
                            return DropdownMenuItem<
                                String>(
                              value:
                                  filter,
                              child:
                                  Text(
                                filter,
                              ),
                            );
                          },
                        ).toList(),

                        onChanged:
                            (value) {
                          if (value ==
                              null) {
                            return;
                          }

                          setState(() {
                            selectedFilter =
                                value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ==================================
                    // ORDER LIST
                    // ==================================

                    Expanded(
                      child:
                          filteredOrders
                                  .isEmpty
                              ? const Center(
                                  child:
                                      Text(
                                    'No matching orders',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          18,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                )
                              : ListView
                                  .builder(
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    12,
                                  ),

                                  itemCount:
                                      filteredOrders
                                          .length,

                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final order =
                                        filteredOrders[
                                            index];

                                    final String
                                        currentStatus =
                                        (order['status'] ??
                                                'Pending')
                                            .toString();

                                    final statusColor =
                                        _statusColor(
                                      currentStatus,
                                    );

                                    return Card(
                                      margin:
                                          const EdgeInsets
                                              .only(
                                        bottom:
                                            16,
                                      ),

                                      elevation:
                                          3,

                                      child:
                                          Padding(
                                        padding:
                                            const EdgeInsets
                                                .all(
                                          16,
                                        ),

                                        child:
                                            Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,

                                          children: [

                                            // ORDER ID
                                            Text(
                                              "Order ID: ${order["id"]}",

                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    17,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  8,
                                            ),

                                            // CUSTOMER
                                            Text(
                                              "Customer: ${order["name"]}",

                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    16,
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  6,
                                            ),

                                            // MOBILE
                                            Text(
                                              "Mobile: ${order["phone"]}",
                                            ),

                                            const SizedBox(
                                              height:
                                                  6,
                                            ),

                                            // AMOUNT
                                            Text(
                                              "Amount: Rs. ${order["amount"]}",

                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  6,
                                            ),

                                            // PAYMENT
                                            Text(
                                              "Payment: ${order["payment"]}",
                                            ),

                                            const SizedBox(
                                              height:
                                                  6,
                                            ),

                                            // ADDRESS
                                            Text(
                                              "Address: ${order["address"] ?? "Address not available"}",
                                            ),

                                            const Divider(
                                              height:
                                                  25,
                                            ),

                                            // CURRENT STATUS
                                            Container(
                                              width:
                                                  double.infinity,

                                              padding:
                                                  const EdgeInsets
                                                      .all(
                                                12,
                                              ),

                                              decoration:
                                                  BoxDecoration(
                                                color: statusColor
                                                    .withValues(
                                                  alpha: 0.10,
                                                ),

                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  10,
                                                ),

                                                border:
                                                    Border
                                                        .all(
                                                  color:
                                                      statusColor,
                                                ),
                                              ),

                                              child:
                                                  Text(
                                                'Current Status: $currentStatus',

                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      16,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                  color:
                                                      statusColor,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  15,
                                            ),

                                            // CHANGE STATUS
                                            const Text(
                                              'Change Order Status',

                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    17,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),

                                            const SizedBox(
                                              height:
                                                  10,
                                            ),

                                            DropdownButtonFormField<
                                                String>(
                                              initialValue:
                                                  orderStatuses.contains(
                                                currentStatus,
                                              )
                                                      ? currentStatus
                                                      : 'Pending',

                                              decoration:
                                                  const InputDecoration(
                                                border:
                                                    OutlineInputBorder(),

                                                prefixIcon:
                                                    Icon(
                                                  Icons
                                                      .local_shipping,
                                                ),
                                              ),

                                              items:
                                                  orderStatuses
                                                      .map(
                                                (
                                                  status,
                                                ) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value:
                                                        status,

                                                    child:
                                                        Text(
                                                      status,
                                                    ),
                                                  );
                                                },
                                              ).toList(),

                                              onChanged:
                                                  (
                                                newStatus,
                                              ) {
                                                if (newStatus ==
                                                    null) {
                                                  return;
                                                }

                                                _changeStatus(
                                                  order['id']
                                                      .toString(),
                                                  newStatus,
                                                );
                                              },
                                            ),

                                            const SizedBox(
                                              height:
                                                  12,
                                            ),

                                            // ==================================
                                            // VIEW ORDER DETAILS
                                            // ==================================

                                            SizedBox(
                                              width:
                                                  double.infinity,

                                              child:
                                                  ElevatedButton
                                                      .icon(
                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .visibility,
                                                ),

                                                label:
                                                    const Text(
                                                  'View Order Details',
                                                  style:
                                                      TextStyle(
                                                    fontSize:
                                                        16,
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                  ),
                                                ),

                                                onPressed:
                                                    () {
                                                  Navigator
                                                      .push(
                                                    context,

                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                        context,
                                                      ) =>
                                                          OrderDetailsPage(
                                                        order:
                                                            order,
                                                      ),
                                                    ),
                                                  );
                                                },
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
                ),
    );
  }
}