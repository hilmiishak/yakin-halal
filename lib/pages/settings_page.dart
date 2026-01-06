import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'login.dart';
import 'change_password_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _newRestaurantAlerts = true;
  bool _promotionAlerts = false;
  bool _reviewReplies = true;
  bool _weeklyDigest = false;
  bool _isLoading = true;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // App info
  static const String _appVersion = "1.0.0";
  static const String _developerName = "Muhammad Hilmi bin Ishak";
  static const String _universityName = "Universiti Sains Islam Malaysia";
  static const String _supportEmail = "yakinhalalapp01@gmail.com";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _notificationsEnabled = data?['notificationsEnabled'] ?? true;
          _newRestaurantAlerts = data?['newRestaurantAlerts'] ?? true;
          _promotionAlerts = data?['promotionAlerts'] ?? false;
          _reviewReplies = data?['reviewReplies'] ?? true;
          _weeklyDigest = data?['weeklyDigest'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateNotificationPreference(String key, bool value) async {
    // Update local state
    setState(() {
      switch (key) {
        case 'notificationsEnabled':
          _notificationsEnabled = value;
          // If master toggle is off, disable all sub-settings
          if (!value) {
            _newRestaurantAlerts = false;
            _promotionAlerts = false;
            _reviewReplies = false;
            _weeklyDigest = false;
          }
          break;
        case 'newRestaurantAlerts':
          _newRestaurantAlerts = value;
          break;
        case 'promotionAlerts':
          _promotionAlerts = value;
          break;
        case 'reviewReplies':
          _reviewReplies = value;
          break;
        case 'weeklyDigest':
          _weeklyDigest = value;
          break;
      }
    });

    if (_currentUser == null) return;

    try {
      Map<String, dynamic> updates = {key: value};

      // If master toggle is off, update all sub-settings too
      if (key == 'notificationsEnabled' && !value) {
        updates = {
          'notificationsEnabled': false,
          'newRestaurantAlerts': false,
          'promotionAlerts': false,
          'reviewReplies': false,
          'weeklyDigest': false,
        };
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set(updates, SetOptions(merge: true));

      _showSnackBar(
        value ? "Notification enabled" : "Notification disabled",
        isSuccess: true,
      );
    } catch (e) {
      _showSnackBar("Failed to save preference", isSuccess: false);
      // Revert on error
      _loadSettings();
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final confirmTextController = TextEditingController();
    bool isPasswordVisible = false;
    bool isLoading = false;
    String? errorMessage;

    if (_currentUser?.email == null) {
      _showSnackBar(
        "Please log in again to delete your account",
        isSuccess: false,
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade400,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Delete Account",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.red.shade400,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "This action is permanent and cannot be undone.",
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "The following data will be deleted:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDeleteItem("Your profile and preferences"),
                        _buildDeleteItem("Saved favorites"),
                        _buildDeleteItem("Review history"),
                        _buildDeleteItem("Calorie tracking data"),
                        _buildDeleteItem("View history"),
                        const SizedBox(height: 20),
                        Text(
                          "Enter your password to confirm:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          enabled: !isLoading,
                          decoration: InputDecoration(
                            labelText: "Password",
                            hintText: "Enter your password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setDialogState(
                                    () =>
                                        isPasswordVisible = !isPasswordVisible,
                                  ),
                            ),
                            errorText: errorMessage,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Type DELETE to confirm:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: confirmTextController,
                          enabled: !isLoading,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: "Type DELETE",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.text_fields),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                // Validate inputs
                                if (passwordController.text.isEmpty) {
                                  setDialogState(
                                    () => errorMessage = "Password is required",
                                  );
                                  return;
                                }
                                if (confirmTextController.text.toUpperCase() !=
                                    "DELETE") {
                                  setDialogState(
                                    () =>
                                        errorMessage =
                                            "Please type DELETE to confirm",
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });

                                // Execute deletion
                                final success = await _executeAccountDeletion(
                                  passwordController.text.trim(),
                                );

                                if (!success && context.mounted) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMessage =
                                        "Incorrect password. Please try again.";
                                  });
                                }
                              },
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text("Delete My Account"),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            size: 16,
            color: Colors.red.shade300,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _executeAccountDeletion(String password) async {
    if (_currentUser?.email == null) return false;

    try {
      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: password,
      );
      await _currentUser.reauthenticateWithCredential(credential);

      // Delete user data from Firestore (subcollections too)
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid);

      // Delete subcollections
      final viewHistory = await userRef.collection('view_history').get();
      for (var doc in viewHistory.docs) {
        await doc.reference.delete();
      }

      final calorieTracker = await userRef.collection('calorie_tracker').get();
      for (var doc in calorieTracker.docs) {
        await doc.reference.delete();
      }

      // Delete main user document
      await userRef.delete();

      // Delete Firebase Auth account
      await _currentUser.delete();

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        _showSnackBar("Account deleted successfully", isSuccess: true);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Delete account error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Delete account error: $e");
      return false;
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'YakinHalal Support Request'},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showSnackBar("Could not open email app", isSuccess: false);
    }
  }

  void _shareApp() {
    SharePlus.instance.share(
      ShareParams(
        text:
            "🍽️ Check out YakinHalal - Find trusted Halal restaurants near you!\n\n"
            "Download now and discover verified Halal dining options with smart recommendations.",
        subject: "YakinHalal - Halal Restaurant Finder",
      ),
    );
  }

  void _showSnackBar(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFF5F9F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // Notifications Section
                  _buildSectionHeader("NOTIFICATIONS"),
                  _buildSettingsCard(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_active_outlined,
                        iconColor: Colors.blue,
                        title: "Push Notifications",
                        subtitle: "Master toggle for all notifications",
                        value: _notificationsEnabled,
                        onChanged:
                            (v) => _updateNotificationPreference(
                              'notificationsEnabled',
                              v,
                            ),
                      ),
                    ],
                  ),

                  // Notification Types (only show if master toggle is on)
                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 8),
                    _buildSettingsCard(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.restaurant_outlined,
                          iconColor: Colors.green,
                          title: "New Restaurant Alerts",
                          subtitle:
                              "When new halal restaurants are added nearby",
                          value: _newRestaurantAlerts,
                          onChanged:
                              (v) => _updateNotificationPreference(
                                'newRestaurantAlerts',
                                v,
                              ),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.local_offer_outlined,
                          iconColor: Colors.orange,
                          title: "Promotions & Deals",
                          subtitle: "Special offers from restaurants",
                          value: _promotionAlerts,
                          onChanged:
                              (v) => _updateNotificationPreference(
                                'promotionAlerts',
                                v,
                              ),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.reply_outlined,
                          iconColor: Colors.purple,
                          title: "Review Replies",
                          subtitle: "When restaurants reply to your reviews",
                          value: _reviewReplies,
                          onChanged:
                              (v) => _updateNotificationPreference(
                                'reviewReplies',
                                v,
                              ),
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.calendar_today_outlined,
                          iconColor: Colors.teal,
                          title: "Weekly Digest",
                          subtitle: "Summary of new restaurants & top picks",
                          value: _weeklyDigest,
                          onChanged:
                              (v) => _updateNotificationPreference(
                                'weeklyDigest',
                                v,
                              ),
                        ),
                      ],
                    ),
                  ],

                  // Account Section
                  _buildSectionHeader("ACCOUNT"),
                  _buildSettingsCard(
                    children: [
                      _buildNavTile(
                        icon: Icons.lock_outline,
                        iconColor: Colors.teal,
                        title: "Change Password",
                        subtitle: "Update your password",
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            ),
                      ),
                      const Divider(height: 1),
                      _buildNavTile(
                        icon: Icons.delete_forever_outlined,
                        iconColor: Colors.red,
                        title: "Delete Account",
                        subtitle: "Permanently remove your account",
                        isDestructive: true,
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                  ),

                  // Support Section
                  _buildSectionHeader("SUPPORT"),
                  _buildSettingsCard(
                    children: [
                      _buildNavTile(
                        icon: Icons.email_outlined,
                        iconColor: Colors.orange,
                        title: "Contact Support",
                        subtitle: _supportEmail,
                        onTap: _launchEmail,
                      ),
                      const Divider(height: 1),
                      _buildNavTile(
                        icon: Icons.share_outlined,
                        iconColor: Colors.purple,
                        title: "Share App",
                        subtitle: "Invite friends to YakinHalal",
                        onTap: _shareApp,
                      ),
                    ],
                  ),

                  // Legal Section
                  _buildSectionHeader("LEGAL"),
                  _buildSettingsCard(
                    children: [
                      _buildNavTile(
                        icon: Icons.shield_outlined,
                        iconColor: Colors.green,
                        title: "Privacy Policy",
                        onTap:
                            () => _showInfoPage(
                              "Privacy Policy",
                              _privacyPolicyContent,
                              Icons.shield_outlined,
                              Colors.green,
                            ),
                      ),
                      const Divider(height: 1),
                      _buildNavTile(
                        icon: Icons.description_outlined,
                        iconColor: Colors.indigo,
                        title: "Terms of Service",
                        onTap:
                            () => _showInfoPage(
                              "Terms of Service",
                              _termsOfServiceContent,
                              Icons.description_outlined,
                              Colors.indigo,
                            ),
                      ),
                    ],
                  ),

                  // About Section
                  _buildSectionHeader("ABOUT"),
                  _buildAboutCard(),

                  const SizedBox(height: 32),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF00A884),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDestructive ? Colors.red : Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo & Name
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A884), Color(0xFF00D4AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A884).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "YakinHalal",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "Version $_appVersion",
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF00A884),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          _buildAboutRow(Icons.person_outline, "Developer", _developerName),
          const SizedBox(height: 12),
          _buildAboutRow(Icons.school_outlined, "University", _universityName),
          const SizedBox(height: 16),
          Text(
            "Final Year Project 2025/2026",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  void _showInfoPage(String title, String content, IconData icon, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _EnhancedInfoPage(
              title: title,
              content: content,
              icon: icon,
              color: color,
            ),
      ),
    );
  }

  // Content strings
  static const String _privacyPolicyContent = """
1. Information We Collect
We collect your email address, food preferences, and location data to provide personalized restaurant recommendations.

2. How We Use Your Data
• Personalize your halal restaurant recommendations
• Save your favorites and view history
• Improve our recommendation algorithms
• Send important notifications (if enabled)

3. Data Storage & Security
Your data is securely stored on Google Firebase servers with industry-standard encryption.

4. Third-Party Services
We use Google Places API to provide restaurant information. Google's privacy policy applies to that data.

5. Your Rights
You can request to view, modify, or delete your personal data at any time through the app settings.

6. Contact Us
For privacy concerns, contact us at yakinhalalapp01@gmail.com
""";

  static const String _termsOfServiceContent = """
1. Acceptance of Terms
By using YakinHalal, you agree to be bound by these Terms of Service.

2. User Conduct
You agree to:
• Provide accurate and honest reviews
• Respect restaurant staff and other users
• Not submit false halal status claims
• Not use the app for any unlawful purposes

3. Content Guidelines
• Reviews must be based on genuine experiences
• Offensive or discriminatory content is prohibited
• Spam and promotional content is not allowed

4. Account Responsibilities
• Keep your login credentials secure
• You are responsible for all activities under your account
• Notify us immediately of any unauthorized access

5. Disclaimer
Restaurant halal status is verified to the best of our ability but we recommend confirming with the restaurant directly for dietary concerns.

6. Termination
We reserve the right to suspend or terminate accounts that violate these terms.

7. Contact
Questions? Email us at yakinhalalapp01@gmail.com
""";
}

// Enhanced Info Page Widget
class _EnhancedInfoPage extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _EnhancedInfoPage({
    required this.title,
    required this.content,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFF5F9F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.8), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Last updated: January 2026",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
