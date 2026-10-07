import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/models/presence_item.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_action_circle.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../../../shared/widgets/mobile_slot_button.dart';
import '../mobile_booking_day.dart';
import 'mobile_booking_parts.dart';

const double _radius = 22;

const double _closedAlpha = 0.43;

// Past days use muted colours at full alpha: an Opacity over glass trips Impeller.

class MobileBookingDayCard extends StatelessWidget
{
  final MobileBookingDay day;
  final bool tablet;

  final ValueChanged<MobileBookingLesson> onOpenLesson;
  final ValueChanged<MobileBookingMode> onModeActions;

  final ValueChanged<String> onAdd;
  final ValueChanged<MobileBookingMode> onAddLesson;

  const MobileBookingDayCard({
    super.key,
    required this.day,
    required this.tablet,
    required this.onOpenLesson,
    required this.onModeActions,
    required this.onAdd,
    required this.onAddLesson,
  });

  Color get _rule => AppTheme.trialInk.withValues(alpha: 0.1);

  Widget _buildDate()
  {
    final Color ink = day.isPast || day.isShut ? MobilePalette.mutedText : AppTheme.trialOcean;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayFullName(day.date.weekday).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 12 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: MobilePalette.mutedText,
              ),
            ),
            if (day.isToday) ...[
              const SizedBox(width: 8),
              const MobilePill('Oggi', tone: MobilePillTone.teal, dense: true),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          formatDayMonthFull(day.date),
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 23 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.15,
            color: ink,
          ),
        ),
      ],
    );
  }

  Widget _buildNote(String text, {IconData? icon})
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: tablet ? 14 : 13,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      color: MobilePalette.mutedText,
    );

    if (icon == null)
    {
      return Text(text, style: style);
    }

    return Row(
      children: [
        Icon(icon, size: 19, color: MobilePalette.mutedText),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }

  Widget _buildContent()
  {
    if (day.isClosed)
    {
      return _buildNote("L'Associazione è chiusa", icon: Icons.event_busy_rounded);
    }

    if (day.modes.isEmpty)
    {
      return _buildNote('Nessuna prenotazione');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, mode) in day.modes.indexed) ...[
          if (i > 0) const SizedBox(height: 14),
          _ModeBlock(
            mode: mode,
            past: day.isPast,
            tablet: tablet,
            onOpenLesson: onOpenLesson,
            onActions: () => onModeActions(mode),
            onAddLesson: () => onAddLesson(mode),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> adds = day.addable;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildDate(),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final mode in adds) MobileAddModeButton(mode: mode, tablet: tablet, onTap: () => onAdd(mode)),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 12), color: _rule),
        _buildContent(),
      ],
    );

    Widget card = MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(20, 16, 18, 18) : const EdgeInsets.fromLTRB(16, 14, 14, 14),
      borderRadius: BorderRadius.circular(_radius),
      whiteAlpha: day.isClosed ? _closedAlpha : MobileGlassPanel.cardAlpha,
      child: content,
    );

    if (day.isToday)
    {
      card = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: const MobileCurrentCard(BorderRadius.all(Radius.circular(_radius))),
        child: card,
      );
    }

    return card;
  }
}

class _ModeBlock extends StatelessWidget
{
  final MobileBookingMode mode;
  final bool past;
  final bool tablet;
  final ValueChanged<MobileBookingLesson> onOpenLesson;
  final VoidCallback onActions;
  final VoidCallback onAddLesson;

  const _ModeBlock({
    required this.mode,
    required this.past,
    required this.tablet,
    required this.onOpenLesson,
    required this.onActions,
    required this.onAddLesson,
  });

  bool get _hasActions => !past && (mode.changeable || mode.deletable);

  Widget _buildChip(PresenceItem slot) => MobileHoursChip(slot: slot, closed: past || mode.isClosed(slot), tablet: tablet);

  @override
  Widget build(BuildContext context)
  {
    final bool inline = mode.slots.length == 1;

    final Widget name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(lessonModeIcon(mode.mode), size: tablet ? 17 : 16, color: MobilePalette.mutedText),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${modeLabel(mode.mode)} · ${bandLabel(mode.band)}'.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 12 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: tablet ? 1.2 : 0.8,
              color: MobilePalette.mutedText,
            ),
          ),
        ),
        // Past days too, as on the desktop; never for who only reads.
        if (mode.hasClosed) ...[
          const SizedBox(width: 5),
          Icon(Icons.lock_outline_rounded, size: tablet ? 15 : 14, color: MobilePalette.mutedText),
        ],
      ],
    );

    final double lead = inline ? 0 : 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: _MoreButton.height(tablet)),
          child: Row(
            children: [
              Expanded(
                child: inline
                    // Phone spacing fits the "IN PRESENZA" + "POMERIGGIO" label and its hours.
                    ? Wrap(
                        spacing: tablet ? 10 : 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [name, _buildChip(mode.slots.single)],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [for (final slot in mode.slots) _buildChip(slot)]),
                        ],
                      ),
              ),
              if (_hasActions) ...[
                SizedBox(width: tablet ? 8 : 6),
                _MoreButton(tablet: tablet, onTap: onActions),
              ],
            ],
          ),
        ),
        for (final (index, lesson) in mode.lessons.indexed) ...[
          SizedBox(height: 8 + (index == 0 ? lead : 0)),
          _LessonRow(
            lesson: lesson,
            muted: past || lesson.closed,
            tablet: tablet,
            onTap: () => onOpenLesson(lesson),
          ),
        ],
        if (mode.canAddLesson) ...[
          SizedBox(height: 10 + (mode.lessons.isEmpty ? lead : 0)),
          MobileSlotButton(label: 'Aggiungi lezione', icon: Icons.add_rounded, onPressed: onAddLesson, onLight: true),
        ],
      ],
    );
  }
}

class _LessonRow extends StatelessWidget
{
  final MobileBookingLesson lesson;
  final bool muted;
  final bool tablet;
  final VoidCallback onTap;

  const _LessonRow({required this.lesson, required this.muted, required this.tablet, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final double titleSize = tablet ? 17 : 15.5;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(tablet ? 16 : 13, 12, 6, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: muted ? MobilePalette.mutedText : AppTheme.trialOcean,
                      ),
                    ),
                    if (lesson.disciplines.isNotEmpty)
                      Text(
                        lesson.disciplines.join(' · '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: tablet ? 13.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: MobilePalette.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMinutes(lesson.booking.duration),
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: titleSize - 1,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: muted ? MobilePalette.mutedText : AppTheme.trialInk,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 24, color: AppTheme.trialInk.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

// The mode's actions, which the desktop shows on hover.
class _MoreButton extends StatelessWidget
{
  final bool tablet;
  final VoidCallback onTap;

  const _MoreButton({required this.tablet, required this.onTap});

  static double height(bool tablet) => tablet ? 46 : 42;

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Azioni',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: tablet ? 44 : 40,
          height: height(tablet),
          child: Align(
            alignment: Alignment.centerRight,
            child: MobileActionCircle(
              icon: Icons.edit_calendar_rounded,
              size: tablet ? 44 : 40,
              iconSize: tablet ? 23 : 21,
            ),
          ),
        ),
      ),
    );
  }
}
