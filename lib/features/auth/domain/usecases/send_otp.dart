import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/contact_identifier.dart';
import '../entities/otp_challenge.dart';
import '../repositories/auth_repository.dart';

class SendOtp implements UseCase<OtpChallenge, ContactIdentifier> {
  const SendOtp(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, OtpChallenge>> call(ContactIdentifier params) =>
      repository.sendOtp(params);
}
