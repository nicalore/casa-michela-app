import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/models/availability_item.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../mobile_availability_week.dart';

const double _radius = 22;

// Past days use muted colours at full alpha: an Opacity over glass trips Impeller.

// A closed day is the same glass, thinner.
const double _closedAlpha = 0.43;

const double _minTileWidth = 38;
const double _wideMinTileWidth = 56;

const double _trailingWidth = 32;
const double _buttonSize = 32;

const double _labelGap = 6;
const double _lockGap = 4;
const double _lockSize = 12;
const double _ruleGap = 7;
const double _stackGap = 4;

const double _chipPadding = 9;
const double _chipIconGap = 4;
const double _chipGap = 5;
const double _chipRadius = 8;

const double _wideColumnGap = 18;

// Shared by every card so the names line up down the list.
class _Sizes
{
  final bool wide;

  const _Sizes(this.wide);

  EdgeInsets get padding => wide
      ? const EdgeInsets.fromLTRB(14, 15, 16, 15)
      : const EdgeInsets.fromLTRB(12, 13, 10, 13);

  double get tileGap => wide ? 14 : 10;
  double get rowsGap => wide ? 14 : 12;

  double get weekdaySize => wide ? 10.5 : 9.5;
  double get numberSize => wide ? 27 : 23;
  double get labelSize => wide ? 10.5 : 9.5;
  double get chipSize => wide ? 13 : 12;
  double get chipIcon => wide ? 17 : 14;
  double get chipHeight => wide ? 30 : 26;
  double get noteSize => wide ? 13 : 12.5;

  TextStyle get labelStyle => GoogleFonts.plusJakartaSans(
        fontSize: labelSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: MobilePalette.mutedText,
      );

  TextStyle get noteStyle => GoogleFonts.plusJakartaSans(
        fontSize: noteSize,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: MobilePalette.mutedText,
      );

