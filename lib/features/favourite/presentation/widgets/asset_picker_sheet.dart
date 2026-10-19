import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/asset_item.dart';
import '../bloc/asset_picker_cubit.dart';
import 'asset_flag.dart';
import 'asset_search_and_tabs.dart';

/// "Add to Favorites" bottom sheet: search, segmented tabs (Currency, Crypto,
/// Commodities) and a check per asset. Tapping a row adds or removes that
/// favorite right away. Resolves to true when anything changed, so the page
/// behind can refresh.
Future<bool> showAssetPickerSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: _sheetColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: BlocProvider(
          create: (_) => sl<AssetPickerCubit>()..load(),
          child: const _AssetPicker(),
        ),
      ),
    ),
  );
  return changed ?? false;
}

const _sheetColor = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _blue = Color(0xFF0A84FF);

class _AssetPicker extends StatefulWidget {
  const _AssetPicker();

  @override
  State<_AssetPicker> createState() => _AssetPickerState();
}

class _AssetPickerState extends State<_AssetPicker> {
  final _search = TextEditingController();
  String _query = '';
  AssetKind _kind = AssetKind.fiat;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(BuildContext context, AssetItem asset) async {
    final error = await context.read<AssetPickerCubit>().toggle(asset);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't update. $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The sheet has its own Scaffold so snack bars show above it. The header,
    // search and tabs stay put and only the asset list scrolls. On a very
    // short screen (keyboard open) the fixed part is capped at 60% of the
    // height and scrolls, so it can never overflow.
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC7C7CC),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    _Header(
                      onDone: () => Navigator.of(context)
                          .pop(context.read<AssetPickerCubit>().state.changed),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: AssetSearchField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: AssetKindTabs(
                        selected: _kind,
                        onSelected: (kind) => setState(() => _kind = kind),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<AssetPickerCubit, AssetPickerState>(
                builder: (context, state) => _body(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _centered(Widget child) => Center(child: child);

  Widget _body(BuildContext context, AssetPickerState state) {
    switch (state.status) {
      case AssetPickerStatus.loading:
        return _centered(const CircularProgressIndicator());
      case AssetPickerStatus.loadFailed:
        return _centered(
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.error ?? 'Unable to load assets',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: context.read<AssetPickerCubit>().load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case AssetPickerStatus.ready:
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
        if (items.isEmpty) {
          return _centered(
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nothing found', style: TextStyle(color: _muted)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: items.length,
          itemBuilder: (context, i) => _AssetTile(
            asset: items[i],
            busy: state.pending.contains(items[i].id),
            onTap: () => _toggle(context, items[i]),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                elevation: 4,
                shadowColor: const Color(0x22000000),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onDone,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 96),
              child: Text(
                'Add to Favorites',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.busy,
    required this.onTap,
  });

  final AssetItem asset;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Only the check circle is tappable, not the whole row.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AssetFlag(asset: asset, width: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: _muted),
                ),
              ],
            ),
          ),
          _Check(
            key: ValueKey('favorite-toggle-${asset.id}'),
            checked: asset.isFavorite,
            onTap: busy ? null : onTap,
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({super.key, required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A 48px hit area around the 30px circle.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? _blue : Colors.transparent,
            border: checked
                ? null
                : Border.all(color: const Color(0xFFC7C7CC), width: 2),
          ),
          child: checked
              ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
