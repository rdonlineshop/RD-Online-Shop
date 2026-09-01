import 'package:flutter/material.dart';

import 'screens/product_details_page.dart';
import 'services/local_file_image.dart';

class ProductCard extends StatelessWidget {
  final String productId;
  final String sellerId;

  final String name;
  final String price;
  final IconData icon;
  final String category;
  final String description;

  final String? originalPrice;
  final int? discount;
  final double rating;
  final bool inStock;
  final bool compact;

  final String? imagePath;
  final List<String>? imagePaths;

  final List<String>? colorOptions;
  final List<String>? sizeOptions;

  const ProductCard({
    super.key,
    this.productId = '',
    this.sellerId = '',
    required this.name,
    required this.price,
    required this.icon,
    this.category = 'General',
    this.description =
        'Quality product available at RD Online Shop.',
    this.originalPrice,
    this.discount,
    this.rating = 4.5,
    this.inStock = true,
    this.compact = false,
    this.imagePath,
    this.imagePaths,
    this.colorOptions,
    this.sizeOptions,
  });

  bool _isNetworkPath(String path) {
    return path.startsWith('http://') ||
        path.startsWith('https://');
  }

  bool _isAssetPath(String path) {
    return path.startsWith('assets/');
  }

  List<String> get _cleanImagePaths {
    final List<String> paths =
        <String>[];

    if (imagePaths != null) {
      for (final String path in imagePaths!) {
        final String cleanPath = path.trim();

        if (cleanPath.isNotEmpty &&
            !paths.contains(cleanPath)) {
          paths.add(cleanPath);
        }
      }
    }

    final String singlePath =
        imagePath?.trim() ?? '';

    if (singlePath.isNotEmpty &&
        !paths.contains(singlePath)) {
      paths.add(singlePath);
    }

    return paths;
  }

  String? get _primaryPath {
    final List<String> paths =
        _cleanImagePaths;

    if (paths.isEmpty) {
      return null;
    }

    // Cross-device photo gets first priority.
    for (final String path in paths) {
      if (_isNetworkPath(path)) {
        return path;
      }
    }

    // Bundled asset gets second priority.
    for (final String path in paths) {
      if (_isAssetPath(path)) {
        return path;
      }
    }

    // Old local photo is last fallback.
    return paths.first;
  }

  List<String> get _orderedImagePaths {
    final List<String> paths =
        _cleanImagePaths;

    final List<String> networkPaths =
        paths
            .where(_isNetworkPath)
            .toList();

    final List<String> assetPaths =
        paths
            .where(_isAssetPath)
            .toList();

    final List<String> localPaths =
        paths
            .where(
              (String path) =>
                  !_isNetworkPath(path) &&
                  !_isAssetPath(path),
            )
            .toList();

    return <String>[
      ...networkPaths,
      ...assetPaths,
      ...localPaths,
    ];
  }

  void _openDetails(
    BuildContext context,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductDetailsPage(
          productId: productId,
          sellerId: sellerId,
          name: name,
          price: price,
          icon: icon,
          category: category,
          description: description,
          originalPrice: originalPrice,
          discount: discount,
          rating: rating,
          inStock: inStock,
          imagePath: _primaryPath,
          imagePaths:
              _orderedImagePaths,
          colorOptions:
              colorOptions,
          sizeOptions:
              sizeOptions,
        ),
      ),
    );
  }

  Widget _imageOrIcon({
    double iconSize = 42,
  }) {
    final String? path =
        _primaryPath;

    final Widget fallback = Center(
      child: Icon(
        icon,
        size: iconSize,
        color: Colors.blue,
      ),
    );

    if (path == null ||
        path.trim().isEmpty) {
      return fallback;
    }

    if (_isNetworkPath(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    if (_isAssetPath(path)) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return fallback;
        },
      );
    }

    return buildLocalFileImage(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fallback: fallback,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!compact) {
      return Card(
        margin:
            const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: ListTile(
          onTap: () {
            _openDetails(context);
          },
          leading: ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: SizedBox(
              width: 55,
              height: 55,
              child: _imageOrIcon(),
            ),
          ),
          title: Text(name),
          subtitle: Text(
            price,
            style: const TextStyle(
              color: Colors.green,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 18,
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          _openDetails(context);
        },
        borderRadius:
            BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  Colors.grey.shade200,
            ),
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: Stack(
                  children: <Widget>[
                    Container(
                      width:
                          double.infinity,
                      decoration:
                          BoxDecoration(
                        color: Colors.blue
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                      ),
                      clipBehavior:
                          Clip.antiAlias,
                      child: Center(
                        child:
                            _imageOrIcon(
                          iconSize: 58,
                        ),
                      ),
                    ),

                    if ((discount ?? 0) >
                        0)
                      Positioned(
                        top: 5,
                        left: 5,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.red,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              6,
                            ),
                          ),
                          child: Text(
                            '$discount% OFF',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 8,
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

              const SizedBox(
                height: 7,
              ),

              Text(
                name,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Row(
                children: <Widget>[
                  const Icon(
                    Icons.star,
                    color:
                        Colors.amber,
                    size: 14,
                  ),
                  Text(
                    ' ${rating.toStringAsFixed(1)}',
                    style:
                        const TextStyle(
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    inStock
                        ? Icons
                            .check_circle
                        : Icons.cancel,
                    color: inStock
                        ? Colors.green
                        : Colors.red,
                    size: 14,
                  ),
                ],
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                price,
                style:
                    const TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              if (originalPrice != null &&
                  originalPrice!
                      .trim()
                      .isNotEmpty)
                Text(
                  originalPrice!,
                  style:
                      const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    decoration:
                        TextDecoration
                            .lineThrough,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}