import 'package:flutter/material.dart';

import '../../domain/entities/asset_item.dart';

const _muted = Color(0xFF8A8A93);

/// Tab label of an asset type: Currency, Crypto or Commodities.
String assetKindLabel(AssetKind kind) => switch (kind) {
  AssetKind.fiat => 'Currency',
  AssetKind.crypto => 'Crypto',
  AssetKind.commodity => 'Commodities',
};

/// Rounded "Search..." field shared by the Browse tab and the Add to
/// Favorites sheet. [raised] gives it the white, lifted look; otherwise it is
/// a flat grey pill.
class AssetSearchField extends StatelessWidget {
  const AssetSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.raised = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: raised ? Colors.white : const Color(0xFFE4E4E9),
      elevation: raised ? 3 : 0,
      shadowColor: const Color(0x14000000),
      shape: const StadiumBorder(),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: _muted),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.black),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/// Pill-style segmented control: the selected tab is a black pill.
class AssetKindTabs extends StatelessWidget {
  const AssetKindTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AssetKind selected;
  final ValueChanged<AssetKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final kind in AssetKind.values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(kind),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: kind == selected ? Colors.black : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      assetKindLabel(kind),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kind == selected ? Colors.white : _muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
