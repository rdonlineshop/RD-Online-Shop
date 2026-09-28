import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[];

final List<Map<String, dynamic>> _onlineCartItems =
    <Map<String, dynamic>>[];

final List<Map<String, dynamic>> _krishiCartItems =
    <Map<String, dynamic>>[];

bool _onlineCartLoaded = false;
bool _krishiCartLoaded = false;

String _activeMarketplace = 'online';

const String _onlineCartKey = 'cart_items_online';
const String _krishiCartKey = 'cart_items_krishi';
const String _legacyCartKey = 'cart_items';

bool _isKrishiMarketplace(
  String marketplace,
) {
  return marketplace.trim().toLowerCase() == 'krishi';
}

String _normalizedMarketplace(
  String marketplace,
) {
  return _isKrishiMarketplace(marketplace)
      ? 'krishi'
      : 'online';
}

String _cartKeyForMarketplace(
  String marketplace,
) {
  return _isKrishiMarketplace(marketplace)
      ? _krishiCartKey
      : _onlineCartKey;
}

List<Map<String, dynamic>> _itemsForMarketplace(
  String marketplace,
) {
  return _isKrishiMarketplace(marketplace)
      ? _krishiCartItems
      : _onlineCartItems;
}

List<Map<String, dynamic>> cartItemsForMarketplace(
  String marketplace,
) {
  return _itemsForMarketplace(marketplace);
}

void activateCartMarketplace(
  String marketplace,
) {
  _activeMarketplace =
      _normalizedMarketplace(marketplace);

  cartItems =
      _itemsForMarketplace(_activeMarketplace);
}

