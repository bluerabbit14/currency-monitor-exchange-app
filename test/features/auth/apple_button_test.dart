import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_converter_repository.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() async {
    // The login globe animates forever; reduced motion lets pumpAndSettle end.
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await sl.reset();
    await init();
    await useFakeConverterRepository();
    await useFakeProfileRepository();
    await useFakeCurrencyRepository();
    auth = FakeAuthRepository();
  });

  Future<void> openLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = AuthSessionCubit(auth);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
  }

  testWidgets('the login sheet has the Apple button under Google', (
    tester,
  ) async {
    await openLogin(tester);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Continue with Apple')).dy,
      greaterThan(tester.getTopLeft(find.text('Continue with Google')).dy),
    );

    expect(find.byIcon(Icons.apple), findsOneWidget);
    expect(
      tester.getSize(find.byIcon(Icons.apple).hitTestable()).height,
      greaterThan(0),
    );
  });

  testWidgets('tapping it explains it is not available and signs nobody in', (
    tester,
  ) async {
    await openLogin(tester);

    await tester.tap(find.text('Continue with Apple'));
    await tester.pump();

    expect(find.text('Sign in with Apple is not available yet'), findsWidgets);
    expect(auth.sent, isEmpty);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets(
      "the Apple label is the same size as the Google label (text x$scale)",
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        final session = AuthSessionCubit(auth);
        await tester.pumpWidget(CurrencyApp(sessionCubit: session));
        await session.start();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();

        // The test font is fixed-width (1em per character), so width divided
        // by the character count is the rendered font size.
        final google = tester.getSize(find.text("Continue with Google")).width;
        final apple = tester.getSize(find.text("Continue with Apple")).width;
        expect(
          google / "Continue with Google".length,
          closeTo(16 * scale, 0.5),
        );
        expect(apple / "Continue with Apple".length, closeTo(16 * scale, 0.5));
      },
    );
  }

  for (final width in [320.0, 390.0, 800.0]) {
    testWidgets('the Apple button never overflows at width $width, 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      final session = AuthSessionCubit(auth);
      await tester.pumpWidget(CurrencyApp(sessionCubit: session));
      await session.start();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
