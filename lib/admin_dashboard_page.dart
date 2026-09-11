import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_bus_operator_management_page.dart';
import 'admin_bus_ticket_management_page.dart';
import 'admin_hotel_partner_management_page.dart';
import 'admin_hotel_management_page.dart';
import 'admin_hotel_fee_page.dart';
import 'admin_earnings_page.dart';
import 'admin_notification_center_page.dart';
import 'admin_order_page.dart';
import 'admin_product_page.dart';
import 'admin_ride_driver_management_page.dart';
import 'admin_ride_earnings_page.dart';
import 'admin_ride_history_page.dart';
import 'admin_ride_sos_page.dart';
import 'admin_ride_fare_settings_page.dart';
import 'admin_seller_page.dart';
import 'flight_ticket_booking_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _fareApprovalSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _monthlyFeeSubscription;

  int _pendingFareApprovals = 0;
  int _submittedMonthlyFees = 0;

  bool _fareLoaded = false;
  bool _monthlyFeeLoaded = false;
  bool _initialBusNoticeShown = false;

  int get _busAttentionCount =>
      _pendingFareApprovals + _submittedMonthlyFees;

  @override
  void initState() {
    super.initState();
    _listenForBusAdminAttention();
  }

  void _listenForBusAdminAttention() {
    _fareApprovalSubscription = FirebaseFirestore.instance
        .collection('bus_schedules')
        .where('fareApprovalStatus', isEqualTo: 'pending')
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final int nextCount = snapshot.docs
            .where(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  doc.data()['pendingFarePerSeat'] is num,
            )
            .length;

        final bool wasLoaded = _fareLoaded;
        final int previousCount = _pendingFareApprovals;

        if (!mounted) {
          return;
        }

        setState(() {
          _pendingFareApprovals = nextCount;
          _fareLoaded = true;
        });

        if (wasLoaded && nextCount > previousCount) {
          _showBusAdminNotice(
            'New Bus Fare Approval Request',
            '$nextCount fare request${nextCount == 1 ? '' : 's'} waiting for Admin approval.',
          );
        } else {
          _maybeShowInitialBusNotice();
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _fareLoaded = true;
        });
        _maybeShowInitialBusNotice();
      },
    );

    _monthlyFeeSubscription = FirebaseFirestore.instance
        .collection('bus_operator_monthly_fee_payments')
        .where('paymentStatus', isEqualTo: 'submitted')
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final int nextCount = snapshot.docs.length;
        final bool wasLoaded = _monthlyFeeLoaded;
        final int previousCount = _submittedMonthlyFees;

        if (!mounted) {
          return;
        }

        setState(() {
          _submittedMonthlyFees = nextCount;
          _monthlyFeeLoaded = true;
        });

        if (wasLoaded && nextCount > previousCount) {
          _showBusAdminNotice(
            'New Monthly Fee Payment Submitted',
            '$nextCount payment${nextCount == 1 ? '' : 's'} waiting for Admin verification.',
          );
        } else {
          _maybeShowInitialBusNotice();
        }
      },
      onError: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _monthlyFeeLoaded = true;
        });
        _maybeShowInitialBusNotice();
      },
    );
  }

  void _maybeShowInitialBusNotice() {
    if (!_fareLoaded ||
        !_monthlyFeeLoaded ||
        _initialBusNoticeShown) {
      return;
    }

    _initialBusNoticeShown = true;

    if (_busAttentionCount <= 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _showBusAdminNotice(
        'Bus Admin Attention',
        '$_pendingFareApprovals fare approval'
        '${_pendingFareApprovals == 1 ? '' : 's'} and '
        '$_submittedMonthlyFees monthly fee payment'
        '${_submittedMonthlyFees == 1 ? '' : 's'} waiting.',
      );
    });
  }

  void _showBusAdminNotice(
    String title,
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title\n$message'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: _openBusTicketManagement,
          ),
        ),
      );
  }

  void _openBusTicketManagement() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const AdminBusTicketManagementPage(),
      ),
    );
  }

  void _openBusAttentionSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Bus Admin Notices',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.price_check_rounded),
                  ),
                  title: const Text(
                    'Fare Approval Requests',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _pendingFareApprovals == 0
                        ? 'No fare request is waiting.'
                        : '$_pendingFareApprovals request'
                            '${_pendingFareApprovals == 1 ? '' : 's'} waiting for approval.',
                  ),
                  trailing: _attentionBadge(_pendingFareApprovals),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_rounded),
                  ),
                  title: const Text(
                    'Monthly Fee Payments',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _submittedMonthlyFees == 0
                        ? 'No submitted payment is waiting.'
                        : '$_submittedMonthlyFees payment'
                            '${_submittedMonthlyFees == 1 ? '' : 's'} waiting for verification.',
                  ),
                  trailing: _attentionBadge(_submittedMonthlyFees),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openBusTicketManagement();
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text(
                    'Open Bus Ticket Management',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attentionBadge(int count) {
    if (count <= 0) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Colors.green,
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 28,
        minHeight: 28,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fareApprovalSubscription?.cancel();
    _monthlyFeeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Admin Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!context.mounted) return;
    Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
  }

  bool _isAllowedAdmin(Map<String, dynamic> admin) {
    final String role = admin['role']?.toString().trim() ?? '';
    return admin['isActive'] == true &&
        (role == 'admin' || role == 'superAdmin');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return _accessDenied(context, 'Admin login required.');
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _accessDenied(
            context,
            'Could not verify Admin access.\n${snapshot.error}',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>>? document = snapshot.data;
        final Map<String, dynamic> admin =
            document?.data() ?? <String, dynamic>{};

        if (document == null ||
            !document.exists ||
            !_isAllowedAdmin(admin)) {
          return _accessDenied(context, 'Active Admin access required.');
        }

        return _dashboard(context);
      },
    );
  }

  Widget _dashboard(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              IconButton(
                tooltip: 'Bus Admin Notices',
                onPressed: _openBusAttentionSheet,
                icon: const Icon(Icons.notifications_active_rounded),
              ),
              if (_busAttentionCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _busAttentionCount > 99
                            ? '99+'
                            : '$_busAttentionCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Admin Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: <Widget>[
          _dashboardCard(
            icon: Icons.shopping_bag,
            title: 'Orders',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminOrderPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.inventory_2,
            title: 'Products',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminProductPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.store,
            title: 'Sellers',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminSellerPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.hotel_class_rounded,
            title: 'Hotel Partners',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminHotelPartnerManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.apartment_rounded,
            title: 'Hotels',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminHotelManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.request_quote_rounded,
            title: 'Hotel Fees',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminHotelFeePage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.people,
            title: 'Customers',
            onTap: () => _comingSoon(context, 'Customer Management'),
          ),
          _dashboardCard(
            icon: Icons.account_balance_wallet,
            title: 'Earnings',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminEarningsPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.notifications_active,
            title: 'Notifications',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminNotificationCenterPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.directions_bus_filled_rounded,
            title: 'Bus Operators',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminBusOperatorManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.confirmation_number_rounded,
            title: 'Bus Tickets',
            badgeCount: _busAttentionCount,
            onTap: _openBusTicketManagement,
          ),
          _dashboardCard(
            icon: Icons.flight_takeoff_rounded,
            title: 'Flight Tickets',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminFlightTicketManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.drive_eta_rounded,
            title: 'Ride Drivers',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideDriverManagementPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.payments_rounded,
            title: 'Ride Fares',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideFareSettingsPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Ride Commission',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideEarningsPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.route_rounded,
            title: 'Ride History',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideHistoryPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.sos_rounded,
            title: 'Ride SOS',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const AdminRideSosPage(),
              ),
            ),
          ),
          _dashboardCard(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _comingSoon(context, 'Admin Settings'),
          ),
        ],
      ),
    );
  }

  Widget _accessDenied(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon.')),
    );
  }

  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 45),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
