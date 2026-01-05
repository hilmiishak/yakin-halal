import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/utils/distance_utils.dart';

void main() {
  group('DistanceUtils', () {
    group('toRadians', () {
      test('should convert 0 degrees to 0 radians', () {
        expect(DistanceUtils.toRadians(0), equals(0));
      });

      test('should convert 90 degrees to pi/2 radians', () {
        expect(DistanceUtils.toRadians(90), closeTo(1.5708, 0.0001));
      });

      test('should convert 180 degrees to pi radians', () {
        expect(DistanceUtils.toRadians(180), closeTo(3.1416, 0.0001));
      });

      test('should convert 360 degrees to 2*pi radians', () {
        expect(DistanceUtils.toRadians(360), closeTo(6.2832, 0.0001));
      });

      test('should handle negative degrees', () {
        expect(DistanceUtils.toRadians(-90), closeTo(-1.5708, 0.0001));
      });
    });

    group('calculateHaversineDistance', () {
      test('should return 0 for same coordinates', () {
        final distance = DistanceUtils.calculateHaversineDistance(
          3.1390,
          101.6869,
          3.1390,
          101.6869,
        );
        expect(distance, equals(0));
      });

      test(
        'should calculate correct distance between Kuala Lumpur and Penang',
        () {
          // KL: 3.1390, 101.6869
          // Penang: 5.4164, 100.3327
          // Expected distance: approximately 280-300 km
          final distance = DistanceUtils.calculateHaversineDistance(
            3.1390,
            101.6869,
            5.4164,
            100.3327,
          );
          expect(distance, greaterThan(270));
          expect(distance, lessThan(310));
        },
      );

      test('should calculate correct distance between nearby points', () {
        // Two points ~1km apart in KL
        final distance = DistanceUtils.calculateHaversineDistance(
          3.1390,
          101.6869,
          3.1480,
          101.6869, // ~1km north
        );
        expect(distance, closeTo(1.0, 0.1));
      });

      test('should return large distance for invalid coordinates (0, 0)', () {
        final distance = DistanceUtils.calculateHaversineDistance(
          0,
          0,
          3.1390,
          101.6869,
        );
        expect(distance, equals(99999.0));
      });

      test('should return large distance when second coordinate is (0, 0)', () {
        final distance = DistanceUtils.calculateHaversineDistance(
          3.1390,
          101.6869,
          0,
          0,
        );
        expect(distance, equals(99999.0));
      });

      test('should handle antipodal points (maximum distance)', () {
        // Two points on opposite sides of Earth
        // Using (0,0) would trigger the invalid coordinate check
        // Let's use non-zero coordinates for valid test
        final validDistance = DistanceUtils.calculateHaversineDistance(
          1,
          1,
          -1,
          -179,
        );
        // Maximum Earth diameter is about 20,000 km
        expect(validDistance, greaterThan(19000));
        expect(validDistance, lessThan(21000));
      });

      test('should handle crossing the equator', () {
        final distance = DistanceUtils.calculateHaversineDistance(
          1.0,
          100.0, // North of equator
          -1.0,
          100.0, // South of equator
        );
        // About 222 km
        expect(distance, closeTo(222, 10));
      });

      test('should handle crossing the prime meridian', () {
        final distance = DistanceUtils.calculateHaversineDistance(
          51.5074,
          -0.1, // West of prime meridian (London)
          51.5074,
          0.1, // East of prime meridian
        );
        // About 14 km
        expect(distance, closeTo(14, 2));
      });
    });

    group('formatDistance', () {
      test('should format distance in meters when less than 1 km', () {
        expect(DistanceUtils.formatDistance(0.5), equals('500 m'));
      });

      test('should format distance in km when 1 km or more', () {
        expect(DistanceUtils.formatDistance(1.0), equals('1.0 km'));
      });

      test('should format decimal km correctly', () {
        expect(DistanceUtils.formatDistance(2.5), equals('2.5 km'));
      });

      test('should round meters to nearest integer', () {
        expect(DistanceUtils.formatDistance(0.123), equals('123 m'));
      });

      test('should round km to one decimal place', () {
        expect(DistanceUtils.formatDistance(5.678), equals('5.7 km'));
      });

      test('should handle very small distances', () {
        expect(DistanceUtils.formatDistance(0.001), equals('1 m'));
      });

      test('should handle very large distances', () {
        expect(DistanceUtils.formatDistance(100.0), equals('100.0 km'));
      });

      test('should handle exactly 1 km', () {
        expect(DistanceUtils.formatDistance(1.0), equals('1.0 km'));
      });

      test('should handle 0.999 km as meters', () {
        expect(DistanceUtils.formatDistance(0.999), equals('999 m'));
      });
    });
  });
}
