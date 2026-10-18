import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_profile.dart';
import '../bloc/profile_cubit.dart';

/// Profile card for the top of Settings: photo (or placeholder), display name
/// when there is one, and the email, or the phone number if there is no email.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) => switch (state) {
          ProfileLoading() => const _Skeleton(),
          ProfileLoaded(:final profile) => _Content(profile: profile),
          ProfileError(:final message) => _Error(
            message: message,
            onRetry: context.read<ProfileCubit>().load,
          ),
        },
      ),
    );
  }
}

const _avatarSize = 56.0;

class _Content extends StatelessWidget {
  const _Content({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName;
    final contact = profile.contact;
    // With no display name the contact becomes the headline instead of
    // repeating it on two lines.
    final headline = name ?? contact ?? 'Signed in';
    final subtitle = name != null ? contact : null;

    return Row(
      children: [
        _Avatar(url: profile.profileImageUrl),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A8A93),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  static const _placeholderColor = Color(0xFFE6E6EB);

  Widget get _placeholder => const DecoratedBox(
    decoration: BoxDecoration(color: _placeholderColor),
    child: Icon(Icons.person_rounded, size: 32, color: Color(0xFF9A9AA2)),
  );

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    final valid =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');

    return SizedBox.square(
      dimension: _avatarSize,
      child: ClipOval(
        child: valid
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                // Falls back to the placeholder while loading and on failure
                // (offline, 404, blocked by the host).
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _placeholder,
                errorBuilder: (context, error, stack) => _placeholder,
              )
            : _placeholder,
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  static const _color = Color(0xFFE6E6EB);

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Row(
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: const BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [bar(130, 16), const SizedBox(height: 8), bar(180, 12)],
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFF9A9AA2)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8A8A93)),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
