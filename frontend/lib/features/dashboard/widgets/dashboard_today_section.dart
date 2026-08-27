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

typedef _DayRow = ({DateTime date, TimeOfDay start, TimeOfDay end, String who});

// Distinct people, not rows; a row counts in every band it overlaps, matching
// how the calendar reads it.
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

class DashboardBandOpening
{
  final int startMinutes;
  final int endMinutes;
  final String mode;

  const DashboardBandOpening({
    required this.startMinutes,
    required this.endMinutes,
    required this.mode,
  });

  String get hours => formatMinutesRange(startMinutes, endMinutes);
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
  final List<DashboardBandOpening> openings;

  // A draft is a publication reopened for changes, so it still counts as
  // published.
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

const String _inBuilding = 'in presenza';
const String _onScreen = 'online';
const String _bothWays = 'in presenza e online';

List<DashboardBandOpening> _openingsOf(OpeningWindow? presence, OpeningWindow? online)
{
  // Same hours both ways: merged into one opening.
  if (presence != null &&
      online != null &&
      presence.startMinutes == online.startMinutes &&
      presence.endMinutes == online.endMinutes)
  {
    return [
      DashboardBandOpening(
        startMinutes: presence.startMinutes,
        endMinutes: presence.endMinutes,
        mode: _bothWays,
      ),
    ];
  }

  return [
    if (presence != null)
      DashboardBandOpening(
        startMinutes: presence.startMinutes,
        endMinutes: presence.endMinutes,
        mode: _inBuilding,
      ),
    if (online != null)
      DashboardBandOpening(
        startMinutes: online.startMinutes,
        endMinutes: online.endMinutes,
        mode: _onScreen,
      ),
  ];
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
    final openings = _openingsOf(
      openingWindowFor(openingDays, day, kPresenceMode, band),
      openingWindowFor(openingDays, day, kOnlineMode, band),
    );

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
      // Once published, counts come from the calendar, not from what was
      // offered or booked.
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

// Type and spacing scale grow as the band count shrinks: the card height is
// fixed, so fewer bands are written larger to fill it.
class _BandScale
{
  final double name;
  final double hours;
  final double unit;
  final double figure;
  final double figureUnit;
  final double padding;
  final double gap;

  const _BandScale({
    required this.name,
    required this.hours,
    required this.unit,
    required this.figure,
    required this.figureUnit,
    required this.padding,
    required this.gap,
  });

  static const _BandScale _tight = _BandScale(
    name: 15,
    hours: 15,
    unit: 12.5,
    figure: 15,
    figureUnit: 12.5,
    padding: 11,
    gap: 4,
  );

  static const _BandScale _roomy = _BandScale(
    name: 17,
    hours: 21,
    unit: 14,
    figure: 21,
    figureUnit: 14,
    padding: 24,
    gap: 6,
  );

  static const _BandScale _alone = _BandScale(
    name: 19,
    hours: 28,
    unit: 15,
    figure: 28,
    figureUnit: 15,
    padding: 34,
    gap: 10,
  );

  static _BandScale of(int bands)
  {
    if (bands >= 3)
    {
      return _tight;
    }

    return bands == 2 ? _roomy : _alone;
  }

  double get between => this == _tight ? 10.0 : 12.0;

  double get spacing => this == _tight ? 14.0 : 18.0;
}

class DashboardTodaySection extends StatelessWidget
{
  // Null when the opening hours could not be read (they are admin-only),
  // distinct from an empty day.
  final List<DashboardBandStatus>? bands;

  final bool isLoading;

  final double minHeight;
  final bool fill;

  const DashboardTodaySection({
    super.key,
    required this.bands,
    this.isLoading = false,
    this.minHeight = 0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      eyebrow: 'Oggi',
      title: 'Orari e presenze',
      minHeight: minHeight,
      fill: fill,
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

    if (open.isEmpty)
    {
      return const _ClosedToday();
    }

    // Multiple bands share the card's extra height; a single band keeps its
    // natural height, centred in the card.
    final _BandScale scale = _BandScale.of(open.length);
    final bool shares = fill && open.length > 1;

    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: shares ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < open.length; i++)
          if (shares)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == open.length - 1 ? 0 : scale.between,
                ),
                child: _BandRow(status: open[i], scale: scale),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(
                bottom: i == open.length - 1 ? 0 : scale.between,
              ),
              child: _BandRow(status: open[i], scale: scale),
            ),
      ],
    );
  }
}

class _ClosedToday extends StatelessWidget
{
  const _ClosedToday();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event_busy_rounded, size: 26, color: AppTheme.trialMutedText),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "L'associazione è chiusa",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialOcean,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nessuna apertura prevista.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BandRow extends StatelessWidget
{
  final DashboardBandStatus status;
  final _BandScale scale;

  const _BandRow({required this.status, required this.scale});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: scale.padding),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  bandLabel(status.band),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scale.name,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              if (status.isPublished) ...[
                const SizedBox(width: 8),
                _PublishedPill(isDraft: status.isDraft),
              ],
            ],
          ),
          SizedBox(height: scale.gap),
          Wrap(
            spacing: scale.spacing,
            runSpacing: 2,
            children: [
              for (final opening in status.openings)
                _Reading(
                  value: opening.hours,
                  label: opening.mode,
                  size: scale.hours,
                  labelSize: scale.unit,
                ),
            ],
          ),
          SizedBox(height: scale.gap / 2),
          Wrap(
            spacing: scale.spacing,
            runSpacing: 2,
            children: [
              for (final figure in status.figures)
                _Reading(
                  value: '${figure.value}',
                  label: figure.label,
                  size: scale.figure,
                  labelSize: scale.figureUnit,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget
{
  final String value;
  final String label;
  final double size;
  final double labelSize;

  const _Reading({
    required this.value,
    required this.label,
    required this.size,
    required this.labelSize,
  });

  @override
  Widget build(BuildContext context)
  {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppTheme.trialInk,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.plusJakartaSans(
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PublishedPill extends StatelessWidget
{
  final bool isDraft;

  const _PublishedPill({required this.isDraft});

  @override
  Widget build(BuildContext context)
  {
    final Color accent = isDraft ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDraft ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Text(
        isDraft ? 'IN BOZZA' : 'PUBBLICATO',
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 1.1,
          color: accent,
        ),
      ),
    );
  }
}
