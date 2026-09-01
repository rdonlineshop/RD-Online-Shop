
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/local_file_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cart_page.dart';
import '../data/cart_data.dart';
import '../data/wishlist_data.dart';

class ProductDetailsPage extends StatefulWidget {
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

  final String? imagePath;
  final List<String>? imagePaths;

  final List<String>? colorOptions;
  final List<String>? sizeOptions;

  const ProductDetailsPage({
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
    this.imagePath,
    this.imagePaths,
    this.colorOptions,
    this.sizeOptions,
  });

  @override
  State<ProductDetailsPage> createState() =>
      _ProductDetailsPageState();
}

class _ProductDetailsPageState
    extends State<ProductDetailsPage> {
  bool isFavorite = false;
  bool isLoadingWishlist = true;

  late final PageController _photoController;

  int _selectedPhoto = 0;

  String? _selectedColor;
  String? _selectedSize;

  List<String> get _colors =>
      widget.colorOptions ?? <String>[];

  List<String> get _sizes =>
      widget.sizeOptions ?? <String>[];

  List<String> get _photos {
    final List<String> many = widget.imagePaths
            ?.where(
              (String path) =>
                  path.trim().isNotEmpty,
            )
            .toList() ??
        <String>[];

    if (many.isNotEmpty) {
      return many;
    }

    final String path =
        widget.imagePath?.trim() ?? '';

    if (path.isNotEmpty) {
      return <String>[path];
    }

    return <String>[];
  }

  @override
  void initState() {
    super.initState();

    _photoController = PageController();

    if (_colors.isNotEmpty) {
      _selectedColor = _colors.first;
    }

    if (_sizes.length == 1) {
      _selectedSize = _sizes.first;
    }

    _loadWishlistStatus();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Color _colorForName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'black':
        return Colors.black;

      case 'white':
        return Colors.white;

      case 'grey':
      case 'gray':
        return Colors.grey;

      case 'silver':
        return Colors.blueGrey.shade300;

      case 'red':
        return Colors.red;

      case 'maroon':
        return const Color(0xFF800000);

      case 'pink':
        return Colors.pink;

      case 'magenta':
        return Colors.purpleAccent;

      case 'purple':
        return Colors.purple;

      case 'violet':
        return const Color(0xFF7F00FF);

      case 'indigo':
        return Colors.indigo;

      case 'blue':
        return Colors.blue;

      case 'navy':
        return const Color(0xFF000080);

      case 'sky blue':
        return Colors.lightBlue;

      case 'cyan':
        return Colors.cyan;

      case 'teal':
        return Colors.teal;

      case 'turquoise':
        return const Color(0xFF40E0D0);

      case 'green':
        return Colors.green;

      case 'lime':
        return Colors.lime;

      case 'olive':
        return const Color(0xFF808000);

      case 'yellow':
        return Colors.yellow;

      case 'gold':
        return const Color(0xFFFFD700);

      case 'orange':
        return Colors.orange;

      case 'coral':
        return const Color(0xFFFF7F50);

      case 'brown':
        return Colors.brown;

      case 'beige':
        return const Color(0xFFF5F5DC);

      case 'cream':
        return const Color(0xFFFFFDD0);

      case 'khaki':
        return const Color(0xFFC3B091);

      default:
        return Colors.blue;
    }
  }

  Widget _fallbackImage({
    double size = 100,
  }) {
    return Center(
      child: Icon(
        widget.icon,
        size: size,
        color: Colors.blue,
      ),
    );
  }

  Widget _productImage(
    String path, {
    BoxFit fit = BoxFit.contain,
  }) {
    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      return Image.network(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return _fallbackImage();
        },
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return _fallbackImage();
        },
      );
    }

    return buildLocalFileImage(
      path,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      fallback: _fallbackImage(),
    );
  }

  Future<void> _loadWishlistStatus() async {
    await loadWishlist();

    if (!mounted) {
      return;
    }

    setState(() {
      isFavorite =
          isInWishlist(widget.name);

      isLoadingWishlist = false;
    });
  }

  Future<void> _addToCart() async {
    if (!widget.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This product is currently out of stock.',
          ),
        ),
      );

      return;
    }

    if (_colors.isNotEmpty &&
        _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a color.',
          ),
        ),
      );

      return;
    }

    if (_sizes.isNotEmpty &&
        _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a size.',
          ),
        ),
      );

      return;
    }

    final List<String> selections =
        <String>[
      if (_selectedColor != null)
        _selectedColor!,
      if (_selectedSize != null)
        _selectedSize!,
    ];

    await addProductToCart(
      <String, dynamic>{
        'productId': widget.productId,
        'sellerId': widget.sellerId,
        'name': selections.isEmpty
            ? widget.name
            : '${widget.name} '
                '(${selections.join(', ')})',
        'productName': widget.name,
        'price': widget.price,
        'icon': widget.icon,
        if (_photos.isNotEmpty)
          'image': _photos.first,
        if (_selectedColor != null)
          'selectedColor':
              _selectedColor,
        if (_selectedSize != null)
          'selectedSize':
              _selectedSize,
      },
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cart updated successfully',
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    if (isFavorite) {
      await removeFromWishlist(
        widget.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Removed from Wishlist',
          ),
        ),
      );

      return;
    }

    await addToWishlist(
      <String, dynamic>{
        'productId': widget.productId,
        'sellerId': widget.sellerId,
        'name': widget.name,
        'price': widget.price,
        'iconCode':
            widget.icon.codePoint,
        if (_photos.isNotEmpty)
          'image': _photos.first,
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isFavorite = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Added to Wishlist',
        ),
      ),
    );
  }

  Widget _heroImage(
    String? path,
  ) {
    if (path == null ||
        path.trim().isEmpty) {
      return _fallbackImage(
        size: 130,
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(25),
      child: _productImage(
        path,
        fit: BoxFit.contain,
      ),
    );
  }

  void _openFullScreen() {
    if (_photos.isEmpty) {
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            FullScreenProductPhotos(
          photos: _photos,
          initialIndex:
              _selectedPhoto,
          fallbackIcon:
              widget.icon,
        ),
      ),
    );
  }

  String _sellerPhoto(
    Map<String, dynamic> seller,
  ) {
    const List<String> fields =
        <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'logoUrl',
      'profilePhotoUrl',
      'profileImageUrl',
    ];

    for (final String field
        in fields) {
      final dynamic value =
          seller[field];

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final dynamic photos =
        seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic value
          in photos) {
        if (value is String &&
            value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return '';
  }

  Widget _sellerAvatar(
    Map<String, dynamic> seller,
  ) {
    final String photo =
        _sellerPhoto(seller);

    if (photo.startsWith('http://') ||
        photo.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          photo,
          width: 62,
          height: 62,
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _sellerFallback();
          },
        ),
      );
    }

    return _sellerFallback();
  }

  Widget _sellerFallback() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade50,
      ),
      child: const Icon(
        Icons.storefront,
        color: Colors.blue,
        size: 34,
      ),
    );
  }

  Future<void> _phoneAction(
    String phone, {
    required bool sms,
  }) async {
    final String number =
        phone.trim().replaceAll(
              ' ',
              '',
            );

    if (number.isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: sms ? 'sms' : 'tel',
      path: number,
    );

    final bool opened =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open phone application.',
          ),
        ),
      );
    }
  }

  Future<void> _sellerEmail(
    String email,
  ) async {
    if (email.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
    );

    final bool opened =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open email application.',
          ),
        ),
      );
    }
  }

  Widget _sellerRow(
    IconData icon,
    String title,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 20,
            color: Colors.blue,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerSection() {
    if (widget.sellerId
        .trim()
        .isEmpty) {
      return Card(
        margin:
            const EdgeInsets.only(
          top: 8,
        ),
        child: const Padding(
          padding:
              EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                child: Icon(
                  Icons.storefront,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      'Sold by',
                      style: TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                    Text(
                      'RD Online Shop',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sellers')
          .doc(widget.sellerId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(16),
              child: Text(
                'Seller information is not available.',
              ),
            ),
          );
        }

        final Map<String, dynamic>
            seller =
            snapshot.data!.data() ??
                <String, dynamic>{};

        final String shopName =
            seller['shopName']
                    ?.toString() ??
                'Seller Shop';

        final String ownerName =
            seller['ownerName']
                    ?.toString() ??
                '';

        final String phone =
            seller['phone']
                    ?.toString() ??
                '';

        final String email =
            seller['email']
                    ?.toString() ??
                '';

        final String address =
            seller['address']
                    ?.toString() ??
                '';

        final bool isActive =
            seller['isActive'] != false;

        return Card(
          margin:
              const EdgeInsets.only(
            top: 8,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Sold By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                Row(
                  children: <Widget>[
                    _sellerAvatar(
                      seller,
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          Text(
                            shopName,
                            style:
                                const TextStyle(
                              fontSize:
                                  19,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          if (ownerName
                              .isNotEmpty)
                            Text(
                              ownerName,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                              ),
                            ),

                          const SizedBox(
                            height: 5,
                          ),

                          Row(
                            mainAxisSize:
                                MainAxisSize
                                    .min,
                            children:
                                <Widget>[
                              Icon(
                                isActive
                                    ? Icons
                                        .verified
                                    : Icons
                                        .block,
                                size: 17,
                                color: isActive
                                    ? Colors
                                        .green
                                    : Colors
                                        .red,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              Text(
                                isActive
                                    ? 'Active Seller'
                                    : 'Inactive Seller',
                                style:
                                    TextStyle(
                                  color: isActive
                                      ? Colors
                                          .green
                                      : Colors
                                          .red,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                  fontSize:
                                      12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (phone.isNotEmpty)
                  _sellerRow(
                    Icons.phone,
                    'Phone',
                    phone,
                  ),

                if (email.isNotEmpty)
                  _sellerRow(
                    Icons.email_outlined,
                    'Email',
                    email,
                  ),

                if (address.isNotEmpty)
                  _sellerRow(
                    Icons.location_on,
                    'Shop Location',
                    address,
                  ),

                if (phone.isNotEmpty) ...<Widget>[
                  const SizedBox(
                    height: 14,
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              isActive
                                  ? () {
                                      _phoneAction(
                                        phone,
                                        sms:
                                            false,
                                      );
                                    }
                                  : null,
                          icon:
                              const Icon(
                            Icons.call,
                          ),
                          label:
                              const Text(
                            'Call Seller',
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              isActive
                                  ? () {
                                      _phoneAction(
                                        phone,
                                        sms:
                                            true,
                                      );
                                    }
                                  : null,
                          icon:
                              const Icon(
                            Icons
                                .sms_outlined,
                          ),
                          label:
                              const Text(
                            'SMS',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (email.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: SizedBox(
                      width:
                          double.infinity,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            isActive
                                ? () {
                                    _sellerEmail(
                                      email,
                                    );
                                  }
                                : null,
                        icon:
                            const Icon(
                          Icons
                              .email_outlined,
                        ),
                        label:
                            const Text(
                          'Email Seller',
                        ),
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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Product Details',
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Wishlist',
            onPressed:
                isLoadingWishlist
                    ? null
                    : _toggleWishlist,
            icon: Icon(
              isFavorite
                  ? Icons.favorite
                  : Icons
                      .favorite_border,
              color: isFavorite
                  ? Colors.red
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Cart',
            icon: const Icon(
              Icons.shopping_cart,
            ),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const CartPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Stack(
                    clipBehavior:
                        Clip.none,
                    children: <Widget>[
                      GestureDetector(
                        onTap:
                            _openFullScreen,
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration:
                              BoxDecoration(
                            color: Colors.blue
                                .withValues(
                              alpha:
                                  0.08,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              25,
                            ),
                          ),
                          clipBehavior:
                              Clip.antiAlias,
                          child:
                              _photos
                                      .isEmpty
                                  ? _heroImage(
                                      null,
                                    )
                                  : Stack(
                                      children:
                                          <Widget>[
                                        PageView
                                            .builder(
                                          controller:
                                              _photoController,
                                          itemCount:
                                              _photos.length,
                                          onPageChanged:
                                              (
                                            int index,
                                          ) {
                                            setState(
                                              () {
                                                _selectedPhoto =
                                                    index;
                                              },
                                            );
                                          },
                                          itemBuilder:
                                              (
                                            BuildContext
                                                context,
                                            int index,
                                          ) {
                                            return _heroImage(
                                              _photos[index],
                                            );
                                          },
                                        ),
                                        if (_photos
                                                .length >
                                            1)
                                          Positioned(
                                            bottom:
                                                10,
                                            left:
                                                0,
                                            right:
                                                0,
                                            child:
                                                Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children:
                                                  List<Widget>.generate(
                                                _photos.length,
                                                (
                                                  int index,
                                                ) {
                                                  return Container(
                                                    width: 8,
                                                    height: 8,
                                                    margin: const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: index == _selectedPhoto
                                                          ? Colors.blue
                                                          : Colors.grey.shade400,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                        ),
                      ),
                      if ((widget.discount ??
                              0) >
                          0)
                        Positioned(
                          top: 12,
                          right: -10,
                          child: Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  10,
                              vertical:
                                  6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.red,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                            ),
                            child: Text(
                              '${widget.discount}% OFF',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (_photos.length >
                    1) ...<Widget>[
                  const SizedBox(
                    height: 12,
                  ),
                  SizedBox(
                    height: 66,
                    child:
                        ListView.builder(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount:
                          _photos.length,
                      itemBuilder:
                          (
                        BuildContext
                            context,
                        int index,
                      ) {
                        final bool
                            selected =
                            index ==
                                _selectedPhoto;

                        return GestureDetector(
                          onTap: () {
                            _photoController
                                .animateToPage(
                              index,
                              duration:
                                  const Duration(
                                milliseconds:
                                    250,
                              ),
                              curve: Curves
                                  .easeInOut,
                            );
                          },
                          child: Container(
                            width: 66,
                            height: 66,
                            margin:
                                const EdgeInsets
                                    .only(
                              right: 8,
                            ),
                            decoration:
                                BoxDecoration(
                              border:
                                  Border.all(
                                color: selected
                                    ? Colors
                                        .blue
                                    : Colors
                                        .grey
                                        .shade300,
                                width: selected
                                    ? 2
                                    : 1,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                8,
                              ),
                            ),
                            clipBehavior:
                                Clip.antiAlias,
                            child:
                                _productImage(
                              _photos[
                                  index],
                              fit:
                                  BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(
                  height: 28,
                ),

                Text(
                  widget.category,
                  style: TextStyle(
                    color: Colors
                        .blue.shade700,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  widget.name,
                  style:
                      const TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: <Widget>[
                    Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children:
                          <Widget>[
                        const Icon(
                          Icons.star,
                          color:
                              Colors.amber,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          '${widget.rating.toStringAsFixed(1)} rating',
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children:
                          <Widget>[
                        Icon(
                          widget.inStock
                              ? Icons
                                  .check_circle
                              : Icons
                                  .cancel,
                          color: widget
                                  .inStock
                              ? Colors
                                  .green
                              : Colors
                                  .red,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          widget.inStock
                              ? 'In Stock'
                              : 'Out of Stock',
                          style:
                              TextStyle(
                            color: widget
                                    .inStock
                                ? Colors
                                    .green
                                : Colors
                                    .red,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),

                Wrap(
                  crossAxisAlignment:
                      WrapCrossAlignment
                          .center,
                  spacing: 12,
                  children: <Widget>[
                    Text(
                      widget.price,
                      style:
                          const TextStyle(
                        fontSize: 23,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.green,
                      ),
                    ),
                    if (widget
                            .originalPrice !=
                        null)
                      Text(
                        widget
                            .originalPrice!,
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                          decoration:
                              TextDecoration
                                  .lineThrough,
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 25,
                ),

                const Text(
                  'Product Description',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  widget.description,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                if (_colors.isNotEmpty)
                  ...<Widget>[
                    const Text(
                      'Color Options',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _colors.map(
                        (
                          String color,
                        ) {
                          final bool
                              selected =
                              _selectedColor ==
                                  color;

                          return Tooltip(
                            message:
                                color,
                            child:
                                InkWell(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                22,
                              ),
                              onTap:
                                  () {
                                setState(
                                  () {
                                    _selectedColor =
                                        color;
                                  },
                                );
                              },
                              child:
                                  Container(
                                width: 42,
                                height:
                                    42,
                                decoration:
                                    BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  color:
                                      _colorForName(
                                    color,
                                  ),
                                  border:
                                      Border.all(
                                    color: selected
                                        ? Colors.blue
                                        : Colors.grey.shade400,
                                    width: selected
                                        ? 4
                                        : 1,
                                  ),
                                ),
                                child: selected
                                    ? Icon(
                                        Icons.check,
                                        color: color.trim().toLowerCase() == 'white' ||
                                                color.trim().toLowerCase() == 'yellow'
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],

                if (_sizes.isNotEmpty)
                  ...<Widget>[
                    const Text(
                      'Size',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _sizes.map(
                        (
                          String size,
                        ) {
                          return ChoiceChip(
                            label:
                                Text(
                              size,
                            ),
                            selected:
                                _selectedSize ==
                                    size,
                            onSelected:
                                (_) {
                              setState(
                                () {
                                  _selectedSize =
                                      size;
                                },
                              );
                            },
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],

                _sellerSection(),

                const SizedBox(
                  height: 25,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        isLoadingWishlist
                            ? null
                            : _toggleWishlist,
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons
                              .favorite_border,
                      color:
                          Colors.red,
                    ),
                    label: Text(
                      isFavorite
                          ? 'Added to Wishlist'
                          : 'Add to Wishlist',
                      style:
                          const TextStyle(
                        color:
                            Colors.red,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        widget.inStock
                            ? _addToCart
                            : null,
                    icon:
                        const Icon(
                      Icons
                          .shopping_cart,
                    ),
                    label: Text(
                      widget.inStock
                          ? 'Add to Cart'
                          : 'Out of Stock',
                    ),
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      OutlinedButton.icon(
                    onPressed: () {
                      Navigator
                          .push<void>(
                        context,
                        MaterialPageRoute<
                            void>(
                          builder: (_) =>
                              const CartPage(),
                        ),
                      );
                    },
                    icon:
                        const Icon(
                      Icons.shopping_bag,
                    ),
                    label:
                        const Text(
                      'View Cart',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenProductPhotos
    extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final IconData fallbackIcon;

  const FullScreenProductPhotos({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.fallbackIcon,
  });

  @override
  State<FullScreenProductPhotos>
      createState() =>
          _FullScreenProductPhotosState();
}

class _FullScreenProductPhotosState
    extends State<FullScreenProductPhotos> {
  late final PageController _controller;

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _currentIndex =
        widget.initialIndex;

    _controller =
        PageController(
      initialPage:
          widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _fallback() {
    return Center(
      child: Icon(
        widget.fallbackIcon,
        color: Colors.white,
        size: 110,
      ),
    );
  }

  Widget _photo(
    String path,
  ) {
    Widget image;

    if (path.startsWith('http://') ||
        path.startsWith('https://')) {
      image = Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return _fallback();
        },
      );
    } else if (path
        .startsWith('assets/')) {
      image = Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return _fallback();
        },
      );
    } else {
      image = buildLocalFileImage(
        path,
        fit: BoxFit.contain,
        fallback: _fallback(),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: image,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / '
          '${widget.photos.length}',
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount:
            widget.photos.length,
        onPageChanged:
            (int index) {
          setState(() {
            _currentIndex =
                index;
          });
        },
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          return _photo(
            widget.photos[index],
          );
        },
      ),
    );
  }
}