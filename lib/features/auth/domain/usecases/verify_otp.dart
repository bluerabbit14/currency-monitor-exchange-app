import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_session.dart';
import '../entities/contact_identifier.dart';
import '../repositories/auth_repository.dart';

class VerifyOtp implements UseCase<SignInResult, VerifyOtpParams> {
  const VerifyOtp(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, SignInResult>> call(VerifyOtpParams params) =>
      repository.verifyOtp(params.contact, params.otp);
}

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.contact, required this.otp});

  final ContactIdentifier contact;
  final String otp;

  @override
  List<Object?> get props => [contact, otp];
}
