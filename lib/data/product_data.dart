import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

final List<Map<String, dynamic>> products =
    <Map<String, dynamic>>[];

final FirebaseFirestore _firestore =
    FirebaseFirestore.instance;

final CollectionReference<Map<String, dynamic>>
    _productsCollection =
    _firestore.collection('products');

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    _productsSubscription;

const List<String> productCategories = <String>[
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

IconData iconForCategory(String category) {
  switch (category) {
    case 'Phones':
      return Icons.phone_android;

    case 'Computers':
      return Icons.laptop_mac;

    case 'Electronics':
      return Icons.headphones;

    case 'Watches & Smartwatches':
      return Icons.watch;

    case 'Fashion':
    case 'Clothes':
    case 'Clothing':
      return Icons.checkroom;

    case 'Shoes':
      return Icons.directions_run;

    case 'Ayurvedic & Herbs':
      return Icons.eco;

    case 'Beauty':
      return Icons.spa;

    case 'Home':
      return Icons.home;

    case 'Furniture':
      return Icons.chair;

    case 'Kitchen':
      return Icons.kitchen;

    case 'Toys':
      return Icons.toys;

    case 'Sports':
      return Icons.sports_soccer;

    case 'Automotive':
    case 'Cars & Light Vehicles':
      return Icons.directions_car;

    case 'Motorcycles & Scooters':
    case 'Motorcycle Parts & Accessories':
      return Icons.two_wheeler;

    case 'Bicycles':
      return Icons.pedal_bike;

    case 'Commercial Vehicles':
      return Icons.local_shipping;

    case 'Car Parts & Accessories':
      return Icons.car_repair;

    case 'Tools':
      return Icons.build;

    case 'Machinery & Industrial Equipment':
      return Icons.precision_manufacturing;

    case 'Building Materials':
      return Icons.construction;

    case 'Electrical Supplies':
      return Icons.electrical_services;

    case 'Safety Equipment':
    case 'Health & Personal Care':
      return Icons.health_and_safety;

    case 'Pet Supplies':
      return Icons.pets;

    case 'Books':
      return Icons.menu_book;

    case 'Groceries':
      return Icons.local_grocery_store;

    case 'Food':
    case 'Food & Beverages':
      return Icons.restaurant;

    case 'Cool Drinks':
      return Icons.local_drink;

    case 'Meat & Seafood':
      return Icons.set_meal;

    case 'Baby':
      return Icons.child_care;

    case 'Jewelry':
      return Icons.diamond;

    case 'Accessories':
      return Icons.watch;

    case 'Eyewear & Sunglasses':
      return Icons.visibility;

    case 'Office & Stationery':
      return Icons.edit_note;

    case 'Garden & Outdoor':
      return Icons.yard;

    case 'Travel & Luggage':
      return Icons.luggage;

    case 'Musical Instruments':
      return Icons.music_note;

    case 'Mobile Accessories':
      return Icons.cable;

    case 'Computer Accessories':
      return Icons.keyboard;

    case 'Gaming':
      return Icons.sports_esports;

    case 'Cameras & Photography':
      return Icons.camera_alt;

    case 'Appliances':
      return Icons.microwave;

    case 'Digital Products':
      return Icons.cloud_download;

    case 'Party & Gifts':
      return Icons.card_giftcard;

    case 'Services':
      return Icons.handyman;

    default:
      return Icons.shopping_bag;
  }
}

double _priceNumber(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  final String text = value
      ?.toString()
      .replaceAll(',', '')
      .replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      ) ??
      '';

  return double.tryParse(text) ?? 0;
}

int _automaticDiscount(
  double sellingPrice,
  double originalPrice,
) {
  if (sellingPrice <= 0 ||
      originalPrice <= 0 ||
      originalPrice <= sellingPrice) {
    return 0;
  }

  return (((originalPrice - sellingPrice) /
              originalPrice) *
          100)
      .round();
}

Map<String, dynamic> _product(
  String name,
  String price,
  String originalPrice,
  int discount,
  double rating,
  String category, {
  String? imagePath,
  bool inStock = true,
}) {
  return <String, dynamic>{
    'id':
        name.toLowerCase().replaceAll(' ', '_'),
    'name': name,
    'description': '',
    'brand': '',
    'sku': '',
    'price': price,
    'originalPrice': originalPrice,
    'discount': discount,
    'rating': rating,
    'reviewCount': 0,
    'soldCount': 0,
    'category': category,
    'inStock': inStock,
    'stockQuantity': inStock ? 1 : 0,
    'imagePath': imagePath,
    'imagePaths': imagePath == null
        ? <String>[]
        : <String>[imagePath],
    'colorOptions': <String>[],
    'sizeOptions': <String>[],
    'sellerId': '',
    'sellerShopName': 'RD Online Shop',
    'sellerEmail': '',
    'productStatus': 'active',
    'approvalStatus': 'approved',
    'icon': iconForCategory(category),
  };
}

