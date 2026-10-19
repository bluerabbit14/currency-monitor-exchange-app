import 'package:country_flags/country_flags.dart';
import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/currency.dart';
import '../bloc/base_currency_cubit.dart';

/// Bottom sheet to change the base currency.
///
/// Tapping a currency only selects it. The sheet stays open, so the user can
/// keep browsing and change their mind. When it is closed (close button, swipe
/// down, tap outside or back) the last pick is saved with a single request.
///
/// Completes after the sheet is closed and the save (if any) has finished:
/// - `null` when nothing changed (no request was made),
/// - `Right(currency)` when the new currency was saved,
/// - `Left(message)` when saving failed; the old currency is still in effect.
Future<Either<String, Currency>?> showCurrencyPickerSheet(
  BuildContext context, {
  Currency? current,
}) async {
  // Owned here, not by the sheet, so it outlives the sheet and can save once
  // the sheet has been closed by any route.
  final cubit = sl<BaseCurrencyCubit>()
    ..setCurrent(current)
    ..load();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.94,
          child: BlocProvider.value(
            value: cubit,
            child: const _CurrencySheet(title: 'Your currency'),
          ),
        ),
      ),
    );

    final picked = cubit.state.selected;
    if (picked == null || picked == current) return null;
    await cubit.save();
    final state = cubit.state;
    if (state.status == BaseCurrencyStatus.saved) return Right(picked);
    return Left(state.error ?? 'Unable to update your currency');
  } finally {
    await cubit.close();
  }
}

/// Bottom sheet that only *chooses* a currency (nothing is saved). Returns the
/// pick when the sheet is closed, or null when nothing was picked. Currencies
/// in [excludeCodes] are not offered.
Future<Currency?> chooseCurrency(
  BuildContext context, {
  Currency? current,
  Set<String> excludeCodes = const {},
  String title = 'Add Currency',
}) async {
  final cubit = sl<BaseCurrencyCubit>()
    ..setCurrent(current)
    ..load();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.94,
          child: BlocProvider.value(
            value: cubit,
            child: _CurrencySheet(title: title, exclude: excludeCodes),
          ),
        ),
      ),
    );
    return cubit.state.selected;
  } finally {
    await cubit.close();
  }
}

const _fieldColor = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _accent = Color(0xFF2F6FED);

/// Shown first, in this order, when the backend has them.
const _popularCodes = [
  'INR',
  'USD',
  'EUR',
  'GBP',
  'JPY',
  'CNY',
  'CHF',
  'CAD',
  'AUD',
];

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.title, this.exclude = const {}});

  final String title;
  final Set<String> exclude;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BaseCurrencyCubit, BaseCurrencyState>(
      builder: (context, state) {
        final q = _query.trim().toLowerCase();
        final searching = q.isNotEmpty;
        final all = state.currencies
            .where((c) => !widget.exclude.contains(c.code))
            .toList();
        final popular = [
          for (final code in _popularCodes) ...all.where((c) => c.code == code),
        ];
        final popularIds = popular.map((c) => c.id).toSet();
        final results = all
            .where(
              (c) =>
                  c.code.toLowerCase().contains(q) ||
                  c.name.toLowerCase().contains(q),
            )
            .toList();
        final others = all.where((c) => !popularIds.contains(c.id)).toList();

        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            _Header(
              title: widget.title,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Hero(currency: state.selected)),
                  SliverToBoxAdapter(
                    child: _SearchField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  ..._content(
                    context,
                    state,
                    searching,
                    results,
                    popular,
                    others,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    BaseCurrencyState state,
    bool searching,
    List<Currency> results,
    List<Currency> popular,
    List<Currency> others,
  ) {
    if (state.status == BaseCurrencyStatus.loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.status == BaseCurrencyStatus.loadFailed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
        ),
      ];
    }

    Widget tile(Currency c, {required bool compact}) => _CurrencyTile(
      currency: c,
      compact: compact,
      selected: state.selected?.id == c.id,
      onTap: () => context.read<BaseCurrencyCubit>().select(c),
    );

    if (searching) {
      if (results.isEmpty) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No currencies found',
                style: TextStyle(color: _muted),
              ),
            ),
          ),
        ];
      }
      return [
        const _SectionTitle('RESULTS'),
        _CardList(children: [for (final c in results) tile(c, compact: false)]),
      ];
    }

    return [
      if (popular.isNotEmpty) ...[
        const _SectionTitle('POPULAR'),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          // A fixed row height (not an aspect ratio, which would shrink the
          // tile's height as the cells get narrower on small phones).
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 56,
            ),
            delegate: SliverChildListDelegate([
              for (final c in popular) tile(c, compact: true),
            ]),
          ),
        ),
      ],
      if (others.isNotEmpty) ...[
        const _SectionTitle('OTHER'),
        _CardList(children: [for (final c in others) tile(c, compact: false)]),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: const Color(0x22000000),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onClose,
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.close_rounded, size: 24),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.currency});

  final Currency? currency;

  @override
  Widget build(BuildContext context) {
    final c = currency;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        children: [
          SizedBox(
            height: 78,
            child: c == null
                ? const Icon(Icons.public_rounded, size: 64, color: _muted)
                : CountryFlag.fromCurrencyCode(
                    c.code,
                    theme: const EmojiTheme(size: 64),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            c?.code ?? 'Select a currency',
            style: TextStyle(
              fontSize: c == null ? 20 : 30,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          if (c != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                c.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: _muted),
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search currency...',
          hintStyle: const TextStyle(color: _muted),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted),
          filled: true,
          fillColor: _fieldColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: _muted,
          ),
        ),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.separated(
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({
    required this.currency,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;

  /// Compact: flag + code in a grid cell. Otherwise a full-width card that
  /// also shows the currency name.
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final flag = SizedBox(
      width: compact ? 32 : 40,
      child: CountryFlag.fromCurrencyCode(
        currency.code,
        theme: EmojiTheme(size: compact ? 24 : 30),
      ),
    );
    final trailing = selected
        ? Icon(
            Icons.check_circle_rounded,
            size: compact ? 16 : 20,
            color: _accent,
          )
        : null;

    return Material(
      color: _fieldColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        side: BorderSide(
          color: selected ? _accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 18 : 20),
        ),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 18,
            vertical: compact ? 0 : 14,
          ),
          child: compact
              // The cell is only ~90px wide on small phones, so the flag + code
              // scale down to fit instead of overflowing, and the check mark
              // sits in the corner rather than widening the row.
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            flag,
                            const SizedBox(width: 6),
                            Text(
                              currency.code,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (trailing != null)
                      Positioned(top: 5, right: 0, child: trailing),
                  ],
                )
              : Row(
                  children: [
                    flag,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currency.code,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            currency.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
        ),
      ),
    );
  }
}
