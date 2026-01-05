import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/data/models/calorie_entry.dart';

void main() {
  group('CalorieEntry Model', () {
    group('fromFirestore', () {
      test('should create CalorieEntry from valid Firestore data', () {
        // Arrange
        const id = 'entry-123';
        final data = {
          'userId': 'user-456',
          'foodName': 'Nasi Lemak',
          'calories': 650,
          'imageUrl': 'https://example.com/nasi-lemak.jpg',
          'timestamp': '2026-01-01T12:00:00.000Z',
          'mealType': 'lunch',
          'nutritionData': {'protein': 15, 'carbs': 80, 'fat': 25},
        };

        // Act
        final entry = CalorieEntry.fromFirestore(data, id);

        // Assert
        expect(entry.id, equals(id));
        expect(entry.userId, equals('user-456'));
        expect(entry.foodName, equals('Nasi Lemak'));
        expect(entry.calories, equals(650));
        expect(entry.imageUrl, equals('https://example.com/nasi-lemak.jpg'));
        expect(entry.mealType, equals('lunch'));
        expect(entry.nutritionData, isNotNull);
        expect(entry.nutritionData!['protein'], equals(15));
      });

      test('should handle missing optional fields', () {
        // Arrange
        final data = {'userId': 'user-123', 'calories': 200};

        // Act
        final entry = CalorieEntry.fromFirestore(data, 'id');

        // Assert
        expect(entry.foodName, equals('Unknown'));
        expect(entry.imageUrl, isNull);
        expect(entry.mealType, isNull);
        expect(entry.nutritionData, isNull);
      });

      test('should handle legacy name field', () {
        // Arrange
        final data = {
          'userId': 'user-123',
          'name': 'Legacy Name',
          'calories': 100,
        };

        // Act
        final entry = CalorieEntry.fromFirestore(data, 'id');

        // Assert
        expect(entry.foodName, equals('Legacy Name'));
      });

      test('should default calories to 0 if missing', () {
        // Arrange
        final data = {'userId': 'user-123', 'foodName': 'Test Food'};

        // Act
        final entry = CalorieEntry.fromFirestore(data, 'id');

        // Assert
        expect(entry.calories, equals(0));
      });
    });

    group('toFirestore', () {
      test('should convert CalorieEntry to Firestore map', () {
        // Arrange
        final entry = CalorieEntry(
          id: 'entry-id',
          userId: 'user-id',
          foodName: 'Test Food',
          calories: 500,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
          mealType: 'dinner',
        );

        // Act
        final map = entry.toFirestore();

        // Assert
        expect(map['userId'], equals('user-id'));
        expect(map['foodName'], equals('Test Food'));
        expect(map['calories'], equals(500));
        expect(map['mealType'], equals('dinner'));
        expect(map['timestamp'], contains('2026-01-01'));
      });
    });

    group('copyWith', () {
      test('should create copy with modified fields', () {
        // Arrange
        final original = CalorieEntry(
          id: 'id',
          userId: 'user',
          foodName: 'Original',
          calories: 100,
          timestamp: DateTime.now(),
        );

        // Act
        final copy = original.copyWith(foodName: 'Modified', calories: 200);

        // Assert
        expect(copy.id, equals('id')); // unchanged
        expect(copy.userId, equals('user')); // unchanged
        expect(copy.foodName, equals('Modified'));
        expect(copy.calories, equals(200));
      });
    });

    group('computed properties', () {
      test('formattedCalories should format correctly', () {
        final entry = CalorieEntry(
          id: 'id',
          userId: 'user',
          foodName: 'Test',
          calories: 350,
          timestamp: DateTime.now(),
        );
        expect(entry.formattedCalories, equals('350 kcal'));
      });

      test('dateOnly should strip time component', () {
        final entry = CalorieEntry(
          id: 'id',
          userId: 'user',
          foodName: 'Test',
          calories: 100,
          timestamp: DateTime(2026, 6, 15, 14, 30, 45),
        );
        expect(entry.dateOnly, equals(DateTime(2026, 6, 15)));
      });

      test('isToday should return true for today', () {
        final entry = CalorieEntry(
          id: 'id',
          userId: 'user',
          foodName: 'Test',
          calories: 100,
          timestamp: DateTime.now(),
        );
        expect(entry.isToday, isTrue);
      });

      test('isToday should return false for yesterday', () {
        final entry = CalorieEntry(
          id: 'id',
          userId: 'user',
          foodName: 'Test',
          calories: 100,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(entry.isToday, isFalse);
      });
    });

    group('equality', () {
      test('two entries with same id should be equal', () {
        final entry1 = CalorieEntry(
          id: 'same-id',
          userId: 'user1',
          foodName: 'Food 1',
          calories: 100,
          timestamp: DateTime.now(),
        );
        final entry2 = CalorieEntry(
          id: 'same-id',
          userId: 'user2',
          foodName: 'Food 2',
          calories: 200,
          timestamp: DateTime.now(),
        );
        expect(entry1, equals(entry2));
      });
    });
  });

  group('DailyCalorieSummary', () {
    final testDate = DateTime(2026, 1, 1);

    test('should calculate isOverLimit correctly', () {
      final summary = DailyCalorieSummary(
        date: testDate,
        totalCalories: 2500,
        limit: 2000,
        entries: [],
      );
      expect(summary.isOverLimit, isTrue);
    });

    test('should calculate remaining calories correctly', () {
      final summary = DailyCalorieSummary(
        date: testDate,
        totalCalories: 1500,
        limit: 2000,
        entries: [],
      );
      expect(summary.remaining, equals(500));
    });

    test('should calculate percentage used correctly', () {
      final summary = DailyCalorieSummary(
        date: testDate,
        totalCalories: 1000,
        limit: 2000,
        entries: [],
      );
      expect(summary.percentageUsed, equals(50.0));
    });

    test('formattedRemaining should show remaining when under limit', () {
      final summary = DailyCalorieSummary(
        date: testDate,
        totalCalories: 1800,
        limit: 2000,
        entries: [],
      );
      expect(summary.formattedRemaining, equals('200 kcal remaining'));
    });

    test('formattedRemaining should show over when exceeding limit', () {
      final summary = DailyCalorieSummary(
        date: testDate,
        totalCalories: 2300,
        limit: 2000,
        entries: [],
      );
      expect(summary.formattedRemaining, equals('300 kcal over limit'));
    });
  });
}
