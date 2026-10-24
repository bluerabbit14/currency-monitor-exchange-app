import 'package:math_expressions/math_expressions.dart';

/// Keys of the calculator keypad, as the strings the keypad reports.
abstract final class Keys {
  static const clear = 'C';
  static const backspace = '⌫';
  static const percent = '%';
  static const divide = '÷';
  static const multiply = '×';
  static const minus = '−';
  static const plus = '+';
  static const triple = '000';
  static const point = '.';
  static const equals = '=';

  static const operators = [divide, multiply, minus, plus];
}

bool _isOperator(String ch) => Keys.operators.contains(ch);

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

/// The expression after [key] is pressed. [Keys.equals] is not handled here:
/// the caller replaces the expression with its result.
String applyKey(String expression, String key) {
  final last = expression.isEmpty ? '' : expression[expression.length - 1];
  switch (key) {
    case Keys.clear:
      return '';
    case Keys.backspace:
      return expression.isEmpty
          ? expression
          : expression.substring(0, expression.length - 1);
    case Keys.point:
      final number = _currentNumber(expression);
      if (number.contains('.')) return expression;
      if (last == '%') return expression;
      return last.isEmpty || _isOperator(last)
          ? '${expression}0.'
          : '$expression.';
    case Keys.triple:
      // Zeros on an empty or zero number would only add leading zeros.
      if (last.isEmpty || _isOperator(last) || last == '%') return expression;
      if (_currentNumber(expression) == '0') return expression;
      return '${expression}000';
    case Keys.percent:
      return last.isNotEmpty && _isDigit(last) ? '$expression%' : expression;
    case Keys.divide:
    case Keys.multiply:
    case Keys.minus:
    case Keys.plus:
      if (last.isEmpty) {
        // Only a minus can start an expression (a negative amount).
        return key == Keys.minus ? key : expression;
      }
      if (_isOperator(last)) {
        // A second operator replaces the first (a lone leading minus stays).
        final body = expression.substring(0, expression.length - 1);
        return body.isEmpty ? expression : '$body$key';
      }
      if (last == '.') return expression;
      return '$expression$key';
    default:
      // A digit.
      if (key.length != 1 || !_isDigit(key)) return expression;
      if (last == '%') return expression;
      if (_currentNumber(expression) == '0') {
        return '${expression.substring(0, expression.length - 1)}$key';
      }
      return '$expression$key';
  }
}

/// The number being typed: everything after the last operator.
String _currentNumber(String expression) {
  var i = expression.length;
  while (i > 0 && !_isOperator(expression[i - 1])) {
    i--;
  }
  return expression.substring(i);
}

/// The value of [expression], or null when it is empty, incomplete beyond a
/// trailing operator, or not a finite number (e.g. a division by zero).
double? evaluateExpression(String expression) {
  var text = expression;
  while (text.isNotEmpty &&
      (_isOperator(text[text.length - 1]) || text.endsWith('.'))) {
    text = text.substring(0, text.length - 1);
  }
  if (text.isEmpty) return null;
  text = text
      .replaceAll(Keys.multiply, '*')
      .replaceAll(Keys.divide, '/')
      .replaceAll(Keys.minus, '-')
      // `50%` is 50/100; the parser's own `%` would be a modulo.
      .replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)%'), (m) => '(${m[1]}/100)');
  try {
    final parsed = GrammarParser().parse(text);
    final value = RealEvaluator(ContextModel()).evaluate(parsed);
    final result = value.toDouble();
    return result.isFinite ? result : null;
  } catch (_) {
    return null;
  }
}

/// [value] as a plain typed number (no grouping), e.g. `1234.5`.
String plainNumber(double value) {
  var text = value.toStringAsFixed(6);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text.replaceFirst('-', Keys.minus);
}
