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

class ConversionFailure extends Failure {
  const ConversionFailure([super.message = 'Unable to convert currency']);
}
