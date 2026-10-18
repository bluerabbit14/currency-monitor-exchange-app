import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:currency/features/auth/domain/repositories/auth_repository.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/shell/presentation/widgets/floating_nav_bar.dart';
import 'package:currency/features/auth/presentation/pages/login_page.dart';
import 'package:currency/features/auth/presentation/pages/otp_page.dart';
import 'package:currency/features/shell/presentation/pages/home_shell_page.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/fake_profile_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late AuthSessionCubit session;

  setUp(() async {
    await sl.reset();
    await init();
    await useFakeProfileRepository();
    repo = FakeAuthRepository();
    // Swap the real network/storage-backed repository for the fake. Everything
    // above it (use cases, cubits, pages) is the real wiring.
    await sl.unregister<AuthRepository>();
    sl.registerLazySingleton<AuthRepository>(() => repo);
  });

  Future<void> pumpApp(WidgetTester tester, {bool signedIn = false}) async {
    if (signedIn) repo.restored = fakeSession;
    session = AuthSessionCubit(repo);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    await session.start();
    await tester.pump();
  }

  Future<void> enterEmailAndContinue(WidgetTester tester, String email) async {
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump(); // loading
    await tester.pump(); // result
    await tester.pumpAndSettle();
  }

  testWidgets('splash, then login when signed out', (tester) async {
    session = AuthSessionCubit(repo);
    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await session.start();
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('a stored session opens the home screen directly', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true);
    expect(find.byType(HomeShellPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('invalid email shows an inline error and sends nothing', (
    tester,
  ) async {
    await pumpApp(tester);

    await enterEmailAndContinue(tester, 'not-an-email');

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(repo.sent, isEmpty);
    expect(find.byType(OtpPage), findsNothing);
  });

  testWidgets('email OTP: send, wrong code, then success routes home', (
    tester,
  ) async {
    await pumpApp(tester);
    var attempts = 0;
    repo.onVerify = (c, otp) async {
      attempts++;
      if (otp != '123456') {
        return const Left(ServerFailure('Invalid or expired OTP.'));
      }
      repo.sessions.add(fakeSession); // the repository stores + announces it
      return Right(fakeSignIn);
    };

    await enterEmailAndContinue(tester, ' Me@Example.com ');
    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Invalid or expired OTP.'), findsOneWidget);
    expect(find.byType(OtpPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(HomeShellPage), findsOneWidget);
    expect(find.byType(OtpPage), findsNothing);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('OTP page: resend is disabled during the cooldown', (
    tester,
  ) async {
    await pumpApp(tester);
    await enterEmailAndContinue(tester, 'a@b.co');

    expect(find.textContaining('Resend code in'), findsOneWidget);
    await tester.tap(
      find.textContaining('Resend code in'),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repo.sent, hasLength(1)); // only the original send

    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Resend code'), findsOneWidget);
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(repo.sent, hasLength(2));
    expect(find.text('A new code has been sent'), findsOneWidget);
  });

  testWidgets('send failure keeps the user on the login page with a message', (
    tester,
  ) async {
    await pumpApp(tester);
    repo.onSend = (_) async => const Left(NetworkFailure());

    await enterEmailAndContinue(tester, 'a@b.co');

    expect(find.byType(OtpPage), findsNothing);
    expect(find.text(const NetworkFailure().message), findsOneWidget);
  });

  testWidgets('google: existing account opens the link-verification OTP page', (
    tester,
  ) async {
    await pumpApp(tester);
    repo.onGoogle = () async => const Right(
      GoogleLinkRequired(
        linkToken: 'link-1',
        maskedEmail: 'u***@example.com',
        expiresInSeconds: 300,
      ),
    );
    String? linked;
    repo.onLink = (token, otp) async {
      linked = '$token:$otp';
      repo.sessions.add(fakeSession);
      return Right(fakeSignIn);
    };

    await tester.tap(find.text('G'));
    await tester.pumpAndSettle();

    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.text('u***@example.com'), findsOneWidget);
    expect(find.textContaining('Resend code'), findsNothing);

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pumpAndSettle();

    expect(linked, 'link-1:654321');
    expect(find.byType(HomeShellPage), findsOneWidget);
  });

  testWidgets('google: direct sign-in routes home', (tester) async {
    await pumpApp(tester);
    repo.onGoogle = () async {
      repo.sessions.add(fakeSession);
      return Right(GoogleSignedIn(fakeSignIn));
    };

    await tester.tap(find.text('G'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShellPage), findsOneWidget);
  });

  testWidgets('logout from Settings returns to the login page', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, signedIn: true);

    final nav = find.byType(FloatingNavBar);
    await tester.tap(find.descendant(of: nav, matching: find.text('Settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(repo.logouts, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomeShellPage), findsNothing);
  });

  testWidgets('the session being revoked elsewhere returns to login', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true);

    repo.sessions.add(null); // e.g. refresh token rejected by the backend
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  group('login page layout never overflows', () {
    const sizes = {
      'small phone': Size(320, 480),
      'compact phone': Size(360, 640),
      'regular phone': Size(390, 844),
      'landscape': Size(800, 360),
      'tablet': Size(820, 1180),
    };

    for (final entry in sizes.entries) {
      for (final textScale in [1.0, 1.6]) {
        for (final keyboard in [0.0, 280.0]) {
          testWidgets(
            '${entry.key}, text x$textScale, keyboard ${keyboard.toInt()}',
            (tester) async {
              tester.view.physicalSize = entry.value;
              tester.view.devicePixelRatio = 1;
              tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
              tester.platformDispatcher.textScaleFactorTestValue = textScale;
              addTearDown(() {
                tester.view.reset();
                tester.platformDispatcher.clearAllTestValues();
              });

              await pumpApp(tester);

              // A RenderFlex overflow is reported as a test exception.
              expect(tester.takeException(), isNull);
              expect(find.byType(LoginPage), findsOneWidget);
            },
          );
        }
      }
    }
  });
}
