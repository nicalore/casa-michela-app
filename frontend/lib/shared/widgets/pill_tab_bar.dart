import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Secondary navigation made of pill shaped chips. It wraps to a new line instead
// of scrolling off screen invisibly, so no option can become unreachable.
class PillTabBar extends StatelessWidget
{
  static const Duration _transitionDuration = Duration(milliseconds: 250);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  const PillTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.only(bottom: 24.0),
  });

  Widget _buildChip(int index)
  {
    final isSelected = selectedIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: _transitionDuration,
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.slate200),
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedDefaultTextStyle(
            duration: _transitionDuration,
            curve: Curves.easeInOut,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.slate500,
            ),
            child: Text(labels[index]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var index = 0; index < labels.length; index++) _buildChip(index),
        ],
      ),
    );
  }
}