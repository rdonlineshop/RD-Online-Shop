import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'resort_cloudinary_service.dart';

class ResortPartnerDirectPaymentPage extends StatefulWidget {
  const ResortPartnerDirectPaymentPage({super.key});

  @override
  State<ResortPartnerDirectPaymentPage> createState() =>
      _ResortPartnerDirectPaymentPageState();
}

class _ResortPartnerDirectPaymentPageState
    extends State<ResortPartnerDirectPaymentPage> {
  static const Color _rdGreen = Color(0xFF2E7D32);
  static const Color _rdBlue = Color(0xFF1565C0);

  final TextEditingController _esewaName = TextEditingController();
  final TextEditingController _esewaNumber = TextEditingController();
  final TextEditingController _khaltiName = TextEditingController();
  final TextEditingController _khaltiNumber = TextEditingController();
  final TextEditingController _bankName = TextEditingController();
  final TextEditingController _bankAccountName = TextEditingController();
  final TextEditingController _bankAccountNumber = TextEditingController();
  final TextEditingController _connectIpsId = TextEditingController();
  final TextEditingController _mobileBankingDetails = TextEditingController();
  final TextEditingController _instructions = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingQr = false;
  String _paymentQrUrl = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _ref {
    final User? user = _user;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance
        .collection('resort_direct_payment_accounts')
        .doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _esewaName.dispose();
    _esewaNumber.dispose();
    _khaltiName.dispose();
    _khaltiNumber.dispose();
    _bankName.dispose();
    _bankAccountName.dispose();
    _bankAccountNumber.dispose();
    _connectIpsId.dispose();
    _mobileBankingDetails.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final DocumentReference<Map<String, dynamic>>? ref = _ref;
    if (ref == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await ref.get();
      final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
      _enabled = data['enabled'] == true;
      _esewaName.text = data['esewaName']?.toString() ?? '';
      _esewaNumber.text = data['esewaNumber']?.toString() ?? '';
      _khaltiName.text = data['khaltiName']?.toString() ?? '';
      _khaltiNumber.text = data['khaltiNumber']?.toString() ?? '';
      _bankName.text = data['bankName']?.toString() ?? '';
      _bankAccountName.text = data['bankAccountName']?.toString() ?? '';
      _bankAccountNumber.text = data['bankAccountNumber']?.toString() ?? '';
      _connectIpsId.text = data['connectIpsId']?.toString() ?? '';
      _mobileBankingDetails.text = data['mobileBankingDetails']?.toString() ?? '';
      _instructions.text = data['instructions']?.toString() ?? '';
      _paymentQrUrl = data['paymentQrUrl']?.toString() ?? '';
    } catch (error) {
      _message('Could not load Resort receiving details.\n$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasMethod =>
      _esewaNumber.text.trim().isNotEmpty ||
      _khaltiNumber.text.trim().isNotEmpty ||
      (_bankName.text.trim().isNotEmpty &&
          _bankAccountNumber.text.trim().isNotEmpty) ||
      _connectIpsId.text.trim().isNotEmpty ||
      _mobileBankingDetails.text.trim().isNotEmpty ||
      _paymentQrUrl.trim().isNotEmpty;

  Future<void> _uploadQr() async {
    if (_uploadingQr) return;
    setState(() => _uploadingQr = true);
    try {
      final String? url = await ResortCloudinaryService.pickAndUploadImage(
        imageQuality: 92,
      );
      if (!mounted || url == null) return;
      setState(() => _paymentQrUrl = url);
      _message('Resort payment QR uploaded.');
    } catch (error) {
      _message('Could not upload QR.\n$error');
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final User? user = _user;
    final DocumentReference<Map<String, dynamic>>? ref = _ref;
    if (user == null || user.isAnonymous || ref == null) {
      _message('Resort Partner login is required.');
      return;
    }
    if (_enabled && !_hasMethod) {
      _message('Add at least one receiving method before enabling Direct Online Payment.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.set(<String, dynamic>{
        'partnerId': user.uid,
        'resortId': user.uid,
        'enabled': _enabled,
        'esewaName': _esewaName.text.trim(),
        'esewaNumber': _esewaNumber.text.trim(),
        'khaltiName': _khaltiName.text.trim(),
        'khaltiNumber': _khaltiNumber.text.trim(),
        'bankName': _bankName.text.trim(),
        'bankAccountName': _bankAccountName.text.trim(),
        'bankAccountNumber': _bankAccountNumber.text.trim(),
        'connectIpsId': _connectIpsId.text.trim(),
        'mobileBankingDetails': _mobileBankingDetails.text.trim(),
        'paymentQrUrl': _paymentQrUrl.trim(),
        'instructions': _instructions.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _message('Resort receiving details saved.');
    } catch (error) {
      _message('Could not save Resort receiving details.\n$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;
    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(child: Text('Resort Partner login required.')),
      );
    }
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Direct Online Payment',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[_rdBlue, _rdGreen],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Customer booking payment can go directly to your Resort receiving account. '
                    'Verify the actual money received before marking a booking PAID. Never ask customers for OTP, PIN or bank password.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _enabled,
                  onChanged: (bool value) => setState(() => _enabled = value),
                  title: const Text(
                    'Enable Direct Online Payment',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Only enabled Resort receiving details are visible to signed-in customers during booking.',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('eSewa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _field(_esewaName, 'eSewa Account Name', Icons.person_outline),
                _field(_esewaNumber, 'eSewa ID / Number', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 4),
                const Text('Khalti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _field(_khaltiName, 'Khalti Account Name', Icons.person_outline),
                _field(_khaltiNumber, 'Khalti ID / Number', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 4),
                const Text('Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _field(_bankName, 'Bank Name', Icons.account_balance_rounded),
                _field(_bankAccountName, 'Bank Account Name', Icons.badge_outlined),
                _field(_bankAccountNumber, 'Bank Account Number', Icons.numbers_rounded),
                const SizedBox(height: 4),
                _field(_connectIpsId, 'connectIPS ID', Icons.link_rounded),
                _field(_mobileBankingDetails, 'Mobile Banking Details', Icons.phone_android_rounded, maxLines: 2),
                OutlinedButton.icon(
                  onPressed: _uploadingQr ? null : _uploadQr,
                  icon: _uploadingQr
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _paymentQrUrl.isEmpty
                        ? 'Upload Resort Payment QR'
                        : 'Replace Resort Payment QR',
                  ),
                ),
                if (_paymentQrUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _paymentQrUrl,
                      height: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _field(_instructions, 'Customer Payment Instructions', Icons.info_outline_rounded, maxLines: 4),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text(
                      'Save Resort Receiving Details',
                      style: TextStyle(fontWeight: FontWeight.w900),
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
