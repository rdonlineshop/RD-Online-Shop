import 'package:flutter/material.dart';

import 'data/cart_data.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {

  // ==========================================
  // GET TOTAL PRICE
  // ==========================================

  double getTotalPrice() {
    double total = 0;

    for (final item in cartItems) {
      String priceText =
          item["price"].toString();

      priceText = priceText
          .replaceAll("Rs.", "")
          .replaceAll(",", "")
          .trim();

      double price =
          double.tryParse(priceText) ?? 0;

      int quantity =
          int.tryParse(
                item["quantity"]
                    .toString(),
              ) ??
              1;

      total += price * quantity;
    }

    return total;
  }

  // ==========================================
  // INCREASE QUANTITY
  // ==========================================

  void increaseQuantity(int index) {
    setState(() {
      int quantity =
          int.tryParse(
                cartItems[index]["quantity"]
                    .toString(),
              ) ??
              1;

      cartItems[index]["quantity"] =
          quantity + 1;
    });
  }

  // ==========================================
  // DECREASE QUANTITY
  // ==========================================

  void decreaseQuantity(int index) {
    setState(() {
      int quantity =
          int.tryParse(
                cartItems[index]["quantity"]
                    .toString(),
              ) ??
              1;

      if (quantity > 1) {
        cartItems[index]["quantity"] =
            quantity - 1;
      } else {
        cartItems.removeAt(index);
      }
    });
  }

  // ==========================================
  // REMOVE ITEM
  // ==========================================

  void removeItem(int index) {
    setState(() {
      cartItems.removeAt(index);
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Item removed from cart",
        ),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Cart",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: cartItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),

                  SizedBox(height: 15),

                  Text(
                    "Your cart is empty",
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
              children: [

                // ==================================
                // CART ITEMS
                // ==================================

                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.all(12),

                    itemCount:
                        cartItems.length,

                    itemBuilder:
                        (context, index) {

                      final item =
                          cartItems[index];

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),

                        elevation: 3,

                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),

                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),

                          child: Column(
                            children: [

                              // PRODUCT INFORMATION
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  // PRODUCT IMAGE / ICON
                                  Container(
                                    width: 75,
                                    height: 75,

                                    decoration:
                                        BoxDecoration(
                                      color: Colors
                                          .grey
                                          .shade100,

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        10,
                                      ),
                                    ),

                                    child:
                                        item["image"] !=
                                                null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  10,
                                                ),
                                                child:
                                                    Image
                                                        .asset(
                                                  item[
                                                      "image"],
                                                  fit: BoxFit
                                                      .cover,
                                                  errorBuilder:
                                                      (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    return const Icon(
                                                      Icons
                                                          .shopping_bag,
                                                      size:
                                                          40,
                                                    );
                                                  },
                                                ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .shopping_bag,
                                                size: 40,
                                              ),
                                  ),

                                  const SizedBox(
                                    width: 12,
                                  ),

                                  // NAME + PRICE
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,

                                      children: [

                                        Text(
                                          item["name"]
                                              .toString(),

                                          style:
                                              const TextStyle(
                                            fontSize:
                                                17,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),

                                          maxLines: 2,

                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        Text(
                                          "Rs. ${item["price"]}",

                                          style:
                                              const TextStyle(
                                            fontSize:
                                                16,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            color:
                                                Colors
                                                    .green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // DELETE BUTTON
                                  IconButton(
                                    onPressed:
                                        () {
                                      removeItem(
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

                              const SizedBox(
                                height: 12,
                              ),

                              const Divider(),

                              // QUANTITY
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,

                                children: [

                                  const Text(
                                    "Quantity",
                                    style:
                                        TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight
                                              .w500,
                                    ),
                                  ),

                                  Row(
                                    children: [

                                      // MINUS
                                      IconButton(
                                        onPressed:
                                            () {
                                          decreaseQuantity(
                                            index,
                                          );
                                        },

                                        icon:
                                            const Icon(
                                          Icons
                                              .remove_circle_outline,
                                        ),
                                      ),

                                      Text(
                                        item["quantity"]
                                            .toString(),

                                        style:
                                            const TextStyle(
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),

                                      // PLUS
                                      IconButton(
                                        onPressed:
                                            () {
                                          increaseQuantity(
                                            index,
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
                ),

                // ==================================
                // BOTTOM TOTAL
                // ==================================

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

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(
                          0.10,
                        ),

                        blurRadius: 8,

                        offset:
                            const Offset(
                          0,
                          -3,
                        ),
                      ),
                    ],
                  ),

                  child: Column(
                    children: [

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,

                        children: [

                          const Text(
                            "Total Amount",
                            style:
                                TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          Text(
                            "Rs. ${getTotalPrice().toStringAsFixed(0)}",

                            style:
                                const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // CHECKOUT BUTTON
                      SizedBox(
                        width:
                            double.infinity,

                        height: 52,

                        child:
                            ElevatedButton(
                          onPressed: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        const CheckoutPage(),
                              ),
                            );
                          },

                          style:
                              ElevatedButton
                                  .styleFrom(
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                          ),

                          child:
                              const Text(
                            "Proceed to Checkout",

                            style:
                                TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight
                                      .bold,
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