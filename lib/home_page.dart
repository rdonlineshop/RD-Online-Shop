import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'admin_dashboard_page.dart';
import 'cart_page.dart';
import 'data/cart_data.dart';
import 'data/product_data.dart';
import 'order_history_page.dart';
import 'product_card.dart';
import 'profile_page.dart';
import 'seller_auth_page.dart';
import 'wishlist_page.dart';

enum ProductSort {
  featured,
  lowToHigh,
  highToLow,
  highestRating,
}

class _BannerData {
  final String title;
  final String subtitle;
  final IconData primaryIcon;
  final Color startColor;
  final Color endColor;

  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.primaryIcon,
    required this.startColor,
    required this.endColor,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController =
      TextEditingController();

  final stt.SpeechToText speech = stt.SpeechToText();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _productsSubscription;

  bool isListening = false;
  bool speechAvailable = false;
  bool inStockOnly = false;

  String selectedCategory = 'All';

  ProductSort selectedSort = ProductSort.featured;

  final List<Map<String, dynamic>> firestoreProducts =
      <Map<String, dynamic>>[];

  final List<String> categories = <String>[
    'All',
    'Phones',
    'Computers',
    'Electronics',
    'Watches & Smartwatches',
    'Fashion',
    'Clothes',
    'Shoes',
    'Ayurvedic & Herbs',
    'Beauty',
    'Home',
    'Furniture',
    'Kitchen',
    'Toys',
    'Sports',
    'Automotive',
    'Cars & Light Vehicles',
    'Motorcycles & Scooters',
    'Bicycles',
    'Commercial Vehicles',
    'Car Parts & Accessories',
    'Motorcycle Parts & Accessories',
    'Tools',
    'Machinery & Industrial Equipment',
    'Building Materials',
    'Electrical Supplies',
    'Safety Equipment',
    'Pet Supplies',
    'Books',
    'Groceries',
    'Food',
    'Cool Drinks',
    'Meat & Seafood',
    'Baby',
    'Jewelry',
    'Accessories',
    'Eyewear & Sunglasses',
    'Clothing',
    'Food & Beverages',
    'Health & Personal Care',
    'Office & Stationery',
    'Garden & Outdoor',
    'Travel & Luggage',
    'Musical Instruments',
    'Mobile Accessories',
    'Computer Accessories',
    'Gaming',
    'Cameras & Photography',
    'Appliances',
    'Digital Products',
    'Party & Gifts',
    'Services',
  ];

  final Map<String, IconData> categoryIcons =
      <String, IconData>{
    'All': Icons.grid_view_rounded,
    'Phones': Icons.phone_android,
    'Computers': Icons.laptop_mac,
    'Electronics': Icons.headphones,
    'Watches & Smartwatches': Icons.watch,
    'Fashion': Icons.checkroom,
    'Clothes': Icons.checkroom,
    'Shoes': Icons.directions_run,
    'Ayurvedic & Herbs': Icons.eco,
    'Beauty': Icons.spa,
    'Home': Icons.home,
    'Furniture': Icons.chair,
    'Kitchen': Icons.kitchen,
    'Toys': Icons.toys,
    'Sports': Icons.sports_soccer,
    'Automotive': Icons.directions_car,
    'Cars & Light Vehicles': Icons.directions_car,
    'Motorcycles & Scooters': Icons.two_wheeler,
    'Bicycles': Icons.pedal_bike,
    'Commercial Vehicles': Icons.local_shipping,
    'Car Parts & Accessories': Icons.car_repair,
    'Motorcycle Parts & Accessories': Icons.two_wheeler,
    'Tools': Icons.build,
    'Machinery & Industrial Equipment':
        Icons.precision_manufacturing,
    'Building Materials': Icons.construction,
    'Electrical Supplies': Icons.electrical_services,
    'Safety Equipment': Icons.health_and_safety,
    'Pet Supplies': Icons.pets,
    'Books': Icons.menu_book,
    'Groceries': Icons.local_grocery_store,
    'Food': Icons.restaurant,
    'Cool Drinks': Icons.local_drink,
    'Meat & Seafood': Icons.set_meal,
    'Baby': Icons.child_care,
    'Jewelry': Icons.diamond,
    'Accessories': Icons.watch,
    'Eyewear & Sunglasses': Icons.visibility,
    'Clothing': Icons.checkroom,
    'Food & Beverages': Icons.restaurant,
    'Health & Personal Care': Icons.health_and_safety,
    'Office & Stationery': Icons.edit_note,
    'Garden & Outdoor': Icons.yard,
    'Travel & Luggage': Icons.luggage,
    'Musical Instruments': Icons.music_note,
    'Mobile Accessories': Icons.cable,
    'Computer Accessories': Icons.keyboard,
    'Gaming': Icons.sports_esports,
    'Cameras & Photography': Icons.camera_alt,
    'Appliances': Icons.microwave,
    'Digital Products': Icons.cloud_download,
    'Party & Gifts': Icons.card_giftcard,
    'Services': Icons.handyman,
  };

