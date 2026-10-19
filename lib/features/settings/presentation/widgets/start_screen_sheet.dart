import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/start_screen.dart';
import '../bloc/start_screen_cubit.dart';

/// Bottom sheet to choose which screen the app opens on. Tapping an option
/// saves it and closes the sheet.
Future<void> showStartScreenSheet(BuildContext context) {
  final cubit = sl<StartScreenCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) =>
        BlocProvider.value(value: cubit, child: const _StartScreenSheet()),
  );
}

const _blue = Color(0xFF0A84FF);
const _muted = Color(0xFF6E6E76);
const _card = Color(0xFFF1F1F6);

class _StartScreenSheet extends StatelessWidget {
  const _StartScreenSheet();

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<StartScreenCubit>().state;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 22),
            for (final screen in StartScreen.values) ...[
              _Option(
                screen: screen,
                selected: screen == selected,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await context.read<StartScreenCubit>().select(screen);
                  navigator.pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.screen,
    required this.selected,
    required this.onTap,
  });

  final StartScreen screen;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _blue.withValues(alpha: 0.08) : _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: selected
            ? const BorderSide(color: Color(0xFF7DB8FF), width: 2.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: selected
                    ? _blue.withValues(alpha: 0.18)
                    : const Color(0xFFE3E3E8),
                child: Icon(
                  screen.icon,
                  size: 22,
                  color: selected ? _blue : const Color(0xFF3A3A3C),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      screen.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      screen.subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? _blue : const Color(0xFFC7C7CC),
          width: selected ? 3 : 2,
        ),
      ),
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _blue,
              ),
            )
          : null,
    );
  }
}
