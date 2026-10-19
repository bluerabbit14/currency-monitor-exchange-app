import 'package:flutter/material.dart';

/// The tab the app opens on. Kept on the device only; the backend knows
/// nothing about it.
enum StartScreen {
  converter(
    title: 'Converter',
    subtitle: 'Convert currencies instantly',
    icon: Icons.swap_horiz_rounded,
    tabIndex: 0,
  ),
  browse(
    title: 'Browse',
    subtitle: 'Explore all currencies and crypto',
    icon: Icons.search_rounded,
    tabIndex: 1,
  ),
  favorites(
    title: 'Favorites',
    subtitle: 'Quick access to your picks',
    icon: Icons.favorite_rounded,
    tabIndex: 2,
  );

  const StartScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tabIndex,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Position of the matching tab in the home shell.
  final int tabIndex;

  /// What a fresh install, or an unreadable saved value, opens on.
  static const defaultScreen = StartScreen.converter;

  static StartScreen fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return defaultScreen;
  }
}
