import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/asset_item.dart';

/// Country flag for a fiat currency; a coloured badge with the symbol's first
/// letters for coins and commodities, which have no flag.
class AssetFlag extends StatelessWidget {
  const AssetFlag({super.key, required this.asset, this.width = 34});

  final AssetItem asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 0.72;
    if (asset.kind == AssetKind.fiat) {
      return SizedBox(
        width: width,
        height: height,
        child: CountryFlag.fromCurrencyCode(
          asset.symbol,
          theme: ImageTheme(
            width: width,
            height: height,
            shape: const RoundedRectangle(4),
          ),
        ),
      );
    }
    final letters = asset.symbol.length > 3
        ? asset.symbol.substring(0, 3)
        : asset.symbol;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: asset.kind == AssetKind.crypto
            ? const Color(0xFFFFE9C7)
            : const Color(0xFFFFF3B8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            letters,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B4A00),
            ),
          ),
        ),
      ),
    );
  }
}