  final Map<String, String> categoryImages =
      <String, String>{
    'All': 'assets/categories/all.png',
    'Phones': 'assets/categories/phones.png',
    'Computers': 'assets/categories/computers.png',
    'Electronics': 'assets/categories/electronics.png',
    'Watches & Smartwatches':
        'assets/categories/watches_smartwatches.png',
    'Fashion': 'assets/categories/fashion.png',
    'Clothes': 'assets/categories/clothes.png',
    'Clothing': 'assets/categories/clothes.png',
    'Shoes': 'assets/categories/shoes.png',
    'Ayurvedic & Herbs':
        'assets/categories/ayurvedic_herbs.png',
    'Beauty': 'assets/categories/beauty.png',
    'Home': 'assets/categories/home.png',
    'Furniture': 'assets/categories/furniture.png',
    'Kitchen': 'assets/categories/kitchen.png',
    'Toys': 'assets/categories/toys.png',
    'Sports': 'assets/categories/sports.png',
    'Automotive': 'assets/categories/automotive.png',
    'Cars & Light Vehicles': 'assets/categories/cars.png',
    'Motorcycles & Scooters':
        'assets/categories/motorcycles.png',
    'Bicycles': 'assets/categories/bicycles.png',
    'Commercial Vehicles':
        'assets/categories/commercial_vehicles.png',
    'Car Parts & Accessories':
        'assets/categories/car_parts.png',
    'Motorcycle Parts & Accessories':
        'assets/categories/motorcycle_parts.png',
    'Tools': 'assets/categories/tools.png',
    'Machinery & Industrial Equipment':
        'assets/categories/machinery.png',
    'Building Materials':
        'assets/categories/building_materials.png',
    'Electrical Supplies':
        'assets/categories/electrical_supplies.png',
    'Safety Equipment':
        'assets/categories/safety_equipment.png',
    'Pet Supplies': 'assets/categories/pet_supplies.png',
    'Books': 'assets/categories/books.png',
    'Groceries': 'assets/categories/groceries.png',
    'Food': 'assets/categories/food.png',
    'Cool Drinks': 'assets/categories/cool_drinks.png',
    'Meat & Seafood': 'assets/categories/meat_seafood.png',
    'Food & Beverages':
        'assets/categories/food_beverages.png',
    'Baby': 'assets/categories/baby.png',
    'Jewelry': 'assets/categories/jewelry.png',
    'Accessories': 'assets/categories/accessories.png',
    'Eyewear & Sunglasses':
        'assets/categories/eyewear.png',
    'Health & Personal Care':
        'assets/categories/health_personal_care.png',
    'Office & Stationery':
        'assets/categories/office_stationery.png',
    'Garden & Outdoor':
        'assets/categories/garden_outdoor.png',
    'Travel & Luggage':
        'assets/categories/travel_luggage.png',
    'Musical Instruments':
        'assets/categories/musical_instruments.png',
    'Mobile Accessories':
        'assets/categories/mobile_accessories.png',
    'Computer Accessories':
        'assets/categories/computer_accessories.png',
    'Gaming': 'assets/categories/gaming.png',
    'Cameras & Photography':
        'assets/categories/cameras_photography.png',
    'Appliances': 'assets/categories/appliances.png',
    'Digital Products':
        'assets/categories/digital_products.png',
    'Party & Gifts':
        'assets/categories/party_gifts.png',
    'Services': 'assets/categories/services.png',
  };

