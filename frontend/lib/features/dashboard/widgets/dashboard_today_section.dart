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

// The day the home page opens on: when the association is open, and who is
// expected in those hours.
//
// One row per band it opens in, and none for the bands it keeps shut: hours
// nobody can be booked in have no figures to carry. What the figures count
// changes the moment a band's calendar goes out. Before it they are what has
// been asked for — the teachers who offered hours, the pupils who booked them.
// After it they are what was decided and told to everybody: the teachers
// called in, the pupils they will see, and the lessons between them.
//
// Everything a row has to say is written on it, and written once: nothing is
// behind a hover, and no hour is said twice in two sizes. This is a page read
// at a glance on the way somewhere else.

// A row of one person on one day: the shape both the teachers' hours and the
// pupils' bookings are counted through, so the two are counted the same way.
typedef _DayRow = ({DateTime date, TimeOfDay start, TimeOfDay end, String who});

// How many different people the rows of [day] name inside the band. People and
// not rows: a teacher who left two windows open is one teacher, and a pupil
// booked twice over is one pupil.
//
// A row belongs to the band it reaches into rather than the one it starts in,
// which is how the calendar reads them too: somebody here from noon to three is
// here in the morning and in the afternoon both.
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

// An opening, and the way of being open it belongs to: the building, the
// screens, or — where the two keep the same hours — both at once, which is one
// opening and is said once.
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

// A figure and what it counts.
class DashboardBandFigure
{
  final int value;
  final String singular;
  final String plural;

  const DashboardBandFigure(this.value, this.singular, this.plural);

  String get label => value == 1 ? singular : plural;
}

// What one band of the day amounts to.
class DashboardBandStatus
{
  final TimeBucket band;

  // When the association is open in this band: one opening where the building
  // and the screens keep the same hours, two where they part, and one alone
  // where it opens only the one way. Never empty — a band with no opening at
  // all is not a band of this day.
  final List<DashboardBandOpening> openings;

  // The publication of this band, where the calendar has gone out. A bozza is
  // one that went out and was reopened to be changed, so it counts as
  // published: the lessons in it are the ones people were told about.
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

  // The figures, in the words the band's own state gives them. A published band
  // is read off the calendar and says so; one still being put together is read
  // off what has been offered and asked for.
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

// How the association is open, said after the hours it is open for.
const String _inBuilding = 'in presenza';
const String _onScreen = 'online';
const String _bothWays = 'in presenza e online';

List<DashboardBandOpening> _openingsOf(OpeningWindow? presence, OpeningWindow? online)
{
  // The same hours both ways: one opening, said once. Written as two rows it
  // would be the same time twice over, and a reader made to compare them.
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

// The bands of [day] the association opens in, in the order of the day.
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
      // Once the calendar is out it is the calendar that is counted, and the
      // hours it was built from stop being the answer: a teacher who offered a
      // morning and was not called in is not a teacher expected this morning.
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

// Quanto la giornata ha da dire decide quanto in grande lo dice.
//
// La card è alta quanto le due che le stanno a fianco, e quell'altezza non
// cambia col numero delle fasce: tre ci stanno strette e vanno scritte piccole,
// due hanno mezza card a testa, una ha tutta la card per sé. Scritta sempre
// nella misura più piccola, una giornata corta diventa tre righe in mezzo a un
// riquadro vuoto.
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

  // Fra una fascia e l'altra, e quanto la riga fa respirare le sue voci.
  double get between => this == _tight ? 10.0 : 12.0;

  double get spacing => this == _tight ? 14.0 : 18.0;
}

class DashboardTodaySection extends StatelessWidget
{
  // The bands of today, or null where they could not be read: the opening hours
  // are an administrator's to see, and a home page that cannot read them says
  // so rather than drawing a day the association never closed.
  final List<DashboardBandStatus>? bands;

  final bool isLoading;

  // Passati alla card: quanto è alta almeno e se il contenuto riempie.
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

    // The day is the tallest thing on the page and the two cards beside it
    // divide its height, so this card is regularly given more room than its
    // lines need. Two bands take that room and share it, each holding its lines
    // in the middle; three do the same with less of it to share.
    //
    // One band does not: a single row stretched over a whole card is a wide
    // grey box with three lines adrift in it. It keeps the height its lines ask
    // for — a larger one, since it has the card to itself — and sits in the
    // middle of the card, so the air is around the panel rather than inside it.
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

// A day the association does not open at all. It is said in the same box the
// figures would have stood in, so the card keeps its shape on a Sunday.
class _ClosedToday extends StatelessWidget
{
  const _ClosedToday();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      // Inside a card as tall as the one beside it, the notice is centred: at
      // the top it would leave half a grey box under it, which reads as a
      // drawing mistake rather than as a quiet day.
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

// One band: what it is called, when the association is open in it, and who is
// expected. Three lines, each read left to right and none of them repeating
// what another has already said.
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
        // Held in the middle where the tile is taller than its lines, which is
        // whenever the card has been given more height than the day needs.
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

// A value and what it is: the value dark and heavy, the words after it small
// and grey. An hour and a headcount are read the same way — a figure and its
// unit — so they are written the same way, one line under the other.
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

// The same mark the calendar carries over a band that has gone out, in the size
// the home page has room for.
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
