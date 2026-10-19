import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/format/number_format.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/presentation/widgets/asset_flag.dart';
import '../../../favourite/presentation/widgets/asset_search_and_tabs.dart';
import '../bloc/browse_cubit.dart';

/// Every active asset, by type, priced in the user's base currency, with a
/// search box. The title, search and tabs stay put; only the list scrolls.
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BrowseCubit>()..load(),
      child: const _BrowseView(),
    );
  }
}

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _up = Color(0xFF34B35B);
const _down = Color(0xFFE5383B);

class _BrowseView extends StatefulWidget {
  const _BrowseView();

  @override
  State<_BrowseView> createState() => _BrowseViewState();
}

class _BrowseViewState extends State<_BrowseView> {
  final _search = TextEditingController();
  String _query = '';
  AssetKind _kind = AssetKind.fiat;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      // No keyboard-driven resizing: the list scrolls under the keyboard and
      // the fixed top part must not be squeezed.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<BrowseCubit, BrowseState>(
          // A failed pull-to-refresh keeps the list and says why.
          listenWhen: (previous, current) =>
              current.status == BrowseStatus.ready &&
              current.error != null &&
              current.error != previous.error,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!))),
          builder: (context, state) => LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                // Capped so a very short screen (landscape, large text) cannot
                // overflow; the fixed part scrolls in that case.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.6,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 36, bottom: 16),
                          child: Text(
                            'Browse',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AssetSearchField(
                          controller: _search,
                          raised: false,
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        const SizedBox(height: 16),
                        AssetKindTabs(
                          selected: _kind,
                          onSelected: (kind) => setState(() => _kind = kind),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _list(context, state)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, BrowseState state) {
    final cubit = context.read<BrowseCubit>();
    switch (state.status) {
      case BrowseStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case BrowseStatus.loadFailed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.error ?? 'Unable to load assets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: cubit.load, child: const Text('Retry')),
              ],
            ),
          ),
        );
      case BrowseStatus.ready:
        final q = _query.trim().toLowerCase();
        final items = state
            .assetsOf(_kind)
            .where(
              (a) =>
                  q.isEmpty ||
                  a.symbol.toLowerCase().contains(q) ||
                  a.name.toLowerCase().contains(q),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () => cubit.load(refresh: true),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'Nothing found',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Room for the floating navigation bar.
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 56,
                    color: Color(0xFFE0E0E6),
                  ),
                  itemBuilder: (context, i) => _AssetRow(
                    key: ValueKey(items[i].id),
                    asset: items[i],
                    quoteCurrency: state.quoteCurrency,
                    quote: state.quotes[items[i].id],
                  ),
                ),
        );
    }
  }
}

/// One asset. Asks for its price when it is first built, i.e. when scrolled
/// into view.
class _AssetRow extends StatefulWidget {
  const _AssetRow({
    super.key,
    required this.asset,
    required this.quoteCurrency,
    required this.quote,
  });

  final AssetItem asset;
  final String quoteCurrency;
  final BrowseQuote? quote;

  @override
  State<_AssetRow> createState() => _AssetRowState();
}

class _AssetRowState extends State<_AssetRow> {
  @override
  void initState() {
    super.initState();
    // After the frame: the cubit emits, which must not happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BrowseCubit>().ensureQuote(widget.asset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          AssetFlag(asset: asset),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Capped so long prices ellipsize instead of overflowing the row.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.5,
            ),
            child: _Price(
              quote: widget.quote,
              quoteCurrency: widget.quoteCurrency,
            ),
          ),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.quote, required this.quoteCurrency});

  final BrowseQuote? quote;
  final String quoteCurrency;

  @override
  Widget build(BuildContext context) {
    final q = quote?.quote;
    if (q == null) {
      // Not asked yet / still loading, or the price could not be fetched.
      return Text(
        quote?.failed == true ? '—' : '···',
        style: const TextStyle(fontSize: 17, color: _muted),
      );
    }
    final change = q.change;
    final moved = change != null && formatPrice(change.abs()) != '0.00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatMoney(q.rate, quoteCurrency),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (change != null) ...[
          const SizedBox(height: 2),
          Text(
            formatMoneyChange(change, quoteCurrency),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: moved && change < 0 ? _down : _up,
            ),
          ),
        ],
      ],
    );
  }
}
