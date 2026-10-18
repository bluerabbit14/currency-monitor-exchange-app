import '../../domain/entities/conversion.dart';

class ConversionException implements Exception {
  const ConversionException(this.message);

  final String message;
}

class ConverterLocalDataSource {
  /// Units of each currency equal to 1 USD.
  static const rates = <String, double>{
    'USD': 1,
    'EUR': 0.92,
    'GBP': 0.78,
    'INR': 83,
  };

  Conversion convert({
    required double amount,
    required String from,
    required String to,
  }) {
    final fromRate = rates[from];
    final toRate = rates[to];
    if (fromRate == null || toRate == null) {
      throw const ConversionException('Unsupported currency');
    }

    return Conversion(
      amount: amount,
      from: from,
      to: to,
      result: amount * (toRate / fromRate),
    );
  }
}
