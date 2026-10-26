import 'package:currency/core/error/failures.dart';
import 'package:currency/features/converter/domain/entities/conversion.dart';
import 'package:currency/features/converter/domain/expression_input.dart';
import 'package:currency/features/converter/domain/repositories/converter_repository.dart';
import 'package:currency/features/converter/presentation/bloc/converter_cubit.dart';
import 'package:currency/features/favourite/domain/usecases/favorite_usecases.dart';
import 'package:currency/features/profile/domain/entities/user_profile.dart';
import 'package:currency/features/profile/domain/repositories/profile_repository.dart';
import 'package:currency/features/profile/domain/usecases/get_profile.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_favorite_repository.dart';

class _FakeConverterRepository implements ConverterRepository {
  /// Rate of one `from` in `to`, by `FROM/TO`.
  final rates = <String, double>{};
  ConverterSession? saved;
  final requests = <String>[];

  @override
  Future<Either<Failure, ConverterRate>> getRate({
    required String from,
    required String to,
    bool refresh = false,
  }) async {
    requests.add('$from/$to');
    final rate = rates['$from/$to'];
    return rate == null
        ? const Left(ServerFailure('No rate'))
        : Right(ConverterRate(rate: rate, fetchedAt: DateTime(2026, 1, 1)));
  }

  @override
  Future<ConverterSession?> loadSession() async => saved;

  @override
  Future<void> saveSession(ConverterSession session) async => saved = session;
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<Either<Failure, UserProfile>> getProfile() async =>
      const Right(UserProfile(email: 'me@example.com'));
}

void main() {
  late _FakeConverterRepository repository;
  late FakeFavoriteRepository catalog;
  late ConverterCubit cubit;

  setUp(() {
    repository = _FakeConverterRepository()
      ..rates.addAll({
        'INR/USD': 0.012,
        'INR/EUR': 0.011,
        'USD/INR': 83.0,
        'USD/EUR': 0.92,
      });
    catalog = FakeFavoriteRepository()..assets = [inrAsset, usdAsset, eurAsset];
    cubit = ConverterCubit(
      repository,
      GetAssetCatalog(catalog),
      GetProfile(_FakeProfileRepository()),
    );
  });

  tearDown(() => cubit.close());

  ConverterSession session({String? active, String expression = ''}) =>
      ConverterSession(
        assets: [inrAsset, usdAsset, eurAsset],
        activeSymbol: active,
        expression: expression,
      );

  test('a first launch starts with USD and EUR', () async {
    await cubit.load();
    expect(cubit.state.status, ConverterStatus.ready);
    expect([for (final a in cubit.state.assets) a.symbol], ['USD', 'EUR']);
    expect(cubit.state.activeSymbol, 'USD');
  });

  test('typing converts every other row from the active one', () async {
    repository.saved = session(active: 'INR');
    await cubit.load();
    for (final key in ['1', '0', '0']) {
      cubit.keyPressed(key);
    }
    expect(cubit.state.expression, '100');
    expect(cubit.state.convertedValue('USD'), closeTo(1.2, 1e-9));
    expect(cubit.state.convertedValue('EUR'), closeTo(1.1, 1e-9));
    expect(cubit.state.convertedValue('INR'), 100);
  });

  test('equals collapses the expression to its result', () async {
    repository.saved = session(active: 'INR', expression: '12+3×2');
    await cubit.load();
    cubit.keyPressed(Keys.equals);
    expect(cubit.state.expression, '18');
  });

  test('switching rows carries the converted amount over', () async {
    repository.saved = session(active: 'INR', expression: '100');
    await cubit.load();
    await cubit.selectActive('USD');
    expect(cubit.state.activeSymbol, 'USD');
    expect(cubit.state.expression, '1.2');
    // Rates are refetched against the new base.
    expect(repository.requests, containsAll(['USD/INR', 'USD/EUR']));
    expect(cubit.state.convertedValue('INR'), closeTo(99.6, 1e-9));
  });

  test('a failed pair is marked and does not block the others', () async {
    repository.rates.remove('INR/EUR');
    repository.saved = session(active: 'INR', expression: '100');
    await cubit.load();
    expect(cubit.state.failed, {'EUR'});
    expect(cubit.state.convertedValue('USD'), closeTo(1.2, 1e-9));
    expect(cubit.state.convertedValue('EUR'), isNull);
    expect(cubit.state.error, 'No rate');
  });

  test('removing the active row makes the first one active', () async {
    repository.saved = session(active: 'INR', expression: '100');
    await cubit.load();
    await cubit.remove('INR');
    expect([for (final a in cubit.state.assets) a.symbol], ['USD', 'EUR']);
    expect(cubit.state.activeSymbol, 'USD');
    expect(cubit.state.expression, '');
  });

  test(
    'setAssets keeps the order, adds new rows last and drops unticked',
    () async {
      repository.saved = session(active: 'INR');
      await cubit.load();
      await cubit.setAssets([eurAsset, btcAsset, inrAsset]);
      expect(
        [for (final a in cubit.state.assets) a.symbol],
        ['INR', 'EUR', 'BTC'],
      );
      expect(cubit.state.activeSymbol, 'INR');
    },
  );

  test('clear resets the typed amount but keeps the rows', () async {
    repository.saved = session(active: 'INR', expression: '5');
    await cubit.load();
    final symbols = [for (final a in cubit.state.assets) a.symbol];
    cubit.clear();
    expect(cubit.state.expression, '');
    expect(cubit.state.activeSymbol, 'INR');
    expect([for (final a in cubit.state.assets) a.symbol], symbols);
    expect(repository.saved?.expression, '');
    expect(repository.saved?.assets, isNotEmpty);
  });

  test('keys are ignored while the list is empty', () async {
    repository.saved = const ConverterSession();
    await cubit.load();
    cubit.keyPressed('5');
    expect(cubit.state.expression, '');
  });

  test('every change is saved', () async {
    repository.saved = session(active: 'INR');
    await cubit.load();
    cubit.keyPressed('7');
    expect(repository.saved?.expression, '7');
  });
}
