import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SellerNotificationsPage extends StatefulWidget {
  const SellerNotificationsPage({super.key});

  @override
  State<SellerNotificationsPage> createState() =>
      _SellerNotificationsPageState();
}

class _SellerNotificationsPageState extends State<SellerNotificationsPage> {
  static const String _readPrefix = 'rd_read_seller_notifications_';

  User? _seller;
  Set<String> _readKeys = <String>{};
  bool _isLoading = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.isAnonymous) {
        throw StateError('Seller login required.');
      }

      final SharedPreferences prefs =
          await SharedPreferences.getInstance();
      final List<String> saved =
          prefs.getStringList('$_readPrefix${user.uid}') ?? <String>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _seller = user;
        _readKeys = saved.toSet();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveReadKeys(Set<String> keys) async {
    final User? seller = _seller;
    if (seller == null) {
      return;
    }

    final SharedPreferences prefs =
        await SharedPreferences.getInstance();

    final List<String> sorted = keys.toList()..sort();

    await prefs.setStringList(
      '$_readPrefix${seller.uid}',
      sorted,
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _broadcastStream() {
    return FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('isActive', isEqualTo: true)
        .where(
          'audience',
          whereIn: <String>['sellers', 'both'],
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _targetedStream() {
    final User seller = _seller!;

    return FirebaseFirestore.instance
        .collection('admin_notifications')
        .where('isActive', isEqualTo: true)
        .where('audience', isEqualTo: 'seller')
        .where('targetSellerId', isEqualTo: seller.uid)
        .snapshots();
  }

  List<Map<String, dynamic>> _toMaps(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(
      (QueryDocumentSnapshot<Map<String, dynamic>> document) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(document.data());

        final String notificationId =
            data['notificationId']?.toString().trim() ?? '';

        if (notificationId.isEmpty) {
          data['notificationId'] = document.id;
        }

        return data;
      },
    ).toList();
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    final String raw = value.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  DateTime? _notificationDate(
    Map<String, dynamic> notification,
  ) {
    return _dateFromValue(
      notification['createdAt'] ?? notification['updatedAt'],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final DateTime local = date.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final int rawHour = local.hour % 12;
    final int hour = rawHour == 0 ? 12 : rawHour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/${local.year}  $hour:$minute $period';
  }

  List<Map<String, dynamic>> _mergeNotifications(
    List<Map<String, dynamic>> broadcast,
    List<Map<String, dynamic>> targeted,
  ) {
    final Map<String, Map<String, dynamic>> unique =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> notification
        in <Map<String, dynamic>>[...broadcast, ...targeted]) {
      final String id =
          notification['notificationId']?.toString().trim() ?? '';

      if (id.isNotEmpty) {
        unique[id] = notification;
      }
    }

    final List<Map<String, dynamic>> result = unique.values.toList();

    result.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) {
        final DateTime aDate =
            _notificationDate(a) ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate =
            _notificationDate(b) ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      },
    );

    return result;
  }

  Future<void> _markRead(String notificationId) async {
    final String key = notificationId.trim();

    if (key.isEmpty || _readKeys.contains(key)) {
      return;
    }

    final Set<String> updated = <String>{..._readKeys, key};
    await _saveReadKeys(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readKeys = updated;
    });
  }

  Future<void> _markAllRead(
    List<Map<String, dynamic>> notifications,
  ) async {
    final Set<String> updated = <String>{..._readKeys};

    for (final Map<String, dynamic> notification in notifications) {
      final String id =
          notification['notificationId']?.toString().trim() ?? '';

      if (id.isNotEmpty) {
        updated.add(id);
      }
    }

    await _saveReadKeys(updated);

    if (!mounted) {
      return;
    }

    setState(() {
      _readKeys = updated;
    });
  }

  Future<void> _openNotification(
    Map<String, dynamic> notification,
  ) async {
    final String notificationId =
        notification['notificationId']?.toString().trim() ?? '';

    await _markRead(notificationId);

    if (!mounted) {
      return;
    }

    final String title =
        notification['title']?.toString().trim() ?? 'RD Online Shop';
    final String message =
        notification['message']?.toString().trim() ?? '';
    final String mediaUrl =
        notification['mediaUrl']?.toString().trim() ?? '';
    final String actionUrl =
        notification['actionUrl']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (message.isNotEmpty) Text(message),
                if (mediaUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Media:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(mediaUrl),
                ],
                if (actionUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  const Text(
                    'Link:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(actionUrl),
                ],
              ],
            ),
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'promotion':
        return Icons.local_offer_rounded;
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'system':
        return Icons.info_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'promotion':
        return Colors.deepOrange;
      case 'order':
        return Colors.blue;
      case 'system':
        return Colors.indigo;
      case 'announcement':
        return Colors.red;
      default:
        return Colors.deepPurple;
    }
  }

  Widget _notificationCard(
    Map<String, dynamic> notification,
  ) {
    final String id =
        notification['notificationId']?.toString().trim() ?? '';
    final String title =
        notification['title']?.toString().trim() ?? 'RD Online Shop';
    final String message =
        notification['message']?.toString().trim() ?? '';
    final String type =
        notification['contentType']?.toString().trim() ?? 'general';
    final bool unread = !_readKeys.contains(id);
    final DateTime? date = _notificationDate(notification);
    final Color color = _colorForType(type);

    return Card(
      margin: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      elevation: unread ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: unread
              ? color.withValues(alpha: 0.32)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openNotification(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(type),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  unread
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: <Widget>[
                        Text(
                          'RD Online Shop',
                          style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_formatDate(date).isNotEmpty)
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 14),
            Text(
              'No seller notifications yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Admin announcements and seller-specific notices will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationList(
    List<Map<String, dynamic>> notifications,
  ) {
    if (notifications.isEmpty) {
      return _emptyState();
    }

    final int unreadCount = notifications.where(
      (Map<String, dynamic> notification) {
        final String id =
            notification['notificationId']?.toString().trim() ?? '';

        return id.isNotEmpty && !_readKeys.contains(id);
      },
    ).length;

    return Column(
      children: <Widget>[
        if (unreadCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$unreadCount unread notification'
                    '${unreadCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _markAllRead(notifications),
                  icon: const Icon(
                    Icons.done_all_rounded,
                    size: 18,
                  ),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 24,
            ),
            itemCount: notifications.length,
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              return _notificationCard(
                notifications[index],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _streams() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _broadcastStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> broadcastSnapshot,
      ) {
        if (broadcastSnapshot.connectionState == ConnectionState.waiting &&
            !broadcastSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (broadcastSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load seller announcements.\n'
                '${broadcastSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<Map<String, dynamic>> broadcast =
            broadcastSnapshot.hasData
                ? _toMaps(broadcastSnapshot.data!)
                : <Map<String, dynamic>>[];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _targetedStream(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> targetedSnapshot,
          ) {
            if (targetedSnapshot.connectionState == ConnectionState.waiting &&
                !targetedSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (targetedSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load personal seller notifications.\n'
                    '${targetedSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<Map<String, dynamic>> targeted =
                targetedSnapshot.hasData
                    ? _toMaps(targetedSnapshot.data!)
                    : <Map<String, dynamic>>[];

            final List<Map<String, dynamic>> notifications =
                _mergeNotifications(
              broadcast,
              targeted,
            );

            return _notificationList(notifications);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Seller Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load seller notifications.\n$_loadError',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _streams(),
    );
  }
}
