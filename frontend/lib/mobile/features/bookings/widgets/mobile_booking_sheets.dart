import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/bookings/utils/booking_strings.dart' show deleteBand, moveBandLessons;
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_danger_button.dart';
import '../../../shared/widgets/mobile_dismiss_button.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../../profile/widgets/mobile_detail_card.dart' show MobileDetailRows, mobileFactValueStyle;
import '../mobile_booking_day.dart';
import '../mobile_bookings_tour.dart';

const String _empty = '—';

const EdgeInsets _tourCardInflate = EdgeInsets.all(4);
const EdgeInsets _tourButtonsInflate = EdgeInsets.all(6);
const double _tourButtonsRadius = 24;

// Carried out by the page from the sheet still open, so a further step turns that sheet.
sealed class MobileBookingAction
{
  const MobileBookingAction();
}

class MobileEditHours extends MobileBookingAction
{
  final String mode;

  const MobileEditHours(this.mode);
}

class MobileMoveAll extends MobileBookingAction
{
  final String mode;

  const MobileMoveAll(this.mode);
}

class MobileDeleteMode extends MobileBookingAction
{
  final String mode;

  const MobileDeleteMode(this.mode);
}

class MobileDeleteDay extends MobileBookingAction
{
  const MobileDeleteDay();
}

class MobileEditLesson extends MobileBookingAction
{
  const MobileEditLesson();
}

class MobileMoveLesson extends MobileBookingAction
{
  const MobileMoveLesson();
}

class MobileDeleteLesson extends MobileBookingAction
{
  const MobileDeleteLesson();
}

String _whoAndWhen(PersonItem pupil, MobileBookingDay day, {required bool named})
{
  final String when = formatAvailableDayLabel(day.date);

  return named ? '${pupil.firstName} · $when' : when;
}

