import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDeliveryPersonManagementPage extends StatelessWidget {
  const AdminDeliveryPersonManagementPage({super.key});

  String _value(Map<String, dynamic> data, String key) {
    return data[key]?.toString().trim() ?? '';
  }

  Future<void> _showResult(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update Delivery Person: $error'),
        ),
      );
    }
  }

  Future<void> _verifyLicence(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _showResult(
      context,
      () => ref.update(
        <String, dynamic>{
          'drivingLicenseVerified': true,
          'drivingLicenseVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ),
      'Driving licence verified.',
    );
  }

  Future<void> _approveDeliveryPerson(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();

    final bool licenceVerified =
        data['drivingLicenseVerified'] == true;
    final String vehicleNumber = _value(data, 'vehicleNumber');
    final String licenceNumber = _value(data, 'drivingLicenseNumber');
    final String licenceExpiry = _value(data, 'drivingLicenseExpiry');
    final String photoUrl = _value(data, 'photoUrl');
    final String licenceFront = _value(data, 'drivingLicenseFrontUrl');
    final String licenceBack = _value(data, 'drivingLicenseBackUrl');

    if (photoUrl.isEmpty ||
        vehicleNumber.isEmpty ||
        licenceNumber.isEmpty ||
        licenceExpiry.isEmpty ||
        licenceFront.isEmpty ||
        licenceBack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo, vehicle and driving licence details must be complete before approval.',
          ),
        ),
      );
      return;
    }

    if (!licenceVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verify the driving licence before approving this Delivery Person.',
          ),
        ),
      );
      return;
    }

    await _showResult(
      context,
      () => doc.reference.update(
        <String, dynamic>{
          'isApproved': true,
          'isActive': true,
          'isOnline': false,
          'approvalStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ),
      'Delivery Person approved.',
    );
  }

  Future<void> _rejectDeliveryPerson(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Delivery Person?'),
          content: const Text(
            'This account will not be able to open the Delivery Dashboard until an Admin approves it again.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await _showResult(
      context,
      () => doc.reference.update(
        <String, dynamic>{
          'isApproved': false,
          'isActive': false,
          'isOnline': false,
          'approvalStatus': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ),
      'Delivery Person rejected.',
    );
  }

  Future<void> _deactivateDeliveryPerson(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await _showResult(
      context,
      () => doc.reference.update(
        <String, dynamic>{
          'isActive': false,
          'isOnline': false,
          'approvalStatus': 'inactive',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ),
      'Delivery Person deactivated.',
    );
  }

  Future<void> _reactivateDeliveryPerson(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();

    if (data['isApproved'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Approve this Delivery Person before reactivating the account.',
          ),
        ),
      );
      return;
    }

    await _showResult(
      context,
      () => doc.reference.update(
        <String, dynamic>{
          'isActive': true,
          'isOnline': false,
          'approvalStatus': 'approved',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      ),
      'Delivery Person reactivated.',
    );
  }

  void _showImage(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title is not available.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
              maxHeight: 760,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Image could not be loaded.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    final String displayValue = value.isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(displayValue)),
        ],
      ),
    );
  }

  Widget _imageCard(
    BuildContext context, {
    required String title,
    required String url,
    required IconData icon,
  }) {
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () => _showImage(
                context,
                title: title,
                url: url,
              ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 120,
              width: double.infinity,
              child: url.isEmpty
                  ? Icon(
                      icon,
                      size: 46,
                      color: Colors.grey.shade500,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Icon(
                            Icons.broken_image_outlined,
                            size: 46,
                            color: Colors.grey.shade500,
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              url.isEmpty ? 'Not uploaded' : 'Tap to view',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Delivery Person Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('delivery_persons')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load Delivery Persons.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          );

          docs.sort((a, b) {
            final Map<String, dynamic> aData = a.data();
            final Map<String, dynamic> bData = b.data();

            final bool aApproved = aData['isApproved'] == true;
            final bool bApproved = bData['isApproved'] == true;

            if (aApproved != bApproved) {
              return aApproved ? 1 : -1;
            }

            final String aCreated = _value(aData, 'createdAt');
            final String bCreated = _value(bData, 'createdAt');
            return bCreated.compareTo(aCreated);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text('No Delivery Person registrations found.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                  docs[index];
              final Map<String, dynamic> data = doc.data();

              return _DeliveryPersonCard(
                doc: doc,
                data: data,
                value: _value,
                detailRow: _detailRow,
                imageCard: _imageCard,
                onVerifyLicence: () =>
                    _verifyLicence(context, doc.reference),
                onApprove: () => _approveDeliveryPerson(context, doc),
                onReject: () => _rejectDeliveryPerson(context, doc),
                onDeactivate: () =>
                    _deactivateDeliveryPerson(context, doc),
                onReactivate: () =>
                    _reactivateDeliveryPerson(context, doc),
              );
            },
          );
        },
      ),
    );
  }
}

