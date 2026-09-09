import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

class BusTicketInAppNoticeService {
  BusTicketInAppNoticeService._();

  static final BusTicketInAppNoticeService instance =
      BusTicketInAppNoticeService._();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _bookingSubscription;

  final Map<String, _BusTicketState> _lastStates =
      <String, _BusTicketState>{};

  String? _boundUid;
  bool _primed = false;

  Future<void> initialize() async {
    await _authSubscription?.cancel();

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        unawaited(_bindUser(user));
      },
      onError: (Object error) {
        debugPrint(
          'Bus ticket notice auth listener error: $error',
        );
      },
    );

    await _bindUser(FirebaseAuth.instance.currentUser);
  }

  Future<void> _bindUser(User? user) async {
    final String? uid = user?.uid;

    if (_boundUid == uid &&
        _bookingSubscription != null) {
      return;
    }

    await _bookingSubscription?.cancel();
    _bookingSubscription = null;

    _boundUid = uid;
    _primed = false;
    _lastStates.clear();

    if (user == null) {
      return;
    }

    try {
      _bookingSubscription = FirebaseFirestore.instance
          .collection('bus_ticket_bookings')
          .where(
            'customerAuthUid',
            isEqualTo: user.uid,
          )
          .snapshots()
          .listen(
        _onBookingSnapshot,
        onError: (Object error) {
          debugPrint(
            'Bus ticket in-app notice listener error: $error',
          );
        },
      );
    } catch (error) {
      debugPrint(
        'Bus ticket in-app notice bind error: $error',
      );
    }
  }

  void _onBookingSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!_primed) {
      for (final QueryDocumentSnapshot<
              Map<String, dynamic>>
          document in snapshot.docs) {
        _lastStates[document.id] =
            _BusTicketState.fromData(
          document.data(),
        );
      }

      _primed = true;
      return;
    }

    for (final DocumentChange<Map<String, dynamic>>
        change in snapshot.docChanges) {
      final DocumentSnapshot<Map<String, dynamic>>
          document = change.doc;

      if (change.type == DocumentChangeType.removed) {
        _lastStates.remove(document.id);
        continue;
      }

      final _BusTicketState current =
          _BusTicketState.fromData(
        document.data() ??
            <String, dynamic>{},
      );

      final _BusTicketState? previous =
          _lastStates[document.id];

      _lastStates[document.id] = current;

      if (previous == null) {
        continue;
      }

      final _BusTicketNotice? notice =
          _noticeForChange(
        previous: previous,
        current: current,
      );

      if (notice != null) {
        _showNotice(notice);
      }
    }
  }

  _BusTicketNotice? _noticeForChange({
    required _BusTicketState previous,
    required _BusTicketState current,
  }) {
    final String bookingCode =
        current.bookingCode.isEmpty
            ? 'Your bus booking'
            : current.bookingCode;

    final String route =
        current.from.isNotEmpty &&
                current.to.isNotEmpty
            ? '${current.from} → ${current.to}'
            : 'your bus trip';

    if (current.bookingStatus == 'cancelled' &&
        previous.bookingStatus != 'cancelled') {
      return _BusTicketNotice(
        title: 'Bus Booking Cancelled',
        body:
            '$bookingCode for $route has been cancelled.',
        icon: Icons.cancel_rounded,
      );
    }

    if (current.ticketStatus == 'issued' &&
        previous.ticketStatus != 'issued') {
      return _BusTicketNotice(
        title: 'Bus Ticket Issued 🎫',
        body:
            '$bookingCode for $route is issued. '
            'Open My Bus Tickets to view the ticket/QR.',
        icon: Icons.confirmation_number_rounded,
      );
    }

    if (current.paymentStatus == 'refunded' &&
        previous.paymentStatus != 'refunded') {
      return _BusTicketNotice(
        title: 'Bus Ticket Refund Completed',
        body:
            '$bookingCode refund has been completed.',
        icon: Icons.currency_exchange_rounded,
      );
    }

    if (current.paymentStatus == 'refund_pending' &&
        previous.paymentStatus != 'refund_pending') {
      return _BusTicketNotice(
        title: 'Bus Ticket Refund Pending',
        body:
            '$bookingCode refund is pending.',
        icon: Icons.hourglass_top_rounded,
      );
    }

    if (current.paymentStatus == 'paid' &&
        previous.paymentStatus != 'paid') {
      return _BusTicketNotice(
        title: 'Bus Payment Confirmed ✅',
        body:
            'Payment for $bookingCode ($route) '
            'has been confirmed.',
        icon: Icons.payments_rounded,
      );
    }

    if (current.bookingStatus == 'confirmed' &&
        previous.bookingStatus != 'confirmed') {
      return _BusTicketNotice(
        title: 'Bus Booking Confirmed ✅',
        body:
            '$bookingCode for $route has been '
            'accepted and confirmed.',
        icon: Icons.verified_rounded,
      );
    }

    return null;
  }

  void _showNotice(_BusTicketNotice notice) {
    final ScaffoldMessengerState? messenger =
        NotificationService.messengerKey.currentState;

    if (messenger == null) {
      debugPrint(
        'Bus ticket notice skipped because '
        'ScaffoldMessenger is not ready.',
      );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          behavior: SnackBarBehavior.floating,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                notice.icon,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notice.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(notice.body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> dispose() async {
    await _bookingSubscription?.cancel();
    await _authSubscription?.cancel();

    _bookingSubscription = null;
    _authSubscription = null;

    _boundUid = null;
    _primed = false;
    _lastStates.clear();
  }
}

class _BusTicketState {
  const _BusTicketState({
    required this.bookingCode,
    required this.from,
    required this.to,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.ticketStatus,
  });

  factory _BusTicketState.fromData(
    Map<String, dynamic> data,
  ) {
    return _BusTicketState(
      bookingCode:
          data['bookingCode']?.toString().trim() ?? '',
      from: data['from']?.toString().trim() ?? '',
      to: data['to']?.toString().trim() ?? '',
      bookingStatus:
          data['bookingStatus']?.toString().trim() ?? '',
      paymentStatus:
          data['paymentStatus']?.toString().trim() ?? '',
      ticketStatus:
          data['ticketStatus']?.toString().trim() ?? '',
    );
  }

  final String bookingCode;
  final String from;
  final String to;
  final String bookingStatus;
  final String paymentStatus;
  final String ticketStatus;
}

class _BusTicketNotice {
  const _BusTicketNotice({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
