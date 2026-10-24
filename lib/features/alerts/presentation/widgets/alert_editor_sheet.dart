import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/presentation/widgets/asset_flag.dart';
import '../../domain/entities/price_alert.dart';
import 'alert_asset_picker_sheet.dart';

/// Called with the chosen asset, condition and target. Returns null on success
/// or the message to show inline (the sheet stays open on failure).
typedef AlertSubmit = Future<String?> Function(
  String base,
  AlertCondition condition,
  double targetRate,
);

/// Create (when [existing] is null) or edit an alert. Resolves to true when
/// something was saved or deleted.
///
/// [quote] is the user's base currency: targets are expressed in it. When
/// editing, the watched currency is fixed (the backend cannot change a pair).
/// [fixedBase] (with [fixedName]) fixes it when creating too, e.g. an alert
/// started from a favorite.
Future<bool> showAlertEditorSheet(
  BuildContext context, {
  required String quote,
  required AlertSubmit onSubmit,
  PriceAlert? existing,
  Future<String?> Function()? onDelete,
  String? fixedBase,
  String? fixedName,
  AssetKind? fixedKind,
}) async {
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
      child: _AlertEditor(
        quote: quote,
        existing: existing,
        onSubmit: onSubmit,
        onDelete: onDelete,
        fixedBase: fixedBase,
        fixedName: fixedName,
        fixedKind: fixedKind,
      ),
    ),
  );
  return changed ?? false;
}

const _sheetColor = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _green = Color(0xFF1FA463);
const _red = Color(0xFFE5383B);

/// Plain decimal text: "3", "3.67", "0.0045". Rejects anything else.
double? parseTargetRate(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

class _AlertEditor extends StatefulWidget {
  const _AlertEditor({
    required this.quote,
    required this.onSubmit,
    this.existing,
    this.onDelete,
    this.fixedBase,
    this.fixedName,
    this.fixedKind,
  });

  final String quote;
  final PriceAlert? existing;
  final AlertSubmit onSubmit;
  final Future<String?> Function()? onDelete;
  final String? fixedBase;
  final String? fixedName;

  /// Crypto and commodities have no country flag, so the row needs the kind to
  /// pick the right icon. Defaults to fiat when unknown.
  final AssetKind? fixedKind;

  @override
  State<_AlertEditor> createState() => _AlertEditorState();
}

class _AlertEditorState extends State<_AlertEditor> {
  late final TextEditingController _price;
  late AlertCondition _condition;
  AssetItem? _asset;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  /// The watched asset cannot be changed: editing, or started from a favorite.
  bool get _baseFixed => _editing || widget.fixedBase != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _condition = existing?.condition ?? AlertCondition.above;
    _price = TextEditingController(
      text: existing == null ? '' : formatRate(existing.targetRate),
    );
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double? get _rate => parseTargetRate(_price.text);

  bool get _canSubmit =>
      !_busy && _rate != null && (_baseFixed || _asset != null);

  Future<void> _pickAsset() async {
    final picked = await chooseAlertAsset(
      context,
      current: _asset,
      excludeSymbols: {widget.quote},
    );
    if (picked != null && mounted) {
      setState(() {
        _asset = picked;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final rate = _rate;
    final base = widget.existing?.base ?? widget.fixedBase ?? _asset?.symbol;
    if (rate == null || base == null || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(base, _condition, rate);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete alert?'),
        content: const Text('You will no longer be notified for this alert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await onDelete();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            _Header(
              title: _editing ? 'Edit Alert' : 'My Alerts',
              onClose: () => Navigator.of(context).pop(false),
            ),
            const _Label('Asset'),
            _CurrencyRow(
              editing: _baseFixed,
              code: widget.existing?.base ?? widget.fixedBase ?? _asset?.symbol,
              name: widget.fixedName ?? _asset?.name,
              kind: widget.fixedKind ?? _asset?.kind ?? AssetKind.fiat,
              onTap: _baseFixed || _busy ? null : _pickAsset,
            ),
            const SizedBox(height: 22),
            const _Label('Notify when price is'),
            Row(
              children: [
                Expanded(
                  child: _ConditionButton(
                    condition: AlertCondition.above,
                    selected: _condition == AlertCondition.above,
                    onTap: () =>
                        setState(() => _condition = AlertCondition.above),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ConditionButton(
                    condition: AlertCondition.below,
                    selected: _condition == AlertCondition.below,
                    onTap: () =>
                        setState(() => _condition = AlertCondition.below),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _Label('Target price'),
            _PriceField(
              controller: _price,
              quote: widget.quote,
              enabled: !_busy,
              onChanged: () => setState(() => _error = null),
            ),
            const SizedBox(height: 22),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _red),
                ),
              ),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6FED),
                  disabledBackgroundColor: const Color(0xFF8E8E93),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_active, size: 22),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _editing ? 'Save Changes' : 'Create Alert',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_editing && widget.onDelete != null)
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text(
                  'Delete alert',
                  style: TextStyle(color: _red, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Trims trailing zeros: 3.6725, 90, 0.0045.
String formatRate(double value) {
  final fixed = value.toStringAsFixed(6);
  if (!fixed.contains('.')) return fixed;
  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              shadowColor: const Color(0x22000000),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.close_rounded, size: 22, color: _muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
    child: Text(text, style: const TextStyle(fontSize: 16, color: _muted)),
  );
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.editing,
    required this.code,
    required this.name,
    required this.kind,
    required this.onTap,
  });

  final bool editing;
  final String? code;
  final String? name;
  final AssetKind kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = code;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              if (c == null)
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF1E88FF),
                  child: Icon(Icons.add, color: Colors.white, size: 22),
                )
              else
                AssetFlag(
                  asset: AssetItem(
                    id: c,
                    symbol: c,
                    name: name ?? c,
                    kind: kind,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  c == null ? 'Add Asset' : (name == null ? c : '$c · $name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!editing)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9A9AA2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionButton extends StatelessWidget {
  const _ConditionButton({
    required this.condition,
    required this.selected,
    required this.onTap,
  });

  final AlertCondition condition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final above = condition == AlertCondition.above;
    final color = above ? _green : _red;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 58,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : const Color(0xFFD8D8DE),
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                above
                    ? Icons.arrow_circle_up_rounded
                    : Icons.arrow_circle_down_rounded,
                color: selected ? color : _muted,
                size: 28,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  above ? 'above' : 'below',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : _muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.quote,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String quote;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(16),
              ],
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Color(0xFFC4C4C9)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quote,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}
