import 'dart:async';

import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:currency/features/auth/domain/entities/contact_identifier.dart';
import 'package:currency/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:currency/features/auth/domain/entities/otp_challenge.dart';
import 'package:currency/features/auth/domain/usecases/send_otp.dart';
import 'package:currency/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:currency/features/auth/domain/usecases/verify_google_link.dart';
import 'package:currency/features/auth/domain/usecases/verify_otp.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/auth/presentation/bloc/login_cubit.dart';
import 'package:currency/features/auth/presentation/bloc/otp_verify_cubit.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  group('AuthSessionCubit', () {
    test('starts unknown, then follows the restored session', () async {
      repo.restored = fakeSession;
      final cubit = AuthSessionCubit(repo);
      expect(cubit.state, const AuthSessionUnknown());
      await cubit.start();
      expect(cubit.state, const AuthSessionAuthenticated());
      await cubit.close();
    });

    test('no stored session means unauthenticated', () async {
      final cubit = AuthSessionCubit(repo);
      await cubit.start();
      expect(cubit.state, const AuthSessionUnauthenticated());
      await cubit.close();
    });

    test('reacts to sign-in and to the session being revoked', () async {
      final cubit = AuthSessionCubit(repo);
      await cubit.start();

      repo.sessions.add(fakeSession);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const AuthSessionAuthenticated());

      repo.sessions.add(null); // e.g. refresh token rejected
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const AuthSessionUnauthenticated());
      await cubit.close();
    });

    test('logout delegates to the repository', () async {
      final cubit = AuthSessionCubit(repo);
      await cubit.logout();
      expect(repo.logouts, 1);
      await cubit.close();
    });
  });

  group('LoginCubit', () {
    LoginCubit make() => LoginCubit(SignInWithGoogle(repo));

    test('invalid email is rejected inline without a request', () {
      final cubit = make();
      cubit.continueWithEmail('nope');
      expect(
        cubit.state,
        const LoginFailed(
          'Enter a valid email address',
          isEmailFieldError: true,
        ),
      );
      cubit.continueWithEmail('   ');
      expect(
        cubit.state,
        const LoginFailed('Enter your email address', isEmailFieldError: true),
      );
      expect(repo.sent, isEmpty);
    });

    test(
      'valid email opens the code screen at once, sending nothing',
      () async {
        final cubit = make();
        final states = <LoginState>[];
        cubit.stream.listen(states.add);

        cubit.continueWithEmail('  Me@Example.com ');
        await Future<void>.delayed(Duration.zero);

        // No loading state and no request: the code screen sends the OTP.
        expect(repo.sent, isEmpty);
        expect(states, [
          LoginOtpRequested(EmailContact.tryParse('me@example.com')!),
          const LoginIdle(),
        ]);
      },
    );

    test(
      'google: signed in returns to idle (app routes via session)',
      () async {
        final cubit = make();
        await cubit.continueWithGoogle();
        expect(cubit.state, const LoginIdle());
      },
    );

    test('google: link required hands over the link details', () async {
      const link = GoogleLinkRequired(
        linkToken: 't',
        maskedEmail: 'u***@x.com',
        expiresInSeconds: 300,
      );
      repo.onGoogle = () async => const Right(link);
      final cubit = make();
      await cubit.continueWithGoogle();
      expect(cubit.state, const LoginGoogleLinkRequired(link));
    });

    test('google: cancel is silent, errors are shown', () async {
      repo.onGoogle = () async => const Left(GoogleSignInCancelledFailure());
      final cubit = make();
      await cubit.continueWithGoogle();
      expect(cubit.state, const LoginIdle());

      repo.onGoogle = () async => const Left(ServerFailure('Already linked'));
      await cubit.continueWithGoogle();
      expect(cubit.state, const LoginFailed('Already linked'));
    });
  });

  group('OtpVerifyCubit', () {
    final contact = EmailContact.tryParse('a@b.co')!;
    var clock = DateTime(2026, 1, 1, 12);

    OtpVerifyCubit make(OtpFlow flow) {
      clock = DateTime(2026, 1, 1, 12);
      return OtpVerifyCubit(
        flow,
        VerifyOtp(repo),
        VerifyGoogleLink(repo),
        SendOtp(repo),
        now: () => clock,
      );
    }

    test('rejects malformed codes without a request', () async {
      var calls = 0;
      repo.onVerify = (_, _) async {
        calls++;
        return Right(fakeSignIn);
      };
      final cubit = make(ContactOtpFlow(contact));
      await cubit.submit('12');
      expect(cubit.state.error, 'Enter the 6-digit code');
      await cubit.submit('12345a');
      expect(cubit.state.error, 'Enter the 6-digit code');
      expect(calls, 0);
      await cubit.close();
    });

    test('verifies the code for the contact; success clears busy', () async {
      String? seen;
      repo.onVerify = (c, o) async {
        seen = '${c.value}:$o';
        return Right(fakeSignIn);
      };
      final cubit = make(ContactOtpFlow(contact));
      await cubit.submit(' 123456 ');
      expect(seen, 'a@b.co:123456');
      expect(cubit.state.isVerifying, isFalse);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('wrong code shows the backend message', () async {
      repo.onVerify = (_, _) async =>
          const Left(ServerFailure('Invalid or expired OTP.'));
      final cubit = make(ContactOtpFlow(contact));
      await cubit.submit('000000');
      expect(cubit.state.error, 'Invalid or expired OTP.');
      expect(cubit.state.isVerifying, isFalse);
      await cubit.close();
    });

    test('double submit while verifying sends one request', () async {
      final gate = Completer<Either<Failure, SignInResult>>();
      var calls = 0;
      repo.onVerify = (_, _) {
        calls++;
        return gate.future;
      };
      final cubit = make(ContactOtpFlow(contact));
      final first = cubit.submit('123456');
      await cubit.submit('123456');
      expect(calls, 1);
      expect(cubit.state.isVerifying, isTrue);
      gate.complete(Right(fakeSignIn));
      await first;
      await cubit.close();
    });

    test('an expired code is not sent to the server', () async {
      var calls = 0;
      repo.onVerify = (_, _) async {
        calls++;
        return Right(fakeSignIn);
      };
      final cubit = make(ContactOtpFlow(contact, expiresInSeconds: 60));
      clock = clock.add(const Duration(seconds: 61));
      await cubit.submit('123456');
      expect(cubit.state.error, contains('expired'));
      expect(calls, 0);
      await cubit.close();
    });

    test('resend has a cooldown, then re-sends and extends expiry', () async {
      final cubit = make(ContactOtpFlow(contact, expiresInSeconds: 60));
      expect(cubit.state.resendInSeconds, OtpVerifyCubit.resendCooldownSeconds);

      await cubit.resend(); // still cooling down
      expect(repo.sent, isEmpty);

      // Simulate the cooldown finishing.
      cubit.emit(cubit.state.copyWith(resendInSeconds: 0));
      clock = clock.add(const Duration(seconds: 61)); // old code expired
      await cubit.resend();

      expect(repo.sent.single.value, 'a@b.co');
      expect(cubit.state.resent, isTrue);
      expect(cubit.state.resendInSeconds, OtpVerifyCubit.resendCooldownSeconds);

      // New code is accepted again.
      await cubit.submit('123456');
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('sendOnOpen sends in the background without blocking', () async {
      final gate = Completer<Either<Failure, OtpChallenge>>();
      repo.onSend = (_) => gate.future;
      final cubit = make(ContactOtpFlow(contact, sendOnOpen: true));

      // Constructed and usable straight away; the send is still in flight.
      expect(repo.sent, hasLength(1));
      expect(cubit.state.isResending, isTrue);
      expect(cubit.state.resendInSeconds, 0);

      gate.complete(
        Right(OtpChallenge(contact: contact, expiresInSeconds: 300)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isResending, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.resent, isFalse);
      expect(cubit.state.resendInSeconds, OtpVerifyCubit.resendCooldownSeconds);
      await cubit.close();
    });

    test('a failed background send shows the error and allows retry', () async {
      repo.onSend = (_) async => const Left(NetworkFailure());
      final cubit = make(ContactOtpFlow(contact, sendOnOpen: true));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.error, const NetworkFailure().message);
      expect(cubit.state.isResending, isFalse);
      expect(cubit.state.resendInSeconds, 0);

      repo.onSend = (c) async =>
          Right(OtpChallenge(contact: c, expiresInSeconds: 300));
      await cubit.resend();
      expect(cubit.state.error, isNull);
      expect(repo.sent, hasLength(2));
      await cubit.close();
    });

    test('resend failure is reported and can be retried', () async {
      repo.onSend = (_) async => const Left(NetworkFailure());
      final cubit = make(ContactOtpFlow(contact));
      cubit.emit(cubit.state.copyWith(resendInSeconds: 0));
      await cubit.resend();
      expect(cubit.state.error, const NetworkFailure().message);
      expect(cubit.state.isResending, isFalse);
      await cubit.close();
    });

    test(
      'google link flow verifies with the link token and has no resend',
      () async {
        String? seen;
        repo.onLink = (t, o) async {
          seen = '$t:$o';
          return Right(fakeSignIn);
        };
        final cubit = make(
          const GoogleLinkOtpFlow(
            linkToken: 'link-1',
            maskedEmail: 'u***@x.com',
            expiresInSeconds: 300,
          ),
        );
        expect(cubit.canResend, isFalse);
        expect(cubit.state.resendInSeconds, 0);
        await cubit.resend();
        expect(repo.sent, isEmpty);

        await cubit.submit('654321');
        expect(seen, 'link-1:654321');
        await cubit.close();
      },
    );
  });
}
