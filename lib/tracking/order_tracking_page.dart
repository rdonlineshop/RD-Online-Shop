import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../order_data.dart';

class OrderTrackingPage extends StatefulWidget {
  final String orderId;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingPage> createState() =>
      _OrderTrackingPageState();
}

class _OrderTrackingPageState
    extends State<OrderTrackingPage> {
  final MapController _mapController =
      MapController();

  bool _mapReady = false;

  // =========================================================
  // DOUBLE CONVERTER
  // =========================================================

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  // =========================================================
  // CUSTOMER LOCATION
  // =========================================================

  LatLng? _customerPoint(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _toDouble(
      order['customerLat'] ??
          order['latitude'],
    );

    final double? longitude =
        _toDouble(
      order['customerLng'] ??
          order['longitude'],
    );

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // =========================================================
  // DRIVER LOCATION
  // =========================================================

  LatLng? _driverPoint(
    Map<String, dynamic> order,
  ) {
    final double? latitude =
        _toDouble(
      order['driverLat'],
    );

    final double? longitude =
        _toDouble(
      order['driverLng'],
    );

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // =========================================================
  // SELLER IDS
  // =========================================================

  List<String> _sellerIds(
    Map<String, dynamic> order,
  ) {
    final Set<String> result =
        <String>{};

    final dynamic savedIds =
        order['sellerIds'];

    if (savedIds is List) {
      for (final dynamic value
          in savedIds) {
        final String id =
            value.toString().trim();

        if (id.isNotEmpty) {
          result.add(id);
        }
      }
    }

    final dynamic items =
        order['items'];

    if (items is List) {
      for (final dynamic item
          in items) {
        if (item is! Map) {
          continue;
        }

        final String id =
            item['sellerId']
                    ?.toString()
                    .trim() ??
                '';

        if (id.isNotEmpty) {
          result.add(id);
        }
      }
    }

    return result.toList();
  }

  // =========================================================
  // SELLER LOCATION STREAM
  // =========================================================

  Stream<List<_SellerMapLocation>>
      _sellerLocationsStream(
    List<String> sellerIds,
  ) {
    final List<String> cleanIds =
        sellerIds
            .where(
              (String id) =>
                  id.trim().isNotEmpty,
            )
            .toSet()
            .take(30)
            .toList();

    if (cleanIds.isEmpty) {
      return Stream<
          List<_SellerMapLocation>>.value(
        <_SellerMapLocation>[],
      );
    }

    return FirebaseFirestore.instance
        .collection('sellers')
        .where(
          FieldPath.documentId,
          whereIn: cleanIds,
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<
                Map<String, dynamic>>
            snapshot,
      ) {
        final List<_SellerMapLocation>
            locations =
            <_SellerMapLocation>[];

        for (final QueryDocumentSnapshot<
                Map<String, dynamic>>
            document in snapshot.docs) {
          final Map<String, dynamic>
              data =
              document.data();

          double? latitude =
              _toDouble(
            data['shopLat'] ??
                data['shopLatitude'],
          );

          double? longitude =
              _toDouble(
            data['shopLng'] ??
                data['shopLongitude'],
          );

          final dynamic geoPoint =
              data['shopLocation'];

          if (geoPoint is GeoPoint) {
            latitude ??=
                geoPoint.latitude;

            longitude ??=
                geoPoint.longitude;
          }

          if (latitude == null ||
              longitude == null) {
            continue;
          }

          locations.add(
            _SellerMapLocation(
              sellerId:
                  document.id,
              shopName:
                  data['shopName']
                          ?.toString() ??
                      'Seller Shop',
              address:
                  data['address']
                          ?.toString() ??
                      '',
              phone:
                  data['phone']
                          ?.toString() ??
                      '',
              point: LatLng(
                latitude,
                longitude,
              ),
            ),
          );
        }

        return locations;
      },
    );
  }

  // =========================================================
  // MAP MARKER
  // =========================================================

  Marker _marker({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    return Marker(
      point: point,
      width: 56,
      height: 56,
      child: Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                blurRadius: 6,
                color: Colors.black26,
                offset: Offset(
                  0,
                  2,
                ),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FIT ALL LOCATIONS
  // =========================================================

  void _fitAll(
    List<LatLng> points,
  ) {
    if (!_mapReady ||
        points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(
        points.first,
        16,
      );

      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding:
            const EdgeInsets.all(
          70,
        ),
      ),
    );
  }

  // =========================================================
  // DATE / TIME
  // =========================================================

  String _formatTime(
    dynamic value,
  ) {
    if (value == null) {
      return 'Not available';
    }

    DateTime? dateTime;

    if (value is Timestamp) {
      dateTime = value.toDate();
    } else {
      dateTime =
          DateTime.tryParse(
        value.toString(),
      );
    }

    if (dateTime == null) {
      return value.toString();
    }

    final String day =
        dateTime.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String month =
        dateTime.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String hour =
        dateTime.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final String minute =
        dateTime.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${dateTime.year} '
        '$hour:$minute';
  }

  // =========================================================
  // INFO CHIP
  // =========================================================

  Widget _statusItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: color.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor:
                color,
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: <Widget>[
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors
                        .grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAP
  // =========================================================

  Widget _trackingMap({
    required Map<String, dynamic> order,
    required List<_SellerMapLocation>
        sellers,
  }) {
    final LatLng? customer =
        _customerPoint(order);

    final LatLng? driver =
        _driverPoint(order);

    final List<LatLng> points =
        <LatLng>[
      ...sellers.map(
        (
          _SellerMapLocation seller,
        ) =>
            seller.point,
      ),
      if (driver != null)
        driver,
      if (customer != null)
        customer,
    ];

    final List<Marker> markers =
        <Marker>[
      ...sellers.map(
        (
          _SellerMapLocation seller,
        ) {
          return _marker(
            point:
                seller.point,
            icon:
                Icons.store,
            color:
                Colors.orange,
            tooltip:
                seller.shopName,
          );
        },
      ),

      if (driver != null)
        _marker(
          point: driver,
          icon:
              Icons.local_shipping,
          color:
              Colors.blue,
          tooltip:
              order['driverName']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? order['driverName']
                  .toString()
              : 'Delivery Person',
        ),

      if (customer != null)
        _marker(
          point: customer,
          icon:
              Icons.home,
          color:
              Colors.green,
          tooltip:
              'Customer Delivery Location',
        ),
    ];

    final LatLng initialCenter =
        points.isNotEmpty
            ? points.first
            : const LatLng(
                20,
                0,
              );

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController:
              _mapController,
          options: MapOptions(
            initialCenter:
                initialCenter,
            initialZoom:
                points.isEmpty
                    ? 2
                    : 14,
            initialCameraFit:
                points.length > 1
                    ? CameraFit
                        .coordinates(
                        coordinates:
                            points,
                        padding:
                            const EdgeInsets
                                .all(
                          70,
                        ),
                      )
                    : null,
            minZoom: 2,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;

              WidgetsBinding
                  .instance
                  .addPostFrameCallback(
                (_) {
                  _fitAll(
                    points,
                  );
                },
              );
            },
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName:
                  'com.rd.onlineshop',
            ),

            MarkerLayer(
              markers: markers,
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

        Positioned(
          right: 12,
          top: 12,
          child: FloatingActionButton.small(
            heroTag:
                'fitTrackingMap',
            tooltip:
                'Show all locations',
            onPressed:
                points.isEmpty
                    ? null
                    : () {
                        _fitAll(
                          points,
                        );
                      },
            child:
                const Icon(
              Icons.center_focus_strong,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // BUILD TRACKING CONTENT
  // =========================================================

  Widget _buildTrackingContent(
    Map<String, dynamic> order,
    List<_SellerMapLocation>
        sellers,
  ) {
    final LatLng? customer =
        _customerPoint(order);

    final LatLng? driver =
        _driverPoint(order);

    final String trackingStatus =
        order['trackingStatus']
                ?.toString() ??
            order['status']
                ?.toString() ??
            'Order Placed';

    final String customerAddress =
        order['customerAddress']
                ?.toString() ??
            order['address']
                ?.toString() ??
            'Address not available';

    final String driverName =
        order['driverName']
                ?.toString()
                .trim() ??
            '';

    final String driverPhone =
        order['driverPhone']
                ?.toString()
                .trim() ??
            '';

    final double screenHeight =
        MediaQuery.sizeOf(
      context,
    ).height;

    final double mapHeight =
        (screenHeight * 0.55)
            .clamp(
              350.0,
              620.0,
            )
            .toDouble();

    return ListView(
      padding:
          const EdgeInsets.all(
        12,
      ),
      children: <Widget>[
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons
                      .location_searching,
                  color:
                      Colors.blue,
                  size: 32,
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      const Text(
                        'Live Order Tracking',
                        style:
                            TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        'Order #${widget.orderId}',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    trackingStatus,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          child: SizedBox(
            height: mapHeight,
            child: _trackingMap(
              order: order,
              sellers: sellers,
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        const Text(
          'Tracking Locations',
          style: TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        if (sellers.isEmpty)
          _statusItem(
            icon:
                Icons.store,
            color:
                Colors.orange,
            title:
                'Seller Shop',
            subtitle:
                'Seller shop map location is not available for this order.',
          )
        else
          ...sellers.map(
            (
              _SellerMapLocation
                  seller,
            ) {
              final String detail =
                  seller.address
                          .trim()
                          .isNotEmpty
                      ? seller.address
                      : '${seller.point.latitude.toStringAsFixed(6)}, '
                          '${seller.point.longitude.toStringAsFixed(6)}';

              return _statusItem(
                icon:
                    Icons.store,
                color:
                    Colors.orange,
                title:
                    seller.shopName,
                subtitle:
                    detail,
              );
            },
          ),

        if (driver == null)
          _statusItem(
            icon:
                Icons.local_shipping,
            color:
                Colors.blue,
            title:
                'Delivery Person',
            subtitle:
                'Live location has not started yet.',
          )
        else
          _statusItem(
            icon:
                Icons.local_shipping,
            color:
                Colors.blue,
            title:
                driverName.isNotEmpty
                    ? driverName
                    : 'Delivery Person',
            subtitle:
                'Lat: ${driver.latitude.toStringAsFixed(6)}, '
                'Lng: ${driver.longitude.toStringAsFixed(6)}'
                '${driverPhone.isNotEmpty ? '\nPhone: $driverPhone' : ''}'
                '\nLast update: '
                '${_formatTime(order['driverLocationUpdatedAt'])}',
          ),

        if (customer == null)
          _statusItem(
            icon:
                Icons.home,
            color:
                Colors.green,
            title:
                'Customer',
            subtitle:
                'Customer map location is not available.',
          )
        else
          _statusItem(
            icon:
                Icons.home,
            color:
                Colors.green,
            title:
                'Customer Delivery Location',
            subtitle:
                '$customerAddress\n'
                'Lat: ${customer.latitude.toStringAsFixed(6)}, '
                'Lng: ${customer.longitude.toStringAsFixed(6)}',
          ),

        const SizedBox(
          height: 8,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration: BoxDecoration(
            color:
                Colors.grey.shade100,
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: const Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Map Symbols',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              SizedBox(
                height: 8,
              ),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.store,
                    color:
                        Colors.orange,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    'Seller Shop',
                  ),
                ],
              ),
              SizedBox(
                height: 6,
              ),
              Row(
                children: <Widget>[
                  Icon(
                    Icons
                        .local_shipping,
                    color:
                        Colors.blue,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    'Delivery Person',
                  ),
                ],
              ),
              SizedBox(
                height: 6,
              ),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.home,
                    color:
                        Colors.green,
                  ),
                  SizedBox(
                    width: 8,
                  ),
                  Text(
                    'Customer',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 30,
        ),
      ],
    );
  }

  // =========================================================
  // MAIN BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Track Order',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          Map<String, dynamic>?>(
        stream:
            orderStream(
          widget.orderId,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<
                  Map<String,
                      dynamic>?>
              orderSnapshot,
        ) {
          if (orderSnapshot
                  .connectionState ==
              ConnectionState
                  .waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (orderSnapshot
              .hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Text(
                  'Could not load tracking data.\n'
                  '${orderSnapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final Map<String, dynamic>?
              order =
              orderSnapshot.data;

          if (order == null) {
            return const Center(
              child: Text(
                'Order tracking data not found.',
              ),
            );
          }

          final List<String>
              sellerIds =
              _sellerIds(
            order,
          );

          return StreamBuilder<
              List<
                  _SellerMapLocation>>(
            stream:
                _sellerLocationsStream(
              sellerIds,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<
                      List<
                          _SellerMapLocation>>
                  sellerSnapshot,
            ) {
              if (sellerSnapshot
                          .connectionState ==
                      ConnectionState
                          .waiting &&
                  sellerIds.isNotEmpty) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final List<
                      _SellerMapLocation>
                  sellers =
                  sellerSnapshot.data ??
                      <
                          _SellerMapLocation>[];

              return _buildTrackingContent(
                order,
                sellers,
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

// ===========================================================
// SELLER MAP MODEL
// ===========================================================

class _SellerMapLocation {
  final String sellerId;
  final String shopName;
  final String address;
  final String phone;
  final LatLng point;

  const _SellerMapLocation({
    required this.sellerId,
    required this.shopName,
    required this.address,
    required this.phone,
    required this.point,
  });
}