Future<void> showMobileLessonSheet({
  required BuildContext context,
  required MobileBookingDay day,
  required MobileBookingLesson lesson,
  required PersonItem pupil,
  required bool named,
  required bool movable,
  required Future<void> Function(BuildContext sheet, MobileBookingAction action) onAction,
  String? tourFor,
  BookingSheetTourLink? tourLink,
})
{
  final bool editable = !day.isPast && lesson.editable;

  DetailRowData fact(String label, String? value)
  {
    final String? said = value?.trim();

    if (said == null || said.isEmpty)
    {
      return DetailRowData.drawn(
        label,
        Text(_empty, style: mobileFactValueStyle().copyWith(color: MobilePalette.mutedText)),
      );
    }

    return DetailRowData(label, said);
  }

  final List<DetailRowData> rows = [
    if (lesson.disciplines.isNotEmpty) fact('Discipline', lesson.disciplines.join(', ')),
    fact(kDurationLabel, formatMinutes(lesson.booking.duration)),
    fact(kLessonKindLabel, lesson.tags.join(', ')),
    fact('Argomento', lesson.topic),
    fact(
      preferredTeachersLabel(pupil.gender),
      lesson.teachers.map((teacher) => '${teacher.firstName} ${teacher.lastName}').join(', '),
    ),
    fact(kTeacherNotesLabel, lesson.notes),
  ];

  return showMobileSheet<void>(
    context: context,
    builder: (context)
    {
      void act(MobileBookingAction action) => onAction(context, action);

      final String? taxCode = tourFor;

      return MobileSheet(
        eyebrow: 'Lezione ${modeLabel(lesson.slot.mode).toLowerCase()}',
        title: lesson.title,
        subtitle: _whoAndWhen(pupil, day, named: named),
        body: [
          MobileTourOnRise(
            onRisen: taxCode == null
                ? null
                : () => startLessonSheetTour(
                      taxCode: taxCode,
                      present: {LessonSheetMark.details, if (editable) LessonSheetMark.actions},
                    ),
            child: _TourLinked(link: tourLink, editable: editable, child: const SizedBox(height: 16)),
          ),
          MobileTourTarget(
            id: lessonSheetTourTarget(LessonSheetMark.details),
            inflate: _tourCardInflate,
            radius: MobileSheetCard.radius + _tourCardInflate.left,
            clipped: true,
            child: MobileSheetCard(child: MobileDetailRows(rows: rows)),
          ),
          const SizedBox(height: 6),
        ],
        footer: !editable
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 18),
                child: MobileTourTarget(
                  id: lessonSheetTourTarget(LessonSheetMark.actions),
                  inflate: _tourButtonsInflate,
                  radius: _tourButtonsRadius,
                  child: Column(
                    children: [
                      MobileGoldButton(
                        label: 'Modifica',
                        icon: Icons.edit_outlined,
                        onPressed: () => act(const MobileEditLesson()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (movable) ...[
                            Expanded(
                              child: MobileDismissButton(
                                label: 'Sposta',
                                icon: Icons.swap_horiz_rounded,
                                onPressed: () => act(const MobileMoveLesson()),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: MobileDangerButton(
                              label: 'Elimina',
                              icon: Icons.delete_outline_rounded,
                              onPressed: () => act(const MobileDeleteLesson()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

Future<void> showMobileModeSheet({
  required BuildContext context,
  required MobileBookingDay day,
  required MobileBookingMode mode,
  required PersonItem pupil,
  required bool named,
  required String? moveAllRefusal,
  required Future<void> Function(BuildContext sheet, MobileBookingAction action) onAction,
  String? tourFor,
})
{
  final String? taxCode = tourFor;

  return showMobileSheet<void>(
    context: context,
    builder: (context)
    {
      void act(MobileBookingAction action) => onAction(context, action);

      final List<Widget> rows = [
        if (mode.changeable)
          _ActionRow(
            icon: Icons.schedule_rounded,
            label: 'Modifica gli orari',
            onTap: () => act(MobileEditHours(mode.mode)),
          ),
        if (mode.changeable && mode.lessons.isNotEmpty)
          _ActionRow(
            icon: Icons.swap_horiz_rounded,
            label: moveBandLessons(mode.band),
            refusal: moveAllRefusal,
            onTap: () => act(MobileMoveAll(mode.mode)),
          ),
        if (mode.deletable)
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: deleteBand(mode.band),
            danger: true,
            onTap: () => act(MobileDeleteMode(mode.mode)),
          ),
        // With one block, its own deletion already empties the day.
        if (day.modes.length > 1 && day.canDeleteDay)
          _ActionRow(
            icon: Icons.event_busy_rounded,
            label: 'Elimina la giornata',
            danger: true,
            onTap: () => act(const MobileDeleteDay()),
          ),
      ];

      return MobileSheet(
        eyebrow: _whoAndWhen(pupil, day, named: named),
        title: '${modeLabel(mode.mode)} · ${bandLabel(mode.band)}',
        subtitle: mode.slots.map((slot) => formatTimeRange(slot.startTime, slot.endTime)).join(' · '),
        body: [
          MobileTourOnRise(
            onRisen: taxCode == null || rows.isEmpty ? null : () => startModeSheetTour(taxCode: taxCode),
            child: const SizedBox(height: 16),
          ),
          MobileTourTarget(
            id: kBookingsTourModeActions,
            inflate: _tourCardInflate,
            radius: MobileSheetCard.radius + _tourCardInflate.left,
            clipped: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(MobileSheetCard.radius)),
                boxShadow: [BoxShadow(color: Color(0x12122438), offset: Offset(0, 4), blurRadius: 14)],
              ),
              child: Column(
                children: [
                  for (final (i, row) in rows.indexed)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.08))),
                      ),
                      child: row,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

class _ActionRow extends StatelessWidget
{
  final IconData icon;
  final String label;
  final bool danger;
  final String? refusal;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.danger = false,
    this.refusal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? refusal = this.refusal;
    final bool off = refusal != null;

    final Color ink = off ? MobilePalette.mutedText.withValues(alpha: 0.6) : (danger ? AppTheme.trialDanger : AppTheme.trialInk);
    final Color iconInk = off ? ink : (danger ? AppTheme.trialDanger : AppTheme.trialTealDeep);

    return Semantics(
      button: true,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: off ? () => MobileNotice.show(context, refusal, error: true) : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Icon(icon, size: 21, color: iconInk),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
              ),
              if (!danger && !off) Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.trialInk.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// Tells a page's tour once the sheet stands still, and when it is gone.
class _TourLinked extends StatefulWidget
{
  final BookingSheetTourLink? link;
  final bool editable;
  final Widget child;

  const _TourLinked({required this.link, required this.editable, required this.child});

  @override
  State<_TourLinked> createState() => _TourLinkedState();
}

class _TourLinkedState extends State<_TourLinked>
{
  bool _risen = false;

  @override
  void initState()
  {
    super.initState();

    if (widget.link != null)
    {
      _riseLater();
    }
  }

  @override
  void dispose()
  {
    final BookingSheetTourLink? link = widget.link;

    // Not while the tree is locked: a tour moves on, and redraws, on hearing it.
    if (link != null && _risen)
    {
      SchedulerBinding.instance.addPostFrameCallback((_) => link.fall());
    }

    super.dispose();
  }

  void _riseLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _rise())
      ..scheduleFrame();
  }

  void _rise()
  {
    if (!mounted)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _riseLater();

      return;
    }

    _risen = true;
    widget.link?.rise(editable: widget.editable, close: () => closeMobileSheet(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
