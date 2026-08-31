import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRideDriverManagementPage
    extends StatelessWidget {
  const AdminRideDriverManagementPage({
    super.key,
  });

  CollectionReference<Map<String, dynamic>>
      get _rideDrivers =>
          FirebaseFirestore.instance
              .collection('ride_drivers');

  Future<void> _updateDriver(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> values,
    String successMessage,
  ) async {
    try {
      await ref.update(
        <String, dynamic>{
          ...values,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update Ride Driver: $error',
          ),
        ),
      );
    }
  }

  Future<void> _verifyLicence(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _updateDriver(
      context,
      ref,
      <String, dynamic>{
        'drivingLicenseVerified': true,
        'drivingLicenseVerifiedAt':
            FieldValue.serverTimestamp(),
      },
      'Driving licence verified.',
    );
  }

  Future<void> _approveDriver(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _updateDriver(
      context,
      ref,
      <String, dynamic>{
        'isApproved': true,
        'isActive': true,
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      },
      'Ride Driver approved and activated.',
    );
  }

  Future<void> _suspendDriver(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _updateDriver(
      context,
      ref,
      <String, dynamic>{
        'isActive': false,
        'approvalStatus': 'suspended',
      },
      'Ride Driver suspended.',
    );
  }

  Future<void> _rejectDriver(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
              context: context,
              builder: (
                BuildContext dialogContext,
              ) {
                return AlertDialog(
                  title: const Text(
                    'Reject Ride Driver?',
                  ),
                  content: const Text(
                    'The driver account will stay in Firestore, but it will not be allowed to go online or receive ride requests.',
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
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      },
                      child: const Text('Reject'),
                    ),
                  ],
                );
              },
            ) ??
            false;

    if (!confirmed || !context.mounted) {
      return;
    }

    await _updateDriver(
      context,
      ref,
      <String, dynamic>{
        'isApproved': false,
        'isActive': false,
        'approvalStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      },
      'Ride Driver rejected.',
    );
  }

  void _showImage(
    BuildContext context,
    String title,
    String url,
  ) {
    final String cleanUrl = url.trim();

    showDialog<void>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 700,
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
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (cleanUrl.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'No image uploaded.',
                      ),
                    )
                  else
                    Flexible(
                      child: InteractiveViewer(
                        child: Image.network(
                          cleanUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace?
                                stackTrace,
                          ) {
                            return const Padding(
                              padding:
                                  EdgeInsets.all(
                                28,
                              ),
                              child: Text(
                                'Could not load image.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride Driver Management',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _rideDrivers.snapshots(),
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
              return _MessageView(
                icon:
                    Icons.error_outline_rounded,
                title:
                    'Could not load Ride Drivers',
                message:
                    snapshot.error.toString(),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                drivers =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[];

            drivers.sort(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    first,
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    second,
              ) {
                final dynamic firstRaw =
                    first.data()['createdAt'];
                final dynamic secondRaw =
                    second.data()['createdAt'];

                final int firstTime =
                    firstRaw is Timestamp
                        ? firstRaw
                            .millisecondsSinceEpoch
                        : 0;
                final int secondTime =
                    secondRaw is Timestamp
                        ? secondRaw
                            .millisecondsSinceEpoch
                        : 0;

                return secondTime
                    .compareTo(firstTime);
              },
            );

            if (drivers.isEmpty) {
              return const _MessageView(
                icon:
                    Icons.drive_eta_rounded,
                title:
                    'No Ride Drivers Yet',
                message:
                    'New Ride Driver registrations will appear here.',
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 900,
                ),
                child: ListView.separated(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  itemCount: drivers.length,
                  separatorBuilder: (
                    BuildContext context,
                    int index,
                  ) =>
                      const SizedBox(
                    height: 12,
                  ),
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>
                        doc = drivers[index];

                    return _DriverCard(
                      doc: doc,
                      onVerifyLicence: () =>
                          _verifyLicence(
                        context,
                        doc.reference,
                      ),
                      onApprove: () =>
                          _approveDriver(
                        context,
                        doc.reference,
                      ),
                      onSuspend: () =>
                          _suspendDriver(
                        context,
                        doc.reference,
                      ),
                      onReject: () =>
                          _rejectDriver(
                        context,
                        doc.reference,
                      ),
                      onShowFront:
                          (String url) =>
                              _showImage(
                        context,
                        'Driving Licence Front',
                        url,
                      ),
                      onShowBack:
                          (String url) =>
                              _showImage(
                        context,
                        'Driving Licence Back',
                        url,
                      ),
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
    required this.onReject,
    required this.onShowFront,
    required this.onShowBack,
  });

  final QueryDocumentSnapshot<
      Map<String, dynamic>> doc;

  final VoidCallback onVerifyLicence;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;
  final VoidCallback onReject;

  final ValueChanged<String> onShowFront;
  final ValueChanged<String> onShowBack;

  String _value(
    Map<String, dynamic> data,
    String key,
  ) {
    return data[key]?.toString().trim() ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        doc.data();

    final String name =
        _value(data, 'name');
    final String phone =
        _value(data, 'phone');
    final String email =
        _value(data, 'email');
    final String vehicleType =
        _value(data, 'vehicleType');
    final String vehicleNumber =
        _value(data, 'vehicleNumber');
    final String licenceNumber =
        _value(
      data,
      'drivingLicenseNumber',
    );
    final String licenceExpiry =
        _value(
      data,
      'drivingLicenseExpiry',
    );
    final String licenceFront =
        _value(
      data,
      'drivingLicenseFrontUrl',
    );
    final String licenceBack =
        _value(
      data,
      'drivingLicenseBackUrl',
    );

    final bool licenceVerified =
        data['drivingLicenseVerified'] ==
            true;
    final bool approved =
        data['isApproved'] == true;
    final bool active =
        data['isActive'] == true;
    final bool online =
        data['isOnline'] == true;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(
                  radius: 29,
                  child: Icon(
                    Icons
                        .drive_eta_rounded,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      Text(
                        name.isEmpty
                            ? 'Ride Driver'
                            : name,
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          vehicleType,
                          vehicleNumber,
                        ]
                            .where(
                              (
                                String item,
                              ) =>
                                  item
                                      .isNotEmpty,
                            )
                            .join(' • '),
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  text: active
                      ? 'Active'
                      : approved
                          ? 'Approved'
                          : 'Pending',
                  positive: active,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Phone',
              value: phone,
            ),
            _InfoRow(
              label: 'Email',
              value: email,
            ),
            _InfoRow(
              label:
                  'Licence Number',
              value: licenceNumber,
            ),
            _InfoRow(
              label:
                  'Licence Expiry',
              value: licenceExpiry,
            ),
            _InfoRow(
              label:
                  'Licence Verified',
              value: licenceVerified
                  ? 'Yes'
                  : 'No',
            ),
            _InfoRow(
              label: 'Online',
              value:
                  online ? 'Yes' : 'No',
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        licenceFront
                                .isEmpty
                            ? null
                            : () =>
                                onShowFront(
                                  licenceFront,
                                ),
                    icon: const Icon(
                      Icons
                          .credit_card_rounded,
                    ),
                    label: const Text(
                      'Licence Front',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        licenceBack.isEmpty
                            ? null
                            : () =>
                                onShowBack(
                                  licenceBack,
                                ),
                    icon: const Icon(
                      Icons
                          .credit_card_rounded,
                    ),
                    label: const Text(
                      'Licence Back',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!licenceVerified)
              FilledButton.icon(
                onPressed:
                    onVerifyLicence,
                icon: const Icon(
                  Icons.verified_rounded,
                ),
                label: const Text(
                  'Verify Driving Licence',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            if (licenceVerified &&
                !approved) ...<Widget>[
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(
                  Icons
                      .check_circle_rounded,
                ),
                label: const Text(
                  'Approve & Activate Driver',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
            if (active) ...<Widget>[
              OutlinedButton.icon(
                onPressed: onSuspend,
                icon: const Icon(
                  Icons.block_rounded,
                ),
                label: const Text(
                  'Suspend Driver',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
            if (!approved) ...<Widget>[
              TextButton.icon(
                onPressed: onReject,
                icon: const Icon(
                  Icons.close_rounded,
                ),
                label: const Text(
                  'Reject Driver',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color:
                    Colors.grey.shade700,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.positive,
  });

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green
                .withValues(alpha: 0.12)
            : Colors.orange
                .withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: positive
              ? Colors.green
              : Colors.orange,
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
        padding:
            const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 48,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  title,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
