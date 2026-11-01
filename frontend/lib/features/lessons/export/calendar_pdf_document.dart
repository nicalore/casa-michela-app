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
import '../widgets/calendar_activity_block.dart' show kActivityWord;
import '../widgets/calendar_lesson_block.dart';
import 'calendar_export_data.dart';
import 'calendar_pdf_fonts.dart';
import 'calendar_pdf_grid.dart';
import 'calendar_pdf_palette.dart';

const String _association = 'ASSOCIAZIONE CASA MICHELA';

const double _typeScale = 1.25;

const double _logoSize = 66 * _typeScale;

const double _closingLabelRoom = 46 * _typeScale;

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

  // The grid's sizes are its own, unscaled: two lines a block, a whole band to a page.
  pw.TextStyle _grid(double size, pw.Font font, PdfColor colour) => pw.TextStyle(
        font: font,
        fontSize: size,
        color: colour,
      );

  pw.TextStyle gridName(double size) => _grid(size, fonts.bold, kPdfInk);
  late final pw.TextStyle gridAside = _grid(6, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle gridRoom = _grid(6, fonts.bold, kPdfPresence);
  late final pw.TextStyle gridOnline = _grid(6, fonts.bold, kPdfOnline);
  late final pw.TextStyle gridTitle = _grid(6.8, fonts.bold, kPdfInk);
  late final pw.TextStyle gridBelow = _grid(6.3, fonts.semiBold, kPdfPerson);

  pw.TextStyle gridHours(PdfColor colour) => _grid(6.8, fonts.bold, colour);

  late final pw.TextStyle activityCellHours = _style(7.5, fonts.bold, kPdfActivity);

  late final pw.TextStyle tableHead = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellName = _style(8.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellRoom = _style(6.8, fonts.bold, kPdfPresence);
  late final pw.TextStyle cellQuiet = _style(7, fonts.regular, kPdfMuted);
  late final pw.TextStyle supervisorTag = _style(5.6, fonts.bold, kPdfWhite, spacing: 0.5);
  late final pw.TextStyle cellLesson = _style(7.5, fonts.regular, kPdfBody);
  late final pw.TextStyle cellTopic = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellAside = _style(6.3, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle together = _style(5.8, fonts.bold, kPdfViolet, spacing: 0.6);

  pw.TextStyle cellHours(String mode) => _style(7.5, fonts.bold, pdfLessonAccent(mode));

  pw.TextStyle cellPlace(String mode) => _style(7.5, fonts.semiBold, pdfLessonAccent(mode));
}

pw.Widget _titleBlock(CalendarExportData data, _Styles styles, {bool withLegend = true})
{
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: _titleWords(data, styles, withLegend: withLegend)),
      pw.SizedBox(width: 16),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.Image(styles.fonts.logo, width: _logoSize, height: _logoSize),
      ),
    ],
  );
}

pw.Widget _titleWords(CalendarExportData data, _Styles styles, {required bool withLegend})
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
      if (withLegend) ...[
        _legend(styles),
        pw.SizedBox(height: 6),
      ],
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