final List<Map<String, dynamic>> _defaultProducts =
    <Map<String, dynamic>>[
  _product(
    'Samsung Galaxy A56',
    'Rs. 45,000',
    'Rs. 49,000',
    8,
    4.6,
    'Phones',
    imagePath:
        'assets/products/samsung_galaxy_a56.png',
  ),
  _product(
    'iPhone 16 Pro Max',
    'Rs. 210,000',
    'Rs. 225,000',
    7,
    4.9,
    'Phones',
  ),
  _product(
    'Gaming Laptop Pro',
    'Rs. 125,000',
    'Rs. 140,000',
    11,
    4.7,
    'Computers',
    imagePath:
        'assets/products/gaming_laptop_pro.png',
  ),
  _product(
    'Wireless Headphones',
    'Rs. 4,500',
    'Rs. 5,500',
    18,
    4.3,
    'Electronics',
  ),
  _product(
    'Men Casual Jacket',
    'Rs. 4,200',
    'Rs. 5,000',
    16,
    4.2,
    'Fashion',
  ),
  _product(
    'Running Sneakers',
    'Rs. 3,500',
    'Rs. 4,000',
    13,
    4.4,
    'Shoes',
  ),
  _product(
    'Face Care Gift Set',
    'Rs. 2,500',
    'Rs. 3,000',
    17,
    4.4,
    'Beauty',
  ),
  _product(
    'LED Table Lamp',
    'Rs. 1,800',
    'Rs. 2,200',
    18,
    4.3,
    'Home',
  ),
  _product(
    'Modern Wooden Chair',
    'Rs. 4,500',
    'Rs. 5,500',
    18,
    4.4,
    'Furniture',
    imagePath:
        'assets/products/modern_wooden_chair.png',
  ),
  _product(
    'Study Table',
    'Rs. 9,500',
    'Rs. 11,000',
    14,
    4.5,
    'Furniture',
  ),
  _product(
    'Electric Rice Cooker',
    'Rs. 5,200',
    'Rs. 6,000',
    13,
    4.5,
    'Kitchen',
    imagePath:
        'assets/products/electric_rice_cooker.png',
  ),
  _product(
    'Remote Control Toy Car',
    'Rs. 2,200',
    'Rs. 2,800',
    21,
    4.3,
    'Toys',
  ),
  _product(
    'Football Training Ball',
    'Rs. 1,500',
    'Rs. 1,900',
    21,
    4.2,
    'Sports',
  ),
  _product(
    'Car Phone Holder',
    'Rs. 1,200',
    'Rs. 1,500',
    20,
    4.1,
    'Automotive',
  ),
  _product(
    'Home Tool Kit',
    'Rs. 3,800',
    'Rs. 4,500',
    16,
    4.5,
    'Tools',
  ),
  _product(
    'Pet Food Bowl Set',
    'Rs. 950',
    'Rs. 1,200',
    21,
    4.3,
    'Pet Supplies',
  ),
  _product(
    'English Learning Book',
    'Rs. 650',
    'Rs. 800',
    19,
    4.4,
    'Books',
  ),
  _product(
    'Healthy Grocery Basket',
    'Rs. 2,300',
    'Rs. 2,700',
    15,
    4.2,
    'Groceries',
  ),
  _product(
    'Baby Care Set',
    'Rs. 3,500',
    'Rs. 4,200',
    17,
    4.6,
    'Baby',
  ),
  _product(
    'Silver Necklace',
    'Rs. 6,500',
    'Rs. 7,500',
    13,
    4.5,
    'Jewelry',
  ),
  _product(
    'Classic Wrist Watch',
    'Rs. 4,800',
    'Rs. 5,500',
    13,
    4.3,
    'Accessories',
    inStock: false,
  ),
];

