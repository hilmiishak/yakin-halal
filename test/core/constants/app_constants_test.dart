import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/core/constants/app_constants.dart';

void main() {
  group('ApiConstants', () {
    test('googlePlacesBaseUrl should be valid URL', () {
      expect(ApiConstants.googlePlacesBaseUrl, startsWith('https://'));
      expect(ApiConstants.googlePlacesBaseUrl, contains('googleapis.com'));
    });

    test('defaultSearchRadiusMeters should be reasonable', () {
      expect(ApiConstants.defaultSearchRadiusMeters, greaterThan(0));
      expect(ApiConstants.defaultSearchRadiusMeters, lessThanOrEqualTo(50000));
    });

    test('maxSearchRadiusMeters should be greater than default', () {
      expect(
        ApiConstants.maxSearchRadiusMeters,
        greaterThan(ApiConstants.defaultSearchRadiusMeters),
      );
    });

    test('apiTimeout should be reasonable', () {
      expect(ApiConstants.apiTimeout.inSeconds, greaterThanOrEqualTo(10));
      expect(ApiConstants.apiTimeout.inSeconds, lessThanOrEqualTo(60));
    });

    test('resultsPerPage should be positive', () {
      expect(ApiConstants.resultsPerPage, greaterThan(0));
    });
  });

  group('FirebaseCollections', () {
    test('all collection names should be non-empty strings', () {
      expect(FirebaseCollections.users, isNotEmpty);
      expect(FirebaseCollections.restaurants, isNotEmpty);
      expect(FirebaseCollections.reviews, isNotEmpty);
      expect(FirebaseCollections.favorites, isNotEmpty);
      expect(FirebaseCollections.viewHistory, isNotEmpty);
      expect(FirebaseCollections.calorieEntries, isNotEmpty);
      expect(FirebaseCollections.preferences, isNotEmpty);
      expect(FirebaseCollections.reports, isNotEmpty);
    });

    test('collection names should be valid Firestore paths', () {
      // Firestore collection names cannot contain '/'
      expect(FirebaseCollections.users, isNot(contains('/')));
      expect(FirebaseCollections.restaurants, isNot(contains('/')));
    });
  });

  group('CalorieConstants', () {
    test('defaultDailyLimit should be reasonable', () {
      expect(CalorieConstants.defaultDailyLimit, greaterThan(1000));
      expect(CalorieConstants.defaultDailyLimit, lessThan(5000));
    });

    test('minDailyLimit should be less than default', () {
      expect(
        CalorieConstants.minDailyLimit,
        lessThan(CalorieConstants.defaultDailyLimit),
      );
    });

    test('maxDailyLimit should be greater than default', () {
      expect(
        CalorieConstants.maxDailyLimit,
        greaterThan(CalorieConstants.defaultDailyLimit),
      );
    });

    test('activityMultipliers should have expected values', () {
      expect(CalorieConstants.activityMultipliers, isNotEmpty);
      expect(CalorieConstants.activityMultipliers, contains('Sedentary'));
      expect(CalorieConstants.activityMultipliers, contains('Active'));

      // Multipliers should increase with activity level
      expect(
        CalorieConstants.activityMultipliers['Sedentary'],
        lessThan(CalorieConstants.activityMultipliers['Active']!),
      );
    });

    test('all activity multipliers should be between 1 and 3', () {
      for (final multiplier in CalorieConstants.activityMultipliers.values) {
        expect(multiplier, greaterThanOrEqualTo(1.0));
        expect(multiplier, lessThanOrEqualTo(3.0));
      }
    });
  });

  group('LocationConstants', () {
    test('earthRadiusKm should be approximately correct', () {
      // Earth's radius is approximately 6,371 km
      expect(LocationConstants.earthRadiusKm, closeTo(6371, 10));
    });

    test('maxDisplayDistance should be reasonable', () {
      expect(LocationConstants.maxDisplayDistance, greaterThan(0));
      expect(LocationConstants.maxDisplayDistance, lessThan(1000));
    });

    test('nearbyThreshold should be less than maxDisplayDistance', () {
      expect(
        LocationConstants.nearbyThreshold,
        lessThan(LocationConstants.maxDisplayDistance),
      );
    });

    test('highAccuracyThreshold should be positive', () {
      expect(LocationConstants.highAccuracyThreshold, greaterThan(0));
    });
  });

  group('AnimationConstants', () {
    test('animation durations should be ordered correctly', () {
      expect(
        AnimationConstants.fast.inMilliseconds,
        lessThan(AnimationConstants.standard.inMilliseconds),
      );
      expect(
        AnimationConstants.standard.inMilliseconds,
        lessThan(AnimationConstants.slow.inMilliseconds),
      );
    });

    test('all durations should be positive', () {
      expect(AnimationConstants.fast.inMilliseconds, greaterThan(0));
      expect(AnimationConstants.standard.inMilliseconds, greaterThan(0));
      expect(AnimationConstants.slow.inMilliseconds, greaterThan(0));
      expect(AnimationConstants.pageTransition.inMilliseconds, greaterThan(0));
    });

    test('durations should be reasonable for UX', () {
      // Animations shouldn't be too long
      expect(AnimationConstants.slow.inMilliseconds, lessThan(1000));
    });
  });

  group('ValidationConstants', () {
    test('minPasswordLength should be reasonable for security', () {
      expect(ValidationConstants.minPasswordLength, greaterThanOrEqualTo(6));
    });

    test('maxUsernameLength should allow reasonable names', () {
      expect(ValidationConstants.maxUsernameLength, greaterThan(10));
      expect(ValidationConstants.maxUsernameLength, lessThan(200));
    });

    test('review length constraints should be valid', () {
      expect(
        ValidationConstants.minReviewLength,
        lessThan(ValidationConstants.maxReviewLength),
      );
      expect(ValidationConstants.minReviewLength, greaterThan(0));
    });
  });

  group('CacheConstants', () {
    test('cache durations should be positive', () {
      expect(CacheConstants.restaurantCache.inMinutes, greaterThan(0));
      expect(CacheConstants.preferencesCache.inMinutes, greaterThan(0));
      expect(CacheConstants.locationCache.inMinutes, greaterThan(0));
    });

    test('location cache should be shorter than restaurant cache', () {
      expect(
        CacheConstants.locationCache.inMinutes,
        lessThan(CacheConstants.restaurantCache.inMinutes),
      );
    });

    test('maxCachedRestaurants should be reasonable', () {
      expect(CacheConstants.maxCachedRestaurants, greaterThan(10));
      expect(CacheConstants.maxCachedRestaurants, lessThan(1000));
    });
  });
}