pw.Widget _legend(_Styles styles, {bool withTogether = false})
{
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _swatch(modeLabel(kPresenceMode), kPdfPresence, kPdfPresenceSurface, styles),
      pw.SizedBox(width: 12),
      _swatch(modeLabel(kOnlineMode), kPdfOnline, kPdfOnlineSurface, styles),
      if (withTogether) ...[
        pw.SizedBox(width: 12),
        _swatch(_togetherLegend, kPdfViolet, kPdfVioletSurface, styles),
      ],
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

// The grid keeps the whole band on one page width: a block writes what fits on its two lines
// and leaves out the rest, never cutting a word, nor widening the hours, nor repeating a lesson.
const double _blockHeight = 26;
const double _blockBar = 2.2;
const double _blockLine = 0.6;
const double _blockLead = _blockBar + 2.6;
const double _blockTrail = 1.5;

const double _nameSize = 8.2;
const double _leastNameSize = 5.4;

List<pw.MultiPage> _gridPages(CalendarExportData data, _Styles styles)
{
  final window = data.window!;
  final scale = TimeScale.even(window.$1, window.$2, _gridFormat.availableWidth - kNameColumnWidth);

  return [
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

  return CalendarPdfTrackRow(
    name: _laneHead(data, styles, lane),
    blocks: [
      for (final lesson in lane.lessons)
        _block(data, styles, lesson, widthOf(lesson.startMinutes, lesson.endMinutes)),
      for (final activity in lane.activities)
        _activityBlock(styles, activity, widthOf(activity.startMinutes, activity.endMinutes)),
    ],
    spans: [
      for (final lesson in lane.lessons) (lesson.startMinutes, lesson.endMinutes),
      for (final activity in lane.activities) (activity.startMinutes, activity.endMinutes),
    ],
    // Activities always take the top sub-lane; subLanesWith puts lessons alongside under them.
    laneOf: [
      ...subLanes.laneOf,
      for (final _ in lane.activities) 0,
    ],
    laneCount: subLanes.laneCount,
    scale: scale,
    striped: striped,
  );
}

// The name on one line, shrunk rather than cut; under it a pupil's hours, or a teacher's rooms.
pw.Widget _laneHead(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  final name = lane.person.fullName;
  final room = data.roomByTeacher[lane.personTaxCode];
  final width = kNameColumnWidth - 6;

  var size = _nameSize;

  while (size > _leastNameSize && styles.widths.of(name, styles.gridName(size)) > width)
  {
    size -= 0.2;
  }

  final rooms = room?.roomsInOrder ?? const <({String name, bool supervised})>[];
  final anyShield = rooms.any((stay) => stay.supervised);

  return pw.Padding(
    padding: const pw.EdgeInsets.only(right: 6, top: 1),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(name, style: styles.gridName(size), maxLines: 1),
        pw.SizedBox(height: 1.5),
        if (data.isByStudent)
          for (final window in laneWhenLines(lane, bandStart: data.bandStart, bandEnd: data.bandEnd))
            pw.Text(window.said, style: styles.gridAside)
        else if (room != null && room.roomName == null)
          pw.Text(modeLabel(kOnlineMode), style: styles.gridOnline)
        else
          for (final stay in rooms)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (stay.supervised)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 0.6, right: 1.6),
                      child: pw.SvgImage(svg: _shieldIn(kPdfPresence), width: 6, height: 6),
                    )
                  else if (anyShield)
                    pw.SizedBox(width: 7.6),
                  pw.Expanded(child: pw.Text(stay.name, style: styles.gridRoom)),
                ],
              ),
            ),
      ],
    ),
  );
}

// A two-line block: start and discipline above, who and where below.
pw.Widget _block(CalendarExportData data, _Styles styles, LessonItem lesson, double width)
{
  final accent = pdfLessonAccent(lesson.mode);
  final topic = lessonTopic(lesson, data.ministrySubjects);
  final room = data.roomByTeacher[lesson.teacherTaxCode];

  final String? where;

  if (data.isByStudent)
  {
    where = lessonWhere(lesson).label;
  }
  else
  {
    // A teacher changing room has each hour say where; online hours never name one.
    where = lesson.mode == kPresenceMode && (room?.changesRoom ?? false)
        ? room!.roomAt(lesson.startMinutes, lesson.endMinutes)?.name
        : null;
  }

  final who = data.isByStudent ? _initialled(lesson.teacher.fullName) : lessonTitle(lesson, view: data.view);

  return _gridBlock(
    styles,
    width: width,
    accent: accent,
    surface: pdfLessonSurface(lesson.mode),
    start: formatTimeOfDayShort(lesson.startTime),
    title: topic.discipline,
    below: [who, ?where],
    hoursStyle: styles.gridHours(accent),
  );
}

pw.Widget _activityBlock(_Styles styles, ScheduledActivity scheduled, double width)
{
  return _gridBlock(
    styles,
    width: width,
    accent: kPdfActivity,
    surface: kPdfActivitySurface,
    start: formatTimeOfDayShort(timeOfDayFromMinutes(scheduled.startMinutes)),
    title: scheduled.name,
    below: [kActivityWord],
    hoursStyle: styles.gridHours(kPdfActivity),
  );
}

pw.Widget _gridBlock(
  _Styles styles, {
  required double width,
  required PdfColor accent,
  required PdfColor surface,
  required String start,
  required String title,
  required List<String> below,
  required pw.TextStyle hoursStyle,
})
{
  final room = width - _blockLead - _blockTrail - _blockLine;
  final widths = styles.widths;

  // The first line drops the title, then the hour; the second drops from its end.
  final hourWidth = widths.of(start, hoursStyle);
  final showsHour = hourWidth <= room;
  final showsTitle = showsHour && hourWidth + widths.of(' $title', styles.gridTitle) <= room;

  final second = <String>[];
  var used = 0.0;

  for (final (index, piece) in below.indexed)
  {
    final said = index == 0 ? piece : ' · $piece';
    final needs = widths.of(said, styles.gridBelow);

    if (used + needs > room)
    {
      break;
    }

    second.add(said);
    used += needs;
  }

  return pw.SizedBox(
    width: width,
    height: _blockHeight,
    child: pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: surface,
              border: pw.Border.all(color: accent, width: _blockLine),
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
        ),
        pw.Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: pw.Container(
            width: _blockBar,
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.horizontal(left: pw.Radius.circular(2)),
            ),
          ),
        ),
        pw.Positioned(
          left: _blockLead,
          top: 2.6,
          child: pw.RichText(
            maxLines: 1,
            text: pw.TextSpan(
              children: [
                if (showsHour) pw.TextSpan(text: start, style: hoursStyle),
                if (showsTitle) pw.TextSpan(text: ' $title', style: styles.gridTitle),
              ],
            ),
          ),
        ),
        pw.Positioned(
          left: _blockLead,
          top: 13.6,
          child: pw.Text(second.join(), style: styles.gridBelow, maxLines: 1),
        ),
      ],
    ),
  );
}

