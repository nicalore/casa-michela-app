import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/desktop_tour.dart';
import '../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../shared/widgets/page_density.dart';
import '../../../../shared/widgets/shared_components.dart';
import '../../models/opening_day_item.dart';
import 'combined_hours.dart';
import 'hours_strings.dart';
import 'mode_hours_parts.dart';

class CombinedVariationsCard extends StatelessWidget
{
  static const double _bandsFontSize = 15;
  static const double _gap = 28;

  // Below the wide window (AppPageDensity), as the other cards there.
  static const double _denseBandsFontSize = 13.5;
  static const double _denseGap = 16;
  static const double _denseLinePadding = 9;

  // Below this beside the date, the changes drop under it.
  static const double _minChangesWidth = 260;

  // The pencil and the bin (24 with 6 around each) and the gap before them.
  static const double _actionsWidth = 2 * (24 + 2 * 6) + 12;

  static TextStyle _dateStyle({required bool dense}) => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13.5 : 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialInk,
      );

  // Rows past [windowEnd] are included so a run keeps its real end date.
  final List<OpeningDayItem> upcomingVariations;

  final DateTime windowEnd;
  final bool isLoading;

  // Both null for a reader: the lines then carry no buttons.
  final ValueChanged<CombinedVariation>? onEdit;
  final ValueChanged<CombinedVariation>? onDelete;

  // Lit by a tour only with variations listed.
  final String? tour;

  const CombinedVariationsCard({
    super.key,
    required this.upcomingVariations,
    required this.windowEnd,
    required this.isLoading,
    this.onEdit,
    this.onDelete,
    this.tour,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool listed = !isLoading && CombinedVariation.from(upcomingVariations, startsOnOrBefore: windowEnd).isNotEmpty;

    // Below the wide window the card takes the page's sizes, as the other cards there.
    final bool dense = AppPageDensity.of(context);

    return DesktopTourTarget(
      id: listed ? tour : null,
      child: AppCard(
        title: kUpcomingVariationsTitle,
        compact: !dense,
        selectable: false,
        leading: AppCardBadge(icon: kVariationIcon, compact: !dense),
        child: _buildBody(context, dense: dense),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {required bool dense})
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.trialTealDeep),
        ),
      );
    }

    final runs = CombinedVariation.from(upcomingVariations, startsOnOrBefore: windowEnd);

    if (runs.isEmpty)
    {
      return Center(
        child: Text(
          kNoUpcomingVariations,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: dense ? 14 : 16, color: AppTheme.trialMutedText),
        ),
      );
    }

    final dateWidth = runs.map((run) => measureText(context, run.dateLabel, _dateStyle(dense: dense))).reduce(math.max);
    final double gap = dense ? _denseGap : _gap;
    final double linePadding = dense ? _denseLinePadding : 12;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Below the wide window the buttons' room counts too: beside them a time was cut.
        final double actions = dense && (onEdit != null || onDelete != null) ? _actionsWidth : 0;
        final stacked = dateWidth + gap + _minChangesWidth + actions > constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, run) in runs.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
              Padding(
                padding: EdgeInsets.only(
                  top: i == 0 ? 0 : linePadding,
                  bottom: i == runs.length - 1 ? 0 : linePadding,
                ),
                child: _buildLine(run, dateWidth, stacked: stacked, dense: dense),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLine(CombinedVariation run, double dateWidth, {required bool stacked, required bool dense})
  {
    final double gap = dense ? _denseGap : _gap;
    final date = OverflowTooltipText(text: run.dateLabel, maxLines: 1, style: _dateStyle(dense: dense));

    final changes = Wrap(
      spacing: gap,
      runSpacing: dense ? 6 : 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final mode in kHoursModes)
          if (run.bandsByMode.containsKey(mode))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dense
                    ? ModeHeading(mode: mode, fontSize: 12, iconSize: 15)
                    : ModeHeading(mode: mode, fontSize: 14, iconSize: 18),
                SizedBox(width: dense ? 7 : 10),
                Flexible(child: _modeHours(run, mode, dense: dense)),
              ],
            ),
        if (run.note case final note?) VariationNote(note, maxLines: 2, dense: dense),
      ],
    );

    final actions = _buildActions(run);

    if (stacked)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: date),
              ?actions,
            ],
          ),
          SizedBox(height: dense ? 6 : 8),
          changes,
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: dateWidth, child: date),
        SizedBox(width: gap),
        Expanded(child: changes),
        if (actions != null) ...[
          const SizedBox(width: 12),
          actions,
        ],
      ],
    );
  }

  Widget? _buildActions(CombinedVariation run)
  {
    if ((onEdit == null && onDelete == null) || run.isHoliday)
    {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit case final edit?)
          FadeHoverIconButton(
            icon: Icons.edit_outlined,
            color: AppTheme.trialTealDeep,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: () => edit(run),
          ),
        if (onDelete case final delete?)
          FadeHoverIconButton(
            icon: Icons.delete_outline_rounded,
            color: AppTheme.trialDanger,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: () => delete(run),
          ),
      ],
    );
  }

  static Widget _modeHours(CombinedVariation run, String mode, {required bool dense})
  {
    if (run.isClosed(mode))
    {
      return ClosedPill(isOverride: true, dense: dense);
    }

    return BandTimes(
      bands: run.bandsByMode[mode]!,
      fontSize: dense ? _denseBandsFontSize : _bandsFontSize,
      markVariations: false,
    );
  }
}
