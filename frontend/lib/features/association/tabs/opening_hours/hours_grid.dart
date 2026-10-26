import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/page_density.dart';
import 'combined_hours.dart';
import 'mode_hours_parts.dart';

class HoursGridDay
{
  final String title;

  final String? subtitle;

  final bool isToday;

  // A mode left out does not concern this day.
  final Map<String, Widget> modes;

  // "Lun 12", "Lun": a row's label where the full one leaves the hours no room.
  final String? shortTitle;

  const HoursGridDay({
    required this.title,
    this.subtitle,
    this.isToday = false,
    required this.modes,
    this.shortTitle,
  });

  String get fullTitle => subtitle == null ? title : '$title $subtitle';
}

class HoursGrid extends StatelessWidget
{
  static const double _cellPadding = 8;
  static const double _tilePadding = 14;
  static const double _tileGap = 12;
  static const double _minTileWidth = 150;
  static const double _lineLabelWidth = 120;

  // Below the wide window (AppPageDensity), as the cards around.
  static const double _denseCellPadding = 6;
  static const double _denseHeadingSize = 12;
  static const double _denseHeadingIcon = 15;
  static const double _denseRowGap = 12;

  // Just above the dense window, where the rail leaves the wide table short of room: its text as the dense
  // window's, each column as wide as its own day. Icons keep their size, hence the slack.
  static const double _tightTextScale = 13.5 / 15;
  static const double _tightSlack = 2;

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

  static final TextStyle _denseTitleStyle = _titleStyle.copyWith(fontSize: 13.5);
  static final TextStyle _denseSubtitleStyle = _subtitleStyle.copyWith(fontSize: 11.5);

  final List<HoursGridDay> days;

  // The widest single entry any cell holds: a time, "Chiuso", a heading line.
  final double entryWidth;

  // Each day's widest entry, for the tight table's columns; [entryWidth] for every day without.
  final List<double>? dayWidths;

  const HoursGrid({super.key, required this.days, required this.entryWidth, this.dayWidths});

  static TextStyle titleStyleOf({required bool dense}) => dense ? _denseTitleStyle : _titleStyle;

  static TextStyle subtitleStyleOf({required bool dense}) => dense ? _denseSubtitleStyle : _subtitleStyle;

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double cellPadding = dense ? _denseCellPadding : _cellPadding;

    double headingWidth({required double fontSize, required double iconSize})
    {
      return kHoursModes
          .map((mode) => ModeHeading.widthOf(context, mode, fontSize: fontSize, iconSize: iconSize))
          .reduce(math.max);
    }