class _DeliveryPersonCard extends StatelessWidget {
  const _DeliveryPersonCard({
    required this.doc,
    required this.data,
    required this.value,
    required this.detailRow,
    required this.imageCard,
    required this.onVerifyLicence,
    required this.onApprove,
    required this.onReject,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic> data;
  final String Function(Map<String, dynamic>, String) value;
  final Widget Function(String, String) detailRow;
  final Widget Function(
    BuildContext, {
    required String title,
    required String url,
    required IconData icon,
  }) imageCard;
  final VoidCallback onVerifyLicence;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final String name = value(data, 'name');
    final String phone = value(data, 'phone');
    final String email = value(data, 'email');
    final String vehicleType = value(data, 'vehicleType');
    final String vehicleNumber = value(data, 'vehicleNumber');
    final String licenceNumber = value(data, 'drivingLicenseNumber');
    final String licenceExpiry = value(data, 'drivingLicenseExpiry');
    final String photoUrl = value(data, 'photoUrl');
    final String licenceFront = value(data, 'drivingLicenseFrontUrl');
    final String licenceBack = value(data, 'drivingLicenseBackUrl');

    final bool licenceVerified =
        data['drivingLicenseVerified'] == true;
    final bool approved = data['isApproved'] == true;
    final bool active = data['isActive'] != false;
    final bool online = data['isOnline'] == true;
    final String approvalStatus =
        value(data, 'approvalStatus').toLowerCase();

    String statusText = 'Pending';
    Color statusColor = Colors.orange;

    if (approved && active) {
      statusText = online ? 'Online' : 'Approved';
      statusColor = online ? Colors.green : Colors.blue;
    } else if (approved && !active) {
      statusText = 'Inactive';
      statusColor = Colors.grey;
    } else if (approvalStatus == 'rejected') {
      statusText = 'Rejected';
      statusColor = Colors.red;
    }

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      photoUrl.isEmpty ? null : NetworkImage(photoUrl),
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.delivery_dining, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'Delivery Person' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (phone.isNotEmpty) Text(phone),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${doc.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusText),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            detailRow('Vehicle Type', vehicleType),
            detailRow('Vehicle Number', vehicleNumber),
            detailRow('Licence Number', licenceNumber),
            detailRow('Licence Expiry', licenceExpiry),
            detailRow('Licence Verified', licenceVerified ? 'Yes' : 'No'),
            detailRow('Approved', approved ? 'Yes' : 'No'),
            detailRow('Active', active ? 'Yes' : 'No'),
            detailRow('Online', online ? 'Yes' : 'No'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                imageCard(
                  context,
                  title: 'Profile Photo',
                  url: photoUrl,
                  icon: Icons.person_outline,
                ),
                imageCard(
                  context,
                  title: 'Licence Front',
                  url: licenceFront,
                  icon: Icons.badge_outlined,
                ),
                imageCard(
                  context,
                  title: 'Licence Back',
                  url: licenceBack,
                  icon: Icons.badge_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: licenceVerified ? null : onVerifyLicence,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(
                    licenceVerified ? 'Licence Verified' : 'Verify Licence',
                  ),
                ),
                FilledButton.icon(
                  onPressed: approved ? null : onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(approved ? 'Approved' : 'Approve'),
                ),
                if (!approved)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                if (approved && active)
                  OutlinedButton.icon(
                    onPressed: onDeactivate,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Deactivate'),
                  ),
                if (approved && !active)
                  OutlinedButton.icon(
                    onPressed: onReactivate,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Reactivate'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
