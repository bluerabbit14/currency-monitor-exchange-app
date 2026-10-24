import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_session_cubit.dart';
import '../../../alerts/presentation/pages/price_alerts_page.dart';
import '../../../currency/presentation/widgets/currency_picker_sheet.dart';
import '../../../feedback/presentation/widgets/feedback_sheet.dart';
import '../../../notifications/presentation/widgets/notifications_sheet.dart';
import '../../../profile/presentation/bloc/profile_cubit.dart';
import '../../../profile/presentation/widgets/profile_header.dart';
import '../../domain/entities/start_screen.dart';
import '../bloc/start_screen_cubit.dart';
import '../widgets/start_screen_sheet.dart';

/// "Your currency" opens the currency sheet. The other rows are display-only
/// for now: no tap actions are wired up yet.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _background = Color(0xFFF1F1F6);

  Future<void> _confirmLogout(BuildContext context) async {
    final session = context.read<AuthSessionCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to use your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileCubit>()..load(),
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            const ProfileHeader(),
            const SizedBox(height: 20),
            _SettingsCard(
              children: [
                const _NotificationsRow(),
                const _CurrencyRow(),
                const _StartScreenRow(),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsCard(
              children: [
                const _FeedbackRow(),
                const _SettingsRow(
                  icon: Icons.star_border_rounded,
                  title: 'Rate app',
                ),
                const _SettingsRow(
                  icon: Icons.ios_share_rounded,
                  title: 'Share app',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => _confirmLogout(context),
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A8A93),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows whether notifications are on and opens the Notifications sheet, from
/// where the user can switch push on/off or go to their price alerts.
class _NotificationsRow extends StatelessWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final loaded = state is ProfileLoaded ? state.profile : null;
        final enabled = loaded?.notificationsEnabled;
        return _SettingsRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          value: enabled == null ? null : (enabled ? 'On' : 'Off'),
          onTap: () async {
            final profile = context.read<ProfileCubit>();
            final navigator = Navigator.of(context);
            final result = await showNotificationsSheet(
              context,
              pushEnabled: enabled,
            );
            final pushEnabled = result.pushEnabled;
            if (pushEnabled != null && pushEnabled != enabled) {
              profile.notificationsChanged(pushEnabled);
            }
            if (result.openAlerts) {
              final current = profile.state;
              await navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => PriceAlertsPage(
                    baseCurrency: current is ProfileLoaded
                        ? current.profile.baseCurrency
                        : null,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

/// Opens the feedback sheet and confirms with a snackbar once it was sent.
class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow();

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: Icons.feedback_outlined,
      title: 'Feedback',
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final sent = await showFeedbackSheet(context);
        if (sent) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Thanks for your feedback.')),
            );
        }
      },
    );
  }
}

/// Shows the chosen start screen and opens the sheet to change it. Saved on
/// the device only.
class _StartScreenRow extends StatelessWidget {
  const _StartScreenRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StartScreenCubit, StartScreen>(
      bloc: sl<StartScreenCubit>(),
      builder: (context, screen) => _SettingsRow(
        icon: Icons.auto_awesome_rounded,
        title: 'Start screen',
        value: screen.title,
        onTap: () => showStartScreenSheet(context),
      ),
    );
  }
}

/// Shows the saved base currency and opens the picker sheet to change it.
class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final current = state is ProfileLoaded
            ? state.profile.baseCurrency
            : null;
        return _SettingsRow(
          icon: Icons.attach_money_rounded,
          title: 'Your currency',
          value: current?.code,
          circledIcon: true,
          onTap: () async {
            final profile = context.read<ProfileCubit>();
            final messenger = ScaffoldMessenger.of(context);
            final result = await showCurrencyPickerSheet(
              context,
              current: current,
            );
            result?.fold(
              (message) => messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Couldn\'t update your currency. $message'),
                  ),
                ),
              profile.baseCurrencyChanged,
            );
          },
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.circledIcon = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;

  /// Draws the icon inside a thin ring, like the currency row.
  final bool circledIcon;

  /// Null for rows with no action yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: circledIcon
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(width: 2),
                      ),
                      child: Icon(icon, size: 18, color: Colors.black),
                    )
                  : Icon(icon, size: 26, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            if (value != null) ...[
              // Capped so a long value (or large text) ellipsizes instead of
              // pushing the row wider than the screen.
              LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                  ),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9A9AA2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: Color(0xFF9A9AA2),
            ),
          ],
        ),
      ),
    );
  }
}
