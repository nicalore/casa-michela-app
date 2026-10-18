import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../association/models/opening_day_item.dart';
import '../../lessons/models/availability_item.dart';
import '../../lessons/models/calendar_publication_item.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/utils/timeline_geometry.dart';
import 'dashboard_section_card.dart';
import '../../home/widgets/home_day_strip.dart';
import '../../lessons/widgets/calendar_lesson_block.dart';

typedef _DayRow = ({DateTime date, TimeOfDay start, TimeOfDay end, String who});

// Distinct people, not rows; a row counts in every band it overlaps, as the calendar reads it.
int _peopleIn(List<_DayRow> rows, DateTime day, int bandStart, int bandEnd)
{
  return rows
      .where((row) =>
          isSameDate(row.date, day) &&
          spansOverlap(
            minutesOfTimeOfDay(row.start),
            minutesOfTimeOfDay(row.end),
            bandStart,
            bandEnd,
          ))
      .map((row) => row.who)
      .toSet()
      .length;
}

class DashboardBandFigure
{
  final int value;
  final String singular;
  final String plural;

  const DashboardBandFigure(this.value, this.singular, this.plural);

  String get label => value == 1 ? singular : plural;
}

class DashboardBandStatus
{
  final TimeBucket band;

  // Never empty: a band with no opening at all is omitted from the day.
  final List<BandOpening> openings;

  // A draft is a publication reopened for changes, so it still counts as published.
  final CalendarPublicationItem? publication;

  final int teachers;
  final int students;
  final int lessons;

  const DashboardBandStatus({
    required this.band,
    required this.openings,
    required this.publication,
    required this.teachers,
    required this.students,
    required this.lessons,
  });

  bool get isPublished => publication != null;

  bool get isDraft => publication?.isDraft ?? false;

  List<DashboardBandFigure> get figures
  {
    if (isPublished)
    {
      return [
        DashboardBandFigure(teachers, 'docente convocato', 'docenti convocati'),
        DashboardBandFigure(students, 'studente', 'studenti'),
        DashboardBandFigure(lessons, 'lezione', 'lezioni'),
      ];
    }

    return [
      DashboardBandFigure(teachers, 'docente disponibile', 'docenti disponibili'),
      DashboardBandFigure(students, 'studente prenotato', 'studenti prenotati'),
    ];
  }
}

List<DashboardBandStatus> openBands({
  required DateTime day,
  required List<OpeningDayItem> openingDays,
  required List<AvailabilityItem> availabilities,
  required List<PresenceItem> presences,
  required List<LessonItem> lessons,
  required List<CalendarPublicationItem> publications,
})
{
  final List<_DayRow> offered = [
    for (final slot in availabilities)
      (
        date: slot.date,
        start: slot.startTime,
        end: slot.endTime,
        who: slot.teacherTaxCode,
      ),
  ];

  final List<_DayRow> booked = [
    for (final row in presences)
      (
        date: row.date,
        start: row.startTime,
        end: row.endTime,
        who: row.studentTaxCode,
      ),
  ];

  final List<DashboardBandStatus> bands = [];

  for (final band in TimeBucket.values)
  {
    final openings = bandOpeningsFor(openingDays, day, band);

    if (openings.isEmpty)
    {
      continue;
    }

    final publication = publications
        .where((row) => isSameDate(row.date, day) && row.band == band)
        .firstOrNull;

    final List<LessonItem> planned = lessons
        .where((lesson) => isSameDate(lesson.date, day) && lesson.band == band)
        .toList();

    final bandStart = bandStartMinutes(band);
    final bandEnd = bandEndMinutes(band);

    bands.add(DashboardBandStatus(
      band: band,
      openings: openings,
      publication: publication,
      // Once published, counts come from the calendar, not from what was offered or booked.
      teachers: publication == null
          ? _peopleIn(offered, day, bandStart, bandEnd)
          : planned.map((lesson) => lesson.teacherTaxCode).toSet().length,
      students: publication == null
          ? _peopleIn(booked, day, bandStart, bandEnd)
          : planned.expand((lesson) => lesson.studentTaxCodes).toSet().length,
      lessons: planned.length,
    ));
  }

  return bands;
}

const double _hoursRow = 22;
const double _figureRow = 24;

// Docenti, studenti and lezioni: a band that has fewer keeps the empty rows.
const int _figureRows = 3;

class DashboardTodaySection extends StatelessWidget
{
  // Null when the opening hours could not be read (admin-only), distinct from an empty day.
  final List<DashboardBandStatus>? bands;

  final bool isLoading;

  final DateTime day;

  const DashboardTodaySection({
    super.key,
    required this.bands,
    required this.day,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      icon: Icons.today_rounded,
      title: 'Orari e prenotazioni',
      action: DashboardCardNote(formatWeekdayColumnLabel(day)),
      child: _buildBody(),
    );
  }

  Widget _buildBody()
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<DashboardBandStatus>? open = bands;

    if (open == null)
    {
      return Text(
        'Gli orari di oggi non sono disponibili.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    return DayStripFrame(
      column: (band)
      {
        final DashboardBandStatus? status = open.where((status) => status.band == band).firstOrNull;

        return status == null ? ClosedBandColumn(band: band) : _BandColumn(status: status);
      },
    );
  }
}

class _BandColumn extends StatelessWidget
{
  final DashboardBandStatus status;

  const _BandColumn({required this.status});

  // Openings name their modes in words, the same hours both ways as one.
  BandOpening? _openingOf(String mode)
  {
    final String alone = mode == kOnlineMode ? kOnScreen : kInBuilding;

    return status.openings.where((opening) => opening.mode == alone || opening.mode == kBothWays).firstOrNull;
  }

  @override
  Widget build(BuildContext context)
  {
    final List<DashboardBandFigure> figures = status.figures;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StripBandHead(band: status.band, isPublished: status.isPublished, isDraft: status.isDraft),
        const SizedBox(height: 6),
        for (final mode in kStripModes)
          if (_openingOf(mode) case final opening?)
            _Hours(mode: mode, opening: opening)
          else
            StripClosedMode(mode: mode, height: _hoursRow),
        const SizedBox(height: 6),
        for (var i = 0; i < _figureRows; i++)
          i < figures.length ? _Figure(figure: figures[i]) : const SizedBox(height: _figureRow),
      ],
    );
  }
}

class _Hours extends StatelessWidget
{
  final String mode;
  final BandOpening opening;

  const _Hours({required this.mode, required this.opening});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _hoursRow,
      child: Row(
        children: [
          Icon(lessonModeIcon(mode), size: 16, color: lessonAccent(mode)),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMinutesRange(opening.startMinutes, opening.endMinutes),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: AppTheme.trialInk,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Numbers right-aligned in a column two digits wide, so the labels of every band line up.
class _Figure extends StatelessWidget
{
  final DashboardBandFigure figure;

  const _Figure({required this.figure});

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _figureRow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${figure.value}',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: AppTheme.trialOcean,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              figure.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
