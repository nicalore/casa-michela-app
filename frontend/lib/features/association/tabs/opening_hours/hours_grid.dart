import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import 'combined_hours.dart';
import 'mode_hours_parts.dart';

// One day, or one variation, of an hours card: what each mode does on it.
class HoursGridDay
{
  final String title;

  // Under the title in a column heading, after it elsewhere.
  final String? subtitle;

  final bool isToday;

  // A mode left out does not concern this day.
  final Map<String, Widget> modes;

  // The whole day answers it: column, tile or line.
  final VoidCallback? onTap;

  const HoursGridDay({
    required this.title,
    this.subtitle,
    this.isToday = false,
    required this.modes,
    this.onTap,
  });

  String get fullTitle => subtitle == null ? title : '$title $subtitle';
}

// Days as columns and modes as rows when every day fits side by side, so the
// width goes to the days and another band only adds height. Otherwise a tile
// per day, the rows as even as they can be, and a plain list where only one
// tile would fit.
class HoursGrid extends StatelessWidget
{
  static const double _cellPadding = 8;
  static const double _tilePadding = 14;
  static const double _tileGap = 12;
  static const double _minTileWidth = 150;
  static const double _lineLabelWidth = 120;

  static final TextStyle _titleStyle = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppTheme.trialInk,
  );

  static final TextStyle _subtitleStyle = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppTheme.trialMutedText,
  );

  final List<HoursGridDay> days;

  // The widest single entry any cell holds: a time, a Chiuso, a heading line.
  final double entryWidth;

  const HoursGrid({super.key, required this.days, required this.entryWidth});

  static TextStyle get titleStyle => _titleStyle;

  static TextStyle get subtitleStyle => _subtitleStyle;

  @override
  Widget build(BuildContext context)
  {
    double headingWidth({required double fontSize, required double iconSize})
    {
      return kHoursModes
          .map((mode) => ModeHeading.widthOf(context, mode, fontSize: fontSize, iconSize: iconSize))
          .reduce(math.max);
    }

    final labelWidth = headingWidth(fontSize: 14, iconSize: 18) + 2 * _cellPadding;
    final tileWidth = math.max(
      _minTileWidth,
      math.max(entryWidth, headingWidth(fontSize: 13, iconSize: 16)) + 2 * _tilePadding,
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final available = constraints.maxWidth;

        if (labelWidth + days.length * (entryWidth + 2 * _cellPadding) <= available)
        {
          return _buildTable(labelWidth, available);
        }

        final fit = math.min(days.length, ((available + _tileGap) / (tileWidth + _tileGap)).floor());

        if (fit <= 1)
        {
          return _buildList();
        }

        // Seven over two rows is four and three, never five and two.
        final rows = (days.length / fit).ceil();

        return _buildTiles((days.length / rows).ceil());
      },
    );
  }

  Widget _buildTable(double labelWidth, double width)
  {
    final lastRow = kHoursModes.length;

    // The rules between rows belong to the cells: in today's column they are
    // inset by the frame's rim, so they meet it instead of cutting through it.
    Widget cell(int row, Widget child, {HoursGridDay? day})
    {
      final inset = (day?.isToday ?? false) ? TodayFrame.rim : 0.0;

      return _tappable(day, Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _cellPadding - inset, vertical: _cellPadding),
          alignment: day == null ? Alignment.topLeft : Alignment.topCenter,
          decoration: row < lastRow
              ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine)))
              : null,
          child: child,
        ),
      ));
    }

    final table = Table(
      columnWidths: {0: FixedColumnWidth(labelWidth)},
      defaultColumnWidth: const FlexColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: [
        TableRow(
          children: [
            cell(0, const SizedBox.shrink()),
            for (final day in days)
              cell(
                0,
                day: day,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(day.title, maxLines: 1, softWrap: false, style: _titleStyle),
                    if (day.subtitle case final subtitle?)
                      Text(subtitle, maxLines: 1, softWrap: false, style: _subtitleStyle),
                  ],
                ),
              ),
          ],
        ),
        for (final (i, mode) in kHoursModes.indexed)
          TableRow(
            children: [
              cell(i + 1, ModeHeading(mode: mode, fontSize: 14, iconSize: 18)),
              for (final day in days) cell(i + 1, day: day, day.modes[mode] ?? const SizedBox.shrink()),
            ],
          ),
      ],
    );

    final today = days.indexWhere((day) => day.isToday);
    final column = (width - labelWidth) / days.length;

    if (today < 0)
    {
      return table;
    }

    return Stack(
      children: [
        // Behind the table, so the cells draw on its white.
        Positioned(
          left: labelWidth + today * column,
          width: column,
          top: 0,
          bottom: 0,
          child: const TodayFrame(radius: 16),
        ),
        table,
      ],
    );
  }

  Widget _buildTiles(int perRow)
  {
    final rows = <List<HoursGridDay>>[
      for (var start = 0; start < days.length; start += perRow)
        days.sublist(start, math.min(start + perRow, days.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: _tileGap),
          // IntrinsicHeight so the tiles of a row end level.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < perRow; j++) ...[
                  if (j > 0) const SizedBox(width: _tileGap),
                  Expanded(child: j < row.length ? _buildTile(row[j]) : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTile(HoursGridDay day)
  {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(day.fullTitle, maxLines: 2, style: _titleStyle),
        for (final mode in kHoursModes)
          if (day.modes[mode] case final hours?) ...[
            const SizedBox(height: 12),
            ModeHeading(mode: mode, fontSize: 13, iconSize: 16),
            const SizedBox(height: 6),
            hours,
          ],
      ],
    );

    if (day.isToday)
    {
      return _tappable(
        day,
        TodayFrame(
          radius: 16,
          child: Padding(padding: const EdgeInsets.all(_tilePadding - TodayFrame.rim), child: content),
        ),
      );
    }

    return _tappable(
      day,
      Container(
        padding: const EdgeInsets.all(_tilePadding),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppTheme.trialLine),
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }

  static Widget _tappable(HoursGridDay? day, Widget child)
  {
    final onTap = day?.onTap;

    if (onTap == null)
    {
      return child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }

  Widget _buildList()
  {
    Widget line(HoursGridDay day)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(day.fullTitle, style: _titleStyle),
          for (final mode in kHoursModes)
            if (day.modes[mode] case final hours?) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _lineLabelWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ModeHeading(mode: mode, fontSize: 14, iconSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: hours)),
                ],
              ),
            ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          if (day.isToday)
            _tappable(
              day,
              TodayFrame(
                radius: 12,
                child: Padding(padding: const EdgeInsets.all(12 - TodayFrame.rim), child: line(day)),
              ),
            )
          else
            _tappable(day, Padding(padding: const EdgeInsets.all(12), child: line(day))),
        ],
      ],
    );
  }
}

// Today as the teachers' availability marks it: white inside a rim running
// from ocean to violet.
class TodayFrame extends StatelessWidget
{
  static const double rim = 2.5;

  final double radius;
  final Widget? child;

  const TodayFrame({super.key, required this.radius, this.child});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.all(rim),
      decoration: BoxDecoration(
        gradient: AppTheme.greetingGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius - rim),
        ),
        child: child,
      ),
    );
  }
}
