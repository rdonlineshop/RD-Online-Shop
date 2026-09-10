import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminHotelPartnerManagementPage extends StatefulWidget {
  const AdminHotelPartnerManagementPage({super.key});

  @override
  State<AdminHotelPartnerManagementPage> createState() =>
      _AdminHotelPartnerManagementPageState();
}

class _AdminHotelPartnerManagementPageState
    extends State<AdminHotelPartnerManagementPage> {
  final TextEditingController _searchController =
      TextEditingController();

  String _filter = 'all';

  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdRed = Color(0xFFD32F2F);
  static const Color _rdOrange = Color(0xFFF57C00);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String query =
        _searchController.text.trim().toLowerCase();

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> result =
        docs.where(
      (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final Map<String, dynamic> data = doc.data();

        final String businessName =
            data['businessName']?.toString().toLowerCase() ?? '';
        final String ownerName =
            data['ownerName']?.toString().toLowerCase() ?? '';
        final String phone =
            data['phone']?.toString().toLowerCase() ?? '';
        final String email =
            data['email']?.toString().toLowerCase() ?? '';
        final String address =
            data['address']?.toString().toLowerCase() ?? '';
        final String status =
            data['status']?.toString().toLowerCase() ?? 'pending';

        final bool approved = data['isApproved'] == true;
        final bool active = data['isActive'] == true;

        final bool matchesSearch = query.isEmpty ||
            businessName.contains(query) ||
            ownerName.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            address.contains(query);

        bool matchesFilter = true;

        switch (_filter) {
          case 'pending':
            matchesFilter = !approved && status == 'pending';
            break;
          case 'approved':
            matchesFilter = approved && active;
            break;
          case 'inactive':
            matchesFilter = approved && !active;
            break;
          case 'rejected':
            matchesFilter = status == 'rejected';
            break;
          case 'all':
            matchesFilter = true;
            break;
        }

        return matchesSearch && matchesFilter;
      },
    ).toList();

    result.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> first,
        QueryDocumentSnapshot<Map<String, dynamic>> second,
      ) {
        final Timestamp? firstCreated =
            first.data()['createdAt'] as Timestamp?;
        final Timestamp? secondCreated =
            second.data()['createdAt'] as Timestamp?;

        if (firstCreated == null && secondCreated == null) {
          return 0;
        }
        if (firstCreated == null) {
          return 1;
        }
        if (secondCreated == null) {
          return -1;
        }

        return secondCreated.compareTo(firstCreated);
      },
    );

    return result;
  }

  Future<void> _approve(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Approve Hotel Partner'),
          content: Text(
            'Approve ${_partnerName(doc.data())}?\n\n'
            'After approval this partner can use the Hotel Partner system.',
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
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _safeUpdate(
      doc.reference,
      <String, dynamic>{
        'isApproved': true,
        'isActive': true,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Hotel Partner approved.',
    );
  }

  Future<void> _setActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool active,
  ) async {
    await _safeUpdate(
      doc.reference,
      <String, dynamic>{
        'isActive': active,
        'status': active ? 'approved' : 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMessage: active
          ? 'Hotel Partner activated.'
          : 'Hotel Partner deactivated.',
    );
  }

  Future<void> _reject(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final TextEditingController reasonController =
        TextEditingController();

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Hotel Partner'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter rejection reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value =
                    reasonController.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    await _safeUpdate(
      doc.reference,
      <String, dynamic>{
        'isApproved': false,
        'isActive': false,
        'status': 'rejected',
        'rejectionReason': reason.trim(),
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      successMessage: 'Hotel Partner rejected.',
    );
  }

  Future<void> _safeUpdate(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data, {
    required String successMessage,
  }) async {
    try {
      await reference.update(data);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not update Hotel Partner.\n$error',
            ),
          ),
        );
    }
  }

  String _partnerName(Map<String, dynamic> data) {
    final String businessName =
        data['businessName']?.toString().trim() ?? '';
    final String ownerName =
        data['ownerName']?.toString().trim() ?? '';

    if (businessName.isNotEmpty) {
      return businessName;
    }
    if (ownerName.isNotEmpty) {
      return ownerName;
    }
    return 'Hotel Partner';
  }

  Color _statusColor(Map<String, dynamic> data) {
    final String status =
        data['status']?.toString().toLowerCase() ?? 'pending';

    if (status == 'rejected') {
      return _rdRed;
    }
    if (data['isApproved'] == true &&
        data['isActive'] == true) {
      return _rdGreen;
    }
    if (data['isApproved'] == true &&
        data['isActive'] != true) {
      return Colors.grey.shade700;
    }

    return _rdOrange;
  }

  String _statusText(Map<String, dynamic> data) {
    final String status =
        data['status']?.toString().toLowerCase() ?? 'pending';

    if (status == 'rejected') {
      return 'REJECTED';
    }
    if (data['isApproved'] == true &&
        data['isActive'] == true) {
      return 'APPROVED • ACTIVE';
    }
    if (data['isApproved'] == true &&
        data['isActive'] != true) {
      return 'APPROVED • INACTIVE';
    }

    return 'PENDING APPROVAL';
  }

  void _showDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_partnerName(data)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  _detailRow(
                    'Owner',
                    data['ownerName']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Phone',
                    data['phone']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Email',
                    data['email']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Address',
                    data['address']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Registration No.',
                    data['registrationNumber']
                            ?.toString() ??
                        '',
                  ),
                  _detailRow(
                    'PAN/VAT',
                    data['panVatNumber']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Status',
                    _statusText(data),
                  ),
                  if ((data['rejectionReason']
                              ?.toString()
                              .trim() ??
                          '')
                      .isNotEmpty)
                    _detailRow(
                      'Rejection Reason',
                      data['rejectionReason'].toString(),
                    ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Partner ID: ${doc.id}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 125,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Hotel Partner Management',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hotel_partners')
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    QuerySnapshot<Map<String, dynamic>>>
                snapshot,
          ) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load Hotel Partners.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                allDocs =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                docs = _filteredDocs(allDocs);

            final int pendingCount =
                allDocs.where((doc) {
              final Map<String, dynamic> data =
                  doc.data();
              return data['isApproved'] != true &&
                  (data['status']
                              ?.toString()
                              .toLowerCase() ??
                          'pending') ==
                      'pending';
            }).length;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _headerCard(
                      total: allDocs.length,
                      pending: pendingCount,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText:
                            'Search Hotel Partner',
                        hintText:
                            'Business, owner, phone, email, address',
                        prefixIcon:
                            Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<String>(
                        segments:
                            const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: 'all',
                            label: Text('All'),
                          ),
                          ButtonSegment<String>(
                            value: 'pending',
                            label: Text('Pending'),
                          ),
                          ButtonSegment<String>(
                            value: 'approved',
                            label: Text('Active'),
                          ),
                          ButtonSegment<String>(
                            value: 'inactive',
                            label: Text('Inactive'),
                          ),
                          ButtonSegment<String>(
                            value: 'rejected',
                            label: Text('Rejected'),
                          ),
                        ],
                        selected: <String>{_filter},
                        onSelectionChanged:
                            (Set<String> value) {
                          setState(() {
                            _filter = value.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hotel Partners (${docs.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No Hotel Partner found.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(_partnerCard),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard({
    required int total,
    required int pending,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF1565C0),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.hotel_class_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'RD Hotel Partners',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$total total • $pending pending approval',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();

    final bool approved = data['isApproved'] == true;
    final bool active = data['isActive'] == true;
    final String status =
        data['status']?.toString().toLowerCase() ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor:
                      _statusColor(data)
                          .withValues(alpha: 0.12),
                  child: Icon(
                    Icons.hotel_rounded,
                    color: _statusColor(data),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _partnerName(data),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        data['ownerName']
                                ?.toString() ??
                            '',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if ((data['phone']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        Text(
                          data['phone'].toString(),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(data)
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText(data),
                    style: TextStyle(
                      color: _statusColor(data),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () =>
                      _showDetails(doc),
                  icon: const Icon(
                    Icons.visibility_rounded,
                  ),
                  label: const Text('Details'),
                ),
                if (!approved &&
                    status != 'rejected')
                  FilledButton.icon(
                    onPressed: () => _approve(doc),
                    icon: const Icon(
                      Icons.verified_rounded,
                    ),
                    label: const Text('Approve'),
                  ),
                if (!approved &&
                    status != 'rejected')
                  OutlinedButton.icon(
                    onPressed: () => _reject(doc),
                    icon: const Icon(
                      Icons.cancel_rounded,
                    ),
                    label: const Text('Reject'),
                  ),
                if (approved)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _setActive(doc, !active),
                    icon: Icon(
                      active
                          ? Icons.pause_circle_rounded
                          : Icons.play_circle_rounded,
                    ),
                    label: Text(
                      active
                          ? 'Deactivate'
                          : 'Activate',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
