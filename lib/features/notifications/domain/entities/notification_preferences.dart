import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    required this.pushEnabled,
    required this.inAppEnabled,
    required this.emailEnabled,
  });

  final bool pushEnabled;
  final bool inAppEnabled;
  final bool emailEnabled;

  @override
  List<Object?> get props => [pushEnabled, inAppEnabled, emailEnabled];
}
