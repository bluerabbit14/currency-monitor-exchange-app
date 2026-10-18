import 'package:currency/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:currency/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:currency/features/auth/data/token_manager.dart';
import 'package:currency/features/auth/domain/entities/auth_session.dart';
import 'package:currency/features/auth/domain/entities/contact_identifier.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_fakes.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);
  final email = EmailContact.tryParse('new@example.com')!;

  late FakeAdapter adapter;
  late InMemoryAuthStorage storage;
  late TokenManager tokens;
  late AuthRepositoryImpl repo;

  setUp(() {
    adapter = FakeAdapter((_) => apiError(500, 'unhandled'));
    storage = InMemoryAuthStorage();
    final remote = remoteFor(adapter);
    tokens = TokenManager(storage, remote, now: () => now);
    repo = AuthRepositoryImpl(remote, FakeGoogle(), tokens, now: () => now);
  });

  tearDown(() => tokens.dispose());

  test('a new account is stored as needing a base currency', () async {
    adapter.handler = (_) => ok(tokenBody(newUser: true));

    final result = await repo.verifyOtp(email, '123456');

    expect(result.getOrElse(() => throw 'x').isNewUser, isTrue);
    expect(storage.stored?.requiresBaseCurrency, isTrue);
  });

  test('a returning user is not asked for a base currency', () async {
    adapter.handler = (_) => ok(tokenBody(newUser: false));

    await repo.verifyOtp(email, '123456');

    expect(storage.stored?.requiresBaseCurrency, isFalse);
  });

  test('google sign-up behaves the same way', () async {
    adapter.handler = (_) =>
        ok({'status': 'SIGNED_IN', ...tokenBody(newUser: true)});

    await repo.signInWithGoogle();

    expect(storage.stored?.requiresBaseCurrency, isTrue);
  });

  test('choosing a currency clears the flag and keeps the tokens', () async {
    adapter.handler = (_) => ok(tokenBody(newUser: true));
    await repo.verifyOtp(email, '123456');
    final emitted = <AuthSession?>[];
    final sub = repo.sessionChanges.listen(emitted.add);

    await repo.markBaseCurrencySelected();
    await Future<void>.delayed(Duration.zero);

    expect(storage.stored?.requiresBaseCurrency, isFalse);
    expect(storage.stored?.refreshToken, 'refresh-1');
    expect(emitted.single?.requiresBaseCurrency, isFalse);
    await sub.cancel();
  });

  test('marking is a no-op when nothing is pending or signed in', () async {
    await repo.markBaseCurrencySelected();
    expect(storage.stored, isNull);

    storage.stored = AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      accessTokenExpiresAt: now.add(const Duration(minutes: 5)),
    );
    final emitted = <AuthSession?>[];
    final sub = repo.sessionChanges.listen(emitted.add);
    await repo.markBaseCurrencySelected();
    await Future<void>.delayed(Duration.zero);
    expect(emitted, isEmpty);
    await sub.cancel();
  });

  test(
    'a token refresh before choosing does not lose the pending flag',
    () async {
      storage.stored = AuthSession(
        accessToken: 'old',
        refreshToken: 'old-refresh',
        accessTokenExpiresAt: now.subtract(const Duration(minutes: 1)),
        requiresBaseCurrency: true,
      );
      adapter.handler = (_) =>
          ok(tokenBody(access: 'new', refresh: 'new-refresh'));

      final fresh = await tokens.refresh();

      expect(fresh?.accessToken, 'new');
      expect(fresh?.requiresBaseCurrency, isTrue);
      expect(storage.stored?.requiresBaseCurrency, isTrue);
    },
  );

  group('secure storage round trip', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('the flag survives closing the app', () async {
      final local = AuthLocalDataSource();
      final session = AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(
          1800000000000,
        ),
        requiresBaseCurrency: true,
      );

      await local.write(session);
      final restored = await AuthLocalDataSource().read();

      expect(restored, session);
      expect(restored?.requiresBaseCurrency, isTrue);
    });

    test(
      'a session stored before this field existed reads as not pending',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'auth_session_v1': '{"accessToken":"a","refreshToken":"r","expiresAtMs":1800000000000}',
        });

        final restored = await AuthLocalDataSource().read();

        expect(restored?.refreshToken, 'r');
        expect(restored?.requiresBaseCurrency, isFalse);
      },
    );
  });
}
