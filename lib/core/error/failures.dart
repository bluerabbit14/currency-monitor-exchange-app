import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign-in failed. Please try again']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Unable to reach the server. Check your connection',
  ]);
}

/// The backend answered with an error. [code] is the backend's error code
/// (e.g. `ACCOUNT_NOT_ACTIVE`) when it sent one.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, this.code});

  final int? statusCode;
  final String? code;

  @override
  List<Object?> get props => [message, statusCode, code];
}

/// Input rejected before (or by the backend instead of) a request.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class ConversionFailure extends Failure {
  const ConversionFailure([super.message = 'Unable to convert currency']);
}
