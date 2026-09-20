import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

const double _width = 84;
const double _height = 52;

class AppBackButton extends StatefulWidget
{
  final String tooltip;
  final VoidCallback onTap;

  const AppBackButton({super.key, required this.tooltip, required this.onTap});

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
        child: Tooltip(
          message: widget.tooltip,
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.trialGoldSurface : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.trialOcean,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
