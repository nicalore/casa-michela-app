import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// No AppTheme equivalent: this fill is unique to the role chips, so it stays a
// literal to preserve the exact appearance.
const Color _chipBackground = Color(0xFFF5F7FA);

/// A single row of role chips that truncates to the available width, replacing
/// the overflowing roles with a "+N" chip whose tooltip lists the hidden ones.
///
/// The chip metrics differ between call sites (card, detail header, wizard), so
/// they are exposed as parameters while the overflow-measurement algorithm is
/// shared.
class RoleChipsRow extends StatelessWidget
{
  final List<String> roles;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double spacing;

  /// Slack kept against sub-pixel rounding, so a chip is dropped rather than
  /// risking a few-pixel overflow.
  final double safetyMargin;

  /// Applies the ambient text scaler while measuring. The offline TextPainter
  /// ignores it by default, which underestimates the width and causes overflow
  /// when the system text scale is not 1.0.
  final bool applyTextScaler;

  /// Wraps the row in a horizontal scroll view aligned to one side, instead of
  /// an unbounded plain row.
  final bool scrollable;
  final bool centered;

  const RoleChipsRow({
    super.key,
    required this.roles,
    this.fontSize = 12,
    this.horizontalPadding = 10,
    this.verticalPadding = 4,
    this.borderRadius = 12,
    this.spacing = 6,
    this.safetyMargin = 0,
    this.applyTextScaler = false,
    this.scrollable = false,
    this.centered = false,
  });

  double _measureChipWidth(String text, TextStyle style, TextScaler textScaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    // The measured chip spans the text plus its horizontal padding on both
    // sides and a one-pixel border per side.
    return painter.width + 2 * horizontalPadding + 2;
  }

  @override
  Widget build(BuildContext context)
  {
    if (roles.isEmpty)
    {
      return const SizedBox.shrink();
    }

    final TextScaler textScaler = applyTextScaler
        ? MediaQuery.textScalerOf(context)
        : TextScaler.noScaling;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final chipStyle = GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: AppTheme.slate500,
        );
        final extraStyle = GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
        );

        int visibleCount = roles.length;
        while (visibleCount > 1)
        {
          double totalWidth = 0;
          for (int i = 0; i < visibleCount; i++)
          {
            totalWidth += _measureChipWidth(roles[i], chipStyle, textScaler);
            if (i > 0) totalWidth += spacing;
          }

          final int remaining = roles.length - visibleCount;
          if (remaining > 0)
          {
            totalWidth += spacing + _measureChipWidth('+$remaining', extraStyle, textScaler);
          }

          if (totalWidth + safetyMargin <= constraints.maxWidth) break;
          visibleCount--;
        }

        final int extraCount = roles.length - visibleCount;
        final List<String> hiddenRoles = roles.sublist(visibleCount);

        final List<Widget> chips = [];
        for (int i = 0; i < visibleCount; i++)
        {
          if (i > 0) chips.add(SizedBox(width: spacing));
          chips.add(_buildChip(roles[i], chipStyle));
        }
        if (extraCount > 0)
        {
          chips.add(SizedBox(width: spacing));
          chips.add(_buildChip('+$extraCount', extraStyle, hiddenRoles: hiddenRoles));
        }

        final Widget row = Row(mainAxisSize: MainAxisSize.min, children: chips);

        if (!scrollable)
        {
          return row;
        }

        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Align(
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: row,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label, TextStyle style, {List<String>? hiddenRoles})
  {
    final Widget chip = Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: _chipBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(label, style: style),
    );

    if (hiddenRoles == null || hiddenRoles.isEmpty)
    {
      return chip;
    }

    return Tooltip(
      waitDuration: const Duration(milliseconds: 600),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: 'Altri ruoli:\n',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.slate400,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          TextSpan(
            text: hiddenRoles.join('\n'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
      child: chip,
    );
  }
}
