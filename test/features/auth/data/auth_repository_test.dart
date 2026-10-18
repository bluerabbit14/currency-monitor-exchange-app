import 'dart:async';

import 'package:currency/core/constant/api_constants.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/core/network/api_client.dart';
import 'package:currency/core/network/api_exception.dart';
import 'package:currency/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:currency/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:currency/features/auth/data/token_manager.dart';
import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:currency/features/auth/domain/entities/contact_identifier.dart';
import 'package:currency/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);
  final email = EmailContact.tryParse('User@Example.com')!;

  late FakeAdapter adapter;
  late InMemoryAuthStorage storage;
  late FakeGoogle google;
  late TokenManager tokens;
  late AuthRepositoryImpl repo;

  setUp(() {
    adapter = FakeAdapter((_) => apiError(500, 'unhandled'));
    storage = InMemoryAuthStorage();
    google = FakeGoogle();
    final remote = remoteFor(adapter);
    tokens = TokenManager(storage, remote, now: () => now);
    repo = AuthRepositoryImpl(remote, google, tokens, now: () => now);
  });

  tearDown(() => tokens.dispose());

  AuthSession session({
    String access = 'old-access',
    String refresh = 'old-refresh',
    Duration expiresIn = const Duration(minutes: 10),
  }) => AuthSession(
    accessToken: access,
    refreshToken: refresh,
    accessTokenExpiresAt: now.add(expiresIn),
  );

  group('email OTP', () {
    test('sends the normalised contact and returns the challenge', () async {
      adapter.handler = (o) =>
          ok({'contact': 'user@example.com', 'expiresInSeconds': 300});

      final result = await repo.sendOtp(email);

      expect(adapter.requests.single.path, ApiConstants.otpSend);
      expect(adapter.requests.single.data, {'contact': 'user@example.com'});
      final challenge = result.getOrElse(() => throw 'expected success');
      expect(challenge.expiresInSeconds, 300);
      expect(challenge.contact, email);
    });

    test('verify stores the session and reports a new user', () async {
      adapter.handler = (o) => ok(tokenBody(newUser: true));
      final emitted = <AuthSession?>[];
      final sub = repo.sessionChanges.listen(emitted.add);

      final result = await repo.verifyOtp(email, '123456');
      await Future<void>.delayed(Duration.zero);

      final signIn = result.getOrElse(() => throw 'expected success');
      expect(signIn.isNewUser, isTrue);
      expect(signIn.session.accessToken, 'access-1');
      expect(
        signIn.session.accessTokenExpiresAt,
        now.add(const Duration(seconds: 900)),
      );
      expect(storage.stored, signIn.session);
      expect(emitted, [signIn.session]);
      expect(adapter.requests.single.data, {
        'contact': 'user@example.com',
        'otp': '123456',
      });
      await sub.cancel();
    });

    test(
      'wrong code surfaces the backend message and stores nothing',
      () async {
        adapter.handler = (o) =>
            apiError(401, 'Invalid or expired OTP.', code: 'UNAUTHORIZED');

        final result = await repo.verifyOtp(email, '000000');

        expect(
          result.swap().getOrElse(() => throw 'expected failure'),
          const ServerFailure(
            'Invalid or expired OTP.',
            statusCode: 401,
            code: 'UNAUTHORIZED',
          ),
        );
        expect(storage.stored, isNull);
      },
    );

    test('400 validation uses the first field message', () async {
      adapter.handler = (o) => apiError(
        400,
        'Validation failed',
        code: 'VALIDATION_FAILED',
        details: [
          {'field': 'otp', 'message': 'OTP must be 6 digits'},
        ],
      );

      final failure = (await repo.verifyOtp(
        email,
        '12',
      )).swap().getOrElse(() => throw 'expected failure');

      expect(failure.message, 'OTP must be 6 digits');
    });

    test('offline and timeouts become NetworkFailure', () async {
      adapter.handler = (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'no route',
      );
      expect(
        (await repo.sendOtp(email)).swap().getOrElse(() => throw 'x'),
        const NetworkFailure(),
      );

      adapter.handler = (o) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: o,
      );
      expect(
        (await repo.sendOtp(email)).swap().getOrElse(() => throw 'x'),
        const NetworkFailure(),
      );
    });

    test(
      '5xx hides backend internals; 503 and 429 get friendly text',
      () async {
        adapter.handler = (o) =>
            apiError(500, 'NullPointerException at Foo.java:12');
        var failure = (await repo.sendOtp(email))
            .swap()
            .getOrElse(() => throw 'x');
        expect(failure.message, 'Something went wrong. Please try again');

        adapter.handler = (o) => apiError(503, 'Resend is down');
        failure = (await repo.sendOtp(email)).swap().getOrElse(() => throw 'x');
        expect(failure.message, contains('temporarily unavailable'));

        adapter.handler = (o) => apiError(429, 'slow down');
        failure = (await repo.sendOtp(email)).swap().getOrElse(() => throw 'x');
        expect(failure.message, contains('Too many attempts'));
      },
    );

    test('malformed success body is a failure, not a crash', () async {
      adapter.handler = (o) => ok({'unexpected': true});
      final failure = (await repo.verifyOtp(
        email,
        '123456',
      )).swap().getOrElse(() => throw 'expected failure');
      expect(failure.message, 'Unexpected response from server');
      expect(storage.stored, isNull);
    });
  });

  group('google', () {
    test('SIGNED_IN stores the session', () async {
      adapter.handler = (o) =>
          ok({'status': 'SIGNED_IN', ...tokenBody(newUser: false)});

      final outcome = (await repo.signInWithGoogle()).getOrElse(
        () => throw 'expected success',
      );

      expect(outcome, isA<GoogleSignedIn>());
      expect(adapter.requests.single.path, ApiConstants.googleSignIn);
      expect(adapter.requests.single.data, {'idToken': 'google-id-token'});
      expect(storage.stored?.refreshToken, 'refresh-1');
      expect(google.signIns, 1);
    });

    test(
      'LINK_VERIFICATION_REQUIRED stores nothing and returns the link',
      () async {
        adapter.handler = (o) => ok({
          'status': 'LINK_VERIFICATION_REQUIRED',
          'linkToken': 'link-123',
          'maskedEmail': 'u***@example.com',
          'linkExpiresInSeconds': 300,
        });

        final outcome = (await repo.signInWithGoogle()).getOrElse(
          () => throw 'expected success',
        );

        expect(
          outcome,
          const GoogleLinkRequired(
            linkToken: 'link-123',
            maskedEmail: 'u***@example.com',
            expiresInSeconds: 300,
          ),
        );
        expect(storage.stored, isNull);
      },
    );

    test('link verify signs in', () async {
      adapter.handler = (o) =>
          ok({'status': 'SIGNED_IN', ...tokenBody(newUser: false)});

      final result = await repo.verifyGoogleLink(
        linkToken: 'link-123',
        otp: '654321',
      );

      expect(result.isRight(), isTrue);
      expect(adapter.requests.single.path, ApiConstants.googleLinkVerify);
      expect(adapter.requests.single.data, {
        'linkToken': 'link-123',
        'otp': '654321',
      });
      expect(storage.stored, isNotNull);
    });

    test('cancelling the account picker never reaches the backend', () async {
      google.result = const Left(GoogleSignInCancelledFailure());

      final failure = (await repo.signInWithGoogle()).swap().getOrElse(
        () => throw 'expected failure',
      );

      expect(failure, isA<GoogleSignInCancelledFailure>());
      expect(adapter.requests, isEmpty);
    });

    test('backend rejections: conflict and unverified email', () async {
      adapter.handler = (o) =>
          apiError(409, 'Already linked', code: 'GOOGLE_ACCOUNT_CONFLICT');
      var failure = (await repo.signInWithGoogle()).swap().getOrElse(
        () => throw 'x',
      );
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).code, 'GOOGLE_ACCOUNT_CONFLICT');

      adapter.handler = (o) => apiError(
        403,
        'Email not verified',
        code: 'GOOGLE_EMAIL_NOT_VERIFIED',
      );
      failure = (await repo.signInWithGoogle()).swap().getOrElse(
        () => throw 'x',
      );
      expect((failure as ServerFailure).code, 'GOOGLE_EMAIL_NOT_VERIFIED');
      expect(storage.stored, isNull);
    });
  });

  group('session', () {
    test('restore returns a valid stored session without a request', () async {
      storage.stored = session();

      expect(await repo.restoreSession(), storage.stored);
      expect(adapter.requests, isEmpty);
    });

    test(
      'restore makes no request, even when the access token expired',
      () async {
        final expired = session(expiresIn: const Duration(seconds: -5));
        storage.stored = expired;

        expect(await repo.restoreSession(), expired);
        expect(adapter.requests, isEmpty);
      },
    );

    group('expired token on the first authenticated request', () {
      ApiClient protectedClient(FakeAdapter protected) {
        final dio = Dio(
          BaseOptions(baseUrl: 'http://test', validateStatus: (_) => true),
        )..httpClientAdapter = protected;
        return ApiClient.authenticated(tokens, dio: dio);
      }

      test('is refreshed and the request retried', () async {
        storage.stored = session(expiresIn: const Duration(seconds: -5));
        adapter.handler = (o) =>
            ok(tokenBody(access: 'new-access', refresh: 'new-refresh'));
        final protected = FakeAdapter(
          (o) => o.headers['Authorization'] == 'Bearer new-access'
              ? ok({'done': true})
              : apiError(401, 'Unauthorized'),
        );

        await repo.restoreSession();
        expect(adapter.requests, isEmpty);

        final body = await protectedClient(protected).get('/api/v1/users/me');

        expect(body, {'done': true});
        expect(adapter.requests.single.data, {'refreshToken': 'old-refresh'});
        expect(storage.stored?.refreshToken, 'new-refresh');
      });

      test('a rejected refresh token signs the user out', () async {
        storage.stored = session(expiresIn: const Duration(seconds: -5));
        adapter.handler = (o) =>
            apiError(401, 'Invalid or expired refresh token');
        final protected = FakeAdapter((o) => apiError(401, 'Unauthorized'));
        final emitted = <AuthSession?>[];
        final sub = repo.sessionChanges.listen(emitted.add);

        await expectLater(
          protectedClient(protected).get('/api/v1/users/me'),
          throwsA(isA<ApiException>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(storage.stored, isNull);
        expect(emitted, [null]);
        await sub.cancel();
      });

      test('offline during that refresh keeps the session', () async {
        final expired = session(expiresIn: const Duration(seconds: -5));
        storage.stored = expired;
        adapter.handler = (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
        final protected = FakeAdapter((o) => apiError(401, 'Unauthorized'));

        await expectLater(
          protectedClient(protected).get('/api/v1/users/me'),
          throwsA(isA<ApiException>()),
        );

        expect(storage.stored, expired);
      });
    });

    test('restore with nothing stored is signed out', () async {
      expect(await repo.restoreSession(), isNull);
    });

    test(
      'logout clears locally, signs out of Google and revokes remotely',
      () async {
        storage.stored = session();
        adapter.handler = (o) => noContent();
        final emitted = <AuthSession?>[];
        final sub = repo.sessionChanges.listen(emitted.add);

        await repo.logout();
        await Future<void>.delayed(Duration.zero);

        expect(storage.stored, isNull);
        expect(google.signOuts, 1);
        expect(adapter.requests.single.path, ApiConstants.logout);
        expect(adapter.requests.single.data, {'refreshToken': 'old-refresh'});
        expect(emitted, [null]);
        await sub.cancel();
      },
    );

    test('logout still succeeds locally when the server call fails', () async {
      storage.stored = session();
      adapter.handler = (o) =>
          apiError(401, 'Invalid or expired refresh token');

      await repo.logout();
      expect(storage.stored, isNull);

      storage.stored = session();
      final fresh = TokenManager(storage, remoteFor(adapter), now: () => now);
      final offline = AuthRepositoryImpl(
        remoteFor(
          FakeAdapter(
            (o) => throw DioException.connectionError(
              requestOptions: o,
              reason: 'offline',
            ),
          ),
        ),
        google,
        fresh,
        now: () => now,
      );
      await offline.logout();
      expect(storage.stored, isNull);
      fresh.dispose();
    });
  });

  group('token manager', () {
    test(
      'concurrent refreshes share one request (refresh tokens rotate)',
      () async {
        storage.stored = session();
        final gate = Completer<void>();
        adapter.handler = (o) async {
          await gate.future;
          return ok(tokenBody(access: 'new-access', refresh: 'new-refresh'));
        };

        final a = tokens.refresh();
        final b = tokens.refresh();
        final c = tokens.refreshAccessToken();
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        final results = await Future.wait([a, b, c]);

        expect(adapter.requests, hasLength(1));
        expect(results[0], results[1]);
        expect(results[2], 'new-access');
      },
    );

    test(
      'a refresh finishing after logout does not resurrect the session',
      () async {
        storage.stored = session();
        final gate = Completer<void>();
        adapter.handler = (o) async {
          await gate.future;
          return ok(tokenBody());
        };

        final pending = tokens.refresh();
        await Future<void>.delayed(Duration.zero);
        await tokens.clear();
        gate.complete();

        expect(await pending, isNull);
        expect(storage.stored, isNull);
      },
    );

    test('a server error during refresh keeps the session', () async {
      final original = session();
      storage.stored = original;
      adapter.handler = (o) => apiError(500, 'boom');

      expect(await tokens.refresh(), isNull);
      expect(storage.stored, original);
    });
  });
}
