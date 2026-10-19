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
