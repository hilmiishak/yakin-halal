import '../core/constants/app_constants.dart';

/// Generic cache entry with expiration
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  /// Check if the cache entry has expired
  bool get isExpired => DateTime.now().isAfter(cachedAt.add(ttl));

  /// Check if the cache entry is still valid
  bool get isValid => !isExpired;

  /// Get remaining time until expiration
  Duration get remainingTtl {
    final expiry = cachedAt.add(ttl);
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// In-memory cache service for temporary data storage
///
/// Provides a simple key-value cache with automatic expiration.
/// Useful for reducing API calls and improving performance.
class CacheService {
  final Map<String, CacheEntry<dynamic>> _cache = {};

  /// Maximum number of entries before cleanup
  final int maxEntries;

  CacheService({this.maxEntries = CacheConstants.maxCachedRestaurants});

  /// Store a value in the cache
  void put<T>(String key, T value, {Duration? ttl}) {
    // Clean up if we've exceeded max entries
    if (_cache.length >= maxEntries) {
      _cleanupExpired();
      if (_cache.length >= maxEntries) {
        _removeOldest();
      }
    }

    _cache[key] = CacheEntry<T>(
      data: value,
      cachedAt: DateTime.now(),
      ttl: ttl ?? CacheConstants.restaurantCache,
    );
  }

  /// Get a value from the cache
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// Get a value or compute it if not cached
  Future<T> getOrCompute<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    final cached = get<T>(key);
    if (cached != null) return cached;

    final value = await compute();
    put(key, value, ttl: ttl);
    return value;
  }

  /// Check if a key exists and is valid
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Remove a specific entry
  void remove(String key) {
    _cache.remove(key);
  }

  /// Remove all entries matching a prefix
  void removeByPrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cached data
  void clear() {
    _cache.clear();
  }

  /// Get the number of cached entries
  int get length => _cache.length;

  /// Get all valid keys
  List<String> get keys {
    _cleanupExpired();
    return _cache.keys.toList();
  }

  /// Remove all expired entries
  void _cleanupExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Remove the oldest entry
  void _removeOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.cachedAt;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// Get cache statistics
  CacheStats get stats {
    _cleanupExpired();
    return CacheStats(
      totalEntries: _cache.length,
      maxEntries: maxEntries,
      utilizationPercent: (_cache.length / maxEntries) * 100,
    );
  }
}

/// Cache statistics
class CacheStats {
  final int totalEntries;
  final int maxEntries;
  final double utilizationPercent;

  const CacheStats({
    required this.totalEntries,
    required this.maxEntries,
    required this.utilizationPercent,
  });

  @override
  String toString() =>
      'CacheStats(entries: $totalEntries/$maxEntries, utilization: ${utilizationPercent.toStringAsFixed(1)}%)';
}

/// Cache keys for consistent key generation
class CacheKeys {
  CacheKeys._();

  /// Restaurant cache key
  static String restaurant(String id) => 'restaurant:$id';

  /// Restaurant list cache key
  static String restaurantList(double lat, double lng, int radius) =>
      'restaurants:$lat,$lng,$radius';

  /// User preferences cache key
  static String userPreferences(String userId) => 'prefs:$userId';

  /// Search results cache key
  static String searchResults(String query) =>
      'search:${query.toLowerCase().trim()}';

  /// Location cache key
  static String location(String userId) => 'location:$userId';

  /// Calorie entries cache key
  static String calorieEntries(String userId, String date) =>
      'calories:$userId:$date';
}
