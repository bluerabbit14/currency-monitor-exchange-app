import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_session_cubit.dart';
import '../../domain/entities/currency.dart';
import '../bloc/base_currency_cubit.dart';

/// Shown right after a new account is created, instead of the app: the user
/// has to choose a base currency before continuing. There is no back button
/// and no way to skip it.
class BaseCurrencyPage extends StatelessWidget {
  const BaseCurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BaseCurrencyCubit>()..load(),
      child: const _BaseCurrencyView(),
    );
  }
}

class _BaseCurrencyView extends StatefulWidget {
  const _BaseCurrencyView();

  @override
  State<_BaseCurrencyView> createState() => _BaseCurrencyViewState();
}

class _BaseCurrencyViewState extends State<_BaseCurrencyView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Currency> _filtered(List<Currency> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.code.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: BlocConsumer<BaseCurrencyCubit, BaseCurrencyState>(
            listenWhen: (previous, current) =>
                current.status != previous.status,
            listener: (context, state) {
              if (state.status == BaseCurrencyStatus.saved) {
                // The app swaps this page for the home screen.
                context.read<AuthSessionCubit>().baseCurrencySelected();
              }
            },
            builder: (context, state) {
              // Header and search scroll with the list, so large text or a short
              // screen can never squeeze the list out of its space. Only the
              // Continue button stays pinned.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: _Header()),
                        SliverToBoxAdapter(
                          child: _SearchField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        _Body(state: state, items: _filtered),
                      ],
                    ),
                  ),
                  _ContinueBar(state: state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your currency',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rates are shown against it. You can change it later.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8A8A93)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search currency',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: const Color(0xFFF1F1F6),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// The list area, as a sliver.
class _Body extends StatelessWidget {
  const _Body({required this.state, required this.items});

  final BaseCurrencyState state;
  final List<Currency> Function(List<Currency>) items;

  static Widget _centered(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case BaseCurrencyStatus.loading:
        return _centered(const CircularProgressIndicator());
      case BaseCurrencyStatus.loadFailed:
        return _centered(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.error ?? 'Unable to load currencies',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: context.read<BaseCurrencyCubit>().load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case BaseCurrencyStatus.ready:
      case BaseCurrencyStatus.saving:
      case BaseCurrencyStatus.saved:
        final list = items(state.currencies);
        if (list.isEmpty) {
          return _centered(
            const Text(
              'No currencies found',
              style: TextStyle(color: Color(0xFF8A8A93)),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.only(bottom: 8),
          sliver: SliverList.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => _CurrencyTile(
              currency: list[i],
              selected: state.selected?.id == list[i].id,
              onTap: state.isSaving
                  ? null
                  : () => context.read<BaseCurrencyCubit>().select(list[i]),
            ),
          ),
        );
    }
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // Emoji flag looked up from the currency code; a placeholder is
            // shown for codes with no country (metals, supranational, etc.).
            SizedBox(
              width: 36,
              child: CountryFlag.fromCurrencyCode(
                currency.code,
                theme: const EmojiTheme(size: 30),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency.code,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    currency.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8A8A93),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2F6FED)),
          ],
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.state});

  final BaseCurrencyState state;

  @override
  Widget build(BuildContext context) {
    final enabled = state.selected != null && !state.isSaving;
    // A failed save is reported right above the button (a snack bar would
    // cover it) and cleared as soon as the user picks again.
    final saveError = state.status == BaseCurrencyStatus.ready
        ? state.error
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                saveError,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFD93025)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: enabled
                  ? context.read<BaseCurrencyCubit>().save
                  : null,
              child: state.isSaving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      state.selected == null
                          ? 'Select a currency'
                          : 'Continue with ${state.selected!.code}',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
