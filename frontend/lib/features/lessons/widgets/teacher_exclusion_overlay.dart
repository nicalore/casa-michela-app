import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'calendar_lesson_block.dart';

// Exclude/readmit control laid over a teacher's avatar; meant for a
// Positioned.fill inside the caller's Stack.
class TeacherExclusionOverlay extends StatefulWidget
{
  final bool isExcluded;

  final VoidCallback? onToggle;

  final double signSize;

  const TeacherExclusionOverlay({
    super.key,
    required this.isExcluded,
    required this.onToggle,
    this.signSize = 26,
  });

  @override
  State<TeacherExclusionOverlay> createState() => _TeacherExclusionOverlayState();
}

class _TeacherExclusionOverlayState extends State<TeacherExclusionOverlay>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final excluded = widget.isExcluded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Tooltip(
          message: excluded ? kReadmitTeacherLabel : kExcludeTeacherLabel,
          decoration: AppTheme.tooltipDecoration,
          textStyle: AppTheme.tooltipTextStyle,
          waitDuration: kTeacherExclusionTooltipWait,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? Colors.black54 : Colors.transparent,
            ),
            child: Center(
              child: AnimatedScale(
                scale: _hover ? 1 : 0.4,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _hover ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    excluded ? Icons.add_rounded : Icons.remove_rounded,
                    size: widget.signSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
