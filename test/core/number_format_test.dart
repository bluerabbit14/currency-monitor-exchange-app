import 'package:currency/core/format/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatMoney puts the currency mark after a grouped number', () {
    test('known symbols', () {
      expect(formatMoney(3.67, 'USD'), '3.67 \$');
      expect(formatMoney(0.038306, 'EUR'), '0.038306 €');
      expect(formatMoney(1234567.891, 'INR'), '1,234,567.89 ₹');
    });

    test('other currencies use the ISO code', () {
      expect(formatMoney(250000.5, 'AED'), '250,000.50 AED');
      expect(formatMoney(65000, 'btc'), '65,000.00 BTC');
    });

    test('negative values keep the sign in front', () {
      expect(formatMoney(-1500.5, 'GBP'), '-1,500.50 £');
    });

    test('changes are signed and a nothing-move has no sign', () {
      expect(formatMoneyChange(0.02, 'USD'), '+0.02 \$');
      expect(formatMoneyChange(-1.5, 'AED'), '-1.50 AED');
      expect(formatMoneyChange(0.0000001, 'USD'), '0.00 \$');
    });
  });

  test('formatAmountWithSymbol and groupExpression', () {
    expect(formatAmountWithSymbol(1234.5, 'USD'), '1,234.5 \$');
    expect(groupExpression('1234+5678.5'), '1,234+5,678.5');
    expect(groupExpression('1234567.'), '1,234,567.');
  });
}
