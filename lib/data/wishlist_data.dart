import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> wishlistItems = [];

// ==========================================
// LOAD WISHLIST
// ==========================================

Future<void> loadWishlist() async {
  final prefs =
      await SharedPreferences.getInstance();

  final String? savedWishlist =
      prefs.getString('wishlistItems');

  if (savedWishlist == null ||
      savedWishlist.isEmpty) {
    wishlistItems = [];
    return;
  }

  try {
    final List decoded =
        jsonDecode(savedWishlist);

    wishlistItems = decoded.map((item) {
      final map =
          Map<String, dynamic>.from(item);

      return {
        'name': map['name'] ?? '',
        'price': map['price'] ?? '',
        'iconCode': map['iconCode'] ??
            Icons.shopping_bag.codePoint,
      };
    }).toList();
  } catch (e) {
    wishlistItems = [];
  }
}

// ==========================================
// SAVE WISHLIST
// ==========================================

Future<void> saveWishlist() async {
  final prefs =
      await SharedPreferences.getInstance();

  await prefs.setString(
    'wishlistItems',
    jsonEncode(wishlistItems),
  );
}

// ==========================================
// ADD TO WISHLIST
// ==========================================

Future<void> addToWishlist(
  Map<String, dynamic> product,
) async {
  final bool alreadyExists =
      wishlistItems.any(
    (item) =>
        item['name'].toString() ==
        product['name'].toString(),
  );

  if (alreadyExists) {
    return;
  }

  wishlistItems.add({
    'name': product['name'],
    'price': product['price'],
    'iconCode': product['iconCode'] ??
        Icons.shopping_bag.codePoint,
  });

  await saveWishlist();
}

// ==========================================
// REMOVE FROM WISHLIST
// ==========================================

Future<void> removeFromWishlist(
  String productName,
) async {
  wishlistItems.removeWhere(
    (item) =>
        item['name'].toString() ==
        productName,
  );

  await saveWishlist();
}

// ==========================================
// CHECK WISHLIST
// ==========================================

bool isInWishlist(
  String productName,
) {
  return wishlistItems.any(
    (item) =>
        item['name'].toString() ==
        productName,
  );
}