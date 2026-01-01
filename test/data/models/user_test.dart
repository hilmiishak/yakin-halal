import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/data/models/user.dart';

void main() {
  group('AppUser Model', () {
    group('fromFirestore', () {
      test('should create AppUser from valid Firestore data', () {
        // Arrange
        const uid = 'user-123';
        final data = {
          'email': 'test@example.com',
          'name': 'John Doe',
          'photoUrl': 'https://example.com/photo.jpg',
          'createdAt': '2025-01-01T00:00:00.000Z',
          'preferences': {
            'favoriteCuisines': ['Malaysian', 'Thai'],
            'halalCertifiedOnly': true,
            'maxDistanceKm': 15.0,
          },
          'calorieSettings': {
            'dailyLimit': 1800,
            'goal': 'lose',
          },
        };

        // Act
        final user = AppUser.fromFirestore(data, uid);

        // Assert
        expect(user.uid, equals(uid));
        expect(user.email, equals('test@example.com'));
        expect(user.displayName, equals('John Doe'));
        expect(user.photoUrl, equals('https://example.com/photo.jpg'));
        expect(user.preferences.favoriteCuisines, contains('Malaysian'));
        expect(user.preferences.halalCertifiedOnly, isTrue);
        expect(user.calorieSettings.dailyLimit, equals(1800));
        expect(user.calorieSettings.goal, equals('lose'));
      });

      test('should handle missing optional fields with defaults', () {
        // Arrange
        final data = <String, dynamic>{};

        // Act
        final user = AppUser.fromFirestore(data, 'uid');

        // Assert
        expect(user.email, isNull);
        expect(user.displayName, isNull);
        expect(user.preferences.favoriteCuisines, isEmpty);
        expect(user.preferences.halalCertifiedOnly, isFalse);
        expect(user.calorieSettings.dailyLimit, equals(2000));
      });

      test('should handle legacy displayName field', () {
        // Arrange
        final data = {
          'displayName': 'Legacy Name',
        };

        // Act
        final user = AppUser.fromFirestore(data, 'uid');

        // Assert
        expect(user.displayName, equals('Legacy Name'));
      });
    });

    group('toFirestore', () {
      test('should convert AppUser to Firestore map', () {
        // Arrange
        const user = AppUser(
          uid: 'uid',
          email: 'test@example.com',
          displayName: 'Test User',
          preferences: UserPreferences(
            favoriteCuisines: ['Chinese'],
            halalCertifiedOnly: true,
          ),
          calorieSettings: CalorieSettings(
            dailyLimit: 2200,
          ),
        );

        // Act
        final map = user.toFirestore();

        // Assert
        expect(map['email'], equals('test@example.com'));
        expect(map['name'], equals('Test User'));
        expect(map['preferences'], isA<Map>());
        expect(map['preferences']['favoriteCuisines'], contains('Chinese'));
        expect(map['calorieSettings']['dailyLimit'], equals(2200));
      });
    });

    group('greetingName', () {
      test('should return first name when displayName is set', () {
        const user = AppUser(
          uid: 'uid',
          displayName: 'John Doe Smith',
        );
        expect(user.greetingName, equals('John'));
      });

      test('should return email prefix when only email is set', () {
        const user = AppUser(
          uid: 'uid',
          email: 'johndoe@example.com',
        );
        expect(user.greetingName, equals('johndoe'));
      });

      test('should return "User" when nothing is set', () {
        const user = AppUser(uid: 'uid');
        expect(user.greetingName, equals('User'));
      });

      test('should prefer displayName over email', () {
        const user = AppUser(
          uid: 'uid',
          email: 'email@example.com',
          displayName: 'Preferred Name',
        );
        expect(user.greetingName, equals('Preferred'));
      });
    });

    group('copyWith', () {
      test('should create copy with modified fields', () {
        // Arrange
        const original = AppUser(
          uid: 'uid',
          email: 'original@test.com',
          displayName: 'Original Name',
        );

        // Act
        final copy = original.copyWith(
          displayName: 'New Name',
        );

        // Assert
        expect(copy.uid, equals('uid')); // unchanged
        expect(copy.email, equals('original@test.com')); // unchanged
        expect(copy.displayName, equals('New Name'));
      });
    });
  });

  group('UserPreferences', () {
    test('should create with default values', () {
      const prefs = UserPreferences();
      expect(prefs.favoriteCuisines, isEmpty);
      expect(prefs.dietaryRestrictions, isEmpty);
      expect(prefs.halalCertifiedOnly, isFalse);
      expect(prefs.maxDistanceKm, equals(10.0));
    });

    test('should parse from map correctly', () {
      final map = {
        'favoriteCuisines': ['Malaysian', 'Thai', 'Chinese'],
        'dietaryRestrictions': ['No Pork'],
        'halalCertifiedOnly': true,
        'maxDistanceKm': 25.0,
        'preferredPriceLevel': r'$$',
      };

      final prefs = UserPreferences.fromMap(map);

      expect(prefs.favoriteCuisines.length, equals(3));
      expect(prefs.dietaryRestrictions, contains('No Pork'));
      expect(prefs.halalCertifiedOnly, isTrue);
      expect(prefs.maxDistanceKm, equals(25.0));
      expect(prefs.preferredPriceLevel, equals(r'$$'));
    });

    test('copyWith should preserve unchanged values', () {
      const original = UserPreferences(
        favoriteCuisines: ['Malaysian'],
        maxDistanceKm: 15.0,
      );

      final copy = original.copyWith(maxDistanceKm: 20.0);

      expect(copy.favoriteCuisines, contains('Malaysian'));
      expect(copy.maxDistanceKm, equals(20.0));
    });
  });

  group('CalorieSettings', () {
    test('should create with default daily limit', () {
      const settings = CalorieSettings();
      expect(settings.dailyLimit, equals(2000));
    });

    test('should parse from map correctly', () {
      final map = {
        'dailyLimit': 1800,
        'tdee': 2200,
        'goal': 'lose',
        'age': 30,
        'heightCm': 175.0,
        'weightKg': 80.0,
        'gender': 'Male',
        'activityLevel': 'Moderate',
      };

      final settings = CalorieSettings.fromMap(map);

      expect(settings.dailyLimit, equals(1800));
      expect(settings.tdee, equals(2200));
      expect(settings.goal, equals('lose'));
      expect(settings.age, equals(30));
      expect(settings.heightCm, equals(175.0));
      expect(settings.weightKg, equals(80.0));
      expect(settings.gender, equals('Male'));
      expect(settings.activityLevel, equals('Moderate'));
    });

    test('toMap should include all fields', () {
      const settings = CalorieSettings(
        dailyLimit: 2500,
        goal: 'gain',
        age: 25,
      );

      final map = settings.toMap();

      expect(map['dailyLimit'], equals(2500));
      expect(map['goal'], equals('gain'));
      expect(map['age'], equals(25));
      expect(map.containsKey('tdee'), isTrue);
    });
  });
}
