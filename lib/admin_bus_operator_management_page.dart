import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminBusOperatorManagementPage
    extends StatelessWidget {
  const AdminBusOperatorManagementPage({super.key});

  Future<void> _update(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref, {
    required bool isApproved,
    required bool isActive,
  }) async {
    try {
      final FirebaseFirestore firestore =
          FirebaseFirestore.instance;
      final WriteBatch batch = firestore.batch();

      batch.update(
        ref,
        <String, dynamic>{
          'isApproved': isApproved,
          'isActive': isActive,
          'status': isApproved
              ? (isActive ? 'active' : 'inactive')
              : 'pending',
          // Admin approval/activation is account permission only.
          // Service always returns OFFLINE after an Admin status change.
          'isOnline': false,
          'serviceStatus': 'offline',
          'serviceStatusUpdatedAt':
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        firestore
            .collection('bus_operator_presence')
            .doc(ref.id),
        <String, dynamic>{
          'operatorId': ref.id,
          'isOnline': false,
          'serviceStatus': 'offline',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bus Operator status updated.',
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
            'Could not update operator: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Operators',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('bus_operators')
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
                  'Could not load Bus Operators.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              docs = <QueryDocumentSnapshot<
                  Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ];

          docs.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  a,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  b,
            ) {
              final String an =
                  a.data()['companyName']
                          ?.toString()
                          .toLowerCase() ??
                      '';
              final String bn =
                  b.data()['companyName']
                          ?.toString()
                          .toLowerCase() ??
                      '';
              return an.compareTo(bn);
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No Bus Operator registrations yet.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  doc = docs[index];
              final Map<String, dynamic> data =
                  doc.data();

              final bool approved =
                  data['isApproved'] == true;
              final bool active =
                  data['isActive'] == true;
              final bool online =
                  data['isOnline'] == true;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          CircleAvatar(
                            child: Icon(
                              approved && active
                                  ? Icons.verified_rounded
                                  : Icons
                                      .directions_bus_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  data['companyName']
                                          ?.toString() ??
                                      'Bus Operator',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  data['ownerName']
                                          ?.toString() ??
                                      '',
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: <Widget>[
                              Chip(
                                label: Text(
                                  approved
                                      ? (active
                                          ? 'ACTIVE'
                                          : 'INACTIVE')
                                      : 'PENDING',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (approved && active)
                                Chip(
                                  avatar: Icon(
                                    online
                                        ? Icons.wifi_rounded
                                        : Icons
                                            .wifi_off_rounded,
                                    size: 16,
                                    color: online
                                        ? Colors.blue
                                        : Colors.grey,
                                  ),
                                  label: Text(
                                    online
                                        ? 'ONLINE'
                                        : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w900,
                                      color: online
                                          ? Colors.blue
                                          : Colors.grey
                                              .shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      Text(
                        'Phone: ${data['phone'] ?? ''}',
                      ),
                      Text(
                        'Email: ${data['email'] ?? ''}',
                      ),
                      Text(
                        'Address: ${data['address'] ?? ''}',
                      ),
                      Text(
                        'Registration/PAN: '
                        '${data['registrationNumber'] ?? ''}',
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        'Operator ID: ${data['operatorId'] ?? doc.id}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (!approved)
                            FilledButton.icon(
                              onPressed: () =>
                                  _update(
                                context,
                                doc.reference,
                                isApproved: true,
                                isActive: true,
                              ),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                              ),
                              label: const Text(
                                'Approve & Activate',
                              ),
                            ),
                          if (approved && active)
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _update(
                                context,
                                doc.reference,
                                isApproved: true,
                                isActive: false,
                              ),
                              icon: const Icon(
                                Icons.pause_circle_outline_rounded,
                              ),
                              label:
                                  const Text('Deactivate'),
                            ),
                          if (approved && !active)
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _update(
                                context,
                                doc.reference,
                                isApproved: true,
                                isActive: true,
                              ),
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                              ),
                              label:
                                  const Text('Reactivate'),
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
