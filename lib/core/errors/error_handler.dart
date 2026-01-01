import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_exceptions.dart';

/// Result wrapper for operations that can fail
///
/// Provides a type-safe way to handle success and failure cases
/// without throwing exceptions.
sealed class Result<T> {
  const Result();

  /// Returns true if the result is a success
  bool get isSuccess => this is Success<T>;

  /// Returns true if the result is a failure
  bool get isFailure => this is Failure<T>;

  /// Get the value if success, or null if failure
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };

  /// Get the error if failure, or null if success
  AppException? get errorOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final error) => error,
  };

  /// Execute callback based on result type
  R when<R>({
    required R Function(T value) success,
    required R Function(AppException error) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    Failure<T>(:final error) => failure(error),
  };

  /// Map the success value to a new type
  Result<R> map<R>(R Function(T value) mapper) => switch (this) {
    Success<T>(:final value) => Success(mapper(value)),
    Failure<T>(:final error) => Failure(error),
  };

  /// Flat map the success value to a new Result
  Result<R> flatMap<R>(Result<R> Function(T value) mapper) => switch (this) {
    Success<T>(:final value) => mapper(value),
    Failure<T>(:final error) => Failure(error),
  };
}

/// Success result containing a value
final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// Failure result containing an error
final class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}

/// Error handler utility class
class ErrorHandler {
  ErrorHandler._();

  /// Handle Firebase Auth exceptions
  static AuthException handleFirebaseAuth(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' => AuthException.userNotFound(),
      'wrong-password' => AuthException.invalidCredentials(),
      'invalid-email' => AuthException.invalidCredentials(),
      'email-already-in-use' => AuthException.emailInUse(),
      'weak-password' => AuthException.weakPassword(),
      'user-disabled' => const AuthException(
        message: 'This account has been disabled.',
        code: 'USER_DISABLED',
      ),
      'too-many-requests' => const AuthException(
        message: 'Too many attempts. Please try again later.',
        code: 'TOO_MANY_REQUESTS',
      ),
      _ => AuthException(
        message: e.message ?? 'Authentication error occurred.',
        code: e.code,
        originalError: e,
      ),
    };
  }

  /// Handle generic exceptions
  static AppException handleGeneric(dynamic error, [StackTrace? stackTrace]) {
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }

    if (error is AppException) return error;
    if (error is FirebaseAuthException) return handleFirebaseAuth(error);

    return NetworkException(
      message: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  /// Execute a function and wrap result
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Success(result);
    } on AppException catch (e) {
      return Failure(e);
    } on FirebaseAuthException catch (e) {
      return Failure(handleFirebaseAuth(e));
    } catch (e, stackTrace) {
      return Failure(handleGeneric(e, stackTrace));
    }
  }

  /// Execute a synchronous function and wrap result
  static Result<T> guardSync<T>(T Function() action) {
    try {
      final result = action();
      return Success(result);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e, stackTrace) {
      return Failure(handleGeneric(e, stackTrace));
    }
  }
}
