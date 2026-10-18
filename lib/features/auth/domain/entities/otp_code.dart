abstract final class OtpCode {
  static const int length = 6;

  static final RegExp _pattern = RegExp(r'^\d{6}$');

  static bool isValid(String code) => _pattern.hasMatch(code);
}
