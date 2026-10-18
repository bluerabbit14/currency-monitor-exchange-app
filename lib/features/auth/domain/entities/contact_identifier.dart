import 'package:equatable/equatable.dart';

/// Where a one-time code is delivered.
///
/// The backend already accepts a single `contact` string and tells email from
/// phone (`+<E.164>`) itself, so adding mobile OTP later means adding a
/// `PhoneContact` subtype here and a phone field in the UI. Nothing in the
/// repository, use cases, cubits or data layer needs to change.
sealed class ContactIdentifier extends Equatable {
  const ContactIdentifier();

  /// Value sent to the backend as `contact`.
  String get value;

  @override
  List<Object?> get props => [value];
}

class EmailContact extends ContactIdentifier {
  const EmailContact._(this.value);

  @override
  final String value;

  // Mirrors the backend's ContactIdentifierService pattern, and additionally
  // requires a dot in the domain (an address like `a@b` cannot receive mail).
  static final RegExp _pattern = RegExp(
    r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
  );
  static const int _maxLength = 254;

  /// Returns null when [input] is not a valid email. Trims and lower-cases
  /// like the backend does, so the OTP is verified against the same value.
  static EmailContact? tryParse(String input) {
    final email = input.trim().toLowerCase();
    if (email.isEmpty || email.length > _maxLength) return null;
    return _pattern.hasMatch(email) ? EmailContact._(email) : null;
  }
}
