import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../models/activity_item.dart';
import '../models/calendar_day.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../utils/opening_window.dart';
import '../utils/timeline_geometry.dart';
import '../widgets/calendar_lesson_block.dart';
import 'calendar_export_data.dart';
import 'calendar_pdf_fonts.dart';
import 'calendar_pdf_grid.dart';
import 'calendar_pdf_palette.dart';

const String _association = 'ASSOCIAZIONE CASA MICHELA';

const double _typeScale = 1.25;

const double _logoSize = 66 * _typeScale;

const double _closingLabelRoom = 46 * _typeScale;

// Narrowest a quarter hour gets on the page: the hour labels still fit.
const double _minQuarter = 13;

// A long activity name may wrap rather than widen the hour.
const double _widestActivityName = 120 * _typeScale;

// No line widens a block past this: a longer one wraps instead.
const double _widestBlockLine = 150;

const pw.EdgeInsets _blockPadding = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5);
const double _blockBorder = 0.6;

final PdfPageFormat _gridFormat = PdfPageFormat.a4.landscape.copyWith(
  marginLeft: 24,
  marginRight: 24,
  marginTop: 18,
  marginBottom: 18,
);

final PdfPageFormat _listFormat = PdfPageFormat.a4.copyWith(
  marginLeft: 28,
  marginRight: 28,
  marginTop: 22,
  marginBottom: 22,
);

String calendarPdfFileName(CalendarExportData data)
{
  final who = data.isByStudent ? 'studenti' : 'docenti';

  return 'Calendario $who ${formatDayMonthFull(data.day)} ${data.day.year} '
      '- ${bandLabel(data.band).toLowerCase()}.pdf';
}

String calendarPdfTitle(CalendarExportData data)
{
  return '${_viewLabel(data)} · ${_dayOnItsOwn(data.day)} · ${bandLabel(data.band)}';
}

String _viewLabel(CalendarExportData data)
{
  return data.isByStudent ? 'Vista studenti' : 'Vista docenti';
}

String _rowNoun(CalendarExportData data) => data.isByStudent ? 'Studente' : 'Docente';

String _dayOnItsOwn(DateTime day) => '${formatWeekdayColumnLabel(day)} ${day.year}';

String _dayInSentence(DateTime day)
{
  final said = _dayOnItsOwn(day);

  return '${said[0].toLowerCase()}${said.substring(1)}';
}

String _count(int value, String singular, String plural)
{
  return '$value ${value == 1 ? singular : plural}';
}

Future<Uint8List> buildCalendarPdf(CalendarExportData data) async
{
  final styles = _Styles(calendarPdfFonts(await calendarPdfAssets()));

  final document = pw.Document(
    theme: styles.fonts.theme,
    title: calendarPdfTitle(data),
    author: 'Associazione Casa Michela',
    creator: 'Associazione Casa Michela',
  );

  if (data.lanes.isEmpty)
  {
    document.addPage(_emptyPage(data, styles));

    return document.save();
  }

  var gridFailed = data.window == null;

  if (!gridFailed)
  {
    try
    {
      for (final pages in _gridPages(data, styles))
      {
        document.addPage(pages);
      }
    }
    on Exception
    {
      gridFailed = true;
    }
  }

  document.addPage(_listPages(data, styles, withGridNote: gridFailed));

  return document.save();
}

// Measures as the document lays out: the same fonts, word by word, no kerning.
class _Widths
{
  final PdfDocument _scratch = PdfDocument();

  final Map<pw.Font, PdfFont> _fonts = {};

  double of(String text, pw.TextStyle style)
  {
    final font = style.font!;
    final measured = _fonts.putIfAbsent(font, () => PdfTtfFont(_scratch, (font as pw.TtfFont).data));

    return (measured.stringMetrics(text) * style.fontSize!).width;
  }
}

class _Styles
{
  _Styles(this.fonts);

  final CalendarPdfFonts fonts;

  final _Widths widths = _Widths();

  pw.TextStyle _style(double size, pw.Font font, PdfColor colour, {double? spacing}) => pw.TextStyle(
        font: font,
        fontSize: size * _typeScale,
        color: colour,
        letterSpacing: spacing,
      );

