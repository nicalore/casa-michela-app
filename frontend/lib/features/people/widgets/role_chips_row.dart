import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

// No AppTheme equivalent: this fill is unique to the role chips.
const Color _chipBackground = Color(0xFFE8F7F5);

// Role chips packed into the available width; whatever does not fit becomes a
// "+N" chip whose tooltip lists the hidden ones.
class RoleChipsRow extends StatelessWidget
{
  final List<String> roles;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final double borderRadius;
  final double spacing;

  // Slack against sub-pixel rounding.
  final double safetyMargin;

  // TextPainter ignores the ambient text scaler by default, underestimating
  // widths when the system text scale is not 1.0.
  final bool applyTextScaler;

  final bool scrollable;
  final bool centered;

  final int maxLines;

  final double runSpacing;

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
    this.maxLines = 1,
    this.runSpacing = 6,
  });

  double _measureChipWidth(String text, TextStyle style, TextScaler textScaler)
  {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    return painter.width + 2 * horizontalPadding;
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
        // Merge onto the inherited style: measured bare, the theme's letter
        // spacing made chips measure narrower than they draw.
        final ambient = DefaultTextStyle.of(context).style;

        final chipStyle = ambient.merge(GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ));
        final extraStyle = ambient.merge(GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ));

        final List<List<String>> lines = [];
        List<String> line = [];
        double lineWidth = 0;
        int placed = 0;

        for (final role in roles)
        {
          final width = _measureChipWidth(role, chipStyle, textScaler);
          final needed = line.isEmpty ? width : width + spacing;

          if (lineWidth + needed + safetyMargin <= constraints.maxWidth)
          {
            line.add(role);
            lineWidth += needed;
            placed++;

            continue;
          }

          if (lines.length + 1 < maxLines)
          {
            lines.add(line);
            line = [role];
            lineWidth = width;
            placed++;

            continue;
          }

          break;
        }

        lines.add(line);

        // Make room for the counter on the last row by removing chips until it
        // fits.
        int hiddenCount = roles.length - placed;

        while (hiddenCount > 0)
        {
          final extraWidth = (lines.last.isEmpty ? 0 : spacing) +
              _measureChipWidth('+$hiddenCount', extraStyle, textScaler);

          if (lineWidth + extraWidth + safetyMargin <= constraints.maxWidth)
          {
            break;
          }

          final shown = lines.fold<int>(0, (total, row) => total + row.length);

          // At least one chip is always kept, even wider than the room there is.
          if (lines.last.isEmpty || shown <= 1)
          {
            break;
          }

          final removed = lines.last.removeLast();

          lineWidth -= _measureChipWidth(removed, chipStyle, textScaler) +
              (lines.last.isEmpty ? 0 : spacing);
          hiddenCount++;
        }

        final List<String> hiddenRoles = roles.sublist(roles.length - hiddenCount);

        List<Widget> chipsOf(List<String> labels, {required bool withCounter})
        {
          final List<Widget> chips = [];

          for (var i = 0; i < labels.length; i++)
          {
            if (i > 0)
            {
              chips.add(SizedBox(width: spacing));
            }

            chips.add(_buildChip(labels[i], chipStyle));
          }

          if (withCounter && hiddenCount > 0)
          {
            if (chips.isNotEmpty)
            {
              chips.add(SizedBox(width: spacing));
            }

            chips.add(_buildChip('+$hiddenCount', extraStyle, hiddenRoles: hiddenRoles));
          }

          return chips;
        }

        final List<Widget> rows = [
          for (var i = 0; i < lines.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: chipsOf(lines[i], withCounter: i == lines.length - 1),
            ),
        ];

        final Widget row = rows.length == 1
            ? rows.first
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) SizedBox(height: runSpacing),
                    rows[i],
                  ],
                ],
              );

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
