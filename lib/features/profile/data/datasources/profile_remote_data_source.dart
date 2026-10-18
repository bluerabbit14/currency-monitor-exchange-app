import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_profile.dart';
import '../models/user_profile_model.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource(this._client);

  /// The authenticated client: adds the bearer token, refreshes on 401.
  final ApiClient _client;

  Future<UserProfile> getProfile() async {
    final body = await _client.get('/api/v1/users/me');
    if (body == null) throw const FormatException('Empty response body');
    return UserProfileModel.fromJson(body);
  }
}