  late final pw.TextStyle eyebrow = _style(7.5, fonts.semiBold, kPdfMuted, spacing: 1.4);
  late final pw.TextStyle title = _style(15, fonts.bold, kPdfInk);
  late final pw.TextStyle meta = _style(8, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle metaStrong = _style(8, fonts.bold, kPdfInk);
  late final pw.TextStyle draft = _style(8, fonts.bold, kPdfOnline);
  late final pw.TextStyle caption = _style(7, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle note = _style(7.5, fonts.regular, kPdfMuted);

  late final pw.TextStyle rulerHour = _style(7, fonts.bold, kPdfInk);
  late final pw.TextStyle rulerHalf = _style(6.5, fonts.regular, kPdfMuted);

  late final pw.TextStyle laneName = _style(8, fonts.bold, kPdfInk);
  late final pw.TextStyle laneRoom = _style(6.5, fonts.bold, kPdfPresence);
  late final pw.TextStyle laneOnline = _style(6.5, fonts.bold, kPdfOnline);
  late final pw.TextStyle laneSupervisor = _style(6, fonts.semiBold, kPdfPresence);
  late final pw.TextStyle laneWhen = _style(6, fonts.regular, kPdfMuted);

  // The discipline, or an activity's name.
  late final pw.TextStyle blockTitle = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle blockSubject = _style(6, fonts.semiBold, kPdfInk);
  late final pw.TextStyle blockWho = _style(6.5, fonts.semiBold, kPdfPerson);
  late final pw.TextStyle blockNote = _style(6, fonts.regular, kPdfBody);
  late final pw.TextStyle blockLength = _style(6.5, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle marker = _style(7, fonts.bold, kPdfWhite);

  pw.TextStyle blockHours(String mode) => _style(6.5, fonts.bold, pdfLessonAccent(mode));

  late final pw.TextStyle activityHours = _style(6.5, fonts.bold, kPdfActivity);

  late final pw.TextStyle activityCellHours = _style(7.5, fonts.bold, kPdfActivity);

  pw.TextStyle blockWhere(String mode) => _style(6, fonts.bold, pdfLessonAccent(mode));

  late final pw.TextStyle tableHead = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellName = _style(8.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellRoom = _style(7.5, fonts.bold, kPdfPresence);
  late final pw.TextStyle cellQuiet = _style(7, fonts.regular, kPdfMuted);
  late final pw.TextStyle cellSupervisor = _style(6.5, fonts.semiBold, kPdfPresence);
  late final pw.TextStyle cellLesson = _style(7.5, fonts.regular, kPdfBody);
  late final pw.TextStyle cellHours = _style(7.5, fonts.bold, kPdfInk);

  pw.TextStyle cellPlace(String mode) => _style(7.5, fonts.semiBold, pdfLessonAccent(mode));
}

pw.Widget _titleBlock(CalendarExportData data, _Styles styles)
{
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: _titleWords(data, styles)),
      pw.SizedBox(width: 16),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Image(styles.fonts.logo, width: _logoSize, height: _logoSize),
      ),
    ],
  );
}

pw.Widget _titleWords(CalendarExportData data, _Styles styles)
{
  final counts = data.counts;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(_association, style: styles.eyebrow),
      pw.SizedBox(height: 3),
      _gradientTitle('Calendario di ${_dayInSentence(data.day)}', styles),
      pw.SizedBox(height: 5),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _pill(bandLabel(data.band), styles),
          pw.SizedBox(width: 6),
          _pill(_viewLabel(data), styles),
          pw.SizedBox(width: 10),
          pw.Expanded(child: _publicationLine(data, styles)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        [
          _count(counts.teachers, 'docente convocato', 'docenti convocati'),
          _count(counts.students, 'studente', 'studenti'),
          _count(counts.lessons, 'lezione', 'lezioni'),
          if (counts.activities > 0) _count(counts.activities, 'attività', 'attività'),
        ].join(' · '),
        style: styles.meta,
      ),
      pw.SizedBox(height: 6),
      _legend(styles),
      pw.SizedBox(height: 6),
    ],
  );
}

