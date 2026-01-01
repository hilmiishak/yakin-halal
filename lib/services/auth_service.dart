import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/error_handler.dart';
import '../core/constants/app_constants.dart';

/// Authentication service
///
/// Provides a clean interface for authentication operations,
/// abstracting Firebase Auth implementation details.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get the current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Check if current user's email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<Result<User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return ErrorHandler.guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw AuthException.invalidCredentials();
      }

      if (!user.emailVerified) {
        throw AuthException.emailNotVerified();
      }

      debugPrint('User signed in: ${user.email}');
      return user;
    });
  }

  /// Create a new account with email and password
  Future<Result<User>> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return ErrorHandler.guard(() async {
      // Validate inputs
      if (password.length < ValidationConstants.minPasswordLength) {
        throw AuthException.weakPassword();
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException(
          message: 'Failed to create account',
          code: 'ACCOUNT_CREATION_FAILED',
        );
      }

      // Update display name
      await user.updateDisplayName(displayName.trim());

      // Create user document in Firestore
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .set({
        'email': email.trim(),
        'name': displayName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await user.sendEmailVerification();

      debugPrint('Account created for: ${user.email}');
      return user;
    });
  }

  /// Send password reset email
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    return ErrorHandler.guard(() async {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to: $email');
    });
  }

  /// Resend email verification
  Future<Result<void>> resendVerificationEmail() async {
    return ErrorHandler.guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException.sessionExpired();
      }
      await user.sendEmailVerification();
      debugPrint('Verification email resent to: ${user.email}');
    });
  }

  /// Update password
  Future<Result<void>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return ErrorHandler.guard(() async {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException.sessionExpired();
      }

      if (newPassword.length < ValidationConstants.minPasswordLength) {
        throw AuthException.weakPassword();
      }

      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      debugPrint('Password updated for: ${user.email}');
    });
  }

  /// Update display name
  Future<Result<void>> updateDisplayName(String displayName) async {
    return ErrorHandler.guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException.sessionExpired();
      }

      await user.updateDisplayName(displayName.trim());

      // Also update in Firestore
      await _firestore
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .set({'name': displayName.trim()}, SetOptions(merge: true));

      debugPrint('Display name updated to: $displayName');
    });
  }

  /// Sign out
  Future<Result<void>> signOut() async {
    return ErrorHandler.guard(() async {
      await _auth.signOut();
      debugPrint('User signed out');
    });
  }

  /// Delete account
  Future<Result<void>> deleteAccount(String password) async {
    return ErrorHandler.guard(() async {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw AuthException.sessionExpired();
      }

      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await _deleteUserData(user.uid);

      // Delete the account
      await user.delete();
      debugPrint('Account deleted');
    });
  }

  /// Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    // Delete user document
    batch.delete(_firestore.collection(FirebaseCollections.users).doc(userId));

    // Delete user's calorie entries
    final calorieQuery = await _firestore
        .collection(FirebaseCollections.calorieEntries)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in calorieQuery.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's favorites
    final favoritesQuery = await _firestore
        .collection(FirebaseCollections.favorites)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in favoritesQuery.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's reviews
    final reviewsQuery = await _firestore
        .collection(FirebaseCollections.reviews)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in reviewsQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Get user profile data from Firestore
  Future<Result<Map<String, dynamic>>> getUserProfile() async {
    return ErrorHandler.guard(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException.sessionExpired();
      }

      final doc = await _firestore
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        return {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? 'User',
        };
      }

      return {
        'uid': user.uid,
        ...doc.data()!,
      };
    });
  }
}
