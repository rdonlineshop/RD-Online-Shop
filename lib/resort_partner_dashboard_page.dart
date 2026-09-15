import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/active_session_role.dart';

import 'resort_partner_availability_page.dart';
import 'resort_partner_bookings_page.dart';
import 'resort_partner_direct_payment_page.dart';
import 'resort_partner_fee_page.dart';
import 'resort_partner_profile_page.dart';
import 'resort_partner_rooms_page.dart';

class ResortPartnerDashboardPage extends StatelessWidget {
  const ResortPartnerDashboardPage({super.key});

  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);

  Future<void> _logout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Resort Partner Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true ||
        !context.mounted) {
      return;
    }

    // Leave the Resort Partner page first so its auth/Firestore
    // StreamBuilders cannot briefly show a progress/login-required
    // screen while the account is being signed out.
    Navigator.popUntil(
      context,
      (Route<dynamic> route) => route.isFirst,
    );

    await ActiveSessionRole.clear();
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Resort Partner login required.',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('resort_partners')
          .doc(user.uid)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<Map<String, dynamic>>>
            snapshot,
      ) {
        if (!snapshot.hasData &&
            snapshot.connectionState ==
                ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Resort Partner account.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>>?
            doc = snapshot.data;
        final Map<String, dynamic> data =
            doc?.data() ?? <String, dynamic>{};

        final bool allowed = doc?.exists == true &&
            data['isApproved'] == true &&
            data['isActive'] == true &&
            data['role'] == 'resort_partner';

        if (!allowed) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Resort Partner',
              ),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This Resort Partner account is not currently approved and active.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }

        return _dashboard(context, data);
      },
    );
  }

  Widget _dashboard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final String businessName =
        data['businessName']?.toString().trim() ?? '';
    final String ownerName =
        data['ownerName']?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Resort Partner Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            int columns = 2;
            if (constraints.maxWidth >= 1000) {
              columns = 4;
            } else if (constraints.maxWidth >= 700) {
              columns = 3;
            }

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1050),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _header(
                      businessName:
                          businessName.isEmpty
                              ? 'Resort Partner'
                              : businessName,
                      ownerName: ownerName,
                      email:
                          data['email']?.toString() ?? '',
                      phone:
                          data['phone']?.toString() ?? '',
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Resort Management',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          columns == 2 ? 0.90 : 1.18,
                      children: <Widget>[
                        _card(
                          context,
                          icon: Icons.holiday_village_rounded,
                          title: 'Resort Profile',
                          subtitle:
                              'Create and update resort information',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerProfilePage(),
                            ),
                          ),
                        ),
                        _card(
                          context,
                          icon: Icons.bed_rounded,
                          title: 'Rooms',
                          subtitle:
                              'Room types, photos, price and total rooms',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerRoomsPage(),
                            ),
                          ),
                        ),
                        _card(
                          context,
                          icon:
                              Icons.calendar_month_rounded,
                          title: 'Availability',
                          subtitle:
                              'Manage date-wise room availability',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerAvailabilityPage(),
                            ),
                          ),
                        ),
                        _card(
                          context,
                          icon: Icons.book_online_rounded,
                          title: 'Bookings',
                          subtitle:
                              'Confirm or reject customer bookings',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerBookingsPage(),
                            ),
                          ),
                        ),
                        _card(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Fees & Payments',
                          subtitle:
                              'Invoices, outstanding balance and fee payment',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerFeePage(),
                            ),
                          ),
                        ),
                        _card(
                          context,
                          icon: Icons.payments_rounded,
                          title: 'Direct Online Payment',
                          subtitle:
                              'Receive customer booking payment directly to your Resort account',
                          onTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const ResortPartnerDirectPaymentPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _rdBlue
                            .withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Resort management is connected to Firestore. '
                        'Manage profile, rooms, date-wise availability, customer bookings, '
                        'direct Resort receiving details and RD Resort fees from this dashboard.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header({
    required String businessName,
    required String ownerName,
    required String email,
    required String phone,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            _rdBlue,
            _rdGreen,
          ],
        ),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 29,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.holiday_village_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  businessName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ownerName.isNotEmpty)
                  Text(
                    ownerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const Chip(
            avatar: Icon(
              Icons.verified_rounded,
              color: _rdGreen,
            ),
            label: Text(
              'ACTIVE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 42,
                color: _rdGreen,
              ),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
