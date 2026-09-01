import 'package:flutter/material.dart';

import 'data/cart_data.dart';
import 'data/wishlist_data.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    await loadWishlist();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _removeProduct(String name) async {
    await removeFromWishlist(name);

    if (!mounted) return;

    setState(() {});
  }

  IconData _iconFromProduct(Map<String, dynamic> product) {
    final String name = product['name'].toString().toLowerCase();

    if (name.contains('iphone')) {
      return Icons.phone_iphone;
    }

    if (name.contains('samsung') ||
        name.contains('redmi') ||
        name.contains('vivo') ||
        name.contains('phone')) {
      return Icons.phone_android;
    }

    if (name.contains('laptop')) {
      return Icons.laptop;
    }

    if (name.contains('watch')) {
      return Icons.watch;
    }

    if (name.contains('headphone')) {
      return Icons.headphones;
    }

    if (name.contains('chair') || name.contains('table')) {
      return Icons.chair;
    }

    if (name.contains('rice') || name.contains('kitchen')) {
      return Icons.kitchen;
    }

    return Icons.shopping_bag;
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    await addProductToCart({
      'name': product['name'],
      'price': product['price'],
      'icon': _iconFromProduct(product),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cart updated successfully'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wishlist ❤️',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : wishlistItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'Your Wishlist is empty',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add products you like ❤️',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWishlist,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: wishlistItems.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> product =
                          wishlistItems[index];

                      final IconData productIcon =
                          _iconFromProduct(product);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              productIcon,
                              color: Colors.blue,
                              size: 32,
                            ),
                          ),
                          title: Text(
                            product['name'].toString(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            product['price'].toString(),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Add to Cart',
                                icon: const Icon(
                                  Icons.shopping_cart,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  _addToCart(product);
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  _removeProduct(
                                    product['name'].toString(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}