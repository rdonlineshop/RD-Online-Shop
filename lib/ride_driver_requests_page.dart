import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'ride_driver_auth_page.dart';

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

class _RideDriverRequestsPageState
    extends State<RideDriverRequestsPage> {
  bool _updatingOnlineStatus = false;

  CollectionReference<Map<String, dynamic>>
      get _rideRequests =>
          FirebaseFirestore.instance
              .collection('ride_requests');

  DocumentReference<Map<String, dynamic>>
      get _driverRef =>
          FirebaseFirestore.instance
              .collection('ride_drivers')
              .doc(widget.driverId.trim());

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _requestsStream() {
    return _rideRequests
        .where(
          'driverId',
          isEqualTo: widget.driverId.trim(),
        )
        .where(
          'status',
          isEqualTo: 'pending',
        )
        .snapshots();
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

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is required to go online.',
          ),
        ),
      );
      return null;
    }

    if (permission ==
        LocationPermission.deniedForever) {
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
            onPressed: () {
              Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> _setOnlineStatus(
    bool goOnline,
  ) async {
    if (_updatingOnlineStatus) {
      return;
    }

    setState(() {
      _updatingOnlineStatus = true;
    });

    try {
      if (goOnline) {
        final Position? position =
            await _getCurrentPosition();

        if (position == null) {
          return;
        }

        await _driverRef.update(
          <String, dynamic>{
            'isOnline': true,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'locationUpdatedAt':
                FieldValue.serverTimestamp(),
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
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
        await _driverRef.update(
          <String, dynamic>{
            'isOnline': false,
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
        );

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are offline.',
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
            'Could not update online status: $error',
          ),
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
    QueryDocumentSnapshot<Map<String, dynamic>>
        request,
  ) async {
    try {
      await request.reference.update(
        <String, dynamic>{
          'status': 'accepted',
          'driverResponse': 'accepted',
          'acceptedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride request accepted.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not accept ride request: $error',
          ),
        ),
      );
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>>
        request,
  ) async {
    try {
      await request.reference.update(
        <String, dynamic>{
          'status': 'rejected',
          'driverResponse': 'rejected',
          'rejectedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ride request rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not reject ride request: $error',
          ),
        ),
      );
    }
  }

  Widget _onlineStatusCard() {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: _driverRef.snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                DocumentSnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Text(
                'Could not load driver status: ${snapshot.error}',
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
          );
        }

        final DocumentSnapshot<
                Map<String, dynamic>>
            document = snapshot.data!;

        if (!document.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Ride Driver profile was not found.',
              ),
            ),
          );
        }

        final Map<String, dynamic> data =
            document.data() ??
                <String, dynamic>{};

        final bool isApproved =
            data['isApproved'] == true;
        final bool isActive =
            data['isActive'] == true;
        final bool licenceVerified =
            data['drivingLicenseVerified'] ==
                true;
        final bool isOnline =
            data['isOnline'] == true;

        final String vehicleType =
            data['vehicleType']
                    ?.toString()
                    .trim() ??
                '';
        final String vehicleNumber =
            data['vehicleNumber']
                    ?.toString()
                    .trim() ??
                '';

        final bool canGoOnline =
            isApproved &&
                isActive &&
                licenceVerified;

        return Card(
          elevation: 1.5,
          child: Padding(
            padding:
                const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: isOnline
                          ? Colors.green
                              .withValues(
                                alpha: 0.14,
                              )
                          : Colors.grey
                              .withValues(
                                alpha: 0.14,
                              ),
                      child: Icon(
                        Icons.drive_eta_rounded,
                        color: isOnline
                            ? Colors.green
                            : Colors.grey.shade700,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          Text(
                            isOnline
                                ? 'Driver Online'
                                : 'Driver Offline',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            <String>[
                              vehicleType,
                              vehicleNumber,
                            ]
                                .where(
                                  (
                                    String value,
                                  ) =>
                                      value
                                          .isNotEmpty,
                                )
                                .join(' • '),
                            style: TextStyle(
                              color: Colors
                                  .grey.shade700,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: isOnline
                            ? Colors.green
                                .withValues(
                                  alpha: 0.12,
                                )
                            : Colors.grey
                                .withValues(
                                  alpha: 0.12,
                                ),
                        borderRadius:
                            BorderRadius
                                .circular(16),
                      ),
                      child: Text(
                        isOnline
                            ? 'ONLINE'
                            : 'OFFLINE',
                        style: TextStyle(
                          color: isOnline
                              ? Colors.green
                              : Colors
                                  .grey.shade700,
                          fontSize: 11.5,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!canGoOnline)
                  Container(
                    padding:
                        const EdgeInsets
                            .all(12),
                    decoration:
                        BoxDecoration(
                      color: Colors.orange
                          .withValues(
                            alpha: 0.10,
                          ),
                      borderRadius:
                          BorderRadius
                              .circular(12),
                    ),
                    child: const Text(
                      'Admin approval, active account and verified driving licence are required before going online.',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (!canGoOnline)
                  const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _updatingOnlineStatus ||
                              (!canGoOnline &&
                                  !isOnline)
                          ? null
                          : () {
                              _setOnlineStatus(
                                !isOnline,
                              );
                            },
                  icon: _updatingOnlineStatus
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isOnline
                              ? Icons
                                  .toggle_off_rounded
                              : Icons
                                  .my_location_rounded,
                        ),
                  label: Text(
                    _updatingOnlineStatus
                        ? 'Please wait...'
                        : isOnline
                            ? 'Go Offline'
                            : 'Go Online with GPS',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                if (isOnline) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Your current GPS location is available to the nearby-driver search while you are online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 12.5,
                      height: 1.3,
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

  Widget _requestsSection() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _requestsStream(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _MessageCard(
            icon:
                Icons.error_outline_rounded,
            title:
                'Could not load ride requests',
            message:
                snapshot.error.toString(),
          );
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            requests =
            snapshot.data?.docs ??
                <QueryDocumentSnapshot<
                    Map<String, dynamic>>>[];

        requests.sort(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                first,
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                second,
          ) {
            final Timestamp? firstTime =
                first.data()['createdAt']
                        is Timestamp
                    ? first.data()['createdAt']
                        as Timestamp
                    : null;

            final Timestamp? secondTime =
                second.data()['createdAt']
                        is Timestamp
                    ? second.data()['createdAt']
                        as Timestamp
                    : null;

            return (secondTime
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
              firstTime
                      ?.millisecondsSinceEpoch ??
                  0,
            );
          },
        );

        if (requests.isEmpty) {
          return const _MessageCard(
            icon: Icons.inbox_rounded,
            title:
                'No pending ride requests',
            message:
                'New customer ride requests will appear here.',
          );
        }

        return Column(
          children: requests
              .map(
                (
                  QueryDocumentSnapshot<
                          Map<String, dynamic>>
                      request,
                ) =>
                    Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child:
                      _RideRequestCard(
                    request: request,
                    onAccept: () =>
                        _acceptRequest(
                      context,
                      request,
                    ),
                    onReject: () =>
                        _rejectRequest(
                      context,
                      request,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _logout() async {
    final bool confirmed =
        await showDialog<bool>(
              context: context,
              builder: (
                BuildContext dialogContext,
              ) {
                return AlertDialog(
                  title: const Text(
                    'Logout Ride Driver?',
                  ),
                  content: const Text(
                    'You will be taken back to the Ride Driver login page.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          false,
                        );
                      },
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          true,
                        );
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                      ),
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

    try {
      await _driverRef.update(
        <String, dynamic>{
          'isOnline': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      // Logout should still continue even if
      // the offline status update fails.
    }

    await FirebaseAuth.instance.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            const RideDriverAuthPage(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cleanDriverId =
        widget.driverId.trim();

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Ride Requests',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 820,
            ),
            child: cleanDriverId.isEmpty
                ? const _MessageCard(
                    icon: Icons
                        .error_outline_rounded,
                    title:
                        'Driver ID missing',
                    message:
                        'A valid ride driver ID is required.',
                  )
                : ListView(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    children: <Widget>[
                      _onlineStatusCard(),
                      const SizedBox(
                        height: 18,
                      ),
                      const Text(
                        'Incoming Ride Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      _requestsSection(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RideRequestCard
    extends StatelessWidget {
  const _RideRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final QueryDocumentSnapshot<
      Map<String, dynamic>> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data =
        request.data();

    final String vehicleType =
        data['vehicleType']
                ?.toString()
                .trim() ??
            '';
    final String pickupAddress =
        data['pickupAddress']
                ?.toString()
                .trim() ??
            '';
    final String destinationAddress =
        data['destinationAddress']
                ?.toString()
                .trim() ??
            '';
    final String customerId =
        data['customerId']
                ?.toString()
                .trim() ??
            '';

    return Card(
      elevation: 1.5,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const CircleAvatar(
                  radius: 27,
                  child: Icon(
                    Icons
                        .person_pin_circle_rounded,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      Text(
                        vehicleType.isEmpty
                            ? 'Ride Request'
                            : '$vehicleType Ride Request',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        customerId.isEmpty
                            ? 'Customer'
                            : 'Customer: $customerId',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: TextStyle(
                          color: Colors
                              .grey.shade700,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.orange
                        .withValues(
                          alpha: 0.12,
                        ),
                    borderRadius:
                        BorderRadius
                            .circular(16),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _locationRow(
              icon:
                  Icons.my_location_rounded,
              label: 'Pickup',
              value: pickupAddress,
            ),
            const Divider(height: 24),
            _locationRow(
              icon:
                  Icons.location_on_rounded,
              label: 'Destination',
              value:
                  destinationAddress,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                    label: const Text(
                      'Accept',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color:
              const Color(0xFF1565C0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value.isEmpty
                    ? '-'
                    : value,
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w700,
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
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 48,
                  color: const Color(
                    0xFF1565C0,
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                Text(
                  title,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  message,
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors
                        .grey.shade700,
                    height: 1.35,
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
