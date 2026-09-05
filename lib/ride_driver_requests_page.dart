import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'ride_chat_page.dart';
import 'ride_driver_agreement_page.dart';
import 'ride_driver_auth_page.dart';
import 'ride_driver_earnings_page.dart';
import 'ride_driver_reactivation_page.dart';
import 'services/platform_capabilities.dart';
import 'services/ride_request_service.dart';
import 'services/ride_sos_service.dart';
import 'widgets/ride_driver_rating_summary.dart';

class RideDriverRequestsPage extends StatefulWidget {
  const RideDriverRequestsPage({
    required this.driverId,
    super.key,
  });

  final String driverId;

  @override
  State<RideDriverRequestsPage> createState() =>
      _RideDriverRequestsPageState();
}

class _RideDriverRequestsPageState extends State<RideDriverRequestsPage> {
  bool _updatingOnlineStatus = false;
  bool _updatingRideStatus = false;
  String? _activeRideRequestId;
  final RideRequestService _rideRequestService = RideRequestService();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _rideWatchSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<Position>? _availabilityPositionSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;

  String get _driverId => widget.driverId.trim();

  String _agreementTimestampText(dynamic value) {
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

  void _openMyDriverAgreement(Map<String, dynamic> data) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RideDriverAgreementPage(
          driverName: data['name']?.toString().trim() ?? '',
          reviewOnly: true,
          acceptedName:
              data['driverAgreementAcceptedName']?.toString().trim() ?? '',
          acceptedVersion:
              data['driverAgreementVersion']?.toString().trim() ?? '',
          acceptedHash:
              data['driverAgreementTextHash']?.toString().trim() ?? '',
          acceptedAtText:
              _agreementTimestampText(data['driverAgreementAcceptedAt']),
          agreementText:
              data['driverAgreementTextSnapshot']?.toString() ?? '',
        ),
      ),
    );
  }



  CollectionReference<Map<String, dynamic>> get _rideRequests =>
      FirebaseFirestore.instance.collection('ride_requests');

  DocumentReference<Map<String, dynamic>> get _driverRef =>
      FirebaseFirestore.instance.collection('ride_drivers').doc(_driverId);

  @override
  void initState() {
    super.initState();
    _watchForActiveRide();
    unawaited(_restoreAvailabilityLocationTracking());
    unawaited(_registerDriverPushNotifications());
  }

  @override
  void dispose() {
    _rideWatchSubscription?.cancel();
    _positionSubscription?.cancel();
    _availabilityPositionSubscription?.cancel();
    _fcmTokenRefreshSubscription?.cancel();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingRequestsStream() {
    return _rideRequests
        .where('driverId', isEqualTo: _driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _allDriverRidesStream() {
    return _rideRequests.where('driverId', isEqualTo: _driverId).snapshots();
  }

  void _watchForActiveRide() {
    if (_driverId.isEmpty) {
      return;
    }

    _rideWatchSubscription = _allDriverRidesStream().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        QueryDocumentSnapshot<Map<String, dynamic>>? activeRide;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in snapshot.docs) {
          final String status = document
                  .data()['status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

          if (status == 'accepted' ||
              status == 'arrived' ||
              status == 'in_progress') {
            activeRide = document;
            break;
          }
        }

        final String? nextRideId = activeRide?.id;

        if (nextRideId == null) {
          if (_activeRideRequestId != null) {
            _activeRideRequestId = null;
            unawaited(
              _stopLiveLocationTracking(
                clearCurrentRide: true,
              ).then(
                (_) => _startAvailabilityLocationTrackingIfOnline(),
              ),
            );
            if (mounted) {
              setState(() {});
            }
          } else {
            unawaited(_startAvailabilityLocationTrackingIfOnline());
          }
          return;
        }

        if (_activeRideRequestId != nextRideId) {
          _activeRideRequestId = nextRideId;
          if (mounted) {
            setState(() {});
          }
        }

        unawaited(_startLiveLocationTracking(nextRideId));
      },
      onError: (_) {
        // The visible StreamBuilders show Firestore errors to the user.
      },
    );
  }

  Future<void> _saveDriverFcmToken(String rawToken) async {
    final String token = rawToken.trim();

    if (_driverId.isEmpty || token.isEmpty) {
      return;
    }

    await _driverRef.update(
      <String, dynamic>{
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion(<String>[token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> _registerDriverPushNotifications() async {
    if (_driverId.isEmpty ||
        !PlatformCapabilities.supportsPushNotifications) {
      return;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      final NotificationSettings settings =
          await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus ==
          AuthorizationStatus.denied) {
        return;
      }

      final String? token = await messaging.getToken();

      if (token != null && token.trim().isNotEmpty) {
        await _saveDriverFcmToken(token);
      }

      await _fcmTokenRefreshSubscription?.cancel();
      _fcmTokenRefreshSubscription =
          messaging.onTokenRefresh.listen(
        (String refreshedToken) {
          unawaited(
            _saveDriverFcmToken(refreshedToken).catchError(
              (Object _) {
                // A later token refresh or page reopen retries automatically.
              },
            ),
          );
        },
        onError: (Object _) {
          // Push token refresh can retry on a later app session.
        },
      );
    } catch (_) {
      // Push setup must never block the Ride Driver page.
    }
  }

  Future<Position?> _getCurrentPosition() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please turn on GPS / Location service first.',
          ),
        ),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is required for Ride Driver GPS.',
          ),
        ),
      );
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Location permission is permanently denied. Open app settings and allow location.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  LocationSettings _livePositionSettings({
    required int distanceFilter,
    required String notificationText,
  }) {
    if (!foundation.kIsWeb &&
        foundation.defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'RD Ride live location active',
          notificationText: notificationText,
          notificationChannelName: 'RD Ride Live Location',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  Future<void> _restoreAvailabilityLocationTracking() async {
    await _startAvailabilityLocationTrackingIfOnline();
  }

  Future<void> _startAvailabilityLocationTrackingIfOnline() async {
    if (_driverId.isEmpty ||
        _activeRideRequestId != null ||
        _availabilityPositionSubscription != null) {
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _driverRef.get();
      final Map<String, dynamic> data =
          snapshot.data() ?? <String, dynamic>{};

      if (!snapshot.exists || data['isOnline'] != true) {
        return;
      }

      await _startAvailabilityLocationTracking();
    } catch (_) {
      // A later Online toggle or ride-state refresh can retry.
    }
  }

  Future<void> _writeAvailabilityPosition(
    Position position,
  ) async {
    if (_driverId.isEmpty || _activeRideRequestId != null) {
      return;
    }

    try {
      await _driverRef.update(
        <String, dynamic>{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Foreground availability GPS retries on the next valid position.
    }
  }

  Future<void> _startAvailabilityLocationTracking({
    Position? initialPosition,
  }) async {
    if (_driverId.isEmpty ||
        _activeRideRequestId != null ||
        _availabilityPositionSubscription != null) {
      return;
    }

    final Position? currentPosition =
        initialPosition ?? await _getCurrentPosition();
    if (currentPosition == null) {
      return;
    }

    if (initialPosition == null) {
      await _writeAvailabilityPosition(currentPosition);
    }

    _availabilityPositionSubscription =
        Geolocator.getPositionStream(
      locationSettings: _livePositionSettings(
        distanceFilter: 10,
        notificationText:
            'You are online. RD Ride is sharing your location so nearby customers can find you.',
      ),
    ).listen(
      (Position position) {
        if (_activeRideRequestId == null) {
          unawaited(_writeAvailabilityPosition(position));
        }
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nearby-driver live GPS temporarily stopped: $error',
            ),
          ),
        );
      },
    );
  }

  Future<void> _stopAvailabilityLocationTracking() async {
    await _availabilityPositionSubscription?.cancel();
    _availabilityPositionSubscription = null;
  }

  double _calculateLiveFare({
    required double distanceKm,
    required double baseFare,
    required double perKm,
    required double minimumFare,
  }) {
    final double rawFare = baseFare + (distanceKm * perKm);
    final double minimumApplied =
        rawFare < minimumFare ? minimumFare : rawFare;
    return (minimumApplied / 5).ceil() * 5.0;
  }

  Future<void> _recordLiveFarePosition(
    Position position,
    String rideRequestId,
  ) async {
    final String cleanRideId = rideRequestId.trim();
    if (cleanRideId.isEmpty || position.accuracy > 100) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> requestRef =
        _rideRequests.doc(cleanRideId);

    await FirebaseFirestore.instance.runTransaction(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(requestRef);
        final Map<String, dynamic>? data = snapshot.data();

        if (!snapshot.exists || data == null) {
          return;
        }

        final String status =
            data['status']?.toString().trim().toLowerCase() ?? '';
        if (status != 'in_progress') {
          return;
        }

        final double? baseFare = _toDouble(data['fareBaseFare']);
        final double? perKm = _toDouble(data['farePerKm']);
        final double? minimumFare = _toDouble(data['fareMinimumFare']);

        // Legacy ride requests created before Live Fare remain usable.
        if (baseFare == null ||
            perKm == null ||
            minimumFare == null ||
            baseFare <= 0 ||
            perKm <= 0 ||
            minimumFare <= 0) {
          return;
        }

        final double currentDistanceKm =
            _toDouble(data['actualDistanceKm']) ?? 0.0;
        final double currentLiveFare = _calculateLiveFare(
          distanceKm: currentDistanceKm,
          baseFare: baseFare,
          perKm: perKm,
          minimumFare: minimumFare,
        );

        final double? previousLat =
            _toDouble(data['tripDistanceLastLatitude']);
        final double? previousLng =
            _toDouble(data['tripDistanceLastLongitude']);
        final Timestamp currentPositionAt =
            Timestamp.fromDate(position.timestamp);

        if (previousLat == null || previousLng == null) {
          transaction.update(
            requestRef,
            <String, dynamic>{
              'actualDistanceKm': currentDistanceKm,
              'liveFare': currentLiveFare,
              'tripDistanceLastLatitude': position.latitude,
              'tripDistanceLastLongitude': position.longitude,
              'tripDistanceLastPositionAt': currentPositionAt,
              'tripDistanceUpdatedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
          return;
        }

        final double segmentMeters = Geolocator.distanceBetween(
          previousLat,
          previousLng,
          position.latitude,
          position.longitude,
        );

        if (!segmentMeters.isFinite || segmentMeters < 0) {
          return;
        }

        final dynamic previousTimeRaw =
            data['tripDistanceLastPositionAt'];
        final DateTime? previousTime = previousTimeRaw is Timestamp
            ? previousTimeRaw.toDate()
            : null;

        if (previousTime != null) {
          final double elapsedSeconds = position.timestamp
                  .difference(previousTime)
                  .inMilliseconds /
              1000.0;

          // Ignore duplicated/out-of-order GPS samples.
          if (elapsedSeconds <= 0) {
            return;
          }

          final double speedKmh =
              (segmentMeters / elapsedSeconds) * 3.6;
          if (speedKmh > 200) {
            // Ignore an unrealistic GPS jump for fare calculation.
            return;
          }
        } else if (segmentMeters > 2000) {
          // Extra protection for a legacy/missing timestamp baseline.
          return;
        }

        // Very small movements are treated as GPS noise. Keep the baseline
        // fresh, but do not charge the passenger for the jitter.
        final double chargedSegmentMeters =
            segmentMeters < 3 ? 0.0 : segmentMeters;
        final double nextDistanceKm =
            currentDistanceKm + (chargedSegmentMeters / 1000.0);
        final double nextLiveFare = _calculateLiveFare(
          distanceKm: nextDistanceKm,
          baseFare: baseFare,
          perKm: perKm,
          minimumFare: minimumFare,
        );

        transaction.update(
          requestRef,
          <String, dynamic>{
            'actualDistanceKm': nextDistanceKm,
            'liveFare': nextLiveFare,
            'tripDistanceLastLatitude': position.latitude,
            'tripDistanceLastLongitude': position.longitude,
            'tripDistanceLastPositionAt': currentPositionAt,
            'tripDistanceUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );
  }

  Future<void> _writeDriverPosition(
    Position position,
    String rideRequestId,
  ) async {
    try {
      await _driverRef.update(
        <String, dynamic>{
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
          'currentRideRequestId': rideRequestId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // A later GPS update retries automatically while the stream is active.
    }

    try {
      await _recordLiveFarePosition(position, rideRequestId);
    } catch (_) {
      // Driver GPS sharing must continue even if one fare write fails.
      // The next valid GPS point retries the live fare update.
    }
  }

  Future<void> _startLiveLocationTracking(String rideRequestId) async {
    final String cleanRideId = rideRequestId.trim();
    if (cleanRideId.isEmpty) {
      return;
    }

    await _stopAvailabilityLocationTracking();

    if (_positionSubscription != null &&
        _activeRideRequestId == cleanRideId) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final Position? currentPosition = await _getCurrentPosition();
    if (currentPosition == null) {
      return;
    }

    await _writeDriverPosition(currentPosition, cleanRideId);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _livePositionSettings(
        distanceFilter: 5,
        notificationText:
            'RD Ride is sharing your live location for the active trip.',
      ),
    ).listen(
      (Position position) {
        unawaited(_writeDriverPosition(position, cleanRideId));
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live GPS temporarily stopped: $error'),
          ),
        );
      },
    );
  }

  Future<void> _stopLiveLocationTracking({
    bool clearCurrentRide = false,
  }) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (clearCurrentRide && _driverId.isNotEmpty) {
      try {
        await _driverRef.update(
          <String, dynamic>{
            'currentRideRequestId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      } catch (_) {
        // The trip lifecycle should not fail only because this cleanup failed.
      }
    }
  }

  Future<void> _setOnlineStatus(bool goOnline) async {
    if (_updatingOnlineStatus) {
      return;
    }

    if (!goOnline && _activeRideRequestId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the active ride before going offline.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _updatingOnlineStatus = true;
    });

    try {
      if (goOnline) {
        final DocumentSnapshot<Map<String, dynamic>> driverDocument =
            await _driverRef.get();
        final Map<String, dynamic> driverData =
            driverDocument.data() ?? <String, dynamic>{};
        final bool approved = driverData['isApproved'] == true;
        final bool active = driverData['isActive'] == true;
        final bool licenceVerified =
            driverData['drivingLicenseVerified'] == true;
        final String approvalStatus =
            driverData['approvalStatus']?.toString().trim().toLowerCase() ?? '';
        final bool suspended = approvalStatus == 'suspended';

        if (!approved || !active || !licenceVerified || suspended) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                suspended
                    ? 'Your driver account is suspended. Pay the amount due and request reactivation before going online.'
                    : 'Admin approval and driving licence verification are required before going online.',
              ),
            ),
          );
          return;
        }

        final Position? position = await _getCurrentPosition();
        if (position == null) {
          return;
        }

        await _driverRef.update(
          <String, dynamic>{
            'isOnline': true,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'locationUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        await _startAvailabilityLocationTracking(
          initialPosition: position,
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are online. Nearby customers can now find you.',
            ),
          ),
        );
      } else {
        await _stopAvailabilityLocationTracking();
        await _stopLiveLocationTracking();

        await _driverRef.update(
          <String, dynamic>{
            'isOnline': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are offline.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update online status: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingOnlineStatus = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    if (_activeRideRequestId != null &&
        _activeRideRequestId != request.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete your current ride before accepting another request.',
          ),
        ),
      );
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> driverDocument =
        await _driverRef.get();
    final Map<String, dynamic> driverData =
        driverDocument.data() ?? <String, dynamic>{};
    final bool driverCanAccept =
        driverData['isApproved'] == true &&
        driverData['isActive'] == true &&
        driverData['drivingLicenseVerified'] == true &&
        driverData['approvalStatus']?.toString().trim().toLowerCase() !=
            'suspended';

    if (!driverCanAccept) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride access is paused. Resolve the driver account status before accepting a new ride.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(
        request.reference,
        <String, dynamic>{
          'status': 'accepted',
          'driverResponse': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _driverRef,
        <String, dynamic>{
          'currentRideRequestId': request.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      _activeRideRequestId = request.id;
      await _startLiveLocationTracking(request.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride accepted. Live GPS tracking started.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept ride request: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      await request.reference.update(
        <String, dynamic>{
          'status': 'rejected',
          'driverResponse': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request rejected.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reject ride request: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }



  Future<void> _cancelAcceptedRide(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    final List<String> reasons = <String>[
      'Vehicle problem',
      'Emergency',
      'Cannot reach pickup',
      'Customer unreachable',
      'Safety concern',
      'Other',
    ];

    String selectedReason = reasons.first;

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: const Text('Cancel Ride Before Start?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Use this only before Start Trip. The customer will not '
                    'be charged a cancellation fee when the driver cancels.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(
                      labelText: 'Cancellation reason',
                      border: OutlineInputBorder(),
                    ),
                    items: reasons
                        .map(
                          (String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedReason = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Keep Ride'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(dialogContext, selectedReason),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Ride'),
                ),
              ],
            );
          },
        );
      },
    );

    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      await _rideRequestService.cancelDriverRide(
        rideRequestId: request.id,
        reason: reason,
      );

      _activeRideRequestId = null;
      await _stopLiveLocationTracking();

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride cancelled. The customer was not charged a cancellation fee.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel ride: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }


  Future<void> _markArrivedAtPickup(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Arrived at Pickup?'),
              content: const Text(
                'Confirm only after you have reached the customer pickup location. '
                'The customer will immediately see that you have arrived.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not Yet'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('I Have Arrived'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      await request.reference.update(
        <String, dynamic>{
          'status': 'arrived',
          'arrivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Arrival confirmed. The customer can now see that you are at the pickup point.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark arrival: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }


  Future<bool> _verifyTripStartOtp(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final Map<String, dynamic> data = request.data();
    final bool otpRequired = data['tripStartOtpRequired'] == true;
    final String expectedHash =
        data['tripStartOtpHash']?.toString().trim() ?? '';

    // Legacy rides created before OTP was added can still be completed.
    if (!otpRequired || expectedHash.isEmpty) {
      return true;
    }

    final String? otp = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const _TripStartOtpDialog();
      },
    );

    if (otp == null || !mounted) {
      return false;
    }

    final String enteredHash =
        sha256.convert(utf8.encode(otp.trim())).toString();

    if (enteredHash != expectedHash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incorrect Trip Start OTP. Ask the customer for the current 6-digit OTP.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _callCustomerPhone(String phone) async {
    final String cleanPhone = phone.trim();

    if (cleanPhone.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customer phone number is not available. Use Ride Chat instead.',
          ),
        ),
      );
      return;
    }

    try {
      final bool opened = await launchUrl(
        Uri(scheme: 'tel', path: cleanPhone),
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone app is available on this device.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open phone call: $error')),
      );
    }
  }

  Future<void> _sendDriverSos(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final List<String> reasons = <String>[
      'Accident',
      'Medical emergency',
      'Safety threat',
      'Passenger conflict',
      'Vehicle emergency',
      'Other emergency',
    ];

    String selectedReason = reasons.first;

    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
            BuildContext dialogContext,
            StateSetter setDialogState,
          ) {
            return AlertDialog(
              title: const Row(
                children: <Widget>[
                  Icon(Icons.sos_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(child: Text('Send SOS Alert?')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'This sends an emergency record to RD Admin with this ride '
                    'and your best available GPS location.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Emergency reason',
                      border: OutlineInputBorder(),
                    ),
                    items: reasons
                        .map(
                          (String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedReason = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      Navigator.pop(dialogContext, selectedReason),
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text('Send SOS'),
                ),
              ],
            );
          },
        );
      },
    );

    if (reason == null || !mounted) {
      return;
    }

    final String authUid =
        FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (authUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride Driver login is required for SOS.')),
      );
      return;
    }

    Position? position;
    try {
      position = await _getCurrentPosition();
    } catch (_) {
      position = null;
    }

    double? latitude = position?.latitude;
    double? longitude = position?.longitude;
    String locationAddress = position != null
        ? 'Current driver GPS'
        : 'Last known driver GPS';

    if (latitude == null || longitude == null) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> driverSnapshot =
            await _driverRef.get();
        final Map<String, dynamic> driverData =
            driverSnapshot.data() ?? <String, dynamic>{};

        latitude = _toDouble(driverData['latitude'] ?? driverData['lat']);
        longitude = _toDouble(driverData['longitude'] ?? driverData['lng']);

        if (latitude == null || longitude == null) {
          locationAddress = 'Driver GPS unavailable';
        }
      } catch (_) {
        locationAddress = 'Driver GPS unavailable';
      }
    }

    try {
      await RideSosService().createAlert(
        ride: request.data(),
        triggeredBy: 'driver',
        triggeredByUid: authUid,
        reason: reason,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SOS sent to RD Admin. If there is immediate danger, contact local emergency services.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send SOS: $error')),
      );
    }
  }


  Future<void> _startTrip(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    final String currentStatus =
        request.data()['status']?.toString().trim().toLowerCase() ?? '';
    if (currentStatus != 'arrived') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirm Arrived at Pickup before starting the trip.',
          ),
        ),
      );
      return;
    }

    final bool otpVerified = await _verifyTripStartOtp(request);
    if (!otpVerified || !mounted) {
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      final Position? startPosition = await _getCurrentPosition();

      final WriteBatch startBatch = FirebaseFirestore.instance.batch();

      startBatch.update(
        request.reference,
        <String, dynamic>{
          'status': 'in_progress',
          'tripStartedAt': FieldValue.serverTimestamp(),
          'tripStartOtpVerifiedAt': FieldValue.serverTimestamp(),
          'actualDistanceKm': 0.0,
          if (startPosition != null && startPosition.accuracy <= 100)
            ...<String, dynamic>{
            'tripDistanceLastLatitude': startPosition.latitude,
            'tripDistanceLastLongitude': startPosition.longitude,
            'tripDistanceLastPositionAt':
                Timestamp.fromDate(startPosition.timestamp),
            'tripDistanceUpdatedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // The real 6-digit OTP is no longer needed after successful
      // verification. Delete it atomically while preserving only the
      // verification timestamp on the parent ride for Admin evidence.
      startBatch.delete(
        request.reference.collection('private').doc('customer'),
      );

      await startBatch.commit();

      if (startPosition != null) {
        await _writeDriverPosition(startPosition, request.id);
      }

      await _startLiveLocationTracking(request.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Trip started. Live GPS, actual distance and live fare are now shared with the customer.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start trip: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }

  Future<void> _completeTrip(
    QueryDocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    if (_updatingRideStatus) {
      return;
    }

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Complete Trip?'),
              content: const Text(
                'Confirm only after the passenger has reached the destination.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not Yet'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('Complete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _updatingRideStatus = true;
    });

    try {
      final Position? finalPosition = await _getCurrentPosition();
      if (finalPosition != null) {
        await _writeDriverPosition(finalPosition, request.id);
      }

      final DocumentSnapshot<Map<String, dynamic>> latestSnapshot =
          await request.reference.get();
      final Map<String, dynamic> latestData =
          latestSnapshot.data() ?? request.data();

      final double finalDistanceKm =
          _toDouble(latestData['actualDistanceKm']) ??
              _toDouble(latestData['routeDistanceKm']) ??
              0.0;
      final double finalFare =
          _toDouble(latestData['liveFare']) ??
              _toDouble(latestData['estimatedFare']) ??
              0.0;
      final double rdCommissionPercent =
          _toDouble(latestData['rdCommissionPercent']) ?? 0.0;
      final double finalRdCommission =
          finalFare * rdCommissionPercent / 100.0;
      final double driverNetIncome =
          (finalFare - finalRdCommission)
              .clamp(0.0, finalFare)
              .toDouble();

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(
        request.reference,
        <String, dynamic>{
          'status': 'completed',
          'tripCompletedAt': FieldValue.serverTimestamp(),
          'finalDistanceKm': finalDistanceKm,
          'finalFare': finalFare,
          'finalRdCommission': finalRdCommission,
          'driverNetIncome': driverNetIncome,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.update(
        _driverRef,
        <String, dynamic>{
          'currentRideRequestId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      _activeRideRequestId = null;
      await _stopLiveLocationTracking();

      if (!mounted) {
        return;
      }

      final String currency =
          latestData['currency']?.toString().trim().isNotEmpty == true
              ? latestData['currency'].toString().trim()
              : 'Rs.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Trip completed. Final ${finalDistanceKm.toStringAsFixed(2)} km • '
            '$currency ${finalFare.toStringAsFixed(0)} • '
            'Net $currency ${driverNetIncome.toStringAsFixed(2)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete trip: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRideStatus = false;
        });
      }
    }
  }

  Widget _onlineStatusCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverRef.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load driver status',
            message: snapshot.error.toString(),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> document =
            snapshot.data!;

        if (!document.exists) {
          return const _MessageCard(
            icon: Icons.person_off_rounded,
            title: 'Ride Driver profile not found',
            message: 'Please log in again or contact Admin.',
          );
        }

        final Map<String, dynamic> data =
            document.data() ?? <String, dynamic>{};

        final bool isApproved = data['isApproved'] == true;
        final bool isActive = data['isActive'] == true;
        final bool licenceVerified =
            data['drivingLicenseVerified'] == true;
        final bool isOnline = data['isOnline'] == true;
        final bool agreementAccepted =
            data['driverAgreementAccepted'] == true;
        final bool agreementReacceptRequired =
            data['driverAgreementReacceptRequired'] == true;
        final String agreementVersion =
            data['driverAgreementVersion']?.toString().trim() ?? '';
        final String approvalStatus =
            data['approvalStatus']?.toString().trim().toLowerCase() ?? '';
        final bool suspended =
            isApproved && !isActive && approvalStatus == 'suspended';
        final bool canGoOnline =
            isApproved && isActive && licenceVerified && !suspended;

        final String vehicleType =
            data['vehicleType']?.toString().trim() ?? '';
        final String vehicleNumber =
            data['vehicleNumber']?.toString().trim() ?? '';
        final String suspensionCurrency =
            data['suspensionCurrency']?.toString().trim().isNotEmpty == true
                ? data['suspensionCurrency'].toString().trim()
                : 'Rs.';
        final double commissionDue =
            _toDouble(data['outstandingRdCommission']) ?? 0.0;
        final double fine = _toDouble(data['suspensionFine']) ?? 0.0;
        final double totalDue =
            _toDouble(data['suspensionTotalDue']) ?? 0.0;
        final String suspensionReason =
            data['suspensionReason']?.toString().trim() ?? '';
        final String reactivationStatus =
            data['reactivationStatus']?.toString().trim().toLowerCase() ?? '';

        return Card(
          elevation: 1.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: (suspended
                              ? Colors.red
                              : isOnline
                                  ? Colors.green
                                  : Colors.grey)
                          .withValues(alpha: 0.14),
                      child: Icon(
                        suspended
                            ? Icons.block_rounded
                            : Icons.drive_eta_rounded,
                        color: suspended
                            ? Colors.red
                            : isOnline
                                ? Colors.green
                                : Colors.grey.shade700,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            suspended
                                ? 'Driver Account Suspended'
                                : isOnline
                                    ? 'Driver Online'
                                    : 'Driver Offline',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            <String>[vehicleType, vehicleNumber]
                                .where((String value) => value.isNotEmpty)
                                .join(' • '),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(
                      suspended
                          ? 'SUSPENDED'
                          : isOnline
                              ? 'ONLINE'
                              : 'OFFLINE',
                      suspended
                          ? Colors.red
                          : isOnline
                              ? Colors.green
                              : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (suspended) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (suspensionReason.isNotEmpty) ...<Widget>[
                          Text(
                            suspensionReason,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _suspensionAmountRow(
                          'RD Commission Due',
                          '$suspensionCurrency ${commissionDue.toStringAsFixed(2)}',
                        ),
                        _suspensionAmountRow(
                          'Late Fine',
                          '$suspensionCurrency ${fine.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 18),
                        _suspensionAmountRow(
                          'Total Due',
                          '$suspensionCurrency ${totalDue.toStringAsFixed(2)}',
                          strong: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reactivationStatus == 'pending_admin_review'
                              ? 'Payment submitted • Waiting for Admin approval'
                              : reactivationStatus == 'rejected'
                                  ? 'Previous reactivation request was rejected. You can submit corrected payment details.'
                                  : 'Pay the amount due and request reactivation to use RD Ride again.',
                          style: TextStyle(
                            color: reactivationStatus == 'pending_admin_review'
                                ? Colors.orange.shade800
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RideDriverReactivationPage(
                            driverId: _driverId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payments_rounded),
                    label: Text(
                      reactivationStatus == 'pending_admin_review'
                          ? 'View Reactivation Status'
                          : 'Pay / Request Reactivation',
                    ),
                  ),
                ] else if (!canGoOnline)
                  Text(
                    'Admin approval and driving licence verification are required before going online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _updatingOnlineStatus
                        ? null
                        : () => _setOnlineStatus(!isOnline),
                    icon: _updatingOnlineStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isOnline
                                ? Icons.toggle_off_rounded
                                : Icons.toggle_on_rounded,
                          ),
                    label: Text(
                      _updatingOnlineStatus
                          ? 'Updating...'
                          : isOnline
                              ? 'Go Offline'
                              : 'Go Online',
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (agreementAccepted && !agreementReacceptRequired
                            ? Colors.green
                            : Colors.orange)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (agreementAccepted && !agreementReacceptRequired
                              ? Colors.green
                              : Colors.orange)
                          .withValues(alpha: 0.20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.description_outlined,
                            color: agreementAccepted && !agreementReacceptRequired
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              agreementReacceptRequired
                                  ? 'Driver Agreement • Re-accept required'
                                  : agreementAccepted
                                      ? 'Driver Agreement • ${agreementVersion.isEmpty ? 'Accepted' : agreementVersion}'
                                      : 'Driver Agreement • Not recorded',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: agreementAccepted
                            ? () => _openMyDriverAgreement(data)
                            : null,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View My Accepted Agreement'),
                      ),
                    ],
                  ),
                ),
                if (_activeRideRequestId != null) ...<Widget>[
                  const SizedBox(height: 10),
                  const Text(
                    'Live GPS is active for your current ride.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _suspensionAmountRow(
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeRideMap(
    Map<String, dynamic> rideData,
  ) {
    return _RideDriverLiveRouteMap(
      driverId: _driverId,
      rideData: rideData,
    );
  }

  Widget _activeRideSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _allDriverRidesStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load active ride',
            message: snapshot.error.toString(),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeRides =
            (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .where(
          (QueryDocumentSnapshot<Map<String, dynamic>> document) {
            final String status = document
                    .data()['status']
                    ?.toString()
                    .trim()
                    .toLowerCase() ??
                '';
            return status == 'accepted' ||
                status == 'arrived' ||
                status == 'in_progress';
          },
        ).toList();

        if (activeRides.isEmpty) {
          return const SizedBox.shrink();
        }

        final QueryDocumentSnapshot<Map<String, dynamic>> ride =
            activeRides.first;
        final Map<String, dynamic> data = ride.data();
        final String status =
            data['status']?.toString().trim().toLowerCase() ?? 'accepted';
        final String pickup =
            data['pickupAddress']?.toString().trim() ?? '';
        final String destination =
            data['destinationAddress']?.toString().trim() ?? '';
        final String vehicleType =
            data['vehicleType']?.toString().trim() ?? '';
        final String customerName =
            data['customerName']?.toString().trim().isNotEmpty == true
                ? data['customerName'].toString().trim()
                : 'Customer';
        final String customerPhone =
            data['customerPhone']?.toString().trim() ?? '';
        final String driverName =
            data['driverName']?.toString().trim().isNotEmpty == true
                ? data['driverName'].toString().trim()
                : 'Ride Driver';
        final double? estimatedFare = data['estimatedFare'] is num
            ? (data['estimatedFare'] as num).toDouble()
            : double.tryParse(
                data['estimatedFare']?.toString().trim() ?? '',
              );
        final double? routeDistanceKm =
            data['routeDistanceKm'] is num
                ? (data['routeDistanceKm'] as num).toDouble()
                : double.tryParse(
                    data['routeDistanceKm']?.toString().trim() ?? '',
                  );
        final int? routeDurationMinutes =
            data['routeDurationMinutes'] is num
                ? (data['routeDurationMinutes'] as num).round()
                : int.tryParse(
                    data['routeDurationMinutes']?.toString().trim() ?? '',
                  );
        final String currency =
            data['currency']?.toString().trim().isNotEmpty == true
                ? data['currency'].toString().trim()
                : 'Rs.';
        final double? actualDistanceKm =
            _toDouble(data['actualDistanceKm']);
        final double? liveFare = _toDouble(data['liveFare']);
        final double? fareBaseFare = _toDouble(data['fareBaseFare']);
        final double? farePerKm = _toDouble(data['farePerKm']);
        final double? fareMinimumFare =
            _toDouble(data['fareMinimumFare']);
        final double rdCommissionPercent =
            _toDouble(data['rdCommissionPercent']) ?? 0.0;
        final double? estimatedRdCommission = estimatedFare == null
            ? null
            : estimatedFare * rdCommissionPercent / 100.0;
        final double? estimatedDriverIncome = estimatedFare == null
            ? null
            : (estimatedFare - (estimatedRdCommission ?? 0.0))
                .clamp(0.0, estimatedFare)
                .toDouble();
        final double? liveRdCommission = liveFare == null
            ? null
            : liveFare * rdCommissionPercent / 100.0;
        final double? liveDriverIncome = liveFare == null
            ? null
            : (liveFare - (liveRdCommission ?? 0.0))
                .clamp(0.0, liveFare)
                .toDouble();

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(
                        Icons.route_rounded,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Active Ride',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            vehicleType.isEmpty ? 'Ride' : vehicleType,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip(
                      status == 'in_progress'
                          ? 'IN PROGRESS'
                          : status == 'arrived'
                              ? 'ARRIVED'
                              : 'ACCEPTED',
                      status == 'in_progress'
                          ? Colors.blue
                          : status == 'arrived'
                              ? Colors.deepOrange
                              : Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _callCustomerPhone(customerPhone),
                              icon: const Icon(Icons.call_rounded),
                              label: const Text('Call Customer'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => RideChatPage(
                                      rideRequestId: ride.id,
                                      senderRole: 'driver',
                                      senderName: driverName,
                                      otherPartyName: customerName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                              ),
                              label: const Text('Chat'),
                            ),
                          ),
                        ],
                      ),
                      if (customerPhone.isEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        const Text(
                          'Customer phone is not saved. Ride Chat is available.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _updatingRideStatus
                      ? null
                      : () => _sendDriverSos(ride),
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text(
                    'SOS / Emergency',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 14),
                _locationRow(
                  icon: Icons.my_location_rounded,
                  label: 'Pickup',
                  value: pickup,
                ),
                const Divider(height: 24),
                _locationRow(
                  icon: Icons.location_on_rounded,
                  label: 'Destination',
                  value: destination,
                ),
                if (routeDistanceKm != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: '${routeDistanceKm.toStringAsFixed(1)} km',
                  ),
                ],
                if (routeDurationMinutes != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.timer_outlined,
                    label: 'Estimated time',
                    value: '$routeDurationMinutes min',
                  ),
                ],
                if (estimatedFare != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.payments_outlined,
                    label: 'Estimated Fare',
                    value:
                        '$currency ${estimatedFare.toStringAsFixed(0)}',
                  ),
                ],
                if (fareBaseFare != null &&
                    farePerKm != null &&
                    fareMinimumFare != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.calculate_outlined,
                    label: 'Fare Formula',
                    value:
                        '$currency ${fareBaseFare.toStringAsFixed(0)} + '
                        '$currency ${farePerKm.toStringAsFixed(0)}/km '
                        '(min $currency ${fareMinimumFare.toStringAsFixed(0)})',
                  ),
                ],
                if (estimatedRdCommission != null &&
                    estimatedDriverIncome != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.percent_rounded,
                    label:
                        'RD Commission (${rdCommissionPercent.toStringAsFixed(2)}%)',
                    value:
                        '$currency ${estimatedRdCommission.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _locationRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Estimated Driver Income',
                    value:
                        '$currency ${estimatedDriverIncome.toStringAsFixed(2)}',
                  ),
                ],
                if (status == 'in_progress' &&
                    actualDistanceKm != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.speed_rounded,
                    label: 'Actual Distance • LIVE',
                    value: '${actualDistanceKm.toStringAsFixed(2)} km',
                  ),
                ],
                if (status == 'in_progress' && liveFare != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Live Fare',
                    value: '$currency ${liveFare.toStringAsFixed(0)}',
                  ),
                ],
                if (status == 'in_progress' &&
                    liveRdCommission != null &&
                    liveDriverIncome != null) ...<Widget>[
                  const Divider(height: 24),
                  _locationRow(
                    icon: Icons.percent_rounded,
                    label: 'Live RD Commission',
                    value:
                        '$currency ${liveRdCommission.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _locationRow(
                    icon: Icons.wallet_rounded,
                    label: 'Live Driver Income',
                    value:
                        '$currency ${liveDriverIncome.toStringAsFixed(2)}',
                  ),
                ],
                const SizedBox(height: 16),
                _activeRideMap(data),
                const SizedBox(height: 16),
                if (status == 'accepted') ...<Widget>[
                  FilledButton.icon(
                    onPressed: _updatingRideStatus
                        ? null
                        : () => _markArrivedAtPickup(ride),
                    icon: const Icon(Icons.location_on_rounded),
                    label: const Text(
                      'I Have Arrived at Pickup',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _updatingRideStatus
                        ? null
                        : () => _cancelAcceptedRide(ride),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(
                      'Cancel Ride Before Start',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ] else if (status == 'arrived') ...<Widget>[
                  FilledButton.icon(
                    onPressed:
                        _updatingRideStatus ? null : () => _startTrip(ride),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Start Trip',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _updatingRideStatus
                        ? null
                        : () => _cancelAcceptedRide(ride),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(
                      'Cancel Ride Before Start',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed:
                        _updatingRideStatus ? null : () => _completeTrip(ride),
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text(
                      'Complete Trip',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Keep this screen open while driving. GPS, actual distance and live fare update together for both driver and customer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _requestsSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingRequestsStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _MessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Could not load ride requests',
            message: snapshot.error.toString(),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> requests =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        requests.sort(
          (
            QueryDocumentSnapshot<Map<String, dynamic>> first,
            QueryDocumentSnapshot<Map<String, dynamic>> second,
          ) {
            final Timestamp? firstTime =
                first.data()['createdAt'] is Timestamp
                    ? first.data()['createdAt'] as Timestamp
                    : null;
            final Timestamp? secondTime =
                second.data()['createdAt'] is Timestamp
                    ? second.data()['createdAt'] as Timestamp
                    : null;

            return (secondTime?.millisecondsSinceEpoch ?? 0).compareTo(
              firstTime?.millisecondsSinceEpoch ?? 0,
            );
          },
        );

        if (requests.isEmpty) {
          return const _MessageCard(
            icon: Icons.inbox_rounded,
            title: 'No pending ride requests',
            message: 'New customer ride requests will appear here.',
          );
        }

        return Column(
          children: requests
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> request) =>
                    Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RideRequestCard(
                    request: request,
                    actionsEnabled: !_updatingRideStatus &&
                        (_activeRideRequestId == null ||
                            _activeRideRequestId == request.id),
                    onAccept: () => _acceptRequest(context, request),
                    onReject: () => _rejectRequest(context, request),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_activeRideRequestId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the active ride before logging out.',
          ),
        ),
      );
      return;
    }

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Logout Ride Driver?'),
              content: const Text(
                'You will be taken back to the Ride Driver login page.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    await _stopLiveLocationTracking(clearCurrentRide: true);

    try {
      await _driverRef.update(
        <String, dynamic>{
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Logout still continues if offline status cannot be updated.
    }

    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const RideDriverAuthPage(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride Requests',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _driverId.isEmpty
                ? const _MessageCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Driver ID missing',
                    message: 'A valid ride driver ID is required.',
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _onlineStatusCard(),
                      const SizedBox(height: 18),
                      RideDriverPrivateRatingSummary(
                        driverId: _driverId,
                        title: 'My Customer Rating',
                        showRecentReviews: true,
                      ),
                      const SizedBox(height: 18),
                      RideDriverEarningsSummaryCard(
                        driverId: _driverId,
                        onViewHistory: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => RideDriverEarningsPage(
                                driverId: _driverId,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _activeRideSection(),
                      if (_activeRideRequestId != null)
                        const SizedBox(height: 18),
                      const Text(
                        'Incoming Ride Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _requestsSection(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _locationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
                value.isEmpty ? 'Not available' : value,
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
}


class _RideDriverLiveRouteMap extends StatefulWidget {
  const _RideDriverLiveRouteMap({
    required this.driverId,
    required this.rideData,
  });

  final String driverId;
  final Map<String, dynamic> rideData;

  @override
  State<_RideDriverLiveRouteMap> createState() =>
      _RideDriverLiveRouteMapState();
}

class _RideDriverLiveRouteMapState
    extends State<_RideDriverLiveRouteMap> {
  final MapController _mapController = MapController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _driverSubscription;

  LatLng? _driverLocation;
  LatLng? _pickup;
  LatLng? _destination;

  List<LatLng> _roadRoute = <LatLng>[];

  LatLng? _lastRouteFrom;
  LatLng? _lastRouteTo;
  DateTime? _lastRouteAt;

  bool _isLoadingRoute = false;
  String? _routeError;

  double? _routeDistanceKm;
  int? _routeDurationMinutes;

  String _primaryInstruction = 'Route ready';
  String _secondaryInstruction = '';
  String _primaryManeuver = 'straight';
  double? _nextTurnDistanceMeters;

  bool _mapReady = false;
  bool _followDriver = true;
  bool _headingUp = true;
  double _driverHeading = 0;

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
  }

  double _bearingBetween(
    LatLng from,
    LatLng to,
  ) {
    final double fromLat =
        from.latitude * math.pi / 180;
    final double toLat =
        to.latitude * math.pi / 180;
    final double deltaLng =
        (to.longitude - from.longitude) *
            math.pi /
            180;

    final double y =
        math.sin(deltaLng) * math.cos(toLat);
    final double x =
        math.cos(fromLat) * math.sin(toLat) -
            math.sin(fromLat) *
                math.cos(toLat) *
                math.cos(deltaLng);

    final double degrees =
        math.atan2(y, x) * 180 / math.pi;

    return (degrees + 360) % 360;
  }

  LatLng? _latLngFrom(
    dynamic latitude,
    dynamic longitude,
  ) {
    final double? lat = _asDouble(latitude);
    final double? lng = _asDouble(longitude);

    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(lat, lng);
  }

  String get _status =>
      widget.rideData['status']
          ?.toString()
          .trim()
          .toLowerCase() ??
      'accepted';

  LatLng? get _routeTarget {
    if (_status == 'in_progress') {
      return _destination ?? _pickup;
    }

    return _pickup ?? _destination;
  }

  String get _routeTargetLabel =>
      _status == 'in_progress'
          ? 'Destination'
          : 'Pickup';

  @override
  void initState() {
    super.initState();
    _readRideCoordinates();
    _listenToDriverLocation();
  }

  @override
  void didUpdateWidget(
    covariant _RideDriverLiveRouteMap oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final String oldStatus =
        oldWidget.rideData['status']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    final String newStatus = _status;

    final dynamic oldPickupLat =
        oldWidget.rideData['pickupLatitude'];
    final dynamic oldPickupLng =
        oldWidget.rideData['pickupLongitude'];
    final dynamic oldDestinationLat =
        oldWidget.rideData['destinationLatitude'];
    final dynamic oldDestinationLng =
        oldWidget.rideData['destinationLongitude'];

    if (oldStatus != newStatus ||
        oldPickupLat !=
            widget.rideData['pickupLatitude'] ||
        oldPickupLng !=
            widget.rideData['pickupLongitude'] ||
        oldDestinationLat !=
            widget.rideData['destinationLatitude'] ||
        oldDestinationLng !=
            widget.rideData['destinationLongitude']) {
      _readRideCoordinates();
      _lastRouteFrom = null;
      _lastRouteTo = null;
      _roadRoute = <LatLng>[];
      unawaited(
        _refreshRoadRoute(
          force: true,
        ),
      );
    }

    if (oldWidget.driverId != widget.driverId) {
      _driverSubscription?.cancel();
      _listenToDriverLocation();
    }
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    super.dispose();
  }

  void _readRideCoordinates() {
    _pickup = _latLngFrom(
      widget.rideData['pickupLatitude'],
      widget.rideData['pickupLongitude'],
    );

    _destination = _latLngFrom(
      widget.rideData['destinationLatitude'],
      widget.rideData['destinationLongitude'],
    );
  }

  void _listenToDriverLocation() {
    final String cleanDriverId =
        widget.driverId.trim();

    if (cleanDriverId.isEmpty) {
      return;
    }

    _driverSubscription = FirebaseFirestore.instance
        .collection('ride_drivers')
        .doc(cleanDriverId)
        .snapshots()
        .listen(
      (
        DocumentSnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final Map<String, dynamic> data =
            snapshot.data() ??
                <String, dynamic>{};

        final LatLng? nextLocation =
            _latLngFrom(
          data['latitude'] ?? data['lat'],
          data['longitude'] ?? data['lng'],
        );

        if (nextLocation == null) {
          return;
        }

        final LatLng? previousLocation =
            _driverLocation;
        double? movementHeading;

        if (previousLocation != null) {
          final double movedMeters =
              Geolocator.distanceBetween(
            previousLocation.latitude,
            previousLocation.longitude,
            nextLocation.latitude,
            nextLocation.longitude,
          );

          if (movedMeters >= 3) {
            movementHeading = _bearingBetween(
              previousLocation,
              nextLocation,
            );
          }
        }

        if (mounted) {
          setState(() {
            _driverLocation = nextLocation;
            if (movementHeading != null) {
              _driverHeading = movementHeading;
            }
          });
        } else {
          _driverLocation = nextLocation;
          if (movementHeading != null) {
            _driverHeading = movementHeading;
          }
        }

        _scheduleFollowDriverCamera();
        unawaited(_refreshRoadRoute());
      },
      onError: (_) {
        // Driver GPS errors are shown by the parent page.
      },
    );
  }

  void _scheduleFollowDriverCamera() {
    if (!_mapReady || !_followDriver) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady || !_followDriver) {
        return;
      }

      final LatLng? driver = _driverLocation;
      if (driver == null) {
        return;
      }

      final MapCamera camera = _mapController.camera;
      final double zoom =
          camera.zoom < 16 ? 16 : camera.zoom;
      final double rotation =
          _headingUp ? _driverHeading : 0;

      _mapController.moveAndRotate(
        driver,
        zoom,
        rotation,
      );
    });
  }

  void _enableFollowDriver() {
    if (!_followDriver) {
      setState(() {
        _followDriver = true;
      });
    }

    _scheduleFollowDriverCamera();
  }

  void _toggleHeadingUp() {
    setState(() {
      _headingUp = !_headingUp;
    });

    if (_followDriver) {
      _scheduleFollowDriverCamera();
    } else {
      _mapController.rotate(
        _headingUp ? _driverHeading : 0,
      );
    }
  }

  void _fitWholeRoute() {
    final List<LatLng> points =
        _roadRoute.isNotEmpty
            ? _roadRoute
            : <LatLng>[
                if (_driverLocation != null)
                  _driverLocation!,
                if (_pickup != null) _pickup!,
                if (_destination != null)
                  _destination!,
              ];

    if (points.isEmpty) {
      return;
    }

    if (_followDriver) {
      setState(() {
        _followDriver = false;
      });
    }

    if (points.length == 1) {
      _mapController.moveAndRotate(
        points.first,
        16,
        0,
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(54),
      ),
    );
  }

  String _formatTurnDistance(
    double? meters,
  ) {
    if (meters == null ||
        !meters.isFinite ||
        meters <= 0) {
      return '';
    }

    if (meters < 950) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  bool _sameTarget(
    LatLng? first,
    LatLng? second,
  ) {
    if (first == null || second == null) {
      return false;
    }

    return Geolocator.distanceBetween(
          first.latitude,
          first.longitude,
          second.latitude,
          second.longitude,
        ) <
        5;
  }

  bool _shouldRefreshRoute({
    required LatLng from,
    required LatLng to,
    required bool force,
  }) {
    if (force || _roadRoute.isEmpty) {
      return true;
    }

    if (!_sameTarget(_lastRouteTo, to)) {
      return true;
    }

    final LatLng? lastFrom = _lastRouteFrom;

    if (lastFrom == null) {
      return true;
    }

    final double movedMeters =
        Geolocator.distanceBetween(
      lastFrom.latitude,
      lastFrom.longitude,
      from.latitude,
      from.longitude,
    );

    final DateTime? lastAt = _lastRouteAt;
    final bool enoughTimePassed =
        lastAt == null ||
        DateTime.now()
                .difference(lastAt)
                .inSeconds >=
            12;

    return movedMeters >= 35 &&
        enoughTimePassed;
  }

  String _cardinalDirection(
    double bearing,
  ) {
    final double normalized =
        ((bearing % 360) + 360) % 360;

    if (normalized >= 337.5 ||
        normalized < 22.5) {
      return 'north';
    }
    if (normalized < 67.5) {
      return 'north-east';
    }
    if (normalized < 112.5) {
      return 'east';
    }
    if (normalized < 157.5) {
      return 'south-east';
    }
    if (normalized < 202.5) {
      return 'south';
    }
    if (normalized < 247.5) {
      return 'south-west';
    }
    if (normalized < 292.5) {
      return 'west';
    }
    return 'north-west';
  }

  String _instructionForStep(
    Map<String, dynamic> step,
  ) {
    final Map<String, dynamic> maneuver =
        step['maneuver'] is Map
            ? Map<String, dynamic>.from(
                step['maneuver'] as Map,
              )
            : <String, dynamic>{};

    final String type =
        maneuver['type']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';
    final String modifier =
        maneuver['modifier']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    final double bearingAfter =
        _asDouble(
              maneuver['bearing_after'],
            ) ??
            0;

    final String roadName =
        step['name']
                ?.toString()
                .trim() ??
            '';

    String instruction;

    switch (type) {
      case 'depart':
        instruction =
            'Head ${_cardinalDirection(bearingAfter)}';
        break;
      case 'arrive':
        instruction =
            'Arrive at $_routeTargetLabel';
        break;
      case 'turn':
      case 'end of road':
        instruction = modifier.isEmpty
            ? 'Turn'
            : 'Turn ${modifier.replaceAll('-', ' ')}';
        break;
      case 'continue':
      case 'new name':
        instruction = modifier.isEmpty
            ? 'Continue straight'
            : 'Continue ${modifier.replaceAll('-', ' ')}';
        break;
      case 'merge':
        instruction = modifier.isEmpty
            ? 'Merge'
            : 'Merge ${modifier.replaceAll('-', ' ')}';
        break;
      case 'fork':
        instruction = modifier.isEmpty
            ? 'Keep ahead'
            : 'Keep ${modifier.replaceAll('-', ' ')}';
        break;
      case 'roundabout':
      case 'rotary':
        instruction =
            'Enter the roundabout';
        break;
      case 'exit roundabout':
      case 'exit rotary':
        instruction =
            'Exit the roundabout';
        break;
      default:
        instruction = modifier.isEmpty
            ? 'Continue on route'
            : 'Go ${modifier.replaceAll('-', ' ')}';
        break;
    }

    if (roadName.isNotEmpty &&
        type != 'arrive') {
      return '$instruction onto $roadName';
    }

    return instruction;
  }

  String _maneuverForStep(
    Map<String, dynamic> step,
  ) {
    final dynamic rawManeuver =
        step['maneuver'];

    if (rawManeuver is! Map) {
      return 'straight';
    }

    final String type =
        rawManeuver['type']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';
    final String modifier =
        rawManeuver['modifier']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    if (type == 'arrive') {
      return 'arrive';
    }

    if (type == 'roundabout' ||
        type == 'rotary' ||
        type == 'exit roundabout' ||
        type == 'exit rotary') {
      return 'roundabout';
    }

    if (modifier.contains('left')) {
      return 'left';
    }

    if (modifier.contains('right')) {
      return 'right';
    }

    return 'straight';
  }

  IconData _maneuverIcon(
    String maneuver,
  ) {
    switch (maneuver) {
      case 'left':
        return Icons.turn_left_rounded;
      case 'right':
        return Icons.turn_right_rounded;
      case 'roundabout':
        return Icons.sync_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }

  Future<void> _refreshRoadRoute({
    bool force = false,
  }) async {
    if (_isLoadingRoute) {
      return;
    }

    final LatLng? from = _driverLocation;
    final LatLng? to = _routeTarget;

    if (from == null || to == null) {
      return;
    }

    if (!_shouldRefreshRoute(
      from: from,
      to: to,
      force: force,
    )) {
      return;
    }

    _isLoadingRoute = true;

    if (mounted) {
      setState(() {
        _routeError = null;
      });
    }

    try {
      final Uri uri = Uri.parse(
        'https://router.project-osrm.org/'
        'route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full'
        '&geometries=geojson'
        '&steps=true',
      );

      final Map<String, String> headers =
          <String, String>{
        'Accept': 'application/json',
      };

      if (!foundation.kIsWeb) {
        headers['User-Agent'] =
            'RDOnlineShop/1.0';
      }

      final http.Response response =
          await http
              .get(
                uri,
                headers: headers,
              )
              .timeout(
                const Duration(
                  seconds: 12,
                ),
              );

      if (response.statusCode != 200) {
        throw StateError(
          'Road route service returned '
          '${response.statusCode}.',
        );
      }

      final dynamic decoded =
          jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw StateError(
          'Road route response is invalid.',
        );
      }

      final dynamic routes =
          decoded['routes'];

      if (routes is! List<dynamic> ||
          routes.isEmpty) {
        throw StateError(
          'No road route was found.',
        );
      }

      final dynamic firstRoute =
          routes.first;

      if (firstRoute
          is! Map<String, dynamic>) {
        throw StateError(
          'Road route data is invalid.',
        );
      }

      final dynamic geometry =
          firstRoute['geometry'];

      if (geometry
          is! Map<String, dynamic>) {
        throw StateError(
          'Road route geometry is missing.',
        );
      }

      final dynamic coordinates =
          geometry['coordinates'];

      if (coordinates
          is! List<dynamic>) {
        throw StateError(
          'Road route coordinates are missing.',
        );
      }

      final List<LatLng> routePoints =
          <LatLng>[];

      for (final dynamic item
          in coordinates) {
        if (item is! List<dynamic> ||
            item.length < 2) {
          continue;
        }

        final double? longitude =
            _asDouble(item[0]);
        final double? latitude =
            _asDouble(item[1]);

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        routePoints.add(
          LatLng(
            latitude,
            longitude,
          ),
        );
      }

      if (routePoints.length < 2) {
        throw StateError(
          'Road route does not contain enough points.',
        );
      }

      final double? distanceMeters =
          _asDouble(
        firstRoute['distance'],
      );
      final double? durationSeconds =
          _asDouble(
        firstRoute['duration'],
      );

      String primaryInstruction =
          'Continue toward $_routeTargetLabel';
      String secondaryInstruction = '';
      String primaryManeuver =
          'straight';
      double? nextTurnDistanceMeters;

      final dynamic legsRaw =
          firstRoute['legs'];

      if (legsRaw is List<dynamic> &&
          legsRaw.isNotEmpty &&
          legsRaw.first is Map) {
        final Map<String, dynamic> firstLeg =
            Map<String, dynamic>.from(
          legsRaw.first as Map,
        );
        final dynamic stepsRaw =
            firstLeg['steps'];

        if (stepsRaw is List<dynamic> &&
            stepsRaw.isNotEmpty) {
          final List<Map<String, dynamic>>
              navigationSteps =
              stepsRaw
                  .whereType<Map>()
                  .map(
                    (Map step) =>
                        Map<String, dynamic>.from(
                      step,
                    ),
                  )
                  .toList();

          if (navigationSteps.isNotEmpty) {
            primaryInstruction =
                _instructionForStep(
              navigationSteps.first,
            );
            primaryManeuver =
                _maneuverForStep(
              navigationSteps.first,
            );
            nextTurnDistanceMeters =
                _asDouble(
              navigationSteps.first['distance'],
            );
          }

          if (navigationSteps.length > 1) {
            secondaryInstruction =
                _instructionForStep(
              navigationSteps[1],
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _roadRoute = routePoints;
        _lastRouteFrom = from;
        _lastRouteTo = to;
        _lastRouteAt = DateTime.now();

        _routeDistanceKm =
            distanceMeters == null
                ? null
                : distanceMeters / 1000;

        _routeDurationMinutes =
            durationSeconds == null
                ? null
                : (durationSeconds / 60)
                    .ceil();

        _primaryInstruction =
            primaryInstruction;
        _secondaryInstruction =
            secondaryInstruction;
        _primaryManeuver =
            primaryManeuver;
        _nextTurnDistanceMeters =
            nextTurnDistanceMeters;

        _routeError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _routeError =
            error.toString();
      });
    } finally {
      _isLoadingRoute = false;
    }
  }

  void _zoomIn() {
    final MapCamera camera = _mapController.camera;
    final double nextZoom =
        camera.zoom >= 19 ? 19 : camera.zoom + 1;

    _mapController.move(
      camera.center,
      nextZoom,
    );
  }

  void _zoomOut() {
    final MapCamera camera = _mapController.camera;
    final double nextZoom =
        camera.zoom <= 2 ? 2 : camera.zoom - 1;

    _mapController.move(
      camera.center,
      nextZoom,
    );
  }

  void _recenterOnDriver() {
    _enableFollowDriver();
  }

  Future<void> _open3DNavigation() async {
    final LatLng? target = _routeTarget;

    if (target == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Destination GPS is not available yet.',
          ),
        ),
      );
      return;
    }

    final LatLng? origin = _driverLocation;

    final Map<String, String> query = <String, String>{
      'api': '1',
      'destination': '${target.latitude},${target.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    };

    if (origin != null) {
      query['origin'] =
          '${origin.latitude},${origin.longitude}';
    }

    final Uri uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      query,
    );

    try {
      final bool opened = await launchUrl(
        uri,
        mode: foundation.kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Google Maps navigation.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open navigation: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? driver =
        _driverLocation;

    final List<LatLng> fitPoints =
        _roadRoute.isNotEmpty
            ? _roadRoute
            : <LatLng>[
                if (driver != null)
                  driver,
                if (_pickup != null)
                  _pickup!,
                if (_destination != null)
                  _destination!,
              ];

    if (fitPoints.isEmpty) {
      return const _MessageCard(
        icon: Icons.map_outlined,
        title: 'Live map is waiting',
        message:
            'Driver, pickup, or destination GPS is not available yet.',
      );
    }

    final String routeSummary =
        _routeDistanceKm != null
            ? '${_routeDistanceKm!.toStringAsFixed(1)} km'
                '${_routeDurationMinutes != null ? ' • about ${_routeDurationMinutes!} min' : ''}'
            : '';

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              14,
              12,
              14,
              10,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  driver != null
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  color: driver != null
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        driver != null
                            ? 'Live GPS + road route connected'
                            : 'Waiting for your GPS location',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Routing to $_routeTargetLabel'
                        '${routeSummary.isEmpty ? '' : ' • $routeSummary'}',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingRoute)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
          if (_routeError != null &&
              _roadRoute.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                0,
                14,
                10,
              ),
              child: Text(
                'Road route is temporarily unavailable. '
                'Live GPS marker is still working.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.fromLTRB(
              10,
              0,
              10,
              10,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _maneuverIcon(
                      _primaryManeuver,
                    ),
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_formatTurnDistance(
                            _nextTurnDistanceMeters,
                          ).isNotEmpty) ...<Widget>[
                        Text(
                          _formatTurnDistance(
                            _nextTurnDistanceMeters,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        _primaryInstruction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      if (_secondaryInstruction
                          .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'Then $_secondaryInstruction',
                          style: const TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 340,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: fitPoints.first,
                      initialZoom: 14,
                      initialCameraFit: fitPoints.length > 1
                          ? CameraFit.coordinates(
                              coordinates: fitPoints,
                              padding: const EdgeInsets.all(48),
                            )
                          : null,
                      minZoom: 2,
                      maxZoom: 19,
                      interactionOptions:
                          const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                      onMapReady: () {
                        _mapReady = true;
                        _scheduleFollowDriverCamera();
                      },
                      onPositionChanged: (
                        MapCamera _,
                        bool hasGesture,
                      ) {
                        if (hasGesture && _followDriver) {
                          setState(() {
                            _followDriver = false;
                          });
                        }
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.rd.onlineshop',
                      ),
                      if (_roadRoute.length >= 2)
                        PolylineLayer(
                          polylines: <Polyline>[
                            Polyline(
                              points: _roadRoute,
                              strokeWidth: 6,
                              color: const Color(
                                0xFF1565C0,
                              ),
                              borderStrokeWidth: 2,
                              borderColor: Colors.white,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: <Marker>[
                          if (_pickup != null)
                            Marker(
                              point: _pickup!,
                              width: 48,
                              height: 48,
                              child:
                                  const _RideDriverMapPin(
                                icon: Icons
                                    .my_location_rounded,
                                color: Colors.blue,
                                tooltip: 'Pickup',
                              ),
                            ),
                          if (_destination != null)
                            Marker(
                              point: _destination!,
                              width: 48,
                              height: 48,
                              child:
                                  const _RideDriverMapPin(
                                icon: Icons
                                    .location_on_rounded,
                                color: Colors.red,
                                tooltip: 'Destination',
                              ),
                            ),
                          if (driver != null)
                            Marker(
                              point: driver,
                              width: 56,
                              height: 56,
                              child:
                                  const _RideDriverMapPin(
                                icon: Icons
                                    .two_wheeler_rounded,
                                color: Colors.green,
                                tooltip:
                                    'Your live location',
                              ),
                            ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions:
                            <SourceAttribution>[
                          TextSourceAttribution(
                            'OpenStreetMap contributors',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: <Widget>[
                      _MapRoundButton(
                        tooltip: 'Zoom in',
                        icon: Icons.add_rounded,
                        onPressed: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _MapRoundButton(
                        tooltip: 'Zoom out',
                        icon: Icons.remove_rounded,
                        onPressed: _zoomOut,
                      ),
                      const SizedBox(height: 8),
                      _MapRoundButton(
                        tooltip: _followDriver
                            ? 'Following driver'
                            : 'Follow driver',
                        icon: _followDriver
                            ? Icons.gps_fixed_rounded
                            : Icons.my_location_rounded,
                        onPressed: _recenterOnDriver,
                        active: _followDriver,
                      ),
                      const SizedBox(height: 8),
                      _MapRoundButton(
                        tooltip: _headingUp
                            ? 'Heading-up mode'
                            : 'North-up mode',
                        icon: _headingUp
                            ? Icons.navigation_rounded
                            : Icons.explore_rounded,
                        onPressed: _toggleHeadingUp,
                        active: _headingUp,
                      ),
                      const SizedBox(height: 8),
                      _MapRoundButton(
                        tooltip: 'Fit full route',
                        icon: Icons.zoom_out_map_rounded,
                        onPressed: _fitWholeRoute,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              4,
            ),
            child: FilledButton.icon(
              onPressed: _open3DNavigation,
              icon: const Icon(
                Icons.navigation_rounded,
              ),
              label: const Text(
                'Open 3D Turn-by-Turn Navigation',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              4,
              14,
              12,
            ),
            child: Text(
              'In-app map supports auto-follow, heading-up / north-up, rotate, pinch/scroll zoom, drag, road route, and next-turn guidance. '
              'Manual map movement pauses follow; tap the GPS button to resume. For true 3D/tilt, voice guidance, and lane guidance, open Google Maps.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? const Color(0xFFE3F2FD)
            : Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              icon,
              color: const Color(0xFF1565C0),
            ),
          ),
        ),
      ),
    );
  }
}

class _RideDriverMapPin extends StatelessWidget {
  const _RideDriverMapPin({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 27,
        ),
      ),
    );
  }
}

class _RideRequestCard extends StatelessWidget {
  const _RideRequestCard({
    required this.request,
    required this.actionsEnabled,
    required this.onAccept,
    required this.onReject,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final bool actionsEnabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = request.data();

    final String vehicleType =
        data['vehicleType']?.toString().trim() ?? '';
    final String pickupAddress =
        data['pickupAddress']?.toString().trim() ?? '';
    final String destinationAddress =
        data['destinationAddress']?.toString().trim() ?? '';
    final String customerId =
        data['customerId']?.toString().trim() ?? '';
    final double? estimatedFare = data['estimatedFare'] is num
        ? (data['estimatedFare'] as num).toDouble()
        : double.tryParse(
            data['estimatedFare']?.toString().trim() ?? '',
          );
    final double? routeDistanceKm =
        data['routeDistanceKm'] is num
            ? (data['routeDistanceKm'] as num).toDouble()
            : double.tryParse(
                data['routeDistanceKm']?.toString().trim() ?? '',
              );
    final int? routeDurationMinutes =
        data['routeDurationMinutes'] is num
            ? (data['routeDurationMinutes'] as num).round()
            : int.tryParse(
                data['routeDurationMinutes']?.toString().trim() ?? '',
              );
    final String currency =
        data['currency']?.toString().trim().isNotEmpty == true
            ? data['currency'].toString().trim()
            : 'Rs.';
    final double? fareBaseFare = data['fareBaseFare'] is num
        ? (data['fareBaseFare'] as num).toDouble()
        : double.tryParse(
            data['fareBaseFare']?.toString().trim() ?? '',
          );
    final double? farePerKm = data['farePerKm'] is num
        ? (data['farePerKm'] as num).toDouble()
        : double.tryParse(
            data['farePerKm']?.toString().trim() ?? '',
          );
    final double? fareMinimumFare = data['fareMinimumFare'] is num
        ? (data['fareMinimumFare'] as num).toDouble()
        : double.tryParse(
            data['fareMinimumFare']?.toString().trim() ?? '',
          );

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 27,
                  child: Icon(
                    Icons.person_pin_circle_rounded,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        vehicleType.isEmpty
                            ? 'Ride Request'
                            : '$vehicleType Ride Request',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customerId.isEmpty
                            ? 'Customer'
                            : 'Customer: $customerId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _cardLocationRow(
              icon: Icons.my_location_rounded,
              label: 'Pickup',
              value: pickupAddress,
            ),
            const Divider(height: 24),
            _cardLocationRow(
              icon: Icons.location_on_rounded,
              label: 'Destination',
              value: destinationAddress,
            ),
            if (routeDistanceKm != null) ...<Widget>[
              const Divider(height: 24),
              _cardLocationRow(
                icon: Icons.route_rounded,
                label: 'Distance',
                value: '${routeDistanceKm.toStringAsFixed(1)} km',
              ),
            ],
            if (routeDurationMinutes != null) ...<Widget>[
              const Divider(height: 24),
              _cardLocationRow(
                icon: Icons.timer_outlined,
                label: 'Estimated time',
                value: '$routeDurationMinutes min',
              ),
            ],
            if (estimatedFare != null) ...<Widget>[
              const Divider(height: 24),
              _cardLocationRow(
                icon: Icons.payments_outlined,
                label: 'Estimated Fare',
                value:
                    '$currency ${estimatedFare.toStringAsFixed(0)}',
              ),
            ],
            if (fareBaseFare != null &&
                farePerKm != null &&
                fareMinimumFare != null) ...<Widget>[
              const Divider(height: 24),
              _cardLocationRow(
                icon: Icons.calculate_outlined,
                label: 'Fare Formula',
                value:
                    '$currency ${fareBaseFare.toStringAsFixed(0)} + '
                    '$currency ${farePerKm.toStringAsFixed(0)}/km '
                    '(min $currency ${fareMinimumFare.toStringAsFixed(0)})',
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionsEnabled ? onReject : null,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionsEnabled ? onAccept : null,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            if (!actionsEnabled) ...<Widget>[
              const SizedBox(height: 8),
              const Text(
                'Complete the current ride before accepting another request.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardLocationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
                value.isEmpty ? 'Not available' : value,
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
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 46, color: Colors.grey.shade600),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripStartOtpDialog extends StatefulWidget {
  const _TripStartOtpDialog();

  @override
  State<_TripStartOtpDialog> createState() => _TripStartOtpDialogState();
}

class _TripStartOtpDialogState extends State<_TripStartOtpDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.password_rounded,
        size: 42,
      ),
      title: const Text('Trip Start OTP'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Ask the customer for the 6-digit Trip Start OTP shown on their Track Ride screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
              decoration: const InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (String? value) {
                final String otp = value?.trim() ?? '';
                if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
                  return 'Enter the 6-digit OTP.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _verify(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _verify,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Verify & Start'),
        ),
      ],
    );
  }
}

