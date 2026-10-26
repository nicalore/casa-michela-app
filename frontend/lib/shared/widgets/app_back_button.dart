import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_tooltip.dart';

const double _width = 84;
const double _height = 52;

// Beside a title below the wide window.
const double _denseWidth = 56;
const double _denseHeight = 38;

class AppBackButton extends StatefulWidget
{
  static const double height = _height;
  static const double denseWidth = _denseWidth;

  final String tooltip;
  final VoidCallback onTap;

  final bool dense;

  const AppBackButton({super.key, required this.tooltip, required this.onTap, this.dense = false});

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AppTooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 400),
          // Sized outside the animation: only the colours fade, a new size never animates.
          child: SizedBox(
            width: widget.dense ? _denseWidth : _width,
            height: widget.dense ? _denseHeight : _height,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _hover ? AppTheme.trialGoldSurface : Colors.white,
                borderRadius: BorderRadius.circular((widget.dense ? _denseHeight : _height) / 2),
                border: Border.all(
                  color: _hover
                    ? AppTheme.trialGold
                    : AppTheme.trialGold.withValues(alpha: 0),
                  width: 2,
                ),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.trialOcean,
                size: widget.dense ? 21 : 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
