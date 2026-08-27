import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'seller_auth_page.dart';
import 'seller_product_page.dart';
import 'seller_shop_profile_page.dart';
import 'seller_order_page.dart';
import 'seller_wallet_page.dart';
import 'seller_reviews_page.dart';

class SellerDashboardPage extends StatelessWidget {
  const SellerDashboardPage({super.key});

  String _sellerPhoto(
    Map<String, dynamic> seller,
  ) {
    const List<String> fields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'logoUrl',
      'profilePhotoUrl',
      'profileImageUrl',
    ];

    for (final String field in fields) {
      final dynamic value = seller[field];

      if (value is String &&
          value.trim().isNotEmpty &&
          (value.startsWith('http://') ||
              value.startsWith('https://'))) {
        return value.trim();
      }
    }

    final dynamic photos = seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic photo in photos) {
        if (photo is String &&
            photo.trim().isNotEmpty &&
            (photo.startsWith('http://') ||
                photo.startsWith('https://'))) {
          return photo.trim();
        }
      }
    }

    return '';
  }

  Future<void> _logout(
    BuildContext context,
  ) async {
    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Seller Logout',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.logout,
              ),
              label: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!context.mounted) {
      return;
    }

    Navigator.popUntil(
      context,
      (Route<dynamic> route) => route.isFirst,
    );
  }

  Widget _sellerLogo(
    Map<String, dynamic> seller,
  ) {
    final String photo =
        _sellerPhoto(seller);

    if (photo.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white
              .withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.storefront,
          color: Colors.white,
          size: 40,
        ),
      );
    }

    return Container(
      width: 70,
      height: 70,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.network(
          photo,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return Container(
              color: Colors.white
                  .withValues(alpha: 0.18),
              child: const Icon(
                Icons.storefront,
                color: Colors.white,
                size: 40,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dashboardHeader(
    Map<String, dynamic> seller,
  ) {
    final String shopName =
        seller['shopName']
                ?.toString()
                .trim() ??
            '';

    final String ownerName =
        seller['ownerName']
                ?.toString()
                .trim() ??
            '';

    final String email =
        seller['email']
                ?.toString()
                .trim() ??
            '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1565C0),
            Color(0xFF42A5F5),
          ],
        ),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: <Widget>[
          _sellerLogo(seller),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  shopName.isEmpty
                      ? 'My Shop'
                      : shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                if (ownerName.isNotEmpty)
                  ...<Widget>[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      ownerName,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ],

                if (email.isNotEmpty)
                  ...<Widget>[
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(
                          alpha: 0.85,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],

                const SizedBox(
                  height: 8,
                ),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.18,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(20),
                  ),
                  child: const Text(
                    'Active Seller',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
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

  Widget _notLoggedIn(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline,
              size: 70,
              color: Colors.grey,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Seller login required.',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator
                    .pushAndRemoveUntil<
                        void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SellerAuthPage(),
                  ),
                  (
                    Route<dynamic> route,
                  ) =>
                      false,
                );
              },
              icon: const Icon(
                Icons.login,
              ),
              label: const Text(
                'Seller Login',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inactiveSeller(
    BuildContext context,
    Map<String, dynamic> seller,
  ) {
    final String shopName =
        seller['shopName']
                ?.toString() ??
            'Seller';

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.block,
              size: 75,
              color: Colors.red,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              '$shopName account is inactive.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Please contact RD Online Shop admin.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 20,
            ),

            FilledButton.icon(
              onPressed: () {
                _logout(context);
              },
              icon: const Icon(
                Icons.logout,
              ),
              label: const Text(
                'Logout',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sellerStats(
    String sellerId,
  ) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore
          .instance
          .collection('products')
          .where(
            'sellerId',
            isEqualTo: sellerId,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<
                    Map<String, dynamic>>>[];

        final int totalProducts =
            docs.length;

        final int inStockProducts =
            docs.where(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc,
          ) {
            final Map<String, dynamic>
                data =
                doc.data();

            return data['inStock'] ==
                true;
          },
        ).length;

        final int outOfStockProducts =
            totalProducts -
                inStockProducts;

        return Row(
          children: <Widget>[
            Expanded(
              child: _statCard(
                icon:
                    Icons.inventory_2,
                title:
                    totalProducts
                        .toString(),
                subtitle:
                    'Products',
                color: Colors.blue,
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: _statCard(
                icon:
                    Icons.check_circle,
                title:
                    inStockProducts
                        .toString(),
                subtitle:
                    'In Stock',
                color: Colors.green,
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: _statCard(
                icon: Icons.cancel,
                title:
                    outOfStockProducts
                        .toString(),
                subtitle:
                    'Out Stock',
                color: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: color,
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            subtitle,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final User? user =
        FirebaseAuth
            .instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Seller Dashboard',
          ),
          centerTitle: true,
        ),
        body:
            _notLoggedIn(
          context,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Dashboard',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: () {
              _logout(context);
            },
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore
            .instance
            .collection('sellers')
            .doc(user.uid)
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  DocumentSnapshot<
                      Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(24),
                child: Text(
                  'Could not load seller account:\n'
                  '${snapshot.error}',
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

          final DocumentSnapshot<
                  Map<String, dynamic>>
              sellerDocument =
              snapshot.data!;

          if (!sellerDocument
              .exists) {
            return _notLoggedIn(
              context,
            );
          }

          final Map<String, dynamic>
              seller =
              sellerDocument.data() ??
                  <String, dynamic>{};

          if (seller['isActive'] ==
              false) {
            return _inactiveSeller(
              context,
              seller,
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1000,
              ),
              child: ListView(
                padding:
                    const EdgeInsets
                        .all(16),
                children: <Widget>[
                  _dashboardHeader(
                    seller,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _sellerStats(
                    user.uid,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  _sellerCard(
                    context,
                    icon:
                        Icons.inventory_2,
                    color:
                        Colors.blue,
                    title:
                        'My Products',
                    subtitle:
                        'Add, edit, delete products and manage stock',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<
                            void>(
                          builder: (_) =>
                              const SellerProductPage(),
                        ),
                      );
                    },
                  ),

                  _sellerCard(
                    context,
                    icon:
                        Icons.receipt_long,
                    color:
                        Colors.orange,
                    title:
                        'My Orders',
                    subtitle:
                        'Check customer orders and delivery status',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<
                            void>(
                          builder: (_) =>
                              const SellerOrderPage(),
                        ),
                      );
                    },
                  ),

                  _sellerCard(
                    context,
                    icon: Icons
                        .account_balance_wallet,
                    color:
                        Colors.green,
                    title:
                        'Wallet & Earnings',
                    subtitle:
                        'Sales, pending settlement, paid amount and payment history',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SellerWalletPage(),
                        ),
                      );
                    },
                  ),

                  _sellerCard(
                    context,
                    icon:
                        Icons.star_rate_rounded,
                    color:
                        Colors.amber,
                    title:
                        'Reviews & Ratings',
                    subtitle:
                        'Average rating, customer reviews and product feedback',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SellerReviewsPage(),
                        ),
                      );
                    },
                  ),

                  _sellerCard(
                    context,
                    icon:
                        Icons.store,
                    color:
                        Colors.purple,
                    title:
                        'Shop Profile',
                    subtitle:
                        'Shop name, address, photo and contact',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<
                            void>(
                          builder: (_) =>
                              const SellerShopProfilePage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _sellerCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.all(
          14,
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor:
              color.withValues(
            alpha: 0.12,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle:
            Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
      ),
    );
  }

}
