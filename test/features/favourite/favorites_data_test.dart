import 'package:currency/core/error/failures.dart';
import 'package:currency/core/format/number_format.dart';
import 'package:currency/features/favourite/data/datasources/favorite_remote_data_source.dart';
import 'package:currency/features/favourite/data/repositories/favorite_repository_impl.dart';
import 'package:currency/features/favourite/domain/entities/asset_item.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fakes.dart';

Map<String, dynamic> favoriteJson(String symbol, String name, String type) => {
  'assetId': 'id-$symbol',
  'symbol': symbol,
  'name': name,
  'type': type,
  'status': 'ACTIVE',
  'createdAt': '2026-10-12T04:00:00Z',
};

ResponseBody listBody(List<Map<String, dynamic>> items) =>
    jsonBody(200, {'status': 'SUCCESS', 'statusCode': 200, 'body': items});

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  late FakeAdapter adapter;
  late FavoriteRepositoryImpl repo;

  setUp(() {
    adapter = FakeAdapter((_) => apiError(500, 'unhandled'));
    repo = FavoriteRepositoryImpl(
      FavoriteRemoteDataSource(clientFor(adapter)),
      now: () => now,
    );
  });

  group('favorites API', () {
    test('lists favorites (the body is a plain array)', () async {
      adapter.handler = (_) => listBody([
        favoriteJson('INR', 'Indian Rupee', 'FIAT'),
        favoriteJson('BTC', 'Bitcoin', 'CRYPTO'),
        favoriteJson('XAU', 'Gold', 'COMMODITY'),
      ]);

      final items = (await repo.getFavorites()).getOrElse(() => throw 'x');

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/api/v1/users/me/favorites');
      expect(items.map((a) => a.symbol), ['INR', 'BTC', 'XAU']);
      expect(items.map((a) => a.kind), [
        AssetKind.fiat,
        AssetKind.crypto,
        AssetKind.commodity,
      ]);
      expect(items.first.id, 'id-INR');
    });

    test('an empty list is fine; a malformed item is a failure', () async {
      adapter.handler = (_) => listBody([]);
      expect((await repo.getFavorites()).getOrElse(() => throw 'x'), isEmpty);

      adapter.handler = (_) => listBody([
        {'assetId': 'x', 'symbol': 'A'},
      ]);
      expect((await repo.getFavorites()).isLeft(), isTrue);

      adapter.handler = (_) => listBody([favoriteJson('A', 'A', 'STOCK')]);
      expect((await repo.getFavorites()).isLeft(), isTrue);
    });

    test('adds with POST /favorites/{assetId}', () async {
      adapter.handler = (_) =>
          ok(favoriteJson('EUR', 'Euro', 'FIAT'), status: 201);

      final added = (await repo.addFavorite('id-EUR'))
          .getOrElse(() => throw 'x');

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/v1/users/me/favorites/id-EUR');
      expect(added.symbol, 'EUR');
    });

    test('removes with DELETE and 204', () async {
      adapter.handler = (_) => noContent();

      final result = await repo.removeFavorite('id-EUR');

      expect(result.isRight(), isTrue);
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/api/v1/users/me/favorites/id-EUR');
    });

    test('lists the asset catalog from the page content', () async {
      adapter.handler = (_) => ok({
        'content': [
          {
            'id': 'id-GBP',
            'symbol': 'GBP',
            'name': 'Pound',
            'type': 'FIAT',
            'status': 'ACTIVE',
          },
        ],
      });

      final assets = (await repo.getAssets()).getOrElse(() => throw 'x');

      expect(adapter.requests.single.path, '/api/v1/assets');
      expect(adapter.requests.single.queryParameters, {'size': 100});
      expect(assets.single.symbol, 'GBP');
    });

    test('errors map to messages', () async {
      adapter.handler = (_) => apiError(404, 'Asset not found');
      expect(
        (await repo.addFavorite('x')).swap().getOrElse(() => throw 'x').message,
        'Asset not found',
      );
      adapter.handler = (o) =>
          throw DioException.connectionError(requestOptions: o, reason: 'off');
      expect(
        (await repo.getFavorites()).swap().getOrElse(() => throw 'x'),
        const NetworkFailure(),
      );
    });
  });

  group('quotes', () {
    ResponseBody handle(
      RequestOptions o, {
      required double rate,
      double? oldest,
    }) {
      if (o.path.endsWith('/history')) {
        return ok({
          'content': [
            if (oldest != null) {'rate': oldest},
          ],
        });
      }
      return ok({'base': 'INR', 'quote': 'AED', 'rate': rate});
    }

    test(
      'price comes from /rates/{symbol}/{quote}; change from 24h history',
      () async {
        adapter.handler = (o) => handle(o, rate: 0.038306, oldest: 0.038288);

        final quote = (await repo.getQuote(
          symbol: 'INR',
          quote: 'AED',
        )).getOrElse(() => throw 'x');

        expect(quote.rate, 0.038306);
        expect(quote.change, closeTo(0.000018, 1e-9));
        final rate = adapter.requests.firstWhere(
          (r) => !r.path.endsWith('/history'),
        );
        expect(rate.path, '/api/v1/rates/INR/AED');
        final history = adapter.requests.firstWhere(
          (r) => r.path.endsWith('/history'),
        );
        expect(history.path, '/api/v1/rates/INR/AED/history');
        expect(history.queryParameters, {
          'from': '2026-10-18T12:00:00.000Z',
          'to': '2026-10-19T12:00:00.000Z',
          'size': 1,
          'sort': 'observedAt,asc',
        });
      },
    );

    test('a falling price has a negative change', () async {
      adapter.handler = (o) => handle(o, rate: 0.977797, oldest: 0.977978);
      final quote = (await repo.getQuote(
        symbol: 'SAR',
        quote: 'AED',
      )).getOrElse(() => throw 'x');
      expect(quote.change, closeTo(-0.000181, 1e-9));
    });

    test('no history means a price without a change', () async {
      adapter.handler = (o) => handle(o, rate: 3.67);
      final quote = (await repo.getQuote(
        symbol: 'USD',
        quote: 'AED',
      )).getOrElse(() => throw 'x');
      expect(quote.rate, 3.67);
      expect(quote.change, isNull);
    });

    test('a failing history call does not fail the price', () async {
      adapter.handler = (o) => o.path.endsWith('/history')
          ? apiError(404, 'no pair')
          : ok({'rate': 4.22});
      final quote = (await repo.getQuote(
        symbol: 'EUR',
        quote: 'AED',
      )).getOrElse(() => throw 'x');
      expect(quote.rate, 4.22);
      expect(quote.change, isNull);
    });

    test('a failing price call is a failure', () async {
      adapter.handler = (_) => apiError(404, 'Rate not available');
      expect(
        (await repo.getQuote(
          symbol: 'EUR',
          quote: 'AED',
        )).swap().getOrElse(() => throw 'x').message,
        'Rate not available',
      );
      adapter.handler = (_) => ok({'rate': 'abc'});
      expect(
        (await repo.getQuote(symbol: 'EUR', quote: 'AED')).isLeft(),
        isTrue,
      );
    });

    test(
      'an asset priced in itself is 1 with no change and no request',
      () async {
        final quote = (await repo.getQuote(
          symbol: 'aed',
          quote: 'AED',
        )).getOrElse(() => throw 'x');
        expect(quote.rate, 1);
        expect(quote.change, 0);
        expect(adapter.requests, isEmpty);
      },
    );
  });

  group('number formatting', () {
    test('formatPrice trims zeros but keeps two decimals', () {
      expect(formatPrice(0.038306), '0.038306');
      expect(formatPrice(3.67), '3.67');
      expect(formatPrice(4.22), '4.22');
      expect(formatPrice(1), '1.00');
      expect(formatPrice(0.9777970), '0.977797');
      expect(formatPrice(65000.123456789), '65000.123457');
      expect(formatPrice(0.5), '0.50');
    });

    test('formatChange is signed and collapses a nothing-move to 0.00', () {
      expect(formatChange(0.000018), '+0.000018');
      expect(formatChange(0.0002), '+0.0002');
      expect(formatChange(0.004105), '+0.004105');
      expect(formatChange(-0.000181), '-0.000181');
      expect(formatChange(0), '0.00');
      expect(formatChange(0.0000001), '0.00');
      expect(formatChange(-0.0000001), '0.00');
    });
  });
}
