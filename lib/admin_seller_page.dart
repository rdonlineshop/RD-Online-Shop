import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/local_file_image.dart';

class AdminSellerPage extends StatelessWidget {
  const AdminSellerPage({super.key});

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  CollectionReference<Map<String, dynamic>> get _sellers =>
      FirebaseFirestore.instance.collection('sellers');


  Future<void> _showSellerRegistrationInfo(
    BuildContext context,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('New Seller'),
          content: const Text(
            'For a launch-safe seller account, the seller must create the '
            'account from Seller Login > Register. After registration, the '
            'seller appears here and Admin can review and activate the account.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _sellerPhoto(Map<String, dynamic> seller) {
    const List<String> possibleFields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'profilePhotoUrl',
      'profileImageUrl',
      'photo',
      'image',
    ];

    for (final String field in possibleFields) {
      final dynamic value = seller[field];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final dynamic photos = seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic item in photos) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
    }

    return '';
  }

  Future<void> _contact(
    BuildContext context,
    String phone,
    bool sms,
  ) async {
    if (phone.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: sms ? 'sms' : 'tel',
      path: phone.replaceAll(' ', ''),
    );

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone application could not be opened.',
          ),
        ),
      );
    }
  }

  Future<void> _email(
    BuildContext context,
    String email,
  ) async {
    if (email.trim().isEmpty) {
      return;
    }

    final Uri uri = Uri(
      scheme: 'mailto',
      path: email.trim(),
    );

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email application could not be opened.',
          ),
        ),
      );
    }
  }

  bool _isLegacySeller(
    Map<String, dynamic> seller,
  ) {
    final String registrationNumber =
        seller['businessRegistrationNumber']
                ?.toString()
                .trim() ??
            '';

    final String panNumber =
        seller['panNumber']?.toString().trim() ??
            '';

    final String registrationPath =
        seller['businessRegistrationDocumentPath']
                ?.toString()
                .trim() ??
            '';

    final String panPath =
        seller['panDocumentPath']
                ?.toString()
                .trim() ??
            '';

    final String ownerIdPath =
        seller['ownerIdDocumentPath']
                ?.toString()
                .trim() ??
            '';

    final bool hasSubmissionMarker =
        seller['legalSubmittedAt'] != null ||
            seller['legalDeclarationAccepted'] == true ||
            seller['legalDocumentsUploaded'] == true;

    return !hasSubmissionMarker &&
        registrationNumber.isEmpty &&
        panNumber.isEmpty &&
        registrationPath.isEmpty &&
        panPath.isEmpty &&
        ownerIdPath.isEmpty;
  }

  String _legalStatusLabel(
    Map<String, dynamic> seller,
  ) {
    if (seller['legalVerified'] == true ||
        seller['legalVerificationStatus'] == 'approved') {
      return 'Verified';
    }

    if (seller['legalVerificationStatus'] == 'rejected') {
      return 'Changes Required';
    }

    if (_isLegacySeller(seller)) {
      return 'Legacy • Pending';
    }

    return 'Pending';
  }

  List<String> _missingLegalRequirements(
    Map<String, dynamic> seller,
  ) {
    final List<String> missing = <String>[];

    final String registrationNumber =
        seller['businessRegistrationNumber']
                ?.toString()
                .trim() ??
            '';
    final String panNumber =
        seller['panNumber']?.toString().trim() ??
            '';
    final String vatNumber =
        seller['vatNumber']?.toString().trim() ??
            '';

    final String registrationPath =
        seller['businessRegistrationDocumentPath']
                ?.toString()
                .trim() ??
            '';
    final String panPath =
        seller['panDocumentPath']
                ?.toString()
                .trim() ??
            '';
    final String vatPath =
        seller['vatDocumentPath']
                ?.toString()
                .trim() ??
            '';
    final String ownerIdPath =
        seller['ownerIdDocumentPath']
                ?.toString()
                .trim() ??
            '';

    if (registrationNumber.isEmpty) {
      missing.add('Registration Number');
    }

    if (panNumber.isEmpty) {
      missing.add('PAN Number');
    }

    if (seller['legalDeclarationAccepted'] != true) {
      missing.add('Legal Declaration');
    }

    if (registrationPath.isEmpty) {
      missing.add('Registration Certificate');
    }

    if (panPath.isEmpty) {
      missing.add('PAN Certificate');
    }

    if (ownerIdPath.isEmpty) {
      missing.add('Owner / Authorized Person ID');
    }

    if (vatNumber.isNotEmpty &&
        vatPath.isEmpty) {
      missing.add('VAT Certificate');
    }

    return missing;
  }

  void _createSellerNotification({
    required WriteBatch batch,
    required String sellerId,
    required String title,
    required String message,
    required String contentType,
  }) async {
    final DocumentReference<Map<String, dynamic>>
        notificationRef = FirebaseFirestore.instance
            .collection('admin_notifications')
            .doc();

    batch.set(
      notificationRef,
      <String, dynamic>{
        'notificationId': notificationRef.id,
        'title': title,
        'message': message,
        'audience': 'seller',
        'contentType': contentType,
        'targetCustomerId': '',
        'targetSellerId': sellerId,
        'mediaUrl': '',
        'actionUrl': '',
        'isActive': true,
        'pushEnabled': true,
        'createdByUid':
            FirebaseAuth.instance.currentUser?.uid ?? '',
        'createdAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _approveSeller(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller, {
    bool closeAfter = false,
  }) async {
    final List<String> missing =
        _missingLegalRequirements(seller);

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot approve. Missing: ${missing.join(', ')}.',
          ),
        ),
      );
      return;
    }

    final String shopName =
        seller['shopName']?.toString().trim() ??
            'Seller';

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Verify & Activate Seller?',
          ),
          content: Text(
            'Confirm that the legal information and uploaded documents for $shopName have been reviewed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.verified_rounded,
              ),
              label: const Text(
                'Verify & Activate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final String adminUid =
        FirebaseAuth.instance.currentUser?.uid ??
            '';

    final WriteBatch batch =
        FirebaseFirestore.instance.batch();

    batch.update(
      _sellers.doc(sellerId),
      <String, dynamic>{
        'isActive': true,
        'legalVerificationStatus': 'approved',
        'legalVerified': true,
        'legalVerifiedAt':
            FieldValue.serverTimestamp(),
        'legalVerifiedBy': adminUid,
        'legalRejectionReason': '',
        'adminReviewRequested': false,
        'reviewedAt':
            FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    _createSellerNotification(
      batch: batch,
      sellerId: sellerId,
      title: 'Seller Account Approved',
      message:
          '$shopName has been approved by NRD Admin. Your Seller Dashboard is now active.',
      contentType: 'seller_approval',
    );

    await batch.commit();

    if (context.mounted) {
      if (closeAfter) {
        Navigator.maybePop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$shopName verified and activated.',
          ),
        ),
      );
    }
  }

  Future<void> _rejectSeller(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) async {
    final TextEditingController reasonController =
        TextEditingController();

    final String shopName =
        seller['shopName']?.toString().trim() ??
            'Seller';

    final String? reason =
        await showDialog<String>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Reject / Request Changes',
          ),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText:
                  'Reason for seller',
              hintText:
                  'Example: PAN certificate is unclear. Please upload a clear copy.',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String value =
                    reasonController.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text(
                'Send Reason',
              ),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null ||
        reason.trim().isEmpty) {
      return;
    }

    final String adminUid =
        FirebaseAuth.instance.currentUser?.uid ??
            '';

    final WriteBatch batch =
        FirebaseFirestore.instance.batch();

    batch.update(
      _sellers.doc(sellerId),
      <String, dynamic>{
        'isActive': false,
        'legalVerificationStatus': 'rejected',
        'legalVerified': false,
        'legalVerifiedAt': null,
        'legalVerifiedBy': '',
        'legalRejectionReason': reason.trim(),
        'adminReviewRequested': false,
        'reviewedAt':
            FieldValue.serverTimestamp(),
        'reviewedBy': adminUid,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );

    _createSellerNotification(
      batch: batch,
      sellerId: sellerId,
      title: 'Seller Verification Needs Changes',
      message:
          '$shopName requires changes before approval. Reason: ${reason.trim()}',
      contentType: 'seller_verification_rejected',
    );

    await batch.commit();

    if (context.mounted) {
      Navigator.maybePop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification reason sent to $shopName.',
          ),
        ),
      );
    }
  }

  Future<void> _setActive(
    BuildContext context,
    String sellerId,
    bool value,
    Map<String, dynamic> seller,
  ) async {
    if (value) {
      if (_isLegacySeller(seller)) {
        await _sellers.doc(sellerId).update(
          <String, dynamic>{
            'isActive': true,
            'legalVerificationStatus': 'pending',
            'legalVerified': false,
            'legalMigrationPending': true,
            'adminReviewRequested': false,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Legacy seller reactivated. Legal verification remains pending.',
              ),
            ),
          );
        }
        return;
      }

      await _approveSeller(
        context,
        sellerId,
        seller,
      );
      return;
    }

    await _sellers.doc(sellerId).update(
      <String, dynamic>{
        'isActive': false,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
    );
  }

  void _showLegalDocument(
    BuildContext context, {
    required String title,
    required String storagePath,
  }) {
    final String path = storagePath.trim();

    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$title has not been uploaded.',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 650,
            height: 520,
            child: FutureBuilder(
              future: FirebaseStorage.instance
                  .ref(path)
                  .getData(
                    10 * 1024 * 1024,
                  ),
              builder: (
                BuildContext context,
                AsyncSnapshot<dynamic> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not open document.\n${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final dynamic bytes =
                    snapshot.data;

                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _legalDocumentRow(
    BuildContext context, {
    required String label,
    required String storagePath,
    bool requiredDocument = false,
  }) {
    final bool uploaded =
        storagePath.trim().isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        uploaded
            ? Icons.check_circle
            : Icons.warning_amber_rounded,
        color: uploaded
            ? Colors.green
            : Colors.orange,
      ),
      title: Text(
        requiredDocument
            ? '$label *'
            : label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        uploaded
            ? 'Uploaded privately'
            : 'Not uploaded',
      ),
      trailing: uploaded
          ? OutlinedButton.icon(
              onPressed: () {
                _showLegalDocument(
                  context,
                  title: label,
                  storagePath:
                      storagePath,
                );
              },
              icon: const Icon(
                Icons.visibility_outlined,
              ),
              label: const Text('View'),
            )
          : null,
    );
  }

  Future<void> _deleteSeller(
    BuildContext context,
    String sellerId,
    String shopName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Seller?'),
          content: Text(
            '$shopName will be permanently removed.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _sellers.doc(sellerId).delete();

    if (!context.mounted) {
      return;
    }

    Navigator.maybePop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seller deleted successfully.'),
      ),
    );
  }

  Widget _sellerAvatar(
    Map<String, dynamic> seller, {
    double radius = 28,
  }) {
    final String photo = _sellerPhoto(seller);
    final bool isActive = seller['isActive'] != false;

    if (photo.startsWith('http://') ||
        photo.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (
          Object exception,
          StackTrace? stackTrace,
        ) {},
      );
    }

    if (photo.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: AssetImage(photo),
      );
    }

    final Widget fallback = Icon(
      Icons.storefront,
      color: isActive ? Colors.blue : Colors.red,
      size: radius,
    );

    if (photo.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            isActive ? Colors.blue.shade50 : Colors.red.shade50,
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: buildLocalFileImage(
              photo,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              fallback: fallback,
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          isActive ? Colors.blue.shade50 : Colors.red.shade50,
      child: fallback,
    );
  }

  Widget _detail(
    IconData icon,
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSellerDetails(
    BuildContext context,
    String sellerId,
    Map<String, dynamic> seller,
  ) {
    final String shopName =
        seller['shopName']?.toString() ?? 'Unnamed Shop';

    final String ownerName =
        seller['ownerName']?.toString() ?? '';

    final String phone =
        seller['phone']?.toString() ?? '';

    final String email =
        seller['email']?.toString() ?? '';

    final String address =
        seller['address']?.toString() ?? '';

    final String description =
        seller['description']?.toString() ?? '';

    final String businessRegistrationNumber =
        seller['businessRegistrationNumber']?.toString() ?? '';

    final String panNumber =
        seller['panNumber']?.toString() ?? '';

    final String vatNumber =
        seller['vatNumber']?.toString() ?? '';

    final String legalVerificationStatus =
        seller['legalVerificationStatus']?.toString() ?? 'pending';

    final bool legalDeclarationAccepted =
        seller['legalDeclarationAccepted'] == true;

    final String registrationDocumentPath =
        seller['businessRegistrationDocumentPath']
                ?.toString() ??
            '';

    final String panDocumentPath =
        seller['panDocumentPath']
                ?.toString() ??
            '';

    final String vatDocumentPath =
        seller['vatDocumentPath']
                ?.toString() ??
            '';

    final String ownerIdDocumentPath =
        seller['ownerIdDocumentPath']
                ?.toString() ??
            '';

    final List<String> otherLegalDocumentPaths =
        (seller['otherLegalDocumentPaths'] is List)
            ? (seller['otherLegalDocumentPaths']
                    as List)
                .map(
                  (dynamic value) =>
                      value.toString(),
                )
                .where(
                  (String value) =>
                      value.trim().isNotEmpty,
                )
                .toList()
            : <String>[];

    final String rejectionReason =
        seller['legalRejectionReason']
                ?.toString()
                .trim() ??
            '';

    final bool isActive =
        seller['isActive'] != false;

    final bool isLegacySeller =
        _isLegacySeller(seller);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _sellerAvatar(
                      seller,
                      radius: 44,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green
                                      .withValues(alpha: 0.12)
                                  : Colors.red
                                      .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              isActive
                                  ? (isLegacySeller
                                      ? 'Active • Legal Pending'
                                      : 'Active')
                                  : 'Inactive',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _detail(
                  Icons.person,
                  'Owner',
                  ownerName,
                ),
                _detail(
                  Icons.phone,
                  'Phone',
                  phone,
                ),
                _detail(
                  Icons.email,
                  'Email',
                  email,
                ),
                _detail(
                  Icons.location_on,
                  'Shop Address',
                  address,
                ),
                _detail(
                  Icons.description,
                  'Description',
                  description,
                ),
                const Divider(height: 28),
                const Text(
                  'Government / Legal Verification',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (isLegacySeller && isActive)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 14,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange
                          .withValues(alpha: 0.09),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange
                            .withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.history_rounded,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Legacy seller: this account existed before NRD legal verification was introduced. Selling access remains active, while legal verification stays pending until the seller submits the required documents.',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _detail(
                  Icons.verified_outlined,
                  'Business Registration Number',
                  businessRegistrationNumber,
                ),
                _detail(
                  Icons.badge_outlined,
                  'PAN Number',
                  panNumber,
                ),
                _detail(
                  Icons.receipt_long_outlined,
                  'VAT Number',
                  vatNumber,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    legalDeclarationAccepted
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: legalDeclarationAccepted
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: const Text('Legal Declaration'),
                  subtitle: Text(
                    legalDeclarationAccepted
                        ? 'Seller confirmed legal registration information'
                        : 'Not confirmed',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    legalVerificationStatus == 'approved'
                        ? Icons.verified
                        : Icons.pending_actions_rounded,
                    color: legalVerificationStatus == 'approved'
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: const Text('Legal Verification Status'),
                  subtitle: Text(
                    _legalStatusLabel(seller),
                  ),
                ),
                if (legalVerificationStatus == 'rejected' &&
                    rejectionReason.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Rejection reason: $rejectionReason',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                _legalDocumentRow(
                  sheetContext,
                  label:
                      'Registration Certificate',
                  storagePath:
                      registrationDocumentPath,
                  requiredDocument: true,
                ),
                _legalDocumentRow(
                  sheetContext,
                  label: 'PAN Certificate',
                  storagePath: panDocumentPath,
                  requiredDocument: true,
                ),
                _legalDocumentRow(
                  sheetContext,
                  label: 'VAT Certificate',
                  storagePath: vatDocumentPath,
                  requiredDocument:
                      vatNumber.trim().isNotEmpty,
                ),
                _legalDocumentRow(
                  sheetContext,
                  label:
                      'Owner / Authorized Person ID',
                  storagePath:
                      ownerIdDocumentPath,
                  requiredDocument: true,
                ),
                ...List<Widget>.generate(
                  otherLegalDocumentPaths.length,
                  (int index) {
                    return _legalDocumentRow(
                      sheetContext,
                      label:
                          'Other Legal Document ${index + 1}',
                      storagePath:
                          otherLegalDocumentPaths[index],
                    );
                  },
                ),
                if (!isActive) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _rejectSeller(
                              sheetContext,
                              sellerId,
                              seller,
                            );
                          },
                          icon: const Icon(
                            Icons
                                .edit_note_rounded,
                          ),
                          label: const Text(
                            'Reject / Changes',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            _approveSeller(
                              sheetContext,
                              sellerId,
                              seller,
                              closeAfter: true,
                            );
                          },
                          icon: const Icon(
                            Icons
                                .verified_rounded,
                          ),
                          label: const Text(
                            'Verify & Activate',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 28),
                _detail(
                  Icons.percent,
                  'NRD Commission',
                  '${seller['commissionPercent'] ?? 10}%',
                ),
                _detail(
                  Icons.account_balance_wallet_outlined,
                  'eSewa',
                  seller['esewaNumber']?.toString() ?? '',
                ),
                _detail(
                  Icons.account_balance_wallet,
                  'Khalti',
                  seller['khaltiNumber']?.toString() ?? '',
                ),
                _detail(
                  Icons.account_balance,
                  'Bank',
                  seller['bankName']?.toString() ?? '',
                ),
                _detail(
                  Icons.person_outline,
                  'Account Holder',
                  seller['bankAccountHolder']?.toString() ?? '',
                ),
                _detail(
                  Icons.numbers,
                  'Account Number',
                  seller['bankAccountNumber']?.toString() ?? '',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    seller['paymentVerified'] == true
                        ? Icons.verified
                        : Icons.gpp_maybe_outlined,
                    color: seller['paymentVerified'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: const Text('Payment Verification'),
                  subtitle: Text(
                    seller['paymentVerified'] == true
                        ? 'Verified by Admin'
                        : 'Not verified',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty
                            ? null
                            : () {
                                _contact(
                                  context,
                                  phone,
                                  false,
                                );
                              },
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty
                            ? null
                            : () {
                                _contact(
                                  context,
                                  phone,
                                  true,
                                );
                              },
                        icon: const Icon(Icons.sms_outlined),
                        label: const Text('SMS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (email.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _email(
                          context,
                          email,
                        );
                      },
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email'),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);

                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  _SellerFormPage(
                                sellerId: sellerId,
                                seller: seller,
                                cloudName: _cloudName,
                                uploadPreset:
                                    _uploadPreset,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Seller'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _deleteSeller(
                            sheetContext,
                            sellerId,
                            shopName,
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Delete Seller',
                          style: TextStyle(
                            color: Colors.red,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seller Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          TextButton.icon(
            onPressed: () =>
                _showSellerRegistrationInfo(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New Seller'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _sellers.snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  QuerySnapshot<Map<String, dynamic>>>
              snapshot,
        ) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load sellers:\n${snapshot.error}',
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
              sellers = snapshot.data!.docs;

          if (sellers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.storefront_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No seller account has been created yet.',
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () =>
                        _showSellerRegistrationInfo(context),
                    icon: const Icon(
                      Icons.person_add_alt_1_rounded,
                    ),
                    label: const Text('New Seller'),
                  ),
                ],
              ),
            );
          }

          final int pendingCount = sellers.where(
            (
              QueryDocumentSnapshot<Map<String, dynamic>> document,
            ) {
              final Map<String, dynamic> seller = document.data();
              final bool isActive =
                  seller['isActive'] != false;

              return seller['adminReviewRequested'] == true ||
                  (!isActive &&
                      seller['legalVerificationStatus'] == 'pending' &&
                      !_isLegacySeller(seller));
            },
          ).length;

          sellers.sort(
            (
              QueryDocumentSnapshot<Map<String, dynamic>> first,
              QueryDocumentSnapshot<Map<String, dynamic>> second,
            ) {
              final bool firstPending =
                  first.data()['isActive'] == false ||
                  first.data()['adminReviewRequested'] == true;
              final bool secondPending =
                  second.data()['isActive'] == false ||
                  second.data()['adminReviewRequested'] == true;

              if (firstPending == secondPending) {
                return 0;
              }
              return firstPending ? -1 : 1;
            },
          );

          return Column(
            children: <Widget>[
              if (pendingCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$pendingCount seller verification request${pendingCount == 1 ? '' : 's'} waiting for Admin review.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
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
                      'Unnamed Shop';

              final String ownerName =
                  seller['ownerName']?.toString() ??
                      'No owner name';

              final String phone =
                  seller['phone']?.toString() ?? '';

              final bool isActive =
                  seller['isActive'] != false;

              return Card(
                margin:
                    const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  onTap: () {
                    _showSellerDetails(
                      context,
                      document.id,
                      seller,
                    );
                  },
                  leading: _sellerAvatar(
                    seller,
                    radius: 30,
                  ),
                  title: Text(
                    shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Padding(
                    padding:
                        const EdgeInsets.only(top: 4),
                    child: Text(
                      '$ownerName'
                      '${phone.isEmpty ? '' : '\n$phone'}'
                      '\nLegal: ${_legalStatusLabel(seller)}'
                      '${seller['adminReviewRequested'] == true ? ' • REVIEW' : ''}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: isActive,
                    onChanged: (bool value) {
                      _setActive(
                        context,
                        document.id,
                        value,
                        seller,
                      );
                    },
                  ),
                ),
              );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerFormPage extends StatefulWidget {
  final String? sellerId;
  final Map<String, dynamic>? seller;
  final String cloudName;
  final String uploadPreset;

  const _SellerFormPage({
    this.sellerId,
    this.seller,
    required this.cloudName,
    required this.uploadPreset,
  });

  @override
  State<_SellerFormPage> createState() =>
      _SellerFormPageState();
}

class _SellerFormPageState
    extends State<_SellerFormPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _shopName;
  late final TextEditingController _ownerName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late final TextEditingController _commissionPercent;

  // Seller payout/payment details
  late final TextEditingController _esewaNumber;
  late final TextEditingController _khaltiNumber;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAccountHolder;
  late final TextEditingController _bankAccountNumber;

  String _photoUrl = '';
  String _paymentQrUrl = '';

  bool _isActive = true;
  bool _paymentVerified = false;
  bool _uploading = false;
  bool _saving = false;

  bool get _editing =>
      widget.sellerId != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? seller =
        widget.seller;

    _shopName = TextEditingController(
      text:
          seller?['shopName']?.toString() ?? '',
    );

    _ownerName = TextEditingController(
      text:
          seller?['ownerName']?.toString() ?? '',
    );

    _phone = TextEditingController(
      text: seller?['phone']?.toString() ?? '',
    );

    _email = TextEditingController(
      text: seller?['email']?.toString() ?? '',
    );

    _address = TextEditingController(
      text:
          seller?['address']?.toString() ?? '',
    );

    _description = TextEditingController(
      text: seller?['description']?.toString() ?? '',
    );

    _commissionPercent = TextEditingController(
      text: seller?['commissionPercent']?.toString() ?? '10',
    );

    _esewaNumber = TextEditingController(
      text: seller?['esewaNumber']?.toString() ?? '',
    );
    _khaltiNumber = TextEditingController(
      text: seller?['khaltiNumber']?.toString() ?? '',
    );
    _bankName = TextEditingController(
      text: seller?['bankName']?.toString() ?? '',
    );
    _bankAccountHolder = TextEditingController(
      text: seller?['bankAccountHolder']?.toString() ?? '',
    );
    _bankAccountNumber = TextEditingController(
      text: seller?['bankAccountNumber']?.toString() ?? '',
    );

    _paymentQrUrl =
        seller?['paymentQrUrl']?.toString() ?? '';
    _paymentVerified =
        seller?['paymentVerified'] == true;

    _isActive =
        seller?['isActive'] != false;

    _photoUrl = _existingPhoto(
      seller,
    );
  }

  String _existingPhoto(
    Map<String, dynamic>? seller,
  ) {
    if (seller == null) {
      return '';
    }

    const List<String> fields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'profilePhotoUrl',
      'profileImageUrl',
      'photo',
      'image',
    ];

    for (final String field in fields) {
      final dynamic value =
          seller[field];

      if (value is String &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final dynamic photos =
        seller['shopPhotos'];

    if (photos is List) {
      for (final dynamic photo in photos) {
        if (photo is String &&
            photo.trim().isNotEmpty) {
          return photo.trim();
        }
      }
    }

    return '';
  }

  @override
  void dispose() {
    _shopName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _description.dispose();
    _commissionPercent.dispose();
    _esewaNumber.dispose();
    _khaltiNumber.dispose();
    _bankName.dispose();
    _bankAccountHolder.dispose();
    _bankAccountNumber.dispose();

    super.dispose();
  }

  Future<String> _uploadToCloudinary(
    XFile image,
  ) async {
    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${widget.cloudName}/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        widget.uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String body =
        await response.stream.bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Photo upload failed: $body',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(body)
            as Map<String, dynamic>;

    final String url =
        data['secure_url']?.toString() ?? '';

    if (url.isEmpty) {
      throw Exception(
        'Cloudinary image URL was not received.',
      );
    }

    return url;
  }

  Future<void> _choosePaymentQr() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String url = await _uploadToCloudinary(image);

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentQrUrl = url;
        // Any changed payout detail must be re-verified by Admin.
        _paymentVerified = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment QR uploaded. Verify details before enabling direct payment.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment QR upload failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _choosePhoto() async {
    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String url =
          await _uploadToCloudinary(
        image,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photoUrl = url;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Seller photo uploaded successfully.',
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
            'Photo upload failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _saveSeller() async {
    if (!_formKey.currentState!.validate() ||
        _saving ||
        _uploading) {
      return;
    }
    final double? commissionPercent =
        double.tryParse(_commissionPercent.text.trim());

    if (commissionPercent == null ||
        commissionPercent < 0 ||
        commissionPercent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'RD Commission must be between 0 and 100.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> data =
          <String, dynamic>{
        'shopName':
            _shopName.text.trim(),
        'ownerName':
            _ownerName.text.trim(),
        'phone':
            _phone.text.trim(),
        'email':
            _email.text.trim(),
        'address':
            _address.text.trim(),
        'description':
            _description.text.trim(),
        'commissionPercent': commissionPercent,

        // Seller payout/payment profile
        'esewaNumber': _esewaNumber.text.trim(),
        'khaltiNumber': _khaltiNumber.text.trim(),
        'bankName': _bankName.text.trim(),
        'bankAccountHolder':
            _bankAccountHolder.text.trim(),
        'bankAccountNumber':
            _bankAccountNumber.text.trim(),
        'paymentQrUrl': _paymentQrUrl,
        'paymentVerified': _paymentVerified,
        'paymentVerifiedAt': _paymentVerified
            ? FieldValue.serverTimestamp()
            : null,

        'photoUrl': _photoUrl,
        'shopPhotoUrl': _photoUrl,
        'shopImageUrl': _photoUrl,
        'shopPhotos': _photoUrl.isEmpty
            ? <String>[]
            : <String>[_photoUrl],
        'isActive': _isActive,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      final CollectionReference<
              Map<String, dynamic>>
          sellers = FirebaseFirestore.instance
              .collection('sellers');

      if (_editing) {
        await sellers.doc(widget.sellerId).set(
              data,
              SetOptions(merge: true),
            );
      } else {
        data['createdAt'] =
            FieldValue.serverTimestamp();

        await sellers.add(data);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not save seller: $error',
          ),
        ),
      );

      setState(() {
        _saving = false;
      });
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
        ),
        validator: requiredField
            ? (String? value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return '$label is required.';
                }

                return null;
              }
            : null,
      ),
    );
  }

  Widget _photoPreview() {
    if (_photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundColor:
            Colors.blue.shade50,
        child: const Icon(
          Icons.storefront,
          size: 52,
          color: Colors.blue,
        ),
      );
    }

    return CircleAvatar(
      radius: 52,
      backgroundColor:
          Colors.grey.shade200,
      backgroundImage:
          NetworkImage(_photoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Edit Seller'
              : 'Add Seller',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: Stack(
                children: <Widget>[
                  _photoPreview(),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      child: IconButton(
                        onPressed: _uploading
                            ? null
                            : _choosePhoto,
                        icon: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _field(
              _shopName,
              'Shop Name',
              requiredField: true,
            ),
            _field(
              _ownerName,
              'Owner Name',
              requiredField: true,
            ),
            _field(
              _phone,
              'Phone',
              keyboardType:
                  TextInputType.phone,
              requiredField: true,
            ),
            _field(
              _email,
              'Email',
              keyboardType:
                  TextInputType.emailAddress,
            ),
            _field(
              _address,
              'Shop Address',
              maxLines: 2,
            ),
            _field(
              _description,
              'Description',
              maxLines: 3,
            ),
            _field(
              _commissionPercent,
              'RD Commission (%)',
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              requiredField: true,
            ),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Seller Payment Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Used for RD settlement and eligible single-seller direct payments.',
            ),
            const SizedBox(height: 14),

            _field(
              _esewaNumber,
              'eSewa Number / Merchant ID',
              keyboardType: TextInputType.phone,
            ),
            _field(
              _khaltiNumber,
              'Khalti Number / Merchant ID',
              keyboardType: TextInputType.phone,
            ),
            _field(
              _bankName,
              'Bank Name',
            ),
            _field(
              _bankAccountHolder,
              'Bank Account Holder Name',
            ),
            _field(
              _bankAccountNumber,
              'Bank Account Number',
            ),

            if (_paymentQrUrl.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _paymentQrUrl,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text('Could not load payment QR.'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            OutlinedButton.icon(
              onPressed: _uploading
                  ? null
                  : _choosePaymentQr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(
                _paymentQrUrl.isEmpty
                    ? 'Upload Payment QR'
                    : 'Change Payment QR',
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Payment Details Verified by Admin',
              ),
              subtitle: Text(
                _paymentVerified
                    ? 'Verified — direct seller payment may be enabled for eligible orders.'
                    : 'Not verified — direct seller payment must remain disabled.',
              ),
              value: _paymentVerified,
              onChanged: (bool value) {
                setState(() {
                  _paymentVerified = value;
                });
              },
            ),

            const Divider(),
            SwitchListTile(
              contentPadding:
                  EdgeInsets.zero,
              title:
                  const Text('Seller Active'),
              value: _isActive,
              onChanged: (bool value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    _saving || _uploading
                        ? null
                        : _saveSeller,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : _editing
                          ? 'Save Changes'
                          : 'Add Seller',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}