import 'package:flutter/material.dart';
import 'order_data.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsPage> createState() =>
      _OrderDetailsPageState();
}

class _OrderDetailsPageState
    extends State<OrderDetailsPage> {
  late Map<String, dynamic> order;

  @override
  void initState() {
    super.initState();

    order = widget.order;
  }

  // =====================================
  // STATUS
  // =====================================

  String get status {
    return (order['status'] ?? 'Pending')
        .toString();
  }

  // =====================================
  // STATUS INDEX
  // =====================================

  int getStatusIndex(String value) {
    switch (value.toLowerCase().trim()) {
      case 'pending':
        return 0;

      case 'confirmed':
        return 1;

      case 'processing':
        return 2;

      case 'shipped':
        return 3;

      case 'delivered':
        return 4;

      default:
        return 0;
    }
  }

  // =====================================
  // ORDER DATE & TIME
  // =====================================

  String getOrderDateTime() {
    final value = order['orderDateTime'];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return 'Date & time not available';
    }

    try {
      final dateTime =
          DateTime.parse(value.toString());

      final day =
          dateTime.day.toString().padLeft(2, '0');

      final month =
          dateTime.month.toString().padLeft(2, '0');

      final year =
          dateTime.year.toString();

      final hour =
          dateTime.hour % 12 == 0
              ? 12
              : dateTime.hour % 12;

      final minute =
          dateTime.minute.toString().padLeft(2, '0');

      final second =
          dateTime.second.toString().padLeft(2, '0');

      final period =
          dateTime.hour >= 12
              ? 'PM'
              : 'AM';

      return '$day/$month/$year  $hour:$minute:$second $period';
    } catch (e) {
      return value.toString();
    }
  }

  // =====================================
  // LATITUDE
  // =====================================

  String getLatitude() {
    final value = order['latitude'];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return 'Not available';
    }

    return value.toString();
  }

  // =====================================
  // LONGITUDE
  // =====================================

  String getLongitude() {
    final value = order['longitude'];

    if (value == null ||
        value.toString().trim().isEmpty) {
      return 'Not available';
    }

    return value.toString();
  }

  List<Map<String, dynamic>> get orderedItems {
    final dynamic savedItems = order['items'];

    if (savedItems is! List) {
      return <Map<String, dynamic>>[];
    }

    return savedItems
        .whereType<Map>()
        .map(
          (Map item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  double _priceFromItem(Map<String, dynamic> item) {
    final String priceText = item['price']
        .toString()
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(priceText) ?? 0;
  }

  Widget _orderedItemsCard() {
    if (orderedItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Items are not available for this old order.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: orderedItems.map((Map<String, dynamic> item) {
          final int quantity = int.tryParse(item['quantity'].toString()) ?? 1;
          final double itemTotal = _priceFromItem(item) * quantity;
          final String? imagePath = item['image'] as String?;

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: imagePath == null || imagePath.isEmpty
                      ? const Icon(Icons.shopping_bag, color: Colors.blue)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              BuildContext context,
                              Object error,
                              StackTrace? stackTrace,
                            ) {
                              return const Icon(
                                Icons.shopping_bag,
                                color: Colors.blue,
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toString() ?? 'Product',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Quantity: $quantity'),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${itemTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // =====================================
  // CHANGE STATUS
  // =====================================

  Future<void> changeStatus(
    String newStatus,
  ) async {
    final orderId =
        (order['id'] ?? '').toString();

    await updateOrderStatus(
      orderId,
      newStatus,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      order['status'] = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order status changed to $newStatus',
        ),
      ),
    );
  }

  // =====================================
  // STATUS COLOR
  // =====================================

  Color statusColor(String value) {
    switch (value) {
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

  // =====================================
  // BUILD
  // =====================================

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        getStatusIndex(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // =====================================
            // ORDER ID
            // =====================================

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(18),

              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(15),

                color:
                    Colors.grey.shade100,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Order ID',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    (order['id'] ??
                            order['orderId'] ??
                            'RD000000')
                        .toString(),

                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // =====================================
            // ORDER DATE & TIME
            // =====================================

            const Text(
              'Order Date & Time',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _infoCard(
              Icons.calendar_month,
              'Order Placed',
              getOrderDateTime(),
            ),

            const SizedBox(height: 18),

            // =====================================
            // ORDERED ITEMS
            // =====================================

            const Text(
              'Ordered Items',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _orderedItemsCard(),

            const SizedBox(height: 18),

            // =====================================
            // CUSTOMER DETAILS
            // =====================================

            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _infoCard(
              Icons.person,
              'Customer',
              (order['name'] ??
                      'Customer')
                  .toString(),
            ),

            _infoCard(
              Icons.phone,
              'Mobile',
              (order['phone'] ??
                      'Not available')
                  .toString(),
            ),

            _infoCard(
              Icons.location_on,
              'Delivery Address',
              (order['address'] ??
                      'Address not available')
                  .toString(),
            ),

            const SizedBox(height: 18),

            // =====================================
            // CUSTOMER LOCATION
            // =====================================

            const Text(
              'Customer Location',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color:
                    Colors.blue.shade50,

                borderRadius:
                    BorderRadius.circular(15),

                border: Border.all(
                  color:
                      Colors.blue.shade200,
                ),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color:
                            Colors.blue.shade700,
                        size: 30,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      const Expanded(
                        child: Text(
                          'Delivery Location',
                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Text(
                    'Latitude: ${getLatitude()}',
                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Longitude: ${getLongitude()}',
                    style:
                        const TextStyle(
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.all(
                      12,
                    ),

                    decoration:
                        BoxDecoration(
                      color: Colors.white,

                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),

                    child: const Row(
                      children: [
                        Icon(
                          Icons.map,
                          color:
                              Colors.blue,
                        ),

                        SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            'Map tracking will be connected in the next step.',
                            style:
                                TextStyle(
                              fontSize: 14,
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // =====================================
            // PAYMENT DETAILS
            // =====================================

            const Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _infoCard(
              Icons.payments,
              'Amount',
              "Rs. ${(order["amount"] ?? "0").toString()}",
            ),

            _infoCard(
              Icons.credit_card,
              'Payment Method',
              (order['payment'] ??
                      'Cash on Delivery')
                  .toString(),
            ),

            const SizedBox(height: 18),

            // =====================================
            // CURRENT STATUS
            // =====================================

            const Text(
              'Current Status',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: statusColor(status)
                    .withValues(alpha: 0.10),

                borderRadius:
                    BorderRadius.circular(15),

                border: Border.all(
                  color:
                      statusColor(status),
                ),
              ),

              child: Row(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color:
                        statusColor(status),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          statusColor(status),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // =====================================
            // ORDER TRACKING
            // =====================================

            const Text(
              'Order Tracking',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            _buildTimeline(
              currentIndex,
            ),

            const SizedBox(height: 25),

            // =====================================
            // CHANGE STATUS
            // =====================================

            const Text(
              'Change Order Status',
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue:
                  orderStatuses.contains(status)
                      ? status
                      : 'Pending',

              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),

                prefixIcon:
                    Icon(Icons.sync),
              ),

              items:
                  orderStatuses.map(
                (item) {
                  return DropdownMenuItem<
                      String>(
                    value: item,
                    child:
                        Text(item),
                  );
                },
              ).toList(),

              onChanged: (value) {
                if (value == null) {
                  return;
                }

                changeStatus(value);
              },
            ),

            const SizedBox(
              height: 30,
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // INFO CARD
  // =====================================

  Widget _infoCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      width: double.infinity,

      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color:
            Colors.grey.shade50,

        borderRadius:
            BorderRadius.circular(12),

        border: Border.all(
          color:
              Colors.grey.shade300,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color:
                Colors.grey.shade700,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        Colors.grey,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // TIMELINE
  // =====================================

  Widget _buildTimeline(
    int currentIndex,
  ) {
    return Column(
      children:
          List.generate(
        orderStatuses.length,
        (index) {
          final completed =
              index <= currentIndex;

          final isLast =
              index ==
                  orderStatuses.length - 1;

          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              SizedBox(
                width: 55,

                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,

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
                            )
                          : Icon(
                              Icons.circle,
                              size: 12,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                    ),

                    if (!isLast)
                      Container(
                        width: 4,
                        height: 50,

                        color: index <
                                currentIndex
                            ? Colors.green
                            : Colors.grey
                                .shade300,
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 8,
                    left: 8,
                  ),

                  child: Text(
                    orderStatuses[index],

                    style: TextStyle(
                      fontSize: 18,

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