  TextStyle chipStyle(Color color) => GoogleFonts.plusJakartaSans(
        fontSize: chipSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

double _textWidth(String text, TextStyle style, TextScaler scaler)
{
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();

  return painter.width;
}

String _bandName(TimeBucket band) => bandLabel(band).toUpperCase();

String _hours(AvailabilityItem slot) => formatTimeRange(slot.startTime, slot.endTime);

class MobileAvailabilityDayCard extends StatelessWidget
{
  final MobileAvailabilityDay day;

  final bool wide;

  final VoidCallback? onOpen;
  final VoidCallback? onAdd;

  const MobileAvailabilityDayCard({
    super.key,
    required this.day,
    required this.wide,
    this.onOpen,
    this.onAdd,
  });

  bool get _opens => day.isEditable && day.hasSlots && onOpen != null;

  bool get _adds => day.isEditable && !day.hasSlots && onAdd != null;

  VoidCallback? get _onTap => _opens ? onOpen : (_adds ? onAdd : null);

  Widget _buildTile(_Sizes sizes, double width)
  {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekdayShortName(day.date.weekday).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: sizes.weekdaySize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: MobilePalette.mutedText,
            ),
          ),
          Text(
            '${day.date.day}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: sizes.numberSize,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: day.isClosed
                  ? AppTheme.trialInk.withValues(alpha: 0.45)
                  : (day.isPast ? MobilePalette.mutedText : AppTheme.trialInk),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (day.isToday) ...[
            const SizedBox(height: 5),
            const MobilePill('Oggi', tone: MobilePillTone.teal, dense: true),
          ],
        ],
      ),
    );
  }

  Widget _buildLabel(_Sizes sizes, MobileAvailabilityBand band)
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_bandName(band.band), maxLines: 1, softWrap: false, style: sizes.labelStyle),
        if (band.showsLock) ...[
          const SizedBox(width: _lockGap),
          Icon(
            Icons.lock_outline_rounded,
            size: _lockSize,
            color: MobilePalette.mutedText.withValues(alpha: 0.85),
          ),
        ],
      ],
    );
  }

  Widget _buildChips(_Sizes sizes, MobileAvailabilityBand band, {required bool column})
  {
    final List<Widget> chips = [
      for (final slot in band.slots)
        _SlotChip(slot: slot, sizes: sizes, locked: band.isLocked),
    ];

    if (column)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, chip) in chips.indexed) ...[
            if (i > 0) const SizedBox(height: _chipGap),
            chip,
          ],
        ],
      );
    }

    return Wrap(spacing: _chipGap, runSpacing: _chipGap, children: chips);
  }

  Widget _buildContent(_Sizes sizes, MobileAvailabilityBand band, {bool column = false})
  {
    if (band.slots.isNotEmpty)
    {
      return _buildChips(sizes, band, column: column);
    }

    if (!band.isOpen)
    {
      return Text(
        'Associazione chiusa',
        style: sizes.noteStyle.copyWith(color: MobilePalette.mutedText.withValues(alpha: 0.6)),
      );
    }

    return Text('Nessuna disponibilità', style: sizes.noteStyle);
  }

  // Beside its name while both fit; with larger text, under it rather than cut.
  Widget _buildBandRow(_Sizes sizes, MobileAvailabilityBand band, double labelWidth, bool inline)
  {
    final Widget content = _buildContent(sizes, band);

    if (!inline)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(sizes, band),
          const SizedBox(height: _stackGap),
          content,
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: sizes.chipHeight),
      child: Row(
        children: [
          SizedBox(width: labelWidth, child: _buildLabel(sizes, band)),
          const SizedBox(width: _labelGap),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildClosed(_Sizes sizes)
  {
    return Row(
      children: [
        const Icon(Icons.event_busy_rounded, size: 18, color: MobilePalette.mutedText),
        const SizedBox(width: 8),
        Expanded(child: Text("L'Associazione è chiusa", style: sizes.noteStyle.copyWith(fontSize: 13))),
      ],
    );
  }

  Widget _buildBands(_Sizes sizes, TextScaler scaler, double width)
  {
    if (day.isClosed)
    {
      return _buildClosed(sizes);
    }

    if (sizes.wide)
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, band) in day.bands.indexed) ...[
            if (i > 0) const SizedBox(width: _wideColumnGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(sizes, band),
                  const SizedBox(height: 7),
                  _buildContent(sizes, band, column: true),
                ],
              ),
            ),
          ],
        ],
      );
    }

    final double labelWidth = TimeBucket.values
            .map((band) => _textWidth(_bandName(band), sizes.labelStyle, scaler))
            .reduce(math.max) +
        _lockGap +
        _lockSize;

    final List<MobileAvailabilityBand> bands = day.shownBands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, band) in bands.indexed) ...[
          if (i > 0)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: _ruleGap),
              color: AppTheme.trialInk.withValues(alpha: 0.1),
            ),
          _buildBandRow(
            sizes,
            band,
            labelWidth,
            labelWidth + _labelGap + _contentWidth(sizes, band, scaler) <= width,
          ),
        ],
      ],
    );
  }

  double _contentWidth(_Sizes sizes, MobileAvailabilityBand band, TextScaler scaler)
  {
    if (band.slots.isEmpty)
    {
      return _textWidth('Nessuna disponibilità', sizes.noteStyle, scaler);
    }

    return band.slots
        .map((slot) => _chipWidth(sizes, slot, scaler))
        .reduce(math.max);
  }

  double _chipWidth(_Sizes sizes, AvailabilityItem slot, TextScaler scaler)
  {
    return _chipPadding * 2 +
        sizes.chipIcon +
        _chipIconGap +
        _textWidth(_hours(slot), sizes.chipStyle(AppTheme.trialInk), scaler);
  }

  Widget _buildButton(IconData icon, double size)
  {
    return Container(
      width: _buttonSize,
      height: _buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.trialGoldSurface,
        border: Border.all(color: AppTheme.trialGold.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Icon(icon, size: size, color: AppTheme.modifiedAccent),
    );
  }

  Widget _buildTrailing()
  {
    if (_opens)
    {
      return _buildButton(Icons.open_in_full_rounded, 16);
    }

    if (_adds)
    {
      return _buildButton(Icons.add_rounded, 19);
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context)
  {
    final _Sizes sizes = _Sizes(wide);
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // Wide enough for today's pill and for a two-digit day at any text size.
    final double tileWidth = [
      wide ? _wideMinTileWidth : _minTileWidth,
      _textWidth('00', GoogleFonts.plusJakartaSans(fontSize: sizes.numberSize, fontWeight: FontWeight.w800), scaler),
      _textWidth('OGGI', GoogleFonts.plusJakartaSans(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6), scaler) + 12,
    ].reduce(math.max);

    Widget card = LayoutBuilder(
      builder: (context, constraints)
      {
        final EdgeInsets padding = sizes.padding;
        final double bandsWidth = constraints.maxWidth -
            padding.horizontal -
            tileWidth -
            sizes.tileGap -
            1 -
            sizes.rowsGap -
            sizes.tileGap -
            _trailingWidth;

        return MobileGlassPanel(
          padding: padding,
          borderRadius: BorderRadius.circular(_radius),
          whiteAlpha: day.isClosed ? _closedAlpha : MobileGlassPanel.cardAlpha,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.topCenter, child: _buildTile(sizes, tileWidth)),
                SizedBox(width: sizes.tileGap),
                Container(width: 1, color: AppTheme.trialInk.withValues(alpha: 0.1)),
                SizedBox(width: sizes.rowsGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildBands(sizes, scaler, bandsWidth),
                  ),
                ),
                SizedBox(width: sizes.tileGap),
                SizedBox(width: _trailingWidth, child: Center(child: _buildTrailing())),
              ],
            ),
          ),
        );
      },
    );

    if (day.isToday)
    {
      card = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: MobilePalette.currentRim, width: MobilePalette.currentRimWidth),
        ),
        child: card,
      );
    }

    final VoidCallback? onTap = _onTap;

    if (onTap == null)
    {
      return card;
    }

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

class _SlotChip extends StatelessWidget
{
  final AvailabilityItem slot;
  final _Sizes sizes;
  final bool locked;

  const _SlotChip({required this.slot, required this.sizes, required this.locked});

  @override
  Widget build(BuildContext context)
  {
    final bool online = slot.mode == kOnlineMode;

    // Locked: neutral chip with the mode kept in the icon, as the desktop greys it.
    final Color surface = locked
        ? Colors.white.withValues(alpha: 0.5)
        : (online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface);
    final Color ink = locked
        ? MobilePalette.mutedText
        : (online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep);
    final Color edge = locked
        ? AppTheme.trialInk.withValues(alpha: 0.1)
        : (online ? AppTheme.trialGold.withValues(alpha: 0.45) : AppTheme.trialTealDeep.withValues(alpha: 0.2));

    return Container(
      height: sizes.chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: _chipPadding),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_chipRadius),
        border: Border.all(color: edge),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(lessonModeIcon(slot.mode), size: sizes.chipIcon, color: ink),
            const SizedBox(width: _chipIconGap),
            Text(_hours(slot), style: sizes.chipStyle(ink)),
          ],
        ),
      ),
    );
  }
}
