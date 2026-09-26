import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'krishi_seller_auth_page.dart';
import 'customer_dashboard_page.dart';
import 'product_card.dart';

class KrishiMarketplacePage extends StatefulWidget {
  const KrishiMarketplacePage({super.key});

  @override
  State<KrishiMarketplacePage> createState() =>
      _KrishiMarketplacePageState();
}

class _KrishiMarketplacePageState
    extends State<KrishiMarketplacePage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _selectedCategory = 'All';

  static const List<String> _categories = <String>[
    'All',
    'Vegetables',
    'Fruits',
    'Grains & Cereals',
    'Pulses & Beans',
    'Seeds',
    'Spices',
    'Herbs',
    'Dairy',
    'Eggs',
    'Honey',
    'Organic Products',
    'Nursery & Plants',
    'Fertilizer & Compost',
    'Animal Feed',
    'Agriculture Tools',
    'Other Agriculture',
  ];

  bool _isKrishiProduct(
    Map<String, dynamic> data,
  ) {
    final String marketplace =
        data['marketplace']?.toString().trim().toLowerCase() ?? '';
    final String productType =
        data['productType']?.toString().trim().toLowerCase() ?? '';

    return marketplace == 'krishi' ||
        productType == 'krishi' ||
        productType == 'agriculture';
  }

  List<String> _images(
    Map<String, dynamic> data,
  ) {
    final List<String> result =
        <String>[];

    final dynamic raw = data['imagePaths'];
    if (raw is List) {
      for (final dynamic item in raw) {
        final String value =
            item?.toString().trim() ?? '';
        if (value.isNotEmpty &&
            !result.contains(value)) {
          result.add(value);
        }
      }
    }

    final String single =
        data['imagePath']?.toString().trim() ?? '';

    if (single.isNotEmpty &&
        !result.contains(single)) {
      result.add(single);
    }

    return result;
  }

  int _columns(
    double width,
  ) {
    if (width >= 1200) {
      return 5;
    }

    if (width >= 950) {
      return 4;
    }

    if (width >= 650) {
      return 3;
    }

    return 2;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.agriculture_rounded,
              color: Colors.green,
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'NRD Krishi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Customer',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CustomerDashboardPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.account_circle_rounded,
              size: 29,
            ),
          ),
          IconButton(
            tooltip: 'Krishi Seller',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const KrishiSellerAuthPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.storefront_rounded,
              size: 28,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              14,
              14,
              8,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText:
                    'Search Krishi products...',
                prefixIcon:
                    const Icon(Icons.search),
                border:
                    const OutlineInputBorder(),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(
                              Icons.clear,
                            ),
                          ),
              ),
            ),
          ),

          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              itemCount:
                  _categories.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(width: 8),
              itemBuilder: (
                BuildContext context,
                int index,
              ) {
                final String category =
                    _categories[index];
                final bool selected =
                    _selectedCategory ==
                        category;

                return ChoiceChip(
                  selected: selected,
                  label: Text(category),
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory =
                          category;
                    });
                  },
                );
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<
                            Map<String, dynamic>>>
                    snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'Could not load Krishi products:\n${snapshot.error}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final String search =
                    _searchController.text
                        .trim()
                        .toLowerCase();

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    docs = snapshot.data!.docs
                        .where(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        doc,
                  ) {
                    final Map<String, dynamic>
                        data = doc.data();

                    if (!_isKrishiProduct(
                      data,
                    )) {
                      return false;
                    }

                    if (data['productStatus']
                            ?.toString()
                            .trim()
                            .toLowerCase() ==
                        'inactive') {
                      return false;
                    }

                    if (data['approvalStatus']
                            ?.toString()
                            .trim()
                            .toLowerCase() ==
                        'rejected') {
                      return false;
                    }

                    final String category =
                        data['category']
                                ?.toString()
                                .trim() ??
                            '';

                    if (_selectedCategory !=
                            'All' &&
                        category !=
                            _selectedCategory) {
                      return false;
                    }

                    if (search.isEmpty) {
                      return true;
                    }

                    final String searchable =
                        <dynamic>[
                      data['name'],
                      data['brand'],
                      data['variety'],
                      data['origin'],
                      data['category'],
                      data['description'],
                    ].join(' ').toLowerCase();

                    return searchable.contains(
                      search,
                    );
                  },
                ).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                          EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons
                                .agriculture_rounded,
                            size: 78,
                            color:
                                Colors.green,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'No Krishi products found.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Products added by Krishi Sellers will appear here.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints
                        constraints,
                  ) {
                    final int columns =
                        _columns(
                      constraints.maxWidth,
                    );

                    return GridView.builder(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        14,
                        8,
                        14,
                        18,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            columns,
                        crossAxisSpacing:
                            12,
                        mainAxisSpacing:
                            12,
                        childAspectRatio:
                            constraints
                                        .maxWidth >=
                                    900
                                ? 0.80
                                : 0.68,
                      ),
                      itemCount:
                          docs.length,
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        final QueryDocumentSnapshot<
                                Map<String, dynamic>>
                            doc =
                            docs[index];

                        final Map<String, dynamic>
                            product =
                            doc.data();

                        final List<String>
                            images =
                            _images(product);

                        return ProductCard(
                          compact: true,
                          productId: doc.id,
                          sellerId:
                              product['sellerId']
                                      ?.toString() ??
                                  '',
                          name:
                              product['name']
                                      ?.toString() ??
                                  'Krishi Product',
                          price:
                              product['price']
                                      ?.toString() ??
                                  'Rs. 0',
                          icon: Icons
                              .agriculture_rounded,
                          category:
                              product['category']
                                      ?.toString() ??
                                  'Agriculture',
                          description:
                              product[
                                          'description']
                                      ?.toString() ??
                                  'Agriculture product available on NRD Krishi.',
                          imagePath:
                              images.isEmpty
                                  ? null
                                  : images.first,
                          imagePaths:
                              images,
                          colorOptions:
                              const <String>[],
                          sizeOptions:
                              const <String>[],
                          originalPrice:
                              product[
                                      'originalPrice']
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
