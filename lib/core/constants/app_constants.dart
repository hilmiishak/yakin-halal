/// Application-wide constants
///
/// This file contains all the constant values used throughout the app.
/// Centralizing constants improves maintainability and reduces magic numbers.
library;

/// API and service configuration constants
class ApiConstants {
  ApiConstants._();

  /// Google Places API base URL
  static const String googlePlacesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';

  /// Default search radius in meters
  static const int defaultSearchRadiusMeters = 5000;

  /// Maximum search radius in meters
  static const int maxSearchRadiusMeters = 50000;

  /// API request timeout duration
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Number of results per page for pagination
  static const int resultsPerPage = 20;
}

/// Firebase collection names
class FirebaseCollections {
  FirebaseCollections._();

  static const String users = 'users';
  static const String restaurants = 'halal_restaurants';
  static const String reviews = 'reviews';
  static const String favorites = 'favorites';
  static const String viewHistory = 'viewHistory';
  static const String calorieEntries = 'calorie_entries';
  static const String preferences = 'preferences';
  static const String reports = 'reports';
}

/// Calorie tracker constants
class CalorieConstants {
  CalorieConstants._();

  /// Default daily calorie limit
  static const int defaultDailyLimit = 2000;

  /// Minimum calorie limit
  static const int minDailyLimit = 1000;

  /// Maximum calorie limit
  static const int maxDailyLimit = 5000;

  /// Activity level multipliers for TDEE calculation
  static const Map<String, double> activityMultipliers = {
    'Sedentary': 1.2,
    'Light': 1.375,
    'Moderate': 1.55,
    'Active': 1.725,
    'Very Active': 1.9,
  };
}

/// Distance and location constants
class LocationConstants {
  LocationConstants._();

  /// Default location accuracy for GPS
  static const double highAccuracyThreshold = 100.0;

  /// Maximum distance to show restaurants (in km)
  static const double maxDisplayDistance = 50.0;

  /// Distance considered "nearby" (in km)
  static const double nearbyThreshold = 2.0;

  /// Earth's radius in kilometers (for Haversine formula)
  static const double earthRadiusKm = 6371.0;
}

/// UI timing constants
class AnimationConstants {
  AnimationConstants._();

  /// Standard animation duration
  static const Duration standard = Duration(milliseconds: 300);

  /// Fast animation duration
  static const Duration fast = Duration(milliseconds: 150);

  /// Slow animation duration
  static const Duration slow = Duration(milliseconds: 500);

  /// Page transition duration
  static const Duration pageTransition = Duration(milliseconds: 400);
}

/// Validation constants
class ValidationConstants {
  ValidationConstants._();

  /// Minimum password length
  static const int minPasswordLength = 6;

  /// Maximum username length
  static const int maxUsernameLength = 50;

  /// Maximum review text length
  static const int maxReviewLength = 1000;

  /// Minimum review text length
  static const int minReviewLength = 10;
}

/// Cache duration constants
class CacheConstants {
  CacheConstants._();

  /// Duration to cache restaurant data
  static const Duration restaurantCache = Duration(hours: 1);

  /// Duration to cache user preferences
  static const Duration preferencesCache = Duration(days: 1);

  /// Duration to cache location data
  static const Duration locationCache = Duration(minutes: 5);

  /// Maximum cached items
  static const int maxCachedRestaurants = 100;
}
