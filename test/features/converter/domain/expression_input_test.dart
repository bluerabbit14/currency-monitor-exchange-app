import 'package:currency/features/converter/domain/expression_input.dart';
import 'package:flutter_test/flutter_test.dart';

String type(String keys) {
  var expression = '';
  for (final key in keys.split(' ')) {
    expression = applyKey(expression, key);
  }
  return expression;
}

void main() {
  group('applyKey', () {
    test('types digits and replaces a lone leading zero', () {
      expect(type('0 0 7'), '7');
      expect(type('1 2 3'), '123');
    });

    test('000 needs a number to extend', () {
      expect(type('000'), '');
      expect(type('0 000'), '0');
      expect(type('5 000'), '5000');
      expect(type('5 + 000'), '5+');
    });

    test('one decimal point per number', () {
      expect(type('. 5'), '0.5');
      expect(type('1 . 5 .'), '1.5');
      expect(type('1 . 5 + .'), '1.5+0.');
    });

    test('a second operator replaces the first', () {
      expect(type('5 + ×'), '5×');
      expect(type('+'), '');
      expect(type('− 5'), '−5');
      expect(type('− +'), '−');
    });

    test('percent only follows a digit', () {
      expect(type('%'), '');
      expect(type('5 %'), '5%');
      expect(type('5 % 3'), '5%');
    });

    test('backspace and clear', () {
      expect(type('1 2 ⌫'), '1');
      expect(type('⌫'), '');
      expect(type('1 2 C'), '');
    });
  });

  group('evaluateExpression', () {
    test('respects precedence', () {
      expect(evaluateExpression('12+3×2'), 18);
      expect(evaluateExpression('10−4÷2'), 8);
    });

    test('percent is a hundredth', () {
      expect(evaluateExpression('50%'), 0.5);
      expect(evaluateExpression('200×10%'), 20);
    });

    test('ignores a trailing operator or point', () {
      expect(evaluateExpression('5+'), 5);
      expect(evaluateExpression('5.'), 5);
    });

    test('is null when empty, invalid or not finite', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('+'), isNull);
      expect(evaluateExpression('5÷0'), isNull);
    });

    test('handles a negative amount', () {
      expect(evaluateExpression('−5+2'), -3);
    });
  });

  test('plainNumber trims zeros and uses the typed minus', () {
    expect(plainNumber(1234.5), '1234.5');
    expect(plainNumber(3), '3');
    expect(plainNumber(0.038306), '0.038306');
    expect(plainNumber(-2), '−2');
    expect(plainNumber(-0.0000001), '0');
  });
}
