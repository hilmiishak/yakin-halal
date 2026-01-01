import '../../core/errors/error_handler.dart';

/// Base repository interface
///
/// All repositories should implement this interface to ensure
/// consistent error handling and data access patterns.
abstract class BaseRepository<T> {
  /// Get a single item by ID
  Future<Result<T>> getById(String id);

  /// Get all items
  Future<Result<List<T>>> getAll();

  /// Create a new item
  Future<Result<T>> create(T item);

  /// Update an existing item
  Future<Result<T>> update(T item);

  /// Delete an item by ID
  Future<Result<void>> delete(String id);
}

/// Repository with pagination support
abstract class PaginatedRepository<T> extends BaseRepository<T> {
  /// Get items with pagination
  Future<Result<List<T>>> getPaginated({
    required int limit,
    String? startAfter,
  });
}

/// Repository with search support
abstract class SearchableRepository<T> extends BaseRepository<T> {
  /// Search items by query
  Future<Result<List<T>>> search(String query);
}
