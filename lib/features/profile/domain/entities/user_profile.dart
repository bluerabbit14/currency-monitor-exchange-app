import 'package:equatable/equatable.dart';

import '../../../currency/domain/entities/currency.dart';

class UserProfile extends Equatable {
  const UserProfile({
    this.displayName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.baseCurrency,
    this.notificationsEnabled,
  });

  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;

  /// The currency the user compares prices against; null until they pick one.
  final Currency? baseCurrency;

  /// Whether push notifications are allowed; null when the backend did not say.
  final bool? notificationsEnabled;

  /// The one contact line to show: the email when there is one, otherwise the
  /// phone number (never both).
  String? get contact => email ?? phoneNumber;

  UserProfile withBaseCurrency(Currency? currency) => UserProfile(
    displayName: displayName,
    email: email,
    phoneNumber: phoneNumber,
    profileImageUrl: profileImageUrl,
    baseCurrency: currency,
    notificationsEnabled: notificationsEnabled,
  );

  UserProfile withNotificationsEnabled(bool enabled) => UserProfile(
    displayName: displayName,
    email: email,
    phoneNumber: phoneNumber,
    profileImageUrl: profileImageUrl,
    baseCurrency: baseCurrency,
    notificationsEnabled: enabled,
  );

  @override
  List<Object?> get props => [
    displayName,
    email,
    phoneNumber,
    profileImageUrl,
    baseCurrency,
    notificationsEnabled,
  ];
}
