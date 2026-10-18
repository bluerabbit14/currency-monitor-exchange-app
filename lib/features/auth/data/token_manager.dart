import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/network/token_provider.dart';
import '../domain/entities/auth_session.dart';
import 'datasources/auth_local_data_source.dart';
import 'datasources/auth_remote_data_source.dart';

/// Single owner of the stored session: loads, saves, clears and refreshes it.
///
/// The backend rotates refresh tokens (each use revokes the old one), so two
/// concurrent refreshes would invalidate each other and sign the user out.
/// All refreshes therefore share one in-flight request.
class TokenManager implements TokenProvider {
  TokenManager(this._local, this._remote, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;
  final DateTime Function() _now;

  final _changes = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;
  bool _loaded = false;
  Future<AuthSession?>? _refreshing;

  Stream<AuthSession?> get changes => _changes.stream;

  Future<AuthSession?> current() async {
    if (!_loaded) {
      _session = await _local.read();
      _loaded = true;
    }
    return _session;
  }

  Future<void> save(AuthSession session) async {
    _session = session;
    _loaded = true;
    await _local.write(session);
    _changes.add(session);
  }

  Future<void> clear() async {
    _session = null;
    _loaded = true;
    await _local.clear();
    _changes.add(null);
  }

  @override
  Future<String?> accessToken() async => (await current())?.accessToken;

  @override
  Future<String?> refreshAccessToken() async => (await refresh())?.accessToken;

  /// Renews the session. Returns the new session, or null when it could not be
  /// renewed. A rejected refresh token signs the user out; a network or server
  /// error leaves the session in place so a later attempt can succeed.
  Future<AuthSession?> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<AuthSession?> _doRefresh() async {
    final before = await current();
    if (before == null) return null;
    try {
      final tokens = await _remote.refresh(before.refreshToken);
      // The user may have signed out or in again while we waited.
      if ((await current())?.refreshToken != before.refreshToken) return null;
      final fresh = tokens.toSession(_now());
      await save(fresh);
      return fresh;
    } on ApiException catch (e) {
      if (e.statusCode >= 400 && e.statusCode < 500) {
        if ((await current())?.refreshToken == before.refreshToken) {
          await clear();
        }
      }
      // Server error: keep the session so a later attempt can succeed.
      return null;
    } on NetworkException {
      return null;
    } on FormatException {
      return null;
    }
  }

  void dispose() => _changes.close();
}
