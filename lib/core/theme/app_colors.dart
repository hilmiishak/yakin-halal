import 'package:flutter/material.dart';

/// Application color palette
///
/// Centralized color definitions for consistent theming across the app.
/// Uses the teal-based color scheme established in the app design.
class AppColors {
  AppColors._();

  // ============ Primary Colors ============

  /// Primary brand color - Teal
  static const Color primary = Color(0xFF009688);

  /// Primary color variants
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00796B);

  /// Primary color with opacity for overlays
  static Color primaryOverlay = primary.withValues(alpha: 0.1);

  // ============ Secondary Colors ============

  /// Secondary accent color
  static const Color secondary = Color(0xFF6ED2B7);

  /// Secondary light variant
  static const Color secondaryLight = Color(0xFFA5E8D3);

  // ============ Background Colors ============

  /// Main scaffold background
  static const Color background = Color(0xFFEEEEEE);

  /// Card and surface background
  static const Color surface = Colors.white;

  /// Slightly elevated surface
  static const Color surfaceElevated = Color(0xFFFAFAFA);

  // ============ Text Colors ============

  /// Primary text color
  static const Color textPrimary = Color(0xFF212121);

  /// Secondary text color
  static const Color textSecondary = Color(0xFF757575);

  /// Hint/placeholder text color
  static const Color textHint = Color(0xFF9E9E9E);

  /// Text on primary color background
  static const Color textOnPrimary = Colors.white;

  // ============ Status Colors ============

  /// Success/positive indicator
  static const Color success = Color(0xFF4CAF50);

  /// Warning indicator
  static const Color warning = Color(0xFFFF9800);

  /// Error/danger indicator
  static const Color error = Color(0xFFE53935);

  /// Info indicator
  static const Color info = Color(0xFF2196F3);

  // ============ Halal Verification Colors ============

  /// Certified halal badge color
  static const Color halalCertified = Color(0xFF2E7D32);

  /// Community verified badge color
  static const Color halalCommunity = Color(0xFFFF8F00);

  /// Unverified/unknown status
  static const Color halalUnknown = Color(0xFF9E9E9E);

  // ============ Calorie Tracker Colors ============

  /// Under calorie limit
  static const Color calorieUnder = Color(0xFF4CAF50);

  /// At calorie limit
  static const Color calorieAt = Color(0xFFFF9800);

  /// Over calorie limit
  static const Color calorieOver = Color(0xFFE53935);

  // ============ Rating Colors ============

  /// Star rating color
  static const Color ratingStar = Color(0xFFFFC107);

  /// Empty star color
  static const Color ratingEmpty = Color(0xFFE0E0E0);

  // ============ Gradient Definitions ============

  /// Primary gradient for headers and accents
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Card gradient for highlighted items
  static const LinearGradient cardGradient = LinearGradient(
    colors: [surface, surfaceElevated],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============ Shadow Colors ============

  /// Default shadow color
  static Color shadowColor = Colors.black.withValues(alpha: 0.1);

  /// Elevated shadow color
  static Color shadowElevated = Colors.black.withValues(alpha: 0.15);
}
