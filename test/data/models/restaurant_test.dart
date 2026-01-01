import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/data/models/restaurant.dart';

void main() {
  group('Restaurant Model', () {
    group('fromFirestore', () {
      test('should create Restaurant from valid Firestore data', () {
        // Arrange
        const id = 'test-id-123';
        final data = {
          'name': 'Test Restaurant',
          'address': '123 Test Street',
          'coordinate': '3.1390, 101.6869',
          'phone': '+60123456789',
          'imageUrl': 'https://example.com/image.jpg',
          'rating': 4.5,
          'user_ratings_total': 150,
          'category': 'Malaysian Food',
          'price_level': '2',
          'is_open_now': true,
          'halal_status': 'certified',
          'certification_body': 'JAKIM',
          'is_google_place': false,
        };

        // Act
        final restaurant = Restaurant.fromFirestore(data, id);

        // Assert
        expect(restaurant.id, equals(id));
        expect(restaurant.name, equals('Test Restaurant'));
        expect(restaurant.address, equals('123 Test Street'));
        expect(restaurant.latitude, closeTo(3.1390, 0.0001));
        expect(restaurant.longitude, closeTo(101.6869, 0.0001));
        expect(restaurant.phone, equals('+60123456789'));
        expect(restaurant.rating, equals(4.5));
        expect(restaurant.userRatingsTotal, equals(150));
        expect(restaurant.category, equals('Malaysian Food'));
        expect(restaurant.halalStatus, equals('certified'));
        expect(restaurant.isCertified, isTrue);
        expect(restaurant.isGooglePlace, isFalse);
      });

      test('should handle missing optional fields gracefully', () {
        // Arrange
        const id = 'minimal-id';
        final data = {'name': 'Minimal Restaurant'};

        // Act
        final restaurant = Restaurant.fromFirestore(data, id);

        // Assert
        expect(restaurant.id, equals(id));
        expect(restaurant.name, equals('Minimal Restaurant'));
        expect(restaurant.address, isNull);
        expect(restaurant.latitude, isNull);
        expect(restaurant.longitude, isNull);
        expect(restaurant.rating, isNull);
        expect(restaurant.halalStatus, equals('community_verified'));
      });

      test('should handle null name with default value', () {
        // Arrange
        final data = <String, dynamic>{};

        // Act
        final restaurant = Restaurant.fromFirestore(data, 'id');

        // Assert
        expect(restaurant.name, equals('Unknown'));
      });

      test('should parse coordinates correctly', () {
        // Arrange
        final data = {
          'name': 'Test',
          'coordinate': '  3.1234 ,  101.5678  ', // with spaces
        };

        // Act
        final restaurant = Restaurant.fromFirestore(data, 'id');

        // Assert
        expect(restaurant.latitude, closeTo(3.1234, 0.0001));
        expect(restaurant.longitude, closeTo(101.5678, 0.0001));
      });

      test('should handle invalid coordinate format', () {
        // Arrange
        final data = {
          'name': 'Test',
          'coordinate': 'invalid-format',
        };

        // Act
        final restaurant = Restaurant.fromFirestore(data, 'id');

        // Assert
        expect(restaurant.latitude, isNull);
        expect(restaurant.longitude, isNull);
        expect(restaurant.coordinate, equals('invalid-format'));
      });
    });

    group('fromGooglePlaces', () {
      test('should create Restaurant from Google Places API response', () {
        // Arrange
        final data = {
          'place_id': 'google-place-123',
          'name': 'Google Restaurant',
          'vicinity': '456 Google Street',
          'geometry': {
            'location': {
              'lat': 3.1234,
              'lng': 101.5678,
            },
          },
          'rating': 4.2,
          'user_ratings_total': 500,
          'price_level': 3,
          'opening_hours': {'open_now': true},
          'photos': [
            {'photo_reference': 'abc123'},
          ],
        };

        // Act
        final restaurant = Restaurant.fromGooglePlaces(data);

        // Assert
        expect(restaurant.id, equals('google-place-123'));
        expect(restaurant.name, equals('Google Restaurant'));
        expect(restaurant.address, equals('456 Google Street'));
        expect(restaurant.latitude, equals(3.1234));
        expect(restaurant.longitude, equals(101.5678));
        expect(restaurant.rating, equals(4.2));
        expect(restaurant.isGooglePlace, isTrue);
        expect(restaurant.halalStatus, equals('unknown'));
      });
    });

    group('toFirestore', () {
      test('should convert Restaurant to Firestore map', () {
        // Arrange
        const restaurant = Restaurant(
          id: 'test-id',
          name: 'Test Restaurant',
          address: '123 Test St',
          rating: 4.5,
          halalStatus: 'certified',
        );

        // Act
        final map = restaurant.toFirestore();

        // Assert
        expect(map['name'], equals('Test Restaurant'));
        expect(map['address'], equals('123 Test St'));
        expect(map['rating'], equals(4.5));
        expect(map['halal_status'], equals('certified'));
        expect(map['updated_at'], isNotNull);
      });
    });

    group('copyWith', () {
      test('should create copy with modified fields', () {
        // Arrange
        const original = Restaurant(
          id: 'id',
          name: 'Original Name',
          rating: 4.0,
        );

        // Act
        final copy = original.copyWith(
          name: 'New Name',
          rating: 5.0,
        );

        // Assert
        expect(copy.id, equals('id')); // unchanged
        expect(copy.name, equals('New Name'));
        expect(copy.rating, equals(5.0));
      });
    });

    group('computed properties', () {
      test('isCertified should return true for certified status', () {
        const restaurant = Restaurant(
          id: 'id',
          name: 'Test',
          halalStatus: 'certified',
        );
        expect(restaurant.isCertified, isTrue);
        expect(restaurant.isCommunityVerified, isFalse);
      });

      test('isCommunityVerified should return true for community_verified status', () {
        const restaurant = Restaurant(
          id: 'id',
          name: 'Test',
          halalStatus: 'community_verified',
        );
        expect(restaurant.isCertified, isFalse);
        expect(restaurant.isCommunityVerified, isTrue);
      });

      test('formattedRating should format rating correctly', () {
        const restaurant = Restaurant(id: 'id', name: 'Test', rating: 4.567);
        expect(restaurant.formattedRating, equals('4.6'));
      });

      test('formattedRating should return N/A for null rating', () {
        const restaurant = Restaurant(id: 'id', name: 'Test');
        expect(restaurant.formattedRating, equals('N/A'));
      });

      test('formattedReviewCount should format thousands correctly', () {
        const restaurant = Restaurant(
          id: 'id',
          name: 'Test',
          userRatingsTotal: 1500,
        );
        expect(restaurant.formattedReviewCount, equals('1.5k reviews'));
      });

      test('formattedReviewCount should show exact count under 1000', () {
        const restaurant = Restaurant(
          id: 'id',
          name: 'Test',
          userRatingsTotal: 500,
        );
        expect(restaurant.formattedReviewCount, equals('500 reviews'));
      });
    });

    group('equality', () {
      test('two restaurants with same id should be equal', () {
        const restaurant1 = Restaurant(id: 'same-id', name: 'Name 1');
        const restaurant2 = Restaurant(id: 'same-id', name: 'Name 2');
        expect(restaurant1, equals(restaurant2));
      });

      test('two restaurants with different ids should not be equal', () {
        const restaurant1 = Restaurant(id: 'id-1', name: 'Same Name');
        const restaurant2 = Restaurant(id: 'id-2', name: 'Same Name');
        expect(restaurant1, isNot(equals(restaurant2)));
      });

      test('hashCode should be based on id', () {
        const restaurant1 = Restaurant(id: 'same-id', name: 'Name 1');
        const restaurant2 = Restaurant(id: 'same-id', name: 'Name 2');
        expect(restaurant1.hashCode, equals(restaurant2.hashCode));
      });
    });
  });
}
