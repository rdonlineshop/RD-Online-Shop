import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SellerReviewsPage extends StatelessWidget {
  const SellerReviewsPage({super.key});

  double _ratingValue(Map<String, dynamic> data) {
    final dynamic value = data['rating'];

    if (value is num) {
      return value.toDouble().clamp(0.0, 5.0).toDouble();
    }

    final double? parsed = double.tryParse(value?.toString() ?? '');
    return (parsed ?? 0.0).clamp(0.0, 5.0).toDouble();
  }

  String _firstText(
    Map<String, dynamic> data,
    List<String> fields,
    String fallback,
  ) {
    for (final String field in fields) {
      final String value = data[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String _reviewText(Map<String, dynamic> data) {
    return _firstText(
      data,
      const <String>['comment', 'review', 'reviewText', 'message'],
      'No written comment.',
    );
  }

  String _customerName(Map<String, dynamic> data) {
    return _firstText(
      data,
      const <String>['customerName', 'userName', 'name', 'buyerName'],
      'Customer',
    );
  }

  String _productName(Map<String, dynamic> data) {
    return _firstText(
      data,
      const <String>['productName', 'itemName', 'product'],
      'Shop Review',
    );
  }

  DateTime? _createdAt(Map<String, dynamic> data) {
    final dynamic value = data['createdAt'] ?? data['reviewDate'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 30, color: Colors.amber.shade700),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _ratingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final double starNumber = index + 1.0;
        final IconData icon;

        if (rating >= starNumber) {
          icon = Icons.star_rounded;
        } else if (rating >= starNumber - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }

        return Icon(
          icon,
          size: 20,
          color: Colors.amber.shade700,
        );
      }),
    );
  }

  Widget _reviewCard(Map<String, dynamic> data) {
    final double rating = _ratingValue(data);
    final String customer = _customerName(data);
    final String product = _productName(data);
    final String comment = _reviewText(data);
    final String date = _formatDate(_createdAt(data));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Colors.amber.shade50,
                  child: Icon(
                    Icons.person,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        customer,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _ratingStars(rating),
                const SizedBox(width: 8),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              comment,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reviews & Ratings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Seller login required.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('sellerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load reviews:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  snapshot.data!.docs,
                );

                docs.sort((
                  QueryDocumentSnapshot<Map<String, dynamic>> a,
                  QueryDocumentSnapshot<Map<String, dynamic>> b,
                ) {
                  final DateTime? aDate = _createdAt(a.data());
                  final DateTime? bDate = _createdAt(b.data());

                  if (aDate == null && bDate == null) {
                    return 0;
                  }
                  if (aDate == null) {
                    return 1;
                  }
                  if (bDate == null) {
                    return -1;
                  }
                  return bDate.compareTo(aDate);
                });

                final int totalReviews = docs.length;
                final double totalRating = docs.fold<double>(
                  0.0,
                  (
                    double total,
                    QueryDocumentSnapshot<Map<String, dynamic>> doc,
                  ) =>
                      total + _ratingValue(doc.data()),
                );
                final double averageRating = totalReviews == 0
                    ? 0.0
                    : totalRating / totalReviews;
                final int fiveStarReviews = docs.where((
                  QueryDocumentSnapshot<Map<String, dynamic>> doc,
                ) {
                  return _ratingValue(doc.data()) >= 4.5;
                }).length;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        LayoutBuilder(
                          builder: (
                            BuildContext context,
                            BoxConstraints constraints,
                          ) {
                            final bool wide = constraints.maxWidth >= 650;
                            final List<Widget> cards = <Widget>[
                              _summaryCard(
                                icon: Icons.star_rounded,
                                title: 'Average Rating',
                                value: averageRating.toStringAsFixed(1),
                              ),
                              _summaryCard(
                                icon: Icons.rate_review_outlined,
                                title: 'Total Reviews',
                                value: totalReviews.toString(),
                              ),
                              _summaryCard(
                                icon: Icons.workspace_premium_outlined,
                                title: '5 Star Reviews',
                                value: fiveStarReviews.toString(),
                              ),
                            ];

                            if (!wide) {
                              return Column(
                                children: cards
                                    .map(
                                      (Widget card) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: card,
                                      ),
                                    )
                                    .toList(),
                              );
                            }

                            return Row(
                              children: <Widget>[
                                Expanded(child: cards[0]),
                                const SizedBox(width: 10),
                                Expanded(child: cards[1]),
                                const SizedBox(width: 10),
                                Expanded(child: cards[2]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Customer Reviews',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (docs.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: const Column(
                              children: <Widget>[
                                Icon(
                                  Icons.reviews_outlined,
                                  size: 55,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No reviews yet.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Customer reviews for this seller will appear here.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...docs.map(
                            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                                _reviewCard(doc.data()),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
