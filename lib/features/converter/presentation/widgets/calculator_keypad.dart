import 'package:flutter/material.dart';

import '../../domain/expression_input.dart';

const _operatorColor = Color(0xFFFF9500);
const _utilityColor = Color(0xFFE0E1E3);

/// The fixed calculator keypad: utility keys on top, digits on the left and the
/// orange operators on the right. It only reports keys (see [Keys]); the
/// Converter decides what they do.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({super.key, required this.onKey, this.keyHeight = 56});

  final ValueChanged<String> onKey;

  /// Height of one key; the page shrinks it on short screens.
  final double keyHeight;

  static const _rows = [
    [Keys.clear, Keys.backspace, Keys.percent, Keys.divide],
    ['7', '8', '9', Keys.multiply],
    ['4', '5', '6', Keys.minus],
    ['1', '2', '3', Keys.plus],
    ['0', Keys.triple, Keys.point, Keys.equals],
  ];

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < _rows.length; r++)
            Padding(
              padding: EdgeInsets.only(top: r == 0 ? 0 : _gap),
              child: Row(
                children: [
                  for (var c = 0; c < _rows[r].length; c++) ...[
                    if (c > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: _Key(
                        label: _rows[r][c],
                        onKey: onKey,
                        height: keyHeight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onKey, required this.height});

  final String label;
  final ValueChanged<String> onKey;
  final double height;

  bool get _isOperator =>
      Keys.operators.contains(label) || label == Keys.equals;
  bool get _isUtility =>
      label == Keys.clear || label == Keys.backspace || label == Keys.percent;

  @override
  Widget build(BuildContext context) {
    final color = _isOperator
        ? _operatorColor
        : _isUtility
        ? _utilityColor
        : Colors.white;
    return Semantics(
      button: true,
      label: _semanticLabel(label),
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('key-$label'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => onKey(label),
          child: SizedBox(
            height: height,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: label == Keys.backspace
                    ? const Icon(Icons.backspace_outlined, size: 28)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: _isOperator ? 32 : 28,
                          fontWeight: FontWeight.w400,
                          color: _isOperator ? Colors.white : Colors.black,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _semanticLabel(String key) => switch (key) {
    Keys.clear => 'Clear entry',
    Keys.backspace => 'Delete',
    Keys.percent => 'Percent',
    Keys.divide => 'Divide',
    Keys.multiply => 'Multiply',
    Keys.minus => 'Subtract',
    Keys.plus => 'Add',
    Keys.equals => 'Equals',
    Keys.point => 'Decimal point',
    Keys.triple => 'Triple zero',
    _ => key,
  };
}
