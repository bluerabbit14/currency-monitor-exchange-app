import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../settings/presentation/bloc/start_screen_cubit.dart';

import '../../../browse/presentation/pages/browse_page.dart';
import '../../../converter/presentation/pages/converter_page.dart';
import '../../../favourite/presentation/pages/favourite_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../widgets/floating_nav_bar.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  /// Opens on the start screen the user chose in Settings (Converter by
  /// default).
  late int _index = sl<StartScreenCubit>().state.tabIndex;

  /// Tabs the user has opened. A tab is only built the first time it is
  /// selected, so nothing a tab loads (e.g. the profile on Settings) happens
  /// at app launch. Visited tabs then stay alive in the [IndexedStack].
  late final _visited = <int>{_index};

  static const _pageBuilders = <WidgetBuilder>[
    _converter,
    _browse,
    _favourite,
    _settings,
  ];

  static Widget _converter(BuildContext _) => const ConverterPage();
  static Widget _browse(BuildContext _) => const BrowsePage();
  static Widget _favourite(BuildContext _) => const FavouritePage();
  static Widget _settings(BuildContext _) => const SettingsPage();

  static const _items = [
    FloatingNavItem(
      icon: Icons.swap_horiz_rounded,
      selectedIcon: Icons.swap_horiz_rounded,
      label: 'Converter',
    ),
    FloatingNavItem(
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
      label: 'Browse',
    ),
    FloatingNavItem(
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      label: 'Favorites',
    ),
    FloatingNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F6),
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pageBuilders.length; i++)
            _visited.contains(i) ? _pageBuilders[i](context) : const SizedBox(),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        items: _items,
        currentIndex: _index,
        onSelected: (index) => setState(() {
          _index = index;
          _visited.add(index);
        }),
      ),
    );
  }
}