pw.Widget _gradientTitle(String text, _Styles styles)
{
  final letters = text.split('');

  return pw.RichText(
    text: pw.TextSpan(
      children: [
        for (var i = 0; i < letters.length; i++)
          pw.TextSpan(
            text: letters[i],
            style: styles.title.copyWith(
              color: _rampAt(letters.length == 1 ? 1 : i / (letters.length - 1)),
            ),
          ),
      ],
    ),
  );
}

PdfColor _rampAt(double t)
{
  const begin = 0.15;
  const end = 0.95;

  if (t <= begin)
  {
    return kPdfInk;
  }

  if (t >= end)
  {
    return kPdfViolet;
  }

  final travelled = (t - begin) / (end - begin);

  return PdfColor(
    kPdfInk.red + (kPdfViolet.red - kPdfInk.red) * travelled,
    kPdfInk.green + (kPdfViolet.green - kPdfInk.green) * travelled,
    kPdfInk.blue + (kPdfViolet.blue - kPdfInk.blue) * travelled,
  );
}

pw.Widget _pill(String label, _Styles styles)
{
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: kPdfHeaderGround,
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Text(label, style: styles.metaStrong),
  );
}

pw.Widget _publicationLine(CalendarExportData data, _Styles styles)
{
  final publication = data.publication;

  if (publication == null)
  {
    return pw.Text('Non ancora pubblicato', style: styles.meta);
  }

  final said = publishedSentence(publication);

  if (!publication.isDraft)
  {
    return pw.Text(said, style: styles.meta);
  }

  return pw.RichText(
    text: pw.TextSpan(
      style: styles.meta,
      children: [
        pw.TextSpan(text: said),
        pw.TextSpan(text: ' · IN BOZZA', style: styles.draft),
      ],
    ),
  );
}

pw.Widget _legend(_Styles styles)
{
  return pw.Row(
    children: [
      _swatch(modeLabel(kPresenceMode), kPdfPresence, kPdfPresenceSurface, styles),
      pw.SizedBox(width: 12),
      _swatch(modeLabel(kOnlineMode), kPdfOnline, kPdfOnlineSurface, styles),
    ],
  );
}

pw.Widget _swatch(String label, PdfColor accent, PdfColor surface, _Styles styles)
{
  return pw.Row(
    children: [
      pw.Container(
        width: 7,
        height: 7,
        decoration: pw.BoxDecoration(
          color: surface,
          border: pw.Border.all(color: accent, width: 0.6),
          borderRadius: pw.BorderRadius.circular(1.5),
        ),
      ),
      pw.SizedBox(width: 3),
      pw.Text(label, style: styles.caption),
    ],
  );
}

pw.Widget _footer(pw.Context context, CalendarExportData data, _Styles styles)
{
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: kPdfLine, width: 0.4)),
    ),
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '${_viewLabel(data)} · ${bandLabel(data.band)} · ${_dayOnItsOwn(data.day)}',
          style: styles.caption,
        ),
        pw.Text('Pagina ${context.pageNumber} di ${context.pagesCount}', style: styles.caption),
      ],
    ),
  );
}

// The width a block needs to write each of its lines whole.
double _lessonNeed(CalendarExportData data, _Styles styles, LessonItem lesson)
{
  final topic = lessonTopic(lesson, data.ministrySubjects);
  final widths = styles.widths;

  double capped(String text, pw.TextStyle style) => math.min(_widestBlockLine, widths.of(text, style));

  final lines = [
    _hoursWidth(styles, lesson.mode, [formatTimeRange(lesson.startTime, lesson.endTime), formatMinutes(lesson.minutes)]),
    capped(topic.discipline, styles.blockTitle),
    if (topic.subject case final subject?) capped(subject, styles.blockSubject),
    capped(lessonTitle(lesson, view: data.view), styles.blockWho),
    if (data.isByStudent) capped(lessonWhere(lesson).label, styles.blockWhere(lesson.mode)),
  ];

  return _withChrome(lines.reduce(math.max));
}

double _activityNeed(_Styles styles, ScheduledActivity scheduled)
{
  final widths = styles.widths;
  final hours = widths.of(formatMinutesRange(scheduled.startMinutes, scheduled.endMinutes), styles.activityHours);
  final name = math.min(_widestActivityName, widths.of(scheduled.name, styles.blockTitle));

  return _withChrome(math.max(hours, name));
}