Map<String, dynamic> normalizeProduct(
  Map<String, dynamic> source,
) {
  final Map<String, dynamic> product =
      Map<String, dynamic>.from(source);

  final String category =
      product['category']?.toString() ??
          'Other';

  product['id'] =
      product['id']?.toString() ?? '';

  product['name'] =
      product['name']?.toString() ??
          'Unnamed Product';

  product['description'] =
      product['description']?.toString() ?? '';

  product['brand'] =
      product['brand']?.toString() ?? '';

  product['sku'] =
      product['sku']?.toString() ?? '';

  product['price'] =
      product['price']?.toString() ??
          'Rs. 0';

  product['originalPrice'] =
      product['originalPrice']?.toString();

  final double priceValue =
      product['priceValue'] is num
          ? (product['priceValue'] as num)
              .toDouble()
          : _priceNumber(product['price']);

  final double originalPriceValue =
      product['originalPriceValue'] is num
          ? (product['originalPriceValue'] as num)
              .toDouble()
          : _priceNumber(
              product['originalPrice'],
            );

  product['priceValue'] = priceValue;

  product['originalPriceValue'] =
      originalPriceValue;

  final int storedDiscount =
      (product['discount'] as num?)
              ?.toInt() ??
          0;

  product['discount'] =
      storedDiscount > 0
          ? storedDiscount
          : _automaticDiscount(
              priceValue,
              originalPriceValue,
            );

  product['category'] = category;

  product['icon'] =
      iconForCategory(category);

  final bool oldInStock =
      product['inStock'] != false;

  int stockQuantity =
      (product['stockQuantity'] as num?)
              ?.toInt() ??
          (oldInStock ? 1 : 0);

  if (stockQuantity < 0) {
    stockQuantity = 0;
  }

  product['stockQuantity'] =
      stockQuantity;

  product['productStatus'] =
      product['productStatus']
              ?.toString() ??
          'active';

  product['approvalStatus'] =
      product['approvalStatus']
              ?.toString() ??
          'approved';

  product['inStock'] =
      oldInStock &&
          stockQuantity > 0 &&
          product['productStatus'] !=
              'inactive';

  product['rating'] =
      (product['rating'] as num?)
              ?.toDouble() ??
          0.0;

  product['reviewCount'] =
      (product['reviewCount'] as num?)
              ?.toInt() ??
          0;

  product['soldCount'] =
      (product['soldCount'] as num?)
              ?.toInt() ??
          0;

  product['sellerId'] =
      product['sellerId']?.toString() ?? '';

  product['sellerShopName'] =
      product['sellerShopName']
              ?.toString() ??
          '';

  product['sellerEmail'] =
      product['sellerEmail']
              ?.toString() ??
          '';

  final dynamic savedPaths =
      product['imagePaths'];

  if (savedPaths is List) {
    product['imagePaths'] = savedPaths
        .whereType<String>()
        .map(
          (String path) => path.trim(),
        )
        .where(
          (String path) =>
              path.isNotEmpty,
        )
        .toList();
  } else {
    final String? imagePath =
        product['imagePath']?.toString();

    product['imagePaths'] =
        imagePath == null ||
                imagePath.trim().isEmpty
            ? <String>[]
            : <String>[
                imagePath.trim(),
              ];
  }

  final List<String> imagePaths =
      (product['imagePaths'] as List)
          .whereType<String>()
          .toList();

  product['imagePath'] =
      imagePaths.isEmpty
          ? null
          : imagePaths.first;

  product['colorOptions'] =
      (product['colorOptions'] as List?)
              ?.whereType<String>()
              .map(
                (String value) =>
                    value.trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty,
              )
              .toList() ??
          <String>[];

  product['sizeOptions'] =
      (product['sizeOptions'] as List?)
              ?.whereType<String>()
              .map(
                (String value) =>
                    value.trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty,
              )
              .toList() ??
          <String>[];

  product['searchText'] = <String>[
    product['name']?.toString() ?? '',
    product['brand']?.toString() ?? '',
    category,
    product['sellerShopName']
            ?.toString() ??
        '',
    product['sku']?.toString() ?? '',
  ].join(' ').toLowerCase();

  return product;
}

Map<String, dynamic> _firestoreSafeProduct(
  Map<String, dynamic> item, {
  bool isNew = false,
}) {
  final Map<String, dynamic> product =
      normalizeProduct(item);

  final Map<String, dynamic> data =
      <String, dynamic>{
    'id': product['id'],
    'name': product['name'],
    'description':
        product['description'],
    'brand': product['brand'],
    'sku': product['sku'],
    'price': product['price'],
    'priceValue':
        product['priceValue'],
    'originalPrice':
        product['originalPrice'],
    'originalPriceValue':
        product['originalPriceValue'],
    'discount':
        product['discount'],
    'rating':
        product['rating'],
    'reviewCount':
        product['reviewCount'],
    'soldCount':
        product['soldCount'],
    'category':
        product['category'],
    'inStock':
        product['inStock'],
    'stockQuantity':
        product['stockQuantity'],
    'imagePath':
        product['imagePath'],
    'imagePaths':
        (product['imagePaths'] as List?)
                ?.whereType<String>()
                .toList() ??
            <String>[],
    'colorOptions':
        (product['colorOptions'] as List?)
                ?.whereType<String>()
                .toList() ??
            <String>[],
    'sizeOptions':
        (product['sizeOptions'] as List?)
                ?.whereType<String>()
                .toList() ??
            <String>[],
    'sellerId':
        product['sellerId'],
    'sellerShopName':
        product['sellerShopName'],
    'sellerEmail':
        product['sellerEmail'],
    'productStatus':
        product['productStatus'],
    'approvalStatus':
        product['approvalStatus'],
    'searchText':
        product['searchText'],
    'updatedAt':
        FieldValue.serverTimestamp(),
  };

  if (isNew) {
    data['createdAt'] =
        FieldValue.serverTimestamp();
  }

  return data;
}

