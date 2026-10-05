import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPropertyManagementPage extends StatelessWidget {
  const AdminPropertyManagementPage({super.key});

  static const List<_AdminPropertyModule> _modules =
      <_AdminPropertyModule>[
    _AdminPropertyModule(
      title: 'Overview',
      subtitle: 'Property & Rent summary',
      icon: Icons.dashboard_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Partners',
      subtitle: 'Owners, agents and offices',
      icon: Icons.badge_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Listings',
      subtitle: 'View all sale and rent listings',
      icon: Icons.real_estate_agent_rounded,
    ),
    _AdminPropertyModule(
      title: 'Approval Queue',
      subtitle: 'Review pending listings and partners',
      icon: Icons.fact_check_rounded,
    ),
    _AdminPropertyModule(
      title: 'Sold / Rented',
      subtitle: 'Completed and closed listings',
      icon: Icons.task_alt_rounded,
    ),
    _AdminPropertyModule(
      title: 'Earnings',
      subtitle: 'Property business earnings',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _AdminPropertyModule(
      title: 'Commission',
      subtitle: 'NRD commission settings and due amounts',
      icon: Icons.percent_rounded,
    ),
    _AdminPropertyModule(
      title: 'Commission Payments',
      subtitle: 'Pending, approved and rejected payments',
      icon: Icons.payments_rounded,
    ),
    _AdminPropertyModule(
      title: 'Reports & Complaints',
      subtitle: 'Listing and partner reports',
      icon: Icons.report_problem_rounded,
    ),
    _AdminPropertyModule(
      title: 'Deleted / Archived',
      subtitle: 'Review, restore or permanently remove records',
      icon: Icons.archive_rounded,
    ),
    _AdminPropertyModule(
      title: 'Verification Documents',
      subtitle: 'Partner and property document review',
      icon: Icons.verified_user_rounded,
    ),
    _AdminPropertyModule(
      title: 'Property Settings',
      subtitle: 'Business rules and admin controls',
      icon: Icons.settings_rounded,
    ),
  ];

  void _openModule(
    BuildContext context,
    String title,
  ) {
    Widget page;

    switch (title) {
      case 'Overview':
        page = const _PropertyAdminOverviewPage();
        break;
      case 'Property Partners':
        page = const _PropertyPartnersAdminPage();
        break;
      case 'Property Listings':
        page = const _PropertyListingsAdminPage();
        break;
      case 'Approval Queue':
        page = const _PropertyApprovalQueuePage();
        break;
      case 'Sold / Rented':
        page = const _PropertyClosedListingsPage();
        break;
      case 'Earnings':
        page = const _PropertyEarningsPage();
        break;
      case 'Commission':
        page = const _PropertyCommissionPage();
        break;
      case 'Commission Payments':
        page = const _PropertyCommissionPaymentsPage();
        break;
      case 'Reports & Complaints':
        page = const _PropertyReportsPage();
        break;
      case 'Deleted / Archived':
        page = const _PropertyDeletedArchivedPage();
        break;
      case 'Verification Documents':
        page = const _PropertyVerificationPage();
        break;
      case 'Property Settings':
        page = const _PropertySettingsPage();
        break;
      default:
        return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Property & Rent Admin',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final int columns =
              constraints.maxWidth >= 1200
                  ? 4
                  : constraints.maxWidth >= 800
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1300,
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _modules.length,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  // Give single-column mobile cards enough vertical room
                  // for titles/subtitles that wrap on narrow screens.
                  // Tablet/desktop sizing remains unchanged.
                  mainAxisExtent:
                      columns == 1 ? 250 : null,
                  childAspectRatio:
                      columns == 1 ? 1.0 : 1.25,
                ),
                itemBuilder: (
                  BuildContext context,
                  int index,
                ) {
                  final _AdminPropertyModule item =
                      _modules[index];

                  return Card(
                    elevation: 3,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openModule(
                        context,
                        item.title,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                color: Color(0x14795548),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item.icon,
                                size: 34,
                                color:
                                    const Color(0xFF795548),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}


class _PropertyAdminOverviewPage extends StatelessWidget {
  const _PropertyAdminOverviewPage();

  Widget _summaryCard(String label, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(radius: 24, child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Admin Overview',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('property_partners').snapshots(),
        builder: (context, partnerSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('property_listings').snapshots(),
            builder: (context, listingSnapshot) {
              if (partnerSnapshot.hasError || listingSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load Property Admin summary.\n'
                      '${partnerSnapshot.error ?? listingSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!partnerSnapshot.hasData || !listingSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final partners = partnerSnapshot.data!.docs;
              final listings = listingSnapshot.data!.docs;

              final int pendingPartners = partners.where((doc) {
                final data = doc.data();
                return (data['status']?.toString().toLowerCase() ?? 'pending') ==
                    'pending';
              }).length;

              final int approvedPartners = partners.where((doc) {
                final data = doc.data();
                return data['isApproved'] == true ||
                    (data['status']?.toString().toLowerCase() ?? '') ==
                        'approved';
              }).length;

              final int activeListings = listings.where((doc) {
                final data = doc.data();
                return (data['status']?.toString().toLowerCase() ?? 'active') ==
                    'active';
              }).length;

              final int closedListings = listings.where((doc) {
                final status =
                    doc.data()['status']?.toString().toLowerCase() ?? '';
                return status == 'sold' || status == 'rented';
              }).length;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final int columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 560
                          ? 2
                          : 1;

                  return GridView.count(
                    padding: const EdgeInsets.all(18),
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.0 : 1.8,
                    children: <Widget>[
                      _summaryCard(
                        'Total Partners',
                        partners.length,
                        Icons.badge_rounded,
                      ),
                      _summaryCard(
                        'Pending Partners',
                        pendingPartners,
                        Icons.pending_actions_rounded,
                      ),
                      _summaryCard(
                        'Approved Partners',
                        approvedPartners,
                        Icons.verified_rounded,
                      ),
                      _summaryCard(
                        'Total Listings',
                        listings.length,
                        Icons.home_work_rounded,
                      ),
                      _summaryCard(
                        'Active Listings',
                        activeListings,
                        Icons.visibility_rounded,
                      ),
                      _summaryCard(
                        'Sold / Rented',
                        closedListings,
                        Icons.task_alt_rounded,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PropertyPartnersAdminPage extends StatelessWidget {
  const _PropertyPartnersAdminPage();

  Future<void> _openMap(
    BuildContext context,
    double? latitude,
    double? longitude,
  ) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This partner has not saved an exact map location yet.',
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/@?api=1'
      '&map_action=map'
      '&center=$latitude,$longitude'
      '&zoom=18',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Partners',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_partners')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Property Partners.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No Property Partners found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();

              final String name = data['fullName']?.toString().trim() ?? '';
              final String partnerId =
                  data['partnerId']?.toString().trim() ?? '';
              final String type =
                  data['partnerType']?.toString().trim() ?? '';
              final String phone = data['phone']?.toString().trim() ?? '';
              final String office =
                  data['officeName']?.toString().trim() ?? '';
              final String address =
                  data['address']?.toString().trim() ?? '';
              final String status =
                  data['status']?.toString().trim().toLowerCase() ?? 'pending';
              final bool approved =
                  data['isApproved'] == true || status == 'approved';

              final rawLat = data['latitude'];
              final rawLng = data['longitude'];
              final double? latitude = rawLat is num
                  ? rawLat.toDouble()
                  : double.tryParse(rawLat?.toString() ?? '');
              final double? longitude = rawLng is num
                  ? rawLng.toDouble()
                  : double.tryParse(rawLng?.toString() ?? '');

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            child: Icon(
                              approved
                                  ? Icons.verified_rounded
                                  : Icons.pending_actions_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name.isEmpty ? 'Unnamed Partner' : name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  [
                                    if (partnerId.isNotEmpty) partnerId,
                                    if (type.isNotEmpty) type,
                                    approved ? 'Approved' : status,
                                  ].join(' • '),
                                  style: TextStyle(
                                    color: approved
                                        ? Colors.green.shade700
                                        : Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (phone.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text('Phone: $phone'),
                      ],
                      if (office.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('Office: $office'),
                      ],
                      if (address.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text('Address: $address'),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openMap(context, latitude, longitude),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('View Exact Location'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


class _PropertyListingsAdminPage extends StatefulWidget {
  const _PropertyListingsAdminPage();

  @override
  State<_PropertyListingsAdminPage> createState() =>
      _PropertyListingsAdminPageState();
}

class _PropertyListingsAdminPageState
    extends State<_PropertyListingsAdminPage> {
  String _filter = 'all';

  String _statusOf(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) {
      return 'deleted';
    }

    final String status =
        data['status']?.toString().trim().toLowerCase() ?? '';

    return status.isEmpty ? 'active' : status;
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_filter == 'all') {
      return true;
    }
    return _statusOf(data) == _filter;
  }

  String _titleOf(Map<String, dynamic> data) {
    final String title =
        data['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }

    final String propertyTitle =
        data['propertyTitle']?.toString().trim() ?? '';
    return propertyTitle.isEmpty
        ? 'Property Listing'
        : propertyTitle;
  }

  String _priceOf(Map<String, dynamic> data) {
    for (final String key in <String>[
      'price',
      'salePrice',
      'monthlyRent',
    ]) {
      final String value =
          data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _addressOf(Map<String, dynamic> data) {
    final String full =
        data['fullAddress']?.toString().trim() ?? '';
    if (full.isNotEmpty) {
      return full;
    }
    return data['address']?.toString().trim() ?? '';
  }

  double? _number(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic raw = data[key];
      if (raw is num) {
        return raw.toDouble();
      }
      final double? parsed =
          double.tryParse(raw?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  Future<void> _openMap(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final double? lat = _number(
      data,
      <String>[
        'propertyLat',
        'propertyLatitude',
        'latitude',
        'lat',
      ],
    );
    final double? lng = _number(
      data,
      <String>[
        'propertyLng',
        'propertyLongitude',
        'longitude',
        'lng',
      ],
    );

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exact property map location is not saved for this listing.',
          ),
        ),
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/@?api=1'
      '&map_action=map'
      '&center=$lat,$lng'
      '&zoom=18',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open property map.'),
        ),
      );
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
    String status,
  ) async {
    try {
      final Map<String, dynamic> update =
          <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'deleted') {
        update['isDeleted'] = true;
        update['deletedAt'] =
            FieldValue.serverTimestamp();
      } else {
        update['isDeleted'] = false;
        if (status == 'active') {
          update['deletedAt'] = FieldValue.delete();
        }
      }

      await reference.update(update);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Property status updated to ${status.toUpperCase()}.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                'Could not update property status.',
          ),
        ),
      );
    }
  }

  Widget _filterChip(
    String value,
    String label,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Property Listings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                _filterChip('all', 'All'),
                _filterChip('active', 'Active'),
                _filterChip('sold', 'Sold'),
                _filterChip('rented', 'Rented'),
                _filterChip('archived', 'Archived'),
                _filterChip('deleted', 'Deleted'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('property_listings')
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
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load Property Listings.\n'
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

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    documents = snapshot.data!.docs
                        .where(
                          (QueryDocumentSnapshot<
                                      Map<String, dynamic>>
                                  document) =>
                              _matchesFilter(
                            document.data(),
                          ),
                        )
                        .toList();

                if (documents.isEmpty) {
                  return Center(
                    child: Text(
                      _filter == 'all'
                          ? 'No Property Listings found.'
                          : 'No $_filter Property Listings.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 1000,
                    ),
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        8,
                        14,
                        24,
                      ),
                      itemCount: documents.length,
                      itemBuilder: (
                        BuildContext context,
                        int index,
                      ) {
                        final document =
                            documents[index];
                        final data = document.data();

                        final String title =
                            _titleOf(data);
                        final String category =
                            data['category']
                                    ?.toString()
                                    .trim() ??
                                'Property';
                        final String price =
                            _priceOf(data);
                        final String address =
                            _addressOf(data);
                        final String status =
                            _statusOf(data);
                        final String partnerId =
                            data['partnerId']
                                    ?.toString()
                                    .trim() ??
                                '';

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.all(
                              14,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .stretch,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: <Widget>[
                                    const CircleAvatar(
                                      child: Icon(
                                        Icons
                                            .home_work_rounded,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: <Widget>[
                                          Text(
                                            title,
                                            style:
                                                const TextStyle(
                                              fontSize:
                                                  17,
                                              fontWeight:
                                                  FontWeight
                                                      .w900,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 4,
                                          ),
                                          Text(
                                            category,
                                            style:
                                                const TextStyle(
                                              color: Colors
                                                  .black54,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                          ),
                                          if (price
                                              .isNotEmpty) ...<
                                              Widget>[
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              price,
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .w900,
                                              ),
                                            ),
                                          ],
                                          if (address
                                              .isNotEmpty) ...<
                                              Widget>[
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              address,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                          ],
                                          if (partnerId
                                              .isNotEmpty) ...<
                                              Widget>[
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              'Partner: $partnerId',
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    12,
                                                color: Colors
                                                    .black54,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        status
                                            .toUpperCase(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 12,
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton
                                        .icon(
                                      onPressed: () =>
                                          _openMap(
                                        context,
                                        data,
                                      ),
                                      icon: const Icon(
                                        Icons
                                            .map_rounded,
                                      ),
                                      label: const Text(
                                        'View Location',
                                      ),
                                    ),
                                    PopupMenuButton<
                                        String>(
                                      onSelected:
                                          (String value) =>
                                              _setStatus(
                                        context,
                                        document
                                            .reference,
                                        value,
                                      ),
                                      itemBuilder:
                                          (BuildContext
                                                  context) =>
                                              const <
                                                  PopupMenuEntry<
                                                      String>>[
                                        PopupMenuItem<
                                            String>(
                                          value:
                                              'active',
                                          child: Text(
                                              'Set Active'),
                                        ),
                                        PopupMenuItem<
                                            String>(
                                          value: 'sold',
                                          child: Text(
                                              'Mark Sold'),
                                        ),
                                        PopupMenuItem<
                                            String>(
                                          value:
                                              'rented',
                                          child: Text(
                                              'Mark Rented'),
                                        ),
                                        PopupMenuItem<
                                            String>(
                                          value:
                                              'archived',
                                          child: Text(
                                              'Archive'),
                                        ),
                                        PopupMenuItem<
                                            String>(
                                          value:
                                              'deleted',
                                          child: Text(
                                              'Move to Deleted'),
                                        ),
                                      ],
                                      child:
                                          OutlinedButton
                                              .icon(
                                        onPressed: null,
                                        icon: Icon(
                                          Icons
                                              .edit_note_rounded,
                                        ),
                                        label: Text(
                                          'Change Status',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _PropertyApprovalQueuePage extends StatelessWidget {
  const _PropertyApprovalQueuePage();

  Future<void> _updatePartnerStatus(
    BuildContext context,
    String documentId, {
    required bool approve,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('property_partners')
          .doc(documentId)
          .update(
        <String, dynamic>{
          'isApproved': approve,
          'status': approve ? 'approved' : 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Property Partner approved.'
                : 'Property Partner rejected.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not update Partner approval.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Approval Queue',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_partners')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load pending Property Partners.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('No pending Property Partner approvals.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final String name = data['fullName']?.toString().trim() ?? '';
              final String type =
                  data['partnerType']?.toString().trim() ?? '';
              final String email = data['email']?.toString().trim() ?? '';
              final String phone = data['phone']?.toString().trim() ?? '';
              final String address =
                  data['address']?.toString().trim() ?? '';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'Unnamed Partner' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (type.isNotEmpty) type,
                          if (email.isNotEmpty) email,
                          if (phone.isNotEmpty) phone,
                        ].join(' • '),
                      ),
                      if (address.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(address),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: () => _updatePartnerStatus(
                              context,
                              doc.id,
                              approve: true,
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Approve'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _updatePartnerStatus(
                              context,
                              doc.id,
                              approve: false,
                            ),
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



double? _propertyNumber(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }

  final String value = raw?.toString().trim() ?? '';
  if (value.isEmpty ||
      RegExp(r'[A-Za-z]').hasMatch(value)) {
    return null;
  }

  final String clean = value
      .replaceAll(',', '')
      .replaceAll('Rs.', '')
      .replaceAll('Rs', '')
      .replaceAll('रु', '')
      .trim();

  return double.tryParse(clean);
}

String _propertyMoney(double value) {
  final String fixed = value.toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String digits = parts.first;
  final StringBuffer buffer = StringBuffer();

  for (int i = 0; i < digits.length; i++) {
    final int remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return 'Rs. ${buffer.toString()}.${parts.last}';
}

double? _listingAmount(Map<String, dynamic> data) {
  for (final String key in <String>[
    'transactionAmount',
    'finalAmount',
    'price',
    'salePrice',
    'monthlyRent',
  ]) {
    final double? value = _propertyNumber(data[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String _listingTitle(Map<String, dynamic> data) {
  final String title =
      data['title']?.toString().trim() ?? '';
  if (title.isNotEmpty) {
    return title;
  }

  final String propertyTitle =
      data['propertyTitle']?.toString().trim() ?? '';

  return propertyTitle.isEmpty
      ? 'Property Listing'
      : propertyTitle;
}

String _listingStatus(Map<String, dynamic> data) {
  if (data['isDeleted'] == true) {
    return 'deleted';
  }

  final String status =
      data['status']?.toString().trim().toLowerCase() ?? '';

  return status.isEmpty ? 'active' : status;
}

class _PropertyClosedListingsPage extends StatelessWidget {
  const _PropertyClosedListingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sold / Rented',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_listings')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load closed listings.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final String status =
                _listingStatus(doc.data());
            return status == 'sold' ||
                status == 'rented';
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text('No sold or rented listings yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> data =
                  docs[index].data();
              final String status =
                  _listingStatus(data);
              final double? amount =
                  _listingAmount(data);

              return Card(
                child: ListTile(
                  leading: Icon(
                    status == 'sold'
                        ? Icons.sell_rounded
                        : Icons.key_rounded,
                  ),
                  title: Text(
                    _listingTitle(data),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    [
                      data['category']
                              ?.toString()
                              .trim() ??
                          'Property',
                      if (amount != null)
                        _propertyMoney(amount),
                      data['partnerId']
                              ?.toString()
                              .trim() ??
                          '',
                    ].where((e) => e.isNotEmpty).join(' • '),
                  ),
                  trailing: Chip(
                    label: Text(status.toUpperCase()),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

DateTime? _propertyDate(dynamic raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }
  if (raw is num) {
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
  }
  final String value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime? _firstPropertyDate(
  Map<String, dynamic> data,
  List<String> keys,
) {
  for (final String key in keys) {
    final DateTime? date = _propertyDate(data[key]);
    if (date != null) {
      return date;
    }
  }
  return null;
}



DateTime? _commissionPaymentDate(Map<String, dynamic> data) {
  return _firstPropertyDate(data, <String>[
    'approvedAt',
    'reviewedAt',
    'paidAt',
    'paymentDate',
    'createdAt',
    'updatedAt',
  ]);
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOfWeek(DateTime value) {
  final DateTime day = _startOfDay(value);
  return day.subtract(Duration(days: day.weekday - 1));
}

bool _dateInRange(
  DateTime? value,
  DateTime start,
  DateTime endExclusive,
) {
  if (value == null) {
    return false;
  }
  return !value.isBefore(start) && value.isBefore(endExclusive);
}

String _propertyDateLabel(DateTime? value) {
  if (value == null) {
    return 'Date not recorded';
  }
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _partnerDisplayName(
  String partnerId,
  Map<String, String> partnerNames,
) {
  final String name = partnerNames[partnerId]?.trim() ?? '';
  if (name.isEmpty) {
    return partnerId.isEmpty ? 'Unknown Partner' : partnerId;
  }
  return partnerId.isEmpty ? name : '$name • $partnerId';
}

class _PropertyEarningsPage extends StatefulWidget {
  const _PropertyEarningsPage();

  @override
  State<_PropertyEarningsPage> createState() =>
      _PropertyEarningsPageState();
}

class _PropertyEarningsPageState
    extends State<_PropertyEarningsPage> {
  String _historyPeriod = 'month';

  bool _matchesPeriod(DateTime? date, String period) {
    if (period == 'all') {
      return true;
    }
    if (date == null) {
      return false;
    }

    final DateTime now = DateTime.now();
    final DateTime today = _startOfDay(now);

    if (period == 'today') {
      return _dateInRange(
        date,
        today,
        today.add(const Duration(days: 1)),
      );
    }
    if (period == 'week') {
      final DateTime start = _startOfWeek(now);
      return _dateInRange(
        date,
        start,
        start.add(const Duration(days: 7)),
      );
    }
    if (period == 'month') {
      final DateTime start = DateTime(now.year, now.month);
      final DateTime end = now.month == 12
          ? DateTime(now.year + 1)
          : DateTime(now.year, now.month + 1);
      return _dateInRange(date, start, end);
    }
    if (period == 'year') {
      return _dateInRange(
        date,
        DateTime(now.year),
        DateTime(now.year + 1),
      );
    }
    return true;
  }

  double _approvedForPeriod(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
    String period,
  ) {
    double total = 0;
    for (final doc in payments) {
      final Map<String, dynamic> data = doc.data();
      final String status =
          data['status']?.toString().trim().toLowerCase() ?? 'pending';
      if (status != 'approved') {
        continue;
      }
      if (!_matchesPeriod(_commissionPaymentDate(data), period)) {
        continue;
      }
      total += _propertyNumber(data['amount']) ?? 0;
    }
    return total;
  }

  String _sourceType(
    Map<String, dynamic> payment,
    Map<String, Map<String, dynamic>> listings,
  ) {
    final String explicit = (payment['sourceType'] ??
            payment['propertyType'] ??
            payment['transactionType'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (explicit.contains('sale') || explicit == 'sold') {
      return 'sale';
    }
    if (explicit.contains('rent')) {
      return 'rent';
    }

    final String listingId =
        payment['listingId']?.toString().trim() ?? '';
    final Map<String, dynamic>? listing = listings[listingId];
    if (listing != null) {
      final String status = _listingStatus(listing);
      if (status == 'sold') return 'sale';
      if (status == 'rented') return 'rent';
      final String category =
          listing['category']?.toString().toLowerCase() ?? '';
      if (category.contains('rent') || category.contains('lease')) {
        return 'rent';
      }
      if (category.contains('sale')) {
        return 'sale';
      }
    }
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Earnings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('property_listings').snapshots(),
        builder: (context, listingSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('property_commission_payments').snapshots(),
            builder: (context, paymentSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db.collection('property_partners').snapshots(),
                builder: (context, partnerSnapshot) {
                  if (listingSnapshot.hasError ||
                      paymentSnapshot.hasError ||
                      partnerSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load earnings.\n'
                          '${listingSnapshot.error ?? paymentSnapshot.error ?? partnerSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!listingSnapshot.hasData ||
                      !paymentSnapshot.hasData ||
                      !partnerSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final listings = listingSnapshot.data!.docs;
                  final payments = paymentSnapshot.data!.docs;
                  final partners = partnerSnapshot.data!.docs;

                  final Map<String, Map<String, dynamic>> listingById =
                      <String, Map<String, dynamic>>{
                    for (final doc in listings) doc.id: doc.data(),
                  };

                  final Map<String, String> partnerNames = <String, String>{};
                  for (final doc in partners) {
                    final data = doc.data();
                    final String name =
                        data['fullName']?.toString().trim() ?? '';
                    final String partnerId =
                        data['partnerId']?.toString().trim() ?? '';
                    if (name.isNotEmpty) {
                      partnerNames[doc.id] = name;
                      if (partnerId.isNotEmpty) {
                        partnerNames[partnerId] = name;
                      }
                    }
                  }

                  final closed = listings.where((doc) {
                    final String status = _listingStatus(doc.data());
                    return status == 'sold' || status == 'rented';
                  }).toList();

                  double gross = 0;
                  double soldGross = 0;
                  double rentedGross = 0;
                  int valuedClosed = 0;
                  for (final doc in closed) {
                    final Map<String, dynamic> data = doc.data();
                    final double? amount = _listingAmount(data);
                    if (amount == null) continue;
                    gross += amount;
                    valuedClosed++;
                    if (_listingStatus(data) == 'sold') {
                      soldGross += amount;
                    } else {
                      rentedGross += amount;
                    }
                  }

                  double approvedCommission = 0;
                  double pendingCommission = 0;
                  double rejectedCommission = 0;
                  double saleCommission = 0;
                  double rentCommission = 0;
                  final Map<String, double> partnerTotals = <String, double>{};

                  for (final doc in payments) {
                    final data = doc.data();
                    final double amount =
                        _propertyNumber(data['amount']) ?? 0;
                    final String status =
                        data['status']?.toString().trim().toLowerCase() ??
                            'pending';
                    final String partnerId =
                        data['partnerId']?.toString().trim() ?? '';

                    if (status == 'approved') {
                      approvedCommission += amount;
                      partnerTotals.update(
                        partnerId,
                        (double old) => old + amount,
                        ifAbsent: () => amount,
                      );
                      final String type = _sourceType(data, listingById);
                      if (type == 'sale') {
                        saleCommission += amount;
                      } else if (type == 'rent') {
                        rentCommission += amount;
                      }
                    } else if (status == 'pending' || status == 'submitted') {
                      pendingCommission += amount;
                    } else if (status == 'rejected') {
                      rejectedCommission += amount;
                    }
                  }

                  final double today = _approvedForPeriod(payments, 'today');
                  final double week = _approvedForPeriod(payments, 'week');
                  final double month = _approvedForPeriod(payments, 'month');
                  final double year = _approvedForPeriod(payments, 'year');

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                      history = payments.where((doc) {
                    return _matchesPeriod(
                      _commissionPaymentDate(doc.data()),
                      _historyPeriod,
                    );
                  }).toList()
                    ..sort((a, b) {
                      final DateTime? ad = _commissionPaymentDate(a.data());
                      final DateTime? bd = _commissionPaymentDate(b.data());
                      if (ad == null && bd == null) return 0;
                      if (ad == null) return 1;
                      if (bd == null) return -1;
                      return bd.compareTo(ad);
                    });

                  final List<MapEntry<String, double>> rankedPartners =
                      partnerTotals.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: <Widget>[
                      const Text(
                        'NRD Commission Income',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MoneySummaryCard(
                        title: 'Today',
                        value: _propertyMoney(today),
                        icon: Icons.today_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'This Week',
                        value: _propertyMoney(week),
                        icon: Icons.date_range_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'This Month',
                        value: _propertyMoney(month),
                        icon: Icons.calendar_month_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'This Year',
                        value: _propertyMoney(year),
                        icon: Icons.calendar_today_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'All-Time Approved Commission',
                        value: _propertyMoney(approvedCommission),
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Commission Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _MoneySummaryCard(
                        title: 'Pending / Submitted',
                        value: _propertyMoney(pendingCommission),
                        icon: Icons.pending_actions_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Rejected',
                        value: _propertyMoney(rejectedCommission),
                        icon: Icons.cancel_outlined,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Income by Property Business',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _MoneySummaryCard(
                        title: 'Sale Commission Received',
                        value: _propertyMoney(saleCommission),
                        icon: Icons.sell_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Rent Commission Received',
                        value: _propertyMoney(rentCommission),
                        icon: Icons.key_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Recorded Sold Property Value',
                        value: _propertyMoney(soldGross),
                        icon: Icons.house_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Recorded Rented Property Value',
                        value: _propertyMoney(rentedGross),
                        icon: Icons.apartment_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Total Recorded Property Value',
                        value: _propertyMoney(gross),
                        icon: Icons.account_balance_rounded,
                      ),
                      _MoneySummaryCard(
                        title: 'Closed Properties / Numeric Amount',
                        value: '${closed.length} / $valuedClosed',
                        icon: Icons.task_alt_rounded,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Partner-wise NRD Income',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (rankedPartners.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No approved commission payments yet.',
                            ),
                          ),
                        )
                      else
                        for (final entry in rankedPartners)
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.badge_rounded),
                              ),
                              title: Text(
                                _partnerDisplayName(
                                  entry.key,
                                  partnerNames,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              trailing: Text(
                                _propertyMoney(entry.value),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Detailed Commission History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const _PropertyCommissionPaymentsPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('Payments'),
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: 8,
                          children: <Widget>[
                            for (final item in <MapEntry<String, String>>[
                              const MapEntry('today', 'Today'),
                              const MapEntry('week', 'Week'),
                              const MapEntry('month', 'Month'),
                              const MapEntry('year', 'Year'),
                              const MapEntry('all', 'All'),
                            ])
                              ChoiceChip(
                                label: Text(item.value),
                                selected: _historyPeriod == item.key,
                                onSelected: (_) {
                                  setState(() => _historyPeriod = item.key);
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (history.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No commission transactions in this period.',
                            ),
                          ),
                        )
                      else
                        for (final doc in history)
                          _commissionHistoryCard(
                            doc,
                            listingById,
                            partnerNames,
                          ),
                      const SizedBox(height: 8),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            'Daily, weekly, monthly and yearly earnings use APPROVED commission payments. Old payments without a recorded date remain visible in All history only. Property values are totaled only when a numeric amount is stored in Firestore.',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _commissionHistoryCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, Map<String, dynamic>> listings,
    Map<String, String> partnerNames,
  ) {
    final Map<String, dynamic> data = doc.data();
    final double amount = _propertyNumber(data['amount']) ?? 0;
    final String status =
        data['status']?.toString().trim().toLowerCase() ?? 'pending';
    final String partnerId = data['partnerId']?.toString().trim() ?? '';
    final String listingId = data['listingId']?.toString().trim() ?? '';
    final Map<String, dynamic>? listing = listings[listingId];
    final String title = listing == null
        ? (data['propertyTitle']?.toString().trim().isNotEmpty == true
            ? data['propertyTitle'].toString().trim()
            : 'Property Commission')
        : _listingTitle(listing);
    final String source = _sourceType(data, listings);
    final String note = data['note']?.toString().trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  child: Icon(
                    source == 'sale'
                        ? Icons.sell_rounded
                        : source == 'rent'
                            ? Icons.key_rounded
                            : Icons.payments_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _partnerDisplayName(partnerId, partnerNames),
                      ),
                    ],
                  ),
                ),
                Text(
                  _propertyMoney(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Chip(label: Text(status.toUpperCase())),
                Chip(label: Text(source.toUpperCase())),
                Text(_propertyDateLabel(_commissionPaymentDate(data))),
              ],
            ),
            if (listingId.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Listing ID: $listingId'),
            ],
            if (note.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('Note: $note'),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoneySummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MoneySummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
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
}

class _PropertyCommissionPage extends StatelessWidget {
  const _PropertyCommissionPage();

  Future<Map<String, double>> _commissionRates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('property_admin_settings')
        .doc('main')
        .get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final double defaultRate =
        _propertyNumber(data['commissionPercent']) ?? 0;
    final double saleRate =
        _propertyNumber(data['saleCommissionPercent']) ?? defaultRate;
    final double rentRate =
        _propertyNumber(data['rentCommissionPercent']) ?? defaultRate;
    return <String, double>{
      'default': defaultRate,
      'sale': saleRate,
      'rent': rentRate,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NRD Property Commission',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Commission settings',
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const _PropertySettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _commissionRates(),
        builder: (context, rateSnapshot) {
          if (!rateSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, double> rates = rateSnapshot.data!;
          final double defaultRate = rates['default'] ?? 0;
          final double saleRate = rates['sale'] ?? defaultRate;
          final double rentRate = rates['rent'] ?? defaultRate;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('property_listings')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load commission data.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              double saleDue = 0;
              double rentDue = 0;
              int eligible = 0;
              final List<_CommissionListingRow> rows = <_CommissionListingRow>[];

              for (final doc in snapshot.data!.docs) {
                final Map<String, dynamic> data = doc.data();
                final String status = _listingStatus(data);
                if (status != 'sold' && status != 'rented') {
                  continue;
                }

                final double? amount = _listingAmount(data);
                final double? explicit = _propertyNumber(
                  data['commissionAmount'] ?? data['nrdCommission'],
                );
                final double rate = status == 'sold' ? saleRate : rentRate;
                double? calculated;
                if (explicit != null) {
                  calculated = explicit;
                } else if (amount != null && rate > 0) {
                  calculated = amount * rate / 100;
                }

                if (calculated == null) {
                  continue;
                }

                eligible++;
                if (status == 'sold') {
                  saleDue += calculated;
                } else {
                  rentDue += calculated;
                }

                rows.add(
                  _CommissionListingRow(
                    title: _listingTitle(data),
                    partnerId: data['partnerId']?.toString().trim() ?? '',
                    status: status,
                    amount: amount,
                    rate: explicit == null ? rate : null,
                    commission: calculated,
                    isOverride: explicit != null,
                  ),
                );
              }

              final double totalDue = saleDue + rentDue;

              return ListView(
                padding: const EdgeInsets.all(18),
                children: <Widget>[
                  _MoneySummaryCard(
                    title: 'Default Commission Rate',
                    value: '${defaultRate.toStringAsFixed(2)}%',
                    icon: Icons.percent_rounded,
                  ),
                  _MoneySummaryCard(
                    title: 'Sale Commission Rate',
                    value: '${saleRate.toStringAsFixed(2)}%',
                    icon: Icons.sell_rounded,
                  ),
                  _MoneySummaryCard(
                    title: 'Rent Commission Rate',
                    value: '${rentRate.toStringAsFixed(2)}%',
                    icon: Icons.key_rounded,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const _PropertySettingsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Set / Change Commission Rates'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MoneySummaryCard(
                    title: 'Sale Commission Due',
                    value: _propertyMoney(saleDue),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  _MoneySummaryCard(
                    title: 'Rent Commission Due',
                    value: _propertyMoney(rentDue),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _MoneySummaryCard(
                    title: 'Total Calculated Commission Due',
                    value: _propertyMoney(totalDue),
                    icon: Icons.calculate_rounded,
                  ),
                  _MoneySummaryCard(
                    title: 'Listings Included in Calculation',
                    value: '$eligible',
                    icon: Icons.home_work_rounded,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Commission Calculation Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No sold/rented listing with a calculable commission yet.',
                        ),
                      ),
                    )
                  else
                    for (final row in rows)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            row.status == 'sold'
                                ? Icons.sell_rounded
                                : Icons.key_rounded,
                          ),
                          title: Text(
                            row.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            [
                              row.status.toUpperCase(),
                              if (row.partnerId.isNotEmpty)
                                'Partner: ${row.partnerId}',
                              if (row.amount != null)
                                'Value: ${_propertyMoney(row.amount!)}',
                              row.isOverride
                                  ? 'Listing-specific commission override'
                                  : 'Rate: ${row.rate!.toStringAsFixed(2)}%',
                            ].join('\n'),
                          ),
                          trailing: Text(
                            _propertyMoney(row.commission),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Sale and Rent can have separate commission rates. A listing-specific commissionAmount / nrdCommission still overrides the percentage calculation for that listing.',
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CommissionListingRow {
  final String title;
  final String partnerId;
  final String status;
  final double? amount;
  final double? rate;
  final double commission;
  final bool isOverride;

  const _CommissionListingRow({
    required this.title,
    required this.partnerId,
    required this.status,
    required this.amount,
    required this.rate,
    required this.commission,
    required this.isOverride,
  });
}

class _PropertyCommissionPaymentsPage
    extends StatefulWidget {
  const _PropertyCommissionPaymentsPage();

  @override
  State<_PropertyCommissionPaymentsPage> createState() =>
      _PropertyCommissionPaymentsPageState();
}

class _PropertyCommissionPaymentsPageState
    extends State<_PropertyCommissionPaymentsPage> {
  String _filter = 'all';

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await ref.update(
      <String, dynamic>{
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _addManualPayment() async {
    final TextEditingController partner =
        TextEditingController();
    final TextEditingController amount =
        TextEditingController();
    final TextEditingController note =
        TextEditingController();

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Commission Payment'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: partner,
                decoration: const InputDecoration(
                  labelText: 'Partner UID / ID',
                ),
              ),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                ),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(
                  labelText: 'Note',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) {
      partner.dispose();
      amount.dispose();
      note.dispose();
      return;
    }

    final double? value =
        double.tryParse(amount.text.trim());

    if (partner.text.trim().isEmpty ||
        value == null ||
        value <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enter a valid Partner ID and amount.',
            ),
          ),
        );
      }
      partner.dispose();
      amount.dispose();
      note.dispose();
      return;
    }

    await FirebaseFirestore.instance
        .collection('property_commission_payments')
        .add(
      <String, dynamic>{
        'partnerId': partner.text.trim(),
        'amount': value,
        'note': note.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    partner.dispose();
    amount.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Commission Payments',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add payment',
            onPressed: _addManualPayment,
            icon: const Icon(Icons.add_card_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                for (final item in <String>[
                  'all',
                  'pending',
                  'approved',
                  'rejected',
                ])
                  ChoiceChip(
                    label: Text(item.toUpperCase()),
                    selected: _filter == item,
                    onSelected: (_) {
                      setState(() => _filter = item);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(
                      'property_commission_payments')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load commission payments.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs =
                    snapshot.data!.docs.where((doc) {
                  if (_filter == 'all') {
                    return true;
                  }
                  return (doc.data()['status']
                                  ?.toString()
                                  .toLowerCase() ??
                              'pending') ==
                          _filter;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                        'No commission payments found.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final String status =
                        data['status']
                                ?.toString()
                                .toLowerCase() ??
                            'pending';
                    final double amount =
                        _propertyNumber(
                                data['amount']) ??
                            0;

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                            Icons.payments_rounded),
                        title: Text(
                          _propertyMoney(amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          '${data['partnerId'] ?? 'Unknown Partner'}'
                          ' • ${status.toUpperCase()}'
                          '${(data['note'] ?? '').toString().trim().isEmpty ? '' : '\n${data['note']}'}',
                        ),
                        trailing:
                            PopupMenuButton<String>(
                          onSelected: (value) =>
                              _setStatus(
                            doc.reference,
                            value,
                          ),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'approved',
                              child: Text('Approve'),
                            ),
                            PopupMenuItem(
                              value: 'rejected',
                              child: Text('Reject'),
                            ),
                            PopupMenuItem(
                              value: 'pending',
                              child: Text(
                                  'Move to Pending'),
                            ),
                          ],
                        ),
                      ),
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

class _PropertyReportsPage extends StatefulWidget {
  const _PropertyReportsPage();

  @override
  State<_PropertyReportsPage> createState() =>
      _PropertyReportsPageState();
}

class _PropertyReportsPageState
    extends State<_PropertyReportsPage> {
  Future<void> _update(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await ref.update(
      <String, dynamic>{
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports & Complaints',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_reports')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load reports.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No Property reports or complaints.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final String status =
                  data['status']
                          ?.toString()
                          .toLowerCase() ??
                      'open';

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.report_problem_rounded,
                  ),
                  title: Text(
                    data['title']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                        ? data['title'].toString()
                        : 'Property Report',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    '${data['message'] ?? data['description'] ?? ''}\n'
                    'Status: ${status.toUpperCase()}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _update(doc.reference, value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'in_review',
                        child: Text('In Review'),
                      ),
                      PopupMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PropertyDeletedArchivedPage
    extends StatelessWidget {
  const _PropertyDeletedArchivedPage();

  Future<void> _restore(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.update(
      <String, dynamic>{
        'status': 'active',
        'isDeleted': false,
        'deletedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _deleteForever(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: Text(
          'Permanently delete "$title"? This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Deleted / Archived',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_listings')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load archived records.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final status =
                _listingStatus(doc.data());
            return status == 'archived' ||
                status == 'deleted';
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                  'No deleted or archived properties.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = _listingTitle(data);
              final status = _listingStatus(data);

              return Card(
                child: ListTile(
                  leading: Icon(
                    status == 'deleted'
                        ? Icons.delete_rounded
                        : Icons.archive_rounded,
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle:
                      Text(status.toUpperCase()),
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Restore',
                        onPressed: () =>
                            _restore(doc.reference),
                        icon: const Icon(
                            Icons.restore_rounded),
                      ),
                      IconButton(
                        tooltip: 'Delete forever',
                        onPressed: () =>
                            _deleteForever(
                          context,
                          doc.reference,
                          title,
                        ),
                        icon: const Icon(
                            Icons.delete_forever_rounded),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PropertyVerificationPage
    extends StatelessWidget {
  const _PropertyVerificationPage();

  Future<void> _setVerification(
    DocumentReference<Map<String, dynamic>> ref,
    String value,
  ) async {
    await ref.update(
      <String, dynamic>{
        'verificationStatus': value,
        'verificationReviewedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification Documents',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('property_partners')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load Partner verification data.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('No Property Partners found.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final String status =
                  data['verificationStatus']
                          ?.toString()
                          .toLowerCase() ??
                      'pending';

              final List<String> evidence = <String>[
                if ((data['registrationNumber'] ??
                        '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  'Registration',
                if ((data['panVatNumber'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  'PAN/VAT',
                if ((data['photoUrl'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  'Profile Photo',
                if ((data['officePhotoUrl'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  'Office Photo',
              ];

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.verified_user_rounded,
                  ),
                  title: Text(
                    data['fullName']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true
                        ? data['fullName'].toString()
                        : 'Property Partner',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    'Partner ID: ${data['partnerId'] ?? '-'}\n'
                    'Evidence: ${evidence.isEmpty ? 'Not uploaded' : evidence.join(', ')}\n'
                    'Verification: ${status.toUpperCase()}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _setVerification(
                      doc.reference,
                      value,
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'verified',
                        child: Text('Verified'),
                      ),
                      PopupMenuItem(
                        value: 'needs_review',
                        child: Text('Needs Review'),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PropertySettingsPage extends StatefulWidget {
  const _PropertySettingsPage();

  @override
  State<_PropertySettingsPage> createState() =>
      _PropertySettingsPageState();
}

class _PropertySettingsPageState
    extends State<_PropertySettingsPage> {
  final TextEditingController _commission = TextEditingController();
  final TextEditingController _saleCommission = TextEditingController();
  final TextEditingController _rentCommission = TextEditingController();
  final TextEditingController _expiryDays = TextEditingController();
  final TextEditingController _maxPhotos = TextEditingController();
  final TextEditingController _supportPhone = TextEditingController();

  bool _approvalRequired = true;
  bool _loading = true;
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _reference =>
      FirebaseFirestore.instance
          .collection('property_admin_settings')
          .doc('main');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await _reference.get();
      final data = doc.data() ?? <String, dynamic>{};
      final double defaultCommission =
          _propertyNumber(data['commissionPercent']) ?? 0;

      _commission.text = defaultCommission.toString();
      _saleCommission.text =
          (_propertyNumber(data['saleCommissionPercent']) ??
                  defaultCommission)
              .toString();
      _rentCommission.text =
          (_propertyNumber(data['rentCommissionPercent']) ??
                  defaultCommission)
              .toString();
      _expiryDays.text =
          (data['listingExpiryDays'] ?? 90).toString();
      _maxPhotos.text = (data['maxPhotos'] ?? 20).toString();
      _supportPhone.text = data['supportPhone']?.toString() ?? '';
      _approvalRequired = data['approvalRequired'] != false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final double? commission =
        double.tryParse(_commission.text.trim());
    final double? saleCommission =
        double.tryParse(_saleCommission.text.trim());
    final double? rentCommission =
        double.tryParse(_rentCommission.text.trim());
    final int? expiry = int.tryParse(_expiryDays.text.trim());
    final int? photos = int.tryParse(_maxPhotos.text.trim());

    bool validRate(double? value) =>
        value != null && value >= 0 && value <= 100;

    if (!validRate(commission) ||
        !validRate(saleCommission) ||
        !validRate(rentCommission) ||
        expiry == null ||
        expiry <= 0 ||
        photos == null ||
        photos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Check Default/Sale/Rent commission rates, expiry days and max photos values.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _reference.set(
        <String, dynamic>{
          'commissionPercent': commission,
          'saleCommissionPercent': saleCommission,
          'rentCommissionPercent': rentCommission,
          'listingExpiryDays': expiry,
          'maxPhotos': photos,
          'supportPhone': _supportPhone.text.trim(),
          'approvalRequired': _approvalRequired,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property settings saved.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _commission.dispose();
    _saleCommission.dispose();
    _rentCommission.dispose();
    _expiryDays.dispose();
    _maxPhotos.dispose();
    _supportPhone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              const Text(
                'NRD Commission Settings',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Default is the fallback rate. Sale and Rent rates are used for their respective closed property transactions.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _commission,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Default NRD Commission (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _saleCommission,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Property Sale Commission (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _rentCommission,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Property Rent Commission (%)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 14),
              TextField(
                controller: _expiryDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Listing Expiry Days',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _maxPhotos,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Property Photos',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _supportPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Property Support Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Require Admin Approval Before Publishing',
                ),
                value: _approvalRequired,
                onChanged: (value) {
                  setState(() => _approvalRequired = value);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Property Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPropertyModule {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminPropertyModule({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
