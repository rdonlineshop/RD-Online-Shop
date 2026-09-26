import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminKrishiSellerPage extends StatelessWidget {
  const AdminKrishiSellerPage({super.key});

  CollectionReference<Map<String, dynamic>> get _sellers =>
      FirebaseFirestore.instance.collection('sellers');

  String _firstText(
    Map<String, dynamic> seller,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final String value =
          seller[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  bool _declarationAccepted(
    Map<String, dynamic> seller,
  ) {
    return seller['legalDeclarationAccepted'] == true ||
        seller['legalDeclaration'] == true;
  }

  List<String> _missingLegalRequirements(
    Map<String, dynamic> seller,
  ) {
    final List<String> missing = <String>[];

    final String registrationNumber = _firstText(
      seller,
      <String>[
        'businessRegistrationNumber',
        'registrationNumber',
        'farmRegistrationNumber',
      ],
    );

    final String panNumber = _firstText(
      seller,
      <String>[
        'panNumber',
        'pan',
      ],
    );

    final String registrationDocument = _firstText(
      seller,
      <String>[
        'businessRegistrationDocumentUrl',
        'registrationDocumentUrl',
        'farmRegistrationDocumentUrl',
      ],
    );

    final String panDocument = _firstText(
      seller,
      <String>[
        'panDocumentUrl',
        'panCertificateUrl',
      ],
    );

    final String vatNumber = _firstText(
      seller,
      <String>[
        'vatNumber',
        'vat',
      ],
    );

    final String vatDocument = _firstText(
      seller,
      <String>[
        'vatDocumentUrl',
        'vatCertificateUrl',
      ],
    );

    if (registrationNumber.isEmpty) {
      missing.add('Registration Number');
    }

    if (registrationDocument.isEmpty) {
      missing.add('Registration Certificate');
    }

    if (panNumber.isEmpty) {
      missing.add('PAN Number');
    }

    if (panDocument.isEmpty) {
      missing.add('PAN Certificate');
    }

    if (vatNumber.isNotEmpty && vatDocument.isEmpty) {
      missing.add('VAT Certificate');
    }

    if (!_declarationAccepted(seller)) {
      missing.add('Legal Declaration');
    }

    return missing;
  }

  bool _documentsComplete(
    Map<String, dynamic> seller,
  ) {
    return _missingLegalRequirements(seller).isEmpty;
  }

  Future<Map<String, dynamic>?> _freshSeller(
    String sellerId,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _sellers.doc(sellerId).get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data() ?? <String, dynamic>{};
  }

  Future<void> _verifyDocuments(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) async {
    try {
      final Map<String, dynamic>? fresh =
          await _freshSeller(sellerId);

      if (fresh == null) {
        throw Exception('Krishi seller account not found.');
      }

      final List<String> missing =
          _missingLegalRequirements(fresh);

      if (missing.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verification blocked. Missing: '
                '${missing.join(', ')}',
              ),
            ),
          );
        }
        return;
      }

      await _sellers.doc(sellerId).update(
        <String, dynamic>{
          'legalVerificationStatus': 'verified',
          'legalVerified': true,
          'legalVerifiedAt': FieldValue.serverTimestamp(),
          'legalVerifiedBy':
              FirebaseAuth.instance.currentUser?.uid ?? '',
          'adminReviewRequested': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Documents verified successfully. '
              'Now Approve & Activate the Krishi seller.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification failed: '
              '${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _approve(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) async {
    try {
      final Map<String, dynamic>? fresh =
          await _freshSeller(sellerId);

      if (fresh == null) {
        throw Exception('Krishi seller account not found.');
      }

      final List<String> missing =
          _missingLegalRequirements(fresh);

      if (missing.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Approval blocked. Missing: '
                '${missing.join(', ')}',
              ),
            ),
          );
        }
        return;
      }

      final String shopName =
          fresh['shopName']?.toString().trim() ??
              'Krishi Seller';

      await _sellers.doc(sellerId).update(
        <String, dynamic>{
          // Approve + verify together from the latest Firestore data.
          // This avoids a stale two-step state between Verify and Activate.
          'legalVerificationStatus': 'approved',
          'legalVerified': true,
          'legalVerifiedAt':
              fresh['legalVerifiedAt'] ??
                  FieldValue.serverTimestamp(),
          'legalVerifiedBy':
              fresh['legalVerifiedBy']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? fresh['legalVerifiedBy']
                  : FirebaseAuth.instance.currentUser?.uid ?? '',
          'isActive': true,
          'accountStatus': 'active',
          'adminReviewRequested': false,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy':
              FirebaseAuth.instance.currentUser?.uid ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Notification is intentionally best-effort.
      try {
        final DocumentReference<Map<String, dynamic>> ref =
            FirebaseFirestore.instance
                .collection('admin_notifications')
                .doc();

        await ref.set(
          <String, dynamic>{
            'notificationId': ref.id,
            'title': 'Krishi Seller Approved',
            'message':
                '$shopName has been approved. '
                'Your Krishi Seller Dashboard is now active.',
            'audience': 'seller',
            'contentType': 'krishi_seller_approval',
            'targetCustomerId': '',
            'targetSellerId': sellerId,
            'mediaUrl': '',
            'actionUrl': '',
            'isActive': true,
            'pushEnabled': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$shopName approved and activated successfully.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approval failed: '
              '${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deactivate(
    BuildContext context,
    String sellerId,
    String shopName,
  ) async {
    try {
      await _sellers.doc(sellerId).update(
        <String, dynamic>{
          'isActive': false,
          'accountStatus': 'deactivated',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$shopName deactivated.'),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not deactivate: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    String sellerId,
    String shopName,
  ) async {
    final TextEditingController reason =
        TextEditingController();

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Verification'),
          content: TextField(
            controller: reason,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason / required changes',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  reason.text.trim(),
                );
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reason.dispose();

    if (result == null) {
      return;
    }

    try {
      await _sellers.doc(sellerId).update(
        <String, dynamic>{
          'isActive': false,
          'legalVerified': false,
          'legalVerificationStatus': 'rejected',
          'legalVerificationRejectionReason': result,
          'adminReviewRequested': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$shopName verification rejected.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reject failed: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  Widget _certificateCard(
    String title,
    String url,
  ) {
    final bool available = url.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 58,
          height: 58,
          child: available
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(
                      Icons.broken_image_outlined,
                    ),
                  ),
                )
              : const Icon(
                  Icons.description_outlined,
                  size: 34,
                ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          available ? 'Uploaded' : 'Missing',
          style: TextStyle(
            color:
                available ? Colors.green : Colors.red,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: null,
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) {
    final String shopName =
        seller['shopName']?.toString().trim() ?? 'Krishi Seller';
    final String ownerName =
        seller['ownerName']?.toString().trim() ?? '';
    final String phone =
        seller['phone']?.toString().trim() ?? '';
    final String email =
        seller['email']?.toString().trim() ?? '';
    final String registration = _firstText(
      seller,
      <String>[
        'businessRegistrationNumber',
        'registrationNumber',
        'farmRegistrationNumber',
      ],
    );
    final String pan = _firstText(
      seller,
      <String>[
        'panNumber',
        'pan',
      ],
    );
    final String vat = _firstText(
      seller,
      <String>[
        'vatNumber',
        'vat',
      ],
    );
    final String registrationUrl = _firstText(
      seller,
      <String>[
        'businessRegistrationDocumentUrl',
        'registrationDocumentUrl',
        'farmRegistrationDocumentUrl',
      ],
    );
    final String panUrl = _firstText(
      seller,
      <String>[
        'panDocumentUrl',
        'panCertificateUrl',
      ],
    );
    final String vatUrl = _firstText(
      seller,
      <String>[
        'vatDocumentUrl',
        'vatCertificateUrl',
      ],
    );
    final bool active = seller['isActive'] == true;
    final bool verified = seller['legalVerified'] == true;
    final String status =
        seller['legalVerificationStatus']
                ?.toString()
                .trim() ??
            'pending';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              18,
              4,
              18,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ownerName.isNotEmpty) Text(ownerName),
                if (phone.isNotEmpty) Text(phone),
                if (email.isNotEmpty) Text(email),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(
                      avatar: Icon(
                        verified
                            ? Icons.verified
                            : Icons.pending_actions,
                        color: verified
                            ? Colors.green
                            : Colors.orange,
                      ),
                      label: Text(
                        'Verification: ${status.toUpperCase()}',
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        active
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: active
                            ? Colors.green
                            : Colors.red,
                      ),
                      label: Text(
                        active ? 'ACTIVE' : 'INACTIVE',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  'Registration No: $registration',
                ),
                Text('PAN: $pan'),
                Text(
                  'VAT: ${vat.isEmpty ? 'Not applicable' : vat}',
                ),
                const SizedBox(height: 14),
                _certificateCard(
                  'Business Registration Certificate',
                  registrationUrl,
                ),
                _certificateCard(
                  'PAN Certificate / Card',
                  panUrl,
                ),
                if (vat.isNotEmpty)
                  _certificateCard(
                    'VAT Certificate',
                    vatUrl,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _verifyDocuments(
                            context,
                            sellerId,
                            seller,
                          );
                        },
                        icon: Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.fact_check_rounded,
                        ),
                        label: Text(
                          verified
                              ? 'Re-Verify Documents'
                              : 'Verify Documents',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: active
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _approve(
                                  context,
                                  sellerId,
                                  seller,
                                );
                              },
                        icon: const Icon(
                          Icons.verified_user_rounded,
                        ),
                        label: const Text(
                          'Approve & Activate',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _reject(
                            context,
                            sellerId,
                            shopName,
                          );
                        },
                        icon: const Icon(
                          Icons.block_rounded,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    if (active) ...<Widget>[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            await _deactivate(
                              context,
                              sellerId,
                              shopName,
                            );
                          },
                          icon: const Icon(
                            Icons.pause_circle_outline,
                          ),
                          label: const Text(
                            'Deactivate',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Sellers',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _sellers
            .where(
              'sellerType',
              isEqualTo: 'krishi',
            )
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not load Krishi sellers:\n${snapshot.error}',
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
              sellers = snapshot.data!.docs.toList();

          sellers.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  a,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  b,
            ) {
              final bool aPending =
                  a.data()['isActive'] != true;
              final bool bPending =
                  b.data()['isActive'] != true;
              if (aPending == bPending) {
                return 0;
              }
              return aPending ? -1 : 1;
            },
          );

          if (sellers.isEmpty) {
            return const Center(
              child: Text(
                'No Krishi Seller requests yet.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sellers.length,
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  document = sellers[index];
              final Map<String, dynamic> seller =
                  document.data();

              final String shopName =
                  seller['shopName']?.toString() ??
                      'Krishi Seller';
              final String ownerName =
                  seller['ownerName']?.toString() ?? '';
              final bool active =
                  seller['isActive'] == true;
              final bool verified =
                  seller['legalVerified'] == true;
              final bool documentsComplete =
                  _documentsComplete(seller);

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  onTap: () {
                    _showDetails(
                      context,
                      document.id,
                      seller,
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor:
                        Colors.green.withValues(
                      alpha: 0.12,
                    ),
                    child: const Icon(
                      Icons.agriculture_rounded,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(
                    shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$ownerName\n'
                    'Documents: ${documentsComplete ? 'Complete' : 'Incomplete'} • '
                    'Verification: ${verified ? 'Verified' : (seller['legalVerificationStatus'] ?? 'pending')}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: active
                        ? 'Active Krishi Seller'
                        : 'Verify / Approve Krishi Seller',
                    onPressed: () {
                      _showDetails(
                        context,
                        document.id,
                        seller,
                      );
                    },
                    icon: Icon(
                      active
                          ? Icons.check_circle
                          : Icons.pending_actions_rounded,
                      color: active
                          ? Colors.green
                          : Colors.red,
                    ),
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
