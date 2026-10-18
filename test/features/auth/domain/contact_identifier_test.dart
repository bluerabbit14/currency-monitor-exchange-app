import 'package:currency/features/auth/domain/entities/contact_identifier.dart';
import 'package:currency/features/auth/domain/entities/otp_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmailContact.tryParse', () {
    test('trims and lower-cases like the backend', () {
      expect(EmailContact.tryParse('  Foo.Bar+x@Example.COM ')?.value, 'foo.bar+x@example.com');
    });

    test('accepts typical addresses', () {
      for (final e in ['a@b.co', 'first.last@mail.example.org', 'x_y-z@a-b.io']) {
        expect(EmailContact.tryParse(e), isNotNull, reason: e);
      }
    });

    test('rejects invalid input', () {
      for (final e in [
        '',
        '   ',
        'plain',
        'no-at.example.com',
        '@example.com',
        'a@',
        'a@b',
        'a@@b.com',
        'a b@c.com',
        'a@b..com',
        '+919876543210', // phone numbers are not supported yet
        '${'a' * 250}@b.com',
      ]) {
        expect(EmailContact.tryParse(e), isNull, reason: e);
      }
    });
  });

  test('OtpCode accepts exactly six digits', () {
    expect(OtpCode.isValid('123456'), isTrue);
    for (final c in ['', '12345', '1234567', '12345a', ' 12345', '１２３４５６']) {
      expect(OtpCode.isValid(c), isFalse, reason: c);
    }
  });
}
