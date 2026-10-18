import 'package:dartz/dartz.dart';

import '../error/failures.dart';
import 'api_exception.dart';

/// Runs [action] and turns the network layer's exceptions into [Failure]s, so
/// every repository reports errors the same way.
Future<Either<Failure, T>> guardApi<T>(Future<T> Function() action) async {
  try {
    return Right(await action());
  } on NetworkException {
    return const Left(NetworkFailure());
  } on ApiException catch (e) {
    return Left(failureFromApi(e));
  } on FormatException {
    return const Left(ServerFailure('Unexpected response from server'));
  } catch (_) {
    return const Left(AuthFailure());
  }
}

/// Backend 4xx messages are written for end users ("Invalid or expired
/// OTP."), so they are shown as-is. 5xx details are not.
Failure failureFromApi(ApiException e) {
  if (e.statusCode == 429) {
    return ServerFailure(
      'Too many attempts. Please wait a moment and try again',
      statusCode: e.statusCode,
      code: e.code,
    );
  }
  if (e.statusCode >= 500) {
    return ServerFailure(
      e.statusCode == 503
          ? 'Service temporarily unavailable. Please try again shortly'
          : 'Something went wrong. Please try again',
      statusCode: e.statusCode,
      code: e.code,
    );
  }
  final message = e.statusCode == 400 && e.fieldErrors.isNotEmpty
      ? e.fieldErrors.values.first
      : e.message;
  return ServerFailure(message, statusCode: e.statusCode, code: e.code);
}
