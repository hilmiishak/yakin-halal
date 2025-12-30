import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isCurrentPasswordObscured = true;
  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Main logic to update the password ---
  Future<void> _updatePassword() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Get the current user
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showErrorSnackBar("No user logged in. Please log in again.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. Re-authenticate the user with their CURRENT password
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      // 4. If re-authentication is successful, update to the NEW password
      await user.updatePassword(_newPasswordController.text.trim());

      if (mounted) {
        _showSuccessSnackBar("Password updated successfully!");
        Navigator.of(context).pop(); // Go back to the profile page
      }

    } on FirebaseAuthException catch (e) {
      // 5. Handle errors
      if (e.code == 'wrong-password') {
        _showErrorSnackBar("Your current password is incorrect.");
      } else {
        _showErrorSnackBar(e.message ?? "An error occurred.");
      }
    } catch (e) {
      _showErrorSnackBar("An unexpected error occurred: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper functions to show snackbars
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F9F4),
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: const Color(0xFF93DCC9),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // --- Current Password Field ---
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _isCurrentPasswordObscured,
                decoration: _buildInputDecoration(
                  "Current Password",
                  _isCurrentPasswordObscured,
                      () => setState(() => _isCurrentPasswordObscured = !_isCurrentPasswordObscured),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? "Please enter your current password" : null,
              ),
              const SizedBox(height: 16),

              // --- New Password Field ---
              TextFormField(
                controller: _newPasswordController,
                obscureText: _isNewPasswordObscured,
                decoration: _buildInputDecoration(
                  "New Password",
                  _isNewPasswordObscured,
                      () => setState(() => _isNewPasswordObscured = !_isNewPasswordObscured),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter a new password";
                  if (value.length < 6) return "Password must be at least 6 characters";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Confirm New Password Field ---
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _isConfirmPasswordObscured,
                decoration: _buildInputDecoration(
                  "Confirm New Password",
                  _isConfirmPasswordObscured,
                      () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please confirm your password";
                  if (value != _newPasswordController.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // --- Update Button ---
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF03BF8D), // Match your login button
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  onPressed: _isLoading ? null : _updatePassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Update Password",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper function for consistent text field styling ---
  InputDecoration _buildInputDecoration(
      String label, bool isObscured, VoidCallback toggleObscured) {
    return InputDecoration(
      labelText: label,
      fillColor: const Color(0xFFD9D9D9).withOpacity(0.5),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 23, vertical: 20),
      suffixIcon: IconButton(
        icon: Icon(
          isObscured ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey[600],
        ),
        onPressed: toggleObscured,
      ),
    );
  }
}