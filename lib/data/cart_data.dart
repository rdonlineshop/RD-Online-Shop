import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> cartItems = [];

bool _cartLoaded = false;


IconData _iconFromCode(int iconCode) {
  final Map<int, IconData> icons = {
    Icons.phone_android.codePoint: Icons.phone_android,
    Icons.phone_iphone.codePoint: Icons.phone_iphone,
    Icons.laptop.codePoint: Icons.laptop,
    Icons.laptop_mac.codePoint: Icons.laptop_mac,
    Icons.headphones.codePoint: Icons.headphones,
    Icons.checkroom.codePoint: Icons.checkroom,
    Icons.directions_run.codePoint: Icons.directions_run,
    Icons.spa.codePoint: Icons.spa,
    Icons.chair.codePoint: Icons.chair,
    Icons.table_restaurant.codePoint:
        Icons.table_restaurant,
    Icons.kitchen.codePoint: Icons.kitchen,
    Icons.toys.codePoint: Icons.toys,
    Icons.sports_soccer.codePoint:
        Icons.sports_soccer,
    Icons.directions_car.codePoint:
        Icons.directions_car,
    Icons.build.codePoint: Icons.build,
    Icons.pets.codePoint: Icons.pets,
    Icons.menu_book.codePoint: Icons.menu_book,
    Icons.local_grocery_store.codePoint:
        Icons.local_grocery_store,
    Icons.child_care.codePoint: Icons.child_care,
    Icons.diamond.codePoint: Icons.diamond,
    Icons.watch.codePoint: Icons.watch,
  };

  return icons[iconCode] ?? Icons.shopping_bag;
}


// LOAD CART

Future<void> loadCart() async {

  if (_cartLoaded) {
    return;
  }

  final SharedPreferences prefs =
      await SharedPreferences.getInstance();


  final String? data =
      prefs.getString('cart_items');


  if (data != null && data.isNotEmpty) {

    final List<dynamic> decoded =
        jsonDecode(data);


    cartItems =
        decoded.map((item) {

      final Map<String,dynamic> cart =
          Map<String,dynamic>.from(item);


      if(cart['iconCode'] != null){

        cart['icon'] =
            _iconFromCode(
              cart['iconCode'],
            );
      }


      cart['quantity'] =
          int.tryParse(
            cart['quantity'].toString(),
          ) ?? 1;


      return cart;


    }).toList();

  }


  _cartLoaded = true;

}



// SAVE CART

Future<void> saveCart() async {

  final SharedPreferences prefs =
      await SharedPreferences.getInstance();


  final List<Map<String,dynamic>> data =
      cartItems.map((item){

    return {

      // PRODUCT DATA
      'productId':
          item['productId'] ?? '',

      'sellerId':
          item['sellerId'] ?? '',

      'sellerShopName':
          item['sellerShopName'] ?? '',

      'sellerLatitude':
          item['sellerLatitude'],

      'sellerLongitude':
          item['sellerLongitude'],

      'productName':
          item['productName'] ??
          item['name'],

      'name':
          item['name'],

      'price':
          item['price'],


      // QUANTITY
      'quantity':
          int.tryParse(
            item['quantity']
                .toString(),
          ) ?? 1,


      // IMAGE
      if(item['image'] != null)
        'image':
            item['image'],


      // SELECT OPTIONS
      if(item['selectedColor'] != null)
        'selectedColor':
            item['selectedColor'],


      if(item['selectedSize'] != null)
        'selectedSize':
            item['selectedSize'],


      // ICON
      if(item['icon'] is IconData)
        'iconCode':
            (item['icon'] as IconData)
                .codePoint,


    };

  }).toList();



  await prefs.setString(
    'cart_items',
    jsonEncode(data),
  );

}



// ADD PRODUCT

Future<void> addProductToCart(
    Map<String,dynamic> product,
) async {


  await loadCart();


  final String productId =
      product['productId']
          ?.toString() ?? '';


  final int index =
      cartItems.indexWhere(
        (item)=>
          item['productId']
              .toString()
              ==
          productId,
      );



  if(index >=0){

    final int qty =
        int.tryParse(
          cartItems[index]['quantity']
              .toString(),
        ) ?? 1;


    cartItems[index]['quantity']
        = qty + 1;


  }
  else {


    final Map<String,dynamic> newItem =
    {

      'productId':
          product['productId']
              ?.toString() ?? '',


      'sellerId':
          product['sellerId']
              ?.toString() ?? '',

      'sellerShopName':
          product['sellerShopName'] ?? '',

      'sellerLatitude':
          product['sellerLatitude'],

      'sellerLongitude':
          product['sellerLongitude'],

      'productName':
          product['productName']
              ??
          product['name'],


      'name':
          product['name'],


      'price':
          product['price'],


      'quantity':
          1,


    };



    if(product['image'] != null){

      newItem['image'] =
          product['image'];

    }



    if(product['selectedColor'] != null){

      newItem['selectedColor'] =
          product['selectedColor'];

    }



    if(product['selectedSize'] != null){

      newItem['selectedSize'] =
          product['selectedSize'];

    }



    if(product['icon'] is IconData){

      newItem['icon'] =
          product['icon'];

    }



    cartItems.add(newItem);

  }



  await saveCart();

}



// CLEAR CART

Future<void> clearCart() async {

  cartItems.clear();

  final SharedPreferences prefs =
      await SharedPreferences.getInstance();


  await prefs.remove(
    'cart_items',
  );


}



// CART COUNT

int getCartItemCount(){

  int count = 0;


  for(final item in cartItems){

    count +=
      int.tryParse(
        item['quantity']
            .toString(),
      ) ?? 1;

  }


  return count;

}



// TOTAL PRICE

int getTotalPrice(){

  int total = 0;


  for(final item in cartItems){

    final String price =
        item['price']
            .toString()
            .replaceAll(
              'Rs.',
              '',
            )
            .replaceAll(
              ',',
              '',
            )
            .trim();



    final int amount =
        int.tryParse(price) ?? 0;



    final int qty =
        int.tryParse(
          item['quantity']
              .toString(),
        ) ?? 1;



    total += amount * qty;

  }


  return total;

}