List<Map<String, dynamic>> _decodeCart(
  String? data,
) {
  if (data == null || data.isEmpty) {
    return <Map<String, dynamic>>[];
  }

  try {
    final dynamic decoded = jsonDecode(data);

    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    return decoded
        .whereType<Map>()
        .map(
      (Map<dynamic, dynamic> raw) {
        final Map<String, dynamic> cart =
            Map<String, dynamic>.from(raw);

        final dynamic iconCode =
            cart['iconCode'];

        if (iconCode != null) {
          final int? code =
              int.tryParse(iconCode.toString());

          if (code != null) {
            cart['icon'] =
                _iconFromCode(code);
          }
        }

        cart['quantity'] =
            _normalizedQuantity(cart);

        return cart;
      },
    ).toList();
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
}

String _encodeCart(
  List<Map<String, dynamic>> items,
) {
  final List<Map<String, dynamic>> data =
      items.map(
    (Map<String, dynamic> item) {
      return <String, dynamic>{
        'productId': item['productId'] ?? '',
        'sellerId': item['sellerId'] ?? '',
        'sellerShopName':
            item['sellerShopName'] ?? '',
        'sellerLatitude':
            item['sellerLatitude'],
        'sellerLongitude':
            item['sellerLongitude'],
        'productName':
            item['productName'] ?? item['name'],
        'name': item['name'],
        'price': item['price'],
        'quantity':
            _normalizedQuantity(item),

        if (item['marketplace'] != null)
          'marketplace':
              item['marketplace'],
        if (item['productType'] != null)
          'productType':
              item['productType'],
        if (item['sellerType'] != null)
          'sellerType':
              item['sellerType'],
        if (item['unit'] != null)
          'unit': item['unit'],
        if (item['pricePerUnit'] != null)
          'pricePerUnit':
              item['pricePerUnit'],
        if (item['stock'] != null)
          'stock': item['stock'],
        if (item['brand'] != null)
          'brand': item['brand'],
        if (item['variety'] != null)
          'variety': item['variety'],
        if (item['origin'] != null)
          'origin': item['origin'],
        if (item['category'] != null)
          'category': item['category'],
        if (item['organic'] != null)
          'organic': item['organic'],

        if (item['image'] != null)
          'image': item['image'],
        if (item['selectedColor'] != null)
          'selectedColor':
              item['selectedColor'],
        if (item['selectedSize'] != null)
          'selectedSize':
              item['selectedSize'],
        if (item['icon'] is IconData)
          'iconCode':
              (item['icon'] as IconData)
                  .codePoint,
      };
    },
  ).toList();

  return jsonEncode(data);
}

Future<void> _migrateLegacyCart(
  SharedPreferences prefs,
) async {
  final bool alreadySeparated =
      prefs.containsKey(_onlineCartKey) ||
          prefs.containsKey(_krishiCartKey);

  if (alreadySeparated) {
    return;
  }

  final String? legacy =
      prefs.getString(_legacyCartKey);

  if (legacy == null || legacy.isEmpty) {
    return;
  }

  final List<Map<String, dynamic>> oldItems =
      _decodeCart(legacy);

  final List<Map<String, dynamic>> onlineItems =
      oldItems
          .where(
            (Map<String, dynamic> item) =>
                !isKrishiCartItem(item),
          )
          .toList();

  final List<Map<String, dynamic>> krishiItems =
      oldItems
          .where(isKrishiCartItem)
          .toList();

  await prefs.setString(
    _onlineCartKey,
    _encodeCart(onlineItems),
  );

  await prefs.setString(
    _krishiCartKey,
    _encodeCart(krishiItems),
  );

  await prefs.remove(_legacyCartKey);
}

IconData _iconFromCode(int iconCode) {
  final Map<int, IconData> icons = <int, IconData>{
    Icons.phone_android.codePoint: Icons.phone_android,
    Icons.phone_iphone.codePoint: Icons.phone_iphone,
    Icons.laptop.codePoint: Icons.laptop,
    Icons.laptop_mac.codePoint: Icons.laptop_mac,
    Icons.headphones.codePoint: Icons.headphones,
    Icons.checkroom.codePoint: Icons.checkroom,
    Icons.directions_run.codePoint: Icons.directions_run,
    Icons.spa.codePoint: Icons.spa,
    Icons.chair.codePoint: Icons.chair,
    Icons.table_restaurant.codePoint: Icons.table_restaurant,
    Icons.kitchen.codePoint: Icons.kitchen,
    Icons.toys.codePoint: Icons.toys,
    Icons.sports_soccer.codePoint: Icons.sports_soccer,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.build.codePoint: Icons.build,
    Icons.pets.codePoint: Icons.pets,
    Icons.menu_book.codePoint: Icons.menu_book,
    Icons.local_grocery_store.codePoint:
        Icons.local_grocery_store,
    Icons.child_care.codePoint: Icons.child_care,
    Icons.diamond.codePoint: Icons.diamond,
    Icons.watch.codePoint: Icons.watch,
    Icons.agriculture_rounded.codePoint:
        Icons.agriculture_rounded,
  };

  return icons[iconCode] ?? Icons.shopping_bag;
}

bool isKrishiCartItem(
  Map<String, dynamic> item,
) {
  final String marketplace =
      item['marketplace']?.toString().trim().toLowerCase() ?? '';
  final String productType =
      item['productType']?.toString().trim().toLowerCase() ?? '';
  final String sellerType =
      item['sellerType']?.toString().trim().toLowerCase() ?? '';

  return marketplace == 'krishi' ||
      productType == 'krishi' ||
      productType == 'agriculture' ||
      sellerType == 'krishi';
}

double _quantityAsDouble(
  dynamic value, {
  double fallback = 1,
}) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

num _normalizedQuantity(
  Map<String, dynamic> item,
) {
  final double value = _quantityAsDouble(
    item['quantity'],
  );

  if (isKrishiCartItem(item)) {
    return value;
  }

  return value.round();
}

double _priceAsDouble(
  dynamic value,
) {
  if (value is num) {
    return value.toDouble();
  }

  final String cleaned = value
          ?.toString()
          .replaceAll(
            RegExp(r'[^0-9.\-]'),
            '',
          )
          .trim() ??
      '';

  return double.tryParse(cleaned) ?? 0;
}

// =============================================================
// LOAD CART
// =============================================================

Future<void> loadCart({
  String marketplace = 'online',
}) async {
  final String normalized =
      _normalizedMarketplace(marketplace);

  final List<Map<String, dynamic>> target =
      _itemsForMarketplace(normalized);

  final bool alreadyLoaded =
      normalized == 'krishi'
          ? _krishiCartLoaded
          : _onlineCartLoaded;

  if (!alreadyLoaded) {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    await _migrateLegacyCart(prefs);

    target
      ..clear()
      ..addAll(
        _decodeCart(
          prefs.getString(
            _cartKeyForMarketplace(normalized),
          ),
        ),
      );

    if (normalized == 'krishi') {
      _krishiCartLoaded = true;
    } else {
      _onlineCartLoaded = true;
    }
  }

  activateCartMarketplace(normalized);
}

// =============================================================
// SAVE CART
// =============================================================

Future<void> saveCart({
  String? marketplace,
}) async {
  final String normalized =
      _normalizedMarketplace(
    marketplace ?? _activeMarketplace,
  );

  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  final List<Map<String, dynamic>> items =
      _itemsForMarketplace(normalized);

  await prefs.setString(
    _cartKeyForMarketplace(normalized),
    _encodeCart(items),
  );
}

// =============================================================
// ADD PRODUCT
// =============================================================

Future<void> addProductToCart(
  Map<String, dynamic> product, {
  num? selectedQuantity,
}) async {
  final bool krishi =
      isKrishiCartItem(product);

  await loadCart(
    marketplace:
        krishi ? 'krishi' : 'online',
  );

  final String marketplace =
      krishi ? 'krishi' : 'online';

  final List<Map<String, dynamic>> target =
      _itemsForMarketplace(marketplace);

  activateCartMarketplace(marketplace);

  final String productId =
      product['productId']?.toString() ?? '';

  final int index =
      target.indexWhere(
    (Map<String, dynamic> item) =>
        item['productId']?.toString() ==
        productId,
  );

  final double addQuantity =
      selectedQuantity == null
          ? 1
          : _quantityAsDouble(
              selectedQuantity,
            );

  if (index >= 0) {
    if (krishi ||
        isKrishiCartItem(
          target[index],
        )) {
      final double current =
          _quantityAsDouble(
        target[index]['quantity'],
      );

      target[index]['quantity'] =
          current + addQuantity;

      // Refresh Krishi/order-routing metadata if an older cart item
      // existed before this update.
      for (final String key in <String>[
        'sellerId',
        'sellerShopName',
        'sellerLatitude',
        'sellerLongitude',
        'productName',
        'name',
        'price',
        'marketplace',
        'productType',
        'sellerType',
        'unit',
        'pricePerUnit',
        'stock',
        'brand',
        'variety',
        'origin',
        'category',
        'organic',
        'image',
      ]) {
        if (product[key] != null) {
          target[index][key] =
              product[key];
        }
      }
    } else {
      final int qty =
          int.tryParse(
                target[index]['quantity']
                        ?.toString() ??
                    '1',
              ) ??
              1;

      target[index]['quantity'] =
          qty + 1;
    }
  } else {
    final Map<String, dynamic> newItem =
        <String, dynamic>{
      'productId':
          product['productId']?.toString() ?? '',
      'sellerId':
          product['sellerId']?.toString() ?? '',
      'sellerShopName':
          product['sellerShopName'] ?? '',
      'sellerLatitude':
          product['sellerLatitude'],
      'sellerLongitude':
          product['sellerLongitude'],
      'productName':
          product['productName'] ?? product['name'],
      'name': product['name'],
      'price': product['price'],
      'quantity':
          krishi ? addQuantity : 1,

      if (product['marketplace'] != null)
        'marketplace':
            product['marketplace'],
      if (product['productType'] != null)
        'productType':
            product['productType'],
      if (product['sellerType'] != null)
        'sellerType':
            product['sellerType'],
      if (product['unit'] != null)
        'unit': product['unit'],
      if (product['pricePerUnit'] != null)
        'pricePerUnit':
            product['pricePerUnit'],
      if (product['stock'] != null)
        'stock': product['stock'],
      if (product['brand'] != null)
        'brand': product['brand'],
      if (product['variety'] != null)
        'variety': product['variety'],
      if (product['origin'] != null)
        'origin': product['origin'],
      if (product['category'] != null)
        'category': product['category'],
      if (product['organic'] != null)
        'organic': product['organic'],
    };

    if (product['image'] != null) {
      newItem['image'] =
          product['image'];
    }

    if (product['selectedColor'] != null) {
      newItem['selectedColor'] =
          product['selectedColor'];
    }

    if (product['selectedSize'] != null) {
      newItem['selectedSize'] =
          product['selectedSize'];
    }

    if (product['icon'] is IconData) {
      newItem['icon'] =
          product['icon'];
    }

    target.add(newItem);
  }

  await saveCart(marketplace: marketplace);
}

// =============================================================
// CLEAR CART
// =============================================================

Future<void> clearCart({
  String? marketplace,
}) async {
  final String normalized =
      _normalizedMarketplace(
    marketplace ?? _activeMarketplace,
  );

  final List<Map<String, dynamic>> target =
      _itemsForMarketplace(normalized);

  target.clear();

  final SharedPreferences prefs =
      await SharedPreferences.getInstance();

  await prefs.remove(
    _cartKeyForMarketplace(normalized),
  );

  activateCartMarketplace(normalized);
}

// =============================================================
// CART COUNT
// =============================================================

int getCartItemCount({
  String marketplace = 'online',
}) {
  int count = 0;

  final List<Map<String, dynamic>> items =
      _itemsForMarketplace(marketplace);

  for (final Map<String, dynamic> item
      in items) {
    if (isKrishiCartItem(item)) {
      count += 1;
      continue;
    }

    count +=
        int.tryParse(
              item['quantity']?.toString() ?? '1',
            ) ??
            1;
  }

  return count;
}

// =============================================================
// TOTAL PRICE
// =============================================================

int getTotalPrice({
  String marketplace = 'online',
}) {
  double total = 0;

  final List<Map<String, dynamic>> items =
      _itemsForMarketplace(marketplace);

  for (final Map<String, dynamic> item
      in items) {
    final double amount =
        _priceAsDouble(
      item['pricePerUnit'] ??
          item['price'],
    );

    final double qty =
        _quantityAsDouble(
      item['quantity'],
    );

    total += amount * qty;
  }

  return total.round();
}
