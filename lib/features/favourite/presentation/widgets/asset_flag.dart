import 'package:country_flags/country_flags.dart';
import 'package:crypto_icons/crypto_icons.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/entities/asset_item.dart';

/// The icon of an asset: an emoji flag for a fiat currency, the coin's logo
/// (crypto_icons) for a cryptocurrency, and a metal / oil icon
/// (font_awesome_flutter) for a commodity.
class AssetFlag extends StatelessWidget {
  const AssetFlag({super.key, required this.asset, this.width = 34});

  final AssetItem asset;
  final double width;

  @override
  Widget build(BuildContext context) {
    switch (asset.kind) {
      case AssetKind.fiat:
        return SizedBox(
          width: width,
          height: width * 0.72,
          // Emoji flag looked up from the currency code (EUR gets the EU flag).
          child: FittedBox(
            child: CountryFlag.fromCurrencyCode(
              asset.symbol,
              theme: EmojiTheme(size: width * 0.8),
            ),
          ),
        );
      case AssetKind.crypto:
        return _Badge(
          size: width,
          color: _cryptoColors[asset.symbol.toUpperCase()] ?? _fallback,
          iconBuilder: _cryptoIconBuilder(asset.symbol),
          fallbackText: asset.symbol,
        );
      case AssetKind.commodity:
        final style = _commodityStyle(asset.symbol);
        return _Badge(
          size: width,
          color: style.color,
          iconBuilder: (size) =>
              FaIcon(style.icon, color: Colors.white, size: size),
        );
    }
  }
}

const _fallback = Color(0xFF5B6075);

/// Brand colours of the biggest coins; any other coin uses [_fallback].
const _cryptoColors = {
  'BTC': Color(0xFFF7931A),
  'ETH': Color(0xFF627EEA),
  'USDT': Color(0xFF26A17B),
  'BNB': Color(0xFFF3BA2F),
  'SOL': Color(0xFF9945FF),
  'XRP': Color(0xFF23292F),
  'USDC': Color(0xFF2775CA),
  'DOGE': Color(0xFFC2A633),
  'ADA': Color(0xFF0033AD),
  'TRX': Color(0xFFEF0027),
};

Widget Function(double)? _cryptoIconBuilder(String symbol) {
  try {
    final icon = CryptoIcons.fromSymbol(symbol);
    return (size) => Icon(icon, color: Colors.white, size: size);
  } on CryptoIconNotFoundException {
    return null;
  }
}

({FaIconData icon, Color color}) _commodityStyle(String symbol) =>
    switch (symbol.toUpperCase()) {
      'XAU' => (icon: FontAwesomeIcons.coins, color: const Color(0xFFE0A21B)),
      'XAG' => (icon: FontAwesomeIcons.coins, color: const Color(0xFF9AA3AE)),
      'XPT' => (icon: FontAwesomeIcons.gem, color: const Color(0xFF7D8A99)),
      'XPD' => (icon: FontAwesomeIcons.gem, color: const Color(0xFF8E7CC3)),
      'WTI' ||
      'BRENT' ||
      'OIL' => (icon: FontAwesomeIcons.oilCan, color: const Color(0xFF3A3F47)),
      _ => (icon: FontAwesomeIcons.coins, color: const Color(0xFFE0A21B)),
    };

/// A round badge with a white icon. A coin with no logo falls back to its
/// first letters.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.color,
    this.iconBuilder,
    this.fallbackText,
  });

  final double size;
  final Color color;
  final Widget Function(double size)? iconBuilder;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final diameter = size * 0.85;
    final text = fallbackText == null
        ? ''
        : fallbackText!.length > 3
        ? fallbackText!.substring(0, 3)
        : fallbackText!;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: iconBuilder != null
              ? iconBuilder!(diameter * 0.55)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
