import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'hotel_cloudinary_service.dart';

class HotelPartnerProfilePage extends StatefulWidget {
  const HotelPartnerProfilePage({super.key});

  @override
  State<HotelPartnerProfilePage> createState() =>
      _HotelPartnerProfilePageState();
}

class _HotelPartnerProfilePageState
    extends State<HotelPartnerProfilePage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdBlue =
      Color(0xFF1565C0);

  static const List<String> _facilityOptions =
      <String>[
    'Free Wi-Fi',
    'Parking',
    'Restaurant',
    'Breakfast',
    '24h Front Desk',
    'Airport Pickup',
    'Room Service',
    'Laundry',
    'Swimming Pool',
    'Gym',
    'Lift',
    'Hot Water',
    'Generator / Backup',
    'Conference Hall',
  ];

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _name =
      TextEditingController();
  final TextEditingController _description =
      TextEditingController();
  final TextEditingController _location =
      TextEditingController();
  final TextEditingController _address =
      TextEditingController();
  final TextEditingController _city =
      TextEditingController();
  final TextEditingController _area =
      TextEditingController();
  final TextEditingController _phone =
      TextEditingController();
  final TextEditingController _email =
      TextEditingController();
  final TextEditingController _checkInTime =
      TextEditingController(text: '12:00 PM');
  final TextEditingController _checkOutTime =
      TextEditingController(text: '11:00 AM');
  final TextEditingController _cancellationPolicy =
      TextEditingController();
  final TextEditingController _houseRules =
      TextEditingController();
  final TextEditingController _otherFacilities =
      TextEditingController();

  final Set<String> _selectedFacilities =
      <String>{};
  final List<String> _galleryUrls =
      <String>[];

  bool _loading = true;
  bool _saving = false;
  bool _uploadingProfile = false;
  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _gettingLocation = false;

  String _profileUrl = '';
  String _coverUrl = '';
  double? _latitude;
  double? _longitude;
  bool _exists = false;
  bool _hotelApproved = false;
  bool _hotelActive = false;
  String _hotelStatus = 'not_created';

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>?
      get _hotelRef {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('hotels')
        .doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    _address.dispose();
    _city.dispose();
    _area.dispose();
    _phone.dispose();
    _email.dispose();
    _checkInTime.dispose();
    _checkOutTime.dispose();
    _cancellationPolicy.dispose();
    _houseRules.dispose();
    _otherFacilities.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          partnerDoc =
          await FirebaseFirestore.instance
              .collection('hotel_partners')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> partner =
          partnerDoc.data() ??
              <String, dynamic>{};

      final DocumentSnapshot<Map<String, dynamic>>
          hotelDoc =
          await FirebaseFirestore.instance
              .collection('hotels')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> hotel =
          hotelDoc.data() ??
              <String, dynamic>{};

      _exists = hotelDoc.exists;

      _name.text =
          hotel['name']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['name'].toString().trim()
              : partner['businessName']
                      ?.toString()
                      .trim() ??
                  '';

      _description.text =
          hotel['description']?.toString() ?? '';

      _location.text =
          hotel['location']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['location']
                  .toString()
                  .trim()
              : partner['address']
                      ?.toString()
                      .trim() ??
                  '';

      _address.text =
          hotel['address']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['address']
                  .toString()
                  .trim()
              : partner['address']
                      ?.toString()
                      .trim() ??
                  '';

      _city.text =
          hotel['city']?.toString() ?? '';
      _area.text =
          hotel['area']?.toString() ?? '';

      _phone.text =
          hotel['phone']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['phone'].toString().trim()
              : partner['phone']
                      ?.toString()
                      .trim() ??
                  '';

      _email.text =
          hotel['email']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['email'].toString().trim()
              : partner['email']
                      ?.toString()
                      .trim() ??
                  user.email ??
                  '';

      _checkInTime.text =
          hotel['checkInTime']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['checkInTime']
                  .toString()
                  .trim()
              : '12:00 PM';

      _checkOutTime.text =
          hotel['checkOutTime']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? hotel['checkOutTime']
                  .toString()
                  .trim()
              : '11:00 AM';

      _cancellationPolicy.text =
          hotel['cancellationPolicy']
                  ?.toString() ??
              '';

      _houseRules.text =
          hotel['houseRules']?.toString() ?? '';

      _profileUrl =
          hotel['profileUrl']
                  ?.toString()
                  .trim() ??
              '';

      _coverUrl =
          hotel['coverUrl']
                  ?.toString()
                  .trim() ??
              '';

      _latitude =
          (hotel['latitude'] as num?)
              ?.toDouble();
      _longitude =
          (hotel['longitude'] as num?)
              ?.toDouble();

      _hotelApproved =
          hotel['isApproved'] == true;
      _hotelActive =
          hotel['isActive'] == true;
      _hotelStatus =
          hotel['status']?.toString().trim() ??
              (_exists
                  ? 'pending'
                  : 'not_created');

      final List<dynamic> facilities =
          hotel['facilities'] is List
              ? hotel['facilities']
                  as List<dynamic>
              : <dynamic>[];

      _selectedFacilities
        ..clear()
        ..addAll(
          facilities
              .map(
                (dynamic value) =>
                    value.toString().trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty &&
                    _facilityOptions
                        .contains(value),
              ),
        );

      final List<String> extras =
          facilities
              .map(
                (dynamic value) =>
                    value.toString().trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty &&
                    !_facilityOptions
                        .contains(value),
              )
              .toList();

      _otherFacilities.text =
          extras.join(', ');

      final List<dynamic> photos =
          hotel['photoUrls'] is List
              ? hotel['photoUrls']
                  as List<dynamic>
              : <dynamic>[];

      _galleryUrls
        ..clear()
        ..addAll(
          photos
              .map(
                (dynamic value) =>
                    value.toString().trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty &&
                    value != _coverUrl &&
                    value != _profileUrl,
              ),
        );
    } catch (error) {
      _message(
        'Could not load hotel profile.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _uploadPhoto({
    int quality = 85,
  }) async {
    return HotelCloudinaryService
        .pickAndUploadImage(
      imageQuality: quality,
    );
  }

  Future<void> _pickProfilePhoto() async {
    if (_uploadingProfile) {
      return;
    }

    setState(() {
      _uploadingProfile = true;
    });

    try {
      final String? url =
          await _uploadPhoto();

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _profileUrl = url;
      });

      _message(
        'Hotel logo/profile photo ready. '
        'Press Save Hotel Profile.',
      );
    } catch (error) {
      _message(
        'Profile photo upload failed.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProfile = false;
        });
      }
    }
  }

  Future<void> _pickCoverPhoto() async {
    if (_uploadingCover) {
      return;
    }

    setState(() {
      _uploadingCover = true;
    });

    try {
      final String? url =
          await _uploadPhoto(quality: 88);

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _coverUrl = url;
      });

      _message(
        'Hotel cover photo ready. '
        'Press Save Hotel Profile.',
      );
    } catch (error) {
      _message(
        'Cover photo upload failed.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingCover = false;
        });
      }
    }
  }

  Future<void> _addGalleryPhoto() async {
    if (_uploadingGallery) {
      return;
    }

    if (_galleryUrls.length >= 8) {
      _message(
        'Maximum 8 gallery photos are allowed.',
      );
      return;
    }

    setState(() {
      _uploadingGallery = true;
    });

    try {
      final String? url =
          await _uploadPhoto(quality: 86);

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        if (!_galleryUrls.contains(url)) {
          _galleryUrls.add(url);
        }
      });

      _message(
        'Gallery photo ready. '
        'Press Save Hotel Profile.',
      );
    } catch (error) {
      _message(
        'Gallery photo upload failed.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingGallery = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) {
      return;
    }

    setState(() {
      _gettingLocation = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location service is turned off.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        throw Exception(
          'Location permission is not available.',
        );
      }

      final Position position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String addressText =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';

      String cityText = '';
      String areaText = '';

      try {
        final List<Placemark> placemarks =
            await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final Placemark place =
              placemarks.first;

          final List<String> parts =
              <String>[
            place.street ?? '',
            place.subLocality ?? '',
            place.locality ?? '',
            place.administrativeArea ?? '',
            place.country ?? '',
          ]
                  .where(
                    (String value) =>
                        value
                            .trim()
                            .isNotEmpty,
                  )
                  .toList();

          if (parts.isNotEmpty) {
            addressText =
                parts.join(', ');
          }

          cityText =
              (place.locality ?? '').trim();

          areaText =
              (place.subLocality ?? '')
                  .trim();
        }
      } catch (_) {
        // Coordinates remain valid even when
        // reverse geocoding is unavailable.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _location.text = addressText;
        _address.text = addressText;

        if (cityText.isNotEmpty) {
          _city.text = cityText;
        }

        if (areaText.isNotEmpty) {
          _area.text = areaText;
        }
      });

      _message(
        'Hotel GPS location captured.',
      );
    } catch (error) {
      _message(
        'Could not get current location.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  List<String> _facilityList() {
    final Set<String> result =
        <String>{..._selectedFacilities};

    result.addAll(
      _otherFacilities.text
          .split(',')
          .map(
            (String value) =>
                value.trim(),
          )
          .where(
            (String value) =>
                value.isNotEmpty,
          ),
    );

    return result.toList()..sort();
  }

  List<String> _allPhotos() {
    final List<String> photos =
        <String>[
      if (_coverUrl.isNotEmpty)
        _coverUrl,
      if (_profileUrl.isNotEmpty)
        _profileUrl,
      ..._galleryUrls,
    ];

    return photos.toSet().toList();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final User? user = _user;
    final DocumentReference<
            Map<String, dynamic>>?
        reference = _hotelRef;

    if (user == null ||
        user.isAnonymous ||
        reference == null) {
      _message(
        'Hotel Partner login is required.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> editable =
          <String, dynamic>{
        'name': _name.text.trim(),
        'description':
            _description.text.trim(),
        'location':
            _location.text.trim(),
        'address':
            _address.text.trim(),
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'coverUrl': _coverUrl,
        'profileUrl': _profileUrl,
        'photoUrls': _allPhotos(),
        'facilities': _facilityList(),
        'latitude': _latitude,
        'longitude': _longitude,
        'checkInTime':
            _checkInTime.text.trim(),
        'checkOutTime':
            _checkOutTime.text.trim(),
        'cancellationPolicy':
            _cancellationPolicy.text.trim(),
        'houseRules':
            _houseRules.text.trim(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (_exists) {
        await reference.update(editable);
      } else {
        await reference.set(
          <String, dynamic>{
            'hotelId': user.uid,
            'partnerId': user.uid,
            ...editable,
            'rating': 0.0,
            'reviewCount': 0,
            'isApproved': false,
            'isActive': false,
            'status': 'pending',
            'createdAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _exists = true;

        if (!_hotelApproved) {
          _hotelStatus = 'pending';
        }
      });

      _message(
        _hotelApproved
            ? 'Hotel profile saved successfully.'
            : 'Hotel profile submitted. Admin approval is required before rooms can go live.',
      );
    } catch (error) {
      _message(
        'Could not save hotel profile.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String? _required(
    String? value,
    String label,
  ) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }

    return null;
  }

  Widget _field({
    required TextEditingController
        controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      textCapitalization:
          keyboardType ==
                  TextInputType.emailAddress
              ? TextCapitalization.none
              : TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon == null
                ? null
                : Icon(icon),
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  Widget _photoPreview({
    required String url,
    required double height,
    required IconData fallback,
  }) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(14),
      child: url.isEmpty
          ? Container(
              height: height,
              color: _rdBlue
                  .withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: Icon(
                fallback,
                size: 52,
                color: _rdBlue,
              ),
            )
          : Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                height: height,
                color: _rdBlue
                    .withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Icon(
                  fallback,
                  size: 52,
                  color: _rdBlue,
                ),
              ),
            ),
    );
  }

  Widget _gallery() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Gallery Photos',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_galleryUrls.length}/8',
              style: TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_galleryUrls.isEmpty)
          const Text(
            'No gallery photo added yet.',
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  _galleryUrls.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: 8,
              ),
              itemBuilder:
                  (
                BuildContext context,
                int index,
              ) {
                final String url =
                    _galleryUrls[index];

                return Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(12),
                      child: Image.network(
                        url,
                        width: 150,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                Container(
                          width: 150,
                          height: 120,
                          color: _rdBlue
                              .withValues(
                            alpha: 0.08,
                          ),
                          child: const Icon(
                            Icons
                                .image_not_supported_outlined,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child:
                          IconButton.filledTonal(
                        tooltip:
                            'Remove Photo',
                        onPressed: () {
                          setState(() {
                            _galleryUrls
                                .removeAt(
                              index,
                            );
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed:
              _uploadingGallery
                  ? null
                  : _addGalleryPhoto,
          icon: _uploadingGallery
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons
                      .add_photo_alternate_rounded,
                ),
          label: const Text(
            'Add Gallery Photo',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final String statusText =
        !_exists
            ? 'NOT CREATED'
            : _hotelApproved &&
                    _hotelActive
                ? 'APPROVED • ACTIVE'
                : _hotelApproved
                    ? 'APPROVED • INACTIVE'
                    : 'PENDING HOTEL APPROVAL';

    final Color statusColor =
        _hotelApproved &&
                _hotelActive
            ? _rdGreen
            : Colors.orange;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Hotel Profile',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 850,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets
                            .all(14),
                    decoration:
                        BoxDecoration(
                      color: statusColor
                          .withValues(
                        alpha: 0.09,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(14),
                      border: Border.all(
                        color: statusColor
                            .withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _hotelApproved
                              ? Icons
                                  .verified_rounded
                              : Icons
                                  .hourglass_top_rounded,
                          color:
                              statusColor,
                        ),
                        const SizedBox(
                          width: 9,
                        ),
                        Expanded(
                          child: Text(
                            '$statusText\n'
                            '${_hotelStatus.toUpperCase()}',
                            style: TextStyle(
                              color:
                                  statusColor,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: <Widget>[
                          const Text(
                            'Hotel Photos',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _photoPreview(
                            url: _coverUrl,
                            height: 180,
                            fallback: Icons
                                .hotel_rounded,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          FilledButton
                              .tonalIcon(
                            onPressed:
                                _uploadingCover
                                    ? null
                                    : _pickCoverPhoto,
                            icon: _uploadingCover
                                ? const SizedBox
                                    .square(
                                    dimension:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .panorama_rounded,
                                  ),
                            label: const Text(
                              'Upload Cover Photo',
                            ),
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          Row(
                            children: <Widget>[
                              SizedBox(
                                width: 95,
                                height: 95,
                                child: ClipOval(
                                  child: _profileUrl
                                          .isEmpty
                                      ? Container(
                                          color: _rdGreen
                                              .withValues(
                                            alpha:
                                                0.09,
                                          ),
                                          child:
                                              const Icon(
                                            Icons
                                                .hotel_class_rounded,
                                            color:
                                                _rdGreen,
                                            size:
                                                44,
                                          ),
                                        )
                                      : Image.network(
                                          _profileUrl,
                                          fit: BoxFit
                                              .cover,
                                          errorBuilder:
                                              (
                                            _,
                                            __,
                                            ___,
                                          ) =>
                                                  Container(
                                            color: _rdGreen
                                                .withValues(
                                              alpha:
                                                  0.09,
                                            ),
                                            child:
                                                const Icon(
                                              Icons
                                                  .hotel_class_rounded,
                                              color:
                                                  _rdGreen,
                                              size:
                                                  44,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child:
                                    FilledButton
                                        .tonalIcon(
                                  onPressed:
                                      _uploadingProfile
                                          ? null
                                          : _pickProfilePhoto,
                                  icon: _uploadingProfile
                                      ? const SizedBox
                                          .square(
                                          dimension:
                                              18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons
                                              .account_circle_rounded,
                                        ),
                                  label:
                                      const Text(
                                    'Upload Logo / Profile Photo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 14,
                          ),
                          _gallery(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        children: <Widget>[
                          _field(
                            controller: _name,
                            label:
                                'Hotel Name',
                            icon: Icons
                                .hotel_rounded,
                            validator:
                                (
                              String? value,
                            ) =>
                                    _required(
                              value,
                              'Hotel Name',
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _description,
                            label:
                                'Hotel Description',
                            icon: Icons
                                .description_rounded,
                            maxLines: 4,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _phone,
                            label:
                                'Contact Number',
                            icon: Icons
                                .phone_rounded,
                            keyboardType:
                                TextInputType
                                    .phone,
                            validator:
                                (
                              String? value,
                            ) {
                              if ((value ?? '')
                                      .trim()
                                      .length <
                                  7) {
                                return 'Enter a valid contact number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _email,
                            label:
                                'Hotel Email',
                            icon: Icons
                                .email_rounded,
                            keyboardType:
                                TextInputType
                                    .emailAddress,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: <Widget>[
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _location,
                            label:
                                'Display Location',
                            icon: Icons
                                .location_on_rounded,
                            validator:
                                (
                              String? value,
                            ) =>
                                    _required(
                              value,
                              'Location',
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _address,
                            label:
                                'Full Address',
                            icon: Icons
                                .map_rounded,
                            maxLines: 2,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          LayoutBuilder(
                            builder:
                                (
                              BuildContext
                                  context,
                              BoxConstraints
                                  constraints,
                            ) {
                              final Widget
                                  city =
                                  _field(
                                controller:
                                    _city,
                                label:
                                    'City',
                              );
                              final Widget
                                  area =
                                  _field(
                                controller:
                                    _area,
                                label:
                                    'Area',
                              );

                              if (constraints
                                      .maxWidth >=
                                  600) {
                                return Row(
                                  children: <
                                      Widget>[
                                    Expanded(
                                      child:
                                          city,
                                    ),
                                    const SizedBox(
                                      width:
                                          10,
                                    ),
                                    Expanded(
                                      child:
                                          area,
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: <
                                    Widget>[
                                  city,
                                  const SizedBox(
                                    height:
                                        10,
                                  ),
                                  area,
                                ],
                              );
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          FilledButton
                              .tonalIcon(
                            onPressed:
                                _gettingLocation
                                    ? null
                                    : _useCurrentLocation,
                            icon: _gettingLocation
                                ? const SizedBox
                                    .square(
                                    dimension:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .my_location_rounded,
                                  ),
                            label: const Text(
                              'Use Current Location',
                            ),
                          ),
                          if (_latitude !=
                                  null &&
                              _longitude !=
                                  null) ...<
                              Widget>[
                            const SizedBox(
                              height: 8,
                            ),
                            SelectableText(
                              'GPS: '
                              '${_latitude!.toStringAsFixed(6)}, '
                              '${_longitude!.toStringAsFixed(6)}',
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  TextStyle(
                                color: Colors
                                    .grey
                                    .shade700,
                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: <Widget>[
                          const Text(
                            'Hotel Facilities',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children:
                                _facilityOptions
                                    .map(
                              (
                                String
                                    facility,
                              ) =>
                                  FilterChip(
                                label: Text(
                                  facility,
                                ),
                                selected:
                                    _selectedFacilities
                                        .contains(
                                  facility,
                                ),
                                onSelected:
                                    (
                                  bool value,
                                ) {
                                  setState(
                                    () {
                                      if (value) {
                                        _selectedFacilities
                                            .add(
                                          facility,
                                        );
                                      } else {
                                        _selectedFacilities
                                            .remove(
                                          facility,
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            )
                                    .toList(),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _otherFacilities,
                            label:
                                'Other Facilities (comma separated)',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        children: <Widget>[
                          LayoutBuilder(
                            builder:
                                (
                              BuildContext
                                  context,
                              BoxConstraints
                                  constraints,
                            ) {
                              final Widget
                                  checkIn =
                                  _field(
                                controller:
                                    _checkInTime,
                                label:
                                    'Check-in Time',
                                icon: Icons
                                    .login_rounded,
                              );

                              final Widget
                                  checkOut =
                                  _field(
                                controller:
                                    _checkOutTime,
                                label:
                                    'Check-out Time',
                                icon: Icons
                                    .logout_rounded,
                              );

                              if (constraints
                                      .maxWidth >=
                                  600) {
                                return Row(
                                  children: <
                                      Widget>[
                                    Expanded(
                                      child:
                                          checkIn,
                                    ),
                                    const SizedBox(
                                      width:
                                          10,
                                    ),
                                    Expanded(
                                      child:
                                          checkOut,
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: <
                                    Widget>[
                                  checkIn,
                                  const SizedBox(
                                    height:
                                        10,
                                  ),
                                  checkOut,
                                ],
                              );
                            },
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _cancellationPolicy,
                            label:
                                'Cancellation Policy',
                            icon: Icons
                                .event_busy_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _houseRules,
                            label:
                                'House Rules',
                            icon:
                                Icons.rule_rounded,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  SizedBox(
                    height: 54,
                    child:
                        FilledButton.icon(
                      onPressed:
                          _saving
                              ? null
                              : _save,
                      icon: _saving
                          ? const SizedBox
                              .square(
                              dimension: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .save_rounded,
                            ),
                      label: Text(
                        _exists
                            ? 'Save Hotel Profile'
                            : 'Submit Hotel for Admin Approval',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
