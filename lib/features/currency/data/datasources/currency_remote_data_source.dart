import '../../../../core/network/api_client.dart';
import '../../domain/entities/currency.dart';

class CurrencyRemoteDataSource {
  const CurrencyRemoteDataSource(this._client);

  /// The authenticated client: the list is public, saving the base currency
  /// is not, and one client keeps token refresh in one place.
  final ApiClient _client;

  Future<List<Currency>> getCurrencies() async {
    final items = await _client.getList('/api/v1/currencies');
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _parse(item) else throw _malformed,
    ];
  }

  Future<void> setBaseCurrency(String currencyId) async {
    await _client.put(
      '/api/v1/users/me/base-currency',
      data: {'currencyId': currencyId},
    );
  }

  static const _malformed = FormatException('Malformed currency');

  static Currency _parse(Map<String, dynamic> json) {
    final id = json['id'];
    final code = json['symbol'];
    final name = json['name'];
    if (id is! String || code is! String || name is! String) {
      throw _malformed;
    }
    return Currency(id: id, code: code, name: name);
  }
}
