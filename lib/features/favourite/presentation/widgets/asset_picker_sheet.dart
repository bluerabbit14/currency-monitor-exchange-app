import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/asset_item.dart';
import '../bloc/asset_picker_cubit.dart';
import 'asset_flag.dart';

/// Bottom sheet to choose an asset to favorite. Resolves to the tapped asset,
/// or null when dismissed. Assets whose id is in [excludeIds] (already
/// favorites) are not offered.
Future<AssetItem?> showAssetPickerSheet(
  BuildContext context, {
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<AssetItem>(
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
        child: BlocProvider(
          create: (_) => sl<AssetPickerCubit>()..load(),
          child: _AssetPicker(excludeIds: excludeIds),
        ),
      ),
    ),
  );
}

const _muted = Color(0xFF8A8A93);
const _fieldColor = Color(0xFFF1F1F6);

class _AssetPicker extends StatefulWidget {
  const _AssetPicker({required this.excludeIds});

  final Set<String> excludeIds;

  @override
  State<_AssetPicker> createState() => _AssetPickerState();
}

class _AssetPickerState extends State<_AssetPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The whole sheet scrolls, so with the keyboard open on a short screen the
    // header and search field can never overflow the space that is left.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
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
              _Header(onClose: () => Navigator.of(context).pop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search currency, coin or metal...',
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
              ),
            ],
          ),
        ),
        BlocBuilder<AssetPickerCubit, AssetPickerState>(
          builder: (context, state) => _body(context, state),
        ),
      ],
    );
  }

  static Widget _centered(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: Center(child: child));

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
        final items = state.assets
            .where((a) => !widget.excludeIds.contains(a.id))
            .where(
              (a) =>
                  q.isEmpty ||
                  a.symbol.toLowerCase().contains(q) ||
                  a.name.toLowerCase().contains(q),
            )
            .toList();
        if (items.isEmpty) {
          return _centered(
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                state.assets.isNotEmpty && q.isEmpty
                    ? 'Everything is already in your favorites'
                    : 'Nothing found',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => _AssetTile(
              asset: items[i],
              onTap: () => Navigator.of(context).pop(items[i]),
            ),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                'Add favorite',
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
  const _AssetTile({required this.asset, required this.onTap});

  final AssetItem asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AssetFlag(asset: asset),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    asset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF1E88FF),
            ),
          ],
        ),
      ),
    );
  }
}
