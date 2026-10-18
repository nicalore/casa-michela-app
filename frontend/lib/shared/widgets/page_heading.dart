import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

// Between a heading and the card or cards it names.
const double kPageHeadingGap = 12;

const double _inset = 8;
const double _fontSize = 12;

// Above the person record's big cards, a step up.
const double _largeFontSize = 14;

// A heading written on the page, above a card or a group of cards: the same everywhere.
class PageHeading extends StatelessWidget
{
  final String text;

  // How many things it names, beside it.
  final int? count;

  // At the far end, as a control acting on what it names.
  final Widget? trailing;

  final bool large;

  const PageHeading(this.text, {super.key, this.count, this.trailing, this.large = false});

  static TextStyle style({Color color = AppTheme.trialMutedText, bool large = false}) => GoogleFonts.plusJakartaSans(
        fontSize: large ? _largeFontSize : _fontSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 1.6,
        color: color,
      );

  @override
  Widget build(BuildContext context)
  {
    final int? count = this.count;
    final Widget? trailing = this.trailing;

    final Widget label = Row(
      children: [
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style(large: large),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count',
            style: style(color: AppTheme.trialTealDeep, large: large).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(left: _inset),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: 12),
                trailing,
              ],
            ),
    );
  }
}
