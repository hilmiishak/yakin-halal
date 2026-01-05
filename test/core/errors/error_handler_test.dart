import 'package:flutter_test/flutter_test.dart';
import 'package:projekfyp/core/errors/app_exceptions.dart';
import 'package:projekfyp/core/errors/error_handler.dart';

void main() {
  group('AppExceptions', () {
    group('NetworkException', () {
      test('noConnection factory should create correct exception', () {
        final exception = NetworkException.noConnection();
        expect(exception.code, equals('NO_CONNECTION'));
        expect(exception.message, contains('internet connection'));
      });

      test('timeout factory should create correct exception', () {
        final exception = NetworkException.timeout();
        expect(exception.code, equals('TIMEOUT'));
        expect(exception.message, contains('timed out'));
      });

      test('serverError factory should create correct exception', () {
        final exception = NetworkException.serverError();
        expect(exception.code, equals('SERVER_ERROR'));
      });

      test('serverError with details should include details', () {
        final exception = NetworkException.serverError('Custom error');
        expect(exception.message, equals('Custom error'));
      });
    });

    group('AuthException', () {
      test('invalidCredentials factory should create correct exception', () {
        final exception = AuthException.invalidCredentials();
        expect(exception.code, equals('INVALID_CREDENTIALS'));
        expect(exception.message, contains('Invalid'));
      });

      test('userNotFound factory should create correct exception', () {
        final exception = AuthException.userNotFound();
        expect(exception.code, equals('USER_NOT_FOUND'));
      });

      test('emailInUse factory should create correct exception', () {
        final exception = AuthException.emailInUse();
        expect(exception.code, equals('EMAIL_IN_USE'));
      });

      test('weakPassword factory should create correct exception', () {
        final exception = AuthException.weakPassword();
        expect(exception.code, equals('WEAK_PASSWORD'));
      });

      test('emailNotVerified factory should create correct exception', () {
        final exception = AuthException.emailNotVerified();
        expect(exception.code, equals('EMAIL_NOT_VERIFIED'));
      });

      test('sessionExpired factory should create correct exception', () {
        final exception = AuthException.sessionExpired();
        expect(exception.code, equals('SESSION_EXPIRED'));
      });
    });

    group('LocationException', () {
      test('permissionDenied factory should create correct exception', () {
        final exception = LocationException.permissionDenied();
        expect(exception.code, equals('PERMISSION_DENIED'));
        expect(exception.message, contains('permission'));
      });

      test('servicesDisabled factory should create correct exception', () {
        final exception = LocationException.servicesDisabled();
        expect(exception.code, equals('SERVICES_DISABLED'));
      });

      test('failedToGet factory should create correct exception', () {
        final exception = LocationException.failedToGet();
        expect(exception.code, equals('FAILED_TO_GET'));
      });
    });

    group('ApiException', () {
      test('rateLimited factory should have correct status code', () {
        final exception = ApiException.rateLimited();
        expect(exception.code, equals('RATE_LIMITED'));
        expect(exception.statusCode, equals(429));
      });

      test('invalidApiKey factory should have correct status code', () {
        final exception = ApiException.invalidApiKey();
        expect(exception.code, equals('INVALID_API_KEY'));
        expect(exception.statusCode, equals(401));
      });

      test('notFound factory should have correct status code', () {
        final exception = ApiException.notFound();
        expect(exception.code, equals('NOT_FOUND'));
        expect(exception.statusCode, equals(404));
      });

      test('notFound with resource should include resource name', () {
        final exception = ApiException.notFound('Restaurant');
        expect(exception.message, contains('Restaurant'));
      });
    });

    group('ValidationException', () {
      test('invalidInput should include field name', () {
        final exception = ValidationException.invalidInput(
          'email',
          'must be valid',
        );
        expect(exception.code, equals('INVALID_INPUT'));
        expect(exception.message, contains('email'));
        expect(exception.fieldErrors, isNotNull);
        expect(exception.fieldErrors!['email'], equals('must be valid'));
      });

      test('requiredField should create correct exception', () {
        final exception = ValidationException.requiredField('name');
        expect(exception.code, equals('REQUIRED_FIELD'));
        expect(exception.message, contains('name'));
      });
    });

    group('CacheException', () {
      test('notFound factory should create correct exception', () {
        final exception = CacheException.notFound();
        expect(exception.code, equals('CACHE_MISS'));
      });

      test('expired factory should create correct exception', () {
        final exception = CacheException.expired();
        expect(exception.code, equals('CACHE_EXPIRED'));
      });
    });
  });

  group('Result', () {
    group('Success', () {
      test('should have isSuccess true', () {
        const result = Success(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('valueOrNull should return value', () {
        const result = Success('hello');
        expect(result.valueOrNull, equals('hello'));
      });

      test('errorOrNull should return null', () {
        const result = Success(42);
        expect(result.errorOrNull, isNull);
      });

      test('when should call success callback', () {
        const result = Success(42);
        final output = result.when(
          success: (value) => 'Value is $value',
          failure: (error) => 'Error',
        );
        expect(output, equals('Value is 42'));
      });

      test('map should transform value', () {
        const result = Success(10);
        final mapped = result.map((value) => value * 2);
        expect(mapped.valueOrNull, equals(20));
      });

      test('flatMap should chain results', () {
        const result = Success(10);
        final chained = result.flatMap((value) => Success(value.toString()));
        expect(chained.valueOrNull, equals('10'));
      });
    });

    group('Failure', () {
      test('should have isFailure true', () {
        final result = Failure<int>(NetworkException.noConnection());
        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
      });

      test('valueOrNull should return null', () {
        final result = Failure<String>(NetworkException.timeout());
        expect(result.valueOrNull, isNull);
      });

      test('errorOrNull should return error', () {
        final error = AuthException.invalidCredentials();
        final result = Failure<int>(error);
        expect(result.errorOrNull, equals(error));
      });

      test('when should call failure callback', () {
        final result = Failure<int>(NetworkException.timeout());
        final output = result.when(
          success: (value) => 'Value is $value',
          failure: (error) => 'Error: ${error.code}',
        );
        expect(output, equals('Error: TIMEOUT'));
      });

      test('map should preserve failure', () {
        final result = Failure<int>(NetworkException.noConnection());
        final mapped = result.map((value) => value * 2);
        expect(mapped.isFailure, isTrue);
        expect(mapped.errorOrNull?.code, equals('NO_CONNECTION'));
      });

      test('flatMap should preserve failure', () {
        final result = Failure<int>(NetworkException.timeout());
        final chained = result.flatMap((value) => Success(value.toString()));
        expect(chained.isFailure, isTrue);
      });
    });
  });

  group('ErrorHandler', () {
    group('guard', () {
      test('should return Success for successful async operation', () async {
        final result = await ErrorHandler.guard(() async => 42);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals(42));
      });

      test('should return Failure for AppException', () async {
        final result = await ErrorHandler.guard<int>(() async {
          throw NetworkException.timeout();
        });
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.code, equals('TIMEOUT'));
      });

      test('should wrap generic exceptions', () async {
        final result = await ErrorHandler.guard<int>(() async {
          throw Exception('Generic error');
        });
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, isA<NetworkException>());
      });
    });

    group('guardSync', () {
      test('should return Success for successful sync operation', () {
        final result = ErrorHandler.guardSync(() => 42);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, equals(42));
      });

      test('should return Failure for thrown exception', () {
        final result = ErrorHandler.guardSync<int>(() {
          throw ValidationException.requiredField('test');
        });
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.code, equals('REQUIRED_FIELD'));
      });
    });

    group('handleGeneric', () {
      test('should return AppException as-is', () {
        final original = AuthException.userNotFound();
        final handled = ErrorHandler.handleGeneric(original);
        expect(handled, equals(original));
      });

      test('should wrap unknown errors in NetworkException', () {
        final handled = ErrorHandler.handleGeneric('Some string error');
        expect(handled, isA<NetworkException>());
      });
    });
  });
}
