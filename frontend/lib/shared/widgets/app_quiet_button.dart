import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// A secondary command: an outlined pill that lights up gold under the pointer,
// like every other pressable thing in the app. It replaced the underlined links,
// which were the only thing answering the pointer with a rule instead of an
// outline.

class AppQuietButton extends StatefulWidget
{
  final String label;
  final VoidCallback onTap;

  // The symbol to the left of the word.
  final IconData icon;

  const AppQuietButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.done_all_rounded,
  });

  @override
  State<AppQuietButton> createState() => _AppQuietButtonState();
}

class _AppQuietButtonState extends State<AppQuietButton>
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _hover
                ? AppTheme.trialGoldSurface
                : AppTheme.trialGoldSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: AppTheme.trialTealDeep),
              const SizedBox(width: 8),
              // Flexible: on a narrow screen a phrase like "Password
              // dimenticata?" is wider than the pill holding it, and a pill
              // cannot overflow.
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialTealDeep,
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
