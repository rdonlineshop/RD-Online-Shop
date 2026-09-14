import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminHomestayManagementPage
    extends StatefulWidget {
  const AdminHomestayManagementPage({
    super.key,
  });

  @override
  State<AdminHomestayManagementPage>
      createState() =>
          _AdminHomestayManagementPageState();
}

class _AdminHomestayManagementPageState
    extends State<AdminHomestayManagementPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdOrange =
      Color(0xFFF57C00);

  String _filter = 'all';

  Future<void> _setHomestayState(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc, {
    required bool approved,
    required bool active,
    required String status,
  }) async {
    try {
      await doc.reference.update(
        <String, dynamic>{
          'isApproved': approved,
          'isActive': active,
          'status': status,
          if (approved)
            'approvedAt':
                FieldValue
                    .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Homestay approved and activated.'
                  : status == 'inactive'
                      ? 'Homestay deactivated.'
                      : 'Homestay status updated.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not update homestay.\n'
            '$error',
          ),
        ),
      );
    }
  }

  bool _matches(
    Map<String, dynamic> data,
  ) {
    final bool approved =
        data['isApproved'] == true;

    final bool active =
        data['isActive'] == true;

    final String status =
        data['status']?.toString() ?? '';

    switch (_filter) {
      case 'pending':
        return !approved &&
            status == 'pending';
      case 'active':
        return approved && active;
      case 'inactive':
        return approved && !active;
      case 'all':
        return true;
    }

    return true;
  }

  Color _statusColor(
    Map<String, dynamic> data,
  ) {
    if (data['isApproved'] == true &&
        data['isActive'] == true) {
      return _rdGreen;
    }

    if (data['isApproved'] == true) {
      return Colors.grey.shade700;
    }

    return _rdOrange;
  }

  String _statusText(
    Map<String, dynamic> data,
  ) {
    if (data['isApproved'] == true &&
        data['isActive'] == true) {
      return 'APPROVED • ACTIVE';
    }

    if (data['isApproved'] == true) {
      return 'APPROVED • INACTIVE';
    }

    return 'PENDING APPROVAL';
  }

  void _showDetails(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final List<dynamic> facilities =
        data['facilities'] is List
            ? data['facilities']
                as List<dynamic>
            : <dynamic>[];

    showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            data['name']?.toString() ??
                'Homestay',
          ),
          content: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 580,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                mainAxisSize:
                    MainAxisSize.min,
                children: <Widget>[
                  _detail(
                    'Location',
                    data['location']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Address',
                    data['address']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'City',
                    data['city']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Area',
                    data['area']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Phone',
                    data['phone']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Email',
                    data['email']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Check-in',
                    data['checkInTime']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Check-out',
                    data['checkOutTime']
                            ?.toString() ??
                        '',
                  ),
                  _detail(
                    'Status',
                    _statusText(data),
                  ),
                  if (facilities.isNotEmpty) ...<
                      Widget>[
                    const SizedBox(
                      height: 8,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: facilities
                          .map(
                            (dynamic value) =>
                                Chip(
                              label: Text(
                                value
                                    .toString(),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if ((data['description']
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty) ...<
                      Widget>[
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      data['description']
                          .toString(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SelectableText(
                    'Homestay ID: ${doc.id}\n'
                    'Partner ID: '
                    '${data['partnerId'] ?? ''}',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detail(
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child:
                SelectableText(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Homestay Management',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(
                  Icons.home_work_rounded,
                ),
                text: 'Homestays',
              ),
              Tab(
                icon: Icon(
                  Icons
                      .book_online_rounded,
                ),
                text: 'Bookings',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _homestaysTab(),
            _bookingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _homestaysTab() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('homestays')
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load homestays.\n'
              '${snapshot.error}',
              textAlign:
                  TextAlign.center,
            ),
          );
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            all =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<
                    Map<String, dynamic>>>[];

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            docs =
            all
                .where(
                  (
                    QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        doc,
                  ) =>
                      _matches(
                    doc.data(),
                  ),
                )
                .toList();

        final int pending =
            all
                .where(
                  (
                    QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        doc,
                  ) =>
                      doc.data()[
                              'isApproved'] !=
                          true &&
                      doc.data()['status'] ==
                          'pending',
                )
                .length;

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: <Color>[
                        Color(
                          0xFF1565C0,
                        ),
                        Color(
                          0xFF2E7D32,
                        ),
                      ],
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(16),
                  ),
                  child: Text(
                    '${all.length} homestay(s) • '
                    '$pending pending approval',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal,
                  child:
                      SegmentedButton<
                          String>(
                    segments: const <
                        ButtonSegment<
                            String>>[
                      ButtonSegment<String>(
                        value: 'all',
                        label: Text('All'),
                      ),
                      ButtonSegment<String>(
                        value: 'pending',
                        label:
                            Text('Pending'),
                      ),
                      ButtonSegment<String>(
                        value: 'active',
                        label:
                            Text('Active'),
                      ),
                      ButtonSegment<String>(
                        value: 'inactive',
                        label:
                            Text('Inactive'),
                      ),
                    ],
                    selected:
                        <String>{_filter},
                    onSelectionChanged:
                        (
                      Set<String> value,
                    ) {
                      setState(() {
                        _filter =
                            value.first;
                      });
                    },
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                if (docs.isEmpty)
                  const Card(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'No homestay found.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...docs.map(
                    _homestayCard,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _homestayCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final bool approved =
        data['isApproved'] == true;

    final bool active =
        data['isActive'] == true;

    final String cover =
        data['coverUrl']
                ?.toString()
                .trim() ??
            '';

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(12),
                child: Image.network(
                  cover,
                  height: 155,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) =>
                          const SizedBox(
                    height: 90,
                    child: Icon(
                      Icons
                          .home_work_rounded,
                      size: 45,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    data['name']
                            ?.toString() ??
                        'Homestay',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _statusText(data),
                    style: TextStyle(
                      color:
                          _statusColor(
                        data,
                      ),
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              data['location']
                      ?.toString() ??
                  '',
            ),
            Text(
              data['phone']
                      ?.toString() ??
                  '',
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () =>
                      _showDetails(doc),
                  icon: const Icon(
                    Icons
                        .visibility_rounded,
                  ),
                  label: const Text(
                    'Details',
                  ),
                ),
                if (!approved)
                  FilledButton.icon(
                    onPressed: () =>
                        _setHomestayState(
                      doc,
                      approved: true,
                      active: true,
                      status:
                          'approved',
                    ),
                    icon: const Icon(
                      Icons
                          .verified_rounded,
                    ),
                    label: const Text(
                      'Approve Homestay',
                    ),
                  ),
                if (approved)
                  FilledButton
                      .tonalIcon(
                    onPressed: () =>
                        _setHomestayState(
                      doc,
                      approved: true,
                      active: !active,
                      status: active
                          ? 'inactive'
                          : 'approved',
                    ),
                    icon: Icon(
                      active
                          ? Icons
                              .pause_circle_rounded
                          : Icons
                              .play_circle_rounded,
                    ),
                    label: Text(
                      active
                          ? 'Deactivate'
                          : 'Activate',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              'Homestay ID: ${doc.id} • '
              'Partner: '
              '${data['partnerId'] ?? ''}',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingsTab() {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(
            'homestay_bookings',
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load homestay bookings.\n'
              '${snapshot.error}',
              textAlign:
                  TextAlign.center,
            ),
          );
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            docs =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<
                    Map<String, dynamic>>>[];

        docs.sort(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                first,
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                second,
          ) {
            final Timestamp? a =
                first.data()['createdAt']
                    as Timestamp?;

            final Timestamp? b =
                second.data()['createdAt']
                    as Timestamp?;

            return (b
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
              a?.millisecondsSinceEpoch ??
                  0,
            );
          },
        );

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                Text(
                  'All Homestay Bookings '
                  '(${docs.length})',
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (docs.isEmpty)
                  const Card(
                    child: Padding(
                      padding:
                          EdgeInsets.all(
                        24,
                      ),
                      child: Text(
                        'No homestay booking yet.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...docs.map(
                    (
                      QueryDocumentSnapshot<
                              Map<String,
                                  dynamic>>
                          doc,
                    ) {
                      final Map<String,
                              dynamic>
                          data =
                          doc.data();

                      return Card(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 10,
                        ),
                        child: ListTile(
                          leading:
                              const CircleAvatar(
                            child: Icon(
                              Icons
                                  .book_online_rounded,
                            ),
                          ),
                          title: Text(
                            '${data['homestayName'] ?? 'Homestay'} • '
                            '${data['roomName'] ?? 'Room'}',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          subtitle: Text(
                            '${data['guestName'] ?? ''} • '
                            '${data['bookingStatus'] ?? ''}\n'
                            'Rs. '
                            '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} • '
                            '${data['paymentStatus'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing:
                              IconButton(
                            tooltip:
                                'Details',
                            onPressed: () =>
                                _showBookingDetails(
                              context,
                              doc,
                            ),
                            icon: const Icon(
                              Icons
                                  .visibility_rounded,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBookingDetails(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title:
              const Text('Booking Details'),
          content: SelectableText(
            'Booking ID: ${doc.id}\n'
            'Homestay: ${data['homestayName'] ?? ''}\n'
            'Room: ${data['roomName'] ?? ''}\n'
            'Guest: ${data['guestName'] ?? ''}\n'
            'Phone: ${data['guestPhone'] ?? ''}\n'
            'Rooms: ${data['roomCount'] ?? 0}\n'
            'Nights: ${data['nights'] ?? 0}\n'
            'Status: ${data['bookingStatus'] ?? ''}\n'
            'Payment: ${data['paymentStatus'] ?? ''}\n'
            'Total: Rs. '
            '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
