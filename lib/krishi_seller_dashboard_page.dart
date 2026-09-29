import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'krishi_seller_auth_page.dart';
import 'krishi_legal_documents_page.dart';
import 'seller_notifications_page.dart';
import 'seller_order_page.dart';
import 'krishi_product_page.dart';
import 'seller_reviews_page.dart';
import 'krishi_seller_profile_page.dart';
import 'seller_wallet_page.dart';

class KrishiSellerDashboardPage extends StatelessWidget {
  const KrishiSellerDashboardPage({super.key});

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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Krishi Seller Logout',
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
    final String photo = _sellerPhoto(seller);

    if (photo.isEmpty) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
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
              color: Colors.white.withValues(alpha: 0.18),
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
        seller['shopName']?.toString().trim() ?? '';

    final String ownerName =
        seller['ownerName']?.toString().trim() ?? '';

    final String email =
        seller['email']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1565C0),
            Color(0xFF42A5F5),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _sellerLogo(seller),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  shopName.isEmpty ? 'My Farm / Shop' : shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (ownerName.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    ownerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    seller['legalVerified'] == true
                        ? 'Verified Krishi Seller'
                        : 'Active Krishi Seller',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline,
              size: 70,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Krishi seller login required.',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const KrishiSellerAuthPage(),
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
                'Krishi Seller Login',
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
        seller['shopName']?.toString() ?? 'Krishi Seller';

    final String verificationStatus =
        seller['legalVerificationStatus']?.toString().trim() ??
            'pending';

    final bool legalSubmitted =
        seller['legalDeclarationAccepted'] == true;

    final String businessRegistrationNumber =
        seller['businessRegistrationNumber']?.toString().trim() ?? '';

    final String panNumber =
        seller['panNumber']?.toString().trim() ?? '';

    final bool registrationDocumentUploaded =
        (seller['businessRegistrationDocumentUrl']
                    ?.toString()
                    .trim() ??
                '')
            .isNotEmpty;

    final bool panDocumentUploaded =
        (seller['panDocumentUrl']
                    ?.toString()
                    .trim() ??
                '')
            .isNotEmpty;

    final String vatNumber =
        seller['vatNumber']?.toString().trim() ?? '';

    final bool vatDocumentUploaded =
        (seller['vatDocumentUrl']
                    ?.toString()
                    .trim() ??
                '')
            .isNotEmpty;

    final bool legalDocumentsComplete =
        registrationDocumentUploaded &&
            panDocumentUploaded &&
            (vatNumber.isEmpty ||
                vatDocumentUploaded);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              verificationStatus == 'rejected'
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_top_rounded,
              size: 75,
              color: verificationStatus == 'rejected'
                  ? Colors.red
                  : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              verificationStatus == 'rejected'
                  ? '$shopName verification needs changes.'
                  : '$shopName is waiting for Admin approval.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You do not need to login again. This page updates automatically when NRD Admin approves the Krishi seller account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Legal Verification',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${verificationStatus.toUpperCase()}',
                  ),
                  Text(
                    'Legal declaration: ${legalSubmitted ? 'Submitted' : 'Not submitted'}',
                  ),
                  if (businessRegistrationNumber.isNotEmpty)
                    Text(
                      'Registration No: $businessRegistrationNumber',
                    ),
                  if (panNumber.isNotEmpty)
                    Text('PAN: $panNumber'),
                  const SizedBox(height: 6),
                  Text(
                    'Registration Certificate: '
                    '${registrationDocumentUploaded ? 'Uploaded' : 'Missing'}',
                  ),
                  Text(
                    'PAN Certificate: '
                    '${panDocumentUploaded ? 'Uploaded' : 'Missing'}',
                  ),
                  if (vatNumber.isNotEmpty)
                    Text(
                      'VAT Certificate: '
                      '${vatDocumentUploaded ? 'Uploaded' : 'Missing'}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const KrishiLegalDocumentsPage(),
                    ),
                  );
                },
                icon: Icon(
                  legalDocumentsComplete
                      ? Icons.edit_document
                      : Icons.upload_file_rounded,
                ),
                label: Text(
                  legalDocumentsComplete
                      ? 'Review / Update Legal Documents'
                      : 'Upload Required Legal Documents',
                ),
              ),
            ),
            const SizedBox(height: 12),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where(
            'sellerId',
            isEqualTo: sellerId,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        final List<QueryDocumentSnapshot<Map<String, dynamic>>>
            krishiDocs = docs.where(
          (
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            final Map<String, dynamic> data = doc.data();
            final String marketplace =
                data['marketplace']?.toString().trim().toLowerCase() ?? '';
            final String productType =
                data['productType']?.toString().trim().toLowerCase() ?? '';

            return marketplace == 'krishi' ||
                productType == 'krishi' ||
                productType == 'agriculture';
          },
        ).toList();

        final int totalProducts = krishiDocs.length;

        final int inStockProducts = krishiDocs.where(
          (
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            final Map<String, dynamic> data = doc.data();

            return data['inStock'] == true;
          },
        ).length;

        final int outOfStockProducts =
            totalProducts - inStockProducts;

        return Row(
          children: <Widget>[
            Expanded(
              child: _statCard(
                icon: Icons.inventory_2,
                title: totalProducts.toString(),
                subtitle: 'Products',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.check_circle,
                title: inStockProducts.toString(),
                subtitle: 'In Stock',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.cancel,
                title: outOfStockProducts.toString(),
                subtitle: 'Out Stock',
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: color,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
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
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Krishi Seller Dashboard',
          ),
          centerTitle: true,
        ),
        body: _notLoggedIn(
          context,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Seller',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: <Widget>[
          _KrishiSellerNotificationButton(
            sellerId: user.uid,
          ),
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sellers')
            .doc(user.uid)
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Krishi seller account:\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final DocumentSnapshot<Map<String, dynamic>> sellerDocument =
              snapshot.data!;

          if (!sellerDocument.exists) {
            return _notLoggedIn(
              context,
            );
          }

          final Map<String, dynamic> seller =
              sellerDocument.data() ?? <String, dynamic>{};

          if (seller['isActive'] == false) {
            return _inactiveSeller(
              context,
              seller,
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1000,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _dashboardHeader(
                    seller,
                  ),
                  const SizedBox(height: 16),
                  _sellerStats(
                    user.uid,
                  ),
                  const SizedBox(height: 18),
                  _sellerCard(
                    context,
                    icon: Icons.inventory_2,
                    color: Colors.blue,
                    title: 'My Products',
                    subtitle:
                        'Add, edit, delete agriculture products and manage stock',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const KrishiProductPage(),
                        ),
                      );
                    },
                  ),
                  _sellerCard(
                    context,
                    icon: Icons.receipt_long,
                    color: Colors.orange,
                    title: 'My Orders',
                    subtitle:
                        'Check Krishi customer orders and delivery status',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SellerOrderPage(),
                        ),
                      );
                    },
                  ),
                  _sellerCard(
                    context,
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    title: 'Wallet & Earnings',
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
                    icon: Icons.notifications_active_rounded,
                    color: Colors.red,
                    title: 'Notifications',
                    subtitle:
                        'Admin announcements and Delivery Person pickup requests',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SellerNotificationsPage(),
                        ),
                      );
                    },
                  ),
                  _sellerCard(
                    context,
                    icon: Icons.star_rate_rounded,
                    color: Colors.amber,
                    title: 'Reviews & Ratings',
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
                    icon: Icons.store,
                    color: Colors.purple,
                    title: 'Farm / Shop Profile',
                    subtitle:
                        'Farm / shop name, address, photo and contact',
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const KrishiSellerProfilePage(),
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
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(
          14,
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color.withValues(
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
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
      ),
    );
  }
}

