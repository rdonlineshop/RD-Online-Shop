import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bus_operator_dashboard_page.dart';
import 'customer_dashboard_page.dart';
import 'delivery_person_dashboard_page.dart';
import 'homestay_module.dart';
import 'hotel_partner_dashboard_page.dart';
import 'ride_driver_requests_page.dart';
import 'seller_dashboard_page.dart';

/// TEMPORARY DEVELOPMENT TOOL.
///
/// It does NOT create another Firebase Auth account.
/// Instead, the currently signed-in Admin UID gets matching role documents
/// in each RD role collection. That lets the same email/password/UID be used
/// for Seller, Hotel Partner, Homestay Partner, Bus Operator, Delivery Person,
/// Ride Driver and Customer testing.
///
/// The page is intentionally disabled in release builds.
class UniversalTestAccessPage extends StatefulWidget {
  const UniversalTestAccessPage({super.key});

  @override
  State<UniversalTestAccessPage> createState() =>
      _UniversalTestAccessPageState();
}

class _UniversalTestAccessPageState
    extends State<UniversalTestAccessPage> {
  bool _working = false;
  bool _rolesReady = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<bool> _isCurrentUserActiveAdmin(User user) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

    final Map<String, dynamic> data =
        doc.data() ?? <String, dynamic>{};

    final String role = data['role']?.toString().trim() ?? '';

    return doc.exists &&
        data['isActive'] == true &&
        (role == 'admin' || role == 'superAdmin');
  }

  Future<void> _enableAllTestRoles() async {
    if (_working) {
      return;
    }

    if (!kDebugMode) {
      _message(
        'Universal Test Access is disabled in release builds.',
      );
      return;
    }

    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message('Please login as RD Admin first.');
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      final bool isAdmin =
          await _isCurrentUserActiveAdmin(user);

      if (!isAdmin) {
        throw StateError(
          'Only an active RD Admin can enable temporary universal test roles.',
        );
      }

      final String uid = user.uid;
      final String email = user.email?.trim() ?? '';
      final String displayName =
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'RD Universal Tester';

      final FirebaseFirestore db = FirebaseFirestore.instance;
      final WriteBatch batch = db.batch();
      final FieldValue now = FieldValue.serverTimestamp();

      // Customer
      batch.set(
        db.collection('customers').doc(uid),
        <String, dynamic>{
          'authUid': uid,
          'customerId': uid,
          'role': 'customer',
          'isActive': true,
          'name': displayName,
          'email': email,
          'phone': '',
          'universalTestAccess': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // Seller
      batch.set(
        db.collection('sellers').doc(uid),
        <String, dynamic>{
          'sellerId': uid,
          'role': 'seller',
          'accountType': 'seller',
          'shopName': 'RD Universal Test Shop',
          'ownerName': displayName,
          'phone': '',
          'address': 'RD Test Address',
          'email': email,
          'description': 'Temporary universal test seller.',
          'photoUrl': '',
          'shopPhotoUrl': '',
          'shopImageUrl': '',
          'imageUrl': '',
          'logoUrl': '',
          'shopPhotos': <String>[],
          'photoStorage': '',
          'isActive': true,
          'isApproved': true,
          'universalTestAccess': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // Hotel Partner
      batch.set(
        db.collection('hotel_partners').doc(uid),
        <String, dynamic>{
          'partnerId': uid,
          'authUid': uid,
          'role': 'hotel_partner',
          'businessName': 'RD Universal Test Hotel',
          'ownerName': displayName,
          'phone': '',
          'email': email,
          'address': 'RD Test Address',
          'registrationNumber': 'TEST',
          'panVatNumber': '',
          'photoUrl': '',
          'documentUrls': <String>[],
          'isApproved': true,
          'isActive': true,
          'status': 'approved',
          'universalTestAccess': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // Homestay Partner
      batch.set(
        db.collection('homestay_partners').doc(uid),
        <String, dynamic>{
          'partnerId': uid,
          'authUid': uid,
          'role': 'homestay_partner',
          'businessName': 'RD Universal Test Homestay',
          'ownerName': displayName,
          'phone': '',
          'email': email,
          'address': 'RD Test Address',
          'registrationNumber': 'TEST',
          'panVatNumber': '',
          'photoUrl': '',
          'documentUrls': <String>[],
          'isApproved': true,
          'isActive': true,
          'status': 'approved',
          'universalTestAccess': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // Bus Operator
      batch.set(
        db.collection('bus_operators').doc(uid),
        <String, dynamic>{
          'authUid': uid,
          'operatorId': uid,
          'role': 'busOperator',
          'companyName': 'RD Universal Test Bus',
          'ownerName': displayName,
          'phone': '',
          'address': 'RD Test Address',
          'registrationNumber': 'TEST',
          'email': email,
          'isApproved': true,
          'isActive': true,
          'status': 'approved',
          'isOnline': false,
          'universalTestAccess': true,
          'updatedAt': now,
          'lastLoginAt': now,
        },
        SetOptions(merge: true),
      );

      // Delivery Person
      batch.set(
        db.collection('delivery_persons').doc(uid),
        <String, dynamic>{
          'deliveryPersonId': uid,
          'name': displayName,
          'phone': '',
          'email': email,
          'role': 'delivery_person',
          'isActive': true,
          'isApproved': true,
          'isOnline': false,
          'currentOrderId': '',
          'latitude': null,
          'longitude': null,
          'locationUpdatedAt': null,
          'universalTestAccess': true,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );

      // Ride Driver
      batch.set(
        db.collection('ride_drivers').doc(uid),
        <String, dynamic>{
          'driverId': uid,
          'authUid': uid,
          'role': 'ride_driver',
          'name': displayName,
          'phone': '',
          'email': email,
          'vehicleType': 'Bike',
          'vehicleNumber': 'RD-TEST',
          'drivingLicenseNumber': 'RD-TEST',
          'drivingLicenseExpiry': '2099-12-31',
          'drivingLicenseFrontUrl': '',
          'drivingLicenseBackUrl': '',
          'drivingLicenseVerified': true,
          'photoUrl': '',
          'rating': 0.0,
          'isActive': true,
          'isApproved': true,
          'isOnline': false,
          'latitude': null,
          'longitude': null,
          'locationUpdatedAt': null,
          'currentRideRequestId': '',
          'universalTestAccess': true,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        _rolesReady = true;
      });

      _message(
        'Universal test roles enabled for ${email.isEmpty ? uid : email}.',
      );
    } catch (error) {
      _message('Could not enable universal test roles.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _open(Widget page) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;
    final String account = user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : user?.uid ?? 'Not signed in';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Universal Test Access',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  color: Colors.amber.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TEMPORARY DEBUG TEST TOOL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'This keeps one Firebase account/UID and gives that UID multiple RD role documents for testing. It is disabled in release builds and should be removed after testing.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_circle_rounded),
                    title: const Text(
                      'Current Test Account',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: SelectableText(account),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _working || !kDebugMode
                        ? null
                        : _enableAllTestRoles,
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key_rounded),
                    label: Text(
                      _rolesReady
                          ? 'Universal Test Roles Ready'
                          : 'Enable All Test Roles For This Account',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Open Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                  ) {
                    final int columns = constraints.maxWidth >= 760 ? 3 : 2;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
                      children: <Widget>[
                        _tile(
                          icon: Icons.storefront_rounded,
                          title: 'Seller',
                          onTap: () => _open(const SellerDashboardPage()),
                        ),
                        _tile(
                          icon: Icons.hotel_rounded,
                          title: 'Hotel Partner',
                          onTap: () => _open(const HotelPartnerDashboardPage()),
                        ),
                        _tile(
                          icon: Icons.home_work_rounded,
                          title: 'Homestay Partner',
                          onTap: () => _open(const HomestayPartnerDashboardPage()),
                        ),
                        _tile(
                          icon: Icons.directions_bus_rounded,
                          title: 'Bus Operator',
                          onTap: () => _open(const BusOperatorDashboardPage()),
                        ),
                        _tile(
                          icon: Icons.delivery_dining_rounded,
                          title: 'Delivery Person',
                          onTap: () => _open(const DeliveryPersonDashboardPage()),
                        ),
                        _tile(
                          icon: Icons.local_taxi_rounded,
                          title: 'Ride Driver',
                          onTap: () {
                            final String uid = _user?.uid ?? '';
                            if (uid.isEmpty) {
                              _message('Admin session is missing.');
                              return;
                            }
                            _open(RideDriverRequestsPage(driverId: uid));
                          },
                        ),
                        _tile(
                          icon: Icons.person_rounded,
                          title: 'Customer',
                          onTap: () => _open(const CustomerDashboardPage()),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Important: while testing from this page, use the Back button to return here. Do not press a role dashboard Logout button, because Logout intentionally signs Firebase out and restores an anonymous customer session.',
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

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _rolesReady ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 38),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
