import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../shared/widgets/shared_components.dart';
import '../../models/opening_day_item.dart';
import 'opening_hours_layout.dart';
import '../../../../core/utils/time_bucket.dart';
import 'variation_group.dart';

// Fixed height, matching the weekly table it sits next to (see
// opening_hours_layout.dart), so the number of rows that fit is a constant rather than
// something measured at layout time.
class UpcomingVariationsCard extends StatelessWidget
{
  // Tall enough for the action buttons, which are the tallest thing on the
  // headline row.
  static const double _headlineHeight = 36.0;

  // Reserved on every row, note or no note: rows that changed height with
  // their content made the list ragged and moved the ones below whenever a
  // note was added or removed.
  static const double _noteHeight = 24.0;

  // Only paid when the hours drop below the date instead of sharing its line.
  static const double _hoursHeight = 24.0;

  // The bounds the measured date column is held between: enough that a short
  // date does not pull the hours against it, capped so a long span cannot push
  // them off the row.
  static const double _dateColumnPadding = 16.0;
  static const double _minDateColumn = 130.0;
  static const double _maxDateColumn = 280.0;

  // What the three band columns need before the row stops being worth keeping
  // on one line — a time range is about 92 wide, so this leaves each of them a
  // little room either side.
  static const double _minHoursWidth = 3 * 108.0;

  // Labels + rule + the gap under them. Only drawn where the rows really do
  // share three columns, which is the one-line layout.
  static const double _hoursHeaderHeight = 40.0;

  // Generous on purpose: variations are read one at a time, and packing them
  // tight turned the card into a wall of dates.
  static const double _groupGap = 20.0;

  static const double _availableHeight = kUpcomingVariationsCardHeight - kHoursCardChrome;

  final List<OpeningDayItem> upcomingVariations;

  // Last day a variation may start on to count as upcoming. Rows past it are
  // still fed in, so a run that begins inside the window and carries on
  // beyond it keeps its real end date.
  final DateTime windowEnd;

  final bool isLoading;

  // Both act on a whole group — the run of days it covers — never on the one
  // row that happens to have been clicked. Not called for public holidays,
  // which carry no buttons.
  final ValueChanged<VariationGroup> onEdit;
  final ValueChanged<VariationGroup> onDelete;

