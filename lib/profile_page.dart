import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_chat_page.dart';
import 'order_data.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _rdRed = Color(0xFFE50914);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController nameController =
      TextEditingController();
  final TextEditingController phoneController =
      TextEditingController();
  final TextEditingController emailController =
      TextEditingController();
  final TextEditingController addressController =
      TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String customerId = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  Future<Map<String, dynamic>> _loadCloudProfile(
    String id,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
          await FirebaseFirestore.instance
              .collection('customers')
              .doc(id)
              .get();

      return document.data() ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _loadData() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      final String id = await getOrCreateCustomerId();
      final Map<String, dynamic> cloud =
          await _loadCloudProfile(id);

      final User? user = FirebaseAuth.instance.currentUser;

      final String cloudEmail = _text(cloud['email']);
      final String authEmail =
          user != null && !user.isAnonymous
              ? _text(user.email)
              : '';

      if (!mounted) return;

      setState(() {
        customerId = id;

        nameController.text =
            _text(cloud['name']).isNotEmpty
                ? _text(cloud['name'])
                : prefs.getString('name') ?? '';

        phoneController.text =
            _text(cloud['phone']).isNotEmpty
                ? _text(cloud['phone'])
                : prefs.getString('phone') ?? '';

        emailController.text = authEmail.isNotEmpty
            ? authEmail
            : cloudEmail.isNotEmpty
                ? cloudEmail
                : prefs.getString('email') ?? '';

        addressController.text =
            _text(cloud['address']).isNotEmpty
                ? _text(cloud['address'])
                : prefs.getString('address') ?? '';

        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      setState(() {
        nameController.text =
            prefs.getString('name') ?? '';
        phoneController.text =
            prefs.getString('phone') ?? '';
        emailController.text =
            prefs.getString('email') ?? '';
        addressController.text =
            prefs.getString('address') ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    if (isSaving ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final String id = customerId.isNotEmpty
          ? customerId
          : await getOrCreateCustomerId();

      final String name = nameController.text.trim();
      final String phone = phoneController.text.trim();
      final String email =
          emailController.text.trim().toLowerCase();
      final String address =
          addressController.text.trim();

      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      // Save locally first so the profile remains available even if
      // internet/Firestore is temporarily unavailable.
      await prefs.setString('name', name);
      await prefs.setString('phone', phone);
      await prefs.setString('email', email);
      await prefs.setString('address', address);

      bool cloudSaved = true;

      try {
        final User? user =
            FirebaseAuth.instance.currentUser;

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(id)
            .set(
          <String, dynamic>{
            'customerId': id,
            'authUid': user?.uid ?? '',
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'role': 'customer',
            'isActive': true,
            'accountType': 'automatic_device_customer',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        cloudSaved = false;
      }

      if (!mounted) return;

      setState(() {
        customerId = id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudSaved
                ? 'Profile saved successfully.'
                : 'Profile saved on this device. Cloud sync will be retried later.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: _rdRed,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                              color: _rdRed,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 68,
                            color: _rdRed,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'RD Customer Profile',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (customerId.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 5),
                          Text(
                            'Customer ID: $customerId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _field(
                          controller: nameController,
                          label: 'Name',
                          icon: Icons.person_outline,
                          validator: (String? value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter your name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        _field(
                          controller: phoneController,
                          label: 'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (String? value) {
                            final String phone =
                                (value ?? '').trim();

                            if (phone.isEmpty) {
                              return 'Enter your phone number.';
                            }

                            if (normalizeOrderRecoveryPhone(
                                  phone,
                                ).length <
                                6) {
                              return 'Enter a valid phone number.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        _field(
                          controller: emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType:
                              TextInputType.emailAddress,
                          validator: (String? value) {
                            final String email =
                                (value ?? '').trim();

                            if (email.isNotEmpty &&
                                (!email.contains('@') ||
                                    !email.contains('.'))) {
                              return 'Enter a valid email address.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        _field(
                          controller: addressController,
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _rdRed,
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                isSaving ? null : _saveData,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_outlined,
                                  ),
                            label: Text(
                              isSaving
                                  ? 'Saving...'
                                  : 'Save Profile',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const CustomerChatPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_outlined,
                            ),
                            label: const Text(
                              'Customer Support Chat',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                Icons.info_outline,
                                color: _rdRed,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No customer login, logout, ID entry or password is required. This profile stays linked to the automatic RD customer identity on this device.',
                                ),
                              ),
                            ],
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
