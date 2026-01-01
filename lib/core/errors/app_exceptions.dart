/// Custom exception types for the application
///
/// These exceptions provide structured error handling throughout the app.
library;

/// Base exception class for all app exceptions
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Exception for network-related errors
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// No internet connection
  factory NetworkException.noConnection() => const NetworkException(
    message: 'No internet connection. Please check your network settings.',
    code: 'NO_CONNECTION',
  );

  /// Request timeout
  factory NetworkException.timeout() => const NetworkException(
    message: 'Request timed out. Please try again.',
    code: 'TIMEOUT',
  );

  /// Server error
  factory NetworkException.serverError([String? details]) => NetworkException(
    message: details ?? 'Server error occurred. Please try again later.',
    code: 'SERVER_ERROR',
  );
}

/// Exception for authentication errors
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Invalid credentials
  factory AuthException.invalidCredentials() => const AuthException(
    message: 'Invalid email or password.',
    code: 'INVALID_CREDENTIALS',
  );

  /// User not found
  factory AuthException.userNotFound() => const AuthException(
    message: 'No account found with this email.',
    code: 'USER_NOT_FOUND',
  );

  /// Email already in use
  factory AuthException.emailInUse() => const AuthException(
    message: 'An account already exists with this email.',
    code: 'EMAIL_IN_USE',
  );

  /// Weak password
  factory AuthException.weakPassword() => const AuthException(
    message: 'Password is too weak. Please use a stronger password.',
    code: 'WEAK_PASSWORD',
  );

  /// Email not verified
  factory AuthException.emailNotVerified() => const AuthException(
    message: 'Please verify your email before logging in.',
    code: 'EMAIL_NOT_VERIFIED',
  );

  /// Session expired
  factory AuthException.sessionExpired() => const AuthException(
    message: 'Your session has expired. Please log in again.',
    code: 'SESSION_EXPIRED',
  );
}

/// Exception for location-related errors
class LocationException extends AppException {
  const LocationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Location permission denied
  factory LocationException.permissionDenied() => const LocationException(
    message: 'Location permission denied. Please enable location access.',
    code: 'PERMISSION_DENIED',
  );

  /// Location services disabled
  factory LocationException.servicesDisabled() => const LocationException(
    message: 'Location services are disabled. Please enable them in settings.',
    code: 'SERVICES_DISABLED',
  );

  /// Failed to get location
  factory LocationException.failedToGet() => const LocationException(
    message: 'Failed to get your location. Please try again.',
    code: 'FAILED_TO_GET',
  );
}

/// Exception for API-related errors
class ApiException extends AppException {
  final int? statusCode;

  const ApiException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.statusCode,
  });

  /// Rate limit exceeded
  factory ApiException.rateLimited() => const ApiException(
    message: 'Too many requests. Please wait a moment and try again.',
    code: 'RATE_LIMITED',
    statusCode: 429,
  );

  /// Invalid API key
  factory ApiException.invalidApiKey() => const ApiException(
    message: 'API configuration error. Please contact support.',
    code: 'INVALID_API_KEY',
    statusCode: 401,
  );

  /// Resource not found
  factory ApiException.notFound([String? resource]) => ApiException(
    message: '${resource ?? 'Resource'} not found.',
    code: 'NOT_FOUND',
    statusCode: 404,
  );
}

/// Exception for validation errors
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.fieldErrors,
  });

  /// Invalid input
  factory ValidationException.invalidInput(String field, String reason) =>
      ValidationException(
        message: 'Invalid $field: $reason',
        code: 'INVALID_INPUT',
        fieldErrors: {field: reason},
      );

  /// Required field missing
  factory ValidationException.requiredField(String field) =>
      ValidationException(
        message: '$field is required.',
        code: 'REQUIRED_FIELD',
        fieldErrors: {field: 'This field is required'},
      );
}

/// Exception for cache-related errors
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Cache miss
  factory CacheException.notFound() => const CacheException(
    message: 'Data not found in cache.',
    code: 'CACHE_MISS',
  );

  /// Cache expired
  factory CacheException.expired() => const CacheException(
    message: 'Cached data has expired.',
    code: 'CACHE_EXPIRED',
  );
}
