import 'package:flutter/material.dart';

class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Pill-shaped bottom bar that floats above the content, with a rounded
/// highlight and blue tint on the selected item.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _selectedColor = Color(0xFF2F6FED);
  static const _idleColor = Color(0xFF111111);
  static const _highlight = Color(0xFFE6E6EB);
  static const _slideDuration = Duration(milliseconds: 320);
  static const _slideCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFE),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: _slideDuration,
                  curve: _slideCurve,
                  alignment: Alignment(
                    items.length > 1
                        ? -1 + 2 * currentIndex / (items.length - 1)
                        : 0,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _highlight,
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final target = selected
        ? FloatingNavBar._selectedColor
        : FloatingNavBar._idleColor;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<Color?>(
          duration: FloatingNavBar._slideDuration,
          curve: FloatingNavBar._slideCurve,
          tween: ColorTween(end: target),
          builder: (context, color, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