  _BannerData get bannerData {
    switch (selectedCategory) {
      case 'Phones':
        return const _BannerData(
          title: 'SMARTPHONES',
          subtitle: 'Latest phones at special RD deals',
          primaryIcon: Icons.phone_android,
          startColor: Color(0xFF1565C0),
          endColor: Color(0xFF42A5F5),
        );

      case 'Computers':
        return const _BannerData(
          title: 'COMPUTERS',
          subtitle: 'Work, study and gaming essentials',
          primaryIcon: Icons.laptop_mac,
          startColor: Color(0xFF4A148C),
          endColor: Color(0xFF8E24AA),
        );

      case 'Fashion':
      case 'Shoes':
      case 'Jewelry':
      case 'Accessories':
        return const _BannerData(
          title: 'FASHION SALE',
          subtitle: 'Fresh styles at special RD prices',
          primaryIcon: Icons.checkroom,
          startColor: Color(0xFFC2185B),
          endColor: Color(0xFFEC407A),
        );

      case 'Furniture':
        return const _BannerData(
          title: 'FURNITURE',
          subtitle: 'Make your space more comfortable',
          primaryIcon: Icons.chair,
          startColor: Color(0xFF6D4C41),
          endColor: Color(0xFFA1887F),
        );

      case 'Kitchen':
        return const _BannerData(
          title: 'KITCHEN DEALS',
          subtitle: 'Smart tools for everyday cooking',
          primaryIcon: Icons.kitchen,
          startColor: Color(0xFFE65100),
          endColor: Color(0xFFFF9800),
        );

      case 'Beauty':
        return const _BannerData(
          title: 'BEAUTY PICKS',
          subtitle: 'Feel fresh, confident and beautiful',
          primaryIcon: Icons.spa,
          startColor: Color(0xFFAD1457),
          endColor: Color(0xFFF48FB1),
        );

      case 'Sports':
      case 'Toys':
        return const _BannerData(
          title: 'FUN & SPORTS',
          subtitle: 'Play more, move more, enjoy more',
          primaryIcon: Icons.sports_soccer,
          startColor: Color(0xFF2E7D32),
          endColor: Color(0xFF66BB6A),
        );

      case 'Automotive':
      case 'Tools':
        return const _BannerData(
          title: 'AUTO & TOOLS',
          subtitle: 'Reliable essentials for every job',
          primaryIcon: Icons.directions_car,
          startColor: Color(0xFF37474F),
          endColor: Color(0xFF78909C),
        );

      default:
        return const _BannerData(
          title: 'RD ONLINE SHOP',
          subtitle: 'Shop products from RD Online Shop',
          primaryIcon: Icons.shopping_bag,
          startColor: Color(0xFFD51F13),
          endColor: Color(0xFFFF5A36),
        );
    }
  }

  @override
  void initState() {
    super.initState();

    searchController.addListener(_refreshProducts);

    _initializeSpeech();
    _loadCart();
    _listenToProducts();
  }

