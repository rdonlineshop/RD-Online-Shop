import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'admin_auth_page.dart';
import 'cart_page.dart';
import 'customer_dashboard_page.dart';
import 'data/cart_data.dart';
import 'data/product_data.dart';
import 'delivery_person_auth_page.dart';
import 'order_data.dart';
import 'customer_notifications_page.dart';
import 'product_card.dart';
import 'profile_page.dart';
import 'ride_booking_hub_page.dart';
import 'stay_venue_booking_hub_page.dart';
import 'ticket_booking_hub_page.dart';
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

  StreamSubscription<List<Map<String, dynamic>>>?
      _notificationOrdersSubscription;

  List<Map<String, dynamic>> _latestNotificationOrders =
      <Map<String, dynamic>>[];

  String _notificationCustomerId = '';
  int _notificationUnreadCount = 0;

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
    _listenToCustomerNotifications();
  }

  Future<void> _listenToCustomerNotifications() async {
    await _notificationOrdersSubscription?.cancel();
    _notificationOrdersSubscription = null;

    try {
      final String customerId =
          (await getOrCreateCustomerId()).trim();

      _notificationCustomerId = customerId;

      _notificationOrdersSubscription =
          customerOrdersStream(customerId).listen(
        (List<Map<String, dynamic>> orders) async {
          _latestNotificationOrders = orders;
          await _refreshNotificationBadge();
        },
        onError: (Object error) {
          if (!mounted) {
            return;
          }

          setState(() {
            _notificationUnreadCount = 0;
          });
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notificationUnreadCount = 0;
      });
    }
  }

  Future<void> _refreshNotificationBadge() async {
    if (_notificationCustomerId.trim().isEmpty) {
      return;
    }

    final int unread = await countUnreadOrderNotifications(
      _notificationCustomerId,
      _latestNotificationOrders,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationUnreadCount = unread;
    });
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

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Filter & Sort',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Featured'),
                  onTap: () {
                    _applyFilter('featured');
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_upward_rounded),
                  title: const Text('Price: Low to High'),
                  onTap: () {
                    _applyFilter('lowToHigh');
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.arrow_downward_rounded),
                  title: const Text('Price: High to Low'),
                  onTap: () {
                    _applyFilter('highToLow');
                    Navigator.pop(sheetContext);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_rounded),
                  title: const Text('Highest Rating'),
                  onTap: () {
                    _applyFilter('rating');
                    Navigator.pop(sheetContext);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  value: inStockOnly,
                  activeThumbColor: _rdRed,
                  title: const Text('In-stock products only'),
                  onChanged: (bool value) {
                    _applyFilter(value ? 'inStock' : 'allStock');
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
    _notificationOrdersSubscription?.cancel();

    searchController
      ..removeListener(_refreshProducts)
      ..dispose();

    super.dispose();
  }

  static const Color _rdRed = Color(0xFFE50914);
  static const Color _rdBlack = Color(0xFF000000);
  static const Color _pageBg = Color(0xFFF7F7F7);

  bool _isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  Widget _contentWidth(
    Widget child, {
    double maxWidth = 1180,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }


  void _openAllCategories() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'All Categories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((String category) {
                        final bool selected = selectedCategory == category;
                        return ChoiceChip(
                          selected: selected,
                          label: Text(category),
                          selectedColor: _rdRed.withValues(alpha: 0.14),
                          side: BorderSide(
                            color: selected ? _rdRed : Colors.grey.shade300,
                          ),
                          onSelected: (_) {
                            setState(() => selectedCategory = category);
                            Navigator.pop(sheetContext);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 30),
              if (badge > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: _rdRed,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() {
    final bool desktop = _isDesktop(context);

    return Container(
      height: desktop ? 118 : 150,
      color: _pageBg,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipPath(
            clipper: _RdHeaderClipper(),
            child: Container(color: _rdBlack),
          ),
          // Red line follows the same curved edge as the black header.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RdHeaderRedLinePainter(),
              ),
            ),
          ),
          Positioned(
            left: desktop ? 28 : 12,
            top: 8,
            width: desktop ? 130 : 136,
            height: desktop ? 70 : 78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/rd_logo.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'RD ONLINE\nSHOPPING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 0.9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: desktop ? 28 : 12,
            top: desktop ? 24 : 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _roundAction(
                  icon: Icons.favorite_border_rounded,
                  tooltip: 'Wishlist',
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const WishlistPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _roundAction(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  badge: _notificationUnreadCount,
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const CustomerNotificationsPage(),
                      ),
                    );
                    await _refreshNotificationBadge();
                  },
                ),
                const SizedBox(width: 4),
                _roundAction(
                  icon: Icons.shopping_cart_outlined,
                  tooltip: 'Cart',
                  badge: getCartItemCount(),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const CartPage()),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  color: Colors.white,
                  onSelected: (String value) {
                    if (value == 'profile') {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfilePage(),
                        ),
                      );
                    } else if (value == 'customer') {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CustomerDashboardPage(),
                        ),
                      );
                    } else if (value == 'admin') {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const AdminAuthPage()),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    } else if (value == 'seller') {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const SellerAuthPage()),
                      );
                    } else if (value == 'delivery') {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const DeliveryPersonAuthPage(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'profile',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline),
                        title: Text('My Profile'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'customer',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.account_circle_rounded, color: _rdRed),
                        title: Text('Customer Dashboard'),
                        subtitle: Text('No ID / password required'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'seller',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.storefront_outlined),
                        title: Text('Seller Dashboard'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delivery',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delivery_dining_outlined),
                        title: Text('Delivery Person'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'admin',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.admin_panel_settings_outlined),
                        title: Text('Admin Dashboard'),
                      ),
                    ),
                  ],
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _rdRed,
                      size: 30,
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

  Widget _searchBox() {
    return _contentWidth(
      Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Material(
        elevation: 5,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(28),
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search for products...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.search_rounded, size: 30),
            suffixIconConstraints: const BoxConstraints(minWidth: 104),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                InkWell(
                  onTap: _voiceSearch,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _rdRed,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.fromLTRB(2, 3, 5, 3),
                    decoration: const BoxDecoration(
                      color: _rdBlack,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 19),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _categoryButton(String category) {
    final bool selected = selectedCategory == category;
    final String image = categoryImages[category] ?? categoryImages['All']!;
    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => setState(() => selectedCategory = category),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _rdRed : Colors.grey.shade200,
                  width: selected ? 3 : 1,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    categoryIcons[category] ?? Icons.shopping_bag_outlined,
                    size: 34,
                    color: _rdRed,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoriesStrip() {
    final List<String> visibleCategories =
        categories.where((String category) => category != 'All').toList();

    return _contentWidth(
      SizedBox(
      height: 110,
      child: ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: <PointerDeviceKind>{
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: visibleCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (BuildContext context, int index) {
            return _categoryButton(visibleCategories[index]);
          },
        ),
      ),
      ),
    );
  }

  Widget _offerBanner() {
    final bool desktop = _isDesktop(context);

    if (selectedCategory == 'All') {
      return _contentWidth(
        Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: desktop ? 5.0 : 3.0,
            child: Image.asset(
              'assets/images/rd_offer_banner.png',
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  alignment: Alignment.center,
                  color: _rdBlack,
                  child: const Text(
                    'SPECIAL OFFER • SHOP MORE, SAVE MORE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      );
    }

    final _BannerData data = bannerData;
    final String imagePath =
        categoryImages[selectedCategory] ?? categoryImages['All']!;

    return _contentWidth(
      Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: desktop ? 180 : 175,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: <Color>[
              data.startColor,
              data.endColor,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 178,
                height: 178,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 16,
              bottom: 16,
              width: 122,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Icon(
                        data.primaryIcon,
                        size: 58,
                        color: data.startColor,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned.fill(
              right: 142,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _rdBlack,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'SHOP NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _benefitStrip() {
    const List<(IconData, String)> items = <(IconData, String)>[
      (Icons.verified_user_rounded, '100% Secure\nPayment'),
      (Icons.local_shipping_rounded, 'Fast\nDelivery'),
      (Icons.autorenew_rounded, 'Easy\nReturns'),
      (Icons.headset_mic_rounded, '24/7\nSupport'),
    ];
    return _contentWidth(
      Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final int index = entry.key;
          final (IconData, String) item = entry.value;
          return Expanded(
            child: Row(
              children: <Widget>[
                if (index > 0)
                  Container(width: 1, height: 34, color: Colors.grey.shade300),
                const SizedBox(width: 7),
                Icon(item.$1, color: _rdRed, size: 23),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    item.$2,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      ),
    );
  }

  Widget _bottomNav() {
    Widget item(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool active = false,
      int badge = 0,
      Color iconColor = _rdBlack,
    }) {
      final Color labelColor = active ? _rdRed : _rdBlack;

      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(
                        icon,
                        color: iconColor,
                        size: 27,
                      ),
                      if (badge > 0)
                        Positioned(
                          right: -7,
                          top: -7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: _rdRed,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              badge > 99
                                  ? '99+'
                                  : badge.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 10.5,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                if (active) ...<Widget>[
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _rdRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                item(
                  Icons.home_rounded,
                  'Home',
                  () {},
                  active: true,
                  iconColor: _rdRed,
                ),
                item(
                  Icons.grid_view_rounded,
                  'Categories',
                  _openAllCategories,
                  iconColor: const Color(0xFF2F3640),
                ),
                item(
                  Icons.directions_car_filled_rounded,
                  'RD Ride',
                  () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const RideBookingHubPage(),
                      ),
                    );
                  },
                  iconColor: const Color(0xFF1565C0),
                ),
                item(
                  Icons.confirmation_number_rounded,
                  'Ticket',
                  () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const TicketBookingHubPage(),
                      ),
                    );
                  },
                  iconColor: const Color(0xFFF57C00),
                ),
                item(
                  Icons.hotel_rounded,
                  'Hotel/Resort',
                  () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const StayVenueBookingHubPage(),
                      ),
                    );
                  },
                  iconColor: const Color(0xFF2E7D32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(child: _brandHeader()),
            SliverToBoxAdapter(child: _searchBox()),
            if (isListening)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Listening... 🎤',
                      style: TextStyle(color: _rdRed, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            // Offer banner first, then the horizontally scrollable categories.
            SliverToBoxAdapter(child: _offerBanner()),
            SliverToBoxAdapter(child: _categoriesStrip()),
            SliverToBoxAdapter(
              child: _contentWidth(
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Best Selling Products',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => selectedCategory = 'All'),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: _rdRed,
                        ),
                        label: const Text(
                          'View All',
                          style: TextStyle(
                            color: _rdRed,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (filteredProducts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: Text('No products found')),
                ),
              )
            else
              SliverLayoutBuilder(
                builder: (BuildContext context, constraints) {
                  final double availableWidth = constraints.crossAxisExtent;
                  final double contentWidth =
                      availableWidth > 1180 ? 1180 : availableWidth;
                  final double sidePadding =
                      ((availableWidth - contentWidth) / 2) + 14;
                  final int columns = _gridColumns(contentWidth);

                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      sidePadding,
                      0,
                      sidePadding,
                      8,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: contentWidth >= 900 ? 0.78 : 0.66,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                          final Map<String, dynamic> product = filteredProducts[index];
                          final List<String> images = _collectProductImages(product);
                          return ProductCard(
                            compact: true,
                            productId: product['id']?.toString() ?? '',
                            sellerId: product['sellerId']?.toString() ?? '',
                            name: product['name']?.toString() ?? 'Product',
                            price: product['price']?.toString() ?? 'Rs. 0',
                            icon: product['icon'] is IconData ? product['icon'] as IconData : Icons.shopping_bag,
                            category: product['category']?.toString() ?? 'General',
                            description: product['description']?.toString() ?? 'Quality product available at RD Online Shop.',
                            imagePath: images.isNotEmpty ? images.first : null,
                            imagePaths: images,
                            colorOptions: _stringList(product['colorOptions']),
                            sizeOptions: _stringList(product['sizeOptions']),
                            originalPrice: product['originalPrice']?.toString(),
                            discount: (product['discount'] as num?)?.toInt(),
                            rating: (product['rating'] as num?)?.toDouble() ?? 0.0,
                            inStock: product['inStock'] != false,
                          );
                        },
                        childCount: filteredProducts.length,
                      ),
                    ),
                  );
                },
              ),
            SliverToBoxAdapter(child: _benefitStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }
}

class _RdHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path()
      ..lineTo(0, size.height - 42)
      ..cubicTo(
        size.width * 0.16,
        size.height - 16,
        size.width * 0.31,
        size.height - 12,
        size.width * 0.48,
        size.height - 26,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height - 44,
        size.width * 0.84,
        size.height - 46,
        size.width,
        size.height - 30,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RdHeaderRedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFFE50914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final Path path = Path()
      ..moveTo(0, size.height - 42)
      ..cubicTo(
        size.width * 0.16,
        size.height - 16,
        size.width * 0.31,
        size.height - 12,
        size.width * 0.48,
        size.height - 26,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height - 44,
        size.width * 0.84,
        size.height - 46,
        size.width,
        size.height - 30,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
