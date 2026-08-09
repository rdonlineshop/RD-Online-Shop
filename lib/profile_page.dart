import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_chat_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;

  final ImagePicker _picker = ImagePicker();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      nameController.text =
          prefs.getString("name") ?? "Dipesh Khati";

      phoneController.text =
          prefs.getString("phone") ?? "";

      emailController.text =
          prefs.getString("email") ?? "";

      addressController.text =
          prefs.getString("address") ?? "";

      String? path = prefs.getString("profile_image");

      if (path != null) {
        _image = File(path);
      }
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "name",
      nameController.text,
    );

    await prefs.setString(
      "phone",
      phoneController.text,
    );

    await prefs.setString(
      "email",
      emailController.text,
    );

    await prefs.setString(
      "address",
      addressController.text,
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? photo =
        await _picker.pickImage(source: source);

    if (photo != null) {
      setState(() {
        _image = File(photo.path);
      });

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setString(
        "profile_image",
        photo.path,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // Profile Image
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  _image != null
                      ? FileImage(_image!)
                      : null,
              child: _image == null
                  ? const Icon(
                      Icons.person,
                      size: 60,
                    )
                  : null,
            ),

            const SizedBox(height: 15),

            // Camera & Gallery
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    pickImage(
                      ImageSource.camera,
                    );
                  },
                  icon: const Icon(
                    Icons.camera_alt,
                  ),
                  label: const Text("Camera"),
                ),

                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    pickImage(
                      ImageSource.gallery,
                    );
                  },
                  icon: const Icon(
                    Icons.photo,
                  ),
                  label: const Text("Gallery"),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),

            const SizedBox(height: 15),

            // Phone
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),

            const SizedBox(height: 15),

            // Email
            TextField(
              controller: emailController,
              keyboardType:
                  TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 15),

            // Address
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 25),

            // Save Profile
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await saveData();

                  if (!mounted) return;

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Profile Saved Successfully",
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Save Profile",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Customer Support Chat
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CustomerChatPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.chat,
                ),
                label: const Text(
                  "Customer Support Chat",
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}