// "Paola Cattaneo" as "P. Cattaneo": a pupil's row names the teacher in short.
String _initialled(String fullName)
{
  final parts = fullName.trim().split(RegExp(r'\s+'));

  return parts.length < 2 ? fullName : '${parts.first.substring(0, 1)}. ${parts.skip(1).join(' ')}';
}

String _shieldIn(PdfColor colour)
{
  return '<svg viewBox="0 0 24 24"><path d="M12 2.5l8 3v6c0 5-3.4 8.9-8 10.5C7.4 20.4 4 16.5 4 11.5v-6z" '
      'fill="${colour.toHex().substring(0, 7)}"/></svg>';
}

// The list's legend word for hours held together, and the tag of a room's supervisor.
const String _togetherLegend = 'Compresenza';
const String _supervisorTagText = 'RESPONSABILE';

// A shield, as the app marks a room's supervisor.
const String _shield = '<svg viewBox="0 0 24 24">'
    '<path d="M12 2.5l8 3v6c0 5-3.4 8.9-8 10.5C7.4 20.4 4 16.5 4 11.5v-6z" fill="#ffffff"/></svg>';

const double _nameColumn = 108;

// Every hour is a strip tinted as its block on the timeline, opened by a bar of its mode's colour.
const double _stripBar = 2.4;
const double _stripLead = _stripBar + 4.5;
const double _stripTrail = 4;
const double _stripGap = 2;

// Hours held together sit in a violet frame; every other strip keeps its inset, so columns line up.
const double _frameInset = 3;

const double _hoursColumn = 70 * _typeScale;
const double _placeColumn = 62 * _typeScale;
const int _whoFlex = 9;
const int _topicFlex = 11;

pw.MultiPage _listPages(CalendarExportData data, _Styles styles, {required bool withGridNote})
{

  return pw.MultiPage(
    pageFormat: _listFormat,
    maxPages: 60,
    header: (context) => context.pageNumber == 1
        ? _titleBlock(data, styles, withLegend: false)
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
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('Elenco completo delle lezioni', style: styles.tableHead),
          _legend(styles, withTogether: _holdsTogether(data)),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Table(
        tableWidth: pw.TableWidth.max,
        columnWidths: const {
          0: pw.FixedColumnWidth(_nameColumn),
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

bool _holdsTogether(CalendarExportData data)
{
  return data.lanes.any((lane) => heldTogether(_spansOf(lane), (span) => span).any((together) => together.length > 1));
}

List<(int, int)> _spansOf(CalendarLane lane)
{
  return [
    for (final lesson in lane.lessons) (lesson.startMinutes, lesson.endMinutes),
    for (final activity in lane.activities) (activity.startMinutes, activity.endMinutes),
  ];
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

// The name, and under it only the rooms the teacher answers for: each hour says its own place.
pw.Widget _nameCell(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  final supervised = data.roomByTeacher[lane.personTaxCode]?.supervisedRooms ?? const <String>[];

  return _cell(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(lane.person.fullName, style: styles.cellName),
      if (supervised.isNotEmpty) ...[
        pw.SizedBox(height: 2.5),
        _supervisorTag(styles),
        for (final room in supervised)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1.5),
            child: pw.Text(room, style: styles.cellRoom),
          ),
      ],
    ],
  ));
}

pw.Widget _supervisorTag(_Styles styles)
{
  const double size = 5.6 * _typeScale;

  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(3, 0.8, 3, 0.6),
    decoration: pw.BoxDecoration(color: kPdfPresence, borderRadius: pw.BorderRadius.circular(2)),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SvgImage(svg: _shield, width: size, height: size),
        pw.SizedBox(width: 2),
        pw.Text(_supervisorTagText, style: styles.supervisorTag),
      ],
    ),
  );
}

pw.Widget _lessonsHeadCell(CalendarExportData data, _Styles styles)
{
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(5 + _frameInset + _stripLead, 4, 5 + _frameInset + _stripTrail, 4),
    child: _columns(
      hours: pw.Text('Orario', style: styles.tableHead),
      who: pw.Text(data.isByStudent ? 'Docente' : 'Studente', style: styles.tableHead),
      topic: pw.Text('Materia', style: styles.tableHead),
      place: pw.Text('Luogo', style: styles.tableHead),
    ),
  );
}

