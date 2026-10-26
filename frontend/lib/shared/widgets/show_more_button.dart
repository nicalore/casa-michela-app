import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const String kShowAllLabel = 'Mostra tutte';
const String kShowFewerLabel = 'Mostra meno';

// Lengthens a list in place, and shortens it again.
class ShowMoreButton extends StatefulWidget
{
  final String label;
  final bool open;
  final VoidCallback onTap;

  const ShowMoreButton({super.key, required this.label, required this.open, required this.onTap});

  @override
  State<ShowMoreButton> createState() => _ShowMoreButtonState();
}

class _ShowMoreButtonState extends State<ShowMoreButton>
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
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.only(left: 14, right: 10),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.closedSurface : AppTheme.todaySurface,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialTealDeep,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                widget.open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: AppTheme.trialTealDeep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