    final tightLabelWidth = headingWidth(fontSize: _denseHeadingSize, iconSize: _denseHeadingIcon) + 2 * _denseCellPadding;
    final labelWidth = dense ? tightLabelWidth : headingWidth(fontSize: 14, iconSize: 18) + 2 * _cellPadding;
    final tileWidth = math.max(
      _minTileWidth,
      math.max(entryWidth, headingWidth(fontSize: 13, iconSize: 16)) + 2 * _tilePadding,
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final available = constraints.maxWidth;

        if (labelWidth + days.length * (entryWidth + 2 * cellPadding) <= available)
        {
          return _buildTable(labelWidth, available, dense: dense);
        }

        // Just above the dense window the rail takes the room: a tighter table, which the dense window
        // shows again, rather than tiles for a moment.
        final List<double> columns = [
          for (var i = 0; i < days.length; i++)
            (dayWidths?[i] ?? entryWidth) * _tightTextScale + 2 * _denseCellPadding + _tightSlack,
        ];

        if (!dense && tightLabelWidth + columns.reduce((a, b) => a + b) <= available)
        {
          return _buildTable(tightLabelWidth, available, dense: false, columns: columns);
        }

        // Below the wide window the table turns rather than breaking into tiles.
        if (dense)
        {
          return _buildRows(context, available, modeWidth: math.max(entryWidth, labelWidth - 2 * cellPadding));
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

  // [columns]: the tight table's column widths, its share of the room each; equal columns without.
  Widget _buildTable(double labelWidth, double width, {required bool dense, List<double>? columns})
  {
    final lastRow = kHoursModes.length;
    final bool tight = columns != null;
    final double padding = dense || tight ? _denseCellPadding : _cellPadding;

    // Row rules belong to the cells, inset by the rim in today's column so they meet the frame.
    Widget cell(int row, Widget child, {HoursGridDay? day})
    {
      final inset = (day?.isToday ?? false) ? TodayFrame.rim : 0.0;

      final Widget content = !tight || day == null
          ? child
          : Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(MediaQuery.textScalerOf(context).scale(1) * _tightTextScale),
                ),
                child: child,
              ),
            );

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: padding - inset, vertical: padding),
          alignment: day == null ? Alignment.topLeft : Alignment.topCenter,
          decoration: row < lastRow
              ? const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine)))
              : null,
          child: content,
        ),
      );
    }

    final table = Table(
      columnWidths: {
        0: FixedColumnWidth(labelWidth),
        if (columns != null)
          for (final (i, column) in columns.indexed) i + 1: FlexColumnWidth(column),
      },
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
                    Text(day.title, maxLines: 1, softWrap: false, style: titleStyleOf(dense: dense)),
                    if (day.subtitle case final subtitle?)
                      Text(subtitle, maxLines: 1, softWrap: false, style: subtitleStyleOf(dense: dense)),
                  ],
                ),
              ),
          ],
        ),
        for (final (i, mode) in kHoursModes.indexed)
          TableRow(
            children: [
              cell(
                i + 1,
                dense || tight
                    ? ModeHeading(mode: mode, fontSize: _denseHeadingSize, iconSize: _denseHeadingIcon)
                    : ModeHeading(mode: mode, fontSize: 14, iconSize: 18),
              ),
              for (final day in days) cell(i + 1, day: day, day.modes[mode] ?? const SizedBox.shrink()),
            ],
          ),
      ],
    );

    final today = days.indexWhere((day) => day.isToday);

    if (today < 0)
    {
      return table;
    }

    // Where today's column lies, the columns sharing the room as the table shares it.
    final List<double> shares = columns ?? List.filled(days.length, 1);
    final double unit = (width - labelWidth) / shares.reduce((a, b) => a + b);
    final double before = shares.take(today).fold(0.0, (sum, share) => sum + share);

    return Stack(
      children: [
        // Behind the table, so the cells draw on its white.
        Positioned(
          left: labelWidth + before * unit,
          width: shares[today] * unit,
          top: 0,
          bottom: 0,
          child: const TodayFrame(radius: 16),
        ),
        table,
      ],
    );
  }

  // Days down, modes across: one line a day, the full name while it leaves the hours their room.
  Widget _buildRows(BuildContext context, double width, {required double modeWidth})
  {
    const double padding = _denseCellPadding;

    double labelOf({required bool short})
    {
      return days
          .map((day) => measureText(context, short ? day.shortTitle ?? day.fullTitle : day.fullTitle, _denseTitleStyle))
          .reduce(math.max);
    }

    final double column = modeWidth + 2 * padding;
    final bool short = labelOf(short: false) + _denseRowGap + 2 * column > width;
    final double label = labelOf(short: short) + _denseRowGap;

    Widget line(List<Widget> cells, {required double labelWidth})
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: labelWidth, child: cells.first),
          for (final cell in cells.skip(1))
            Expanded(child: Align(alignment: Alignment.topLeft, child: cell)),
        ],
      );
    }

    // [inset]: inside today's frame the padding gives way to its rim, so the columns stay in line.
    Widget dayLine(HoursGridDay day, {required double inset})
    {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding - inset, vertical: padding),
        child: line(
          [
            Text(short ? day.shortTitle ?? day.fullTitle : day.fullTitle, maxLines: 1, softWrap: false, style: _denseTitleStyle),
            for (final mode in kHoursModes) day.modes[mode] ?? const SizedBox.shrink(),
          ],
          labelWidth: label,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(padding, 0, padding, padding),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine))),
          child: line(
            [
              const SizedBox.shrink(),
              for (final mode in kHoursModes)
                ModeHeading(mode: mode, fontSize: _denseHeadingSize, iconSize: _denseHeadingIcon),
            ],
            labelWidth: label,
          ),
        ),
        for (final (i, day) in days.indexed)
          if (day.isToday)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: TodayFrame(radius: 12, child: dayLine(day, inset: TodayFrame.rim)),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                border: i < days.length - 1 && !days[i + 1].isToday
                    ? const Border(bottom: BorderSide(color: AppTheme.trialLine))
                    : null,
              ),
              child: dayLine(day, inset: 0),
            ),
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
      return TodayFrame(
        radius: 16,
        child: Padding(padding: const EdgeInsets.all(_tilePadding - TodayFrame.rim), child: content),
      );
    }

    return Container(
      padding: const EdgeInsets.all(_tilePadding),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.trialLine),
        borderRadius: BorderRadius.circular(16),
      ),
      child: content,
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
            TodayFrame(
              radius: 12,
              child: Padding(padding: const EdgeInsets.all(12 - TodayFrame.rim), child: line(day)),
            )
          else
            Padding(padding: const EdgeInsets.all(12), child: line(day)),
        ],
      ],
    );
  }
}

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
