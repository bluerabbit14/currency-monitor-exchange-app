import 'dart:typed_data';

import 'package:currency/core/graphics/svg_path.dart';
import 'package:currency/features/auth/presentation/widgets/google_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSvgPath', () {
    Rect bounds(String d) => parseSvgPath(d).getBounds();

    test('absolute lines and close', () {
      expect(
        bounds('M10 10 L20 10 L20 30 Z'),
        const Rect.fromLTRB(10, 10, 20, 30),
      );
    });

    test('relative commands, H/V and implicit repeats', () {
      expect(
        bounds('m10 10 l10 0 v10 h-10 z'),
        const Rect.fromLTRB(10, 10, 20, 20),
      );
      expect(bounds('M0 0 H5 V7'), const Rect.fromLTRB(0, 0, 5, 7));
      // Pairs after M are implicit lineTo commands.
      expect(bounds('M0 0 10 0 10 10'), const Rect.fromLTRB(0, 0, 10, 10));
      // A relative curve ends at current point + its last pair.
      expect(bounds('M0 0c0 0 0 0 10 20').bottomRight, const Offset(10, 20));
    });

    test('numbers can be packed: signs and leading dots separate them', () {
      expect(bounds('M.5.5l-.5.5'), const Rect.fromLTRB(0, 0.5, 0.5, 1));
      expect(bounds('M1-2L3-4'), const Rect.fromLTRB(1, -4, 3, -2));
    });

    test('smooth curves reuse the mirrored control point', () {
      final path = parseSvgPath('M0 0C0 10 10 10 10 0S20 -10 20 0');
      expect(path.getBounds().right, 20);
      // The mirrored control point (10,-10) bends the second half upwards.
      expect(path.getBounds().top, lessThan(0));
    });

    test('unsupported commands and malformed data throw', () {
      expect(() => parseSvgPath('M0 0 A1 1 0 0 1 2 2'), throwsFormatException);
      expect(() => parseSvgPath('L1 1'), returnsNormally);
      expect(() => parseSvgPath('M0'), throwsFormatException);
      expect(() => parseSvgPath('5 5'), throwsFormatException);
    });
  });

  group('GoogleSignInButton', () {
    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onPressed,
      bool isLoading = false,
      double width = 360,
      double textScale = 1,
    }) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: GoogleSignInButton(
                  onPressed: onPressed,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the label and logo, and reports taps', (tester) async {
      var taps = 0;
      await pump(tester, onPressed: () => taps++);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      expect(taps, 1);
    });

    testWidgets('follows the guideline: white fill, grey border, dark label', (
      tester,
    ) async {
      await pump(tester, onPressed: () {});

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(GoogleSignInButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, const Color(0xFFFFFFFF));
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.color, const Color(0xFF747775));
      expect(
        tester.widget<Text>(find.text('Continue with Google')).style!.color,
        const Color(0xFF1F1F1F),
      );
    });

    testWidgets('disabled: faded and ignores taps', (tester) async {
      await pump(tester);

      final label = tester.widget<Text>(find.text('Continue with Google'));
      expect(label.style!.color!.a, lessThan(0.5));
      await tester.tap(find.text('Continue with Google'));
      // Nothing to assert on a null callback except that it does not throw.
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading: spinner instead of the logo, taps ignored', (
      tester,
    ) async {
      var taps = 0;
      await pump(tester, onPressed: () => taps++, isLoading: true);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(GoogleLogo), findsNothing);
      await tester.tap(find.text('Continue with Google'));
      expect(taps, 0);
    });

    for (final width in [200.0, 320.0, 800.0]) {
      testWidgets('never overflows at width $width with 2x text', (
        tester,
      ) async {
        await pump(tester, onPressed: () {}, width: width, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('exposes itself to screen readers as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, onPressed: () {});
      final node = tester.getSemantics(
        find.bySemanticsLabel('Continue with Google'),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('GoogleLogo', () {
    testWidgets(
      'paints the four Google colours where the official logo has them',
      (tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: const ColoredBox(
                  color: Color(0xFFFFFFFF),
                  child: GoogleLogo(size: 48),
                ),
              ),
            ),
          ),
        );

        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        late ByteData bytes;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          bytes = (await image.toByteData())!;
        });

        Color at(int x, int y) {
          final i = (y * 48 + x) * 4;
          return Color.fromARGB(
            bytes.getUint8(i + 3),
            bytes.getUint8(i),
            bytes.getUint8(i + 1),
            bytes.getUint8(i + 2),
          );
        }

        expect(
          at(24, 4),
          const Color(0xFFEA4335),
          reason: 'red, top of the ring',
        );
        expect(at(40, 24), const Color(0xFF4285F4), reason: 'blue, the bar');
        expect(at(4, 24), const Color(0xFFFBBC05), reason: 'yellow, left');
        expect(at(24, 45), const Color(0xFF34A853), reason: 'green, bottom');
        expect(
          at(16, 24),
          const Color(0xFFFFFFFF),
          reason: 'inside the G nothing is drawn',
        );
      },
    );
  });
}
