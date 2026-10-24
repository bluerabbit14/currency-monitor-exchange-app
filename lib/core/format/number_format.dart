import 'package:intl/intl.dart';

/// Price text: up to 6 decimals, trailing zeros trimmed, but never fewer than 2
/// (`3.67`, `1.00`, `0.038306`).
String formatPrice(double value) {
  var text = value.toStringAsFixed(6);
  final dot = text.indexOf('.');
  while (text.endsWith('0') && text.length - dot - 1 > 2) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// Signed change text (`+0.000018`, `-0.000181`, `0.00`). A move too small to
/// show at 6 decimals counts as no change.
String formatChange(double value) {
  final magnitude = formatPrice(value.abs());
  if (magnitude == '0.00') return '0.00';
  return value > 0 ? '+$magnitude' : '-$magnitude';
}

/// Money text in [currencyCode], as people write it: a symbol or code, thousands
/// separators and a sensible number of decimals.
///
/// `formatMoney(3.67, 'USD')` is `$3.67`, `formatMoney(250000.5, 'AED')` is
/// `AED 250,000.50`, `formatMoney(0.038306, 'EUR')` is `€0.038306`.
///
/// Decimals depend on the size: 2 from 1,000 up, up to 4 from 1 up, up to 6
/// below 1 (a rate like 0.038306 would be useless rounded to 2). Trailing zeros
/// are trimmed but never below 2 decimals.
String formatMoney(double value, String currencyCode) {
  final negative = value < 0;
  final text = _moneyText(value.abs(), currencyCode);
  return negative ? '-$text' : text;
}

/// Signed change in [currencyCode] (`+$0.02`, `-AED 1.50`); a move too small
/// to show counts as no change (`$0.00`, no sign).
String formatMoneyChange(double value, String currencyCode) {
  final magnitude = _moneyText(value.abs(), currencyCode);
  if (formatPrice(value.abs()) == '0.00') {
    return _moneyText(0, currencyCode);
  }
  return value > 0 ? '+$magnitude' : '-$magnitude';
}

String _moneyText(double value, String currencyCode) {
  final code = currencyCode.toUpperCase();
  final maxDecimals = value >= 1000
      ? 2
      : value >= 1
      ? 4
      : 6;
  final number = NumberFormat.decimalPattern('en_US')
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = maxDecimals;
  final symbol = _symbols[code];
  // A well-known symbol sits against the number; any other currency is
  // written with its ISO code and a space (AED 3.67).
  return symbol != null
      ? '$symbol${number.format(value)}'
      : '$code ${number.format(value)}';
}

/// Symbols people know at a glance. Everything else uses its ISO code, since
/// local symbols ("dh", "Riyal") are ambiguous.
const _symbols = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'INR': '₹',
  'KRW': '₩',
  'RUB': '₽',
  'TRY': '₺',
  'ILS': '₪',
  'UAH': '₴',
  'NGN': '₦',
  'PHP': '₱',
  'VND': '₫',
  'THB': '฿',
};

/// A plain amount with thousands separators and no currency mark, as the
/// Converter rows show it (`1,234.5`, `0.038306`, `0`).
String formatAmount(double value) {
  final magnitude = value.abs();
  final maxDecimals = magnitude >= 1000
      ? 2
      : magnitude >= 1
      ? 4
      : 6;
  final number = NumberFormat.decimalPattern('en_US')
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDecimals;
  final text = number.format(value);
  return text == '-0' ? '0' : text;
}