  void _refreshProducts() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCart() async {
    await loadCart();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =========================================================
  // IMAGE PATHS
  // Cloudinary / assets / old local image path support
  // =========================================================

  List<String> _collectProductImages(
    Map<String, dynamic> data,
  ) {
    final List<String> result = <String>[];

    void addValue(dynamic value) {
      if (value == null) {
        return;
      }

      if (value is List) {
        for (final dynamic item in value) {
          addValue(item);
        }

        return;
      }

      final String path = value.toString().trim();

      if (path.isEmpty) {
        return;
      }

      if (!result.contains(path)) {
        result.add(path);
      }
    }

    // New / Cloudinary fields
    addValue(data['imagePaths']);
    addValue(data['imageUrls']);
    addValue(data['images']);
    addValue(data['photoUrls']);
    addValue(data['photos']);

    // Single image fields
    addValue(data['imagePath']);
    addValue(data['imageUrl']);
    addValue(data['photoUrl']);

    // Cloud/network photos first
    result.sort(
      (String first, String second) {
        final bool firstNetwork =
            first.startsWith('http://') ||
                first.startsWith('https://');

        final bool secondNetwork =
            second.startsWith('http://') ||
                second.startsWith('https://');

        if (firstNetwork && !secondNetwork) {
          return -1;
        }

        if (!firstNetwork && secondNetwork) {
          return 1;
        }

        return 0;
      },
    );

    return result;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .map(
          (dynamic item) =>
              item.toString().trim(),
        )
        .where(
          (String item) => item.isNotEmpty,
        )
        .toList();
  }

  // =========================================================
  // FIRESTORE REALTIME PRODUCTS
  // =========================================================

  void _listenToProducts() {
    _productsSubscription = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen(
      (
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) {
        final List<Map<String, dynamic>>
            loadedProducts =
            snapshot.docs.map(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc,
          ) {
            final Map<String, dynamic> data =
                doc.data();

            final String category =
                data['category']
                        ?.toString()
                        .trim() ??
                    'All';

            final List<String> imagePaths =
                _collectProductImages(data);

            final List<String> colorOptions =
                _stringList(
              data['colorOptions'],
            );

            final List<String> sizeOptions =
                _stringList(
              data['sizeOptions'],
            );

            final String productName =
                data['name']
                        ?.toString()
                        .trim() ??
                    'Product';

            final String description =
                data['description']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? data['description']
                        .toString()
                        .trim()
                    : 'Quality product available at RD Online Shop.';

            final String sellerId =
                data['sellerId']
                        ?.toString()
                        .trim() ??
                    '';

            return <String, dynamic>{
              ...data,

              // Important IDs
              'id': doc.id,
              'productId': doc.id,
              'sellerId': sellerId,

              // Product basic details
              'name': productName,
              'description': description,
              'price':
                  data['price']?.toString() ??
                      'Rs. 0',
              'category': category,

              // Category icon
              'icon':
                  categoryIcons[category] ??
                      Icons.shopping_bag,

              // Cross-device photos
              'imagePath':
                  imagePaths.isNotEmpty
                      ? imagePaths.first
                      : null,
              'imagePaths': imagePaths,

              // Options
              'colorOptions': colorOptions,
              'sizeOptions': sizeOptions,

              // Pricing
              'originalPrice':
                  data['originalPrice']
                      ?.toString(),
              'discount':
                  (data['discount'] as num?)
                          ?.toInt() ??
                      0,

              // Rating
              'rating':
                  (data['rating'] as num?)
                          ?.toDouble() ??
                      0.0,

              // Stock
              'inStock':
                  data['inStock'] != false,
            };
          },
        ).toList();

        if (!mounted) {
          return;
        }

        setState(() {
          firestoreProducts
            ..clear()
            ..addAll(loadedProducts);
        });
      },
      onError: (Object error) {
        debugPrint(
          'Firestore products error: $error',
        );
      },
    );
  }

  Future<void> _initializeSpeech() async {
    try {
      final bool available =
          await speech.initialize(
        onStatus: (String status) {
          if (!mounted) {
            return;
          }

          if (status == 'done' ||
              status == 'notListening') {
            setState(() {
              isListening = false;
            });
          }
        },
        onError: (_) {
          if (!mounted) {
            return;
          }

          setState(() {
            isListening = false;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        speechAvailable = available;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        speechAvailable = false;
        isListening = false;
      });
    }
  }

  Future<void> _voiceSearch() async {
    if (!speechAvailable) {
      await _initializeSpeech();
    }

    if (!speechAvailable) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice search is not available',
          ),
        ),
      );

