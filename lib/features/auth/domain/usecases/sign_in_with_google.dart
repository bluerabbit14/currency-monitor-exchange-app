import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/google_sign_in_outcome.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle implements UseCase<GoogleSignInOutcome, NoParams> {
  const SignInWithGoogle(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, GoogleSignInOutcome>> call(NoParams params) =>
      repository.signInWithGoogle();
}
