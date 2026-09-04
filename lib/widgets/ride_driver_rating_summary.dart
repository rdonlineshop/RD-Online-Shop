import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Rating-only badge safe to show while a customer is choosing a driver.
/// Reads from the public-safe `ride_driver_ratings` collection, which contains
/// no customer identity and no review text.
class RideDriverPublicRatingBadge extends StatelessWidget {
  const RideDriverPublicRatingBadge({
    required this.driverId,
    this.showWhenEmpty = true,
    super.key,
  });

  final String driverId;
  final bool showWhenEmpty;

  int? _rating(dynamic value) {
    final int? parsed = value is num
        ? value.round()
        : int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 5) {
      return null;
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId = driverId.trim();
    if (cleanDriverId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_driver_ratings')
          .where('driverId', isEqualTo: cleanDriverId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final List<int> ratings = (snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _rating(doc.data()['rating']))
            .whereType<int>()
            .toList();

        if (ratings.isEmpty && !showWhenEmpty) {
          return const SizedBox.shrink();
        }

        final double average = ratings.isEmpty
            ? 0
            : ratings.reduce((int a, int b) => a + b) / ratings.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.star_rounded,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 3),
              Text(
                ratings.isEmpty
                    ? 'New driver'
                    : '${average.toStringAsFixed(1)} (${ratings.length})',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full rating summary for the assigned driver or Admin. It reads the source
/// ride documents, so review text remains visible only to the parties already
/// allowed to read those rides by Firestore rules.
class RideDriverPrivateRatingSummary extends StatelessWidget {
  const RideDriverPrivateRatingSummary({
    required this.driverId,
    this.title = 'Customer Rating',
    this.showRecentReviews = true,
    super.key,
  });

  final String driverId;
  final String title;
  final bool showRecentReviews;

  int? _rating(dynamic value) {
    final int? parsed = value is num
        ? value.round()
        : int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 5) {
      return null;
    }
    return parsed;
  }

  DateTime _ratedAt(Map<String, dynamic> data) {
    final dynamic value = data['driverRatedAt'];
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId = driverId.trim();
    if (cleanDriverId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('driverId', isEqualTo: cleanDriverId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.18),
              ),
            ),
            child: const Text(
              'Driver ratings are temporarily unavailable.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> ratedDocuments =
            (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                    _rating(doc.data()['driverRating']) != null)
                .toList();

        final List<Map<String, dynamic>> ratedRides = ratedDocuments
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.data())
            .toList();

        ratedRides.sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              _ratedAt(b).compareTo(_ratedAt(a)),
        );

        final List<int> ratings = ratedRides
            .map((Map<String, dynamic> data) => _rating(data['driverRating']))
            .whereType<int>()
            .toList();
        final double average = ratings.isEmpty
            ? 0
            : ratings.reduce((int a, int b) => a + b) / ratings.length;
        final List<Map<String, dynamic>> reviews = ratedRides
            .where((Map<String, dynamic> data) =>
                data['driverReview']?.toString().trim().isNotEmpty == true)
            .take(3)
            .toList();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in ratedDocuments)
                _RideDriverRatingPublicBackfill(
                  rideRequestId: doc.id,
                  driverId: cleanDriverId,
                  rating: _rating(doc.data()['driverRating'])!,
                ),
              Row(
                children: <Widget>[
                  const Icon(Icons.star_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    ratings.isEmpty
                        ? 'No ratings yet'
                        : '${average.toStringAsFixed(1)} / 5',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (ratings.isEmpty)
                const Text(
                  'This driver has not received a customer rating yet.',
                  style: TextStyle(color: Colors.blueGrey),
                )
              else ...<Widget>[
                Row(
                  children: <Widget>[
                    ...List<Widget>.generate(
                      5,
                      (int index) => Icon(
                        index < average.round()
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ratings.length} rating${ratings.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (showRecentReviews && reviews.isNotEmpty) ...<Widget>[
                  const Divider(height: 22),
                  const Text(
                    'Recent reviews',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  ...reviews.map(
                    (Map<String, dynamic> review) {
                      final int rating = _rating(review['driverRating']) ?? 0;
                      final String text =
                          review['driverReview']?.toString().trim() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '★ $rating',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RideDriverRatingPublicBackfill extends StatefulWidget {
  const _RideDriverRatingPublicBackfill({
    required this.rideRequestId,
    required this.driverId,
    required this.rating,
  });

  final String rideRequestId;
  final String driverId;
  final int rating;

  @override
  State<_RideDriverRatingPublicBackfill> createState() =>
      _RideDriverRatingPublicBackfillState();
}

class _RideDriverRatingPublicBackfillState
    extends State<_RideDriverRatingPublicBackfill> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    final String rideId = widget.rideRequestId.trim();
    final String cleanDriverId = widget.driverId.trim();
    if (rideId.isEmpty || cleanDriverId.isEmpty) {
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> ref =
          FirebaseFirestore.instance
              .collection('ride_driver_ratings')
              .doc(rideId);

      final DocumentSnapshot<Map<String, dynamic>> existing = await ref.get();
      if (existing.exists) {
        return;
      }

      await ref.set(
        <String, dynamic>{
          'rideRequestId': rideId,
          'driverId': cleanDriverId,
          'rating': widget.rating,
          'createdAt': FieldValue.serverTimestamp(),
          'ratingVersion': 1,
        },
      );
    } catch (_) {
      // Backfill is best-effort only. The source ride rating remains intact.
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