// Padding, border and gaps, and a hair for rounding.
double _withChrome(double text) => text * 1.02 + kBlockChrome + 1.2 + 1;

List<TimeNeed> _needsOf(CalendarExportData data, _Styles styles)
{
  return [
    for (final lane in data.lanes) ...[
      for (final lesson in lane.lessons)
        (startMinutes: lesson.startMinutes, endMinutes: lesson.endMinutes, size: _lessonNeed(data, styles, lesson)),
      for (final activity in lane.activities)
        (startMinutes: activity.startMinutes, endMinutes: activity.endMinutes, size: _activityNeed(styles, activity)),
    ],
  ];
}

// The band in parts that each fit the page width, cut where no lesson runs across.
List<TimeScale> _gridScales(CalendarExportData data, _Styles styles)
{
  final window = data.window!;
  final track = _gridFormat.availableWidth - kNameColumnWidth;
  final needs = _needsOf(data, styles);

  TimeScale scaleOf(int start, int end) => TimeScale.elastic(
        start: start,
        end: end,
        extent: track,
        needs: needs,
        minQuarter: _minQuarter,
      );

  final whole = scaleOf(window.$1, window.$2);

  if (whole.extent <= track + 0.5)
  {
    return [whole];
  }

  bool isClean(int minute)
  {
    return data.lanes.every((lane) =>
        lane.lessons.every((lesson) => lesson.startMinutes >= minute || lesson.endMinutes <= minute) &&
        lane.activities.every((activity) => activity.startMinutes >= minute || activity.endMinutes <= minute));
  }

  // At its narrowest, as the whole band came out.
  final slices = whole.slices;
  int minuteAt(int slice) => math.min(window.$2, window.$1 + slice * kQuarterHour);

  final scales = <TimeScale>[];
  var first = 0;

  while (first < slices.length)
  {
    var reached = 0.0;
    var fits = first;
    var cut = first;

    for (var i = first; i < slices.length; i++)
    {
      reached += slices[i];

      if (reached > track)
      {
        break;
      }

      fits = i + 1;

      if (isClean(minuteAt(i + 1)))
      {
        cut = i + 1;
      }
    }

    // No clean cut fits: a lesson is split, rather than a page too wide.
    if (cut == first)
    {
      cut = fits == first ? first + 1 : fits;
    }

    scales.add(scaleOf(minuteAt(first), minuteAt(cut)));
    first = cut;
  }

  return scales;
}

List<pw.MultiPage> _gridPages(CalendarExportData data, _Styles styles)
{
  return [
    for (final scale in _gridScales(data, styles))
      pw.MultiPage(
        pageFormat: _gridFormat,
        maxPages: 60,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (context.pageNumber == 1) _titleBlock(data, styles),
            _ruler(data, styles, scale),
          ],
        ),
        footer: (context) => _footer(context, data, styles),
        build: (context) => [
          for (var i = 0; i < data.lanes.length; i++)
            _trackRow(data, styles, data.lanes[i], scale, striped: i.isOdd),
        ],
      ),
  ];
}

