import 'dart:async';

import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/data/datasources/currency_remote_data_source.dart';
import 'package:currency/features/currency/data/repositories/currency_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  group('shared currency cache', () {
    late FakeAdapter adapter;
    late CurrencyRepositoryImpl repo;

    Map<String, dynamic> list() => {
      'status': 'SUCCESS',
      'body': [
        {'id': 'a', 'symbol': 'USD', 'name': 'US Dollar'},
      ],
    };

    setUp(() {
      adapter = FakeAdapter((_) => jsonBody(200, list()));
      repo = CurrencyRepositoryImpl(
        CurrencyRemoteDataSource(clientFor(adapter)),
      );
    });

    test('concurrent callers share one request', () async {
      final gate = Completer<void>();
      adapter.handler = (_) async {
        await gate.future;
        return jsonBody(200, list());
      };

      final first = repo.getCurrencies();
      final second = repo.getCurrencies();
      gate.complete();
      final results = await Future.wait([first, second]);

      expect(adapter.to('/api/v1/currencies'), hasLength(1));
      expect(results.every((r) => r.isRight()), isTrue);
    });

    test('a later call reuses the cached list without a request', () async {
      await repo.getCurrencies();
      final again = (await repo.getCurrencies()).getOrElse(() => throw 'x');

      expect(adapter.to('/api/v1/currencies'), hasLength(1));
      expect(again.single.code, 'USD');
    });

    test('a failure is not cached: the next call retries', () async {
      adapter.handler = (_) => apiError(500, 'down');
      expect((await repo.getCurrencies()).isLeft(), isTrue);

      adapter.handler = (_) => jsonBody(200, list());
      expect((await repo.getCurrencies()).isRight(), isTrue);
      expect(adapter.to('/api/v1/currencies'), hasLength(2));
    });

    test(
      'a failure is shared by callers that joined it, then cleared',
      () async {
        final gate = Completer<void>();
        adapter.handler = (_) async {
          await gate.future;
          return apiError(500, 'down');
        };
        final first = repo.getCurrencies();
        final second = repo.getCurrencies();
        gate.complete();

        expect((await first).isLeft(), isTrue);
        expect((await second).isLeft(), isTrue);
        expect(adapter.to('/api/v1/currencies'), hasLength(1));
      },
    );
  });

  testWidgets('opening the login screen preloads the currency list once', (
    tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    await sl.reset();
    await init();
    await useFakeProfileRepository();
    final currencies = await useFakeCurrencyRepository();
    final session = AuthSessionCubit(FakeAuthRepository());

    await tester.pumpWidget(CurrencyApp(sessionCubit: session));
    expect(currencies.loads, 0); // splash: not signed out yet
    await session.start();
    await tester.pumpAndSettle();

    expect(currencies.loads, 1);
  });
}
