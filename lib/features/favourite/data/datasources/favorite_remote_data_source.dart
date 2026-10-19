import '../../../../core/network/api_client.dart';
import '../../domain/entities/asset_item.dart';

class FavoriteRemoteDataSource {
  const FavoriteRemoteDataSource(this._client);

  /// The authenticated client (favorites need a login; rates and assets are
  /// public but share the client so token refresh lives in one place).
  final ApiClient _client;

  static const _favorites = '/api/v1/users/me/favorites';

  Future<List<AssetItem>> getFavorites() async {
    final items = await _client.getList(_favorites);
    return [for (final item in items) _favorite(item)];
  }

  /// First page (up to 100) of the active asset catalog.
  Future<List<AssetItem>> getAssets() async {
    final page = await _client.get('/api/v1/assets', query: {'size': 100});
    final content = page?['content'];
    if (content is! List) throw const FormatException('Malformed asset page');
    return [for (final item in content) _asset(item, idKey: 'id')];
  }

  Future<AssetItem> addFavorite(String assetId) async {
    final body = await _client.post('$_favorites/$assetId');
    return _favorite(body);
  }

  Future<void> removeFavorite(String assetId) =>
      _client.delete('$_favorites/$assetId');

  /// Current rate of [symbol] priced in [quote]. The backend derives pairs it
  /// does not store (through USD), so any asset can be priced in any currency.
  Future<double> getRate(String symbol, String quote) async {
    final body = await _client.get(
      '/api/v1/rates/${Uri.encodeComponent(symbol)}/${Uri.encodeComponent(quote)}',
    );
    final rate = body?['rate'];
    if (rate is! num) throw const FormatException('Malformed rate');
    return rate.toDouble();
  }

  /// The oldest stored rate at or after [from], or null when there is none.
  Future<double?> getOldestRateSince(
    String symbol,
    String quote,
    DateTime from,
    DateTime to,
  ) async {
    final page = await _client.get(
      '/api/v1/rates/${Uri.encodeComponent(symbol)}/${Uri.encodeComponent(quote)}/history',
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'size': 1,
        'sort': 'observedAt,asc',
      },
    );
    final content = page?['content'];
    if (content is! List || content.isEmpty) return null;
    final first = content.first;
    final rate = first is Map ? first['rate'] : null;
    return rate is num ? rate.toDouble() : null;
  }

  static AssetItem _favorite(Object? raw) => _asset(raw, idKey: 'assetId');

  static AssetItem _asset(Object? raw, {required String idKey}) {
    if (raw is! Map) throw const FormatException('Malformed asset');
    final id = raw[idKey];
    final symbol = raw['symbol'];
    final name = raw['name'];
    final kind = AssetKind.fromApi(raw['type']);
    if (id is! String || symbol is! String || name is! String || kind == null) {
      throw const FormatException('Malformed asset');
    }
    return AssetItem(id: id, symbol: symbol, name: name, kind: kind);
  }
}
