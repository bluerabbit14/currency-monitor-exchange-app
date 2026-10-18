import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    this.displayName,
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
  });

  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;

  /// The one contact line to show: the email when there is one, otherwise the
  /// phone number (never both).
  String? get contact => email ?? phoneNumber;

  @override
  List<Object?> get props => [displayName, email, phoneNumber, profileImageUrl];
}
