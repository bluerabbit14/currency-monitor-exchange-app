import 'package:currency/core/di/injection.dart';
import 'package:currency/core/error/failures.dart';
import 'package:currency/features/converter/domain/entities/conversion.dart';
import 'package:currency/features/converter/domain/repositories/converter_repository.dart';
import 'package:dartz/dartz.dart';

/// A Converter that starts empty (nothing saved) and prices every pair at 1.
class FakeConverterRepository implements ConverterRepository {
  ConverterSession? session = const ConverterSession();
  final requests = <String>[];

  @override
  Future<Either<Failure, ConverterRate>> getRate({
    required String from,
    required String to,
    bool refresh = false,
  }) async {
    requests.add('$from/$to');
    return const Right(ConverterRate(rate: 1));
  }

  @override
  Future<ConverterSession?> loadSession() async => session;

  @override
  Future<void> saveSession(ConverterSession session) async =>
      this.session = session;
}

/// Replaces the network-backed converter repository registered by `init()`, so
/// the Converter tab settles without touching the network or the device.
Future<FakeConverterRepository> useFakeConverterRepository() async {
  final fake = FakeConverterRepository();
  await sl.unregister<ConverterRepository>();
  sl.registerLazySingleton<ConverterRepository>(() => fake);
  return fake;
}
