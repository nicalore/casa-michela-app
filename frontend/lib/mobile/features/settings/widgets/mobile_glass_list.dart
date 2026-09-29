import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const double _radius = 22;
const double _verticalPadding = 4;
const double _hairlineEnd = 14;

class MobileGlassList extends StatelessWidget
{
  final List<Widget> rows;

  // Hairlines start here, at the left edge of the rows' text.
  final double indent;

  const MobileGlassList({super.key, required this.rows, required this.indent});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
      borderRadius: const BorderRadius.all(Radius.circular(_radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: EdgeInsets.only(left: indent, right: _hairlineEnd),
                color: AppTheme.trialInk.withValues(alpha: 0.09),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class MobileGlassListRow extends StatelessWidget
{
  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  final EdgeInsets padding;
  final double gap;
  final double minHeight;
  final TextStyle? titleStyle;

  const MobileGlassListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(14, 8, 12, 8),
    this.gap = 13,
    this.minHeight = 58,
    this.titleStyle,
  });

  static Widget chevron()
  {
    return Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialInk.withValues(alpha: 0.36));
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget? subtitle = this.subtitle;
    final Widget? trailing = this.trailing;

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                leading,
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: titleStyle ??
                            GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: AppTheme.trialInk,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        DefaultTextStyle.merge(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MobilePalette.mutedText,
                          ),
                          child: subtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
