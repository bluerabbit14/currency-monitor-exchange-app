import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../favourite/domain/entities/asset_item.dart';
import '../../domain/entities/conversion.dart';

/// Stores the Converter rows in local preferences on the device (never sent to
/// the backend).
class ConverterLocalDataSource {
  const ConverterLocalDataSource();

  static const _key = 'converter_session_v1';

  Future<ConverterSession?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final assets = <AssetItem>[];
      for (final item in json['assets'] as List) {
        final kind = AssetKind.fromApi(item['kind']);
        if (kind == null) continue;
        assets.add(
          AssetItem(
            id: item['id'] as String,
            symbol: item['symbol'] as String,
            name: item['name'] as String,
            kind: kind,
          ),
        );
      }
      return ConverterSession(
        assets: assets,
        activeSymbol: json['active'] as String?,
        expression: json['expression'] as String? ?? '',
      );
    } catch (_) {
      // Unreadable (older, damaged or unavailable) data counts as a first
      // launch.
      return null;
    }
  }

  /// Best effort: the Converter works without being remembered.
  Future<void> write(ConverterSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'assets': [
            for (final a in session.assets)
              {
                'id': a.id,
                'symbol': a.symbol,
                'name': a.name,
                'kind': a.kind.name.toUpperCase(),
              },
          ],
          'active': session.activeSymbol,
          'expression': session.expression,
        }),
      );
    } catch (_) {
      // Not remembering is better than failing a key press.
    }
  }
}
