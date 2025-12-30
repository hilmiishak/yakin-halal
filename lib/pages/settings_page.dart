import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'change_password_page.dart'; // ⭐️ Import your new page here

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  // 🔹 1. LOAD NOTIFICATION PREFERENCE
  Future<void> _loadNotificationPreference() async {
    if (_currentUser == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser.uid)
              .get();
      if (doc.exists && mounted) {
        setState(() {
          _notificationsEnabled = doc.data()?['notificationsEnabled'] ?? true;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  // 🔹 2. SAVE NOTIFICATION PREFERENCE
  Future<void> _updateNotificationPreference(bool value) async {
    setState(() => _notificationsEnabled = value);
    if (_currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .update({'notificationsEnabled': value});
      _showSuccessSnackBar("Preference saved.");
    } catch (e) {
      _showErrorSnackBar("Failed to save preference.");
    }
  }

  // 🔹 3. DELETE ACCOUNT LOGIC
  Future<void> _showDeleteAccountDialog() async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Account?"),
            content: const Text(
              "This is a permanent action. All your data will be deleted. This cannot be undone.",
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    );

    if (didConfirm == true) {
      _showPasswordEntryDialogForDeletion();
    }
  }

  Future<void> _showPasswordEntryDialogForDeletion() async {
    final passwordController = TextEditingController();
    if (_currentUser == null || _currentUser.email == null) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your password to confirm."),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Confirm"),
              onPressed: () {
                _deleteAccountFinal(passwordController.text.trim());
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccountFinal(String password) async {
    if (_currentUser == null || _currentUser.email == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Re-authenticate
      final AuthCredential credential = EmailAuthProvider.credential(
        email: _currentUser.email!,
        password: password,
      );
      await _currentUser.reauthenticateWithCredential(credential);

      // Delete Data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .delete();

      // Delete User
      await _currentUser.delete();

      if (mounted) {
        Navigator.of(context).pop(); // Close spinner
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close spinner
        _showErrorSnackBar(e.message ?? "Delete failed.");
      }
    }
  }

  // --- UI Helpers ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildNavListTile({
    required String title,
    required IconData icon,
    VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: color ?? Colors.grey[600],
        size: 16,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE3F9F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          _buildSectionHeader("NOTIFICATIONS"),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            subtitle: const Text("Receive promotions and alerts"),
            value: _notificationsEnabled,
            onChanged: _updateNotificationPreference,
            secondary: const Icon(Icons.notifications_none),
            activeColor: const Color(0xFF03BF8D),
          ),
          _buildSectionHeader("ACCOUNT"),

          // ⭐️ UPDATED: Change Password now navigates to the page
          _buildNavListTile(
            title: "Change Password",
            icon: Icons.lock_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),

          _buildNavListTile(
            title: "Delete Account",
            icon: Icons.delete_forever_outlined,
            color: Colors.red,
            onTap: _showDeleteAccountDialog,
          ),
          _buildSectionHeader("LEGAL & ABOUT"),
          _buildNavListTile(
            title: "Privacy Policy",
            icon: Icons.shield_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => const StaticInfoPage(
                        title: "Privacy Policy",
                        content:
                            "1. Data Collection\nWe collect your email and food preferences to improve recommendations.\n\n2. Data Security\nYour data is stored securely on Google Firebase.\n\n3. Contact\nContact us at admin@yakinhalal.com for concerns.",
                      ),
                ),
              );
            },
          ),
          _buildNavListTile(
            title: "Terms of Service",
            icon: Icons.description_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => const StaticInfoPage(
                        title: "Terms of Service",
                        content:
                            "By using YakinHalal, you agree to:\n- Treat restaurant staff with respect.\n- Provide honest reviews.\n\nWe reserve the right to ban users who violate these terms.",
                      ),
                ),
              );
            },
          ),
          _buildNavListTile(
            title: "About Us",
            icon: Icons.info_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => const StaticInfoPage(
                        title: "About YakinHalal",
                        content:
                            "YakinHalal is a Final Year Project designed to help Muslim consumers find trusted Halal dining options using smart recommendation algorithms.\n\nVersion: 1.0.0\nDeveloper: Muhammad Hilmi bin Ishak\nUniversity: Universiti Sains Islam Malaysia",
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ⭐️ INTERNAL CLASS FOR INFO PAGES
class StaticInfoPage extends StatelessWidget {
  final String title;
  final String content;

  const StaticInfoPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFE3F9F4),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
