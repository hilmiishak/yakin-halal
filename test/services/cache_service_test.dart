import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/services/cache_service.dart';

void main() {
  group('CacheEntry', () {
    test('should be valid when not expired', () {
      final entry = CacheEntry(
        data: 'test',
        cachedAt: DateTime.now(),
        ttl: const Duration(hours: 1),
      );

      expect(entry.isValid, isTrue);
      expect(entry.isExpired, isFalse);
    });

    test('should be expired after TTL', () {
      final entry = CacheEntry(
        data: 'test',
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ttl: const Duration(hours: 1),
      );

      expect(entry.isExpired, isTrue);
      expect(entry.isValid, isFalse);
    });

    test('remainingTtl should decrease over time', () {
      final entry = CacheEntry(
        data: 'test',
        cachedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ttl: const Duration(hours: 1),
      );

      expect(entry.remainingTtl.inMinutes, closeTo(30, 1));
    });

    test('remainingTtl should be zero when expired', () {
      final entry = CacheEntry(
        data: 'test',
        cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ttl: const Duration(hours: 1),
      );

      expect(entry.remainingTtl, equals(Duration.zero));
    });
  });

  group('CacheService', () {
    late CacheService cache;

    setUp(() {
      cache = CacheService(maxEntries: 10);
    });

    group('put and get', () {
      test('should store and retrieve values', () {
        cache.put('key1', 'value1');
        expect(cache.get<String>('key1'), equals('value1'));
      });

      test('should store different types', () {
        cache.put('string', 'hello');
        cache.put('int', 42);
        cache.put('list', [1, 2, 3]);
        cache.put('map', {'a': 1, 'b': 2});

        expect(cache.get<String>('string'), equals('hello'));
        expect(cache.get<int>('int'), equals(42));
        expect(cache.get<List<int>>('list'), equals([1, 2, 3]));
        expect(cache.get<Map<String, int>>('map'), equals({'a': 1, 'b': 2}));
      });

      test('should return null for non-existent key', () {
        expect(cache.get<String>('nonexistent'), isNull);
      });

      test('should return null for expired entries', () {
        cache.put(
          'expired',
          'value',
          ttl: const Duration(milliseconds: 1),
        );

        // Wait for expiration
        Future.delayed(const Duration(milliseconds: 10), () {
          expect(cache.get<String>('expired'), isNull);
        });
      });

      test('should overwrite existing values', () {
        cache.put('key', 'original');
        cache.put('key', 'updated');

        expect(cache.get<String>('key'), equals('updated'));
      });
    });

    group('has', () {
      test('should return true for existing valid entries', () {
        cache.put('key', 'value');
        expect(cache.has('key'), isTrue);
      });

      test('should return false for non-existent entries', () {
        expect(cache.has('nonexistent'), isFalse);
      });
    });

    group('remove', () {
      test('should remove specific entry', () {
        cache.put('key1', 'value1');
        cache.put('key2', 'value2');

        cache.remove('key1');

        expect(cache.has('key1'), isFalse);
        expect(cache.has('key2'), isTrue);
      });
    });

    group('removeByPrefix', () {
      test('should remove all entries with matching prefix', () {
        cache.put('user:1', 'data1');
        cache.put('user:2', 'data2');
        cache.put('restaurant:1', 'data3');

        cache.removeByPrefix('user:');

        expect(cache.has('user:1'), isFalse);
        expect(cache.has('user:2'), isFalse);
        expect(cache.has('restaurant:1'), isTrue);
      });
    });

    group('clear', () {
      test('should remove all entries', () {
        cache.put('key1', 'value1');
        cache.put('key2', 'value2');

        cache.clear();

        expect(cache.length, equals(0));
      });
    });

    group('length and keys', () {
      test('should return correct count', () {
        cache.put('key1', 'value1');
        cache.put('key2', 'value2');
        cache.put('key3', 'value3');

        expect(cache.length, equals(3));
      });

      test('should return all valid keys', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);

        final keys = cache.keys;

        expect(keys, containsAll(['a', 'b', 'c']));
      });
    });

    group('max entries', () {
      test('should respect max entries limit', () {
        final smallCache = CacheService(maxEntries: 3);

        smallCache.put('key1', 'value1');
        smallCache.put('key2', 'value2');
        smallCache.put('key3', 'value3');
        smallCache.put('key4', 'value4'); // Should trigger cleanup

        expect(smallCache.length, lessThanOrEqualTo(3));
      });
    });

    group('getOrCompute', () {
      test('should return cached value if exists', () async {
        cache.put('key', 'cached');

        var computeCalled = false;
        final result = await cache.getOrCompute('key', () async {
          computeCalled = true;
          return 'computed';
        });

        expect(result, equals('cached'));
        expect(computeCalled, isFalse);
      });

      test('should compute and cache if not exists', () async {
        var computeCount = 0;
        final result1 = await cache.getOrCompute('key', () async {
          computeCount++;
          return 'computed';
        });

        final result2 = await cache.getOrCompute('key', () async {
          computeCount++;
          return 'computed again';
        });

        expect(result1, equals('computed'));
        expect(result2, equals('computed'));
        expect(computeCount, equals(1)); // Only computed once
      });
    });

    group('stats', () {
      test('should return accurate statistics', () {
        cache.put('key1', 'value1');
        cache.put('key2', 'value2');
        cache.put('key3', 'value3');

        final stats = cache.stats;

        expect(stats.totalEntries, equals(3));
        expect(stats.maxEntries, equals(10));
        expect(stats.utilizationPercent, equals(30.0));
      });

      test('toString should format correctly', () {
        cache.put('key1', 'value1');
        cache.put('key2', 'value2');

        final statsString = cache.stats.toString();

        expect(statsString, contains('2/10'));
        expect(statsString, contains('20.0%'));
      });
    });
  });

  group('CacheKeys', () {
    test('restaurant key should include id', () {
      final key = CacheKeys.restaurant('abc123');
      expect(key, equals('restaurant:abc123'));
    });

    test('restaurantList key should include coordinates', () {
      final key = CacheKeys.restaurantList(3.14, 101.69, 5000);
      expect(key, contains('3.14'));
      expect(key, contains('101.69'));
      expect(key, contains('5000'));
    });

    test('userPreferences key should include userId', () {
      final key = CacheKeys.userPreferences('user123');
      expect(key, equals('prefs:user123'));
    });

    test('searchResults key should normalize query', () {
      final key1 = CacheKeys.searchResults('  NASI LEMAK  ');
      final key2 = CacheKeys.searchResults('nasi lemak');
      expect(key1, equals(key2));
    });

    test('calorieEntries key should include userId and date', () {
      final key = CacheKeys.calorieEntries('user123', '2026-01-01');
      expect(key, equals('calories:user123:2026-01-01'));
    });
  });
}
