import 'package:equatable/equatable.dart';

/// Where tapping a push notification should take the user.
///
/// Built from the FCM `data` map the backend sends (see the backend's
/// `NotificationPayload`): `type` plus the ids of the resource. Every type the
/// backend can send must map to a destination here; anything else is
/// [UnsupportedDestination] and is ignored.
sealed class NotificationDestination extends Equatable {
  const NotificationDestination();

  /// Never throws: a missing / unknown `type` or a malformed id never opens
  /// anything.
  factory NotificationDestination.fromData(Map<String, String> data) {
    switch (data['type']) {
      case 'PRICE_ALERT':
        final alertId = data['alertId'];
        if (alertId != null && !_isUuid(alertId)) {
          return const UnsupportedDestination();
        }
        return PriceAlertsDestination(alertId: alertId);
      default:
        return const UnsupportedDestination();
    }
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _isUuid(String value) => _uuid.hasMatch(value);
}

/// The price alerts list. [alertId], when given, is the alert that fired; the
/// list shows it highlighted, or says it no longer exists.
class PriceAlertsDestination extends NotificationDestination {
  const PriceAlertsDestination({this.alertId});

  final String? alertId;

  @override
  List<Object?> get props => [alertId];
}

class UnsupportedDestination extends NotificationDestination {
  const UnsupportedDestination();

  @override
  List<Object?> get props => [];
}
