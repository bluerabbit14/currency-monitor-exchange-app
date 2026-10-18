import 'package:equatable/equatable.dart';

import 'contact_identifier.dart';

/// A code was sent to [contact] and stays valid for [expiresInSeconds].
class OtpChallenge extends Equatable {
  const OtpChallenge({required this.contact, required this.expiresInSeconds});

  final ContactIdentifier contact;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [contact, expiresInSeconds];
}
