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

// Fixed height matching the weekly table, so the row count is a constant.
class UpcomingVariationsCard extends StatelessWidget
{
  static const double _headlineHeight = 36.0;

  // Reserved even when empty so every row shares one height.
  static const double _noteHeight = 24.0;

  static const double _hoursHeight = 24.0;

  static const double _dateColumnPadding = 16.0;
  static const double _minDateColumn = 130.0;
  static const double _maxDateColumn = 280.0;

  // A time range is ~92 wide; leaves margin per band column.
  static const double _minHoursWidth = 3 * 108.0;

  static const double _hoursHeaderHeight = 40.0;

  static const double _groupGap = 20.0;

  static const double _availableHeight = kUpcomingVariationsCardHeight - kHoursCardChrome;

  final List<OpeningDayItem> upcomingVariations;

  // Rows past windowEnd are still fed in so a run keeps its real end date.
  final DateTime windowEnd;

  final bool isLoading;

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
      child: LayoutBuilder(builder: (context, constraints)
      {
        final candidates = VariationGroup.from(upcomingVariations, startsOnOrBefore: windowEnd);

        // Measured over all candidates to avoid a circular dependency with the visible rows.
        final dateWidth = _dateColumnWidth(candidates, MediaQuery.textScalerOf(context));
        final stackHours = constraints.maxWidth < _oneLineWidth(dateWidth);

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

  List<VariationGroup> _visible(List<VariationGroup> groups, bool stackHours)
  {
    final free = _availableHeight - (stackHours ? 0 : _hoursHeaderHeight);
    final fit = (free + _groupGap) ~/ (_rowHeight(stackHours) + _groupGap);

    return groups.take(math.max(fit, 0)).toList();
  }

  double _rowHeight(bool stackHours)
  {
    return _headlineHeight + (stackHours ? _hoursHeight : 0) + _noteHeight;
  }

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

class VariationRow extends StatelessWidget
{
  // Reserved even for holidays (no buttons) so hours stay column-aligned.
  static const double actionsWidth = 72;

  // Zero, but kept because the header measures its indent from it.
  static const double leadingWidth = 0;

  static const double columnGap = 24;

  static final TextStyle dateStyle = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppTheme.trialInk,
  );

  final VariationGroup group;

  final double dateWidth;

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
              if (stackHours)
                Expanded(child: _buildDate())
              else ...[
                SizedBox(width: dateWidth, child: _buildDate()),
                const SizedBox(width: columnGap),
                Expanded(child: _buildHours()),
              ],
              const SizedBox(width: columnGap),
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
            child: Padding(
              padding: const EdgeInsets.only(left: leadingWidth),
              child: _buildHours(),
            ),
          ),
        // Laid out even when empty so every row is the same height.
        SizedBox(
          height: noteHeight,
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

  // Falls back to filling slots left to right when bands do not map cleanly
  // (only reachable with data older than the 06:00-23:00 bounds).
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
