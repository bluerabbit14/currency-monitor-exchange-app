import '../../../../core/network/api_client.dart';
import '../../domain/entities/asset_item.dart';
import '../../domain/entities/price_point.dart';

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

  /// Every active asset grouped by type, each flagged when it is a favorite.
  /// Needs the access token (sent by the authenticated client).
  Future<Map<AssetKind, List<AssetItem>>> getAssetCatalog() async {
    final body = await _client.get('/api/v1/assets/grouped');
    if (body == null) throw const FormatException('Malformed asset catalog');
    final catalog = <AssetKind, List<AssetItem>>{};
    for (final kind in AssetKind.values) {
      final items = body[kind.name.toUpperCase()];
      if (items is! List) {
        throw const FormatException('Malformed asset catalog');
      }
      catalog[kind] = [
        for (final item in items)
          _asset(item, idKey: 'id', kind: kind, withFavorite: true),
      ];
    }
    return catalog;
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

  /// Every stored price in [from, to), oldest first. The first page says how
  /// many pages there are; the rest are fetched together.
  Future<List<PricePoint>> getHistory(
    String symbol,
    String quote,
    DateTime from,
    DateTime to,
  ) async {
    final path =
        '/api/v1/rates/${Uri.encodeComponent(symbol)}/${Uri.encodeComponent(quote)}/history';
    Future<Map<String, dynamic>?> page(int n) => _client.get(
      path,
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page': n,
        'size': _historyPageSize,
      },
    );

    final first = await page(0);
    final pages = <Map<String, dynamic>?>[first];
    final totalPages = (first?['totalPages'] as num?)?.toInt() ?? 1;
    if (totalPages > 1) {
      pages.addAll(
        await Future.wait([
          for (var n = 1; n < totalPages && n < _maxHistoryPages; n++) page(n),
        ]),
      );
    }
    final points = <PricePoint>[];
    for (final p in pages) {
      final content = p?['content'];
      if (content is! List) continue;
      for (final item in content) {
        if (item is! Map) continue;
        final rate = item['rate'];
        final time = DateTime.tryParse('${item['observedAt'] ?? ''}');
        if (rate is num && time != null) {
          points.add(PricePoint(time: time, rate: rate.toDouble()));
        }
      }
    }
    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  static const _historyPageSize = 100;
  static const _maxHistoryPages = 30;

  static AssetItem _favorite(Object? raw) => _asset(raw, idKey: 'assetId');

  static AssetItem _asset(
    Object? raw, {
    required String idKey,
    AssetKind? kind,
    bool withFavorite = false,
  }) {
    if (raw is! Map) throw const FormatException('Malformed asset');
    final id = raw[idKey];
    final symbol = raw['symbol'];
    final name = raw['name'];
    final assetKind = kind ?? AssetKind.fromApi(raw['type']);
    if (id is! String ||
        symbol is! String ||
        name is! String ||
        assetKind == null) {
      throw const FormatException('Malformed asset');
    }
    return AssetItem(
      id: id,
      symbol: symbol,
      name: name,
      kind: assetKind,
      isFavorite: withFavorite && raw['favorite'] == true,
      createdAt: DateTime.tryParse('${raw['createdAt'] ?? ''}'),
    );
  }
}
