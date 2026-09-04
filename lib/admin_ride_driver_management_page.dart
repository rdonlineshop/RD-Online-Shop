import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ride_driver_agreement_page.dart';
import 'widgets/ride_driver_rating_summary.dart';

class AdminRideDriverManagementPage extends StatelessWidget {
  const AdminRideDriverManagementPage({super.key});

  CollectionReference<Map<String, dynamic>> get _rideDrivers =>
      FirebaseFirestore.instance.collection('ride_drivers');

  CollectionReference<Map<String, dynamic>> get _accountHistory =>
      FirebaseFirestore.instance.collection('ride_driver_account_history');

  String get _adminUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(String currency, double amount) {
    final String clean = currency.trim().isEmpty ? 'Rs.' : currency.trim();
    return '$clean ${amount.toStringAsFixed(2)}';
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
        SnackBar(content: Text('Could not update Ride Driver: $error')),
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
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ),
      'Driving licence verified.',
    );
  }

  Future<void> _approveDriver(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> driver = doc.data();
    final bool agreementAccepted =
        driver['driverAgreementAccepted'] == true;
    final bool reacceptRequired =
        driver['driverAgreementReacceptRequired'] == true;

    if (!agreementAccepted || reacceptRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reacceptRequired
                ? 'Driver must accept the latest RD Ride Driver Agreement before approval.'
                : 'Driver Agreement acceptance is required before approval.',
          ),
        ),
      );
      return;
    }

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.update(
      doc.reference,
      <String, dynamic>{
        'isApproved': true,
        'isActive': true,
        'isOnline': false,
        'approvalStatus': 'approved',
        'suspensionStatus': 'active',
        'reactivationStatus': 'not_required',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final DocumentReference<Map<String, dynamic>> logRef = _accountHistory.doc();
    batch.set(
      logRef,
      <String, dynamic>{
        'eventId': logRef.id,
        'driverId': doc.id,
        'action': 'approved',
        'adminUid': _adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await _showResult(
      context,
      batch.commit,
      'Ride Driver approved and activated.',
    );
  }

  Future<void> _suspendDriver(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final String currentRideId =
        data['currentRideRequestId']?.toString().trim() ?? '';

    if (currentRideId.isNotEmpty && currentRideId != 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This driver has an active ride. Complete the active ride before a payment suspension.',
          ),
        ),
      );
      return;
    }

    final _SuspensionInput? input = await showDialog<_SuspensionInput>(
      context: context,
      builder: (_) => const _SuspendDriverDialog(),
    );

    if (input == null || !context.mounted) {
      return;
    }

    final double totalDue = input.commissionDue + input.fine;
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(
      doc.reference,
      <String, dynamic>{
        // Approval/licence stay valid. Suspension only pauses ride access.
        'isActive': false,
        'isOnline': false,
        'approvalStatus': 'suspended',
        'suspensionStatus': 'suspended',
        'suspensionReason': input.reason,
        'suspensionCurrency': input.currency,
        'outstandingRdCommission': input.commissionDue,
        'suspensionFine': input.fine,
        'suspensionTotalDue': totalDue,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspendedByUid': _adminUid,
        'reactivationStatus': 'not_requested',
        'reactivationRequestedAt': FieldValue.delete(),
        'reactivationPaymentMethod': FieldValue.delete(),
        'reactivationPaymentAmount': FieldValue.delete(),
        'reactivationPaymentReference': FieldValue.delete(),
        'reactivationPaymentNote': FieldValue.delete(),
        'reactivationReviewedAt': FieldValue.delete(),
        'reactivationReviewedByUid': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final DocumentReference<Map<String, dynamic>> logRef = _accountHistory.doc();
    batch.set(
      logRef,
      <String, dynamic>{
        'eventId': logRef.id,
        'driverId': doc.id,
        'action': 'suspended',
        'reason': input.reason,
        'currency': input.currency,
        'outstandingRdCommission': input.commissionDue,
        'fine': input.fine,
        'totalDue': totalDue,
        'adminUid': _adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await _showResult(
      context,
      batch.commit,
      'Ride Driver suspended. Approval is preserved for later reactivation.',
    );
  }

  Future<void> _approveReactivation(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final Map<String, dynamic> data = doc.data();
    final String requestStatus =
        data['reactivationStatus']?.toString().trim().toLowerCase() ?? '';

    if (requestStatus != 'pending_admin_review') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending reactivation request.')),
      );
      return;
    }

    final String currency =
        data['suspensionCurrency']?.toString().trim().isNotEmpty == true
            ? data['suspensionCurrency'].toString().trim()
            : 'Rs.';
    final double totalDue = _number(data['suspensionTotalDue']);
    final double paid = _number(data['reactivationPaymentAmount']);
    final String method =
        data['reactivationPaymentMethod']?.toString().trim() ?? '';
    final String reference =
        data['reactivationPaymentReference']?.toString().trim() ?? '';

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Approve Reactivation?'),
              content: Text(
                'Amount due: ${_money(currency, totalDue)}\n'
                'Driver submitted: ${_money(currency, paid)}\n'
                'Method: ${method.isEmpty ? '-' : method}\n'
                'Reference: ${reference.isEmpty ? '-' : reference}\n\n'
                'Verify the payment before approving.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Approve Reactivation'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    final WriteBatch batch = FirebaseFirestore.instance.batch();
    batch.update(
      doc.reference,
      <String, dynamic>{
        'isActive': true,
        'isOnline': false,
        'approvalStatus': 'approved',
        'suspensionStatus': 'active',
        'reactivationStatus': 'approved',
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedByUid': _adminUid,
        'lastSuspensionResolvedAmount': totalDue,
        'lastReactivationPaymentAmount': paid,
        'lastReactivationPaymentMethod': method,
        'lastReactivationPaymentReference': reference,
        'outstandingRdCommission': 0.0,
        'suspensionFine': 0.0,
        'suspensionTotalDue': 0.0,
        'suspensionReason': '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    final DocumentReference<Map<String, dynamic>> logRef = _accountHistory.doc();
    batch.set(
      logRef,
      <String, dynamic>{
        'eventId': logRef.id,
        'driverId': doc.id,
        'action': 'reactivated_after_payment',
        'currency': currency,
        'amountDue': totalDue,
        'amountSubmitted': paid,
        'paymentMethod': method,
        'paymentReference': reference,
        'adminUid': _adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await _showResult(
      context,
      batch.commit,
      'Payment verified. Ride Driver reactivated.',
    );
  }

  Future<void> _rejectReactivation(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final String status =
        doc.data()['reactivationStatus']?.toString().trim().toLowerCase() ?? '';
    if (status != 'pending_admin_review') {
      return;
    }

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Reject Reactivation Request?'),
            content: const Text(
              'The driver will remain suspended and can submit corrected payment details again.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Reject Request'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    await _showResult(
      context,
      () async {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        batch.update(
          doc.reference,
          <String, dynamic>{
            'reactivationStatus': 'rejected',
            'reactivationReviewedAt': FieldValue.serverTimestamp(),
            'reactivationReviewedByUid': _adminUid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        final DocumentReference<Map<String, dynamic>> logRef =
            _accountHistory.doc();
        batch.set(
          logRef,
          <String, dynamic>{
            'eventId': logRef.id,
            'driverId': doc.id,
            'action': 'reactivation_rejected',
            'adminUid': _adminUid,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        await batch.commit();
      },
      'Reactivation request rejected. Driver remains suspended.',
    );
  }

  Future<void> _unsuspendWithoutPayment(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final String? reason = await showDialog<String>(
      context: context,
      builder: (_) => const _AdminOverrideDialog(),
    );

    if (reason == null || !context.mounted) {
      return;
    }

    final Map<String, dynamic> data = doc.data();
    final String currency =
        data['suspensionCurrency']?.toString().trim().isNotEmpty == true
            ? data['suspensionCurrency'].toString().trim()
            : 'Rs.';
    final double totalDue = _number(data['suspensionTotalDue']);

    await _showResult(
      context,
      () async {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        batch.update(
          doc.reference,
          <String, dynamic>{
            'isActive': true,
            'isOnline': false,
            'approvalStatus': 'approved',
            'suspensionStatus': 'active',
            'reactivationStatus': 'admin_override',
            'reactivatedAt': FieldValue.serverTimestamp(),
            'reactivatedByUid': _adminUid,
            'outstandingRdCommission': 0.0,
            'suspensionFine': 0.0,
            'suspensionTotalDue': 0.0,
            'suspensionReason': '',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
        final DocumentReference<Map<String, dynamic>> logRef =
            _accountHistory.doc();
        batch.set(
          logRef,
          <String, dynamic>{
            'eventId': logRef.id,
            'driverId': doc.id,
            'action': 'reactivated_admin_override',
            'reason': reason,
            'currency': currency,
            'waivedAmount': totalDue,
            'adminUid': _adminUid,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        await batch.commit();
      },
      'Ride Driver reactivated by Admin override.',
    );
  }

  Future<void> _rejectDriver(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Reject Ride Driver?'),
            content: const Text(
              'The driver account stays in Firestore, but cannot go online or receive rides until Admin approves it again.',
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
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) {
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
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ),
      'Ride Driver rejected.',
    );
  }

  void _showImage(BuildContext context, String title, String url) {
    final String cleanUrl = url.trim();
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
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
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (cleanUrl.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text('No image uploaded.'),
                  )
                else
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.network(
                        cleanUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('Could not load image.'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride Driver Management',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _rideDrivers.snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageView(
                icon: Icons.error_outline_rounded,
                title: 'Could not load Ride Drivers',
                message: snapshot.error.toString(),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> drivers =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            drivers.sort(
              (QueryDocumentSnapshot<Map<String, dynamic>> first,
                  QueryDocumentSnapshot<Map<String, dynamic>> second) {
                final dynamic firstRaw = first.data()['createdAt'];
                final dynamic secondRaw = second.data()['createdAt'];
                final int firstTime =
                    firstRaw is Timestamp ? firstRaw.millisecondsSinceEpoch : 0;
                final int secondTime =
                    secondRaw is Timestamp ? secondRaw.millisecondsSinceEpoch : 0;
                return secondTime.compareTo(firstTime);
              },
            );

            if (drivers.isEmpty) {
              return const _MessageView(
                icon: Icons.drive_eta_rounded,
                title: 'No Ride Drivers Yet',
                message: 'New Ride Driver registrations will appear here.',
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: drivers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                        drivers[index];
                    return _DriverCard(
                      doc: doc,
                      onVerifyLicence: () =>
                          _verifyLicence(context, doc.reference),
                      onApprove: () => _approveDriver(context, doc),
                      onSuspend: () => _suspendDriver(context, doc),
                      onApproveReactivation: () =>
                          _approveReactivation(context, doc),
                      onRejectReactivation: () =>
                          _rejectReactivation(context, doc),
                      onAdminOverride: () =>
                          _unsuspendWithoutPayment(context, doc),
                      onReject: () => _rejectDriver(context, doc),
                      onShowFront: (String url) =>
                          _showImage(context, 'Driving Licence Front', url),
                      onShowBack: (String url) =>
                          _showImage(context, 'Driving Licence Back', url),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.doc,
    required this.onVerifyLicence,
    required this.onApprove,
    required this.onSuspend,
    required this.onApproveReactivation,
    required this.onRejectReactivation,
    required this.onAdminOverride,
    required this.onReject,
    required this.onShowFront,
    required this.onShowBack,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onVerifyLicence;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;
  final VoidCallback onApproveReactivation;
  final VoidCallback onRejectReactivation;
  final VoidCallback onAdminOverride;
  final VoidCallback onReject;
  final ValueChanged<String> onShowFront;
  final ValueChanged<String> onShowBack;

  String _value(Map<String, dynamic> data, String key) =>
      data[key]?.toString().trim() ?? '';

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _money(String currency, double amount) {
    final String clean = currency.trim().isEmpty ? 'Rs.' : currency.trim();
    return '$clean ${amount.toStringAsFixed(2)}';
  }

  String _timestampText(dynamic value) {
    if (value is! Timestamp) {
      return 'Not recorded';
    }

    final DateTime time = value.toDate().toLocal();
    final String day = time.day.toString().padLeft(2, '0');
    final String month = time.month.toString().padLeft(2, '0');
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$day/$month/${time.year} $hour:$minute';
  }

  void _openAgreement(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideDriverAgreementPage(
          driverName: _value(data, 'name'),
          reviewOnly: true,
          acceptedName: _value(data, 'driverAgreementAcceptedName'),
          acceptedVersion: _value(data, 'driverAgreementVersion'),
          acceptedHash: _value(data, 'driverAgreementTextHash'),
          acceptedAtText: _timestampText(data['driverAgreementAcceptedAt']),
          agreementText: _value(data, 'driverAgreementTextSnapshot'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = doc.data();
    final String name = _value(data, 'name');
    final String phone = _value(data, 'phone');
    final String email = _value(data, 'email');
    final String vehicleType = _value(data, 'vehicleType');
    final String vehicleNumber = _value(data, 'vehicleNumber');
    final String licenceNumber = _value(data, 'drivingLicenseNumber');
    final String licenceExpiry = _value(data, 'drivingLicenseExpiry');
    final String licenceFront = _value(data, 'drivingLicenseFrontUrl');
    final String licenceBack = _value(data, 'drivingLicenseBackUrl');
    final bool licenceVerified = data['drivingLicenseVerified'] == true;
    final bool agreementAccepted = data['driverAgreementAccepted'] == true;
    final bool agreementReacceptRequired =
        data['driverAgreementReacceptRequired'] == true;
    final String agreementVersion = _value(data, 'driverAgreementVersion');
    final String agreementName =
        _value(data, 'driverAgreementAcceptedName');
    final String agreementHash = _value(data, 'driverAgreementTextHash');
    final String agreementAcceptedAt =
        _timestampText(data['driverAgreementAcceptedAt']);
    final bool approved = data['isApproved'] == true;
    final bool active = data['isActive'] == true;
    final bool online = data['isOnline'] == true;
    final String approvalStatus =
        _value(data, 'approvalStatus').toLowerCase();
    final bool suspended =
        approved && !active && approvalStatus == 'suspended';
    final String reactivationStatus =
        _value(data, 'reactivationStatus').toLowerCase();
    final String currency = _value(data, 'suspensionCurrency').isEmpty
        ? 'Rs.'
        : _value(data, 'suspensionCurrency');
    final double commissionDue = _number(data['outstandingRdCommission']);
    final double fine = _number(data['suspensionFine']);
    final double totalDue = _number(data['suspensionTotalDue']);
    final double submittedAmount = _number(data['reactivationPaymentAmount']);

    String chipText = 'Pending';
    Color chipColor = Colors.orange;
    if (suspended) {
      chipText = 'Suspended';
      chipColor = Colors.red;
    } else if (active) {
      chipText = 'Active';
      chipColor = Colors.green;
    } else if (approved) {
      chipText = 'Approved';
      chipColor = Colors.orange;
    } else if (approvalStatus == 'rejected') {
      chipText = 'Rejected';
      chipColor = Colors.red;
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
                const CircleAvatar(
                  radius: 29,
                  child: Icon(Icons.drive_eta_rounded, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'Ride Driver' : name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        <String>[vehicleType, vehicleNumber]
                            .where((String item) => item.isNotEmpty)
                            .join(' • '),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(text: chipText, color: chipColor),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Phone', value: phone),
            _InfoRow(label: 'Email', value: email),
            _InfoRow(label: 'Licence Number', value: licenceNumber),
            _InfoRow(label: 'Licence Expiry', value: licenceExpiry),
            _InfoRow(
              label: 'Licence Verified',
              value: licenceVerified ? 'Yes' : 'No',
            ),
            _InfoRow(label: 'Online', value: online ? 'Yes' : 'No'),
            const SizedBox(height: 12),
            RideDriverPrivateRatingSummary(
              driverId: doc.id,
              title: 'Customer Rating',
              showRecentReviews: true,
            ),
            const Divider(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Driver Agreement',
                    style: TextStyle(
                      color: agreementAccepted && !agreementReacceptRequired
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusChip(
                  text: agreementReacceptRequired
                      ? 'RE-ACCEPT REQUIRED'
                      : agreementAccepted
                          ? 'ACCEPTED'
                          : 'NOT RECORDED',
                  color: agreementAccepted && !agreementReacceptRequired
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Accepted Name',
              value: agreementName.isEmpty ? 'Not recorded' : agreementName,
            ),
            _InfoRow(
              label: 'Version',
              value: agreementVersion.isEmpty ? 'Not recorded' : agreementVersion,
            ),
            _InfoRow(label: 'Accepted At', value: agreementAcceptedAt),
            _InfoRow(
              label: 'Text Hash',
              value: agreementHash.isEmpty ? 'Not recorded' : agreementHash,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: agreementAccepted
                  ? () => _openAgreement(context, data)
                  : null,
              icon: const Icon(Icons.description_outlined),
              label: const Text('View Accepted Agreement'),
            ),
            if (!agreementAccepted && !approved)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Approval is blocked until the driver accepts the RD Ride Driver Agreement.',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (suspended) ...<Widget>[
              const Divider(height: 24),
              Text(
                'Suspension & Reactivation',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              _InfoRow(
                label: 'Reason',
                value: _value(data, 'suspensionReason'),
              ),
              _InfoRow(
                label: 'RD Commission Due',
                value: _money(currency, commissionDue),
              ),
              _InfoRow(label: 'Fine', value: _money(currency, fine)),
              _InfoRow(
                label: 'Total Due',
                value: _money(currency, totalDue),
              ),
              _InfoRow(
                label: 'Request Status',
                value: reactivationStatus.isEmpty
                    ? 'Not requested'
                    : reactivationStatus.replaceAll('_', ' '),
              ),
              if (reactivationStatus == 'pending_admin_review') ...<Widget>[
                _InfoRow(
                  label: 'Submitted',
                  value: _money(currency, submittedAmount),
                ),
                _InfoRow(
                  label: 'Pay Method',
                  value: _value(data, 'reactivationPaymentMethod'),
                ),
                _InfoRow(
                  label: 'Reference',
                  value: _value(data, 'reactivationPaymentReference'),
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        licenceFront.isEmpty ? null : () => onShowFront(licenceFront),
                    icon: const Icon(Icons.credit_card_rounded),
                    label: const Text('Licence Front'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        licenceBack.isEmpty ? null : () => onShowBack(licenceBack),
                    icon: const Icon(Icons.credit_card_rounded),
                    label: const Text('Licence Back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!licenceVerified)
              FilledButton.icon(
                onPressed: onVerifyLicence,
                icon: const Icon(Icons.verified_rounded),
                label: const Text(
                  'Verify Driving Licence',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            if (licenceVerified && !approved)
              FilledButton.icon(
                onPressed: agreementAccepted && !agreementReacceptRequired
                    ? onApprove
                    : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Approve & Activate Driver',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            if (active)
              OutlinedButton.icon(
                onPressed: onSuspend,
                icon: const Icon(Icons.block_rounded),
                label: const Text(
                  'Suspend Driver',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            if (suspended && reactivationStatus == 'pending_admin_review') ...<Widget>[
              FilledButton.icon(
                onPressed: onApproveReactivation,
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text(
                  'Approve Reactivation',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRejectReactivation,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject Request'),
              ),
            ],
            if (suspended)
              TextButton.icon(
                onPressed: onAdminOverride,
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Unsuspend Without Payment'),
              ),
            if (!approved)
              TextButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject Driver'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuspensionInput {
  const _SuspensionInput({
    required this.reason,
    required this.currency,
    required this.commissionDue,
    required this.fine,
  });

  final String reason;
  final String currency;
  final double commissionDue;
  final double fine;
}

class _SuspendDriverDialog extends StatefulWidget {
  const _SuspendDriverDialog();

  @override
  State<_SuspendDriverDialog> createState() => _SuspendDriverDialogState();
}

class _SuspendDriverDialogState extends State<_SuspendDriverDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reason =
      TextEditingController(text: 'Weekly RD commission unpaid');
  final TextEditingController _commission = TextEditingController(text: '0');
  final TextEditingController _fine = TextEditingController(text: '0');
  String _currency = 'Rs.';

  @override
  void dispose() {
    _reason.dispose();
    _commission.dispose();
    _fine.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final double total = _value(_commission) + _value(_fine);
    return AlertDialog(
      title: const Text('Suspend Ride Driver'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Approval stays valid. The driver will be forced offline and cannot receive new rides until Admin reactivates the account.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reason,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Suspension Reason',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter suspension reason'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>['Rs.', 'SAR', 'USD']
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commission,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Outstanding RD Commission',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (String? value) {
                    final double? amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || amount < 0
                        ? 'Enter a valid amount'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fine,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Late Fine',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (String? value) {
                    final double? amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || amount < 0
                        ? 'Enter a valid fine amount'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total Due: $_currency ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.pop(
              context,
              _SuspensionInput(
                reason: _reason.text.trim(),
                currency: _currency,
                commissionDue: _value(_commission),
                fine: _value(_fine),
              ),
            );
          },
          icon: const Icon(Icons.block_rounded),
          label: const Text('Suspend Driver'),
        ),
      ],
    );
  }
}

class _AdminOverrideDialog extends StatefulWidget {
  const _AdminOverrideDialog();

  @override
  State<_AdminOverrideDialog> createState() => _AdminOverrideDialogState();
}

class _AdminOverrideDialogState extends State<_AdminOverrideDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unsuspend Without Payment'),
      content: TextField(
        controller: _reason,
        maxLength: 200,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Admin override reason',
          hintText: 'Example: Suspended by mistake',
          counterText: '',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final String value = _reason.text.trim();
            if (value.isEmpty) {
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('Unsuspend'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
