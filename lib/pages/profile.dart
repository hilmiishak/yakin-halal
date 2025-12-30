import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_page.dart';
import 'preference.dart';
import 'report_page.dart'; // ⭐️ Added missing import
import 'partner_info_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ⚠️ REPLACE WITH YOUR REAL CLOUDINARY DETAILS
  final String _cloudinaryCloudName = "dajmimoiy";
  final String _cloudinaryUploadPreset = "Halal_Restaurant";

  String? _username;
  String? _profileImageUrl;
  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .get();

      if (doc.exists) {
        setState(() {
          _username = doc.data()?['name'];
          _profileImageUrl = doc.data()?['profileImageUrl'];
        });
      } else {
        _username = _currentUser.email?.split('@').first ?? 'New User';
      }
    } catch (e) {
      print("Error fetching user data: $e");
      _username = _currentUser.email?.split('@').first ?? 'New User';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _changeProfilePicture() async {
    if (_currentUser == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload",
      );
      final request =
          http.MultipartRequest('POST', url)
            ..fields['upload_preset'] = _cloudinaryUploadPreset
            ..files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        final newImageUrl = jsonResponse['secure_url'];

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .set({'profileImageUrl': newImageUrl}, SetOptions(merge: true));

        setState(() {
          _profileImageUrl = newImageUrl;
          _isLoading = false;
        });
      } else {
        throw Exception('Upload failed: ${jsonResponse['error']['message']}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to upload image: $e")));
    }
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _username,
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Name"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Enter your name"),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Save"),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && _currentUser != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser.uid)
                      .set({'name': newName}, SetOptions(merge: true));
                  setState(() => _username = newName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF93DCC9),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "PROFILE",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: "Poppins",
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                children: [
                  // --- Profile Picture ---
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                          child:
                              _profileImageUrl == null
                                  ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.black45,
                                  )
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF58C3A3),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Name ---
                  Center(
                    child: Text(
                      "${_username?.toUpperCase() ?? 'USER'}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Poppins",
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Menu Items ---
                  ProfileMenuItem(
                    title: "Edit Profile",
                    icon: Icons.person_outline,
                    onTap: _showEditNameDialog,
                  ),
                  const SizedBox(height: 12),

                  ProfileMenuItem(
                    title: "Edit Preferences",
                    icon: Icons.tune_outlined,
                    onTap: () {
                      if (_currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PreferencePage(
                                  userId: _currentUser.uid,
                                  isEditing: true,
                                ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  ProfileMenuItem(
                    title: "Settings",
                    icon: Icons.settings_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ⭐️ Unified Report Button (using ProfileMenuItem style)
                  ProfileMenuItem(
                    title: "Report a Problem",
                    icon: Icons.report_problem_outlined,
                    textColor: Colors.orange[800],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ⭐️ PARTNER BUTTON
                  ProfileMenuItem(
                    title: "Partner with Us",
                    icon: Icons.storefront, // Store icon looks good here
                    textColor: Colors.teal[800],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PartnerInfoPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  ProfileMenuItem(
                    title: "Log out",
                    icon: Icons.logout,
                    onTap: _logOut,
                    textColor: Colors.red,
                  ),
                ],
              ),
    );
  }
}

// --- Reusable Widget ---
class ProfileMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color? textColor;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9).withOpacity(0.5),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 23),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? Colors.black, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor ?? Colors.black,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: textColor ?? Colors.grey[600],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
