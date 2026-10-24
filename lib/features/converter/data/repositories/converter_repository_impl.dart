import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/conversion.dart';
import '../../domain/repositories/converter_repository.dart';
import '../datasources/converter_local_data_source.dart';
import '../datasources/converter_remote_data_source.dart';

class ConverterRepositoryImpl implements ConverterRepository {
  ConverterRepositoryImpl(
    this.remote,
    this.local, {
    DateTime Function()? now,
    this.cacheFor = const Duration(seconds: 60),
  }) : _now = now ?? DateTime.now;

  final ConverterRemoteDataSource remote;
  final ConverterLocalDataSource local;
  final Duration cacheFor;
  final DateTime Function() _now;

  /// The backend has no bulk rate call, so answers are kept briefly: switching
  /// rows back and forth does not repeat requests.
  final _cache = <String, ({ConverterRate rate, DateTime at})>{};

  @override
  Future<Either<Failure, ConverterRate>> getRate({
    required String from,
    required String to,
    bool refresh = false,
  }) async {
    // An asset priced in itself is always 1; the backend has no such pair.
    if (from.toUpperCase() == to.toUpperCase()) {
      return const Right(ConverterRate(rate: 1));
    }
    final key = '${from.toUpperCase()}/${to.toUpperCase()}';
    final cached = _cache[key];
    if (!refresh && cached != null && _now().difference(cached.at) < cacheFor) {
      return Right(cached.rate);
    }
    final result = await guardApi(() => remote.getRate(from, to));
    result.fold((_) {}, (rate) => _cache[key] = (rate: rate, at: _now()));
    return result;
  }

  @override
  Future<ConverterSession?> loadSession() => local.read();

  @override
  Future<void> saveSession(ConverterSession session) => local.write(session);
}
