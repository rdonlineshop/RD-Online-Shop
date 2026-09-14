
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class HomestayCloudinaryService {
  const HomestayCloudinaryService._();

  static const String _cloudName = 'p83ttfym';
  static const String _uploadPreset = 'rd_online_shop_products';

  static Future<String?> pickAndUploadImage({
    int imageQuality = 85,
  }) async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    if (image == null) return null;

    final Uri uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final http.MultipartRequest request =
        http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name.isEmpty ? 'rd_homestay.jpg' : image.name,
      ),
    );

    final http.StreamedResponse response = await request.send();
    final String body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed: $body');
    }
    final dynamic decoded = jsonDecode(body);
    final String url = decoded is Map<String, dynamic>
        ? decoded['secure_url']?.toString().trim() ?? ''
        : '';
    if (url.isEmpty) throw Exception('Image URL was not received.');
    return url;
  }
}

class HomestayPartnerAuthPage extends StatefulWidget {
  const HomestayPartnerAuthPage({super.key});

  @override
  State<HomestayPartnerAuthPage> createState() =>
      _HomestayPartnerAuthPageState();
}

class _HomestayPartnerAuthPageState extends State<HomestayPartnerAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final doc = await FirebaseFirestore.instance
        .collection('homestay_partners')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    if (!mounted) return;
    if (doc.exists &&
        data['isApproved'] == true &&
        data['isActive'] == true &&
        data['role'] == 'homestay_partner') {
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const HomestayPartnerDashboardPage(),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_business, _owner, _phone, _address, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreAnonymous() async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_register) {
        await _doRegister();
      } else {
        await _doLogin();
      }
    } on FirebaseAuthException catch (e) {
      _msg(e.message ?? e.code);
    } catch (e) {
      _msg(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doRegister() async {
    final String email = _email.text.trim();
    final String password = _password.text;
    User? user;
    bool created = false;

    try {
      final c = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = c.user;
      created = true;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = c.user;
    }

    if (user == null) throw StateError('Account could not be created.');

    final ref = FirebaseFirestore.instance
        .collection('homestay_partners')
        .doc(user.uid);
    final old = await ref.get();
    if (old.exists) {
      final status = old.data()?['status']?.toString() ?? 'pending';
      if (status == 'pending') {
        throw StateError('Registration is already waiting for Admin approval.');
      }
      if (old.data()?['isApproved'] == true) {
        throw StateError('This account is already a Homestay Partner.');
      }
    }

    try {
      await ref.set({
        'partnerId': user.uid,
        'authUid': user.uid,
        'role': 'homestay_partner',
        'businessName': _business.text.trim(),
        'ownerName': _owner.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'email': email,
        'isApproved': false,
        'isActive': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (created) {
        try { await user.delete(); } catch (_) {}
      }
      rethrow;
    }

    await _restoreAnonymous();
    if (!mounted) return;
    setState(() {
      _register = false;
      _password.clear();
    });
    _msg('Registration submitted. Wait for RD Admin approval.');
  }

  Future<void> _doLogin() async {
    final c = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _email.text.trim(),
      password: _password.text,
    );
    final user = c.user;
    if (user == null) throw StateError('Login failed.');

    final doc = await FirebaseFirestore.instance
        .collection('homestay_partners')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};

    if (!doc.exists) {
      await _restoreAnonymous();
      _msg('This account is not registered as a Homestay Partner.');
      return;
    }
    if (data['status'] == 'rejected') {
      await _restoreAnonymous();
      _msg('Homestay Partner registration was rejected.');
      return;
    }
    if (data['isApproved'] != true) {
      await _restoreAnonymous();
      _msg('Waiting for RD Admin approval.');
      return;
    }
    if (data['isActive'] != true) {
      await _restoreAnonymous();
      _msg('Homestay Partner account is inactive.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('homestay_partners')
        .doc(user.uid)
        .update({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const HomestayPartnerDashboardPage(),
      ),
    );
  }

  String? _required(String? v, String label) =>
      (v ?? '').trim().isEmpty ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _register ? 'Homestay Partner Registration' : 'Homestay Partner Login',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Icon(Icons.home_work_rounded),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'RD Homestay Partner',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_register) ...[
                  _field(_business, 'Homestay / Business Name',
                      validator: (v) => _required(v, 'Homestay / Business Name')),
                  _field(_owner, 'Owner Full Name',
                      validator: (v) => _required(v, 'Owner Full Name')),
                  _field(_phone, 'Phone Number',
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v ?? '').trim().length < 7 ? 'Enter valid phone' : null),
                  _field(_address, 'Homestay Address',
                      validator: (v) => _required(v, 'Homestay Address')),
                ],
                _field(_email, 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                  final x = (v ?? '').trim();
                  return x.contains('@') ? null : 'Enter valid email';
                }),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    validator: (v) =>
                        (v ?? '').length < 6 ? 'Minimum 6 characters' : null,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_register
                            ? Icons.how_to_reg_rounded
                            : Icons.login_rounded),
                    label: Text(_register ? 'Submit Registration' : 'Login'),
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Already registered? Login'
                        : 'New Homestay Partner? Register',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class HomestayPartnerDashboardPage extends StatelessWidget {
  const HomestayPartnerDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const HomestayPartnerAuthPage(),
      ),
      (_) => false,
    );
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInAnonymously();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const HomestayPartnerAuthPage();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('homestay_partners')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final allowed = data['isApproved'] == true &&
            data['isActive'] == true &&
            data['role'] == 'homestay_partner';

        if (!allowed) {
          return const Scaffold(
            body: Center(
              child: Text('Homestay Partner account is not approved and active.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Homestay Partner Dashboard',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Logout',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 1000
                  ? 4
                  : c.maxWidth >= 700
                      ? 3
                      : 2;
              return GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: c.maxWidth < 500 ? .95 : 1.15,
                children: [
                  _card(context, Icons.home_work_rounded, 'Homestay Profile',
                      const HomestayPartnerProfilePage()),
                  _card(context, Icons.bed_rounded, 'Rooms',
                      const HomestayPartnerRoomsPage()),
                  _card(context, Icons.calendar_month_rounded, 'Availability',
                      const HomestayPartnerAvailabilityPage()),
                  _card(context, Icons.book_online_rounded, 'Bookings',
                      const HomestayPartnerBookingsPage()),
                  _card(context, Icons.account_balance_wallet_rounded, 'Earnings',
                      const HomestayPartnerFinancePage()),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, IconData icon, String title, Widget page) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => page),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class HomestayPartnerProfilePage extends StatefulWidget {
  const HomestayPartnerProfilePage({super.key});

  @override
  State<HomestayPartnerProfilePage> createState() =>
      _HomestayPartnerProfilePageState();
}

class _HomestayPartnerProfilePageState
    extends State<HomestayPartnerProfilePage> {
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
  bool _homestayApproved = false;
  bool _homestayActive = false;
  String _homestayStatus = 'not_created';

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>?
      get _homestayRef {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('homestays')
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
              .collection('homestay_partners')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> partner =
          partnerDoc.data() ??
              <String, dynamic>{};

      final DocumentSnapshot<Map<String, dynamic>>
          homestayDoc =
          await FirebaseFirestore.instance
              .collection('homestays')
              .doc(user.uid)
              .get();

      final Map<String, dynamic> homestay =
          homestayDoc.data() ??
              <String, dynamic>{};

      _exists = homestayDoc.exists;

      _name.text =
          homestay['name']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['name'].toString().trim()
              : partner['businessName']
                      ?.toString()
                      .trim() ??
                  '';

      _description.text =
          homestay['description']?.toString() ?? '';

      _location.text =
          homestay['location']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['location']
                  .toString()
                  .trim()
              : partner['address']
                      ?.toString()
                      .trim() ??
                  '';

      _address.text =
          homestay['address']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['address']
                  .toString()
                  .trim()
              : partner['address']
                      ?.toString()
                      .trim() ??
                  '';

      _city.text =
          homestay['city']?.toString() ?? '';
      _area.text =
          homestay['area']?.toString() ?? '';

      _phone.text =
          homestay['phone']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['phone'].toString().trim()
              : partner['phone']
                      ?.toString()
                      .trim() ??
                  '';

      _email.text =
          homestay['email']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['email'].toString().trim()
              : partner['email']
                      ?.toString()
                      .trim() ??
                  user.email ??
                  '';

      _checkInTime.text =
          homestay['checkInTime']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['checkInTime']
                  .toString()
                  .trim()
              : '12:00 PM';

      _checkOutTime.text =
          homestay['checkOutTime']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? homestay['checkOutTime']
                  .toString()
                  .trim()
              : '11:00 AM';

      _cancellationPolicy.text =
          homestay['cancellationPolicy']
                  ?.toString() ??
              '';

      _houseRules.text =
          homestay['houseRules']?.toString() ?? '';

      _profileUrl =
          homestay['profileUrl']
                  ?.toString()
                  .trim() ??
              '';

      _coverUrl =
          homestay['coverUrl']
                  ?.toString()
                  .trim() ??
              '';

      _latitude =
          (homestay['latitude'] as num?)
              ?.toDouble();
      _longitude =
          (homestay['longitude'] as num?)
              ?.toDouble();

      _homestayApproved =
          homestay['isApproved'] == true;
      _homestayActive =
          homestay['isActive'] == true;
      _homestayStatus =
          homestay['status']?.toString().trim() ??
              (_exists
                  ? 'pending'
                  : 'not_created');

      final List<dynamic> facilities =
          homestay['facilities'] is List
              ? homestay['facilities']
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
          homestay['photoUrls'] is List
              ? homestay['photoUrls']
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
        'Could not load homestay profile.\n'
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
    return HomestayCloudinaryService
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
        'Homestay logo/profile photo ready. '
        'Press Save Homestay Profile.',
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
        'Homestay cover photo ready. '
        'Press Save Homestay Profile.',
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
        'Press Save Homestay Profile.',
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
        'Homestay GPS location captured.',
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
        reference = _homestayRef;

    if (user == null ||
        user.isAnonymous ||
        reference == null) {
      _message(
        'Homestay Partner login is required.',
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
            'homestayId': user.uid,
            'partnerId': user.uid,
            ...editable,
            'rating': 0.0,
            'reviewCount': 0,
            'isApproved': false,
            'isActive': false,
            'status': 'pending_review',
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

        if (!_homestayApproved) {
          _homestayStatus = 'pending';
        }
      });

      _message(
        _homestayApproved
            ? 'Homestay profile saved successfully.'
            : 'Homestay profile submitted. Admin approval is required before rooms can go live.',
      );
    } catch (error) {
      _message(
        'Could not save homestay profile.\n'
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
            : _homestayApproved &&
                    _homestayActive
                ? 'APPROVED • ACTIVE'
                : _homestayApproved
                    ? 'APPROVED • INACTIVE'
                    : 'PENDING HOMESTAY APPROVAL';

    final Color statusColor =
        _homestayApproved &&
                _homestayActive
            ? _rdGreen
            : Colors.orange;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Homestay Profile',
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
                          _homestayApproved
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
                            '${_homestayStatus.toUpperCase()}',
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
                            'Homestay Photos',
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
                                .home_work_rounded,
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
                                                .home_work_rounded,
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
                                                  .home_work_rounded,
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
                                'Homestay Name',
                            icon: Icons
                                .home_work_rounded,
                            validator:
                                (
                              String? value,
                            ) =>
                                    _required(
                              value,
                              'Homestay Name',
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          _field(
                            controller:
                                _description,
                            label:
                                'Homestay Description',
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
                                'Homestay Email',
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
                            'Homestay Facilities',
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
                            ? 'Save Homestay Profile'
                            : 'Submit Homestay for Admin Approval',
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

class HomestayPartnerRoomsPage extends StatefulWidget {
  const HomestayPartnerRoomsPage({super.key});

  @override
  State<HomestayPartnerRoomsPage> createState() =>
      _HomestayPartnerRoomsPageState();
}

class _HomestayPartnerRoomsPageState
    extends State<HomestayPartnerRoomsPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdBlue =
      Color(0xFF1565C0);

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  Future<Map<String, dynamic>>
      _loadHomestay() async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return <String, dynamic>{};
    }

    final DocumentSnapshot<Map<String, dynamic>>
        doc = await FirebaseFirestore.instance
            .collection('homestays')
            .doc(user.uid)
            .get();

    return <String, dynamic>{
      '_exists': doc.exists,
      ...?doc.data(),
    };
  }

  Future<void> _openEditor({
    QueryDocumentSnapshot<
            Map<String, dynamic>>?
        roomDoc,
  }) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message(
        'Homestay Partner login is required.',
      );
      return;
    }

    final Map<String, dynamic> homestay =
        await _loadHomestay();

    if (!mounted) {
      return;
    }

    if (homestay['_exists'] != true) {
      _message(
        'Please create Homestay Profile first.',
      );
      return;
    }

    if (homestay['isApproved'] != true ||
        homestay['isActive'] != true) {
      _message(
        'Homestay must be approved and active '
        'before room types can be added.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext dialogContext) =>
              _RoomEditorDialog(
        partnerId: user.uid,
        homestayId: user.uid,
        existing: roomDoc,
      ),
    );
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;

    return 'Rs. '
        '${amount.toStringAsFixed(0)}';
  }

  Widget _roomImage(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color:
            _rdBlue.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(
        color:
            _rdBlue.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Homestay Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Rooms',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Room Type',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('homestay_rooms')
              .where(
                'partnerId',
                isEqualTo: user.uid,
              )
              .snapshots(),
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
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Text(
                    'Could not load rooms.\n'
                    '${snapshot.error}',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                docs =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>[])
                    .where(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          doc.data()[
                              'homestayId'] ==
                          user.uid,
                    )
                    .toList();

            docs.sort(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    first,
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    second,
              ) =>
                  (first.data()['name']
                              ?.toString() ??
                          '')
                      .compareTo(
                    second.data()['name']
                            ?.toString() ??
                        '',
                  ),
            );

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 950,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ),
                  children: <Widget>[
                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color: _rdGreen
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(14),
                      ),
                      child: const Text(
                        'Add each room type separately. '
                        'Every room type can have its own photos, '
                        'price, AC/Non-AC setting, bed, guest capacity, '
                        'facilities and total room count.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      'Room Types '
                      '(${docs.length})',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(
                            24,
                          ),
                          child: Text(
                            'No room type added yet.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(_roomCard),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _roomCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final bool active =
        data['isActive'] == true;

    final List<dynamic> photos =
        data['photoUrls'] is List
            ? data['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final String mainPhoto =
        data['photoUrl']
                ?.toString()
                .trim() ??
            (photos.isNotEmpty
                ? photos.first
                    .toString()
                    .trim()
                : '');

    final Widget details = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                data['name']?.toString() ??
                    'Room',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Chip(
              avatar: Icon(
                active
                    ? Icons
                        .check_circle_rounded
                    : Icons
                        .pause_circle_rounded,
                size: 17,
                color: active
                    ? _rdGreen
                    : Colors.grey,
              ),
              label: Text(
                active
                    ? 'ACTIVE'
                    : 'INACTIVE',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        Text(
          '${data['roomClass'] ?? ''} • '
          '${data['isAc'] == true ? 'AC' : 'Non-AC'} • '
          '${data['bed'] ?? ''}',
        ),
        const SizedBox(height: 5),
        Text(
          '${_money(data['pricePerNight'])} / night',
          style: const TextStyle(
            color: _rdBlue,
            fontSize: 16,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        Text(
          'Total rooms: '
          '${data['totalRooms'] ?? 0} • '
          'Max guests: '
          '${data['maxGuests'] ?? 0}',
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () =>
                  _openEditor(
                roomDoc: doc,
              ),
              icon: const Icon(
                Icons.edit_rounded,
              ),
              label: const Text('Edit'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  await doc.reference.update(
                    <String, dynamic>{
                      'isActive': !active,
                      'updatedAt': FieldValue
                          .serverTimestamp(),
                    },
                  );
                } catch (error) {
                  _message(
                    'Could not update room.\n'
                    '$error',
                  );
                }
              },
              icon: Icon(
                active
                    ? Icons
                        .pause_circle_rounded
                    : Icons
                        .play_circle_rounded,
              ),
              label: Text(
                active
                    ? 'Deactivate'
                    : 'Activate',
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final Widget photo =
                ClipRRect(
              borderRadius:
                  BorderRadius.circular(12),
              child: SizedBox(
                width:
                    constraints.maxWidth <
                            560
                        ? double.infinity
                        : 190,
                height: 160,
                child:
                    _roomImage(mainPhoto),
              ),
            );

            if (constraints.maxWidth <
                560) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  photo,
                  const SizedBox(
                    height: 10,
                  ),
                  details,
                ],
              );
            }

            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                photo,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomEditorDialog
    extends StatefulWidget {
  const _RoomEditorDialog({
    required this.partnerId,
    required this.homestayId,
    this.existing,
  });

  final String partnerId;
  final String homestayId;
  final QueryDocumentSnapshot<
      Map<String, dynamic>>? existing;

  @override
  State<_RoomEditorDialog> createState() =>
      _RoomEditorDialogState();
}

class _RoomEditorDialogState
    extends State<_RoomEditorDialog> {
  static const Color _rdBlue =
      Color(0xFF1565C0);

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController
      _description;
  late final TextEditingController
      _roomClass;
  late final TextEditingController _bed;
  late final TextEditingController
      _maxGuests;
  late final TextEditingController _price;
  late final TextEditingController
      _totalRooms;
  late final TextEditingController
      _facilities;

  final List<String> _photoUrls =
      <String>[];

  bool _isAc = false;
  bool _breakfastIncluded = false;
  bool _freeCancellation = false;
  bool _active = true;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic> data =
        widget.existing?.data() ??
            <String, dynamic>{};

    _name = TextEditingController(
      text:
          data['name']?.toString() ?? '',
    );

    _description =
        TextEditingController(
      text: data['description']
              ?.toString() ??
          '',
    );

    _roomClass = TextEditingController(
      text: data['roomClass']
              ?.toString() ??
          '',
    );

    _bed = TextEditingController(
      text:
          data['bed']?.toString() ?? '',
    );

    _maxGuests =
        TextEditingController(
      text: (data['maxGuests'] ?? 2)
          .toString(),
    );

    _price = TextEditingController(
      text: data['pricePerNight']
              ?.toString() ??
          '',
    );

    _totalRooms =
        TextEditingController(
      text: (data['totalRooms'] ?? 1)
          .toString(),
    );

    final List<dynamic> facilities =
        data['facilities'] is List
            ? data['facilities']
                as List<dynamic>
            : <dynamic>[];

    _facilities =
        TextEditingController(
      text: facilities
          .map(
            (dynamic value) =>
                value.toString(),
          )
          .join(', '),
    );

    final List<dynamic> photos =
        data['photoUrls'] is List
            ? data['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    _photoUrls.addAll(
      photos
          .map(
            (dynamic value) =>
                value.toString().trim(),
          )
          .where(
            (String value) =>
                value.isNotEmpty,
          ),
    );

    final String singlePhoto =
        data['photoUrl']
                ?.toString()
                .trim() ??
            '';

    if (singlePhoto.isNotEmpty &&
        !_photoUrls
            .contains(singlePhoto)) {
      _photoUrls.insert(
        0,
        singlePhoto,
      );
    }

    _isAc =
        data['isAc'] == true;
    _breakfastIncluded =
        data['breakfastIncluded'] ==
            true;
    _freeCancellation =
        data['freeCancellation'] ==
            true;

    _active = widget.existing == null
        ? true
        : data['isActive'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _roomClass.dispose();
    _bed.dispose();
    _maxGuests.dispose();
    _price.dispose();
    _totalRooms.dispose();
    _facilities.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_uploading) {
      return;
    }

    if (_photoUrls.length >= 5) {
      _message(
        'Maximum 5 photos per room type.',
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String? url =
          await HomestayCloudinaryService
              .pickAndUploadImage();

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        if (!_photoUrls.contains(url)) {
          _photoUrls.add(url);
        }
      });
    } catch (error) {
      _message(
        'Photo upload failed.\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
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

    final double? price =
        double.tryParse(
      _price.text.trim(),
    );

    final int? total =
        int.tryParse(
      _totalRooms.text.trim(),
    );

    final int? guests =
        int.tryParse(
      _maxGuests.text.trim(),
    );

    if (price == null ||
        price < 0) {
      _message(
        'Enter a valid room price.',
      );
      return;
    }

    if (total == null ||
        total < 1) {
      _message(
        'Total rooms must be at least 1.',
      );
      return;
    }

    if (guests == null ||
        guests < 1) {
      _message(
        'Max guests must be at least 1.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final CollectionReference<
              Map<String, dynamic>>
          collection =
          FirebaseFirestore.instance
              .collection('homestay_rooms');

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          widget.existing?.reference ??
              collection.doc();

      final List<String> facilities =
          _facilities.text
              .split(',')
              .map(
                (String value) =>
                    value.trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty,
              )
              .toSet()
              .toList();

      final Map<String, dynamic> editable =
          <String, dynamic>{
        'name': _name.text.trim(),
        'description':
            _description.text.trim(),
        'roomClass':
            _roomClass.text.trim(),
        'isAc': _isAc,
        'bed': _bed.text.trim(),
        'maxGuests': guests,
        'pricePerNight': price,
        'totalRooms': total,
        'photoUrl':
            _photoUrls.isEmpty
                ? ''
                : _photoUrls.first,
        'photoUrls':
            List<String>.from(
          _photoUrls,
        ),
        'facilities': facilities,
        'breakfastIncluded':
            _breakfastIncluded,
        'freeCancellation':
            _freeCancellation,
        'isActive':
            widget.existing == null
                ? true
                : _active,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (widget.existing == null) {
        await reference.set(
          <String, dynamic>{
            'roomId': reference.id,
            'homestayId': widget.homestayId,
            'partnerId':
                widget.partnerId,
            ...editable,
            'createdAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      } else {
        await reference.update(editable);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      _message(
        'Could not save room.\n$error',
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
        SnackBar(content: Text(message)),
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
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  Widget _photos() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Room Photos',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_photoUrls.length}/5',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_photoUrls.isNotEmpty)
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  _photoUrls.length,
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
                return Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(10),
                      child: Image.network(
                        _photoUrls[index],
                        width: 155,
                        height: 125,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                Container(
                          width: 155,
                          height: 125,
                          color: _rdBlue
                              .withValues(
                            alpha: 0.08,
                          ),
                          child: const Icon(
                            Icons
                                .bed_rounded,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child:
                          IconButton.filledTonal(
                        tooltip:
                            'Remove Photo',
                        onPressed: () {
                          setState(() {
                            _photoUrls
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
          )
        else
          const Text(
            'No room photo added yet.',
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed:
              _uploading
                  ? null
                  : _addPhoto,
          icon: _uploading
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
            'Add Room Photo',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Room Type'
            : 'Edit Room Type',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                _photos(),
                const SizedBox(height: 12),
                _field(
                  controller: _name,
                  label: 'Room Name',
                  hint:
                      'Standard Room / Deluxe AC Room',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Room Name',
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _roomClass,
                  label: 'Room Class',
                  hint:
                      'Economy / Standard / Deluxe / Suite',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Room Class',
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _description,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _bed,
                  label: 'Bed',
                  hint:
                      '1 Queen Bed / 2 Single Beds',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Bed',
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _field(
                        controller:
                            _maxGuests,
                        label: 'Max Guests',
                        keyboardType:
                            TextInputType
                                .number,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _field(
                        controller:
                            _totalRooms,
                        label: 'Total Rooms',
                        keyboardType:
                            TextInputType
                                .number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _price,
                  label:
                      'Price Per Night (Rs.)',
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _facilities,
                  label:
                      'Room Facilities (comma separated)',
                  hint:
                      'Wi-Fi, TV, Hot Water, Balcony',
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value: _isAc,
                  title:
                      const Text('AC Room'),
                  onChanged: (bool value) {
                    setState(() {
                      _isAc = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      _breakfastIncluded,
                  title: const Text(
                    'Breakfast Included',
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _breakfastIncluded =
                          value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      _freeCancellation,
                  title: const Text(
                    'Free Cancellation',
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _freeCancellation =
                          value;
                    });
                  },
                ),
                if (widget.existing !=
                    null)
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    value: _active,
                    title: const Text(
                      'Room Active',
                    ),
                    onChanged:
                        (bool value) {
                      setState(() {
                        _active = value;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving
              ? null
              : () =>
                  Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed:
              _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.save_rounded,
                ),
          label: const Text(
            'Save Room',
          ),
        ),
      ],
    );
  }
}

class HomestayPartnerAvailabilityPage extends StatefulWidget {
  const HomestayPartnerAvailabilityPage({super.key});

  @override
  State<HomestayPartnerAvailabilityPage> createState() =>
      _HomestayPartnerAvailabilityPageState();
}

class _HomestayPartnerAvailabilityPageState
    extends State<HomestayPartnerAvailabilityPage> {
  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _open = true;
  int _blocked = 0;
  String? _savingRoomId;

  User? get _user => FirebaseAuth.instance.currentUser;

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  String _key(DateTime date) =>
      '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _dates() {
    final List<DateTime> result = <DateTime>[];
    DateTime current = DateTime(
      _from.year,
      _from.month,
      _from.day,
    );
    final DateTime end = DateTime(
      _to.year,
      _to.month,
      _to.day,
    );

    while (!current.isAfter(end)) {
      result.add(current);
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  Future<void> _pickDate({required bool from}) async {
    final DateTime today = DateTime.now();
    final DateTime firstDate = DateTime(
      today.year,
      today.month,
      today.day,
    );
    final DateTime initial = from ? _from : _to;

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : initial,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (from) {
        _from = selected;
        if (_to.isBefore(_from)) {
          _to = _from;
        }
      } else {
        _to = selected;
      }
    });
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _save(
    QueryDocumentSnapshot<Map<String, dynamic>> room,
  ) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message('Homestay Partner login is required.');
      return;
    }

    if (_savingRoomId != null) {
      return;
    }

    final Map<String, dynamic> roomData = room.data();
    final int total =
        (roomData['totalRooms'] as num?)?.toInt() ?? 1;

    if (_blocked < 0 || _blocked > total) {
      _message(
        'Blocked rooms must be between 0 and $total for this room type.',
      );
      return;
    }

    final List<DateTime> dates = _dates();
    if (dates.isEmpty) {
      _message('Please select a valid date range.');
      return;
    }

    setState(() {
      _savingRoomId = room.id;
    });

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final List<MapEntry<
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>>>
          entries = <MapEntry<
              DocumentReference<Map<String, dynamic>>,
              DocumentSnapshot<Map<String, dynamic>>>>[];

      for (final DateTime date in dates) {
        final DocumentReference<Map<String, dynamic>> reference =
            firestore.collection('homestay_inventory').doc(
                  '${room.id}_${_key(date)}',
                );
        final DocumentSnapshot<Map<String, dynamic>> old =
            await reference.get();
        entries.add(MapEntry(reference, old));
      }

      WriteBatch batch = firestore.batch();
      int writes = 0;

      for (int index = 0; index < dates.length; index++) {
        final DateTime date = dates[index];
        final DocumentReference<Map<String, dynamic>> reference =
            entries[index].key;
        final DocumentSnapshot<Map<String, dynamic>> old =
            entries[index].value;
        final int booked =
            (old.data()?['bookedRooms'] as num?)?.toInt() ?? 0;

        if (_blocked + booked > total) {
          throw StateError(
            'Blocked + booked rooms cannot exceed total rooms on ${_date(date)}.',
          );
        }

        batch.set(
          reference,
          <String, dynamic>{
            'inventoryId': reference.id,
            'homestayId': user.uid,
            'partnerId': user.uid,
            'roomId': room.id,
            'date': Timestamp.fromDate(
              DateTime(date.year, date.month, date.day),
            ),
            'totalRooms': total,
            'blockedRooms': _blocked,
            'bookedRooms': booked,
            'availableRooms': _open
                ? total - _blocked - booked
                : 0,
            'isOpen': _open,
            'lastBookingId':
                old.data()?['lastBookingId'] ?? '',
            'createdAt': old.data()?['createdAt'] ??
                FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        writes++;
        if (writes >= 450) {
          await batch.commit();
          batch = firestore.batch();
          writes = 0;
        }
      }

      if (writes > 0) {
        await batch.commit();
      }

      _message(
        'Availability saved for ${roomData['name'] ?? 'room'} '
        '(${_date(_from)} - ${_date(_to)}).',
      );
    } catch (error) {
      _message('Could not save availability.\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _savingRoomId = null;
        });
      }
    }
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Homestay Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Availability',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('homestay_rooms')
              .where(
                'partnerId',
                isEqualTo: user.uid,
              )
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<
                    QuerySnapshot<Map<String, dynamic>>>
                snapshot,
          ) {
            if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load room types.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final List<QueryDocumentSnapshot<
                    Map<String, dynamic>>> rooms =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String, dynamic>>>[])
                    .where(
                      (QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              room) =>
                          room.data()['homestayId'] ==
                          user.uid,
                    )
                    .toList();

            rooms.sort(
              (
                QueryDocumentSnapshot<Map<String, dynamic>> a,
                QueryDocumentSnapshot<Map<String, dynamic>> b,
              ) => (a.data()['name']?.toString() ?? '')
                  .compareTo(
                b.data()['name']?.toString() ?? '',
              ),
            );

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 950,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _rdGreen.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Manage date-wise room availability. '
                        'Choose the date range, open/close booking, '
                        'set blocked rooms, then save for each room type.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Date Range',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final Widget fromButton =
                                    FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _pickDate(from: true),
                                  icon: const Icon(
                                    Icons.login_rounded,
                                  ),
                                  label: Text(
                                    'From  ${_date(_from)}',
                                  ),
                                );

                                final Widget toButton =
                                    FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _pickDate(from: false),
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                  ),
                                  label: Text(
                                    'To  ${_date(_to)}',
                                  ),
                                );

                                if (constraints.maxWidth >= 600) {
                                  return Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: fromButton,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: toButton,
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    fromButton,
                                    const SizedBox(height: 10),
                                    toButton,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _open,
                              title: const Text(
                                'Open for booking',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                _open
                                    ? 'Customers can book available rooms.'
                                    : 'Selected dates will be closed for booking.',
                              ),
                              onChanged: (bool value) {
                                setState(() {
                                  _open = value;
                                });
                              },
                            ),
                            const Divider(),
                            Row(
                              children: <Widget>[
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Blocked Rooms',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'Rooms kept unavailable by the Homestay Partner.',
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _blocked <= 0
                                      ? null
                                      : () {
                                          setState(() {
                                            _blocked--;
                                          });
                                        },
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                  ),
                                ),
                                Text(
                                  '$_blocked',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _blocked++;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Room Types (${rooms.length})',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (rooms.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No room type added yet. Add room types first.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...rooms.map(
                        (
                          QueryDocumentSnapshot<
                                  Map<String, dynamic>>
                              room,
                        ) {
                          final Map<String, dynamic> data =
                              room.data();
                          final bool active =
                              data['isActive'] == true;
                          final int total =
                              (data['totalRooms'] as num?)
                                      ?.toInt() ??
                                  0;
                          final bool saving =
                              _savingRoomId == room.id;

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: LayoutBuilder(
                                builder: (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  final Widget details = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              data['name']
                                                      ?.toString() ??
                                                  'Room',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          Chip(
                                            label: Text(
                                              active
                                                  ? 'ACTIVE'
                                                  : 'INACTIVE',
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${data['roomClass'] ?? ''} • '
                                        '${data['isAc'] == true ? 'AC' : 'Non-AC'} • '
                                        '${data['bed'] ?? ''}',
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${_money(data['pricePerNight'])} / night',
                                        style: const TextStyle(
                                          color: _rdBlue,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'Total rooms: $total • '
                                        'Max guests: ${data['maxGuests'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  );

                                  final Widget saveButton =
                                      SizedBox(
                                    width: constraints.maxWidth < 560
                                        ? double.infinity
                                        : 190,
                                    child: FilledButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () => _save(room),
                                      icon: saving
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.save_rounded,
                                            ),
                                      label: const Text(
                                        'Save Availability',
                                      ),
                                    ),
                                  );

                                  if (constraints.maxWidth < 560) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        details,
                                        const SizedBox(height: 12),
                                        saveButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: <Widget>[
                                      Expanded(child: details),
                                      const SizedBox(width: 12),
                                      saveButton,
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomestayPartnerBookingsPage extends StatelessWidget {
  const HomestayPartnerBookingsPage({super.key});

  Future<void> _update(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    await ref.update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(body: Center(child: Text('Partner login required.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Homestay Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('homestay_bookings')
            .where('partnerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = s.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No bookings.'));
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final status = d['bookingStatus']?.toString() ?? 'request_submitted';
              final payment = d['paymentStatus']?.toString() ?? 'pending';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        d['guestName']?.toString() ?? 'Guest',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(d['roomName']?.toString() ?? 'Room'),
                      Text('Total: Rs. ${(d['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                      Text('Status: ${status.toUpperCase()}'),
                      Text('Payment: ${payment.toUpperCase()}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (status == 'request_submitted')
                            FilledButton(
                              onPressed: () => _update(context, doc.reference, {
                                'bookingStatus': 'confirmed',
                                'confirmationStatus': 'confirmed',
                                'partnerConfirmed': true,
                                'confirmedAt': FieldValue.serverTimestamp(),
                              }),
                              child: const Text('Confirm'),
                            ),
                          if (status == 'request_submitted')
                            OutlinedButton(
                              onPressed: () => _update(context, doc.reference, {
                                'bookingStatus': 'rejected',
                                'confirmationStatus': 'rejected',
                                'rejectedAt': FieldValue.serverTimestamp(),
                              }),
                              child: const Text('Reject'),
                            ),
                          if (payment != 'paid' &&
                              {'confirmed', 'checked_in', 'completed'}.contains(status))
                            OutlinedButton(
                              onPressed: () => _update(context, doc.reference, {
                                'paymentStatus': 'paid',
                                'paidAt': FieldValue.serverTimestamp(),
                              }),
                              child: const Text('Mark Paid'),
                            ),
                          if (status == 'confirmed')
                            FilledButton.tonal(
                              onPressed: () => _update(context, doc.reference, {
                                'bookingStatus': 'checked_in',
                                'checkedInAt': FieldValue.serverTimestamp(),
                              }),
                              child: const Text('Check In'),
                            ),
                          if (status == 'checked_in')
                            FilledButton.tonal(
                              onPressed: () => _update(context, doc.reference, {
                                'bookingStatus': 'completed',
                                'completedAt': FieldValue.serverTimestamp(),
                              }),
                              child: const Text('Complete'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class HomestayPartnerFinancePage extends StatelessWidget {
  const HomestayPartnerFinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(body: Center(child: Text('Partner login required.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Homestay Earnings')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('homestay_settings')
            .doc('global')
            .snapshots(),
        builder: (context, settings) {
          final percent =
              (settings.data?.data()?['commissionPercent'] as num?)?.toDouble() ?? 0;
          final fee =
              (settings.data?.data()?['monthlyFee'] as num?)?.toDouble() ?? 0;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('homestay_bookings')
                .where('partnerId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, s) {
              double paid = 0;
              int count = 0;
              for (final doc in s.data?.docs ?? []) {
                final d = doc.data();
                if (d['paymentStatus'] == 'paid') {
                  paid += (d['totalAmount'] as num?)?.toDouble() ?? 0;
                  count++;
                }
              }
              final commission = paid * percent / 100;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _tile('Paid Booking Amount', 'Rs. ${paid.toStringAsFixed(0)}'),
                  _tile('Paid Bookings', '$count'),
                  _tile('RD Commission Rate', '${percent.toStringAsFixed(2)}%'),
                  _tile('Estimated RD Commission',
                      'Rs. ${commission.toStringAsFixed(0)}'),
                  _tile('Monthly Platform Fee', 'Rs. ${fee.toStringAsFixed(0)}'),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _tile(String label, String value) => Card(
        child: ListTile(
          title: Text(label),
          subtitle: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

Future<void> _openHomestayDirections(
  BuildContext context, {
  required double? homestayLatitude,
  required double? homestayLongitude,
  required String homestayName,
}) async {
  if (homestayLatitude == null ||
      homestayLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Homestay GPS location is not saved yet. '
            'Homestay Partner must enable Location, capture current location '
            'and save the Homestay Profile first.',
          ),
        ),
      );
    return;
  }

  try {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw StateError(
        'Please turn ON phone Location/GPS first.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      throw StateError(
        'Customer live location permission is required for navigation.',
      );
    }

    final Position customerPosition =
        await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final Uri directionsUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      <String, String>{
        'api': '1',
        'origin':
            '${customerPosition.latitude},${customerPosition.longitude}',
        'destination':
            '$homestayLatitude,$homestayLongitude',
        'destination_place_id': '',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      }..removeWhere(
          (String key, String value) => value.isEmpty,
        ),
    );

    final bool opened = await launchUrl(
      directionsUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw StateError(
        'Could not open map/navigation app.',
      );
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not start navigation to $homestayName.\n$error',
          ),
        ),
      );
  }
}

Future<void> _openHomestayPin(
  BuildContext context, {
  required double? homestayLatitude,
  required double? homestayLongitude,
  required String homestayName,
}) async {
  if (homestayLatitude == null ||
      homestayLongitude == null) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Homestay GPS location is not saved yet.',
          ),
        ),
      );
    return;
  }

  try {
    final Uri mapUri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '$homestayLatitude,$homestayLongitude',
      },
    );

    final bool opened = await launchUrl(
      mapUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw StateError(
        'Could not open map.',
      );
    }
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Could not open $homestayName location.\n$error',
          ),
        ),
      );
  }
}

class HomestayBookingPage extends StatefulWidget {
  const HomestayBookingPage({super.key});

  @override
  State<HomestayBookingPage> createState() =>
      _HomestayBookingPageState();
}

class _HomestayBookingPageState
    extends State<HomestayBookingPage> {
  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  final TextEditingController _search =
      TextEditingController();

  DateTime _checkIn =
      DateTime.now()
          .add(const Duration(days: 1));

  DateTime _checkOut =
      DateTime.now()
          .add(const Duration(days: 2));

  bool _sessionReady = false;
  String _sessionError = '';
  bool _homestayPartnerSessionActive = false;

  Position? _customerPosition;
  bool _locatingCustomer = false;
  bool _nearestFirst = false;
  String _locationStatus = '';

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    try {
      if (FirebaseAuth.instance.currentUser ==
          null) {
        await FirebaseAuth.instance
            .signInAnonymously();
      }

      final User? user =
          FirebaseAuth.instance.currentUser;

      bool partnerSession = false;

      if (user != null && !user.isAnonymous) {
        try {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              partnerDoc =
              await FirebaseFirestore.instance
                  .collection(
                    'homestay_partners',
                  )
                  .doc(user.uid)
                  .get();

          final Map<String, dynamic> data =
              partnerDoc.data() ??
                  <String, dynamic>{};

          partnerSession =
              partnerDoc.exists &&
                  data['isApproved'] == true &&
                  data['isActive'] == true &&
                  data['role'] ==
                      'homestay_partner';
        } catch (_) {
          partnerSession = false;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sessionReady = true;
        _sessionError = '';
        _homestayPartnerSessionActive =
            partnerSession;
      });

      if (!partnerSession) {
        await _loadLocationIfAlreadyAllowed();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sessionReady = false;
        _sessionError =
            'Could not start customer session.\n$error';
      });
    }
  }

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  int get _nights {
    final int value = _day(_checkOut)
        .difference(_day(_checkIn))
        .inDays;

    return value < 1 ? 1 : value;
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _stayDates(
    DateTime checkIn,
    DateTime checkOut,
  ) {
    final int nights = _day(checkOut)
        .difference(_day(checkIn))
        .inDays;

    if (nights < 1) {
      return <DateTime>[];
    }

    return List<DateTime>.generate(
      nights,
      (int index) => _day(checkIn)
          .add(Duration(days: index)),
    );
  }

  Future<void> _pickCheckIn() async {
    final DateTime now = DateTime.now();
    final DateTime first =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _checkIn.isBefore(first)
              ? first
              : _checkIn,
      firstDate: first,
      lastDate:
          DateTime(now.year + 2, 12, 31),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _checkIn = picked;

      if (!_checkOut
          .isAfter(_checkIn)) {
        _checkOut =
            _checkIn.add(
          const Duration(days: 1),
        );
      }
    });
  }

  Future<void> _pickCheckOut() async {
    final DateTime first =
        _checkIn.add(
      const Duration(days: 1),
    );

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate:
          _checkOut.isBefore(first)
              ? first
              : _checkOut,
      firstDate: first,
      lastDate: DateTime(
        _checkIn.year + 2,
        12,
        31,
      ),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _checkOut = picked;
    });
  }

  String _normalized(String value) {
    return value
        .toLowerCase()
        .replaceAll('काठमाडौं', 'kathmandu')
        .replaceAll('काठमाडौँ', 'kathmandu')
        .replaceAll('ललितपुर', 'lalitpur')
        .replaceAll('भक्तपुर', 'bhaktapur')
        .trim();
  }

  bool _isKathmanduValleySearch(String query) {
    final String normalized = _normalized(query);

    return normalized.contains('kathmandu') ||
        normalized.contains('kathmandu valley') ||
        normalized.contains('ktm valley');
  }

  bool _matches(
    Map<String, dynamic> data,
  ) {
    final String query =
        _normalized(_search.text);

    if (query.isEmpty) {
      return true;
    }

    final String searchable = _normalized(
      <String>[
        data['name']?.toString() ?? '',
        data['location']?.toString() ?? '',
        data['address']?.toString() ?? '',
        data['city']?.toString() ?? '',
        data['area']?.toString() ?? '',
        data['description']?.toString() ?? '',
      ].join(' '),
    );

    if (searchable.contains(query)) {
      return true;
    }

    if (_isKathmanduValleySearch(query)) {
      const List<String> valleyTerms = <String>[
        'kathmandu',
        'lalitpur',
        'patan',
        'bhaktapur',
        'kirtipur',
        'tokha',
        'budhanilkantha',
        'madhyapur',
        'thimi',
        'chandragiri',
        'gokarneshwor',
        'nagarjun',
        'tarakeshwor',
      ];

      return valleyTerms.any(
        (String term) =>
            searchable.contains(term),
      );
    }

    return false;
  }

  double? _homestayDistanceKm(
    Map<String, dynamic> homestay,
  ) {
    final Position? customer =
        _customerPosition;

    final double? latitude =
        (homestay['latitude'] as num?)
            ?.toDouble();

    final double? longitude =
        (homestay['longitude'] as num?)
            ?.toDouble();

    if (customer == null ||
        latitude == null ||
        longitude == null) {
      return null;
    }

    final double meters =
        Geolocator.distanceBetween(
      customer.latitude,
      customer.longitude,
      latitude,
      longitude,
    );

    return meters / 1000;
  }

  int? _estimatedDriveMinutes(
    Map<String, dynamic> homestay,
  ) {
    final double? distance =
        _homestayDistanceKm(homestay);

    if (distance == null) {
      return null;
    }

    final double averageKph =
        distance <= 10
            ? 25
            : distance <= 40
                ? 35
                : 50;

    final int minutes =
        ((distance / averageKph) * 60)
            .round();

    return minutes < 1 ? 1 : minutes;
  }

  Future<void> _loadLocationIfAlreadyAllowed() async {
    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        return;
      }

      final LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission !=
              LocationPermission.always &&
          permission !=
              LocationPermission.whileInUse) {
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customerPosition = position;
        _nearestFirst = true;
        _locationStatus =
            'Nearest approved Homestays are shown first.';
      });
    } catch (_) {
      // Near Me remains optional until tapped.
    }
  }

  Future<void> _useMyLocation() async {
    if (_locatingCustomer) {
      return;
    }

    setState(() {
      _locatingCustomer = true;
      _locationStatus =
          'Getting your live location...';
    });

    try {
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw StateError(
          'Please turn ON phone Location/GPS first.',
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
              LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required to show nearest Homestays.',
        );
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customerPosition = position;
        _nearestFirst = true;
        _locationStatus =
            'Nearest approved Homestays are shown first.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationStatus = error.toString();
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not use Near Me.\n$error',
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _locatingCustomer = false;
        });
      }
    }
  }

  void _sortHomestaysByDistance(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        docs,
  ) {
    if (!_nearestFirst ||
        _customerPosition == null) {
      return;
    }

    docs.sort(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            first,
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            second,
      ) {
        final double firstDistance =
            _homestayDistanceKm(first.data()) ??
                double.infinity;

        final double secondDistance =
            _homestayDistanceKm(second.data()) ??
                double.infinity;

        return firstDistance
            .compareTo(secondDistance);
      },
    );
  }

  Future<int> _roomAvailability({
    required String roomId,
    required int totalRooms,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    int minimum = totalRooms;

    final List<DateTime> dates =
        _stayDates(
      checkIn,
      checkOut,
    );

    if (dates.isEmpty ||
        totalRooms < 1) {
      return 0;
    }

    for (final DateTime date in dates) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'homestay_inventory',
              )
              .doc(
                '${roomId}_${_dateKey(date)}',
              )
              .get();

      // No inventory document means the Homestay has not blocked/closed
      // this future date and no RD booking has reserved it yet.
      // In that case all rooms are available by default.
      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      // Homestay Partner can explicitly close a date.
      if (data['isOpen'] == false) {
        return 0;
      }

      final int blocked =
          (data['blockedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int booked =
          (data['bookedRooms'] as num?)
                  ?.toInt() ??
              0;

      // Recalculate from the current room total instead of trusting a
      // stale availableRooms value left by an older test/update.
      final int calculated =
          totalRooms - blocked - booked;

      final int available =
          calculated < 0
              ? 0
              : calculated > totalRooms
                  ? totalRooms
                  : calculated;

      if (available < minimum) {
        minimum = available;
      }
    }

    return minimum < 0 ? 0 : minimum;
  }

  Future<_HomestaySummary>
      _homestayAvailability(
    String homestayId,
  ) async {
    final QuerySnapshot<
            Map<String, dynamic>>
        rooms =
        await FirebaseFirestore.instance
            .collection('homestay_rooms')
            .where(
              'homestayId',
              isEqualTo: homestayId,
            )
            .where(
              'isActive',
              isEqualTo: true,
            )
            .get();

    int totalAvailable = 0;
    double? lowestAvailablePrice;

    for (final QueryDocumentSnapshot<
            Map<String, dynamic>>
        room in rooms.docs) {
      final Map<String, dynamic> data =
          room.data();

      final int total =
          (data['totalRooms'] as num?)
                  ?.toInt() ??
              0;

      final int available =
          await _roomAvailability(
        roomId: room.id,
        totalRooms: total,
        checkIn: _checkIn,
        checkOut: _checkOut,
      );

      if (available > 0) {
        totalAvailable += available;

        final double price =
            (data['pricePerNight']
                        as num?)
                    ?.toDouble() ??
                0;

        if (lowestAvailablePrice ==
                null ||
            price <
                lowestAvailablePrice) {
          lowestAvailablePrice =
              price;
        }
      }
    }

    return _HomestaySummary(
      activeRoomTypes:
          rooms.docs.length,
      availableRooms:
          totalAvailable,
      lowestAvailablePrice:
          lowestAvailablePrice,
    );
  }

  void _openMyBookings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const MyHomestayBookingsPage(),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons
                .calendar_month_rounded,
          ),
          border:
              const OutlineInputBorder(),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: <Color>[
            _rdBlue,
            _rdGreen,
          ],
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: const Row(
        children: <Widget>[
          CircleAvatar(
            radius: 27,
            backgroundColor:
                Colors.white24,
            child: Icon(
              Icons
                  .hotel_class_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose an approved homestay. Use Near Me to see closest Homestays first, '
              'or search Homestay / city / area such as Kathmandu. '
              'Check photos, facilities, price and real date-wise availability before booking.',
              style: TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _search,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Search Homestay / city / area (e.g. Kathmandu)',
                prefixIcon: Icon(
                  Icons.search_rounded,
                ),
                border:
                    OutlineInputBorder(),
              ),
              onChanged: (_) =>
                  setState(() {}),
            ),
            const SizedBox(
              height: 10,
            ),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final Widget nearMe =
                    FilledButton.tonalIcon(
                  onPressed: _locatingCustomer
                      ? null
                      : _useMyLocation,
                  icon: _locatingCustomer
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.my_location_rounded,
                        ),
                  label: Text(
                    _customerPosition == null
                        ? 'Near Me'
                        : 'Refresh Near Me',
                  ),
                );

                final Widget orderButton =
                    OutlinedButton.icon(
                  onPressed:
                      _customerPosition == null
                          ? null
                          : () {
                              setState(() {
                                _nearestFirst =
                                    !_nearestFirst;
                              });
                            },
                  icon: Icon(
                    _nearestFirst
                        ? Icons.near_me_rounded
                        : Icons
                            .format_list_numbered_rounded,
                  ),
                  label: Text(
                    _nearestFirst
                        ? 'Nearest First'
                        : 'Original Order',
                  ),
                );

                if (constraints.maxWidth >=
                    560) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: nearMe),
                      const SizedBox(width: 10),
                      Expanded(child: orderButton),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: <Widget>[
                    nearMe,
                    const SizedBox(height: 8),
                    orderButton,
                  ],
                );
              },
            ),
            if (_locationStatus.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _locationStatus,
                style: const TextStyle(
                  color: _rdBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(
              height: 10,
            ),
            LayoutBuilder(
              builder:
                  (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final Widget checkIn =
                    _dateBox(
                  label: 'Check-in',
                  value:
                      _date(_checkIn),
                  onTap:
                      _pickCheckIn,
                );

                final Widget checkOut =
                    _dateBox(
                  label: 'Check-out',
                  value:
                      _date(_checkOut),
                  onTap:
                      _pickCheckOut,
                );

                if (constraints
                        .maxWidth >=
                    620) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: checkIn,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: checkOut,
                      ),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    checkIn,
                    const SizedBox(
                      height: 10,
                    ),
                    checkOut,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Stay: $_nights night(s)',
              style: const TextStyle(
                color: _rdBlue,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyHomestaysMap(
    List<QueryDocumentSnapshot<
            Map<String, dynamic>>>
        docs,
  ) {
    final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        mappedHomestays = docs.where(
      (
        QueryDocumentSnapshot<
                Map<String, dynamic>>
            doc,
      ) {
        final Map<String, dynamic> homestay =
            doc.data();

        return homestay['latitude'] is num &&
            homestay['longitude'] is num;
      },
    ).toList();

    if (mappedHomestays.isEmpty &&
        _customerPosition == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.map_outlined,
                color: _rdBlue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  docs.isEmpty
                      ? 'No Homestay is available on the map yet.'
                      : 'Homestay map is waiting for saved GPS coordinates. '
                          'Homestay Partners must save their Homestay location first.',
                  style: const TextStyle(
                    height: 1.4,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    LatLng center;

    if (_customerPosition != null) {
      center = LatLng(
        _customerPosition!.latitude,
        _customerPosition!.longitude,
      );
    } else {
      final Map<String, dynamic> first =
          mappedHomestays.first.data();

      center = LatLng(
        (first['latitude'] as num)
            .toDouble(),
        (first['longitude'] as num)
            .toDouble(),
      );
    }

    final List<Marker> markers = <Marker>[
      if (_customerPosition != null)
        Marker(
          point: LatLng(
            _customerPosition!.latitude,
            _customerPosition!.longitude,
          ),
          width: 52,
          height: 52,
          child: const Tooltip(
            message: 'My Location',
            child: Icon(
              Icons.my_location_rounded,
              size: 34,
              color: _rdBlue,
            ),
          ),
        ),
      ...mappedHomestays.map(
        (
          QueryDocumentSnapshot<
                  Map<String, dynamic>>
              doc,
        ) {
          final Map<String, dynamic> homestay =
              doc.data();

          final double latitude =
              (homestay['latitude'] as num)
                  .toDouble();

          final double longitude =
              (homestay['longitude'] as num)
                  .toDouble();

          final String homestayName =
              homestay['name']?.toString() ??
                  'Homestay';

          return Marker(
            point:
                LatLng(latitude, longitude),
            width: 60,
            height: 60,
            child: Tooltip(
              message: homestayName,
              child: GestureDetector(
                onTap: () =>
                    _openHomestayPin(
                  context,
                  homestayLatitude: latitude,
                  homestayLongitude:
                      longitude,
                  homestayName: homestayName,
                ),
                child: const Icon(
                  Icons.hotel_rounded,
                  size: 39,
                  color: _rdGreen,
                ),
              ),
            ),
          );
        },
      ),
    ];

    return Card(
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
              children: <Widget>[
                const Icon(
                  Icons.map_rounded,
                  color: _rdBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nearby Homestays Map',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                if (_customerPosition != null)
                  Text(
                    '${mappedHomestays.length} Homestay(s)',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 285,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom:
                    _customerPosition != null
                        ? 13
                        : 12,
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'rd_online_shop_new',
                ),
                MarkerLayer(
                  markers: markers,
                ),
                RichAttributionWidget(
                  attributions: const <
                      SourceAttribution>[
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Blue marker = your location • Green Homestay marker = approved Homestay. '
              'Tap a Homestay marker to open its map location.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homestayCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> homestay =
        doc.data();

    final String cover =
        homestay['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        homestay['profileUrl']
                ?.toString()
                .trim() ??
            '';

    final double? distanceKm =
        _homestayDistanceKm(homestay);

    final int? driveMinutes =
        _estimatedDriveMinutes(homestay);

    final double? homestayLatitude =
        (homestay['latitude'] as num?)
            ?.toDouble();

    final double? homestayLongitude =
        (homestay['longitude'] as num?)
            ?.toDouble();

    return FutureBuilder<_HomestaySummary>(
      future:
          _homestayAvailability(doc.id),
      builder: (
        BuildContext context,
        AsyncSnapshot<_HomestaySummary>
            snapshot,
      ) {
        final bool loading =
            snapshot.connectionState ==
                ConnectionState.waiting;

        final _HomestaySummary summary =
            snapshot.data ??
                const _HomestaySummary(
                  activeRoomTypes: 0,
                  availableRooms: 0,
                  lowestAvailablePrice:
                      null,
                );

        final bool fullyBooked =
            !loading &&
                summary.activeRoomTypes >
                    0 &&
                summary.availableRooms <=
                    0;

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          clipBehavior:
              Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    HomestayDetailsPage(
                  homestayId: doc.id,
                  homestay: homestay,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    SizedBox(
                      height: 180,
                      width:
                          double.infinity,
                      child: cover.isEmpty
                          ? Container(
                              color: _rdBlue
                                  .withValues(
                                alpha: 0.08,
                              ),
                              alignment:
                                  Alignment
                                      .center,
                              child: const Icon(
                                Icons
                                    .hotel_rounded,
                                color:
                                    _rdBlue,
                                size: 58,
                              ),
                            )
                          : Image.network(
                              cover,
                              fit:
                                  BoxFit.cover,
                              errorBuilder:
                                  (
                                _,
                                __,
                                ___,
                              ) =>
                                      Container(
                                color: _rdBlue
                                    .withValues(
                                  alpha: 0.08,
                                ),
                                alignment:
                                    Alignment
                                        .center,
                                child:
                                    const Icon(
                                  Icons
                                      .hotel_rounded,
                                  color:
                                      _rdBlue,
                                  size: 58,
                                ),
                              ),
                            ),
                    ),
                    if (fullyBooked)
                      Positioned.fill(
                        child: Container(
                          alignment:
                              Alignment
                                  .center,
                          color: Colors.black
                              .withValues(
                            alpha: 0.48,
                          ),
                          child:
                              const Text(
                            'FULLY BOOKED',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets
                          .all(13),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            _rdGreen
                                .withValues(
                          alpha: 0.10,
                        ),
                        backgroundImage:
                            profile.isEmpty
                                ? null
                                : NetworkImage(
                                    profile,
                                  ),
                        child:
                            profile.isEmpty
                                ? const Icon(
                                    Icons
                                        .hotel_class_rounded,
                                    color:
                                        _rdGreen,
                                  )
                                : null,
                      ),
                      const SizedBox(
                        width: 11,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: <Widget>[
                            Text(
                              homestay['name']
                                      ?.toString() ??
                                  'Homestay',
                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              homestay['location']
                                      ?.toString() ??
                                  '',
                            ),
                            if ((homestay['phone']
                                        ?.toString()
                                        .trim() ??
                                    '')
                                .isNotEmpty)
                              SelectableText(
                                homestay['phone']
                                    .toString(),
                                style:
                                    const TextStyle(
                                  color:
                                      _rdGreen,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            const SizedBox(
                              height: 7,
                            ),
                            if (loading)
                              const SizedBox(
                                width: 140,
                                child:
                                    LinearProgressIndicator(),
                              )
                            else if (summary
                                    .activeRoomTypes ==
                                0)
                              const Text(
                                'No active room type yet',
                                style:
                                    TextStyle(
                                  color:
                                      Colors
                                          .grey,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              )
                            else if (fullyBooked)
                              const Text(
                                'No room available for selected dates',
                                style:
                                    TextStyle(
                                  color:
                                      _rdRed,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              )
                            else
                              Text(
                                '${summary.availableRooms} room(s) available'
                                '${summary.lowestAvailablePrice == null ? '' : ' • from Rs. ${summary.lowestAvailablePrice!.toStringAsFixed(0)}/night'}',
                                style:
                                    const TextStyle(
                                  color:
                                      _rdGreen,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),
                            if (distanceKm != null) ...<Widget>[
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                'Distance: '
                                '${distanceKm.toStringAsFixed(distanceKm < 10 ? 1 : 0)} km'
                                '${driveMinutes == null ? '' : ' • approx. $driveMinutes min drive'}',
                                style:
                                    const TextStyle(
                                  color:
                                      _rdBlue,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'Approximate only. Use Navigate for live Maps route/time.',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                            if (homestayLatitude != null &&
                                homestayLongitude != null) ...<Widget>[
                              const SizedBox(
                                height: 7,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: <Widget>[
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openHomestayPin(
                                      context,
                                      homestayLatitude:
                                          homestayLatitude,
                                      homestayLongitude:
                                          homestayLongitude,
                                      homestayName:
                                          homestay['name']
                                                  ?.toString() ??
                                              'Homestay',
                                    ),
                                    icon: const Icon(
                                      Icons.map_rounded,
                                    ),
                                    label: const Text(
                                      'Map',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openHomestayDirections(
                                      context,
                                      homestayLatitude:
                                          homestayLatitude,
                                      homestayLongitude:
                                          homestayLongitude,
                                      homestayName:
                                          homestay['name']
                                                  ?.toString() ??
                                              'Homestay',
                                    ),
                                    icon: const Icon(
                                      Icons
                                          .navigation_rounded,
                                    ),
                                    label: const Text(
                                      'Navigate',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(
                              height: 5,
                            ),
                            const Text(
                              'Tap to view rooms',
                              style:
                                  TextStyle(
                                color:
                                    _rdBlue,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Homestays'),
        ),
        body: Center(
          child:
              _sessionError.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _sessionError,
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          FilledButton(
                            onPressed:
                                _ensureSession,
                            child:
                                const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      );
    }

    if (_homestayPartnerSessionActive) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Homestays',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 520,
            ),
            child: Card(
              margin:
                  const EdgeInsets.all(20),
              child: Padding(
                padding:
                    const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_person_rounded,
                      size: 54,
                      color: _rdBlue,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Homestay Partner session is active',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'For privacy, a Homestay Partner account can manage only its own Homestay. '
                      'Other Homestays are not available while this Partner ID is active.\n\n'
                      'To book a Homestay as a customer, first use the Homestay Partner Logout button '
                      'and then open the customer Homestay booking section.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                      ),
                      label: const Text(
                        'Back',
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

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Homestays',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Homestay Partner Login',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const HomestayPartnerAuthPage(),
              ),
            ),
            icon: const Icon(
              Icons.person_outline,
            ),
          ),
          IconButton(
            tooltip:
                'My Homestay Bookings',
            onPressed:
                _openMyBookings,
            icon: const Icon(
              Icons
                  .book_online_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('homestays')
              .where(
                'isApproved',
                isEqualTo: true,
              )
              .where(
                'isActive',
                isEqualTo: true,
              )
              .snapshots(),
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
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    24,
                  ),
                  child: Text(
                    'Could not load homestays.\n'
                    '${snapshot.error}',
                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            final List<
                    QueryDocumentSnapshot<
                        Map<String, dynamic>>>
                docs =
                (snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>[])
                    .where(
                      (
                        QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          _matches(
                        doc.data(),
                      ),
                    )
                    .toList();

            _sortHomestaysByDistance(docs);

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 1100,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  children: <Widget>[
                    _header(),
                    const SizedBox(
                      height: 14,
                    ),
                    _searchCard(),
                    const SizedBox(
                      height: 16,
                    ),
                    _nearbyHomestaysMap(
                      docs,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    Text(
                      'Available Homestays '
                      '(${docs.length})',
                      style:
                          const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(
                            24,
                          ),
                          child: Text(
                            'No approved homestay is available yet.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(
                        _homestayCard,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomestayDetailsPage
    extends StatelessWidget {
  const HomestayDetailsPage({
    required this.homestayId,
    required this.homestay,
    required this.checkIn,
    required this.checkOut,
    super.key,
  });

  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final String homestayId;
  final Map<String, dynamic> homestay;
  final DateTime checkIn;
  final DateTime checkOut;

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  Widget _homestayGallery() {
    final List<dynamic> photos =
        homestay['photoUrls'] is List
            ? homestay['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final List<String> urls =
        photos
            .map(
              (dynamic value) =>
                  value.toString().trim(),
            )
            .where(
              (String value) =>
                  value.isNotEmpty,
            )
            .toSet()
            .toList();

    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount: urls.length,
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
          return ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: Image.network(
              urls[index],
              width: 195,
              height: 145,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) =>
                      Container(
                width: 195,
                height: 145,
                color: _rdBlue
                    .withValues(
                  alpha: 0.08,
                ),
                child: const Icon(
                  Icons.image_rounded,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: <Widget>[
        Icon(
          icon,
          color: _rdBlue,
        ),
        const SizedBox(height: 3),
        Text(label),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String cover =
        homestay['coverUrl']
                ?.toString()
                .trim() ??
            '';

    final String profile =
        homestay['profileUrl']
                ?.toString()
                .trim() ??
            '';

    final List<dynamic> facilities =
        homestay['facilities'] is List
            ? homestay['facilities']
                as List<dynamic>
            : <dynamic>[];

    final double? homestayLatitude =
        (homestay['latitude'] as num?)?.toDouble();

    final double? homestayLongitude =
        (homestay['longitude'] as num?)?.toDouble();

    final bool hasHomestayGps =
        homestayLatitude != null &&
            homestayLongitude != null;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          homestay['name']?.toString() ??
              'Homestay',
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1050,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                Card(
                  clipBehavior:
                      Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 230,
                        child: cover.isEmpty
                            ? Container(
                                color: _rdBlue
                                    .withValues(
                                  alpha: 0.08,
                                ),
                                alignment:
                                    Alignment
                                        .center,
                                child:
                                    const Icon(
                                  Icons
                                      .hotel_rounded,
                                  color:
                                      _rdBlue,
                                  size: 64,
                                ),
                              )
                            : Image.network(
                                cover,
                                fit:
                                    BoxFit.cover,
                                errorBuilder:
                                    (
                                  _,
                                  __,
                                  ___,
                                ) =>
                                        Container(
                                  color: _rdBlue
                                      .withValues(
                                    alpha: 0.08,
                                  ),
                                  alignment:
                                      Alignment
                                          .center,
                                  child:
                                      const Icon(
                                    Icons
                                        .hotel_rounded,
                                    color:
                                        _rdBlue,
                                    size: 64,
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets
                                .all(14),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  _rdGreen
                                      .withValues(
                                alpha: 0.10,
                              ),
                              backgroundImage:
                                  profile
                                          .isEmpty
                                      ? null
                                      : NetworkImage(
                                          profile,
                                        ),
                              child:
                                  profile
                                          .isEmpty
                                      ? const Icon(
                                          Icons
                                              .hotel_class_rounded,
                                          color:
                                              _rdGreen,
                                          size:
                                              34,
                                        )
                                      : null,
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
                                    homestay['name']
                                            ?.toString() ??
                                        'Homestay',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          22,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),
                                  Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons
                                            .location_on_rounded,
                                        color:
                                            Colors.red,
                                        size:
                                            18,
                                      ),
                                      const SizedBox(
                                        width:
                                            4,
                                      ),
                                      Expanded(
                                        child: Text(
                                          homestay['location']?.toString() ??
                                              '',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((homestay['phone']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                      .isNotEmpty)
                                    Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons
                                              .phone_rounded,
                                          color:
                                              _rdGreen,
                                          size:
                                              18,
                                        ),
                                        const SizedBox(
                                          width:
                                              4,
                                        ),
                                        SelectableText(
                                          homestay['phone']
                                              .toString(),
                                        ),
                                      ],
                                    ),
                                  if ((homestay['email']
                                              ?.toString()
                                              .trim() ??
                                          '')
                                      .isNotEmpty)
                                    SelectableText(
                                      homestay['email']
                                          .toString(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((homestay['description']
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            14,
                            0,
                            14,
                            14,
                          ),
                          child: Text(
                            homestay[
                                    'description']
                                .toString(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Homestay Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasHomestayGps
                              ? 'Homestay GPS location is saved. '
                                  'You can view the homestay pin or navigate '
                                  'from your current live location.'
                              : 'Homestay GPS location has not been saved yet.',
                          style: TextStyle(
                            color: hasHomestayGps
                                ? _rdGreen
                                : Colors.orange,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        if (hasHomestayGps) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openHomestayPin(
                                  context,
                                  homestayLatitude:
                                      homestayLatitude,
                                  homestayLongitude:
                                      homestayLongitude,
                                  homestayName:
                                      homestay['name']
                                              ?.toString() ??
                                          'Homestay',
                                ),
                                icon: const Icon(
                                  Icons
                                      .location_on_rounded,
                                ),
                                label: const Text(
                                  'View Homestay Location',
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openHomestayDirections(
                                  context,
                                  homestayLatitude:
                                      homestayLatitude,
                                  homestayLongitude:
                                      homestayLongitude,
                                  homestayName:
                                      homestay['name']
                                              ?.toString() ??
                                          'Homestay',
                                ),
                                icon: const Icon(
                                  Icons
                                      .navigation_rounded,
                                ),
                                label: const Text(
                                  'Navigate from My Live Location',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                _homestayGallery(),
                if ((homestay['photoUrls']
                            as List?)
                        ?.isNotEmpty ==
                    true)
                  const SizedBox(
                    height: 12,
                  ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _summary(
                            'Check-in',
                            _date(checkIn),
                            Icons
                                .login_rounded,
                          ),
                        ),
                        Expanded(
                          child: _summary(
                            'Check-out',
                            _date(checkOut),
                            Icons
                                .logout_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (facilities.isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 12,
                  ),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          const Text(
                            'Homestay Facilities',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children:
                                facilities
                                    .map(
                              (
                                dynamic value,
                              ) =>
                                  Chip(
                                avatar:
                                    const Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                      _rdGreen,
                                  size:
                                      17,
                                ),
                                label: Text(
                                  value
                                      .toString(),
                                ),
                              ),
                            )
                                    .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if ((homestay['cancellationPolicy']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 12,
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons
                            .event_busy_rounded,
                      ),
                      title: const Text(
                        'Cancellation Policy',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      subtitle: Text(
                        homestay[
                                'cancellationPolicy']
                            .toString(),
                      ),
                    ),
                  ),
                ],
                if ((homestay['houseRules']
                            ?.toString()
                            .trim() ??
                        '')
                    .isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 8,
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.rule_rounded,
                      ),
                      title: const Text(
                        'House Rules',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                      subtitle: Text(
                        homestay['houseRules']
                            .toString(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(
                  height: 16,
                ),
                const Text(
                  'Rooms',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(
                        'homestay_rooms',
                      )
                      .where(
                        'homestayId',
                        isEqualTo:
                            homestayId,
                      )
                      .where(
                        'isActive',
                        isEqualTo:
                            true,
                      )
                      .snapshots(),
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<
                            QuerySnapshot<
                                Map<String,
                                    dynamic>>>
                        snapshot,
                  ) {
                    if (snapshot
                                .connectionState ==
                            ConnectionState
                                .waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
                    }

                    if (snapshot
                        .hasError) {
                      return Text(
                        'Could not load rooms.\n'
                        '${snapshot.error}',
                      );
                    }

                    final List<
                            QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>>
                        docs =
                        snapshot
                                .data
                                ?.docs ??
                            <QueryDocumentSnapshot<
                                Map<String,
                                    dynamic>>>[];

                    if (docs.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding:
                              EdgeInsets
                                  .all(
                            24,
                          ),
                          child: Text(
                            'No active room is available.',
                            textAlign:
                                TextAlign
                                    .center,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: docs
                          .map(
                            (
                              QueryDocumentSnapshot<
                                      Map<String,
                                          dynamic>>
                                  roomDoc,
                            ) =>
                                CustomerRoomCard(
                              homestayId:
                                  homestayId,
                              homestay: homestay,
                              roomDoc:
                                  roomDoc,
                              checkIn:
                                  checkIn,
                              checkOut:
                                  checkOut,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerRoomCard
    extends StatelessWidget {
  const CustomerRoomCard({
    required this.homestayId,
    required this.homestay,
    required this.roomDoc,
    required this.checkIn,
    required this.checkOut,
    super.key,
  });

  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  final String homestayId;
  final Map<String, dynamic> homestay;
  final QueryDocumentSnapshot<
      Map<String, dynamic>> roomDoc;
  final DateTime checkIn;
  final DateTime checkOut;

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  List<DateTime> _stayDates() {
    final int nights = _day(checkOut)
        .difference(_day(checkIn))
        .inDays;

    if (nights < 1) {
      return <DateTime>[];
    }

    return List<DateTime>.generate(
      nights,
      (int index) =>
          _day(checkIn).add(
        Duration(days: index),
      ),
    );
  }

  Future<int> _availableForStay() async {
    final Map<String, dynamic> room =
        roomDoc.data();

    final int totalRooms =
        (room['totalRooms'] as num?)
                ?.toInt() ??
            0;

    int minimum = totalRooms;

    if (totalRooms < 1) {
      return 0;
    }

    for (final DateTime date
        in _stayDates()) {
      final DocumentSnapshot<
              Map<String, dynamic>>
          inventory =
          await FirebaseFirestore.instance
              .collection(
                'homestay_inventory',
              )
              .doc(
                '${roomDoc.id}_${_dateKey(date)}',
              )
              .get();

      // Missing date inventory = open by default with all rooms
      // available, unless a booking/block/closed record exists.
      if (!inventory.exists) {
        continue;
      }

      final Map<String, dynamic> data =
          inventory.data() ??
              <String, dynamic>{};

      if (data['isOpen'] == false) {
        return 0;
      }

      final int blocked =
          (data['blockedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int booked =
          (data['bookedRooms'] as num?)
                  ?.toInt() ??
              0;

      final int calculated =
          totalRooms - blocked - booked;

      final int available =
          calculated < 0
              ? 0
              : calculated > totalRooms
                  ? totalRooms
                  : calculated;

      if (available < minimum) {
        minimum = available;
      }
    }

    return minimum < 0 ? 0 : minimum;
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ??
            0;

    return 'Rs. '
        '${amount.toStringAsFixed(0)}';
  }

  Widget _roomPhotos(
    List<String> photos,
  ) {
    if (photos.isEmpty) {
      return Container(
        height: 175,
        color:
            _rdBlue.withValues(
          alpha: 0.08,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      );
    }

    if (photos.length == 1) {
      return SizedBox(
        height: 175,
        child: Image.network(
          photos.first,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  Container(
            color:
                _rdBlue.withValues(
              alpha: 0.08,
            ),
            child: const Icon(
              Icons.bed_rounded,
              size: 52,
              color: _rdBlue,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 175,
      child: PageView.builder(
        itemCount: photos.length,
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          return Image.network(
            photos[index],
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) =>
                    Container(
              color:
                  _rdBlue.withValues(
                alpha: 0.08,
              ),
              child: const Icon(
                Icons.bed_rounded,
                size: 52,
                color: _rdBlue,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> room =
        roomDoc.data();

    final List<dynamic> rawPhotos =
        room['photoUrls'] is List
            ? room['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final List<String> photos =
        rawPhotos
            .map(
              (dynamic value) =>
                  value.toString().trim(),
            )
            .where(
              (String value) =>
                  value.isNotEmpty,
            )
            .toSet()
            .toList();

    final String single =
        room['photoUrl']
                ?.toString()
                .trim() ??
            '';

    if (single.isNotEmpty &&
        !photos.contains(single)) {
      photos.insert(0, single);
    }

    final List<dynamic> facilities =
        room['facilities'] is List
            ? room['facilities']
                as List<dynamic>
            : <dynamic>[];

    return FutureBuilder<int>(
      future: _availableForStay(),
      builder: (
        BuildContext context,
        AsyncSnapshot<int> snapshot,
      ) {
        final bool loading =
            snapshot.connectionState ==
                ConnectionState.waiting;

        final int available =
            snapshot.data ?? 0;

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 10,
          ),
          clipBehavior:
              Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _roomPhotos(photos),
                  if (!loading &&
                      available <= 0)
                    Positioned.fill(
                      child: Container(
                        alignment:
                            Alignment
                                .center,
                        color: Colors.black
                            .withValues(
                          alpha: 0.48,
                        ),
                        child:
                            const Text(
                          'NOT AVAILABLE',
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsets
                        .all(13),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      room['name']
                              ?.toString() ??
                          'Room',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    Text(
                      '${room['roomClass'] ?? ''} • '
                      '${room['isAc'] == true ? 'AC Room' : 'Non-AC'} • '
                      '${room['bed'] ?? ''}',
                    ),
                    if ((room['description']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 4,
                        ),
                        child: Text(
                          room['description']
                              .toString(),
                        ),
                      ),
                    const SizedBox(
                      height: 6,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Chip(
                          label: Text(
                            'Max '
                            '${room['maxGuests'] ?? 0} guests',
                          ),
                        ),
                        if (room[
                                'breakfastIncluded'] ==
                            true)
                          const Chip(
                            label: Text(
                              'Breakfast Included',
                            ),
                          ),
                        if (room[
                                'freeCancellation'] ==
                            true)
                          const Chip(
                            label: Text(
                              'Free Cancellation',
                            ),
                          ),
                      ],
                    ),
                    if (facilities
                        .isNotEmpty) ...<
                        Widget>[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        facilities
                            .map(
                              (
                                dynamic value,
                              ) =>
                                  value
                                      .toString(),
                            )
                            .join(' • '),
                        style: TextStyle(
                          color: Colors
                              .grey
                              .shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      '${_money(room['pricePerNight'])} / night',
                      style:
                          const TextStyle(
                        color: _rdBlue,
                        fontSize: 17,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    if (loading)
                      const LinearProgressIndicator()
                    else
                      Text(
                        available > 0
                            ? '$available room(s) available for selected dates'
                            : 'Fully booked for selected dates',
                        style: TextStyle(
                          color: available > 0
                              ? _rdGreen
                              : _rdRed,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    const SizedBox(
                      height: 9,
                    ),
                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed: !loading &&
                                available >
                                    0
                            ? () =>
                                Navigator.push<
                                    void>(
                                  context,
                                  MaterialPageRoute<
                                      void>(
                                    builder:
                                        (_) =>
                                            HomestayRoomBookingPage(
                                      homestayId:
                                          homestayId,
                                      homestay:
                                          homestay,
                                      roomId:
                                          roomDoc.id,
                                      room:
                                          room,
                                      checkIn:
                                          checkIn,
                                      checkOut:
                                          checkOut,
                                      available:
                                          available,
                                    ),
                                  ),
                                )
                            : null,
                        icon: const Icon(
                          Icons
                              .book_online_rounded,
                        ),
                        label: Text(
                          available > 0
                              ? 'Book Now'
                              : 'Full',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomestayRoomBookingPage
    extends StatefulWidget {
  const HomestayRoomBookingPage({
    required this.homestayId,
    required this.homestay,
    required this.roomId,
    required this.room,
    required this.checkIn,
    required this.checkOut,
    required this.available,
    super.key,
  });

  final String homestayId;
  final Map<String, dynamic> homestay;
  final String roomId;
  final Map<String, dynamic> room;
  final DateTime checkIn;
  final DateTime checkOut;
  final int available;

  @override
  State<HomestayRoomBookingPage>
      createState() =>
          _HomestayRoomBookingPageState();
}

class _HomestayRoomBookingPageState
    extends State<HomestayRoomBookingPage> {
  static const Color _rdBlue =
      Color(0xFF1565C0);
  static const Color _rdGreen =
      Color(0xFF2E7D32);

  final TextEditingController
      _guestName =
      TextEditingController();

  final TextEditingController _phone =
      TextEditingController();

  final TextEditingController
      _paymentReference =
      TextEditingController();

  int _roomCount = 1;

  String _paymentOption =
      'pay_at_homestay';

  String _paymentMethod =
      'bank_transfer';

  bool _submitting = false;
  bool _loadingDirectPayment = true;
  bool _uploadingPaymentProof = false;

  String _paymentProofUrl = '';

  Map<String, dynamic> _directPayment =
      <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadDirectPayment();
  }

  @override
  void dispose() {
    _guestName.dispose();
    _phone.dispose();
    _paymentReference.dispose();
    super.dispose();
  }

  DateTime _day(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      );

  int get _nights {
    final int value =
        _day(widget.checkOut)
            .difference(
              _day(widget.checkIn),
            )
            .inDays;

    return value < 1 ? 1 : value;
  }

  double get _price =>
      (widget.room['pricePerNight']
                  as num?)
              ?.toDouble() ??
          0;

  double get _total =>
      _price *
      _nights *
      _roomCount;

  String _money(double value) =>
      'Rs. '
      '${value.toStringAsFixed(0)}';

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  Future<User> _ensureUser() async {
    final User? current =
        FirebaseAuth.instance.currentUser;

    if (current != null) {
      return current;
    }

    final UserCredential credential =
        await FirebaseAuth.instance
            .signInAnonymously();

    final User? user = credential.user;

    if (user == null) {
      throw StateError(
        'Could not create customer session.',
      );
    }

    return user;
  }

  String get _partnerId =>
      widget.homestay['partnerId']
              ?.toString()
              .trim() ??
          '';

  Future<void> _loadDirectPayment() async {
    final String partnerId = _partnerId;

    if (partnerId.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingDirectPayment = false;
        });
      }
      return;
    }

    try {
      final DocumentSnapshot<
              Map<String, dynamic>>
          doc =
          await FirebaseFirestore.instance
              .collection(
                'homestay_direct_payment_accounts',
              )
              .doc(partnerId)
              .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _directPayment =
            doc.data() ??
                <String, dynamic>{};

        _loadingDirectPayment = false;

        final List<String> methods =
            _availablePaymentMethods();

        if (methods.isNotEmpty &&
            !methods.contains(
              _paymentMethod,
            )) {
          _paymentMethod =
              methods.first;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDirectPayment = false;
          _directPayment =
              <String, dynamic>{};
        });
      }
    }
  }

  bool get _directPaymentEnabled =>
      _directPayment['enabled'] == true &&
      _availablePaymentMethods().isNotEmpty;

  List<String> _availablePaymentMethods() {
    final List<String> methods =
        <String>[];

    if ((_directPayment['esewaNumber']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('esewa');
    }

    if ((_directPayment['khaltiNumber']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('khalti');
    }

    if ((_directPayment['bankName']
                ?.toString()
                .trim() ??
            '')
            .isNotEmpty &&
        (_directPayment['bankAccountNumber']
                ?.toString()
                .trim() ??
            '')
            .isNotEmpty) {
      methods.add('bank_transfer');
    }

    if ((_directPayment['connectIpsId']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('connectips');
    }

    if ((_directPayment[
                    'mobileBankingDetails']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('mobile_banking');
    }

    if ((_directPayment['paymentQrUrl']
                ?.toString()
                .trim() ??
            '')
        .isNotEmpty) {
      methods.add('homestay_qr');
    }

    return methods;
  }

  String _paymentMethodLabel(
    String method,
  ) {
    switch (method) {
      case 'esewa':
        return 'eSewa';
      case 'khalti':
        return 'Khalti';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'connectips':
        return 'connectIPS';
      case 'mobile_banking':
        return 'Mobile Banking';
      case 'homestay_qr':
        return 'Homestay Payment QR';
      default:
        return method;
    }
  }

  Widget _detailLine(
    String label,
    String value,
  ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }

  Widget _directPaymentSection() {
    if (_loadingDirectPayment) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (!_directPaymentEnabled) {
      return Container(
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange
              .withValues(alpha: 0.10),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Text(
          'This Homestay has not enabled Direct Online Payment yet. '
          'Please choose Pay at Homestay.',
          style: TextStyle(
            color: Colors.orange,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      );
    }

    final List<String> methods =
        _availablePaymentMethods();

    final String qrUrl =
        _directPayment['paymentQrUrl']
                ?.toString()
                .trim() ??
            '';

    final String instructions =
        _directPayment['instructions']
                ?.toString()
                .trim() ??
            '';

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding:
              const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _rdGreen
                .withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Text(
            'Payment goes DIRECTLY to this Homestay account. '
            'RD Online Shop does not receive this booking payment. '
            'After transfer, enter the transaction reference and upload proof. '
            'The Homestay Partner must verify actual receipt before payment becomes PAID.',
            style: TextStyle(
              color: _rdGreen,
              fontWeight:
                  FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue:
              methods.contains(
                _paymentMethod,
              )
                  ? _paymentMethod
                  : methods.first,
          decoration:
              const InputDecoration(
            labelText:
                'Direct Payment Method',
            prefixIcon: Icon(
              Icons.payments_rounded,
            ),
            border:
                OutlineInputBorder(),
          ),
          items: methods
              .map(
                (String method) =>
                    DropdownMenuItem<
                        String>(
                  value: method,
                  child: Text(
                    _paymentMethodLabel(
                      method,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value == null) {
              return;
            }

            setState(() {
              _paymentMethod = value;
            });
          },
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding:
                const EdgeInsets.all(
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                Text(
                  '${widget.homestay['name'] ?? 'Homestay'} Receiving Details',
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                if (_paymentMethod ==
                    'esewa') ...<Widget>[
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'esewaName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'eSewa ID',
                    _directPayment[
                                'esewaNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'khalti') ...<Widget>[
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'khaltiName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Khalti ID',
                    _directPayment[
                                'khaltiNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'bank_transfer') ...<
                    Widget>[
                  _detailLine(
                    'Bank',
                    _directPayment[
                                'bankName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Account Name',
                    _directPayment[
                                'bankAccountName']
                            ?.toString() ??
                        '',
                  ),
                  _detailLine(
                    'Account No.',
                    _directPayment[
                                'bankAccountNumber']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (_paymentMethod ==
                    'connectips')
                  _detailLine(
                    'connectIPS',
                    _directPayment[
                                'connectIpsId']
                            ?.toString() ??
                        '',
                  ),
                if (_paymentMethod ==
                    'mobile_banking')
                  _detailLine(
                    'Details',
                    _directPayment[
                                'mobileBankingDetails']
                            ?.toString() ??
                        '',
                  ),
                if (_paymentMethod ==
                        'homestay_qr' &&
                    qrUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child: Image.network(
                      qrUrl,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                if (instructions.isNotEmpty) ...<
                    Widget>[
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Homestay instruction: '
                    '$instructions',
                    style:
                        const TextStyle(
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
        const SizedBox(height: 10),
        TextField(
          controller:
              _paymentReference,
          textCapitalization:
              TextCapitalization
                  .characters,
          decoration:
              const InputDecoration(
            labelText:
                'Transaction / Payment Reference',
            hintText:
                'Enter reference after payment',
            prefixIcon: Icon(
              Icons.numbers_rounded,
            ),
            border:
                OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed:
              _uploadingPaymentProof
                  ? null
                  : _uploadPaymentProof,
          icon: _uploadingPaymentProof
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  _paymentProofUrl
                          .isEmpty
                      ? Icons
                          .upload_file_rounded
                      : Icons
                          .check_circle_rounded,
                ),
          label: Text(
            _paymentProofUrl.isEmpty
                ? 'Upload Payment Proof'
                : 'Payment Proof Uploaded • Replace',
          ),
        ),
        if (_paymentProofUrl
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child: Image.network(
              _paymentProofUrl,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Never enter OTP, PIN, bank password, eSewa/Khalti PIN or card PIN in RD Online Shop.',
          style: TextStyle(
            color: _rdBlue,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void>
      _uploadPaymentProof() async {
    if (_uploadingPaymentProof) {
      return;
    }

    setState(() {
      _uploadingPaymentProof = true;
    });

    try {
      final String? url =
          await HomestayCloudinaryService
              .pickAndUploadImage(
        imageQuality: 88,
      );

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _paymentProofUrl = url;
      });

      _message(
        'Payment proof uploaded.',
      );
    } catch (error) {
      _message(
        'Could not upload payment proof.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPaymentProof =
              false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    if (_guestName.text
            .trim()
            .length <
        2) {
      _message(
        'Please enter guest full name.',
      );
      return;
    }

    if (_phone.text
            .trim()
            .length <
        7) {
      _message(
        'Please enter a valid phone number.',
      );
      return;
    }

    if (_roomCount >
        widget.available) {
      _message(
        'Only ${widget.available} '
        'room(s) are available.',
      );
      return;
    }

    if (_paymentOption ==
        'online') {
      if (!_directPaymentEnabled) {
        _message(
          'This Homestay has not enabled '
          'Direct Online Payment. '
          'Please choose Pay at Homestay.',
        );
        return;
      }

      if (!_availablePaymentMethods()
          .contains(_paymentMethod)) {
        _message(
          'Please select a valid Homestay payment method.',
        );
        return;
      }

      if (_paymentReference.text
          .trim()
          .isEmpty) {
        _message(
          'Enter the transaction / payment reference after paying the Homestay.',
        );
        return;
      }

      if (_paymentProofUrl
          .trim()
          .isEmpty) {
        _message(
          'Upload payment proof before submitting the booking.',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
    });

    try {
      final User user =
          await _ensureUser();

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          FirebaseFirestore.instance
              .collection(
                'homestay_bookings',
              )
              .doc();

      final String paymentStatus =
          _paymentOption ==
                  'pay_at_homestay'
              ? 'pay_at_homestay_pending'
              : _paymentOption ==
                      'online'
                  ? 'submitted_to_homestay'
                  : 'online_pending';

      await reference.set(
        <String, dynamic>{
          'bookingId':
              reference.id,
          'serviceType': 'homestay',
          'customerAuthUid':
              user.uid,
          'customerId': user.uid,
          'partnerId': widget
                  .homestay['partnerId']
                  ?.toString() ??
              '',
          'homestayId':
              widget.homestayId,
          'homestayName': widget
                  .homestay['name']
                  ?.toString() ??
              'Homestay',
          'homestayLocation': widget
                  .homestay['location']
                  ?.toString() ??
              '',
          'homestayLatitude':
              (widget.homestay['latitude'] as num?)
                  ?.toDouble(),
          'homestayLongitude':
              (widget.homestay['longitude'] as num?)
                  ?.toDouble(),
          'roomId': widget.roomId,
          'roomName': widget
                  .room['name']
                  ?.toString() ??
              'Room',
          'checkIn':
              Timestamp.fromDate(
            _day(widget.checkIn),
          ),
          'checkOut':
              Timestamp.fromDate(
            _day(widget.checkOut),
          ),
          'nights': _nights,
          'roomCount': _roomCount,
          'guestName':
              _guestName.text.trim(),
          'guestPhone':
              _phone.text.trim(),
          'pricePerNight': _price,
          'totalAmount': _total,
          'currency': 'Rs.',
          'paymentOption':
              _paymentOption,
          'paymentStatus':
              paymentStatus,
          if (_paymentOption ==
              'online') ...<
              String, dynamic>{
            'paymentMethod':
                _paymentMethod,
            'paymentReference':
                _paymentReference.text
                    .trim(),
            'paymentProofUrl':
                _paymentProofUrl.trim(),
            'paymentSubmittedAt':
                FieldValue
                    .serverTimestamp(),
            'paymentReceiverPartnerId':
                _partnerId,
            'paymentReceiverHomestayId':
                widget.homestayId,
            'paymentReceiverType':
                'homestay_direct',
          },
          'bookingStatus':
              'request_submitted',
          'confirmationStatus':
              'pending',
          'partnerConfirmed':
              false,
          'adminConfirmed': false,
          'refundStatus': 'none',
          'createdAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      final String bookingSubmitMessage =
          _paymentOption == 'online'
              ? 'Your payment proof was sent directly to the Homestay Partner. '
                  'The payment becomes PAID only after the Homestay confirms '
                  'that the money arrived in its own receiving account.\n\n'
                  'The Homestay Partner will also confirm room availability. '
                  'This request is not a confirmed reservation until '
                  'the booking status becomes Confirmed.'
              : 'The Homestay Partner will confirm '
                  'availability. This request is not '
                  'a confirmed reservation until '
                  'the status becomes Confirmed.';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (
          BuildContext dialogContext,
        ) {
          return AlertDialog(
            icon: const Icon(
              Icons
                  .check_circle_rounded,
              color: _rdGreen,
              size: 44,
            ),
            title: const Text(
              'Booking Request Submitted',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            content: Text(
              'Booking ID: ${reference.id}\n'
              '${widget.homestay['name'] ?? 'Homestay'}\n'
              '${widget.room['name'] ?? 'Room'} × $_roomCount\n'
              '${_date(widget.checkIn)} → '
              '${_date(widget.checkOut)}\n'
              'Total: ${_money(_total)}\n\n'
              '$bookingSubmitMessage',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                  dialogContext,
                ),
                child:
                    const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      _message(
        'Could not submit booking.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
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

  Widget _row(
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Book Room',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),
            child: ListView(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: <Widget>[
                        Text(
                          widget.homestay[
                                      'name']
                                  ?.toString() ??
                              'Homestay',
                          style:
                              const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        Text(
                          widget.room[
                                      'name']
                                  ?.toString() ??
                              'Room',
                        ),
                        Text(
                          '${_money(_price)} / night',
                          style:
                              const TextStyle(
                            color: _rdBlue,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        Text(
                          '${widget.available} room(s) available for selected dates',
                          style:
                              const TextStyle(
                            color:
                                _rdGreen,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller:
                      _guestName,
                  textCapitalization:
                      TextCapitalization
                          .words,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Guest Full Name',
                    prefixIcon:
                        Icon(
                      Icons
                          .person_rounded,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextField(
                  controller: _phone,
                  keyboardType:
                      TextInputType.phone,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Phone Number',
                    prefixIcon:
                        Icon(
                      Icons
                          .phone_rounded,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(12),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Number of Rooms',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _roomCount > 1
                                  ? () =>
                                      setState(
                                        () {
                                          _roomCount--;
                                        },
                                      )
                                  : null,
                          icon: const Icon(
                            Icons
                                .remove_circle_outline_rounded,
                          ),
                        ),
                        Text(
                          '$_roomCount',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _roomCount <
                                      widget
                                          .available
                                  ? () =>
                                      setState(
                                        () {
                                          _roomCount++;
                                        },
                                      )
                                  : null,
                          icon: const Icon(
                            Icons
                                .add_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(12),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: <Widget>[
                        const Text(
                          'Payment Option',
                          style:
                              TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        SegmentedButton<
                            String>(
                          segments: const <
                              ButtonSegment<
                                  String>>[
                            ButtonSegment<
                                String>(
                              value:
                                  'pay_at_homestay',
                              label: Text(
                                'Pay at Homestay',
                              ),
                              icon: Icon(
                                Icons
                                    .hotel_rounded,
                              ),
                            ),
                            ButtonSegment<
                                String>(
                              value:
                                  'online',
                              label: Text(
                                'Direct Online to Homestay',
                              ),
                              icon: Icon(
                                Icons
                                    .payments_rounded,
                              ),
                            ),
                          ],
                          selected: <String>{
                            _paymentOption,
                          },
                          onSelectionChanged:
                              (
                            Set<String>
                                value,
                          ) {
                            setState(() {
                              _paymentOption =
                                  value.first;
                            });
                          },
                        ),
                        if (_paymentOption ==
                            'online') ...<
                            Widget>[
                          const SizedBox(
                            height: 10,
                          ),
                          _directPaymentSection(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .all(14),
                    child: Column(
                      children: <Widget>[
                        _row(
                          'Check-in',
                          _date(
                            widget
                                .checkIn,
                          ),
                        ),
                        _row(
                          'Check-out',
                          _date(
                            widget
                                .checkOut,
                          ),
                        ),
                        _row(
                          'Nights',
                          '$_nights',
                        ),
                        _row(
                          'Rooms',
                          '$_roomCount',
                        ),
                        const Divider(),
                        _row(
                          'Total',
                          _money(
                            _total,
                          ),
                          strong: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                SizedBox(
                  height: 52,
                  child:
                      FilledButton.icon(
                    onPressed:
                        _submitting
                            ? null
                            : _submit,
                    icon: _submitting
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
                                .book_online_rounded,
                          ),
                    label: const Text(
                      'Submit Booking Request',
                      style:
                          TextStyle(
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
    );
  }
}

class MyHomestayBookingsPage
    extends StatelessWidget {
  const MyHomestayBookingsPage({
    super.key,
  });

  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  String _date(dynamic value) {
    if (value is! Timestamp) {
      return '-';
    }

    final DateTime date = value.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _cancel(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) async {
    String reason = '';

    final String? result =
        await showDialog<String>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Request Cancellation',
          ),
          content: TextField(
            maxLines: 3,
            onChanged: (String value) {
              reason = value.trim();
            },
            decoration:
                const InputDecoration(
              labelText: 'Reason',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
              ),
              child:
                  const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.isNotEmpty) {
                  Navigator.pop(
                    dialogContext,
                    reason,
                  );
                }
              },
              child: const Text(
                'Request Cancel',
              ),
            ),
          ],
        );
      },
    );

    if (result == null ||
        result.trim().isEmpty ||
        !context.mounted) {
      return;
    }

    try {
      await doc.reference.update(
        <String, dynamic>{
          'bookingStatus':
              'cancel_requested',
          'cancellationReason':
              result.trim(),
          'cancelRequestedAt':
              FieldValue
                  .serverTimestamp(),
          'updatedAt':
              FieldValue
                  .serverTimestamp(),
        },
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Cancellation requested.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not request cancellation.\n'
            '$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No customer session found.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Homestay Bookings',
          style: TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(
              'homestay_bookings',
            )
            .where(
              'customerAuthUid',
              isEqualTo: user.uid,
            )
            .snapshots(),
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
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load bookings.\n'
                '${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            );
          }

          final List<
                  QueryDocumentSnapshot<
                      Map<String, dynamic>>>
              docs =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<
                      Map<String, dynamic>>>[];

          docs.sort(
            (
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  first,
              QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  second,
            ) {
              final Timestamp? a =
                  first.data()['createdAt']
                      as Timestamp?;

              final Timestamp? b =
                  second.data()['createdAt']
                      as Timestamp?;

              return (b
                          ?.millisecondsSinceEpoch ??
                      0)
                  .compareTo(
                a?.millisecondsSinceEpoch ??
                    0,
              );
            },
          );

          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 900,
              ),
              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                children: docs.isEmpty
                    ? <Widget>[
                        const Card(
                          child: Padding(
                            padding:
                                EdgeInsets.all(
                              24,
                            ),
                            child: Text(
                              'No homestay booking yet.',
                              textAlign:
                                  TextAlign.center,
                            ),
                          ),
                        ),
                      ]
                    : docs
                        .map(
                          (
                            QueryDocumentSnapshot<
                                    Map<String,
                                        dynamic>>
                                doc,
                          ) =>
                              _bookingCard(
                            context,
                            doc,
                          ),
                        )
                        .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bookingCard(
    BuildContext context,
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final String status =
        data['bookingStatus']
                ?.toString() ??
            'request_submitted';

    final bool cancellable =
        <String>[
      'request_submitted',
      'confirmed',
    ].contains(status);

    final bool issued =
        <String>[
      'confirmed',
      'checked_in',
      'completed',
    ].contains(status);

    final bool issueClosed =
        <String>[
      'rejected',
      'cancelled',
    ].contains(status);

    final String issueText =
        issued
            ? 'ISSUED'
            : issueClosed
                ? 'CLOSED'
                : 'NOT ISSUED';

    final Color issueColor =
        issued
            ? _rdGreen
            : issueClosed
                ? _rdRed
                : Colors.orange;

    final double? homestayLatitude =
        (data['homestayLatitude'] as num?)
            ?.toDouble();

    final double? homestayLongitude =
        (data['homestayLongitude'] as num?)
            ?.toDouble();

    Color statusColor = Colors.orange;

    if (status == 'confirmed' ||
        status == 'checked_in' ||
        status == 'completed') {
      statusColor = _rdGreen;
    } else if (status == 'cancelled' ||
        status == 'rejected') {
      statusColor = _rdRed;
    }

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    data['homestayName']
                            ?.toString() ??
                        'Homestay',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              data['roomName']
                      ?.toString() ??
                  'Room',
            ),
            Text(
              '${_date(data['checkIn'])} → '
              '${_date(data['checkOut'])}',
            ),
            Text(
              '${data['roomCount'] ?? 0} room(s) • '
              '${data['nights'] ?? 0} night(s)',
            ),
            Text(
              'Total: Rs. '
              '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            Text(
              'Payment: '
              '${data['paymentStatus'] ?? ''}',
            ),
            if (data['paymentOption'] ==
                'online') ...<
                Widget>[
              Text(
                'Direct to Homestay: '
                '${data['paymentMethod'] ?? ''}',
              ),
              SelectableText(
                'Transaction / Reference: '
                '${data['paymentReference'] ?? ''}',
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: issueColor
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: issueColor
                      .withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    issued
                        ? Icons
                            .verified_rounded
                        : Icons
                            .confirmation_number_outlined,
                    color: issueColor,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Booking Voucher: '
                          '$issueText',
                          style: TextStyle(
                            color: issueColor,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        Text(
                          issued
                              ? 'Homestay booking is confirmed. '
                                  'Show this booking ID at the homestay.'
                              : issueClosed
                                  ? 'This booking is no longer active.'
                                  : 'Voucher will be issued automatically '
                                      'after Homestay Partner confirms the booking.',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (issued) ...<Widget>[
              const SizedBox(height: 8),
              SelectableText(
                'Issued Booking ID: ${doc.id}',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
            if ((data['rejectionReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Reason: '
                '${data['rejectionReason']}',
                style: const TextStyle(
                  color: _rdRed,
                ),
              ),
            if ((data['cancellationReason']
                        ?.toString()
                        .trim() ??
                    '')
                .isNotEmpty)
              Text(
                'Cancellation: '
                '${data['cancellationReason']}',
                style: const TextStyle(
                  color: Colors.orange,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                double? latitude =
                    homestayLatitude;
                double? longitude =
                    homestayLongitude;

                if ((latitude == null ||
                        longitude == null) &&
                    (data['homestayId']
                                ?.toString()
                                .trim() ??
                            '')
                        .isNotEmpty) {
                  try {
                    final DocumentSnapshot<
                            Map<String, dynamic>>
                        homestayDoc =
                        await FirebaseFirestore
                            .instance
                            .collection(
                              'homestays',
                            )
                            .doc(
                              data['homestayId']
                                  .toString(),
                            )
                            .get();

                    latitude =
                        (homestayDoc.data()?[
                                    'latitude']
                                as num?)
                            ?.toDouble();

                    longitude =
                        (homestayDoc.data()?[
                                    'longitude']
                                as num?)
                            ?.toDouble();
                  } catch (_) {
                    // The common navigation helper
                    // will show the missing-GPS message.
                  }
                }

                if (!context.mounted) {
                  return;
                }

                await _openHomestayDirections(
                  context,
                  homestayLatitude:
                      latitude,
                  homestayLongitude:
                      longitude,
                  homestayName:
                      data['homestayName']
                              ?.toString() ??
                          'Homestay',
                );
              },
              icon: const Icon(
                Icons.navigation_rounded,
              ),
              label: const Text(
                'Navigate to Homestay from My Live Location',
              ),
            ),
            if (cancellable) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _cancel(
                  context,
                  doc,
                ),
                icon: const Icon(
                  Icons
                      .event_busy_rounded,
                ),
                label: const Text(
                  'Request Cancellation',
                ),
              ),
            ],
            const SizedBox(height: 5),
            SelectableText(
              'Booking ID: ${doc.id}',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomestaySummary {
  const _HomestaySummary({
    required this.activeRoomTypes,
    required this.availableRooms,
    required this.lowestAvailablePrice,
  });

  final int activeRoomTypes;
  final int availableRooms;
  final double? lowestAvailablePrice;
}
