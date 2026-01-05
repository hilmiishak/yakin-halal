import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'login.dart';
import 'preference.dart';
// Ensure you create this file below or update your existing imports
import 'static_info_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final formKey = GlobalKey<FormState>();

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isAgreedToTerms = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Password Strength State
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    // Listen to password changes to update UI in real-time
    passwordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final text = passwordController.text;
    setState(() {
      _hasMinLength = text.length >= 8;
      _hasUppercase = text.contains(RegExp(r'[A-Z]'));
      _hasDigits = text.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = text.contains(RegExp(r'[!@#\$&*~]'));
    });
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> createUserWithEmailAndPassword() async {
    if (!formKey.currentState!.validate()) return;

    // Check strict password requirements manually to be safe
    if (!(_hasMinLength && _hasUppercase && _hasDigits && _hasSpecialChar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fulfill all password requirements below."),
        ),
      );
      return;
    }

    if (!isAgreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must agree to the Terms & Privacy Policy."),
        ),
      );
      return;
    }

    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    try {
      setState(() => isLoading = true);

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
        await _saveUserToFirestore(
          userCredential.user!,
          name: fullNameController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration failed")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveUserToFirestore(User user, {required String name}) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'authMethod': 'email',
    }, SetOptions(merge: true));

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => PreferencePage(userId: user.uid),
        ),
        (route) => false, // Kill all previous history
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.5;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background Circles
            Positioned(
              left: -circleSize * 0.6,
              top: -circleSize * 0.2,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x636ED2B7),
                ),
              ),
            ),
            Positioned(
              left: circleSize * 0.005,
              top: -circleSize * 0.6,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x636ED2B7),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 80),
                      const Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const Text(
                        "Join YakinHalal today",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 40),

                      _buildInputField(
                        "Short Name",
                        Icons.person_outline,
                        controller: fullNameController,
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        "Email",
                        Icons.email_outlined,
                        controller: emailController,
                      ),
                      const SizedBox(height: 15),

                      _buildPasswordField(
                        "Password",
                        passwordController,
                        _isPasswordVisible,
                        () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),

                      // ⭐️ NEW: Password Strength Visual Indicator
                      if (passwordController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 5,
                          ),
                          child: Column(
                            children: [
                              _buildPasswordCriteria(
                                "At least 8 characters",
                                _hasMinLength,
                              ),
                              _buildPasswordCriteria(
                                "Contains Uppercase (A-Z)",
                                _hasUppercase,
                              ),
                              _buildPasswordCriteria(
                                "Contains Number (0-9)",
                                _hasDigits,
                              ),
                              _buildPasswordCriteria(
                                "Special Character (!@#\$&*~)",
                                _hasSpecialChar,
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 15),
                      _buildPasswordField(
                        "Confirm Password",
                        confirmPasswordController,
                        _isConfirmPasswordVisible,
                        () => setState(
                          () =>
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: isAgreedToTerms,
                              activeColor: const Color(0xFF03BF8D),
                              onChanged:
                                  (value) =>
                                      setState(() => isAgreedToTerms = value!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: "I agree to the ",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                  color: Colors.black,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Terms of Service",
                                    style: TextStyle(
                                      color: Colors.teal[700],
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            // ⭐️ NEW: Navigate to Terms
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => const StaticInfoPage(
                                                      title: "Terms of Service",
                                                      // Content taken from your PDF
                                                      content:
                                                          "By using YakinHalal, you agree to treat restaurant staff with respect and provide honest reviews.\n\nWe reserve the right to ban users who violate these terms.",
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                  const TextSpan(text: " and "),
                                  TextSpan(
                                    text: "Privacy Policy",
                                    style: TextStyle(
                                      color: Colors.teal[700],
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            // ⭐️ NEW: Navigate to Privacy
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => const StaticInfoPage(
                                                      title: "Privacy Policy",
                                                      // Content taken from your PDF
                                                      content:
                                                          "1. Data Collection\nWe collect your email and food preferences to improve recommendations.\n\n2. Data Security\nYour data is stored securely on Google Firebase.",
                                                    ),
                                              ),
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03BF8D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed:
                              isLoading ? null : createUserWithEmailAndPassword,
                          child:
                              isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    "SIGN UP",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(fontFamily: 'Poppins'),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                ),
                            child: const Text(
                              "Sign in",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4DBE9C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐️ NEW: Helper for Password Requirement Row
  Widget _buildPasswordCriteria(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          color: isMet ? Colors.green : Colors.grey,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isMet ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String hint,
    IconData icon, {
    TextEditingController? controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        validator: (value) => value!.isEmpty ? "Enter $hint" : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    TextEditingController controller,
    bool isVisible,
    VoidCallback onToggle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[700]),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey[700],
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
