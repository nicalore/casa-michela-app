import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/models/availability_item.dart';
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_card_delete_buttons.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../mobile_availability_week.dart';

const double _blockRadius = 20;
const double _blockGap = 8;

const double _rowHeight = 42;

// Locked slots fade through their colours: an Opacity trips Impeller's check.
const double _lockedFade = 0.5;
const double _actionSize = 40;

// Returned by the day sheet; the page confirms and carries it out.
sealed class MobileDaySheetAction
{
  const MobileDaySheetAction();
}

class MobileDeleteSlot extends MobileDaySheetAction
{
  final AvailabilityItem slot;

  const MobileDeleteSlot(this.slot);
}

class MobileDeleteBand extends MobileDaySheetAction
{
  final MobileAvailabilityBand band;

  const MobileDeleteBand(this.band);
}

class MobileDeleteDay extends MobileDaySheetAction
{
  const MobileDeleteDay();
}

class MobileEditDay extends MobileDaySheetAction
{
  const MobileEditDay();
}

String _deleteAllLabel(TimeBucket band)
{
  return switch (band)
  {
    TimeBucket.morning => 'Elimina tutta la mattina',
    TimeBucket.afternoon => 'Elimina tutto il pomeriggio',
    TimeBucket.evening => 'Elimina tutta la sera',
  };
}

Future<void> showMobileAvailabilityDaySheet({
  required BuildContext context,
  required MobileAvailabilityDay day,
  required bool editable,
  required Future<void> Function(BuildContext sheet, MobileDaySheetAction action) onAction,
})
{
  // With one band holding slots, its own deletion already empties the day.
  final bool wholeDay = day.canDelete && day.bands.where((band) => band.slots.isNotEmpty).length > 1;

  return showMobileSheet<void>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: 'Disponibilità',
      title: formatAvailableDayLabel(day.date),
      body: [
        const SizedBox(height: 14),
        for (final (i, band) in day.shownBands.indexed) ...[
          if (i > 0) const SizedBox(height: _blockGap),
          _BandBlock(band: band, onAction: (action) => onAction(context, action)),
        ],
      ],
      footer: editable
          ? Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Column(
                children: [
                  MobileGoldButton(
                    label: 'Modifica',
                    icon: Icons.edit_outlined,
                    onPressed: () => onAction(context, const MobileEditDay()),
                  ),
                  if (wholeDay) ...[
                    const SizedBox(height: 12),
                    MobileDangerButton(
                      label: 'Elimina la giornata',
                      icon: Icons.delete_outline_rounded,
                      onPressed: () => onAction(context, const MobileDeleteDay()),
                    ),
                  ],
                ],
              ),
            )
          : null,
    ),
  );
}

class _BandBlock extends StatelessWidget
{
  final MobileAvailabilityBand band;
  final ValueChanged<MobileDaySheetAction> onAction;

  const _BandBlock({required this.band, required this.onAction});

  Widget _buildHead()
  {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Text(
            bandLabel(band.band).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: MobilePalette.mutedText,
            ),
          ),
          if (band.showsLock) ...[
            const SizedBox(width: 5),
            const Icon(Icons.lock_outline_rounded, size: 13, color: MobilePalette.mutedText),
          ],
        ],
      ),
    );
  }

  Widget _buildOpenings()
  {
    final TextStyle hours = GoogleFonts.plusJakartaSans(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: MobilePalette.mutedText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: [
          Text(
            'Apertura'.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: MobilePalette.mutedText.withValues(alpha: 0.8),
            ),
          ),
          for (final (mode, window) in band.openings)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(lessonModeIcon(mode), size: 14, color: MobilePalette.mutedText),
                const SizedBox(width: 4),
                Text(formatMinutesRange(window.startMinutes, window.endMinutes), style: hours),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(_blockRadius),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHead(),
          if (band.slots.isEmpty)
            const _Divided(child: _Empty())
          else
            for (final slot in band.slots)
              _Divided(
                child: _SlotRow(
                  slot: slot,
                  locked: band.isLocked,
                  onDelete: band.canDelete ? () => onAction(MobileDeleteSlot(slot)) : null,
                ),
              ),
          if (band.isOpen) _buildOpenings(),
          // With one slot its own bin already empties the band.
          if (band.canDelete && band.slots.length > 1)
            _Divided(
              child: Padding(
                // Square with the block's left padding.
                padding: const EdgeInsets.fromLTRB(0, 10, 6, 6),
                child: MobileCardDeleteButton(
                  label: _deleteAllLabel(band.band),
                  onPressed: () => onAction(MobileDeleteBand(band)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Divided extends StatelessWidget
{
  final Widget child;

  const _Divided({required this.child});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.07))),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowHeight),
        child: child,
      ),
    );
  }
}

class _SlotRow extends StatelessWidget
{
  final AvailabilityItem slot;
  final bool locked;
  final VoidCallback? onDelete;

  const _SlotRow({required this.slot, required this.locked, required this.onDelete});

  @override
  Widget build(BuildContext context)
  {
    final bool online = slot.mode == kOnlineMode;
    final VoidCallback? onDelete = this.onDelete;

    Color ink(Color color) => locked ? color.withValues(alpha: color.a * _lockedFade) : color;

    final Widget facts = Row(
      children: [
        Icon(
          lessonModeIcon(slot.mode),
          size: 19,
          color: ink(online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            modeLabel(slot.mode),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: ink(AppTheme.trialInk.withValues(alpha: 0.75)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatTimeRange(slot.startTime, slot.endTime),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: ink(AppTheme.trialInk),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(child: facts),
        if (onDelete == null)
          const SizedBox(width: _actionSize)
        else
          MobileCardBinButton(onPressed: onDelete, extent: _actionSize),
      ],
    );
  }
}

class _Empty extends StatelessWidget
{
  const _Empty();

  @override
  Widget build(BuildContext context)
  {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Nessuna disponibilità',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w600,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }
}
