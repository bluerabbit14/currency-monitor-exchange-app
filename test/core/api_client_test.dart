import 'package:currency/core/network/api_client.dart';
import 'package:currency/core/network/api_exception.dart';
import 'package:currency/core/network/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_fakes.dart';

class _Tokens implements TokenProvider {
  _Tokens(this.access, {this.refreshesTo});

  String? access;
  String? refreshesTo;
  int refreshes = 0;

  @override
  Future<String?> accessToken() async => access;

  @override
  Future<String?> refreshAccessToken() async {
    refreshes++;
    return access = refreshesTo;
  }
}

ApiClient _authed(FakeAdapter adapter, _Tokens tokens) {
  final dio = Dio(
    BaseOptions(baseUrl: 'http://test', validateStatus: (_) => true),
  )..httpClientAdapter = adapter;
  return ApiClient.authenticated(tokens, dio: dio);
}

void main() {
  test('unwraps the envelope body', () async {
    final client = clientFor(FakeAdapter((_) => ok({'a': 1})));
    expect(await client.post('/x'), {'a': 1});
  });

  test('204 returns null', () async {
    final client = clientFor(FakeAdapter((_) => noContent()));
    expect(await client.post('/x'), isNull);
  });

  test(
    'error envelope becomes ApiException with code and field errors',
    () async {
      final client = clientFor(
        FakeAdapter(
          (_) => apiError(
            400,
            'Validation failed',
            code: 'VALIDATION_FAILED',
            details: [
              {'field': 'contact', 'message': 'Contact is required'},
            ],
          ),
        ),
      );

      await expectLater(
        client.post('/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having((e) => e.code, 'code', 'VALIDATION_FAILED')
              .having((e) => e.fieldErrors, 'fields', {
                'contact': 'Contact is required',
              }),
        ),
      );
    },
  );

  test(
    'non-JSON error (proxy / gateway page) still yields an ApiException',
    () async {
      final client = clientFor(
        FakeAdapter(
          (_) => ResponseBody.fromString('<html>Bad gateway</html>', 502),
        ),
      );
      await expectLater(
        client.post('/x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
      );
    },
  );

  test('connection failures become NetworkException', () async {
    final client = clientFor(
      FakeAdapter(
        (o) =>
            throw DioException.connectionError(requestOptions: o, reason: 'x'),
      ),
    );
    await expectLater(client.post('/x'), throwsA(isA<NetworkException>()));
  });

  group('authenticated client', () {
    test('adds the bearer token', () async {
      final adapter = FakeAdapter((_) => ok({}));
      await _authed(adapter, _Tokens('abc')).post('/x');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
    });

    test('on 401 refreshes once and retries with the new token', () async {
      final tokens = _Tokens('stale', refreshesTo: 'fresh');
      final adapter = FakeAdapter(
        (o) => o.headers['Authorization'] == 'Bearer fresh'
            ? ok({'done': true})
            : apiError(401, 'Unauthorized'),
      );

      final body = await _authed(adapter, tokens).post('/x');

      expect(body, {'done': true});
      expect(tokens.refreshes, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('gives up with the 401 when the refresh fails', () async {
      final tokens = _Tokens('stale');
      final adapter = FakeAdapter((_) => apiError(401, 'Unauthorized'));

      await expectLater(
        _authed(adapter, tokens).post('/x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 401)),
      );
      expect(tokens.refreshes, 1);
      expect(adapter.requests, hasLength(1));
    });

    test('does not loop when the retry is also 401', () async {
      final tokens = _Tokens('stale', refreshesTo: 'fresh');
      final adapter = FakeAdapter((_) => apiError(401, 'Unauthorized'));

      await expectLater(
        _authed(adapter, tokens).post('/x'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.refreshes, 1);
      expect(adapter.requests, hasLength(2));
    });
  });
}
