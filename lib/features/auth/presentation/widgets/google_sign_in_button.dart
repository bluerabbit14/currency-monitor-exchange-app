import 'package:flutter/material.dart';

import '../../../../core/graphics/svg_path.dart';

/// "Continue with Google" button following Google's branding guidelines for the
/// light theme: white fill, 1px neutral border, the four-colour "G" and a dark
/// label. https://developers.google.com/identity/branding-guidelines
///
/// Pass `onPressed: null` to disable it. [isLoading] swaps the logo for a
/// spinner and ignores taps.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  /// Corner radius; fully rounded (pill) when null.
  final double? borderRadius;

  /// Label size shared with the Apple button so the two match.
  static const double labelFontSize = 16;

  // Google's published colours (light theme).
  static const _fill = Color(0xFFFFFFFF);
  static const _border = Color(0xFF747775);
  static const _text = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null || isLoading;
    // Disabled state per the guidelines: 38% fill, 12% border and text at 38%.
    final fill = enabled ? _fill : _fill.withValues(alpha: 0.38);
    final border = enabled
        ? _border
        : const Color(0xFF1F1F1F).withValues(alpha: 0.12);
    final text = enabled ? _text : _text.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // The visible children (logo, label, ink) are hidden from screen readers;
      // this node carries the label and the tap action instead.
      excludeSemantics: true,
      onTap: isLoading ? null : onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: fill,
          shape: borderRadius == null
              ? StadiumBorder(side: BorderSide(color: border))
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius!),
                  side: BorderSide(color: border),
                ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 22,
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Opacity(
                            opacity: enabled ? 1 : 0.38,
                            child: const GoogleLogo(size: 22),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w500,
                        color: text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The multicolour Google "G", drawn from Google's official SVG (48x48 box).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static final _paths = <(Color, Path)>[
    (
      const Color(0xFFEA4335),
      parseSvgPath(
        'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
        '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
      ),
    ),
    (
      const Color(0xFF4285F4),
      parseSvgPath(
        'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
        '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
      ),
    ),
    (
      const Color(0xFFFBBC05),
      parseSvgPath(
        'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
        'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
      ),
    ),
    (
      const Color(0xFF34A853),
      parseSvgPath(
        'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
        '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
      ),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    for (final (color, path) in _paths) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
