import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/notifications_cubit.dart';

/// What the Notifications sheet reports when it closes.
class NotificationsSheetResult {
  const NotificationsSheetResult({this.pushEnabled, this.openAlerts = false});

  /// The push setting as last confirmed with the backend, or null if it was
  /// never loaded (so the caller should leave what it shows alone).
  final bool? pushEnabled;

  /// The user tapped "My Alerts" and wants the alerts screen.
  final bool openAlerts;
}

/// Notifications bottom sheet: "My Alerts" (opens the alerts screen) and the
/// push-notifications switch. [pushEnabled] is the value already known from the
/// profile, so the switch is correct before the preferences load.
Future<NotificationsSheetResult> showNotificationsSheet(
  BuildContext context, {
  bool? pushEnabled,
}) async {
  final cubit = sl<NotificationsCubit>()
    ..seed(pushEnabled)
    ..load();
  var openAlerts = false;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: _NotificationsSheet(
          onOpenAlerts: () {
            openAlerts = true;
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
    final ready = cubit.state.status == NotificationsStatus.ready;
    return NotificationsSheetResult(
      pushEnabled: ready ? cubit.state.pushEnabled : null,
      openAlerts: openAlerts,
    );
  } finally {
    await cubit.close();
  }
}

const _sheetColor = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.onOpenAlerts});

  final VoidCallback onOpenAlerts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 22, 4, 16),
              child: Text(
                'Notifications',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            _OptionCard(
              icon: Icons.track_changes_rounded,
              iconColor: const Color(0xFF1E88FF),
              tint: const Color(0xFFD6E9FF),
              title: 'My Alerts',
              subtitle: 'Get notified when price reaches your target',
              onTap: onOpenAlerts,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9A9AA2),
              ),
            ),
            const SizedBox(height: 14),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              builder: (context, state) => _PushCard(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushCard extends StatelessWidget {
  const _PushCard({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == NotificationsStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status == NotificationsStatus.loadFailed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                state.error ?? 'Unable to load your notification settings',
                style: const TextStyle(color: _muted),
              ),
            ),
            TextButton(
              onPressed: context.read<NotificationsCubit>().load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OptionCard(
          icon: Icons.show_chart_rounded,
          iconColor: const Color(0xFFFF8A1F),
          tint: const Color(0xFFFFE6D0),
          title: 'Significant Changes',
          subtitle: 'Push when an asset from Favorites changes sharply',
          onTap: state.isUpdating
              ? null
              : () => context.read<NotificationsCubit>().setPush(
                  !state.pushEnabled,
                ),
          trailing: Transform.scale(
            scale: 0.75,
            child: Switch.adaptive(
              value: state.pushEnabled,
              onChanged: state.isUpdating
                  ? null
                  : context.read<NotificationsCubit>().setPush,
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Text(
              state.error!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFD93025)),
            ),
          ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