pw.Widget _ruler(CalendarExportData data, _Styles styles, TimeScale scale)
{
  final track = _gridFormat.availableWidth - kNameColumnWidth;

  double at(int minute) => atMinuteOfTrack(minute, scale: scale, track: track);

  final marks = [
    scale.start,
    for (var minute = (scale.start ~/ 30 + 1) * 30; minute < scale.end; minute += 30) minute,
  ];

  final slots = <pw.Widget>[];

  for (var i = 0; i < marks.length; i++)
  {
    final minute = marks[i];
    final next = i + 1 < marks.length ? marks[i + 1] : scale.end;
    final isHour = minute % 60 == 0;
    final width = at(next) - at(minute);

    final label = formatTimeOfDayShort(timeOfDayFromMinutes(minute));
    final style = isHour ? styles.rulerHour : styles.rulerHalf;
    final crowded = styles.widths.of(label, style) + 3 > width ||
        (next >= scale.end && width < _closingLabelRoom);

    slots.add(pw.SizedBox(
      width: width,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: isHour ? kPdfRule : kPdfLine, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.only(left: 2, bottom: 3),
        child: crowded ? pw.SizedBox() : pw.Text(label, style: style),
      ),
    ));
  }

  final columns = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: kNameColumnWidth,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(_rowNoun(data), style: styles.tableHead),
        ),
      ),
      ...slots,
    ],
  );

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: kPdfRule, width: 0.8)),
    ),
    child: pw.Stack(
      children: [
        columns,
        pw.Positioned(
          right: 0,
          bottom: 3,
          child: pw.Text(
            formatTimeOfDayShort(timeOfDayFromMinutes(scale.end)),
            style: scale.end % 60 == 0 ? styles.rulerHour : styles.rulerHalf,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _trackRow(
  CalendarExportData data,
  _Styles styles,
  CalendarLane lane,
  TimeScale scale, {
  required bool striped,
})
{
  final subLanes = lane.subLanesWith();

  final track = _gridFormat.availableWidth - kNameColumnWidth;

  double widthOf(int startMinutes, int endMinutes)
  {
    return atMinuteOfTrack(endMinutes, scale: scale, track: track) -
        atMinuteOfTrack(startMinutes, scale: scale, track: track) -
        2 * kBlockGap;
  }

  bool shows(int startMinutes, int endMinutes) => startMinutes < scale.end && endMinutes > scale.start;

  final lessons = [
    for (final (i, lesson) in lane.lessons.indexed)
      if (shows(lesson.startMinutes, lesson.endMinutes)) (lesson: lesson, subLane: subLanes.laneOf[i]),
  ];
  final activities = [
    for (final activity in lane.activities)
      if (shows(activity.startMinutes, activity.endMinutes)) activity,
  ];

  return CalendarPdfTrackRow(
    name: _laneHead(data, styles, lane),
    blocks: [
      for (final shown in lessons)
        _block(data, styles, shown.lesson, widthOf(shown.lesson.startMinutes, shown.lesson.endMinutes)),
      for (final activity in activities)
        _activityBlock(styles, activity, widthOf(activity.startMinutes, activity.endMinutes)),
    ],
    spans: [
      for (final shown in lessons) (shown.lesson.startMinutes, shown.lesson.endMinutes),
      for (final activity in activities) (activity.startMinutes, activity.endMinutes),
    ],
    // Activities always take the top sub-lane: they never overlap lessons.
    laneOf: [
      for (final shown in lessons) shown.subLane,
      for (final _ in activities) 0,
    ],
    laneCount: subLanes.laneCount,
    scale: scale,
    striped: striped,
  );
}

pw.Widget _laneHead(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  final room = data.roomByTeacher[lane.personTaxCode];

  final windows = data.isByStudent
      ? laneWhenLines(lane, bandStart: data.bandStart, bandEnd: data.bandEnd)
      : const <({String mode, String said})>[];

  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(lane.person.fullName, style: styles.laneName),
        if (room != null) ...[
          pw.SizedBox(height: 1),
          if (room.roomName != null)
            pw.Text(room.roomName!, style: styles.laneRoom)
          else
            pw.Text(modeLabel(kOnlineMode), style: styles.laneOnline),
          if (room.isSupervisor) pw.Text(kSupervisorLabel, style: styles.laneSupervisor),
        ],
        if (data.isByStudent) ...[
          pw.SizedBox(height: 1),
          if (windows.isEmpty)
            pw.Text(whenNothingLabel(data.view), style: styles.laneWhen)
          else
            for (final window in windows) pw.Text(window.said, style: styles.laneWhen),
        ],
      ],
    ),
  );
}

pw.Widget _block(CalendarExportData data, _Styles styles, LessonItem lesson, double width)
{
  final accent = pdfLessonAccent(lesson.mode);
  final where = lessonWhere(lesson);
  final topic = lessonTopic(lesson, data.ministrySubjects);
  final hours = _hoursFor(data, styles, lesson, width - _blockPadding.horizontal - 2 * _blockBorder);

  return pw.Container(
    decoration: pw.BoxDecoration(
      color: pdfLessonSurface(lesson.mode),
      border: pw.Border.all(color: accent, width: _blockBorder),
      borderRadius: pw.BorderRadius.circular(2.5),
    ),
    padding: _blockPadding,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.RichText(
          text: pw.TextSpan(
            text: hours.first,
            style: styles.blockHours(lesson.mode),
            children: [for (final part in hours.skip(1)) pw.TextSpan(text: ' · $part', style: styles.blockLength)],
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(topic.discipline, style: styles.blockTitle),
        if (topic.subject case final subject?) pw.Text(subject, style: styles.blockSubject),
        pw.SizedBox(height: 1.5),
        pw.Text(lessonTitle(lesson, view: data.view), style: styles.blockWho),
        if (data.isByStudent) pw.Text(where.label, style: styles.blockWhere(lesson.mode)),
      ],
    ),
  );
}

pw.Widget _activityBlock(_Styles styles, ScheduledActivity scheduled, double width)
{
  final usable = width - kBlockChrome;
  final description = scheduled.description;

  return pw.Container(
    decoration: pw.BoxDecoration(
      color: kPdfActivitySurface,
      border: pw.Border.all(color: kPdfActivity, width: 0.6),
      borderRadius: pw.BorderRadius.circular(2.5),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          usable >= 40 * _typeScale
              ? formatMinutesRange(scheduled.startMinutes, scheduled.endMinutes)
              : formatTimeOfDayShort(timeOfDayFromMinutes(scheduled.startMinutes)),
          style: styles.activityHours,
        ),
        pw.Text(scheduled.name, style: styles.blockTitle),
        if (description != null) pw.Text(description, style: styles.blockNote),
      ],
    ),
  );
}

