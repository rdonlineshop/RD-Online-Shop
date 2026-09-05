import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class RideDriverForegroundAlertService {
  RideDriverForegroundAlertService._();

  static final RideDriverForegroundAlertService instance =
      RideDriverForegroundAlertService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _driverSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _rideSubscription;

  Timer? _reminderTimer;

  final Set<String> _knownPendingRideIds = <String>{};

  bool _initialized = false;
  bool _rideSnapshotInitialized = false;
  bool _driverCanReceiveRequests = false;
  String _driverId = '';

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        unawaited(_bindAuthenticatedUser(user));
      },
      onError: (Object _) {
        unawaited(_stopDriverBinding());
      },
    );
  }

  Future<void> _bindAuthenticatedUser(User? user) async {
    await _stopDriverBinding();

    if (user == null || user.isAnonymous) {
      return;
    }

    final String uid = user.uid.trim();
    if (uid.isEmpty) {
      return;
    }

    _driverId = uid;

    _driverSubscription = FirebaseFirestore.instance
        .collection('ride_drivers')
        .doc(uid)
        .snapshots()
        .listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic> data =
            snapshot.data() ?? <String, dynamic>{};

        final String role =
            data['role']?.toString().trim().toLowerCase() ?? '';
        final bool isOnline = data['isOnline'] == true;
        final bool isActive = data['isActive'] == true;
        final bool isApproved = data['isApproved'] == true;
        final bool licenceVerified =
            data['drivingLicenseVerified'] == true;

        final String currentRideRequestId =
            data['currentRideRequestId']?.toString().trim() ?? '';

        final bool canReceive =
            role == 'ride_driver' &&
            isOnline &&
            isActive &&
            isApproved &&
            licenceVerified &&
            currentRideRequestId.isEmpty;

        if (canReceive == _driverCanReceiveRequests) {
          return;
        }

        _driverCanReceiveRequests = canReceive;

        if (canReceive) {
          _startRideRequestListener();
        } else {
          unawaited(_stopRideRequestListener());
        }
      },
      onError: (Object _) {
        _driverCanReceiveRequests = false;
        unawaited(_stopRideRequestListener());
      },
    );
  }

  void _startRideRequestListener() {
    if (_driverId.isEmpty ||
        !_driverCanReceiveRequests ||
        _rideSubscription != null) {
      return;
    }

    _rideSnapshotInitialized = false;
    _knownPendingRideIds.clear();

    _rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .where('driverId', isEqualTo: _driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final Set<String> currentIds = snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  doc.id,
            )
            .toSet();

        if (!_rideSnapshotInitialized) {
          _rideSnapshotInitialized = true;
          _knownPendingRideIds
            ..clear()
            ..addAll(currentIds);

          if (currentIds.isNotEmpty) {
            _playAlert();
          }

          _syncReminderTimer();
          return;
        }

        final Set<String> newlyAdded =
            currentIds.difference(_knownPendingRideIds);

        _knownPendingRideIds
          ..clear()
          ..addAll(currentIds);

        if (newlyAdded.isNotEmpty) {
          _playAlert();
        }

        _syncReminderTimer();
      },
      onError: (Object _) {
        unawaited(_stopRideRequestListener());
      },
    );
  }

  void _playAlert() {
    if (!_driverCanReceiveRequests ||
        _knownPendingRideIds.isEmpty) {
      return;
    }

    unawaited(
      _audioPlayer
          .stop()
          .then(
            (_) => _audioPlayer.play(
              AssetSource('sounds/ride_request_alert.wav'),
              volume: 1.0,
            ),
          )
          .catchError(
            (Object _) {
              // A later reminder can retry playback.
            },
          ),
    );

    unawaited(HapticFeedback.vibrate());
  }

  void _syncReminderTimer() {
    if (!_driverCanReceiveRequests ||
        _knownPendingRideIds.isEmpty) {
      _reminderTimer?.cancel();
      _reminderTimer = null;
      return;
    }

    if (_reminderTimer != null) {
      return;
    }

    _reminderTimer = Timer.periodic(
      const Duration(seconds: 12),
      (Timer timer) {
        if (!_driverCanReceiveRequests ||
            _knownPendingRideIds.isEmpty) {
          timer.cancel();
          _reminderTimer = null;
          return;
        }

        _playAlert();
      },
    );
  }

  Future<void> _stopRideRequestListener() async {
    _reminderTimer?.cancel();
    _reminderTimer = null;

    await _rideSubscription?.cancel();
    _rideSubscription = null;

    _rideSnapshotInitialized = false;
    _knownPendingRideIds.clear();

    try {
      await _audioPlayer.stop();
    } catch (_) {
      // Nothing else is required if audio is already stopped.
    }
  }

  Future<void> _stopDriverBinding() async {
    _driverCanReceiveRequests = false;

    await _stopRideRequestListener();

    await _driverSubscription?.cancel();
    _driverSubscription = null;

    _driverId = '';
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;

    await _stopDriverBinding();
    await _audioPlayer.dispose();

    _initialized = false;
  }
}
