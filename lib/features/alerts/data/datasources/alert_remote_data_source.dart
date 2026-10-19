import '../../../../core/network/api_client.dart';
import '../../domain/entities/price_alert.dart';

class AlertRemoteDataSource {
  const AlertRemoteDataSource(this._client);

  /// The authenticated client.
  final ApiClient _client;

  static const _path = '/api/v1/users/me/alerts';

  /// The list endpoint is a Spring page: the alerts are in `content`.
  Future<List<PriceAlert>> getAlerts() async {
    final page = await _client.get(_path, query: {'page': 0, 'size': 100});
    final content = page?['content'];
    if (content is! List) throw const FormatException('Malformed alert page');
    return [for (final item in content) _parse(item)];
  }

  Future<PriceAlert> createAlert({
    required String base,
    required String quote,
    required AlertCondition condition,
    required double targetRate,
  }) async => _parse(
    await _client.post(
      _path,
      data: {
        'base': base,
        'quote': quote,
        'condition': condition.api,
        'targetRate': targetRate,
      },
    ),
  );

  Future<PriceAlert> updateAlert(
    String id, {
    AlertCondition? condition,
    double? targetRate,
  }) async => _parse(
    await _client.patch(
      '$_path/$id',
      data: {'condition': ?condition?.api, 'targetRate': ?targetRate},
    ),
  );

  Future<void> deleteAlert(String id) => _client.delete('$_path/$id');

  static PriceAlert _parse(Object? raw) {
    if (raw is! Map) throw const FormatException('Malformed alert');
    final json = raw.cast<String, dynamic>();
    final id = json['id'];
    final base = json['base'];
    final quote = json['quote'];
    final rate = json['targetRate'];
    final condition = AlertCondition.fromApi(json['condition']);
    final status = AlertStatus.fromApi(json['status']);
    if (id is! String ||
        base is! String ||
        quote is! String ||
        rate is! num ||
        condition == null ||
        status == null) {
      throw const FormatException('Malformed alert');
    }
    DateTime? time(String key) {
      final v = json[key];
      return v is String ? DateTime.tryParse(v) : null;
    }

    return PriceAlert(
      id: id,
      base: base,
      quote: quote,
      condition: condition,
      targetRate: rate.toDouble(),
      status: status,
      createdAt: time('createdAt'),
      triggeredAt: time('triggeredAt'),
    );
  }
}
