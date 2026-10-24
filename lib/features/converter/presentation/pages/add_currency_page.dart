import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/presentation/widgets/asset_flag.dart';
import '../../../favourite/presentation/widgets/asset_search_and_tabs.dart';
import '../bloc/converter_picker_cubit.dart';

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _blue = Color(0xFF0A84FF);

/// Opens the Add Currency page with [current] ticked. Resolves to the ticked
/// assets when the user taps Done, or null when they go back.
Future<List<AssetItem>?> showAddCurrencyPage(
  BuildContext context,
  List<AssetItem> current,
) => Navigator.of(context).push<List<AssetItem>>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => BlocProvider(
      create: (_) => sl<ConverterPickerCubit>(param1: current)..load(),
      child: const AddCurrencyPage(),
    ),
  ),
);

class AddCurrencyPage extends StatefulWidget {
  const AddCurrencyPage({super.key});

  @override
  State<AddCurrencyPage> createState() => _AddCurrencyPageState();
}

class _AddCurrencyPageState extends State<AddCurrencyPage> {
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
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
                          onTap: () => Navigator.of(context).pop(
                            context
                                .read<ConverterPickerCubit>()
                                .state
                                .selected
                                .values
                                .toList(),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 13,
                            ),
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
                        'Add Currency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            Expanded(
              child: BlocBuilder<ConverterPickerCubit, ConverterPickerState>(
                builder: _body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ConverterPickerState state) {
    switch (state.status) {
      case ConverterPickerStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ConverterPickerStatus.loadFailed:
        return Center(
          child: Padding(
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
                  onPressed: context.read<ConverterPickerCubit>().load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case ConverterPickerStatus.ready:
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
          itemBuilder: (context, i) => _AssetTile(
            asset: items[i],
            checked: state.selected.containsKey(items[i].id),
            onTap: () => context.read<ConverterPickerCubit>().toggle(items[i]),
          ),
        );
    }
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.checked,
    required this.onTap,
  });

  final AssetItem asset;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('converter-toggle-${asset.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
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
            Padding(
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
                    ? const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