  const UpcomingVariationsCard({
    super.key,
    required this.upcomingVariations,
    required this.windowEnd,
    required this.isLoading,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: kUpcomingVariationsCardHeight,
      // Inside the padding, so the width read here is the one the rows get.
      child: LayoutBuilder(builder: (context, constraints)
      {
        final candidates = VariationGroup.from(upcomingVariations, startsOnOrBefore: windowEnd);

        // Measured over every candidate rather than over the rows that end up
        // visible: the two would otherwise define each other, since how many
        // fit depends on how tall a row is, which depends on this.
        final dateWidth = _dateColumnWidth(candidates, MediaQuery.textScalerOf(context));
        final stackHours = constraints.maxWidth < _oneLineWidth(dateWidth);

        // How much of the window the card can hold without scrolling, which
        // depends on how tall a row turned out to be.
        final groups = _visible(candidates, stackHours);

        return AppCard(
          title: 'Prossime variazioni',
          compact: true,
          leading: const AppCardBadge(icon: Icons.flag_rounded, compact: true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.trialTealDeep),
                ),
              )
            else if (groups.isEmpty)
              Text(
                'Nessuna variazione programmata.',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppTheme.trialMutedText),
              )
            else ...[
              // Without it the three positions carry no meaning, and a row
              // showing one band in the middle just reads as badly aligned.
              if (!stackHours)
                VariationHoursHeader(height: _hoursHeaderHeight, dateWidth: dateWidth),
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const SizedBox(height: _groupGap),
                VariationRow(
                  group: groups[i],
                  dateWidth: dateWidth,
                  stackHours: stackHours,
                  headlineHeight: _headlineHeight,
                  hoursHeight: _hoursHeight,
                  noteHeight: _noteHeight,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ],
            ],
          ),
        );
      }),
    );
  }

  // The groups that fit the pinned height, in order. Every row is the same
  // height, so this is a division rather than a running total.
  List<VariationGroup> _visible(List<VariationGroup> groups, bool stackHours)
  {
    final free = _availableHeight - (stackHours ? 0 : _hoursHeaderHeight);
    // The gap sits between rows, so the last one does not pay for it.
    final fit = (free + _groupGap) ~/ (_rowHeight(stackHours) + _groupGap);

    return groups.take(math.max(fit, 0)).toList();
  }

  // One height for every row, whatever it holds: the note line is reserved
  // even when empty, and the hours line only exists in the stacked layout.
  double _rowHeight(bool stackHours)
  {
    return _headlineHeight + (stackHours ? _hoursHeight : 0) + _noteHeight;
  }

  // Measured off the longest label on screen rather than taken as a share of the
  // row, which had to be sized for the worst case and left a gulf on every other
  // row. One width for all of them, so the columns still line up.
  double _dateColumnWidth(List<VariationGroup> groups, TextScaler textScaler)
  {
    var widest = 0.0;

    for (final group in groups)
    {
      final painter = TextPainter(
        text: TextSpan(text: group.dateLabel, style: VariationRow.dateStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();

      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return (widest + _dateColumnPadding).clamp(_minDateColumn, _maxDateColumn);
  }

  // The width below which the row can no longer carry date, hours and buttons
  // on one line.
  double _oneLineWidth(double dateWidth)
  {
    return VariationRow.leadingWidth +
        dateWidth +
        VariationRow.columnGap +
        _minHoursWidth +
        VariationRow.columnGap +
        VariationRow.actionsWidth;
  }
}

// One variation in columns rather than a running sentence: the date left, the
// hours in the same three band positions the weekly table uses, actions right.
// A comma list packed everything against the left edge and was slow to read,
// where fixed positions say at a glance which part of the day is touched.
class VariationRow extends StatelessWidget
{
  // Reserved even where the buttons are not drawn, so a holiday's hours stay
  // in the same columns as every other row's.
  static const double actionsWidth = 72;

  // Zero now that the rows carry no mark of their own: every variation here is
  // one. The constant stays because the header measures its indent from it.
  static const double leadingWidth = 0;

  static const double columnGap = 24;

  // Shared with the card, which measures the date column against it.
  static final TextStyle dateStyle = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppTheme.trialInk,
  );

  final VariationGroup group;

  // Measured by the card over every row, so the hours start at the same place
  // on all of them without a short date leaving a gap in front of them.
  final double dateWidth;

  // True when the row is too narrow to hold date, hours and actions on one
  // line, so the hours take a line of their own underneath.
  final bool stackHours;

  final double headlineHeight;
  final double hoursHeight;
  final double noteHeight;
  final ValueChanged<VariationGroup> onEdit;
  final ValueChanged<VariationGroup> onDelete;

  const VariationRow({
    super.key,
    required this.group,
    required this.dateWidth,
    required this.stackHours,
    required this.headlineHeight,
    required this.hoursHeight,
    required this.noteHeight,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _hasNote => group.note != null && group.note!.isNotEmpty;

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: headlineHeight,
          child: Row(
            children: [
              // Fixed rather than a share of the row, which would grow with the
              // card and park the hours far from short dates. Stacked, there is
              // nothing to line up with and the date takes what is left.
              if (stackHours)
                Expanded(child: _buildDate())
              else ...[
                SizedBox(width: dateWidth, child: _buildDate()),
                const SizedBox(width: columnGap),
                Expanded(child: _buildHours()),
              ],
              const SizedBox(width: columnGap),
              // Holidays keep the row's shape without the actions rather than
              // showing disabled ones: there is nothing an admin could do to
              // Natale that the next generation would not undo.
              if (group.isHoliday)
                const SizedBox(width: actionsWidth)
              else
                SizedBox(
                  width: actionsWidth,
                  child: Row(
                    children: [
                      FadeHoverIconButton(
                        icon: Icons.edit_outlined,
                        color: AppTheme.trialTealDeep,
                        hoverColor: AppTheme.trialGoldSurface,
                        onTap: () => onEdit(group),
                      ),
                      FadeHoverIconButton(
                        icon: Icons.delete_outline_rounded,
                        color: AppTheme.trialDanger,
                        // Gold, like every other hover in the app: the red of
                        // the glyph already says what the button does, and a
                        // red wash under it said it twice.
                        hoverColor: AppTheme.trialGoldSurface,
                        onTap: () => onDelete(group),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (stackHours)
          SizedBox(
            height: hoursHeight,
            // Indented to the date above, and running the full width from
            // there: narrow is exactly where the three columns need the room.
            child: Padding(
              padding: const EdgeInsets.only(left: leadingWidth),
              child: _buildHours(),
            ),
          ),
        // Always laid out, empty or not: every row is the same height, so
        // adding or clearing a note never shifts the rows below it.
        SizedBox(
          height: noteHeight,
          // Indented to the date above it, so the note reads as hanging off
          // that row rather than as another entry.
          child: !_hasNote
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: leadingWidth),
                  child: Row(
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 15, color: AppTheme.trialMutedText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          group.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.trialMutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDate()
  {
    return Align(
      alignment: Alignment.centerLeft,
      child: OverflowTooltipText(text: group.dateLabel, maxLines: 1, style: dateStyle),
    );
  }

  Widget _buildHours()
  {
    if (group.isClosed)
    {
      // A closure has no band to sit in: it runs across all three columns, and
      // a tinted strip says that far better than the word alone parked under
      // one of the headings.
      return Container(
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.modifiedAccentSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          group.hoursLabel,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.modifiedAccent,
          ),
        ),
      );
    }

    // Stacked there is no header above to name the columns, so a lone band in
    // the middle would read as a stray rather than as "afternoon". The bands
    // are simply listed instead, in order.
    if (stackHours)
    {
      return Row(
        children: [
          for (final band in group.bands) ...[
            if (band != group.bands.first) const SizedBox(width: 24),
            Flexible(child: _buildBand(band)),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (final band in _bandSlots())
          Expanded(
            child: Center(
              child: band == null
                  ? Text(
                      '–',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: AppTheme.trialMutedText),
                    )
                  : _buildBand(band),
            ),
          ),
      ],
    );
  }

  Widget _buildBand(OpeningDayItem band)
  {
    return Text(
      formatTimeRange(band.startTime!, band.endTime!),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.modifiedAccent,
      ),
    );
  }

  // The day's bands in their three columns, falling back to filling them left to
  // right where the bands do not map cleanly — only reachable through data older
  // than the 06:00-23:00 bounds. Position stops meaning anything, but nothing is
  // dropped, which matters more.
  List<OpeningDayItem?> _bandSlots()
  {
    final slots = List<OpeningDayItem?>.filled(TimeBucket.values.length, null);

    for (final band in group.bands)
    {
      final bucket = bucketFor(band.startTime);

      if (bucket == null || slots[bucket.index] != null)
      {
        return [
          for (var i = 0; i < slots.length; i++) i < group.bands.length ? group.bands[i] : null,
        ];
      }

      slots[bucket.index] = band;
    }

    return slots;
  }
}

// Names the three columns, so a variation touching only the afternoon reads as
// such rather than as a stray value mid-row. Built from VariationRow's own
// constants, so the two cannot drift apart.
class VariationHoursHeader extends StatelessWidget
{
  final double height;
  final double dateWidth;

  const VariationHoursHeader({super.key, required this.height, required this.dateWidth});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                const SizedBox(width: VariationRow.leadingWidth),
                SizedBox(width: dateWidth),
                const SizedBox(width: VariationRow.columnGap),
                Expanded(
                  child: Row(
                    children: [
                      for (final bucket in TimeBucket.values)
                        Expanded(child: Center(child: _label(bandLabel(bucket)))),
                    ],
                  ),
                ),
                const SizedBox(width: VariationRow.columnGap),
                const SizedBox(width: VariationRow.actionsWidth),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _label(String text)
  {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}