// Longest first; the mode goes before the length, the end before the start.
List<String> _hoursFor(CalendarExportData data, _Styles styles, LessonItem lesson, double room)
{
  final range = formatTimeRange(lesson.startTime, lesson.endTime);
  final length = formatMinutes(lesson.minutes);

  final forms = [
    if (!data.isByStudent && lesson.mode == kOnlineMode) [range, length, modeLabel(kOnlineMode)],
    [range, length],
    [range],
    [formatTimeOfDayShort(lesson.startTime)],
  ];

  return forms.firstWhere((parts) => _hoursWidth(styles, lesson.mode, parts) <= room, orElse: () => forms.last);
}

double _hoursWidth(_Styles styles, String mode, List<String> parts)
{
  final widths = styles.widths;

  return widths.of(parts.first, styles.blockHours(mode)) +
      parts.skip(1).fold(0.0, (total, part) => total + widths.of(' · $part', styles.blockLength));
}

pw.MultiPage _listPages(CalendarExportData data, _Styles styles, {required bool withGridNote})
{

  return pw.MultiPage(
    pageFormat: _listFormat,
    maxPages: 60,
    header: (context) => context.pageNumber == 1
        ? _titleBlock(data, styles)
        : pw.SizedBox(),
    footer: (context) => _footer(context, data, styles),
    build: (context) => [
      if (withGridNote) ...[
        pw.Text(
          data.window == null
              ? 'Nessun orario di apertura per questa fascia: le lezioni sono elencate qui sotto.'
              : 'La griglia oraria non è stata stampata: l\'elenco qui sotto la riporta per intero.',
          style: styles.note,
        ),
        pw.SizedBox(height: 8),
      ],
      pw.Text('Elenco completo delle lezioni', style: styles.tableHead),
      pw.SizedBox(height: 6),
      pw.Table(
        tableWidth: pw.TableWidth.max,
        columnWidths: const {
          0: pw.FixedColumnWidth(116),
          1: pw.FlexColumnWidth(),
        },
        border: pw.TableBorder(
          top: pw.BorderSide(color: kPdfRule, width: 0.6),
          bottom: pw.BorderSide(color: kPdfRule, width: 0.6),
          horizontalInside: pw.BorderSide(color: kPdfLine, width: 0.4),
        ),
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: kPdfHeaderGround),
            children: [
              _headCell(_rowNoun(data), styles),
              _lessonsHeadCell(data, styles),
            ],
          ),
          for (final lane in data.lanes)
            pw.TableRow(
              children: [
                _nameCell(data, styles, lane),
                _lessonsCell(data, styles, lane),
              ],
            ),
        ],
      ),
    ],
  );
}

pw.Widget _headCell(String label, _Styles styles)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Text(label, style: styles.tableHead),
  );
}

pw.Widget _cell(pw.Widget child)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    child: child,
  );
}