class _KrishiSellerNotificationButton
    extends StatefulWidget {
  const _KrishiSellerNotificationButton({
    required this.sellerId,
  });

  final String sellerId;

  @override
  State<_KrishiSellerNotificationButton>
      createState() =>
          _KrishiSellerNotificationButtonState();
}

class _KrishiSellerNotificationButtonState
    extends State<_KrishiSellerNotificationButton> {
  StreamSubscription<
          QuerySnapshot<
              Map<String, dynamic>>>?
      _poolSubscription;

  final Map<
      String,
      StreamSubscription<
          QuerySnapshot<
              Map<String, dynamic>>>> _requestSubscriptions =
      <String,
          StreamSubscription<
              QuerySnapshot<
                  Map<String, dynamic>>>>{};

  final Map<String, int>
      _pendingByOrder =
      <String, int>{};

  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(
    covariant _KrishiSellerNotificationButton
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.sellerId !=
        widget.sellerId) {
      unawaited(
        _restart(),
      );
    }
  }

  void _start() {
    final String sellerId =
        widget.sellerId.trim();

    if (sellerId.isEmpty) {
      return;
    }

    _poolSubscription =
        FirebaseFirestore.instance
            .collection(
              'krishi_delivery_pool',
            )
            .where(
              'sellerId',
              isEqualTo: sellerId,
            )
            .snapshots()
            .listen(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final Set<String> orderIds =
            snapshot.docs
                .map(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        document,
                  ) =>
                      document.id,
                )
                .toSet();

        final List<String> removed =
            _requestSubscriptions.keys
                .where(
                  (String orderId) =>
                      !orderIds.contains(
                    orderId,
                  ),
                )
                .toList();

        for (final String orderId
            in removed) {
          final StreamSubscription<
                  QuerySnapshot<
                      Map<String, dynamic>>>?
              subscription =
              _requestSubscriptions
                  .remove(
            orderId,
          );

          if (subscription != null) {
            unawaited(
              subscription.cancel(),
            );
          }

          _pendingByOrder.remove(
            orderId,
          );
        }

        for (final QueryDocumentSnapshot<
                Map<String, dynamic>>
            document in snapshot.docs) {
          if (_requestSubscriptions
              .containsKey(
            document.id,
          )) {
            continue;
          }

          _listenToOrder(
            document.id,
          );
        }

        _refreshCount();
      },
      onError: (Object _) {
        // Keep the dashboard usable if the optional badge cannot refresh.
      },
    );
  }

  void _listenToOrder(
    String orderId,
  ) {
    _requestSubscriptions[orderId] =
        FirebaseFirestore.instance
            .collection(
              'krishi_delivery_pool',
            )
            .doc(orderId)
            .collection(
              'pickup_requests',
            )
            .snapshots()
            .listen(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final int pending =
            snapshot.docs
                .where(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        document,
                  ) {
                    final Map<String, dynamic>
                        data =
                        document.data();

                    return data[
                                'requestedBy'] ==
                            'driver' &&
                        data['status'] ==
                            'pending_seller';
                  },
                )
                .length;

        _pendingByOrder[orderId] =
            pending;

        _refreshCount();
      },
      onError: (Object _) {
        _pendingByOrder[orderId] =
            0;

        _refreshCount();
      },
    );
  }

  void _refreshCount() {
    final int next =
        _pendingByOrder.values.fold<int>(
      0,
      (
        int total,
        int value,
      ) =>
          total + value,
    );

    if (!mounted ||
        next == _pendingCount) {
      return;
    }

    setState(() {
      _pendingCount = next;
    });
  }

  Future<void> _restart() async {
    await _cancelSubscriptions();

    _pendingByOrder.clear();

    if (mounted) {
      setState(() {
        _pendingCount = 0;
      });
    }

    _start();
  }

  Future<void>
      _cancelSubscriptions() async {
    final StreamSubscription<
            QuerySnapshot<
                Map<String, dynamic>>>?
        poolSubscription =
        _poolSubscription;

    if (poolSubscription != null) {
      await poolSubscription.cancel();
    }

    _poolSubscription = null;

    final List<Future<void>>
        cancellations =
        _requestSubscriptions.values
            .map(
              (
                StreamSubscription<
                        QuerySnapshot<
                            Map<String,
                                dynamic>>>
                    subscription,
              ) =>
                  subscription.cancel(),
            )
            .toList();

    _requestSubscriptions.clear();

    if (cancellations.isNotEmpty) {
      await Future.wait(
        cancellations,
      );
    }
  }

  @override
  void dispose() {
    unawaited(
      _cancelSubscriptions(),
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final String badgeText =
        _pendingCount > 99
            ? '99+'
            : _pendingCount
                .toString();

    return IconButton(
      tooltip: _pendingCount > 0
          ? 'Notifications - $_pendingCount pickup request${_pendingCount == 1 ? '' : 's'}'
          : 'Notifications',
      onPressed: () {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                const SellerNotificationsPage(),
          ),
        );
      },
      icon: Stack(
        clipBehavior:
            Clip.none,
        children: <Widget>[
          const Icon(
            Icons
                .notifications_none_rounded,
          ),
          if (_pendingCount > 0)
            Positioned(
              top: -7,
              right: -9,
              child: Container(
                constraints:
                    const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.red,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  border:
                      Border.all(
                    color:
                        Colors.white,
                    width: 1.5,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Text(
                  badgeText,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

