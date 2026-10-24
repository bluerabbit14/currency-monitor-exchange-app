import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/push/push_message_source.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../alerts/presentation/pages/price_alerts_page.dart';
import '../../../auth/presentation/bloc/auth_session_cubit.dart';
import '../../../currency/domain/entities/currency.dart';
import '../../../profile/domain/usecases/get_profile.dart';
import '../../domain/entities/notification_destination.dart';

/// Opens the screen a tapped push notification points at.
///
/// A tap while signed out (or before the new account has picked its currency)
/// is held in memory and opened once the user is fully signed in. It is dropped
/// on logout, so one account's notification is never opened for another.
class NotificationNavigator {
  NotificationNavigator(
    this._source,
    this._getProfile, {
    GlobalKey<NavigatorState>? navigatorKey,
    Route<void> Function(NotificationDestination, Currency?)? routeBuilder,
    this._duplicateWindow = const Duration(seconds: 2),
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>(),
       _routeBuilder = routeBuilder ?? _defaultRoute;

  final PushMessageSource _source;
  final GetProfile _getProfile;
  final Route<void> Function(NotificationDestination, Currency?) _routeBuilder;
  final Duration _duplicateWindow;

  /// Shared with the app's [MaterialApp].
  final GlobalKey<NavigatorState> navigatorKey;

  AuthSessionCubit? _session;
  StreamSubscription<AuthSessionState>? _authSubscription;
  StreamSubscription<Map<String, String>>? _openedSubscription;
  NotificationDestination? _pending;
  String? _lastKey;
  DateTime? _lastAt;
  var _started = false;
  var _wasSignedIn = false;

  /// Call once, after the first frame (the navigator must exist).
  Future<void> start(AuthSessionCubit session) async {
    if (_started) return;
    _started = true;
    _session = session;
    _wasSignedIn = session.state is AuthSessionAuthenticated;
    _authSubscription = session.stream.listen(_onAuthChanged);
    await _source.start();
    _openedSubscription = _source.opened.listen(handle);
    final initial = await _source.initialMessage();
    if (initial != null) handle(initial);
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _openedSubscription?.cancel();
  }

  /// A notification was tapped. Invalid or unsupported payloads are ignored.
  void handle(Map<String, String> data) {
    final destination = NotificationDestination.fromData(data);
    if (destination is UnsupportedDestination) return;
    if (_isDuplicate(destination)) return;
    _pending = destination;
    unawaited(_openPending());
  }

  bool _isDuplicate(NotificationDestination destination) {
    final key = '${destination.runtimeType}:${destination.props}';
    final now = DateTime.now();
    final duplicate =
        key == _lastKey &&
        _lastAt != null &&
        now.difference(_lastAt!) < _duplicateWindow;
    _lastKey = key;
    _lastAt = now;
    return duplicate;
  }

  bool get _signedIn {
    final state = _session?.state;
    return state is AuthSessionAuthenticated && !state.needsBaseCurrency;
  }

  void _onAuthChanged(AuthSessionState state) {
    if (state is AuthSessionUnauthenticated) {
      // Logout / session loss: a destination tapped under that account must
      // not be opened for whoever signs in next.
      if (_wasSignedIn) _pending = null;
    }
    _wasSignedIn = state is AuthSessionAuthenticated;
    if (_signedIn && _pending != null) {
      // After the app has swapped its home screen and cleared the stack.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _openPending())
        ..ensureVisualUpdate();
    }
  }

  Future<void> _openPending() async {
    final destination = _pending;
    if (destination == null || !_signedIn) return;
    if (navigatorKey.currentState == null) return;
    _pending = null;

    final baseCurrency = await _baseCurrency();
    // The user may have logged out while the profile was loading.
    final navigator = navigatorKey.currentState;
    if (navigator == null || !_signedIn) return;

    navigator.popUntil((route) => route.isFirst);
    unawaited(navigator.push(_routeBuilder(destination, baseCurrency)));
  }

  Future<Currency?> _baseCurrency() async {
    final result = await _getProfile(const NoParams());
    return result.fold((_) => null, (profile) => profile.baseCurrency);
  }

  static Route<void> _defaultRoute(
    NotificationDestination destination,
    Currency? baseCurrency,
  ) => MaterialPageRoute<void>(
    builder: (_) => PriceAlertsPage(
      baseCurrency: baseCurrency,
      highlightAlertId: switch (destination) {
        PriceAlertsDestination(:final alertId) => alertId,
        UnsupportedDestination() => null,
      },
    ),
  );
}
