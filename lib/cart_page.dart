import 'package:flutter/material.dart';

import 'checkout_page.dart';
import 'data/cart_data.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController couponController = TextEditingController();
  bool isLoading = true;
  String? appliedCoupon;
  String? couponMessage;
  bool freeDeliveryCoupon = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    await loadCart();
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  double get subtotal {
    double total = 0;
    for (final Map<String, dynamic> item in cartItems) {
      final String priceText = item['price']
          .toString()
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim();
      final double price = double.tryParse(priceText) ?? 0;
      final int quantity = int.tryParse(item['quantity'].toString()) ?? 1;
      total += price * quantity;
    }
    return total;
  }

  double get discountAmount {
    if (appliedCoupon == 'SAVE10') {
      return (subtotal * 0.10).clamp(0, 1000).toDouble();
    }
    if (appliedCoupon == 'RD100' && subtotal >= 1000) return 100;
    return 0;
  }

  double get totalAfterDiscount => subtotal - discountAmount;

  void _applyCoupon() {
    final String code = couponController.text.trim().toUpperCase();
    String message;
    bool valid = false;
    bool freeDelivery = false;

    if (code == 'SAVE10') {
      valid = true;
      message = 'SAVE10 applied: 10% discount (maximum Rs. 1,000).';
    } else if (code == 'RD100' && subtotal >= 1000) {
      valid = true;
      message = 'RD100 applied: Rs. 100 discount.';
    } else if (code == 'FREEDELIVERY') {
      valid = true;
      freeDelivery = true;
      message = 'FREEDELIVERY applied successfully.';
    } else if (code == 'RD100') {
      message = 'RD100 needs a minimum order of Rs. 1,000.';
    } else {
      message = 'Invalid coupon code.';
    }

    setState(() {
      appliedCoupon = valid ? code : null;
      freeDeliveryCoupon = valid && freeDelivery;
      couponMessage = message;
    });
  }

  void _removeCoupon() {
    setState(() {
      appliedCoupon = null;
      freeDeliveryCoupon = false;
      couponMessage = null;
      couponController.clear();
    });
  }

  IconData _itemIcon(Map<String, dynamic> item) {
    if (item['icon'] is IconData) return item['icon'] as IconData;
    final String name = item['name'].toString().toLowerCase();
    if (name.contains('iphone')) return Icons.phone_iphone;
    if (name.contains('phone')) return Icons.phone_android;
    if (name.contains('laptop')) return Icons.laptop_mac;
    if (name.contains('chair')) return Icons.chair;
    if (name.contains('rice')) return Icons.kitchen;
    return Icons.shopping_bag;
  }

  Future<void> _changeQuantity(int index, int change) async {
    setState(() {
      final int quantity =
          int.tryParse(cartItems[index]['quantity'].toString()) ?? 1;
      if (change < 0 && quantity == 1) {
        cartItems.removeAt(index);
      } else {
        cartItems[index]['quantity'] = quantity + change;
      }
    });
    await saveCart();
  }

  Future<void> _removeItem(int index) async {
    setState(() => cartItems.removeAt(index));
    await saveCart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item removed from cart')),
    );
  }

  Widget _amountRow(
    String label,
    double amount, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text(
            'Rs. ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Your cart is empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          ...List.generate(cartItems.length, (int index) {
                            final Map<String, dynamic> item = cartItems[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 75,
                                          height: 75,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: item['image'] is String
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.asset(
                                                    item['image'] as String,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      BuildContext context,
                                                      Object error,
                                                      StackTrace? stackTrace,
                                                    ) => Icon(
                                                      _itemIcon(item),
                                                      size: 40,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                )
                                              : Icon(
                                                  _itemIcon(item),
                                                  size: 40,
                                                  color: Colors.blue,
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'].toString(),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                item['price'].toString(),
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _removeItem(index),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Quantity',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _changeQuantity(index, -1),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                            ),
                                            Text(
                                              item['quantity'].toString(),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _changeQuantity(index, 1),
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Coupon Code',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: couponController,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'SAVE10, RD100 or FREEDELIVERY',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _applyCoupon,
                                        child: const Text('Apply'),
                                      ),
                                    ],
                                  ),
                                  if (couponMessage != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            couponMessage!,
                                            style: TextStyle(
                                              color: appliedCoupon == null
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                        if (appliedCoupon != null)
                                          IconButton(
                                            onPressed: _removeCoupon,
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Delivery charge is calculated from your selected location at checkout.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _amountRow('Subtotal', subtotal),
                          if (discountAmount > 0)
                            _amountRow(
                              'Discount',
                              -discountAmount,
                              color: Colors.red,
                            ),
                          const Divider(),
                          _amountRow(
                            'Items Total',
                            totalAfterDiscount,
                            color: Colors.green,
                            bold: true,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutPage(
                                      cartSubtotal: subtotal,
                                      discountAmount: discountAmount,
                                      freeDeliveryCoupon: freeDeliveryCoupon,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
