import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class VerifyGoogleLink
    implements UseCase<SignInResult, VerifyGoogleLinkParams> {
  const VerifyGoogleLink(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, SignInResult>> call(VerifyGoogleLinkParams params) =>
      repository.verifyGoogleLink(linkToken: params.linkToken, otp: params.otp);
}

class VerifyGoogleLinkParams extends Equatable {
  const VerifyGoogleLinkParams({required this.linkToken, required this.otp});

  final String linkToken;
  final String otp;

  @override
  List<Object?> get props => [linkToken, otp];
}
