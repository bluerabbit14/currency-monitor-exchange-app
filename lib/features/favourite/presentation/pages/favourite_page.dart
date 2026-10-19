import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/format/number_format.dart';
import '../bloc/favorites_cubit.dart';
import '../widgets/asset_flag.dart';
import '../widgets/asset_picker_sheet.dart';

/// The user's favorite assets, each priced in their base currency with its
/// 24-hour change. Pull to refresh, swipe a row left to remove it, "+" to add.
class FavouritePage extends StatelessWidget {
  const FavouritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FavoritesCubit>()..load(),
      child: const _FavoritesView(),
    );
  }
}

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _up = Color(0xFF34B35B);
const _down = Color(0xFFE5383B);

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<FavoritesCubit>();
    final picked = await showAssetPickerSheet(
      context,
      excludeIds: {for (final r in cubit.state.rows) r.asset.id},
    );
    if (picked == null || !context.mounted) return;
    final error = await cubit.add(picked);
    if (error != null && context.mounted) {
      _snack(context, "Couldn't add ${picked.symbol}. $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<FavoritesCubit, FavoritesState>(
          // A failed pull-to-refresh keeps the rows and says why.
          listenWhen: (previous, current) =>
              current.status == FavoritesStatus.ready &&
              current.error != null &&
              current.error != previous.error,
          listener: (context, state) => _snack(context, state.error!),
          builder: (context, state) {
            final cubit = context.read<FavoritesCubit>();
            return RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _Header(onAdd: () => _add(context)),
                  const SizedBox(height: 20),
                  ..._content(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FavoritesState state) {
    final cubit = context.read<FavoritesCubit>();
    switch (state.status) {
      case FavoritesStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      case FavoritesStatus.loadFailed:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Text(
                  state.error ?? 'Unable to load your favorites',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: cubit.load, child: const Text('Retry')),
              ],
            ),
          ),
        ];
      case FavoritesStatus.ready:
        if (state.rows.isEmpty) {
          return [_EmptyState(onAdd: () => _add(context))];
        }
        return [
          for (var i = 0; i < state.rows.length; i++) ...[
            Dismissible(
              key: ValueKey(state.rows[i].asset.id),
              direction: DismissDirection.endToStart,
              background: const _DeleteBackground(),
              confirmDismiss: (_) async {
                final error = await cubit.remove(state.rows[i].asset.id);
                if (error != null && context.mounted) {
                  _snack(
                    context,
                    "Couldn't remove ${state.rows[i].asset.symbol}. $error",
                  );
                }
                return error == null;
              },
              onDismissed: (_) => cubit.dropRow(state.rows[i].asset.id),
              child: _FavoriteTile(
                row: state.rows[i],
                quoteCurrency: state.quoteCurrency,
              ),
            ),
            if (i < state.rows.length - 1)
              const Divider(height: 1, indent: 48, color: Color(0xFFE0E0E6)),
          ],
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 36),
            child: Text(
              'Favorites',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x22000000),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAdd,
            child: const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _down,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: Color(0xFFC4C4C9),
          ),
          const SizedBox(height: 20),
          const Text(
            'No favorites yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add currencies, coins or metals to follow their prices here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _muted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add favorite'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.row, required this.quoteCurrency});

  final FavoriteRow row;
  final String quoteCurrency;

  @override
  Widget build(BuildContext context) {
    final asset = row.asset;
    return Container(
      // Opaque, so the swipe-to-delete background is hidden until dragged.
      color: _background,
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
            child: _Price(row: row, quoteCurrency: quoteCurrency),
          ),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.row, required this.quoteCurrency});

  final FavoriteRow row;
  final String quoteCurrency;

  @override
  Widget build(BuildContext context) {
    final quote = row.quote;
    if (quote == null) {
      // Still loading, or the price could not be fetched.
      return Text(
        row.quoteFailed ? '—' : '···',
        style: const TextStyle(fontSize: 17, color: _muted),
      );
    }
    final change = quote.change;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${formatPrice(quote.rate)}$quoteCurrency',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (change != null) ...[
          const SizedBox(height: 2),
          Text(
            '${formatChange(change)}$quoteCurrency',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: change < 0 && formatChange(change) != '0.00' ? _down : _up,
            ),
          ),
        ],
      ],
    );
  }
}
