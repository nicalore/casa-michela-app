import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../shared/widgets/shared_components.dart';
import '../../models/opening_day_item.dart';
import 'combined_hours.dart';
import 'hours_strings.dart';
import 'mode_hours_parts.dart';

class CombinedVariationsCard extends StatelessWidget
{
  static const double _bandsFontSize = 15;
  static const double _gap = 28;

  // Below this beside the date, the changes drop under it.
  static const double _minChangesWidth = 260;

  static final TextStyle _dateStyle = GoogleFonts.plusJakartaSans(
    fontSize: 16,
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

  const CombinedVariationsCard({
    super.key,
    required this.upcomingVariations,
    required this.windowEnd,
    required this.isLoading,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: kUpcomingVariationsTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: kVariationIcon, compact: true),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context)
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
      return Text(
        kNoUpcomingVariations,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: AppTheme.trialMutedText),
      );
    }

    final dateWidth = runs.map((run) => measureText(context, run.dateLabel, _dateStyle)).reduce(math.max);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final stacked = dateWidth + _gap + _minChangesWidth > constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, run) in runs.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: i == runs.length - 1 ? 0 : 12),
                child: _buildLine(run, dateWidth, stacked: stacked),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLine(CombinedVariation run, double dateWidth, {required bool stacked})
  {
    final date = OverflowTooltipText(text: run.dateLabel, maxLines: 1, style: _dateStyle);

    final changes = Wrap(
      spacing: _gap,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final mode in kHoursModes)
          if (run.bandsByMode.containsKey(mode))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModeHeading(mode: mode, fontSize: 14, iconSize: 18),
                const SizedBox(width: 10),
                Flexible(child: _modeHours(run, mode)),
              ],
            ),
        if (run.note case final note?) VariationNote(note, maxLines: 2),
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
          const SizedBox(height: 8),
          changes,
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: dateWidth, child: date),
        const SizedBox(width: _gap),
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

  static Widget _modeHours(CombinedVariation run, String mode)
  {
    if (run.isClosed(mode))
    {
      return const ClosedPill(isOverride: true);
    }

    return BandTimes(bands: run.bandsByMode[mode]!, fontSize: _bandsFontSize, markVariations: false);
  }
}
