
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _facilities = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _coverUrl = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _phone, _address, _city, _facilities]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final doc = await FirebaseFirestore.instance
        .collection('homestays')
        .doc(user.uid)
        .get();
    final d = doc.data() ?? <String, dynamic>{};
    _name.text = d['name']?.toString() ?? '';
    _description.text = d['description']?.toString() ?? '';
    _phone.text = d['phone']?.toString() ?? '';
    _address.text = d['address']?.toString() ?? '';
    _city.text = d['city']?.toString() ?? '';
    _facilities.text =
        d['facilities'] is List ? (d['facilities'] as List).join(', ') : '';
    _coverUrl = d['coverUrl']?.toString() ?? '';
    _lat = (d['latitude'] as num?)?.toDouble();
    _lng = (d['longitude'] as num?)?.toDouble();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    try {
      final url = await HomestayCloudinaryService.pickAndUploadImage();
      if (url != null && mounted) setState(() => _coverUrl = url);
    } catch (e) {
      _msg('Upload failed: $e');
    }
  }

  Future<void> _location() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _msg('Turn on GPS first.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _msg('Location permission required.');
      return;
    }

    final p = await Geolocator.getCurrentPosition();
    String addr = _address.text;
    String city = _city.text;
    try {
      final List<Placemark> places =
          await Geocoding().placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      );
      if (places.isNotEmpty) {
        final x = places.first;
        city = x.locality?.trim().isNotEmpty == true
            ? x.locality!.trim()
            : city;
        addr = <String>[
          x.street ?? '',
          x.subLocality ?? '',
          x.locality ?? '',
          x.administrativeArea ?? '',
          x.country ?? '',
        ].where(
          (String e) => e.trim().isNotEmpty,
        ).join(', ');
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
      if (addr.isNotEmpty) _address.text = addr;
      if (city.isNotEmpty) _city.text = city;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    setState(() => _saving = true);
    try {
      final ref = FirebaseFirestore.instance.collection('homestays').doc(user.uid);
      final old = await ref.get();
      final keepApproved = old.data()?['isApproved'] == true;
      final keepActive = old.data()?['isActive'] == true;
      await ref.set({
        'homestayId': user.uid,
        'partnerId': user.uid,
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'facilities': _facilities.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList(),
        'coverUrl': _coverUrl,
        'latitude': _lat,
        'longitude': _lng,
        'isApproved': keepApproved,
        'isActive': keepActive,
        'status': keepApproved ? 'approved' : 'pending_review',
        'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _msg(keepApproved
          ? 'Homestay profile updated.'
          : 'Profile saved. Admin approval is required.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Homestay Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _coverUrl,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _upload,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('Cover Photo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _location,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Current Location'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _f(_name, 'Homestay Name', true),
                _f(_description, 'Description', false, maxLines: 4),
                _f(_phone, 'Phone', true),
                _f(_address, 'Address', true),
                _f(_city, 'City / Area', true),
                _f(_facilities, 'Facilities (comma separated)', false),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Homestay Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _f(TextEditingController c, String label, bool required,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: required
            ? (v) => (v ?? '').trim().isEmpty ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class HomestayPartnerRoomsPage extends StatelessWidget {
  const HomestayPartnerRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      return const Scaffold(body: Center(child: Text('Partner login required.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Homestay Rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, user.uid),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Room'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('homestay_rooms')
            .where('partnerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = s.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No rooms yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bed_rounded),
                  title: Text(d['name']?.toString() ?? 'Room'),
                  subtitle: Text(
                    'Rs. ${(d['pricePerNight'] as num?)?.toStringAsFixed(0) ?? '0'} / night\n'
                    'Total ${(d['totalRooms'] as num?)?.toInt() ?? 1} • '
                    'Max guests ${(d['maxGuests'] as num?)?.toInt() ?? 2}',
                  ),
                  trailing: IconButton(
                    onPressed: () => _edit(context, user.uid, doc: docs[i]),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    String partnerId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final old = doc?.data() ?? <String, dynamic>{};
    final name = TextEditingController(text: old['name']?.toString() ?? '');
    final price = TextEditingController(
      text: (old['pricePerNight'] as num?)?.toString() ?? '',
    );
    final rooms = TextEditingController(
      text: (old['totalRooms'] as num?)?.toString() ?? '1',
    );
    final guests = TextEditingController(
      text: (old['maxGuests'] as num?)?.toString() ?? '2',
    );
    final facilities = TextEditingController(
      text: old['facilities'] is List ? (old['facilities'] as List).join(', ') : '',
    );
    bool active = old['isActive'] != false;
    String photoUrl = old['photoUrl']?.toString() ?? '';

    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            final parsedPrice = double.tryParse(price.text.trim());
            final parsedRooms = int.tryParse(rooms.text.trim());
            final parsedGuests = int.tryParse(guests.text.trim());
            if (name.text.trim().isEmpty ||
                parsedPrice == null ||
                parsedRooms == null ||
                parsedRooms < 1 ||
                parsedGuests == null ||
                parsedGuests < 1) {
              return;
            }
            final ref = doc?.reference ??
                FirebaseFirestore.instance.collection('homestay_rooms').doc();
            await ref.set({
              'roomId': ref.id,
              'homestayId': partnerId,
              'partnerId': partnerId,
              'name': name.text.trim(),
              'pricePerNight': parsedPrice,
              'currency': 'Rs.',
              'totalRooms': parsedRooms,
              'maxGuests': parsedGuests,
              'facilities': facilities.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList(),
              'photoUrl': photoUrl,
              'isActive': active,
              'createdAt': old['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            if (dc.mounted) Navigator.pop(dc);
          }

          return AlertDialog(
            title: Text(doc == null ? 'Add Room' : 'Edit Room'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final url =
                          await HomestayCloudinaryService.pickAndUploadImage();
                      if (url != null) setState(() => photoUrl = url);
                    },
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: const Text('Room Photo'),
                  ),
                  _dialogField(name, 'Room Name'),
                  _dialogField(price, 'Price Per Night'),
                  _dialogField(rooms, 'Total Rooms'),
                  _dialogField(guests, 'Max Guests'),
                  _dialogField(facilities, 'Facilities'),
                  SwitchListTile(
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                    title: const Text('Active'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dc),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: save, child: const Text('Save')),
            ],
          );
        },
      ),
    );

    for (final c in [name, price, rooms, guests, facilities]) {
      c.dispose();
    }
  }

  static Widget _dialogField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
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
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _open = true;
  int _blocked = 0;

  String _key(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  List<DateTime> _dates() {
    final out = <DateTime>[];
    var c = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(_to.year, _to.month, _to.day);
    while (!c.isAfter(end)) {
      out.add(c);
      c = c.add(const Duration(days: 1));
    }
    return out;
  }

  Future<void> _pick(bool from) async {
    final first = from ? DateTime.now() : _from;
    final initial = from ? _from : _to;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = d;
      }
    });
  }

  Future<void> _save(QueryDocumentSnapshot<Map<String, dynamic>> room) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final total = (room.data()['totalRooms'] as num?)?.toInt() ?? 1;
    if (_blocked < 0 || _blocked > total) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final d in _dates()) {
      final ref = FirebaseFirestore.instance
          .collection('homestay_inventory')
          .doc('${room.id}_${_key(d)}');
      final old = await ref.get();
      final booked = (old.data()?['bookedRooms'] as num?)?.toInt() ?? 0;
      batch.set(
        ref,
        {
          'inventoryId': ref.id,
          'homestayId': user.uid,
          'partnerId': user.uid,
          'roomId': room.id,
          'date': Timestamp.fromDate(DateTime(d.year, d.month, d.day)),
          'totalRooms': total,
          'blockedRooms': _blocked,
          'bookedRooms': booked,
          'availableRooms':
              _open ? (total - _blocked - booked).clamp(0, total) : 0,
          'isOpen': _open,
          'lastBookingId': old.data()?['lastBookingId'] ?? '',
          'createdAt': old.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved.')),
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
      appBar: AppBar(title: const Text('Homestay Availability')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('homestay_rooms')
            .where('partnerId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, s) {
          final docs = s.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(true),
                      child: Text('From ${_from.day}/${_from.month}/${_from.year}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(false),
                      child: Text('To ${_to.day}/${_to.month}/${_to.year}'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _open,
                onChanged: (v) => setState(() => _open = v),
                title: const Text('Open for booking'),
              ),
              Row(
                children: [
                  const Expanded(child: Text('Blocked Rooms')),
                  IconButton(
                    onPressed: _blocked <= 0
                        ? null
                        : () => setState(() => _blocked--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_blocked'),
                  IconButton(
                    onPressed: () => setState(() => _blocked++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const Divider(),
              ...docs.map(
                (room) => Card(
                  child: ListTile(
                    title: Text(room.data()['name']?.toString() ?? 'Room'),
                    subtitle: Text(
                      'Total ${(room.data()['totalRooms'] as num?)?.toInt() ?? 1}',
                    ),
                    trailing: FilledButton(
                      onPressed: () => _save(room),
                      child: const Text('Save'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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

class HomestayBookingPage extends StatefulWidget {
  const HomestayBookingPage({super.key});

  @override
  State<HomestayBookingPage> createState() => _HomestayBookingPageState();
}

class _HomestayBookingPageState extends State<HomestayBookingPage> {
  final _search = TextEditingController();
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(bool checkIn) async {
    final first = checkIn ? DateTime.now() : _checkIn.add(const Duration(days: 1));
    final initial = checkIn ? _checkIn : _checkOut;
    final d = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (checkIn) {
        _checkIn = d;
        if (!_checkOut.isAfter(_checkIn)) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      } else {
        _checkOut = d;
      }
    });
  }

  int get _nights => _checkOut.difference(_checkIn).inDays;

  Future<void> _book(
    QueryDocumentSnapshot<Map<String, dynamic>> home,
    QueryDocumentSnapshot<Map<String, dynamic>> room,
  ) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dc) {
        return AlertDialog(
          title: const Text('Homestay Booking Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Guest Name'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().length < 2 || phone.text.trim().length < 7) {
                  return;
                }
                User? user = FirebaseAuth.instance.currentUser;
                user ??=
                    (await FirebaseAuth.instance.signInAnonymously()).user;
                if (user == null) return;

                final ref =
                    FirebaseFirestore.instance.collection('homestay_bookings').doc();
                final hd = home.data();
                final rd = room.data();
                final price = (rd['pricePerNight'] as num?)?.toDouble() ?? 0;
                await ref.set({
                  'bookingId': ref.id,
                  'serviceType': 'homestay',
                  'customerAuthUid': user.uid,
                  'customerId': user.uid,
                  'partnerId': hd['partnerId'],
                  'homestayId': home.id,
                  'homestayName': hd['name'] ?? 'Homestay',
                  'roomId': room.id,
                  'roomName': rd['name'] ?? 'Room',
                  'guestName': name.text.trim(),
                  'guestPhone': phone.text.trim(),
                  'checkIn': Timestamp.fromDate(_checkIn),
                  'checkOut': Timestamp.fromDate(_checkOut),
                  'nights': _nights,
                  'roomCount': 1,
                  'pricePerNight': price,
                  'totalAmount': price * _nights,
                  'currency': 'Rs.',
                  'paymentOption': 'pay_at_homestay',
                  'paymentStatus': 'pay_at_homestay_pending',
                  'bookingStatus': 'request_submitted',
                  'confirmationStatus': 'pending',
                  'partnerConfirmed': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (dc.mounted) Navigator.pop(dc);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Booking request sent. ID: ${ref.id}')),
                  );
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homestay Booking'),
        actions: [
          IconButton(
            tooltip: 'Homestay Partner Login',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const HomestayPartnerAuthPage(),
              ),
            ),
            icon: const Icon(Icons.business_center_rounded),
          ),
          IconButton(
            tooltip: 'My Homestay Bookings',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const MyHomestayBookingsPage(),
              ),
            ),
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search Homestay, city or area',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(true),
                        child: Text(
                          'In ${_checkIn.day}/${_checkIn.month}/${_checkIn.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(false),
                        child: Text(
                          'Out ${_checkOut.day}/${_checkOut.month}/${_checkOut.year}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('homestays')
                  .where('isApproved', isEqualTo: true)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, s) {
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final q = _search.text.trim().toLowerCase();
                final homes = s.data!.docs.where((doc) {
                  if (q.isEmpty) return true;
                  final d = doc.data();
                  return [
                    d['name']?.toString() ?? '',
                    d['city']?.toString() ?? '',
                    d['address']?.toString() ?? '',
                  ].any((x) => x.toLowerCase().contains(q));
                }).toList();

                if (homes.isEmpty) {
                  return const Center(child: Text('No approved Homestay found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: homes.length,
                  itemBuilder: (context, i) {
                    final h = homes[i];
                    final d = h.data();
                    return Card(
                      child: ExpansionTile(
                        title: Text(
                          d['name']?.toString() ?? 'Homestay',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('${d['city'] ?? ''} • ${d['address'] ?? ''}'),
                        children: [
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('homestay_rooms')
                                .where('homestayId', isEqualTo: h.id)
                                .where('isActive', isEqualTo: true)
                                .snapshots(),
                            builder: (context, rs) {
                              final rooms = rs.data?.docs ?? [];
                              if (!rs.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (rooms.isEmpty) {
                                return const ListTile(title: Text('No active rooms.'));
                              }
                              return Column(
                                children: rooms.map((room) {
                                  final r = room.data();
                                  return ListTile(
                                    leading: const Icon(Icons.bed_rounded),
                                    title: Text(r['name']?.toString() ?? 'Room'),
                                    subtitle: Text(
                                      'Rs. ${(r['pricePerNight'] as num?)?.toStringAsFixed(0) ?? '0'} / night',
                                    ),
                                    trailing: FilledButton(
                                      onPressed: () => _book(h, room),
                                      child: const Text('Book'),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MyHomestayBookingsPage extends StatelessWidget {
  const MyHomestayBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No customer session.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Homestay Bookings')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('homestay_bookings')
            .where('customerAuthUid', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.data!.docs.isEmpty) {
            return const Center(child: Text('No Homestay bookings.'));
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: s.data!.docs.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  title: Text(
                    d['homestayName']?.toString() ?? 'Homestay',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${d['roomName'] ?? ''}\n'
                    'Status: ${(d['bookingStatus'] ?? '').toString().toUpperCase()}',
                  ),
                  trailing: Text(
                    'Rs. ${(d['totalAmount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
