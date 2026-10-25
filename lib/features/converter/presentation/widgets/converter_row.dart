import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../favourite/domain/entities/asset_item.dart';
import '../../../favourite/presentation/widgets/asset_flag.dart';

const _highlight = Color(0xFFE4E5E9);
const _divider = Color(0xFFD1D1D6);
const _delete = Color(0xFFFF3B30);

/// One asset of the Converter list: flag, code and value. The active row is
/// highlighted; tapping another row makes it the one typed into, and sliding
/// left reveals a red delete button.
class ConverterRow extends StatelessWidget {
  const ConverterRow({
    super.key,
    required this.asset,
    required this.value,
    required this.active,
    required this.showDivider,
    required this.onTap,
    required this.onDelete,
  });

  final AssetItem asset;

  /// The text on the right (an amount, the typed expression, or "-").
  final String value;
  final bool active;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(asset.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color.fromRGBO(0, 0, 0, 0),
            padding: const EdgeInsets.all(6),
            child: Container(
              decoration: BoxDecoration(
                color: _delete,
                borderRadius: BorderRadius.circular(30),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: active ? _highlight : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      AssetFlag(asset: asset, width: 36),
                      const SizedBox(width: 20),
                      Text(
                        asset.symbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              value,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3A3A3C),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                if (showDivider && !active)
                  const Padding(
                    padding: EdgeInsets.only(left: 86),
                    child: Divider(height: 1, thickness: 1, color: _divider),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
