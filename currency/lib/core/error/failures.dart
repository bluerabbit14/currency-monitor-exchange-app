import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ConversionFailure extends Failure {
  const ConversionFailure([super.message = 'Unable to convert currency']);
}
