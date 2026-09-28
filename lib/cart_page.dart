import 'package:flutter/material.dart';

import 'checkout_page.dart';
import 'data/cart_data.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    this.marketplace = 'online',
  });

  final String marketplace;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> get _cartItems =>
      cartItemsForMarketplace(
        widget.marketplace,
      );

  final TextEditingController couponController =
      TextEditingController();

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
    await loadCart(
      marketplace: widget.marketplace,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isLoading = false;
    });
  }

  // =========================================================
  // SUBTOTAL
  // =========================================================

  double get subtotal {
    double total = 0;

    for (final Map<String, dynamic> item in _cartItems) {
      final dynamic rawPrice =
          item['pricePerUnit'] ?? item['price'];

      final double price = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(
                rawPrice
                        ?.toString()
                        .replaceAll('Rs.', '')
                        .replaceAll('Rs', '')
                        .replaceAll(',', '')
                        .trim() ??
                    '0',
              ) ??
              0;

      final double quantity =
          double.tryParse(
            item['quantity']?.toString() ?? '1',
          ) ??
          1;

      total += price * quantity;
    }

    return total;
  }

  // =========================================================
  // DISCOUNT
  // =========================================================

  double get discountAmount {
    if (appliedCoupon == 'SAVE10') {
      return (subtotal * 0.10)
          .clamp(0, 1000)
          .toDouble();
    }

    if (appliedCoupon == 'RD100' &&
        subtotal >= 1000) {
      return 100;
    }

    return 0;
  }

  double get totalAfterDiscount =>
      subtotal - discountAmount;

  // =========================================================
  // COUPON
  // =========================================================

  void _applyCoupon() {
    final String code =
        couponController.text
            .trim()
            .toUpperCase();

    String message;

    bool valid = false;
    bool freeDelivery = false;

    if (code == 'SAVE10') {
      valid = true;

      message =
          'SAVE10 applied: 10% discount '
          '(maximum Rs. 1,000).';
    } else if (code == 'RD100' &&
        subtotal >= 1000) {
      valid = true;

      message =
          'RD100 applied: Rs. 100 discount.';
    } else if (code == 'FREEDELIVERY') {
      valid = true;
      freeDelivery = true;

      message =
          'FREEDELIVERY applied successfully.';
    } else if (code == 'RD100') {
      message =
          'RD100 needs a minimum order of '
          'Rs. 1,000.';
    } else {
      message = 'Invalid coupon code.';
    }

    setState(() {
      appliedCoupon =
          valid ? code : null;

      freeDeliveryCoupon =
          valid && freeDelivery;

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

  // =========================================================
  // PRODUCT ICON
  // =========================================================

  IconData _itemIcon(
    Map<String, dynamic> item,
  ) {
    if (item['icon'] is IconData) {
      return item['icon'] as IconData;
    }

    final String name =
        item['name']
            ?.toString()
            .toLowerCase() ??
        '';

    if (name.contains('iphone')) {
      return Icons.phone_iphone;
    }

    if (name.contains('phone')) {
      return Icons.phone_android;
    }

    if (name.contains('laptop')) {
      return Icons.laptop_mac;
    }

    if (name.contains('chair')) {
      return Icons.chair;
    }

    if (name.contains('rice')) {
      return Icons.kitchen;
    }

    return Icons.shopping_bag;
  }

  // =========================================================
  // PRODUCT IMAGE
  // =========================================================

  String _cartThumbnailUrl(
    String url,
  ) {
    final String value = url.trim();

    if (value.contains('res.cloudinary.com') &&
        value.contains('/image/upload/')) {
      return value.replaceFirst(
        '/image/upload/',
        '/image/upload/c_fill,g_auto,w_240,h_240,q_auto:good/',
      );
    }

    return value;
  }

  Widget _productImage(
    Map<String, dynamic> item,
  ) {
    final String image =
        item['image']
            ?.toString()
            .trim() ??
        '';

    final Widget fallback =
        Icon(
      _itemIcon(item),
      size: 40,
      color: Colors.blue,
    );

    if (image.isEmpty ||
        image.toLowerCase() == 'null') {
      return fallback;
    }

    if (image.startsWith('http://') ||
        image.startsWith('https://')) {
      return Image.network(
        _cartThumbnailUrl(image),
        fit: BoxFit.cover,
        width: 75,
        height: 75,
        cacheWidth: 240,
        cacheHeight: 240,
        loadingBuilder: (
          BuildContext context,
          Widget child,
          ImageChunkEvent? loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return Container(
            width: 75,
            height: 75,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        width: 75,
        height: 75,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    return fallback;
  }

  bool _isKrishi(
    Map<String, dynamic> item,
  ) {
    return isKrishiCartItem(item);
  }

  double _quantityValue(
    Map<String, dynamic> item,
  ) {
    return double.tryParse(
          item['quantity']?.toString() ?? '1',
        ) ??
        1;
  }

  double? _stockValue(
    Map<String, dynamic> item,
  ) {
    if (item['stock'] == null) {
      return null;
    }

    if (item['stock'] is num) {
      return (item['stock'] as num).toDouble();
    }

    return double.tryParse(
      item['stock'].toString(),
    );
  }

  String _unitText(
    Map<String, dynamic> item,
  ) {
    final String unit =
        item['unit']?.toString().trim() ?? '';

    return unit.isEmpty ? 'unit' : unit;
  }

  String _numberText(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    String text = value.toStringAsFixed(2);

    while (text.endsWith('0')) {
      text = text.substring(
        0,
        text.length - 1,
      );
    }

    if (text.endsWith('.')) {
      text = text.substring(
        0,
        text.length - 1,
      );
    }

    return text;
  }

  double _krishiStep(
    Map<String, dynamic> item,
  ) {
    final String unit =
        _unitText(item).toLowerCase();

    if (<String>[
      'kg',
      'kilogram',
      'kilograms',
      'l',
      'ltr',
      'litre',
      'liter',
      'litres',
      'liters',
    ].contains(unit)) {
      return 0.5;
    }

    return 1;
  }

  bool _wholeKrishiUnit(
    Map<String, dynamic> item,
  ) {
    final String unit =
        _unitText(item).toLowerCase();

    return <String>[
      'pc',
      'pcs',
      'piece',
      'pieces',
      'dozen',
      'packet',
      'packets',
      'pack',
      'bag',
      'bags',
      'sack',
      'sacks',
      'box',
      'boxes',
      'crate',
      'crates',
      'tray',
      'trays',
      'bottle',
      'bottles',
      'bundle',
      'bundles',
    ].contains(unit);
  }

  Future<void> _editKrishiQuantity(
    int index,
  ) async {
    if (index < 0 ||
        index >= _cartItems.length ||
        !_isKrishi(_cartItems[index])) {
      return;
    }

    final Map<String, dynamic> item =
        _cartItems[index];

    final String unit =
        _unitText(item);
    final double? stock =
        _stockValue(item);

    final TextEditingController controller =
        TextEditingController(
      text: _numberText(
        _quantityValue(item),
      ),
    );

    final double? result =
        await showDialog<double>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: Text(
            'Enter quantity ($unit)',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                TextInputType.numberWithOptions(
              decimal:
                  !_wholeKrishiUnit(item),
            ),
            decoration: InputDecoration(
              labelText: 'Quantity',
              helperText: stock == null
                  ? null
                  : 'Available: ${_numberText(stock)} $unit',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                final double? typed =
                    double.tryParse(
                  controller.text.trim(),
                );

                if (typed == null ||
                    typed <= 0) {
                  return;
                }

                double value = typed;

                if (_wholeKrishiUnit(
                  item,
                )) {
                  value =
                      typed.roundToDouble();
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text(
                'Update',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    if (stock != null &&
        stock > 0 &&
        result > stock) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Only ${_numberText(stock)} $unit is available.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _cartItems[index]['quantity'] =
          result;
    });

    await saveCart(
      marketplace: widget.marketplace,
    );
  }

  // =========================================================
  // QUANTITY
  // =========================================================

  Future<void> _changeQuantity(
    int index,
    int change,
  ) async {
    if (index < 0 ||
        index >= _cartItems.length) {
      return;
    }

    final Map<String, dynamic> item =
        _cartItems[index];

    if (_isKrishi(item)) {
      final double quantity =
          _quantityValue(item);
      final double step =
          _krishiStep(item);
      final double? stock =
          _stockValue(item);

      double newQuantity =
          quantity + (change * step);

      if (_wholeKrishiUnit(item)) {
        newQuantity =
            newQuantity.roundToDouble();
      }

      if (newQuantity <= 0) {
        setState(() {
          _cartItems.removeAt(index);
        });

        await saveCart(
      marketplace: widget.marketplace,
    );
        return;
      }

      if (stock != null &&
          stock > 0 &&
          newQuantity > stock) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Only ${_numberText(stock)} ${_unitText(item)} is available.',
            ),
          ),
        );

        return;
      }

      setState(() {
        _cartItems[index]['quantity'] =
            newQuantity;
      });

      await saveCart(
      marketplace: widget.marketplace,
    );
      return;
    }

    setState(() {
      final int quantity =
          int.tryParse(
            _cartItems[index]['quantity']
                    ?.toString() ??
                '1',
          ) ??
          1;

      if (change < 0 &&
          quantity <= 1) {
        _cartItems.removeAt(index);
      } else {
        final int newQuantity =
            quantity + change;

        _cartItems[index]['quantity'] =
            newQuantity < 1
                ? 1
                : newQuantity;
      }
    });

    await saveCart(
      marketplace: widget.marketplace,
    );
  }

  // =========================================================
  // REMOVE ITEM
  // =========================================================

  Future<void> _removeItem(
    int index,
  ) async {
    if (index < 0 ||
        index >= _cartItems.length) {
      return;
    }

    setState(() {
      _cartItems.removeAt(index);
    });

    await saveCart(
      marketplace: widget.marketplace,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Item removed from cart',
        ),
      ),
    );
  }

  // =========================================================
  // AMOUNT ROW
  // =========================================================

  Widget _amountRow(
    String label,
    double amount, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : null,
            ),
          ),
          Text(
            'Rs. ${_numberText(amount)}',
            style: TextStyle(
              color: color,
              fontWeight:
                  bold
                      ? FontWeight.bold
                      : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // OPEN CHECKOUT
  // =========================================================

  void _openCheckout() {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Your cart is empty.',
          ),
        ),
      );

      return;
    }

    activateCartMarketplace(
      widget.marketplace,
    );

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder:
            (BuildContext context) {
          return CheckoutPage(
            cartSubtotal: subtotal,
            discountAmount:
                discountAmount,
            freeDeliveryCoupon:
                freeDeliveryCoupon,
          );
        },
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    couponController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.marketplace
                      .trim()
                      .toLowerCase() ==
                  'krishi'
              ? 'Krishi Cart'
              : 'My Cart',
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body:
          isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : _cartItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    children: <Widget>[
                      Icon(
                        Icons
                            .shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      Text(
                        'Your cart is empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: <Widget>[
                    Expanded(
                      child: ListView(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),
                        children: <Widget>[
                          ...List.generate(
                            _cartItems.length,
                            (
                              int index,
                            ) {
                              final Map<
                                      String,
                                      dynamic>
                                  item =
                                  _cartItems[
                                      index];

                              final bool
                                  isKrishi =
                                  _isKrishi(
                                item,
                              );

                              final double
                                  quantity =
                                  _quantityValue(
                                item,
                              );

                              final String
                                  unit =
                                  _unitText(
                                item,
                              );

                              final double?
                                  stock =
                                  _stockValue(
                                item,
                              );

                              return Card(
                                margin:
                                    const EdgeInsets.only(
                                  bottom:
                                      12,
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(
                                    12,
                                  ),
                                  child: Column(
                                    children:
                                        <Widget>[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children:
                                            <Widget>[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(
                                              10,
                                            ),
                                            child:
                                                Container(
                                              width:
                                                  75,
                                              height:
                                                  75,
                                              color:
                                                  Colors.grey.shade100,
                                              child:
                                                  _productImage(
                                                item,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width:
                                                12,
                                          ),
                                          Expanded(
                                            child:
                                                Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children:
                                                  <Widget>[
                                                Text(
                                                  item['name']?.toString() ??
                                                      'Product',
                                                  maxLines:
                                                      2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      const TextStyle(
                                                    fontSize:
                                                        17,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height:
                                                      8,
                                                ),
                                                Text(
                                                  isKrishi
                                                      ? '${item['price']?.toString() ?? 'Rs. 0'} / $unit'
                                                      : item['price']?.toString() ??
                                                          'Rs. 0',
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.green,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                                if (isKrishi) ...<Widget>[
                                                  const SizedBox(
                                                    height: 4,
                                                  ),
                                                  Text(
                                                    stock == null
                                                        ? 'Krishi quantity: ${_numberText(quantity)} $unit'
                                                        : 'Selected: ${_numberText(quantity)} $unit • Available: ${_numberText(stock)} $unit',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed:
                                                () {
                                              _removeItem(
                                                index,
                                              );
                                            },
                                            icon:
                                                const Icon(
                                              Icons
                                                  .delete_outline,
                                              color:
                                                  Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children:
                                            <Widget>[
                                          Text(
                                            isKrishi
                                                ? 'Quantity ($unit)'
                                                : 'Quantity',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight.w500,
                                            ),
                                          ),
                                          Row(
                                            children:
                                                <Widget>[
                                              IconButton(
                                                onPressed:
                                                    () {
                                                  _changeQuantity(
                                                    index,
                                                    -1,
                                                  );
                                                },
                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .remove_circle_outline,
                                                ),
                                              ),
                                              isKrishi
                                                  ? TextButton(
                                                      onPressed:
                                                          () {
                                                        _editKrishiQuantity(
                                                          index,
                                                        );
                                                      },
                                                      child:
                                                          Text(
                                                        '${_numberText(quantity)} $unit',
                                                        style:
                                                            const TextStyle(
                                                          fontSize:
                                                              17,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      quantity
                                                          .round()
                                                          .toString(),
                                                      style:
                                                          const TextStyle(
                                                        fontSize:
                                                            18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                              IconButton(
                                                onPressed:
                                                    () {
                                                  _changeQuantity(
                                                    index,
                                                    1,
                                                  );
                                                },
                                                icon:
                                                    const Icon(
                                                  Icons
                                                      .add_circle_outline,
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
                            },
                          ),

                          // =========================================
                          // COUPON
                          // =========================================

                          Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children:
                                    <Widget>[
                                  const Text(
                                    'Coupon Code',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        8,
                                  ),
                                  Row(
                                    children:
                                        <Widget>[
                                      Expanded(
                                        child:
                                            TextField(
                                          controller:
                                              couponController,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          decoration:
                                              const InputDecoration(
                                            hintText:
                                                'SAVE10, RD100 or FREEDELIVERY',
                                            border:
                                                OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width:
                                            8,
                                      ),
                                      ElevatedButton(
                                        onPressed:
                                            _applyCoupon,
                                        child:
                                            const Text(
                                          'Apply',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (couponMessage !=
                                      null) ...<Widget>[
                                    const SizedBox(
                                      height:
                                          8,
                                    ),
                                    Row(
                                      children:
                                          <Widget>[
                                        Expanded(
                                          child:
                                              Text(
                                            couponMessage!,
                                            style:
                                                TextStyle(
                                              color:
                                                  appliedCoupon == null
                                                      ? Colors.red
                                                      : Colors.green,
                                            ),
                                          ),
                                        ),
                                        if (appliedCoupon !=
                                            null)
                                          IconButton(
                                            onPressed:
                                                _removeCoupon,
                                            icon:
                                                const Icon(
                                              Icons.close,
                                              color:
                                                  Colors.red,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(
                                    height:
                                        6,
                                  ),
                                  const Text(
                                    'Delivery charge is calculated from your selected location at checkout.',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          12,
                                      color:
                                          Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =============================================
                    // BOTTOM TOTAL
                    // =============================================

                    Container(
                      padding:
                          const EdgeInsets.fromLTRB(
                        16,
                        15,
                        16,
                        20,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        boxShadow:
                            <BoxShadow>[
                          BoxShadow(
                            color: Colors.black
                                .withValues(
                              alpha:
                                  0.10,
                            ),
                            blurRadius:
                                8,
                            offset:
                                const Offset(
                              0,
                              -3,
                            ),
                          ),
                        ],
                      ),
                      child: Column(
                        children:
                            <Widget>[
                          _amountRow(
                            'Subtotal',
                            subtotal,
                          ),
                          if (discountAmount >
                              0)
                            _amountRow(
                              'Discount',
                              -discountAmount,
                              color:
                                  Colors.red,
                            ),
                          const Divider(),
                          _amountRow(
                            'Items Total',
                            totalAfterDiscount,
                            color:
                                Colors.green,
                            bold:
                                true,
                          ),
                          const SizedBox(
                            height:
                                12,
                          ),
                          SizedBox(
                            width:
                                double.infinity,
                            height:
                                52,
                            child:
                                ElevatedButton(
                              onPressed:
                                  _openCheckout,
                              child:
                                  const Text(
                                'Proceed to Checkout',
                                style:
                                    TextStyle(
                                  fontSize:
                                      17,
                                  fontWeight:
                                      FontWeight.bold,
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