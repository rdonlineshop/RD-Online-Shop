import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/local_file_image.dart';
import 'services/platform_capabilities.dart';

class SellerShopProfilePage extends StatefulWidget {
  const SellerShopProfilePage({super.key});

  @override
  State<SellerShopProfilePage> createState() =>
      _SellerShopProfilePageState();
}

class _SellerShopProfilePageState
    extends State<SellerShopProfilePage> {
  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset =
      'rd_online_shop_products';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _shop =
      TextEditingController();

  final TextEditingController _owner =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  final TextEditingController _email =
      TextEditingController();

  final TextEditingController _address =
      TextEditingController();

  final TextEditingController _description =
      TextEditingController();

  final TextEditingController _latitudeController =
      TextEditingController();

  final TextEditingController _longitudeController =
      TextEditingController();

  // Seller payout/payment details
  final TextEditingController _esewaNumber =
      TextEditingController();
  final TextEditingController _khaltiNumber =
      TextEditingController();
  final TextEditingController _bankName =
      TextEditingController();
  final TextEditingController _bankAccountHolder =
      TextEditingController();
  final TextEditingController _bankAccountNumber =
      TextEditingController();

  String _photoUrl = '';
  String _paymentQrUrl = '';
  String _locationSource = '';

  bool _paymentVerified = false;

  double? _shopLatitude;
  double? _shopLongitude;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _gettingLocation = false;
  bool _migratingOldPhoto = false;

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  bool get _hasCoordinates =>
      _shopLatitude != null &&
      _shopLongitude != null;

  DocumentReference<Map<String, dynamic>>?
      get _sellerDocument {
    final User? user = _user;

    if (user == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('sellers')
        .doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  bool _isNetworkPhoto(String value) {
    return value.startsWith('https://') ||
        value.startsWith('http://');
  }

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

  String _findOnlinePhoto(
    Map<String, dynamic> data,
  ) {
    const List<String> fields = <String>[
      'photoUrl',
      'shopPhotoUrl',
      'shopImageUrl',
      'imageUrl',
      'logoUrl',
      'profilePhotoUrl',
      'profileImageUrl',
    ];

    for (final String field in fields) {
      final dynamic value = data[field];

      if (value is String &&
          value.trim().isNotEmpty &&
          _isNetworkPhoto(value.trim())) {
        return value.trim();
      }
    }

    final dynamic shopPhotos =
        data['shopPhotos'];

    if (shopPhotos is List) {
      for (final dynamic item in shopPhotos) {
        if (item is String &&
            item.trim().isNotEmpty &&
            _isNetworkPhoto(item.trim())) {
          return item.trim();
        }
      }
    }

    return '';
  }

  Future<void> _load() async {
    final User? user = _user;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      _message(
        'Please login as a seller first.',
      );

      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          snapshot = await FirebaseFirestore.instance
              .collection('sellers')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> data =
          snapshot.data() ??
              <String, dynamic>{};

      _shop.text =
          data['shopName']?.toString() ?? '';

      _owner.text =
          data['ownerName']?.toString() ?? '';

      _phone.text =
          data['phone']?.toString() ?? '';

      _email.text =
          data['email']?.toString() ??
              user.email ??
              '';

      _address.text =
          data['address']?.toString() ?? '';

      _description.text =
          data['description']?.toString() ?? '';

      _esewaNumber.text =
          data['esewaNumber']?.toString() ?? '';
      _khaltiNumber.text =
          data['khaltiNumber']?.toString() ?? '';
      _bankName.text =
          data['bankName']?.toString() ?? '';
      _bankAccountHolder.text =
          data['bankAccountHolder']?.toString() ?? '';
      _bankAccountNumber.text =
          data['bankAccountNumber']?.toString() ?? '';
      _paymentQrUrl =
          data['paymentQrUrl']?.toString() ?? '';
      _paymentVerified =
          data['paymentVerified'] == true;

      _locationSource =
          data['shopLocationSource']
                  ?.toString() ??
              '';

      double? latitude =
          _toDouble(
        data['shopLat'],
      );

      double? longitude =
          _toDouble(
        data['shopLng'],
      );

      final dynamic geoPoint =
          data['shopLocation'];

      if (geoPoint is GeoPoint) {
        latitude ??=
            geoPoint.latitude;

        longitude ??=
            geoPoint.longitude;
      }

      _shopLatitude = latitude;
      _shopLongitude = longitude;

      if (latitude != null) {
        _latitudeController.text =
            latitude.toStringAsFixed(7);
      }

      if (longitude != null) {
        _longitudeController.text =
            longitude.toStringAsFixed(7);
      }

      final String onlinePhoto =
          _findOnlinePhoto(data);

      if (onlinePhoto.isNotEmpty) {
        _photoUrl = onlinePhoto;
      } else {
        final String oldLogoPath =
            data['logoPath']
                    ?.toString()
                    .trim() ??
                '';

        if (oldLogoPath.isNotEmpty) {
          await _tryMigrateOldLogo(
            oldLogoPath,
          );
        }
      }
    } catch (error) {
      _email.text =
          user.email ?? '';

      _message(
        'Could not load profile. Please save it again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String> _uploadBytesToCloudinary(
    List<int> bytes,
    String fileName,
  ) async {
    if (bytes.isEmpty) {
      throw Exception('Selected photo is empty.');
    }

    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$_cloudName/image/upload',
    );

    final http.MultipartRequest request =
        http.MultipartRequest(
      'POST',
      uri,
    );

    request.fields['upload_preset'] =
        _uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final http.StreamedResponse response =
        await request.send();

    final String responseBody =
        await response.stream.bytesToString();

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed: $responseBody',
      );
    }

    final dynamic decoded = jsonDecode(responseBody);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Cloudinary response.');
    }

    final String secureUrl =
        decoded['secure_url']?.toString().trim() ?? '';

    if (secureUrl.isEmpty) {
      throw Exception(
        'Cloudinary image URL was not received.',
      );
    }

    return secureUrl;
  }

  Future<String> _uploadXFileToCloudinary(
    XFile image,
  ) async {
    return _uploadBytesToCloudinary(
      await image.readAsBytes(),
      image.name,
    );
  }

  Future<String> _uploadPathToCloudinary(
    String path,
  ) async {
    if (!await localFileExists(path)) {
      throw Exception(
        'Selected photo file could not be found.',
      );
    }

    return _uploadBytesToCloudinary(
      await readLocalFileBytes(path),
      localFileName(path),
    );
  }

  Future<void> _savePhotoFields(
    String url,
  ) async {
    final DocumentReference<
            Map<String, dynamic>>?
        document = _sellerDocument;

    if (document == null) {
      return;
    }

    await document.set(
      <String, dynamic>{
        'photoUrl': url,
        'shopPhotoUrl': url,
        'shopImageUrl': url,
        'imageUrl': url,
        'logoUrl': url,
        'shopPhotos': <String>[url],
        'photoStorage': 'cloudinary',
        'logoPath': '',
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  Future<void> _tryMigrateOldLogo(
    String oldPath,
  ) async {
    if (_isNetworkPhoto(oldPath)) {
      _photoUrl = oldPath;

      await _savePhotoFields(
        oldPath,
      );

      return;
    }

    try {
      if (!await localFileExists(oldPath)) {
        return;
      }

      if (mounted) {
        setState(() {
          _migratingOldPhoto = true;
        });
      }

      final String url =
          await _uploadPathToCloudinary(
        oldPath,
      );

      await _savePhotoFields(
        url,
      );

      _photoUrl = url;

      if (mounted) {
        _message(
          'Old seller photo converted to cloud successfully.',
        );
      }
    } catch (error) {
      debugPrint(
        'Old seller photo migration error: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _migratingOldPhoto = false;
        });
      }
    }
  }

  Future<void> _pickPaymentQr() async {
    if (_uploadingPhoto) {
      return;
    }

    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingPhoto = true;
    });

    try {
      final String url =
          await _uploadXFileToCloudinary(image);

      final DocumentReference<Map<String, dynamic>>?
          document = _sellerDocument;

      if (document == null) {
        throw Exception('Please login as a seller first.');
      }

      await document.set(
        <String, dynamic>{
          'paymentQrUrl': url,
          // Seller changes require a fresh Admin verification.
          'paymentVerified': false,
          'paymentVerifiedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentQrUrl = url;
        _paymentVerified = false;
      });

      _message(
        'Payment QR saved. Admin verification is required before direct payment is enabled.',
      );
    } catch (error) {
      _message('Payment QR upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _pickLogo() async {
    if (_uploadingPhoto) {
      return;
    }

    final XFile? image =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _uploadingPhoto = true;
    });

    try {
      final String url =
          await _uploadXFileToCloudinary(
        image,
      );

      await _savePhotoFields(
        url,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _photoUrl = url;
      });

      _message(
        'Shop photo uploaded successfully.',
      );
    } catch (error) {
      _message(
        'Photo upload failed: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  // =========================================================
  // CURRENT SELLER SHOP GPS LOCATION
  // =========================================================

  Future<void> _location() async {
    if (_gettingLocation) {
      return;
    }

    setState(() {
      _gettingLocation = true;
    });

    try {
      if (PlatformCapabilities.isWindows) {
        throw Exception(
          'Current GPS Location works on Android/iPhone/macOS. '
          'On Windows enter Latitude and Longitude manually.',
        );
      }

      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Please turn on Location / GPS first.',
        );
      }

      LocationPermission permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        throw Exception(
          'Location permission was denied.',
        );
      }

      if (permission ==
          LocationPermission.deniedForever) {
        throw Exception(
          'Enable location permission from phone settings.',
        );
      }

      final Position position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      String address =
          '${position.latitude}, '
          '${position.longitude}';

      try {
        final List<Placemark> places =
            PlatformCapabilities.supportsNativeGeocoding
                ? await Geocoding().placemarkFromCoordinates(
                    position.latitude,
                    position.longitude,
                  )
                : <Placemark>[];

        if (places.isNotEmpty) {
          final Placemark place =
              places.first;

          final String foundAddress =
              <String?>[
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
            place.country,
          ]
                  .whereType<String>()
                  .where(
                    (String part) =>
                        part.trim().isNotEmpty,
                  )
                  .join(', ');

          if (foundAddress.isNotEmpty) {
            address = foundAddress;
          }
        }
      } catch (_) {
        // Coordinates remain usable even
        // if reverse geocoding fails.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _shopLatitude =
            position.latitude;

        _shopLongitude =
            position.longitude;

        _latitudeController.text =
            position.latitude
                .toStringAsFixed(7);

        _longitudeController.text =
            position.longitude
                .toStringAsFixed(7);

        _address.text =
            address;

        _locationSource =
            'GPS Current Location';
      });

      _message(
        'Shop map location found successfully.',
      );
    } catch (error) {
      _message(
        error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  // =========================================================
  // MANUAL LATITUDE / LONGITUDE
  // Useful on Windows
  // =========================================================

  void _applyManualCoordinates() {
    final double? latitude =
        double.tryParse(
      _latitudeController.text.trim(),
    );

    final double? longitude =
        double.tryParse(
      _longitudeController.text.trim(),
    );

    if (latitude == null ||
        longitude == null) {
      _message(
        'Enter valid Latitude and Longitude.',
      );

      return;
    }

    if (latitude < -90 ||
        latitude > 90) {
      _message(
        'Latitude must be between -90 and 90.',
      );

      return;
    }

    if (longitude < -180 ||
        longitude > 180) {
      _message(
        'Longitude must be between -180 and 180.',
      );

      return;
    }

    setState(() {
      _shopLatitude = latitude;
      _shopLongitude = longitude;
      _locationSource =
          'Manual Coordinates';
    });

    _message(
      'Shop coordinates selected.',
    );
  }

  // =========================================================
  // OPEN LOCATION IN MAP
  // =========================================================

  Future<void> _openMap() async {
    _applyManualCoordinates();

    if (!_hasCoordinates) {
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${_shopLatitude!},${_shopLongitude!}',
    );

    final bool opened =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened) {
      _message(
        'Could not open map.',
      );
    }
  }

  // =========================================================
  // SAVE SHOP PROFILE
  // =========================================================

  Future<void> _save() async {
    if (_formKey.currentState
            ?.validate() !=
        true) {
      return;
    }

    if (_saving ||
        _uploadingPhoto) {
      return;
    }

    final User? user = _user;

    if (user == null) {
      _message(
        'Please login as a seller first.',
      );

      return;
    }

    if (_latitudeController.text
            .trim()
            .isNotEmpty ||
        _longitudeController.text
            .trim()
            .isNotEmpty) {
      final double? latitude =
          double.tryParse(
        _latitudeController.text.trim(),
      );

      final double? longitude =
          double.tryParse(
        _longitudeController.text.trim(),
      );

      if (latitude == null ||
          longitude == null) {
        _message(
          'Please enter valid shop Latitude and Longitude.',
        );

        return;
      }

      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        _message(
          'Shop coordinates are not valid.',
        );

        return;
      }

      _shopLatitude = latitude;
      _shopLongitude = longitude;

      if (_locationSource.isEmpty) {
        _locationSource =
            'Manual Coordinates';
      }
    }

    if (!_hasCoordinates) {
      _message(
        'Please set the shop map location before saving.',
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .set(
        <String, dynamic>{
          'sellerId': user.uid,

          'shopName':
              _shop.text.trim(),

          'ownerName':
              _owner.text.trim(),

          'phone':
              _phone.text.trim(),

          'email':
              _email.text.trim(),

          'address':
              _address.text.trim(),

          'description':
              _description.text.trim(),

          // ================================================
          // SELLER PAYMENT / PAYOUT PROFILE
          // Admin must verify after seller changes details.
          // ================================================

          'esewaNumber':
              _esewaNumber.text.trim(),
          'khaltiNumber':
              _khaltiNumber.text.trim(),
          'bankName':
              _bankName.text.trim(),
          'bankAccountHolder':
              _bankAccountHolder.text.trim(),
          'bankAccountNumber':
              _bankAccountNumber.text.trim(),
          'paymentQrUrl':
              _paymentQrUrl,
          'paymentVerified': false,
          'paymentVerifiedAt': null,

          // ================================================
          // SHOP TRACKING LOCATION
          // ================================================

          'shopLat':
              _shopLatitude,

          'shopLng':
              _shopLongitude,

          'shopLocation':
              GeoPoint(
            _shopLatitude!,
            _shopLongitude!,
          ),

          'shopLocationSource':
              _locationSource,

          'shopLocationUpdatedAt':
              FieldValue.serverTimestamp(),

          // ================================================
          // SHOP PHOTO
          // ================================================

          'photoUrl':
              _photoUrl,

          'shopPhotoUrl':
              _photoUrl,

          'shopImageUrl':
              _photoUrl,

          'imageUrl':
              _photoUrl,

          'logoUrl':
              _photoUrl,

          'shopPhotos':
              _photoUrl.isEmpty
                  ? <String>[]
                  : <String>[
                      _photoUrl,
                    ],

          'photoStorage':
              _photoUrl.isEmpty
                  ? ''
                  : 'cloudinary',

          'logoPath': '',

          'isActive': true,

          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (mounted) {
        setState(() {
          _paymentVerified = false;
        });
      }

      _message(
        'Shop profile saved. Payment details require Admin verification.',
      );
    } catch (error) {
      _message(
        'Could not save profile: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _contact(
    bool sms,
  ) async {
    final String phone =
        _phone.text
            .trim()
            .replaceAll(
              ' ',
              '',
            );

    if (phone.isEmpty) {
      _message(
        'First enter the seller phone number.',
      );

      return;
    }

    final Uri uri = Uri(
      scheme:
          sms ? 'sms' : 'tel',
      path: phone,
    );

    final bool opened =
        await launchUrl(
      uri,
      mode:
          LaunchMode.externalApplication,
    );

    if (!opened) {
      _message(
        'Could not open phone application.',
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int lines = 1,
    TextInputType? type,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
            const OutlineInputBorder(),
      ),
      validator: required
          ? (String? value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Enter $label.';
              }

              return null;
            }
          : null,
    );
  }

  Widget _shopLogo() {
    if (_uploadingPhoto ||
        _migratingOldPhoto) {
      return CircleAvatar(
        radius: 56,
        backgroundColor:
            Colors.blue.shade50,
        child:
            const CircularProgressIndicator(),
      );
    }

    if (_photoUrl.isNotEmpty &&
        _isNetworkPhoto(
          _photoUrl,
        )) {
      return CircleAvatar(
        radius: 56,
        backgroundColor:
            Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            _photoUrl,
            width: 112,
            height: 112,
            fit: BoxFit.cover,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const Icon(
                Icons.storefront,
                size: 52,
                color: Colors.blue,
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 56,
      backgroundColor:
          Colors.blue.shade50,
      child: const Icon(
        Icons.storefront,
        size: 52,
        color: Colors.blue,
      ),
    );
  }

  Widget _locationCard() {
    final bool ready =
        _hasCoordinates;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ready
                ? Icons.location_on
                : Icons.location_off,
            color: ready
                ? Colors.green
                : Colors.orange,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: ready
                ? Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children:
                        <Widget>[
                      const Text(
                        'Shop Map Location Ready',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Lat: ${_shopLatitude!.toStringAsFixed(7)}',
                      ),
                      Text(
                        'Lng: ${_shopLongitude!.toStringAsFixed(7)}',
                      ),
                      if (_locationSource
                          .isNotEmpty)
                        Text(
                          'Source: $_locationSource',
                        ),
                    ],
                  )
                : const Text(
                    'Shop map coordinates are not set yet.',
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _shop.dispose();
    _owner.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _description.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _esewaNumber.dispose();
    _khaltiNumber.dispose();
    _bankName.dispose();
    _bankAccountHolder.dispose();
    _bankAccountNumber.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Shop Profile',
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                children: <Widget>[
                  Center(
                    child: Stack(
                      children: <Widget>[
                        _shopLogo(),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            backgroundColor:
                                Colors.blue,
                            child: IconButton(
                              onPressed:
                                  _uploadingPhoto
                                      ? null
                                      : _pickLogo,
                              icon:
                                  const Icon(
                                Icons
                                    .camera_alt,
                                color:
                                    Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Center(
                    child:
                        TextButton.icon(
                      onPressed:
                          _uploadingPhoto
                              ? null
                              : _pickLogo,
                      icon:
                          const Icon(
                        Icons
                            .photo_library_outlined,
                      ),
                      label: Text(
                        _uploadingPhoto
                            ? 'Uploading...'
                            : 'Choose Shop Logo',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _field(
                    _shop,
                    'Shop Name',
                    Icons.store,
                    required: true,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _field(
                    _owner,
                    'Owner Name',
                    Icons.person,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _field(
                    _phone,
                    'Phone Number',
                    Icons.phone,
                    required: true,
                    type:
                        TextInputType.phone,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Card(
                    color:
                        Colors.blue.shade50,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          const Text(
                            'Seller Contact Preview',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Row(
                            children:
                                <Widget>[
                              Expanded(
                                child:
                                    OutlinedButton.icon(
                                  onPressed:
                                      () =>
                                          _contact(
                                    false,
                                  ),
                                  icon:
                                      const Icon(
                                    Icons.call,
                                  ),
                                  label:
                                      const Text(
                                    'Call Seller',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              Expanded(
                                child:
                                    OutlinedButton.icon(
                                  onPressed:
                                      () =>
                                          _contact(
                                    true,
                                  ),
                                  icon:
                                      const Icon(
                                    Icons
                                        .sms_outlined,
                                  ),
                                  label:
                                      const Text(
                                    'SMS Seller',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _field(
                    _email,
                    'Email (optional)',
                    Icons.email,
                    type:
                        TextInputType
                            .emailAddress,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Shop Location',
                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            _gettingLocation
                                ? null
                                : _location,
                        icon:
                            _gettingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height:
                                        18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .my_location,
                                  ),
                        label: Text(
                          _gettingLocation
                              ? 'Finding...'
                              : 'Use Current Location',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _field(
                    _address,
                    'Shop Address',
                    Icons.location_on,
                    required: true,
                    lines: 2,
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _latitudeController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Latitude',
                            prefixIcon:
                                Icon(
                              Icons
                                  .location_searching,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _longitudeController,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Longitude',
                            prefixIcon:
                                Icon(
                              Icons
                                  .explore,
                            ),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _applyManualCoordinates,
                          icon:
                              const Icon(
                            Icons
                                .location_on,
                          ),
                          label:
                              const Text(
                            'Set Coordinates',
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              _openMap,
                          icon:
                              const Icon(
                            Icons.map,
                          ),
                          label:
                              const Text(
                            'Open in Map',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  _locationCard(),

                  const SizedBox(
                    height: 16,
                  ),

                  _field(
                    _description,
                    'Shop Description (optional)',
                    Icons.description,
                    lines: 4,
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    'Payment / Payout Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'RD can use these verified details for seller settlement. Direct seller payment is allowed only for eligible single-seller orders.',
                  ),
                  const SizedBox(height: 12),

                  _field(
                    _esewaNumber,
                    'eSewa Number / Merchant ID',
                    Icons.account_balance_wallet_outlined,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  _field(
                    _khaltiNumber,
                    'Khalti Number / Merchant ID',
                    Icons.account_balance_wallet,
                    type: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  _field(
                    _bankName,
                    'Bank Name',
                    Icons.account_balance,
                  ),
                  const SizedBox(height: 12),

                  _field(
                    _bankAccountHolder,
                    'Bank Account Holder Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),

                  _field(
                    _bankAccountNumber,
                    'Bank Account Number',
                    Icons.numbers,
                  ),
                  const SizedBox(height: 12),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                _paymentVerified
                                    ? Icons.verified
                                    : Icons.pending_actions,
                                color: _paymentVerified
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _paymentVerified
                                      ? 'Payment details verified by Admin'
                                      : 'Payment details not verified yet',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_paymentQrUrl.isNotEmpty)
                            Center(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(12),
                                child: Image.network(
                                  _paymentQrUrl,
                                  height: 180,
                                  fit: BoxFit.contain,
                                  errorBuilder: (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return const SizedBox(
                                      height: 100,
                                      child: Center(
                                        child: Text(
                                          'Could not load payment QR.',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _uploadingPhoto
                                  ? null
                                  : _pickPaymentQr,
                              icon: const Icon(Icons.qr_code_2),
                              label: Text(
                                _paymentQrUrl.isEmpty
                                    ? 'Upload Payment QR'
                                    : 'Change Payment QR',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Changing payout details or QR requires Admin verification again.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    height: 52,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _saving ||
                                  _uploadingPhoto
                              ? null
                              : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons.save,
                            ),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : 'Save Shop Profile',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}