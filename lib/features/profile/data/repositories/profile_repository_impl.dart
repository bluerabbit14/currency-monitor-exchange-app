import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_data_source.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this.remote);

  final ProfileRemoteDataSource remote;

  @override
  Future<Either<Failure, UserProfile>> getProfile() =>
      guardApi(remote.getProfile);
}
