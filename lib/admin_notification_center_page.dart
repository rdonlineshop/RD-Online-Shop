import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationCenterPage extends StatefulWidget {
  const AdminNotificationCenterPage({super.key});

  @override
  State<AdminNotificationCenterPage> createState() =>
      _AdminNotificationCenterPageState();
}

class _AdminNotificationCenterPageState
    extends State<AdminNotificationCenterPage> {
  static const String _collectionName = 'admin_notifications';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _targetIdController = TextEditingController();
  final TextEditingController _mediaUrlController = TextEditingController();
  final TextEditingController _actionUrlController = TextEditingController();

  String _audience = 'customers';
  String _contentType = 'announcement';
  bool _pushEnabled = true;
  bool _isSending = false;

  bool get _needsTargetId =>
      _audience == 'customer' || _audience == 'seller';

  String get _targetLabel {
    if (_audience == 'customer') {
      return 'Customer ID';
    }

    if (_audience == 'seller') {
      return 'Seller ID';
    }

    return 'Target ID';
  }

  String get _audienceLabel {
    switch (_audience) {
      case 'customers':
        return 'All Customers';
      case 'sellers':
        return 'All Sellers';
      case 'both':
        return 'Customers + Sellers';
      case 'customer':
        return 'Specific Customer';
      case 'seller':
        return 'Specific Seller';
      default:
        return 'Audience';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetIdController.dispose();
    _mediaUrlController.dispose();
    _actionUrlController.dispose();
    super.dispose();
  }

  String _optionalText(TextEditingController controller) {
    return controller.text.trim();
  }

  Future<void> _sendNotification() async {
    if (_isSending) {
      return;
    }

    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      _showMessage('Admin login required.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final DocumentReference<Map<String, dynamic>> reference =
          FirebaseFirestore.instance.collection(_collectionName).doc();

      final String targetId = _targetIdController.text.trim();
      final String mediaUrl = _optionalText(_mediaUrlController);
      final String actionUrl = _optionalText(_actionUrlController);

      final Map<String, dynamic> data = <String, dynamic>{
        'notificationId': reference.id,
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'audience': _audience,
        'contentType': _contentType,
        'targetCustomerId': _audience == 'customer' ? targetId : '',
        'targetSellerId': _audience == 'seller' ? targetId : '',
        'mediaUrl': mediaUrl,
        'actionUrl': actionUrl,
        'isActive': true,
        'pushEnabled': _pushEnabled,
        'createdByUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await reference.set(data);

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _messageController.clear();
      _targetIdController.clear();
      _mediaUrlController.clear();
      _actionUrlController.clear();

      setState(() {
        _audience = 'customers';
        _contentType = 'announcement';
        _pushEnabled = true;
      });

      _showMessage(
        'Notification saved for $_audienceLabel.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? 'Could not save notification.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not save notification.\n$error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deactivateNotification(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      await reference.update(<String, dynamic>{
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _showMessage('Notification deactivated.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? 'Could not deactivate notification.',
        isError: true,
      );
    }
  }

  Future<void> _deleteNotification(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Notification'),
          content: const Text(
            'Delete this notification permanently?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await reference.delete();

      if (!mounted) {
        return;
      }

      _showMessage('Notification deleted.');
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? 'Could not delete notification.',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Saving...';
    }

    final DateTime value = timestamp.toDate().toLocal();

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _composerCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _sectionTitle('Create Notification'),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(
                  labelText: 'Send To',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'customers',
                    child: Text('All Customers'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'sellers',
                    child: Text('All Sellers'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'both',
                    child: Text('Customers + Sellers'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'customer',
                    child: Text('Specific Customer'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'seller',
                    child: Text('Specific Seller'),
                  ),
                ],
                onChanged: _isSending
                    ? null
                    : (String? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _audience = value;
                          _targetIdController.clear();
                        });
                      },
              ),
              if (_needsTargetId) ...<Widget>[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _targetIdController,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    labelText: _targetLabel,
                    hintText: 'Enter exact $_targetLabel',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (String? value) {
                    if (!_needsTargetId) {
                      return null;
                    }

                    if (value == null || value.trim().isEmpty) {
                      return '$_targetLabel is required.';
                    }

                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _contentType,
                decoration: const InputDecoration(
                  labelText: 'Notification Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'announcement',
                    child: Text('Announcement'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'promotion',
                    child: Text('Promotion / Offer'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'order',
                    child: Text('Order Information'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'system',
                    child: Text('System Notice'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'general',
                    child: Text('General'),
                  ),
                ],
                onChanged: _isSending
                    ? null
                    : (String? value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _contentType = value;
                        });
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                enabled: !_isSending,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Example: RD Online Shop Offer',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Title is required.';
                  }

                  if (text.length < 2) {
                    return 'Title is too short.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                enabled: !_isSending,
                minLines: 4,
                maxLines: 7,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Write the notification message...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 76),
                    child: Icon(Icons.message_outlined),
                  ),
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Message is required.';
                  }

                  if (text.length < 2) {
                    return 'Message is too short.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _mediaUrlController,
                enabled: !_isSending,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Image / Video URL (Optional)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.perm_media_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _actionUrlController,
                enabled: !_isSending,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Open Link (Optional)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Push Notification',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Saved now. Real automatic push will use this flag when the '
                  'FCM backend is deployed.',
                ),
                value: _pushEnabled,
                onChanged: _isSending
                    ? null
                    : (bool value) {
                        setState(() {
                          _pushEnabled = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _isSending ? null : _sendNotification,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending ? 'Saving...' : 'Send Notification',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();

    final String title = data['title']?.toString().trim() ?? '';
    final String message = data['message']?.toString().trim() ?? '';
    final String audience = data['audience']?.toString().trim() ?? '';
    final String contentType =
        data['contentType']?.toString().trim() ?? 'general';
    final bool isActive = data['isActive'] == true;
    final bool pushEnabled = data['pushEnabled'] == true;
    final Timestamp? createdAt =
        data['createdAt'] is Timestamp ? data['createdAt'] as Timestamp : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              child: Icon(
                isActive
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? 'Untitled notification' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: <Widget>[
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(audience),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(contentType),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          pushEnabled
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_off_outlined,
                          size: 17,
                        ),
                        label: Text(
                          pushEnabled ? 'Push on' : 'Push off',
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          isActive ? 'Active' : 'Inactive',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Notification actions',
              onSelected: (String value) async {
                if (value == 'deactivate') {
                  await _deactivateNotification(document.reference);
                } else if (value == 'delete') {
                  await _deleteNotification(document.reference);
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<String>>[
                  if (isActive)
                    const PopupMenuItem<String>(
                      value: 'deactivate',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notifications_off_outlined),
                        title: Text('Deactivate'),
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Could not load notification history.\n${snapshot.error}',
              ),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (documents.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No admin notifications yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Column(
          children: documents.map(_historyCard).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notification Center',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final double contentWidth =
              constraints.maxWidth > 900 ? 900 : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _composerCard(),
                  const SizedBox(height: 20),
                  _sectionTitle('Recent Notifications'),
                  _historySection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