Future<void> loadProducts() async {
  await _productsSubscription?.cancel();

  final QuerySnapshot<Map<String, dynamic>>
      snapshot =
      await _productsCollection.get();

  if (snapshot.docs.isEmpty) {
    await _uploadDefaultProducts();
  }

  final QuerySnapshot<Map<String, dynamic>>
      firstSnapshot =
      await _productsCollection.get();

  products
    ..clear()
    ..addAll(
      firstSnapshot.docs.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
        ) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(
            document.data(),
          );

          data['id'] = document.id;

          return normalizeProduct(data);
        },
      ),
    );

  _productsSubscription =
      _productsCollection
          .snapshots()
          .listen(
    (
      QuerySnapshot<Map<String, dynamic>>
          snapshot,
    ) {
      products
        ..clear()
        ..addAll(
          snapshot.docs.map(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  document,
            ) {
              final Map<String, dynamic>
                  data =
                  Map<String, dynamic>.from(
                document.data(),
              );

              data['id'] =
                  document.id;

              return normalizeProduct(
                data,
              );
            },
          ),
        );
    },
  );
}

Stream<List<Map<String, dynamic>>>
    sellerProductsStream(
  String sellerId,
) {
  if (sellerId.trim().isEmpty) {
    return Stream<
        List<Map<String, dynamic>>>.value(
      <Map<String, dynamic>>[],
    );
  }

  return _productsCollection
      .where(
        'sellerId',
        isEqualTo: sellerId.trim(),
      )
      .snapshots()
      .map(
    (
      QuerySnapshot<Map<String, dynamic>>
          snapshot,
    ) {
      final List<Map<String, dynamic>>
          sellerProducts =
          snapshot.docs.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              document,
        ) {
          final Map<String, dynamic> data =
              Map<String, dynamic>.from(
            document.data(),
          );

          data['id'] = document.id;

          return normalizeProduct(data);
        },
      ).toList();

      sellerProducts.sort(
        (
          Map<String, dynamic> a,
          Map<String, dynamic> b,
        ) {
          final dynamic aTime =
              a['updatedAt'];

          final dynamic bTime =
              b['updatedAt'];

          final int aValue =
              aTime is Timestamp
                  ? aTime
                      .millisecondsSinceEpoch
                  : 0;

          final int bValue =
              bTime is Timestamp
                  ? bTime
                      .millisecondsSinceEpoch
                  : 0;

          return bValue.compareTo(aValue);
        },
      );

      return sellerProducts;
    },
  );
}

Future<void> _uploadDefaultProducts() async {
  final WriteBatch batch =
      _firestore.batch();

  for (final Map<String, dynamic>
      product in _defaultProducts) {
    final String id =
        product['id'].toString();

    final DocumentReference<
            Map<String, dynamic>>
        document =
        _productsCollection.doc(id);

    batch.set(
      document,
      _firestoreSafeProduct(
        product,
        isNew: true,
      ),
    );
  }

  await batch.commit();
}

Future<void> saveProducts() async {
  final WriteBatch batch =
      _firestore.batch();

  for (final Map<String, dynamic>
      item in products) {
    final String id =
        item['id']?.toString() ?? '';

    if (id.isEmpty) {
      continue;
    }

    batch.set(
      _productsCollection.doc(id),
      _firestoreSafeProduct(item),
      SetOptions(merge: true),
    );
  }

  await batch.commit();
}

Future<void> addProduct(
  Map<String, dynamic> product,
) async {
  final DocumentReference<
          Map<String, dynamic>>
      document =
      _productsCollection.doc();

  final String sellerId =
      product['sellerId']
              ?.toString()
              .trim() ??
          '';

  final Map<String, dynamic> newProduct =
      normalizeProduct(
    <String, dynamic>{
      ...product,
      'id': document.id,
      'sku':
          product['sku']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? product['sku']
              : 'RD-${document.id.substring(0, 8).toUpperCase()}',
      'sellerShopName':
          product['sellerShopName']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? product['sellerShopName']
              : sellerId.isEmpty
                  ? 'RD Online Shop'
                  : '',
      'approvalStatus':
          product['approvalStatus'] ??
              'approved',
      'productStatus':
          product['productStatus'] ??
              'active',
    },
  );

  await document.set(
    _firestoreSafeProduct(
      newProduct,
      isNew: true,
    ),
  );
}