// A strip's four columns; the header lines its labels up the same way.
pw.Widget _columns({
  required pw.Widget hours,
  required pw.Widget who,
  required pw.Widget topic,
  required pw.Widget place,
})
{
  pw.Widget spaced(pw.Widget child) => pw.Padding(padding: const pw.EdgeInsets.only(right: 5), child: child);

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(width: _hoursColumn, child: spaced(hours)),
      pw.Expanded(flex: _whoFlex, child: spaced(who)),
      pw.Expanded(flex: _topicFlex, child: spaced(topic)),
      pw.SizedBox(width: _placeColumn, child: place),
    ],
  );
}

pw.Widget _lessonsCell(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  if (lane.lessons.isEmpty && lane.activities.isEmpty)
  {
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(5 + _frameInset + _stripLead, 5, 5, 5),
      child: pw.Text('Nessuna lezione', style: styles.cellQuiet),
    );
  }

  final hours = <_Hour>[
    for (final lesson in lane.lessons)
      (startMinutes: lesson.startMinutes, endMinutes: lesson.endMinutes, strip: _lessonStrip(data, styles, lesson)),
    for (final activity in lane.activities)
      (startMinutes: activity.startMinutes, endMinutes: activity.endMinutes, strip: _activityStrip(styles, activity)),
  ];

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(5, 5, 5, 5 - _stripGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final together in heldTogether(hours, _spanOf)) _togetherPiece(styles, together),
      ],
    ),
  );
}

// One hour of a row's lessons cell: a lesson or an activity.
typedef _Hour = ({int startMinutes, int endMinutes, pw.Widget strip});

(int, int) _spanOf(_Hour hour) => (hour.startMinutes, hour.endMinutes);

// Hours held at the same time share a violet frame that says when.
pw.Widget _togetherPiece(_Styles styles, List<_Hour> together)
{
  final strips = [
    for (final hour in together)
      pw.Padding(padding: const pw.EdgeInsets.only(bottom: _stripGap), child: hour.strip),
  ];

  if (together.length == 1)
  {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: _frameInset), child: strips.single);
  }

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: _stripGap),
    padding: const pw.EdgeInsets.fromLTRB(_frameInset, 2, _frameInset, 0),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: kPdfViolet, width: 1),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(
            togetherLabel([for (final hour in together) _spanOf(hour)]).toUpperCase(),
            style: styles.together,
          ),
        ),
        ...strips,
      ],
    ),
  );
}

// Tinted as the hour's block on the timeline, the bar of its mode on the left.
pw.Widget _strip({required PdfColor accent, required PdfColor surface, required pw.Widget child})
{
  return pw.Stack(
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(_stripLead, 3.2, _stripTrail, 3.2),
        decoration: pw.BoxDecoration(color: surface, borderRadius: pw.BorderRadius.circular(2)),
        child: child,
      ),
      pw.Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: pw.Container(
          width: _stripBar,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: const pw.BorderRadius.horizontal(left: pw.Radius.circular(2)),
          ),
        ),
      ),
    ],
  );
}

pw.Widget _lessonStrip(CalendarExportData data, _Styles styles, LessonItem lesson)
{
  final fields = exportLessonFields(
    lesson,
    view: data.view,
    ministrySubjects: data.ministrySubjects,
    room: data.roomByTeacher[lesson.teacherTaxCode],
  );
  final subject = fields.subject;

  return _strip(
    accent: pdfLessonAccent(lesson.mode),
    surface: pdfLessonSurface(lesson.mode),
    child: _columns(
      hours: pw.Text(fields.hours, style: styles.cellHours(lesson.mode)),
      who: pw.Text(fields.who, style: styles.cellLesson),
      topic: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(fields.discipline, style: styles.cellTopic),
          if (subject != null) pw.Text(subject, style: styles.cellAside),
        ],
      ),
      place: pw.Text(fields.place, style: styles.cellPlace(lesson.mode)),
    ),
  );
}

// An activity has no place: its name stands in the middle of the row, after the hours.
pw.Widget _activityStrip(_Styles styles, ScheduledActivity scheduled)
{
  final fields = exportActivityFields(scheduled);
  final description = fields.description;

  return _strip(
    accent: kPdfActivity,
    surface: kPdfActivitySurface,
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: _hoursColumn,
          child: pw.Text(fields.hours, style: styles.activityCellHours),
        ),
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(fields.name, style: styles.cellTopic, textAlign: pw.TextAlign.center),
              if (description != null)
                pw.Text(description, style: styles.cellAside, textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      ],
    ),
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
