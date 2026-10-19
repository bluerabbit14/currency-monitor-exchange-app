import '../repositories/currency_repository.dart';

/// Warms the shared currency cache (e.g. while the login screen is open) so
/// the currency screens show instantly. Never throws and ignores the outcome:
/// a failure is simply retried when a screen asks for the list.
class PreloadCurrencies {
  const PreloadCurrencies(this.repository);

  final CurrencyRepository repository;

  Future<void> call() async {
    try {
      await repository.getCurrencies();
    } catch (_) {
      // Best effort only.
    }
  }
}
