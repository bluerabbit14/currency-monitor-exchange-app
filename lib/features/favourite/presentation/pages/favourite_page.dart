import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/format/number_format.dart';
import '../../../alerts/domain/usecases/alert_usecases.dart';
import '../../../alerts/presentation/widgets/alert_editor_sheet.dart';
import '../../domain/entities/asset_item.dart';
import '../bloc/favorites_cubit.dart';
import '../widgets/asset_flag.dart';
import '../widgets/asset_picker_sheet.dart';
import 'asset_detail_page.dart';

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
const _blue = Color(0xFF2F6FED);

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the asset's detail page; its favorite flag may change there, so the
  /// list reloads when it did.
  Future<void> _openDetail(
    BuildContext context,
    AssetItem asset,
    FavoritesState state,
  ) async {
    final cubit = context.read<FavoritesCubit>();
    final changed = await AssetDetailPage.open(
      context,
      asset: asset,
      quoteCurrency: state.quoteCurrency,
      isFavorite: true,
    );
    if (changed) await cubit.load(refresh: true);
  }

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<FavoritesCubit>();
    final changed = await showAssetPickerSheet(context);
    // Favorites were toggled inside the sheet; reload the list behind it.
    if (changed) await cubit.load(refresh: true);
  }

  /// Asks first; the delete request is only sent after the user confirms.
  Future<void> _confirmDelete(BuildContext context, FavoriteRow row) async {
    final cubit = context.read<FavoritesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from favorites?'),
        content: Text(
          "${row.asset.symbol} · ${row.asset.name} will be removed from your favorites.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _down),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final error = await cubit.remove(row.asset.id);
    if (!context.mounted) return;
    if (error == null) {
      cubit.dropRow(row.asset.id);
    } else {
      _snack(context, "Couldn't remove ${row.asset.symbol}. $error");
    }
  }

  /// Opens the price-alert editor for this favorite, priced in the base
  /// currency.
  Future<void> _alert(
    BuildContext context,
    FavoriteRow row,
    FavoritesState state,
  ) async {
    final quote = state.quoteCurrency;
    if (row.asset.symbol.toUpperCase() == quote.toUpperCase()) {
      _snack(
        context,
        "This is your base currency, so it can't have a price alert",
      );
      return;
    }
    final created = await showAlertEditorSheet(
      context,
      quote: quote,
      fixedBase: row.asset.symbol,
      fixedName: row.asset.name,
      fixedKind: row.asset.kind,
      onSubmit: (base, condition, rate) async {
        final result = await sl<CreateAlert>()(
          CreateAlertParams(
            base: base,
            quote: quote,
            condition: condition,
            targetRate: rate,
          ),
        );
        return result.fold((failure) => failure.message, (_) => null);
      },
    );
    if (created && context.mounted) {
      _snack(context, "Alert set for ${row.asset.symbol}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      // No inputs on this page; the keyboard (e.g. in the add sheet) must not
      // squeeze the fixed header.
      resizeToAvoidBottomInset: false,
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
            // The title and the add button stay put; only the list scrolls (and
            // pulls to refresh).
            return LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  // Capped so a very short body (keyboard up, landscape) cannot
                  // overflow; the header scrolls in that case.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.5,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: _Header(onAdd: () => _add(context)),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => cubit.load(refresh: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        children: _content(context, state),
                      ),
                    ),
                  ),
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
            Slidable(
              key: ValueKey(state.rows[i].asset.id),
              // Sliding only reveals the actions; nothing happens until one is
              // tapped.
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.5,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => _alert(context, state.rows[i], state),
                    backgroundColor: const Color.fromRGBO(0, 0, 0, 0),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Alert',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  CustomSlidableAction(
                    onPressed: (_) => _confirmDelete(context, state.rows[i]),
                    backgroundColor: const Color.fromRGBO(0, 0, 0, 0),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _down,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _down.withValues(alpha: 0.20),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_sharp,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              child: _FavoriteTile(
                row: state.rows[i],
                quoteCurrency: state.quoteCurrency,
                onTap: () => _openDetail(context, state.rows[i].asset, state),
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
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
              dimension: 40,
              child: Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ),
      ],
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
  const _FavoriteTile({
    required this.row,
    required this.quoteCurrency,
    required this.onTap,
  });

  final FavoriteRow row;
  final String quoteCurrency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = row.asset;
    return InkWell(
      onTap: onTap,
      child: Container(
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
          formatMoney(quote.rate, quoteCurrency),
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
              color: change < 0 && formatChange(change) != '0.00' ? _down : _up,
            ),
          ),
        ],
      ],
    );
  }
}
