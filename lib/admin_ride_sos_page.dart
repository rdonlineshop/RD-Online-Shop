import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminRideSosPage extends StatelessWidget {
  const AdminRideSosPage({super.key});

  CollectionReference<Map<String, dynamic>> get _alerts =>
      FirebaseFirestore.instance.collection('ride_sos_alerts');

  String _text(dynamic value, {String fallback = 'Not available'}) {
    final String clean = value?.toString().trim() ?? '';
    return clean.isEmpty ? fallback : clean;
  }

  String _timeText(dynamic value) {
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

  Future<void> _resolveAlert(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> alert,
  ) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Mark SOS Resolved?'),
            content: const Text(
              'Use this only after Admin has checked the emergency and completed the required follow-up.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not Yet'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Resolve'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await alert.reference.update(
        <String, dynamic>{
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS marked as resolved.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve SOS: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride SOS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _alerts.snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _message(
                icon: Icons.error_outline_rounded,
                title: 'Could not load Ride SOS',
                message: snapshot.error.toString(),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts =
                snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            alerts.sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> first,
                QueryDocumentSnapshot<Map<String, dynamic>> second,
              ) {
                final Map<String, dynamic> firstData = first.data();
                final Map<String, dynamic> secondData = second.data();

                final String firstStatus =
                    firstData['status']?.toString().trim().toLowerCase() ?? '';
                final String secondStatus =
                    secondData['status']?.toString().trim().toLowerCase() ?? '';

                final int firstPriority = firstStatus == 'active' ? 0 : 1;
                final int secondPriority = secondStatus == 'active' ? 0 : 1;

                if (firstPriority != secondPriority) {
                  return firstPriority.compareTo(secondPriority);
                }

                final Timestamp? firstTime =
                    firstData['createdAt'] is Timestamp
                        ? firstData['createdAt'] as Timestamp
                        : null;
                final Timestamp? secondTime =
                    secondData['createdAt'] is Timestamp
                        ? secondData['createdAt'] as Timestamp
                        : null;

                return (secondTime?.millisecondsSinceEpoch ?? 0).compareTo(
                  firstTime?.millisecondsSinceEpoch ?? 0,
                );
              },
            );

            if (alerts.isEmpty) {
              return _message(
                icon: Icons.health_and_safety_outlined,
                title: 'No Ride SOS alerts',
                message:
                    'Active emergency alerts from customers or drivers will appear here.',
              );
            }

            final int activeCount = alerts
                .where(
                  (QueryDocumentSnapshot<Map<String, dynamic>> alert) =>
                      alert.data()['status']
                          ?.toString()
                          .trim()
                          .toLowerCase() ==
                      'active',
                )
                .length;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Card(
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.12),
                              child: const Icon(
                                Icons.sos_rounded,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Emergency Overview',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$activeCount active • ${alerts.length} total',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...alerts.map(
                      (QueryDocumentSnapshot<Map<String, dynamic>> alert) =>
                          Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _alertCard(context, alert),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _alertCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> alert,
  ) {
    final Map<String, dynamic> data = alert.data();

    final String status =
        data['status']?.toString().trim().toLowerCase() ?? 'active';
    final bool active = status == 'active';

    final String triggeredBy = _text(data['triggeredBy']);
    final String reason = _text(data['reason']);
    final String rideRequestId = _text(data['rideRequestId']);
    final String customerName = _text(data['customerName']);
    final String customerPhone = _text(data['customerPhone']);
    final String driverName = _text(data['driverName']);
    final String driverPhone = _text(data['driverPhone']);
    final String locationText = _text(data['locationAddress']);

    final double? latitude = data['latitude'] is num
        ? (data['latitude'] as num).toDouble()
        : double.tryParse(data['latitude']?.toString() ?? '');
    final double? longitude = data['longitude'] is num
        ? (data['longitude'] as num).toDouble()
        : double.tryParse(data['longitude']?.toString() ?? '');

    return Card(
      elevation: active ? 2.5 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: (active ? Colors.red : Colors.green)
                      .withValues(alpha: 0.12),
                  child: Icon(
                    active
                        ? Icons.warning_amber_rounded
                        : Icons.task_alt_rounded,
                    color: active ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        active ? 'ACTIVE SOS' : 'RESOLVED SOS',
                        style: TextStyle(
                          color: active ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Triggered by: $triggeredBy',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeText(data['createdAt']),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _row(Icons.report_problem_outlined, 'Reason', reason),
            const Divider(height: 22),
            _row(Icons.confirmation_number_outlined, 'Ride ID', rideRequestId),
            const Divider(height: 22),
            _row(
              Icons.person_outline_rounded,
              'Customer',
              '$customerName • $customerPhone',
            ),
            const Divider(height: 22),
            _row(
              Icons.drive_eta_rounded,
              'Driver',
              '$driverName • $driverPhone',
            ),
            const Divider(height: 22),
            _row(
              Icons.location_on_outlined,
              'Location',
              locationText,
            ),
            if (latitude != null && longitude != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ],
            if (!active) ...<Widget>[
              const Divider(height: 22),
              _row(
                Icons.schedule_rounded,
                'Resolved At',
                _timeText(data['resolvedAt']),
              ),
            ],
            if (active) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _resolveAlert(context, alert),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text(
                  'Mark Resolved',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: const Color(0xFF1565C0)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 72, color: Colors.grey),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