      return;
    }

    if (isListening) {
      await speech.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        isListening = false;
      });

      return;
    }

    setState(() {
      isListening = true;
    });

    await speech.listen(
      onResult: (result) {
        if (!mounted) {
          return;
        }

        setState(() {
          searchController.text =
              result.recognizedWords;

          searchController.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset:
                  searchController.text.length,
            ),
          );
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor:
            const Duration(seconds: 30),
        pauseFor:
            const Duration(seconds: 3),
        partialResults: true,
        listenMode: stt.ListenMode.search,
      ),
    );
  }

  double _priceValue(String price) {
    return double.tryParse(
          price.replaceAll(
            RegExp(r'[^0-9.]'),
            '',
          ),
        ) ??
        0;
  }

  List<Map<String, dynamic>> get allProducts {
    if (firestoreProducts.isNotEmpty) {
      return firestoreProducts;
    }

    return products;
  }

  List<Map<String, dynamic>> get filteredProducts {
    final String search =
        searchController.text
            .toLowerCase()
            .trim();

    final List<Map<String, dynamic>> result =
        allProducts.where(
      (Map<String, dynamic> product) {
        final String name =
            product['name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final String description =
            product['description']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final String brand =
            product['brand']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final String category =
            product['category']
                    ?.toString() ??
                'All';

        final bool stock =
            product['inStock'] != false;

        final bool matchesSearch =
            search.isEmpty ||
                name.contains(search) ||
                description.contains(search) ||
                brand.contains(search) ||
                category
                    .toLowerCase()
                    .contains(search);

        final bool matchesCategory =
            selectedCategory == 'All' ||
                category ==
                    selectedCategory;

        final bool matchesStock =
            !inStockOnly || stock;

        return matchesSearch &&
            matchesCategory &&
            matchesStock;
      },
    ).toList();

    switch (selectedSort) {
      case ProductSort.lowToHigh:
        result.sort(
          (
            Map<String, dynamic> first,
            Map<String, dynamic> second,
          ) =>
              _priceValue(
            first['price'].toString(),
          ).compareTo(
            _priceValue(
              second['price'].toString(),
            ),
          ),
        );
        break;

      case ProductSort.highToLow:
        result.sort(
          (
            Map<String, dynamic> first,
            Map<String, dynamic> second,
          ) =>
              _priceValue(
            second['price'].toString(),
          ).compareTo(
            _priceValue(
              first['price'].toString(),
            ),
          ),
        );
        break;

      case ProductSort.highestRating:
        result.sort(
          (
            Map<String, dynamic> first,
            Map<String, dynamic> second,
          ) =>
              ((second['rating'] as num?) ?? 0)
                  .compareTo(
            (first['rating'] as num?) ?? 0,
          ),
        );
        break;

      case ProductSort.featured:
        break;
    }

    return result;
  }

  void _applyFilter(String value) {
    setState(() {
      switch (value) {
        case 'featured':
          selectedSort =
              ProductSort.featured;
          break;

        case 'lowToHigh':
          selectedSort =
              ProductSort.lowToHigh;
          break;

        case 'highToLow':
          selectedSort =
              ProductSort.highToLow;
          break;

        case 'rating':
          selectedSort =
              ProductSort.highestRating;
          break;

        case 'inStock':
          inStockOnly = true;
          break;

        case 'allStock':
          inStockOnly = false;
          break;
      }
    });
  }

  int _gridColumns(double width) {
    if (width >= 1400) {
      return 6;
    }

    if (width >= 1100) {
      return 5;
    }

    if (width >= 850) {
      return 4;
    }

    if (width >= 600) {
      return 3;
    }

    return 2;
  }

  @override
  void dispose() {
    speech.stop();
    _productsSubscription?.cancel();

    searchController
      ..removeListener(_refreshProducts)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text(
          'RD Online Shop',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Wishlist',
            icon:
                const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const WishlistPage(),
                ),
              );
            },
          ),

          IconButton(
            tooltip: 'Cart',
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(
                  Icons.shopping_cart,
                ),
                if (getCartItemCount() > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 4,
                      ),
                      decoration:
                          const BoxDecoration(
                        color: Colors.red,
                        shape:
                            BoxShape.circle,
                      ),
                      child: Text(
                        getCartItemCount() >
                                99
                            ? '99+'
                            : getCartItemCount()
                                .toString(),
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CartPage(),
                ),
              );

              if (!mounted) {
                return;
              }

              setState(() {});
            },
          ),

          IconButton(
            tooltip: 'My Orders',
            icon: const Icon(
              Icons.local_shipping,
            ),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const OrderHistoryPage(),
                ),
              );
            },
          ),

          PopupMenuButton<String>(
            icon:
                const Icon(Icons.more_vert),
            onSelected: (String value) {
              if (value == 'profile') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ProfilePage(),
                  ),
                );
              }

              if (value == 'admin') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AdminDashboardPage(),
                  ),
                ).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                });
              }

              if (value == 'seller') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SellerAuthPage(),
                  ),
                );
              }
            },
            itemBuilder:
                (BuildContext context) {
              return const <
                  PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Profile'),
                ),
                PopupMenuItem<String>(
                  value: 'admin',
                  child: Text(
                    'Admin Dashboard',
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'seller',
                  child: Text(
                    'Seller Dashboard',
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      body: Column(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              8,
            ),
            child: TextField(
              controller:
                  searchController,
              decoration: InputDecoration(
                hintText:
                    'Search products...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip:
                          'Voice Search',
                      icon: Icon(
                        isListening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: isListening
                            ? Colors.red
                            : Colors
                                .lightBlue,
                      ),
                      onPressed:
                          _voiceSearch,
                    ),
                    if (searchController
                        .text.isNotEmpty)
                      IconButton(
                        tooltip:
                            'Clear Search',
                        icon: const Icon(
                          Icons.clear,
                        ),
                        onPressed:
                            searchController
                                .clear,
                      ),
                  ],
                ),
                filled: true,
                fillColor:
                    Colors.grey.shade100,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),

          if (isListening)
            const Text(
              'Listening... 🎤',
              style: TextStyle(
                color: Colors.red,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Container(
                    height: 130,
                    margin:
                        const EdgeInsets
                            .fromLTRB(
                      12,
                      4,
                      12,
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                      child: Stack(
                        fit:
                            StackFit.expand,
                        children: <Widget>[
                          Image.asset(
                            categoryImages[
                                    selectedCategory] ??
                                categoryImages[
                                    'All']!,
                            fit: BoxFit.contain,
                            errorBuilder: (
                              BuildContext
                                  context,
                              Object error,
                              StackTrace?
                                  stackTrace,
                            ) {
                              return Container(
                                color: bannerData
                                    .startColor,
                                child: Icon(
                                  bannerData
                                      .primaryIcon,
                                  size: 76,
                                  color: Colors
                                      .white,
                                ),
                              );
                            },
                          ),

                          DecoratedBox(
                            decoration:
                                BoxDecoration(
                              gradient:
                                  LinearGradient(
                                colors: <Color>[
                                  bannerData
                                      .startColor
                                      .withValues(
                                    alpha:
                                        0.92,
                                  ),
                                  bannerData
                                      .endColor
                                      .withValues(
                                    alpha:
                                        0.58,
                                  ),
                                  Colors
                                      .transparent,
                                ],
                                stops: const <
                                    double>[
                                  0.0,
                                  0.52,
                                  1.0,
                                ],
                              ),
                            ),
                          ),

                          Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              14,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children:
                                  <Widget>[
                                Text(
                                  bannerData
                                      .title,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        20,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                SizedBox(
                                  width: 185,
                                  child: Text(
                                    bannerData
                                        .subtitle,
                                    style:
                                        const TextStyle(
                                      color: Colors
                                          .white,
                                      fontSize:
                                          13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets
                            .symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      'Shop by Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 112,
                    child:
                        ScrollConfiguration(
                      behavior:
                          const MaterialScrollBehavior()
                              .copyWith(
                        dragDevices:
                            <PointerDeviceKind>{
                          PointerDeviceKind
                              .touch,
                          PointerDeviceKind
                              .mouse,
                          PointerDeviceKind
                              .trackpad,
                          PointerDeviceKind
                              .stylus,
                        },
                      ),
                      child:
                          ListView.builder(
                        scrollDirection:
                            Axis.horizontal,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                          vertical: 10,
                        ),
                        itemCount:
                            categories
                                .length,
                        itemBuilder: (
                          BuildContext
                              context,
                          int index,
                        ) {
                          final String
                              category =
                              categories[
                                  index];

                          final bool
                              selected =
                              selectedCategory ==
                                  category;

                          return InkWell(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              40,
                            ),
                            onTap: () {
                              setState(() {
                                selectedCategory =
                                    category;
                              });
                            },
                            child:
                                Container(
                              width: 86,
                              margin:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    4,
                              ),
                              child:
                                  Column(
                                children:
                                    <Widget>[
                                  Container(
                                    width: 66,
                                    height:
                                        66,
                                    decoration:
                                        BoxDecoration(
                                      shape:
                                          BoxShape.circle,
                                      border:
                                          Border.all(
                                        color: selected
                                            ? Colors.lightBlue
                                            : Colors.transparent,
                                        width:
                                            3,
                                      ),
                                    ),
                                    child:
                                        ClipOval(
                                      child:
                                          Container(
                                        color:
                                            Colors.white,
                                        padding:
                                            const EdgeInsets.all(
                                          4,
                                        ),
                                        child:
                                            Image.asset(
                                          categoryImages[category] ??
                                              categoryImages['All']!,
                                          fit:
                                              BoxFit.cover,
                                          errorBuilder:
                                              (
                                            BuildContext
                                                context,
                                            Object
                                                error,
                                            StackTrace?
                                                stackTrace,
                                          ) {
                                            return Icon(
                                              categoryIcons[category] ??
                                                  Icons.shopping_bag,
                                              size:
                                                  30,
                                              color:
                                                  Colors.blue,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height:
                                        4,
                                  ),
                                  Text(
                                    category,
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    textAlign:
                                        TextAlign.center,
                                    style:
                                        TextStyle(
                                      fontSize:
                                          11,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      14,
                      4,
                      8,
                      8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${filteredProducts.length} Products Found',
                            style:
                                const TextStyle(
                              fontSize:
                                  17,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                        PopupMenuButton<
                            String>(
                          tooltip:
                              'Filter and Sort',
                          onSelected:
                              _applyFilter,
                          itemBuilder: (
                            BuildContext
                                context,
                          ) {
                            return const <
                                PopupMenuEntry<
                                    String>>[
                              PopupMenuItem<
                                  String>(
                                value:
                                    'featured',
                                child: Text(
                                  'Featured Products',
                                ),
                              ),
                              PopupMenuItem<
                                  String>(
                                value:
                                    'lowToHigh',
                                child: Text(
                                  'Price: Low to High',
                                ),
                              ),
                              PopupMenuItem<
                                  String>(
                                value:
                                    'highToLow',
                                child: Text(
                                  'Price: High to Low',
                                ),
                              ),
                              PopupMenuItem<
                                  String>(
                                value:
                                    'rating',
                                child: Text(
                                  'Highest Rating',
                                ),
                              ),
                              PopupMenuItem<
                                  String>(
                                value:
                                    'inStock',
                                child: Text(
                                  'In Stock Only',
                                ),
                              ),
                              PopupMenuItem<
                                  String>(
                                value:
                                    'allStock',
                                child: Text(
                                  'Show All Stock',
                                ),
                              ),
                            ];
                          },
                          icon:
                              const Icon(
                            Icons.tune,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (filteredProducts
                    .isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody:
                        false,
                    child: Center(
                      child: Text(
                        'No products found',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      10,
                      0,
                      10,
                      20,
                    ),
                    sliver:
                        SliverLayoutBuilder(
                      builder: (
                        BuildContext
                            context,
                        constraints,
                      ) {
                        final int columns =
                            _gridColumns(
                          constraints
                              .crossAxisExtent,
                        );

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                columns,
                            crossAxisSpacing:
                                10,
                            mainAxisSpacing:
                                10,
                            childAspectRatio:
                                0.66,
                          ),
                          delegate:
                              SliverChildBuilderDelegate(
                            (
                              BuildContext
                                  context,
                              int index,
                            ) {
                              final Map<
                                      String,
                                      dynamic>
                                  product =
                                  filteredProducts[
                                      index];

                              final List<
                                      String>
                                  images =
                                  _collectProductImages(
                                product,
                              );

                              return ProductCard(
                                compact:
                                    true,

                                // Important
                                productId:
                                    product['id']
                                            ?.toString() ??
                                        '',

                                sellerId:
                                    product['sellerId']
                                            ?.toString() ??
                                        '',

                                name:
                                    product['name']
                                            ?.toString() ??
                                        'Product',

                                price:
                                    product['price']
                                            ?.toString() ??
                                        'Rs. 0',

                                icon: product[
                                            'icon']
                                        is IconData
                                    ? product[
                                            'icon']
                                        as IconData
                                    : Icons
                                        .shopping_bag,

                                category:
                                    product['category']
                                            ?.toString() ??
                                        'General',

                                description:
                                    product['description']
                                            ?.toString() ??
                                        'Quality product available at RD Online Shop.',

                                imagePath:
                                    images
                                            .isNotEmpty
                                        ? images
                                            .first
                                        : null,

                                imagePaths:
                                    images,

                                colorOptions:
                                    _stringList(
                                  product[
                                      'colorOptions'],
                                ),

                                sizeOptions:
                                    _stringList(
                                  product[
                                      'sizeOptions'],
                                ),

                                originalPrice:
                                    product['originalPrice']
                                        ?.toString(),

                                discount:
                                    (product['discount']
                                            as num?)
                                        ?.toInt(),

                                rating:
                                    (product['rating']
                                                as num?)
                                            ?.toDouble() ??
                                        0.0,

                                inStock:
                                    product['inStock'] !=
                                        false,
                              );
                            },
                            childCount:
                                filteredProducts
                                    .length,
                          ),
                        );
                      },
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