import 'package:country_flags/country_flags.dart';
import 'package:currency/app.dart';
import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/auth/presentation/bloc/auth_session_cubit.dart';
import 'package:currency/features/currency/data/datasources/currency_remote_data_source.dart';
import 'package:currency/features/currency/data/repositories/currency_repository_impl.dart';
import 'package:currency/features/currency/presentation/pages/base_currency_page.dart';
import 'package:currency/features/shell/presentation/pages/home_shell_page.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_currency_repository.dart';
import '../../helpers/fake_profile_repository.dart';

void main() {
  group('repository', () {
    test('GETs /currencies and maps the array body', () async {
      final adapter = FakeAdapter(
        (_) => jsonBody(200, {
          'status': 'SUCCESS',
          'statusCode': 200,
          'body': [
            {
              'id': 'a',
              'symbol': 'RUB',
              'name': 'Russian Ruble',
              'type': 'FIAT',
              'status': 'ACTIVE',
            },
            {'id': 'b', 'symbol': 'USD', 'name': 'US Dollar'},
          ],
        }),
      );
      final repo = CurrencyRepositoryImpl(
        CurrencyRemoteDataSource(clientFor(adapter)),
      );

      final list = (await repo.getCurrencies()).getOrElse(() => throw 'x');

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/v1/currencies');
      expect(list.map((c) => c.code), ['RUB', 'USD']);
      expect(list.first.name, 'Russian Ruble');
    });

    test('a malformed list is a failure, not a crash', () async {
      final adapter = FakeAdapter((_) => ok({'not': 'a list'}));
      final repo = CurrencyRepositoryImpl(
        CurrencyRemoteDataSource(clientFor(adapter)),
      );
      expect(
        (await repo.getCurrencies()).swap().getOrElse(() => throw 'x').message,
        'Unexpected response from server',
      );

      adapter.handler = (_) => jsonBody(200, {
        'status': 'SUCCESS',
        'body': [
          {'id': 1},
        ],
      });
      expect((await repo.getCurrencies()).isLeft(), isTrue);
    });

    test('PUTs the chosen id to /users/me/base-currency', () async {
      final adapter = FakeAdapter((_) => ok({'id': 'user'}));
      final repo = CurrencyRepositoryImpl(
        CurrencyRemoteDataSource(clientFor(adapter)),
      );

      final result = await repo.setBaseCurrency('id-usd');

      expect(result.isRight(), isTrue);
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/api/v1/users/me/base-currency');
      expect(adapter.requests.single.data, {'currencyId': 'id-usd'});
    });

    test('404 and offline map to failures', () async {
      final adapter = FakeAdapter((_) => apiError(404, 'Currency not found'));
      final repo = CurrencyRepositoryImpl(
        CurrencyRemoteDataSource(clientFor(adapter)),
      );
      expect(
        (await repo.setBaseCurrency('x'))
            .swap()
            .getOrElse(() => throw 'x')
            .message,
        'Currency not found',
      );

      adapter.handler = (o) => throw Exception('socket');
      expect(
        (await repo.getCurrencies()).swap().getOrElse(() => throw 'x'),
        isA<Failure>(),
      );
    });
  });

  group('base currency gate', () {
    late FakeAuthRepository auth;
    late FakeCurrencyRepository currencies;
    late FakeProfileRepository profile;
    late AuthSessionCubit session;

    setUp(() async {
      await sl.reset();
      await init();
      profile = await useFakeProfileRepository();
      currencies = await useFakeCurrencyRepository();
      auth = FakeAuthRepository();
    });

    Future<void> pump(WidgetTester tester, {required bool newUser}) async {
      auth.restored = fakeSession.copyWith(requiresBaseCurrency: newUser);
      session = AuthSessionCubit(auth);
      await tester.pumpWidget(CurrencyApp(sessionCubit: session));
      await session.start();
      await tester.pumpAndSettle();
    }

    testWidgets('an existing user skips it and makes no currency request', (
      tester,
    ) async {
      await pump(tester, newUser: false);

      expect(find.byType(HomeShellPage), findsOneWidget);
      expect(find.byType(BaseCurrencyPage), findsNothing);
      expect(currencies.loads, 0);
    });

    testWidgets('a new user must choose a currency before the app opens', (
      tester,
    ) async {
      await pump(tester, newUser: true);

      expect(find.byType(BaseCurrencyPage), findsOneWidget);
      expect(find.byType(HomeShellPage), findsNothing);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('US Dollar'), findsOneWidget);
      // One flag per row, taken from the currency code.
      expect(find.byType(CountryFlag), findsNWidgets(3));
      expect(
        tester
            .widgetList<CountryFlag>(find.byType(CountryFlag))
            .map((f) => f.flagCode),
        ['us', 'eu', 'in'],
      );

      // Nothing selected: the button is disabled.
      final button = find.widgetWithText(FilledButton, 'Select a currency');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tester.tap(find.text('Euro'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue with EUR'));
      await tester.pumpAndSettle();

      expect(currencies.saved, ['id-eur']);
      expect(auth.baseCurrencyMarks, 1);
      expect(find.byType(HomeShellPage), findsOneWidget);
      expect(find.byType(BaseCurrencyPage), findsNothing);
      expect(profile.calls, 0, reason: 'profile still loads lazily');
    });

    testWidgets('the system back button cannot skip the gate', (tester) async {
      await pump(tester, newUser: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BaseCurrencyPage), findsOneWidget);
    });

    testWidgets('a failed save keeps the user on the page to retry', (
      tester,
    ) async {
      currencies.saveResult = const Left(NetworkFailure());
      await pump(tester, newUser: true);

      await tester.tap(find.text('Indian Rupee'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue with INR'));
      await tester.pumpAndSettle();

      expect(find.text(const NetworkFailure().message), findsOneWidget);
      expect(find.byType(BaseCurrencyPage), findsOneWidget);
      expect(auth.baseCurrencyMarks, 0);

      currencies.saveResult = const Right(unit);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue with INR'));
      await tester.pumpAndSettle();

      expect(currencies.saved, ['id-inr', 'id-inr']);
      expect(find.byType(HomeShellPage), findsOneWidget);
    });

    testWidgets('a failed load shows Retry', (tester) async {
      currencies.list = const Left(NetworkFailure());
      await pump(tester, newUser: true);
      expect(find.text(const NetworkFailure().message), findsOneWidget);

      currencies.list = const Right([usd]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('US Dollar'), findsOneWidget);
      expect(currencies.loads, 2);
    });

    testWidgets('search filters by code or name', (tester) async {
      await pump(tester, newUser: true);

      await tester.enterText(find.byType(TextField), 'rup');
      await tester.pump();
      expect(find.text('Indian Rupee'), findsOneWidget);
      expect(find.text('Euro'), findsNothing);

      await tester.enterText(find.byType(TextField), 'usd');
      await tester.pump();
      expect(find.text('US Dollar'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No currencies found'), findsOneWidget);
    });

    testWidgets('the user can log out from the gate', (tester) async {
      await pump(tester, newUser: true);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(auth.logouts, 1);
      expect(find.byType(BaseCurrencyPage), findsNothing);
    });
  });
}
