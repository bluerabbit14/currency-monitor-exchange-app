import '../../domain/entities/user_profile.dart';

/// Body of `GET /api/v1/users/me`. Only the fields the app shows are read;
/// plan, features and the rest are ignored for now.
class UserProfileModel {
  static UserProfile fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw FormatException('Malformed "$key"');
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return UserProfile(
      displayName: text('displayName'),
      email: text('email'),
      phoneNumber: text('phoneNumber'),
      profileImageUrl: text('profileImageUrl'),
    );
  }
}
