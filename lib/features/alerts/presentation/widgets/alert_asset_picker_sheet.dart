import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/domain/usecases/favorite_usecases.dart';
import '../../../favourite/presentation/widgets/asset_flag.dart';
import '../../../favourite/presentation/widgets/asset_search_and_tabs.dart';

/// Lets the user pick any asset (currency, crypto or commodity) to watch.
/// Resolves to the tapped asset, or null when dismissed. [excludeSymbols]
/// hides assets that cannot be chosen, e.g. the user's base currency.
Future<AssetItem?> chooseAlertAsset(
  BuildContext context, {
  AssetItem? current,
  Set<String> excludeSymbols = const {},
}) {
  return showModalBottomSheet<AssetItem>(
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
        child: _AlertAssetPicker(
          current: current,
          excludeSymbols: excludeSymbols.map((s) => s.toUpperCase()).toSet(),
        ),
      ),
    ),
  );
}

const _sheetColor = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _blue = Color(0xFF0A84FF);

class _AlertAssetPicker extends StatefulWidget {
  const _AlertAssetPicker({
    required this.current,
    required this.excludeSymbols,
  });

  final AssetItem? current;
  final Set<String> excludeSymbols;

  @override
  State<_AlertAssetPicker> createState() => _AlertAssetPickerState();
}

class _AlertAssetPickerState extends State<_AlertAssetPicker> {
  final _search = TextEditingController();
  String _query = '';
  late AssetKind _kind = widget.current?.kind ?? AssetKind.fiat;

  Map<AssetKind, List<AssetItem>>? _catalog;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _catalog = null;
      _error = null;
    });
    final result = await sl<GetAssetCatalog>()(const NoParams());
    if (!mounted) return;
    setState(() {
      result.fold((f) => _error = f.message, (c) => _catalog = c);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    const _Header(),
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
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final catalog = _catalog;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = _query.trim().toLowerCase();
    final items = (catalog[_kind] ?? const <AssetItem>[])
        .where((a) => !widget.excludeSymbols.contains(a.symbol.toUpperCase()))
        .where(
          (a) =>
              q.isEmpty ||
              a.symbol.toLowerCase().contains(q) ||
              a.name.toLowerCase().contains(q),
        )
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nothing found', style: TextStyle(color: _muted)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final asset = items[i];
        return _AssetTile(
          asset: asset,
          selected: asset.symbol == widget.current?.symbol,
          onTap: () => Navigator.of(context).pop(asset),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

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
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                    child: Text(
                      'Cancel',
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
                'Add Asset',
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
    required this.selected,
    required this.onTap,
  });

  final AssetItem asset;
  final bool selected;
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
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _blue, size: 26),
          ],
        ),
      ),
    );
  }
}
