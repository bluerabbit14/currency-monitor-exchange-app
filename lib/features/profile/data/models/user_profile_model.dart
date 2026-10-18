import '../../../currency/domain/entities/currency.dart';
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

    Currency? baseCurrency;
    final base = json['baseCurrency'];
    if (base is Map<String, dynamic>) {
      final id = base['id'];
      final code = base['symbol'];
      final name = base['name'];
      if (id is! String || code is! String || name is! String) {
        throw const FormatException('Malformed "baseCurrency"');
      }
      baseCurrency = Currency(id: id, code: code, name: name);
    }

    return UserProfile(
      displayName: text('displayName'),
      email: text('email'),
      phoneNumber: text('phoneNumber'),
      profileImageUrl: text('profileImageUrl'),
      baseCurrency: baseCurrency,
    );
  }
}
