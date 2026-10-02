import 'package:flutter/material.dart';

import 'property_rent_post_page.dart';
import 'property_sale_post_page.dart';

class PropertyPostPage extends StatelessWidget {
  final String category;

  const PropertyPostPage({
    super.key,
    required this.category,
  });

  bool get _isRentCategory {
    final String value = category.toLowerCase();

    return value.contains('rent') ||
        value.contains('room');
  }

  @override
  Widget build(BuildContext context) {
    if (_isRentCategory) {
      return PropertyRentPostPage(
        category: category,
      );
    }

    return PropertySalePostPage(
      category: category,
    );
  }
}