pw.Widget _nameCell(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  final room = data.roomByTeacher[lane.personTaxCode];

  return _cell(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(lane.person.fullName, style: styles.cellName),
      if (room?.roomName != null) pw.Text(room!.roomName!, style: styles.cellRoom),
      if (room?.isSupervisor == true) pw.Text(kSupervisorLabel, style: styles.cellSupervisor),
    ],
  ));
}

const Map<int, pw.TableColumnWidth> _studentLessonColumns = {
  0: pw.FixedColumnWidth(58 * _typeScale),
  1: pw.FlexColumnWidth(0.85),
  2: pw.FlexColumnWidth(1.15),
  3: pw.FixedColumnWidth(88 * _typeScale),
};

const Map<int, pw.TableColumnWidth> _teacherLessonColumns = {
  0: pw.FixedColumnWidth(92 * _typeScale),
  1: pw.FlexColumnWidth(0.85),
  2: pw.FlexColumnWidth(1.15),
};

Map<int, pw.TableColumnWidth> _lessonColumnsFor(CalendarExportData data) =>
    data.isByStudent ? _studentLessonColumns : _teacherLessonColumns;

pw.Widget _lessonsHeadCell(CalendarExportData data, _Styles styles)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Table(
      columnWidths: _lessonColumnsFor(data),
      children: [
        pw.TableRow(
          children: [
            _lessonHead('Orario', styles),
            _lessonHead(data.isByStudent ? 'Docente' : 'Studente', styles),
            _lessonHead('Materia', styles),
            if (data.isByStudent) _lessonHead('Luogo', styles),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _lessonHead(String label, _Styles styles)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 5),
    child: pw.Text(label, style: styles.tableHead),
  );
}

pw.Widget _lessonsCell(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  if (lane.lessons.isEmpty && lane.activities.isEmpty)
  {
    return _cell(pw.Text('Nessuna lezione', style: styles.cellQuiet));
  }

  final rows = <({int startMinutes, pw.TableRow row})>[
    for (final lesson in lane.lessons)
      (startMinutes: lesson.startMinutes, row: _lessonRow(data, styles, lesson)),
    for (final activity in lane.activities)
      (startMinutes: activity.startMinutes, row: _activityRow(data, styles, activity)),
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  return _cell(pw.Table(
    columnWidths: _lessonColumnsFor(data),
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: kPdfLine, width: 0.4),
    ),
    children: [for (final entry in rows) entry.row],
  ));
}

pw.TableRow _activityRow(
  CalendarExportData data,
  _Styles styles,
  ScheduledActivity scheduled,
)
{
  final fields = exportActivityFields(scheduled);

  return pw.TableRow(
    children: [
      _lessonField(pw.Text(fields.hours, style: styles.activityCellHours)),
      _lessonField(pw.Text(fields.who, style: styles.cellLesson)),
      _lessonField(pw.Text(fields.subject, style: styles.cellLesson)),
      if (data.isByStudent) _lessonField(pw.SizedBox()),
    ],
  );
}

pw.TableRow _lessonRow(CalendarExportData data, _Styles styles, LessonItem lesson)
{
  final fields = exportLessonFields(
    lesson,
    view: data.view,
    ministrySubjects: data.ministrySubjects,
  );

  return pw.TableRow(
    children: [
      _lessonField(pw.Text(fields.hours, style: styles.cellHours)),
      _lessonField(pw.Text(fields.who, style: styles.cellLesson)),
      _lessonField(pw.Text(fields.subject, style: styles.cellLesson)),
      if (fields.place != null)
        _lessonField(pw.Text(fields.place!, style: styles.cellPlace(lesson.mode))),
    ],
  );
}

pw.Widget _lessonField(pw.Widget child)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 5, top: 3.5, bottom: 3.5),
    child: child,
  );
}

pw.Page _emptyPage(CalendarExportData data, _Styles styles)
{
  return pw.Page(
    pageFormat: _listFormat,
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _titleBlock(data, styles),
        pw.Expanded(
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  data.isByStudent ? 'Nessuno studente in calendario' : 'Nessun docente convocato',
                  style: styles.title,
                ),
                pw.SizedBox(height: 6),
                pw.Text('Nessuna lezione in calendario per questa fascia.', style: styles.note),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
