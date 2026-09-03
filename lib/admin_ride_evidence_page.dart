import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ride_chat_page.dart';
import 'ride_voice_message_player.dart';

class AdminRideEvidencePage extends StatefulWidget {
  const AdminRideEvidencePage({super.key});

  @override
  State<AdminRideEvidencePage> createState() =>
      _AdminRideEvidencePageState();
}

class _AdminRideEvidencePageState extends State<AdminRideEvidencePage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Evidence',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Security archive: customer/driver cannot edit, unsend or delete sent text/voice messages. Completed ride chat is hidden from them and remains available to Admin during the evidence retention period.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (String value) {
                          setState(() {
                            _search = value.trim().toLowerCase();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search Ride ID, customer or driver...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ride_requests')
                        .orderBy('updatedAt', descending: true)
                        .limit(200)
                        .snapshots(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                          snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Could not load ride evidence: ${snapshot.error}',
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

                      final DateTime cutoff = DateTime.now().subtract(
                        const Duration(days: 90),
                      );

                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          rides = snapshot.data!.docs.where((document) {
                        final Map<String, dynamic> data = document.data();
                        final DateTime time = _rideTime(data);

                        if (time.isBefore(cutoff)) {
                          return false;
                        }

                        if (_search.isEmpty) {
                          return true;
                        }

                        final String searchable = <String>[
                          document.id,
                          data['rideRequestId']?.toString() ?? '',
                          data['customerName']?.toString() ?? '',
                          data['customerPhone']?.toString() ?? '',
                          data['driverName']?.toString() ?? '',
                          data['driverPhone']?.toString() ?? '',
                          data['vehicleNumber']?.toString() ?? '',
                        ].join(' ').toLowerCase();

                        return searchable.contains(_search);
                      }).toList();

                      if (rides.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No ride evidence found in the current 90-day window.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: rides.length,
                        itemBuilder: (BuildContext context, int index) {
                          final QueryDocumentSnapshot<Map<String, dynamic>>
                              ride = rides[index];
                          final Map<String, dynamic> data = ride.data();
                          final String status = data['status']
                                  ?.toString()
                                  .trim()
                                  .toUpperCase() ??
                              'UNKNOWN';
                          final String customer =
                              _displayName(data['customerName'], 'Customer');
                          final String driver =
                              _displayName(data['driverName'], 'Ride Driver');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.security_rounded),
                              ),
                              title: Text(
                                '$customer ↔ $driver',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'Ride ID: ${ride.id}\n'
                                '$status • ${_dateText(_rideTime(data))}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                              ),
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _AdminRideEvidenceDetailPage(
                                      rideId: ride.id,
                                      rideData: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminRideEvidenceDetailPage extends StatelessWidget {
  const _AdminRideEvidenceDetailPage({
    required this.rideId,
    required this.rideData,
  });

  final String rideId;
  final Map<String, dynamic> rideData;

  @override
  Widget build(BuildContext context) {
    final String customer =
        _displayName(rideData['customerName'], 'Customer');
    final String driver =
        _displayName(rideData['driverName'], 'Ride Driver');
    final String status =
        rideData['status']?.toString().trim().toLowerCase() ?? '';
    final bool active = status == 'accepted' || status == 'in_progress';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Chat Evidence',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            '$customer ↔ $driver',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text('Ride ID: $rideId'),
                          Text(
                            'Status: ${status.isEmpty ? 'UNKNOWN' : status.toUpperCase()}',
                          ),
                          if (rideData['tripStartOtpVerifiedAt'] is Timestamp)
                            Text(
                              'Trip OTP verified: '
                              '${_dateText((rideData['tripStartOtpVerifiedAt'] as Timestamp).toDate().toLocal())}',
                            ),
                          const SizedBox(height: 7),
                          const Text(
                            'Evidence is append-only. Customer and driver cannot edit, unsend or delete original text/voice messages.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (active) ...<Widget>[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => RideChatPage(
                                      rideRequestId: rideId,
                                      senderRole: 'admin',
                                      senderName: 'RD Admin',
                                      otherPartyName: '$customer ↔ $driver',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_rounded),
                              label: const Text('Open Admin Chat'),
                            ),
                          ] else ...<Widget>[
                            const SizedBox(height: 8),
                            const Text(
                              'Ride completed/closed: Admin can review evidence but cannot send a new message.',
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ride_requests')
                        .doc(rideId)
                        .collection('messages')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                          snapshot,
                    ) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Could not load evidence messages: '
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

                      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                          messages = snapshot.data!.docs;

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'No chat messages were recorded for this ride.',
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final QueryDocumentSnapshot<Map<String, dynamic>>
                              document = messages[index];
                          final Map<String, dynamic> data = document.data();
                          final String senderRole = data['senderRole']
                                  ?.toString()
                                  .trim()
                                  .toLowerCase() ??
                              '';
                          final bool adminMessage = senderRole == 'admin';
                          final String sender = _displayName(
                            data['senderName'],
                            senderRole.isEmpty ? 'Sender' : senderRole,
                          );
                          final String text =
                              data['text']?.toString().trim() ?? '';
                          final String type = data['messageType']
                                  ?.toString()
                                  .trim()
                                  .toLowerCase() ??
                              'text';
                          final int voiceDuration =
                              data['voiceDurationSeconds'] is num
                                  ? (data['voiceDurationSeconds'] as num).round()
                                  : 0;
                          final DateTime? time = data['createdAt'] is Timestamp
                              ? (data['createdAt'] as Timestamp)
                                  .toDate()
                                  .toLocal()
                              : null;
                          final DateTime? expires =
                              data['evidenceExpiresAt'] is Timestamp
                                  ? (data['evidenceExpiresAt'] as Timestamp)
                                      .toDate()
                                      .toLocal()
                                  : null;

                          return Align(
                            alignment: adminMessage
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 620),
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: adminMessage
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.07),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '$sender • ${type.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (type == 'voice')
                                    RideVoiceMessagePlayer(
                                      rideRequestId: rideId,
                                      messageId: document.id,
                                      durationSeconds: voiceDuration,
                                      compact: true,
                                    )
                                  else
                                    Text(
                                      text.isEmpty
                                          ? '[No text content]'
                                          : text,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  if (time != null) ...<Widget>[
                                    const SizedBox(height: 5),
                                    Text(
                                      _dateText(time),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                  if (expires != null) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Auto-delete after: ${_dateText(expires)}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
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
          ),
        ),
      ),
    );
  }
}

String _displayName(dynamic value, String fallback) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime _rideTime(Map<String, dynamic> data) {
  for (final String key in <String>[
    'tripCompletedAt',
    'cancelledAt',
    'rejectedAt',
    'updatedAt',
    'createdAt',
  ]) {
    final dynamic value = data[key];
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _dateText(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
