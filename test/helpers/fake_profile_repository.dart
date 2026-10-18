import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/profile/domain/repositories/profile_repository.dart';
import 'package:dartz/dartz.dart';

class FakeProfileRepository implements ProfileRepository {
  Either<Failure, UserProfile> result = const Right(
    UserProfile(email: 'me@example.com'),
  );
  int calls = 0;

  @override
  Future<Either<Failure, UserProfile>> getProfile() async {
    calls++;
    return result;
  }
}

/// Replaces the network-backed profile repository registered by `init()`.
Future<FakeProfileRepository> useFakeProfileRepository() async {
  final fake = FakeProfileRepository();
  await sl.unregister<ProfileRepository>();
  sl.registerLazySingleton<ProfileRepository>(() => fake);
  return fake;
}
