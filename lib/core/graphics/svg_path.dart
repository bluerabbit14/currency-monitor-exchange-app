import 'dart:ui';

/// Parses the `d` attribute of an SVG `<path>` into a Flutter [Path].
///
/// Supports the commands used by simple icons: M m L l H h V v C c S s Z z,
/// including implicit repeats (`c 1 2 3 4 5 6 7 8 9 10 11 12`). Arcs and
/// quadratic curves are not supported and throw a [FormatException].
Path parseSvgPath(String d) {
  final tokens = RegExp(
    r'([MmLlHhVvCcSsZz])|(-?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?)',
  ).allMatches(d).map((m) => m.group(0)!).toList();

  final path = Path();
  var i = 0;
  var x = 0.0, y = 0.0; // current point
  var startX = 0.0, startY = 0.0; // start of the current subpath
  var lastCx = 0.0, lastCy = 0.0; // last cubic control point (for S/s)
  var lastWasCubic = false;
  String? command;

  bool isCommand(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double num() {
    if (i >= tokens.length || isCommand(tokens[i])) {
      throw FormatException('Expected a number in path data near "$d"');
    }
    return double.parse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (isCommand(tokens[i])) command = tokens[i++];
    final c = command;
    if (c == null) throw FormatException('Path data must start with a command');

    final relative = c == c.toLowerCase();
    switch (c.toUpperCase()) {
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        lastWasCubic = false;
        // `z` takes no arguments: a number after it is malformed.
        command = null;
      case 'M':
        final nx = num() + (relative ? x : 0);
        final ny = num() + (relative ? y : 0);
        path.moveTo(nx, ny);
        x = startX = nx;
        y = startY = ny;
        lastWasCubic = false;
        // Further coordinate pairs after M are implicit lineTo commands.
        command = relative ? 'l' : 'L';
      case 'L':
        final nx = num() + (relative ? x : 0);
        final ny = num() + (relative ? y : 0);
        path.lineTo(nx, ny);
        x = nx;
        y = ny;
        lastWasCubic = false;
      case 'H':
        x = num() + (relative ? x : 0);
        path.lineTo(x, y);
        lastWasCubic = false;
      case 'V':
        y = num() + (relative ? y : 0);
        path.lineTo(x, y);
        lastWasCubic = false;
      case 'C':
        final x1 = num() + (relative ? x : 0);
        final y1 = num() + (relative ? y : 0);
        final x2 = num() + (relative ? x : 0);
        final y2 = num() + (relative ? y : 0);
        final nx = num() + (relative ? x : 0);
        final ny = num() + (relative ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lastCx = x2;
        lastCy = y2;
        x = nx;
        y = ny;
        lastWasCubic = true;
      case 'S':
        // The first control point mirrors the previous curve's second one.
        final x1 = lastWasCubic ? 2 * x - lastCx : x;
        final y1 = lastWasCubic ? 2 * y - lastCy : y;
        final x2 = num() + (relative ? x : 0);
        final y2 = num() + (relative ? y : 0);
        final nx = num() + (relative ? x : 0);
        final ny = num() + (relative ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lastCx = x2;
        lastCy = y2;
        x = nx;
        y = ny;
        lastWasCubic = true;
      default:
        throw FormatException('Unsupported path command "$c"');
    }
  }
  return path;
}
