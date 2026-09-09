import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bus_operator_auth_page.dart';
import 'bus_operator_bookings_page.dart';
import 'bus_operator_schedules_page.dart';

class BusOperatorDashboardPage extends StatelessWidget {
  const BusOperatorDashboardPage({super.key});

  Future<void> _setServiceOnline(
    BuildContext context,
    String operatorId,
    bool isOnline, {
    bool showMessage = true,
  }) async {
    final FirebaseFirestore firestore =
        FirebaseFirestore.instance;
    final WriteBatch batch = firestore.batch();

    final DocumentReference<Map<String, dynamic>>
        operatorRef = firestore
            .collection('bus_operators')
            .doc(operatorId);
    final DocumentReference<Map<String, dynamic>>
        presenceRef = firestore
            .collection('bus_operator_presence')
            .doc(operatorId);

    batch.update(
      operatorRef,
      <String, dynamic>{
        'isOnline': isOnline,
        'serviceStatus': isOnline ? 'online' : 'offline',
        'serviceStatusUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      presenceRef,
      <String, dynamic>{
        'operatorId': operatorId,
        'isOnline': isOnline,
        'serviceStatus': isOnline ? 'online' : 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    try {
      await batch.commit();

      if (!showMessage || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Bus service is ONLINE. Eligible upcoming buses are now visible to customers.'
                : 'Bus service is OFFLINE. Your buses are hidden from customers.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!showMessage || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not change service status: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser != null && !currentUser.isAnonymous) {
      await _setServiceOnline(
        context,
        currentUser.uid,
        false,
        showMessage: false,
      );
    }

    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();

    if (!context.mounted) {
      return;
    }

    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BusOperatorAuthPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const BusOperatorAuthPage();
    }

    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bus_operators')
          .doc(user.uid)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Bus Operator Dashboard',
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Bus Operator account.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>>?
            document = snapshot.data;
        final Map<String, dynamic> operator =
            document?.data() ??
                <String, dynamic>{};

        if (document == null ||
            !document.exists ||
            operator['role']?.toString() !=
                'busOperator') {
          return const BusOperatorAuthPage();
        }

        final bool approved =
            operator['isApproved'] == true;
        final bool active =
            operator['isActive'] == true;

        if (!approved || !active) {
          return _pendingPage(
            context,
            operator,
          );
        }

        return _dashboard(
          context,
          user.uid,
          operator,
        );
      },
    );
  }

  Widget _pendingPage(
    BuildContext context,
    Map<String, dynamic> operator,
  ) {
    final bool approved =
        operator['isApproved'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Operator',
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
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      approved
                          ? Icons.pause_circle_outline_rounded
                          : Icons
                              .pending_actions_rounded,
                      size: 70,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      operator['companyName']
                              ?.toString() ??
                          'Bus Operator',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      approved
                          ? 'This Bus Operator account is currently inactive.'
                          : 'Registration submitted. Admin approval is required before schedules and bookings can be managed.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboard(
    BuildContext context,
    String operatorId,
    Map<String, dynamic> operator,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Operator Dashboard',
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
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _header(
                context,
                operator,
                operatorId,
              ),
              const SizedBox(height: 16),
              _stats(operatorId),
              const SizedBox(height: 18),
              _actionCard(
                context,
                icon:
                    Icons.calendar_month_rounded,
                title: 'My Schedules',
                subtitle:
                    'Add and manage your own bus routes, times, fares and seats',
                onTap: () =>
                    Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const BusOperatorSchedulesPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                icon:
                    Icons.confirmation_number_rounded,
                title: 'My Bookings',
                subtitle:
                    'Only bookings for your Bus Operator ID appear here',
                onTap: () =>
                    Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const BusOperatorBookingsPage(),
                  ),
                ),
              ),
              _actionCard(
                context,
                icon:
                    Icons.account_balance_wallet_rounded,
                title: 'Payments',
                subtitle:
                    'Pay on Bus collection and online payment status are shown inside My Bookings',
                onTap: () =>
                    Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const BusOperatorBookingsPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Map<String, dynamic> operator,
    String operatorId,
  ) {
    final bool isOnline =
        operator['isOnline'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 32,
              child: Icon(
                Icons.directions_bus_filled_rounded,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    operator['companyName']
                            ?.toString() ??
                        'Bus Operator',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    operator['ownerName']
                            ?.toString() ??
                        '',
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Operator ID: $operatorId',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ActionChip(
              tooltip: isOnline
                  ? 'Tap to go offline'
                  : 'Tap to go online',
              avatar: Icon(
                isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                size: 18,
                color: isOnline
                    ? Colors.white
                    : Colors.grey.shade700,
              ),
              label: Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: isOnline
                      ? Colors.white
                      : Colors.grey.shade800,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: isOnline
                  ? Colors.blue
                  : Colors.grey.shade200,
              side: BorderSide(
                color: isOnline
                    ? Colors.blue
                    : Colors.grey.shade400,
              ),
              onPressed: () => _setServiceOnline(
                context,
                operatorId,
                !isOnline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(String operatorId) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bus_ticket_bookings')
          .where(
            'operatorId',
            isEqualTo: operatorId,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<Map<String, dynamic>>>
            snapshot,
      ) {
        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            bookings = <QueryDocumentSnapshot<
                Map<String, dynamic>>>[
          ...?snapshot.data?.docs,
        ];

        final int total = bookings.length;
        final int pending = bookings
            .where(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) =>
                  doc.data()['bookingStatus'] ==
                  'request_submitted',
            )
            .length;
        final int issued = bookings
            .where(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc,
              ) =>
                  doc.data()['ticketStatus'] ==
                  'issued',
            )
            .length;

        return LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            return GridView.count(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio:
                  constraints.maxWidth < 430
                      ? 0.95
                      : 1.4,
              children: <Widget>[
                _statCard(
                  'Bookings',
                  total.toString(),
                ),
                _statCard(
                  'Requests',
                  pending.toString(),
                ),
                _statCard(
                  'Issued',
                  issued.toString(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
