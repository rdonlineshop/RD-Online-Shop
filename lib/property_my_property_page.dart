import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'property_marketplace_page.dart';

class PropertyMyPropertyPage extends StatefulWidget {
  const PropertyMyPropertyPage({super.key});

  @override
  State<PropertyMyPropertyPage> createState() =>
      _PropertyMyPropertyPageState();
}

class _PropertyMyPropertyPageState
    extends State<PropertyMyPropertyPage> {
  String _filter = 'active';

  User? get _user => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _myListingsStream() {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('property_listings')
        .where('partnerId', isEqualTo: user.uid)
        .snapshots();
  }

  String _statusOf(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) {
      return 'deleted';
    }

    final String status =
        data['status']?.toString().trim().toLowerCase() ?? '';

    if (status.isEmpty) {
      return 'active';
    }

    return status;
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final String status = _statusOf(data);

    switch (_filter) {
      case 'sold':
        return status == 'sold';
      case 'rented':
        return status == 'rented';
      case 'archived':
        return status == 'archived';
      case 'deleted':
        return status == 'deleted';
      case 'active':
      default:
        return status != 'sold' &&
            status != 'rented' &&
            status != 'archived' &&
            status != 'deleted';
    }
  }

  Future<bool> _ownsListing(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await reference.get();

    final Map<String, dynamic>? data = snapshot.data();

    return snapshot.exists &&
        data != null &&
        data['partnerId']?.toString() == user.uid;
  }

  Future<void> _setListingStatus(
    DocumentReference<Map<String, dynamic>> reference,
    String status,
  ) async {
    if (!await _ownsListing(reference)) {
      _showMessage(
        'You can only update property listings that belong to your own Partner ID.',
      );
      return;
    }

    await reference.update(
      <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    _showMessage(
      'Property status updated to ${status.toUpperCase()}.',
    );
  }

  Future<void> _softDelete(
    DocumentReference<Map<String, dynamic>> reference,
    String title,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Property'),
          content: Text(
            'Delete "$title" from My Property?\n\n'
            'It will be removed from the active marketplace, but the record '
            'will remain archived for earnings, commission and audit history.',
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
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    if (!await _ownsListing(reference)) {
      _showMessage(
        'You can only delete property listings that belong to your own Partner ID.',
      );
      return;
    }

    await reference.update(
      <String, dynamic>{
        'isDeleted': true,
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    _showMessage(
      'Property moved to Deleted / Archived.',
    );
  }

  Future<void> _restore(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    if (!await _ownsListing(reference)) {
      _showMessage(
        'You can only restore property listings that belong to your own Partner ID.',
      );
      return;
    }

    await reference.update(
      <String, dynamic>{
        'isDeleted': false,
        'status': 'active',
        'deletedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    _showMessage('Property restored.');
  }

  void _openAddProperty() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PropertyMarketplacePage(),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.home_work_outlined,
              size: 72,
              color: Color(0xFF795548),
            ),
            const SizedBox(height: 14),
            Text(
              _filter == 'active'
                  ? 'No active property listings yet.'
                  : 'No $_filter property listings.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openAddProperty,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Property'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String title =
        data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString().trim()
            : data['propertyTitle']?.toString().trim().isNotEmpty == true
                ? data['propertyTitle'].toString().trim()
                : 'Property Listing';

    final String category =
        data['category']?.toString().trim().isNotEmpty == true
            ? data['category'].toString().trim()
            : 'Property';

    final String status = _statusOf(data);
    final String price =
        data['price']?.toString().trim().isNotEmpty == true
            ? data['price'].toString().trim()
            : data['salePrice']?.toString().trim().isNotEmpty == true
                ? data['salePrice'].toString().trim()
                : data['monthlyRent']?.toString().trim().isNotEmpty == true
                    ? data['monthlyRent'].toString().trim()
                    : '';

    final String address =
        data['fullAddress']?.toString().trim().isNotEmpty == true
            ? data['fullAddress'].toString().trim()
            : data['address']?.toString().trim() ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: Color(0x14795548),
                  child: Icon(
                    Icons.home_work_rounded,
                    color: Color(0xFF795548),
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      if (price.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (address.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(
                      'Property detail view will be connected with the final listing detail page.',
                    );
                  },
                  icon: const Icon(
                    Icons.visibility_rounded,
                  ),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(
                      'Edit will open the same Property form with this listing pre-filled in the next step.',
                    );
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                if (status != 'sold' &&
                    status != 'rented' &&
                    status != 'deleted')
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'sold' ||
                          value == 'rented' ||
                          value == 'archived') {
                        _setListingStatus(
                          document.reference,
                          value,
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'sold',
                        child: Text('Mark as Sold'),
                      ),
                      PopupMenuItem<String>(
                        value: 'rented',
                        child: Text('Mark as Rented'),
                      ),
                      PopupMenuItem<String>(
                        value: 'archived',
                        child: Text('Archive'),
                      ),
                    ],
                    child: const OutlinedButton(
                      onPressed: null,
                      child: Text('Status'),
                    ),
                  ),
                if (status == 'deleted')
                  OutlinedButton.icon(
                    onPressed: () => _restore(
                      document.reference,
                    ),
                    icon: const Icon(
                      Icons.restore_rounded,
                    ),
                    label: const Text('Restore'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _softDelete(
                      document.reference,
                      title,
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot<Map<String, dynamic>>>? stream =
        _myListingsStream();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'My Property',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Add Property',
            onPressed: _openAddProperty,
            icon: const Icon(
              Icons.add_business_rounded,
            ),
          ),
        ],
      ),
      body: stream == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Property Partner login is required.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: Column(
                  children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          _filterChip(
                            'active',
                            'Active',
                          ),
                          _filterChip(
                            'sold',
                            'Sold',
                          ),
                          _filterChip(
                            'rented',
                            'Rented',
                          ),
                          _filterChip(
                            'archived',
                            'Archived',
                          ),
                          _filterChip(
                            'deleted',
                            'Deleted',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: stream,
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
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(24),
                                child: Text(
                                  'Could not load My Property.\n'
                                  '${snapshot.error}\n\n'
                                  'The Property Firestore rules / publish backend still needs to be connected.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }

                          final List<
                                  QueryDocumentSnapshot<
                                      Map<String, dynamic>>>
                              documents =
                              (snapshot.data?.docs ??
                                      <QueryDocumentSnapshot<
                                          Map<String, dynamic>>>[])
                                  .where(
                            (
                              QueryDocumentSnapshot<
                                      Map<String, dynamic>>
                                  document,
                            ) =>
                                _matchesFilter(
                              document.data(),
                            ),
                          ).toList();

                          if (documents.isEmpty) {
                            return _emptyState();
                          }

                          return ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              24,
                            ),
                            itemCount:
                                documents.length,
                            itemBuilder: (
                              BuildContext context,
                              int index,
                            ) =>
                                _listingCard(
                              documents[index],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProperty,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Property'),
      ),
    );
  }
}
