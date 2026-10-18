import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_session_cubit.dart';
import '../../../profile/presentation/bloc/profile_cubit.dart';
import '../../../profile/presentation/widgets/profile_header.dart';

/// Rows are display-only for now: no tap actions are wired up yet.
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
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
            const ProfileHeader(),
            const SizedBox(height: 20),
            const _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  value: 'Off',
                ),
                _SettingsRow(
                  icon: Icons.attach_money_rounded,
                  title: 'Your currency',
                  value: 'AED',
                  circledIcon: true,
                ),
                _SettingsRow(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Start screen',
                  value: 'Converter',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SettingsCard(
              children: [
                _SettingsRow(icon: Icons.feedback_outlined, title: 'Feedback'),
                _SettingsRow(
                  icon: Icons.star_border_rounded,
                  title: 'Rate app',
                ),
                _SettingsRow(icon: Icons.ios_share_rounded, title: 'Share app'),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
  });

  final IconData icon;
  final String title;
  final String? value;

  /// Draws the icon inside a thin ring, like the currency row.
  final bool circledIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            Text(
              value!,
              style: const TextStyle(fontSize: 15, color: Color(0xFF9A9AA2)),
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
    );
  }
}
