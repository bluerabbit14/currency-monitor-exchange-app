import '../../../../core/network/api_client.dart';
import '../../domain/entities/conversion.dart';

class ConverterRemoteDataSource {
  const ConverterRemoteDataSource(this._client);

  final ApiClient _client;

  /// `GET /api/v1/rates/{base}/{quote}`. The backend derives pairs it does not
  /// store (through USD).
  Future<ConverterRate> getRate(String base, String quote) async {
    final body = await _client.get(
      '/api/v1/rates/${Uri.encodeComponent(base)}/${Uri.encodeComponent(quote)}',
    );
    final rate = body?['rate'];
    if (rate is! num) throw const FormatException('Malformed rate');
    return ConverterRate(
      rate: rate.toDouble(),
      fetchedAt: DateTime.tryParse('${body?['fetchedAt'] ?? ''}'),
    );
  }
}