Future<void> addSellerProduct(
  Map<String, dynamic> product, {
  required String sellerId,
  required String sellerShopName,
  required String sellerEmail,
}) async {
  if (sellerId.trim().isEmpty) {
    throw Exception(
      'Seller login is required.',
    );
  }

  final DocumentReference<
          Map<String, dynamic>>
      document =
      _productsCollection.doc();

  final Map<String, dynamic> newProduct =
      normalizeProduct(
    <String, dynamic>{
      ...product,
      'id': document.id,
      'sellerId': sellerId.trim(),
      'sellerShopName':
          sellerShopName.trim(),
      'sellerEmail':
          sellerEmail.trim(),
      'sku':
          product['sku']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? product['sku']
              : 'RD-${document.id.substring(0, 8).toUpperCase()}',
      'approvalStatus':
          product['approvalStatus'] ??
              'approved',
      'productStatus':
          product['productStatus'] ??
              'active',
    },
  );

  await document.set(
    _firestoreSafeProduct(
      newProduct,
      isNew: true,
    ),
  );
}

Future<void> updateProduct(
  String id,
  Map<String, dynamic> updatedProduct,
) async {
  if (id.trim().isEmpty) {
    return;
  }

  final DocumentReference<
          Map<String, dynamic>>
      document =
      _productsCollection.doc(id);

  final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await document.get();

  final Map<String, dynamic> existing =
      snapshot.data() ??
          <String, dynamic>{};

  final Map<String, dynamic>
      normalizedProduct =
      normalizeProduct(
    <String, dynamic>{
      ...existing,
      ...updatedProduct,
      'id': id,
    },
  );

  await document.set(
    _firestoreSafeProduct(
      normalizedProduct,
    ),
    SetOptions(merge: true),
  );
}

Future<void> updateSellerProduct(
  String id,
  Map<String, dynamic> updatedProduct, {
  required String sellerId,
  required String sellerShopName,
  required String sellerEmail,
}) async {
  if (id.trim().isEmpty ||
      sellerId.trim().isEmpty) {
    throw Exception(
      'Invalid seller or product.',
    );
  }

  final DocumentReference<
          Map<String, dynamic>>
      document =
      _productsCollection.doc(id);

  final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await document.get();

  if (!snapshot.exists) {
    throw Exception(
      'Product could not be found.',
    );
  }

  final Map<String, dynamic> existing =
      snapshot.data() ??
          <String, dynamic>{};

  final String ownerId =
      existing['sellerId']
              ?.toString()
              .trim() ??
          '';

  if (ownerId != sellerId.trim()) {
    throw Exception(
      'You can only edit your own product.',
    );
  }

  final Map<String, dynamic>
      normalizedProduct =
      normalizeProduct(
    <String, dynamic>{
      ...existing,
      ...updatedProduct,
      'id': id,
      'sellerId': sellerId.trim(),
      'sellerShopName':
          sellerShopName.trim(),
      'sellerEmail':
          sellerEmail.trim(),
    },
  );

  await document.set(
    _firestoreSafeProduct(
      normalizedProduct,
    ),
    SetOptions(merge: true),
  );
}

Future<void> deleteProduct(String id) async {
  if (id.trim().isEmpty) {
    return;
  }

  await _productsCollection
      .doc(id)
      .delete();
}

Future<void> deleteSellerProduct(
  String id, {
  required String sellerId,
}) async {
  if (id.trim().isEmpty ||
      sellerId.trim().isEmpty) {
    throw Exception(
      'Invalid seller or product.',
    );
  }

  final DocumentReference<
          Map<String, dynamic>>
      document =
      _productsCollection.doc(id);

  final DocumentSnapshot<
          Map<String, dynamic>>
      snapshot =
      await document.get();

  if (!snapshot.exists) {
    return;
  }

  final String ownerId =
      snapshot.data()?['sellerId']
              ?.toString()
              .trim() ??
          '';

  if (ownerId != sellerId.trim()) {
    throw Exception(
      'You can only delete your own product.',
    );
  }

  await document.delete();
}

Future<void> disposeProductListener() async {
  await _productsSubscription?.cancel();
  _productsSubscription = null;
}