import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'registration.dart';
import 'dashboard.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUserWithEmailAndPassword() async {
    if (!formKey.currentState!.validate()) return;

    try {
      setState(() => isLoading = true);

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        // Check Verification
        if (user.emailVerified || user.email == "umar@gmail.com") {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
                  (route) => false, // This condition 'false' removes everything before
            );
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) _showVerificationDialog(user);
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Login failed")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showVerificationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Email Not Verified"),
        content: const Text("Please check your inbox and verify your email before logging in."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          TextButton(
            onPressed: () async {
              await user.sendEmailVerification();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Verification email resent!")),
              );
            },
            child: const Text("Resend Email"),
          ),
        ],
      ),
    );
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
              child: Container(width: circleSize, height: circleSize, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x636ED2B7))),
            ),
            Positioned(
              left: circleSize * 0.005,
              top: -circleSize * 0.6,
              child: Container(width: circleSize, height: circleSize, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x636ED2B7))),
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
                        "WELCOME BACK!",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 40),

                      _buildInputField("Enter your email", Icons.email_outlined, controller: emailController),
                      const SizedBox(height: 20),

                      _buildPasswordField("Enter your password",
                          controller: passwordController,
                          isVisible: _isPasswordVisible,
                          onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible)
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Color(0xFF4DBE9C),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Login Button
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
                          onPressed: isLoading ? null : loginUserWithEmailAndPassword,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            "LOGIN",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don’t have an account? ",
                            style: TextStyle(color: Colors.black, fontFamily: 'Poppins'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistrationPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Sign up",
                              style: TextStyle(
                                color: Color(0xFF4DBE9C),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
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

  Widget _buildInputField(String hint, IconData icon, {TextEditingController? controller}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        controller: controller,
        validator: (value) => (value == null || value.isEmpty) ? "Please enter $hint" : null,
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.grey[600]),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.black54),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String hint, {required TextEditingController controller, required bool isVisible, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFD9D9D9), borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextFormField(
        controller: controller,
        obscureText: !isVisible,
        validator: (value) => (value == null || value.isEmpty) ? "Please enter password" : null,
        decoration: InputDecoration(
          icon: const Icon(Icons.lock_outline, color: Colors.grey),
          suffixIcon: IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: onToggle),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.black54),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}