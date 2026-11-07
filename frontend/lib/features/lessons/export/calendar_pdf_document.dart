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
import 'calendar_export_data.dart';
import 'calendar_pdf_fonts.dart';
import 'calendar_pdf_palette.dart';

const String _association = 'ASSOCIAZIONE CASA MICHELA';

const double _typeScale = 1.25;

const double _logoSize = 66 * _typeScale;

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
  return '${calendarPdfViewLabel(data)} · ${_dayOnItsOwn(data.day)} · ${bandLabel(data.band)}';
}

// The tab holding both views is named after the band alone.
String calendarPdfBandTitle(CalendarExportData data)
{
  return 'Calendario · ${_dayOnItsOwn(data.day)} · ${bandLabel(data.band)}';
}

String calendarPdfViewLabel(CalendarExportData data)
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

  document.addPage(_listPages(data, styles));

  return document.save();
}

class _Styles
{
  _Styles(this.fonts);

  final CalendarPdfFonts fonts;

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

  late final pw.TextStyle activityCellHours = _style(7.5, fonts.bold, kPdfActivity);

  late final pw.TextStyle tableHead = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellName = _style(8.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellRoom = _style(6.8, fonts.bold, kPdfPresence);
  late final pw.TextStyle cellQuiet = _style(7, fonts.regular, kPdfMuted);
  late final pw.TextStyle cellSupervisedRoom = _style(6.8, fonts.bold, kPdfWhite);
  late final pw.TextStyle cellLesson = _style(7.5, fonts.regular, kPdfBody);
  late final pw.TextStyle cellTopic = _style(7.5, fonts.bold, kPdfInk);
  late final pw.TextStyle cellAside = _style(6.3, fonts.semiBold, kPdfMuted);
  late final pw.TextStyle together = _style(5.8, fonts.bold, kPdfViolet);

  pw.TextStyle cellHours(String mode) => _style(7.5, fonts.bold, pdfLessonAccent(mode));

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
        children: [
          _pill(bandLabel(data.band), styles),
          pw.SizedBox(width: 6),
          _pill(calendarPdfViewLabel(data), styles),
        ],
      ),
      pw.SizedBox(height: 5),
      _publicationLine(data, styles),
      pw.SizedBox(height: 3),
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

pw.Widget _legend(_Styles styles, {required bool withTogether, required bool withSupervisor})
{
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      _swatch(modeLabel(kPresenceMode), kPdfPresence, kPdfPresenceSurface, styles),
      pw.SizedBox(width: 12),
      _swatch(modeLabel(kOnlineMode), kPdfOnline, kPdfOnlineSurface, styles),
      if (withTogether) ...[
        pw.SizedBox(width: 12),
        _legendEntry(
          pw.CustomPaint(
            size: const PdfPoint(4, 8),
            painter: (canvas, size) => _strokeBracket(canvas, [
              PdfPoint(size.x, size.y - 0.5),
              PdfPoint(0.5, size.y - 0.5),
              const PdfPoint(0.5, 0.5),
              PdfPoint(size.x, 0.5),
            ]),
          ),
          _togetherLegend,
          styles,
        ),
      ],
      if (withSupervisor) ...[
        pw.SizedBox(width: 12),
        _legendEntry(
          pw.Container(
            padding: const pw.EdgeInsets.all(1),
            decoration: pw.BoxDecoration(color: kPdfPresence, borderRadius: pw.BorderRadius.circular(1.5)),
            child: pw.SvgImage(svg: _shieldIn(kPdfWhite), width: 6, height: 6),
          ),
          _supervisorLegend,
          styles,
        ),
      ],
    ],
  );
}

bool _supervising(CalendarExportData data) => data.roomByTeacher.values.any((room) => room.isSupervisor);

pw.Widget _swatch(String label, PdfColor accent, PdfColor surface, _Styles styles)
{
  return _legendEntry(
    pw.Container(
      width: 7,
      height: 7,
      decoration: pw.BoxDecoration(
        color: surface,
        border: pw.Border.all(color: accent, width: 0.6),
        borderRadius: pw.BorderRadius.circular(1.5),
      ),
    ),
    label,
    styles,
  );
}

pw.Widget _legendEntry(pw.Widget mark, String label, _Styles styles)
{
  return pw.Row(
    children: [
      mark,
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
          '${calendarPdfViewLabel(data)} · ${bandLabel(data.band)} · ${_dayOnItsOwn(data.day)}',
          style: styles.caption,
        ),
        pw.Text('Pagina ${context.pageNumber} di ${context.pagesCount}', style: styles.caption),
      ],
    ),
  );
}

// The app's own glyphs: Icons.shield_rounded and Icons.meeting_room_outlined.
String _shieldIn(PdfColor colour)
{
  return '<svg viewBox="0 0 24 24"><path d="M11.3 2.25L5.3 4.5C4.5 4.83 3.98 5.53 3.98 6.38V11.11'
      'C3.98 15.94 7.13 20.44 11.44 21.84C11.81 21.94 12.19 21.94 12.56 21.84C16.88 20.44 20.02 15.94 20.02 11.11'
      'V6.38C20.02 5.58 19.5 4.83 18.7 4.5L12.7 2.25C12.23 2.11 11.77 2.11 11.3 2.25Z" '
      'fill="${colour.toHex().substring(0, 7)}"/></svg>';
}

String _doorIn(PdfColor colour)
{
  return '<svg viewBox="0 0 24 24"><path fill-rule="evenodd" d="M18.98 18.98V3.98H15V3H5.02V18.98H3V21H15V6'
      'H17.02V21H21V18.98H18.98ZM12.98 18.98H6.98V5.02H12.98V18.98ZM9.98 11.02H12V12.98H9.98V11.02Z" '
      'fill="${colour.toHex().substring(0, 7)}"/></svg>';
}

// The list's legend words for hours held together and for a room's supervisor.
const String _togetherLegend = 'Compresenza';
const String _supervisorLegend = 'Responsabile di stanza';

const double _nameColumn = 108;

// People part with a marked rule, so a row's hours never seem to run into the next row's.
const double _peopleRule = 1.1;

// Every hour is a strip tinted as its block on the timeline, opened by a bar of its mode's colour.
const double _stripBar = 2.4;
const double _stripLead = _stripBar + 4.5;
const double _stripTrail = 4;
const double _stripGap = 2;

// Two lessons held together are joined by a violet bracket left of their strips; brackets that
// nest take a track each, the shorter nearer the strips.
const double _bracketTrack = 3.2;
const double _bracketStroke = 1.1;
const double _bracketReach = 1.6;

const double _hoursColumn = 70 * _typeScale;
const double _placeColumn = 62 * _typeScale;
const int _whoFlex = 9;
const int _topicFlex = 11;

pw.MultiPage _listPages(CalendarExportData data, _Styles styles)
{
  final tracks = [
    for (final lane in data.lanes)
      for (final bracket in _bracketsOf(_hoursOf(data, lane))) bracket.track + 1,
  ].fold(0, math.max);
  final gutter = tracks == 0 ? 3.0 : 2 + tracks * _bracketTrack + _bracketReach;

  return pw.MultiPage(
    pageFormat: _listFormat,
    maxPages: 60,
    header: (context) => context.pageNumber == 1 ? _titleBlock(data, styles) : pw.SizedBox(),
    footer: (context) => _footer(context, data, styles),
    build: (context)
    {
      final room = _rowRoom(context, data, styles, gutter);

      return [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Elenco completo delle lezioni', style: styles.tableHead),
            _legend(styles, withTogether: tracks > 0, withSupervisor: _supervising(data)),
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
            top: pw.BorderSide(color: kPdfMuted, width: _peopleRule),
            bottom: pw.BorderSide(color: kPdfMuted, width: _peopleRule),
            horizontalInside: pw.BorderSide(color: kPdfMuted, width: _peopleRule),
          ),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: pw.BoxDecoration(color: kPdfHeaderGround),
              children: [
                _headCell(_rowNoun(data), styles),
                _lessonsHeadCell(data, styles, gutter),
              ],
            ),
            for (final lane in data.lanes) ..._laneRows(context, data, styles, lane, gutter, room),
          ],
        ),
      ];
    },
  );
}

final double _lessonsColumn = _listFormat.availableWidth - _nameColumn;

// Padding above and below a row's strips.
const double _lessonsInset = 5 + 5 - _stripGap;

double _heightOf(pw.Context context, pw.Widget widget, double width)
{
  widget.layout(context, pw.BoxConstraints(minWidth: width, maxWidth: width));

  return widget.box!.height;
}

// The tallest row a page holds under the repeated head and above the footer.
double _rowRoom(pw.Context context, CalendarExportData data, _Styles styles, double gutter)
{
  final head = _heightOf(context, _lessonsHeadCell(data, styles, gutter), _lessonsColumn);
  final footer = _heightOf(context, pw.Text('Pagina', style: styles.caption), _lessonsColumn) + 4.4;

  return _listFormat.availableHeight - head - footer - 3 * _peopleRule - 4;
}

// A table row never splits, so a person moves whole to the next page; only one taller than a
// whole page is cut, between two hours, each piece under the name again.
List<pw.TableRow> _laneRows(
  pw.Context context,
  CalendarExportData data,
  _Styles styles,
  CalendarLane lane,
  double gutter,
  double room,
)
{
  final measured = _lessonStrips(data, styles, lane, gutter);
  final heights = [for (final strip in measured) _heightOf(context, strip, _lessonsColumn - 10)];

  final pieces = <(int, int)>[];
  var from = 0;
  var used = _lessonsInset;

  for (var i = 0; i < heights.length; i++)
  {
    if (i > from && used + heights[i] > room)
    {
      pieces.add((from, i));
      from = i;
      used = _lessonsInset;
    }

    used += heights[i];
  }

  pieces.add((from, heights.length));

  final strips = _lessonStrips(data, styles, lane, gutter);

  return [
    for (final (start, end) in pieces)
      pw.TableRow(
        children: [
          _nameCell(data, styles, lane),
          _lessonsCell(styles, strips.sublist(start, end), gutter),
        ],
      ),
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

// The name, and under it a pupil's hours, or every room of the teacher's hours: those they
// answer for on the shield.
pw.Widget _nameCell(CalendarExportData data, _Styles styles, CalendarLane lane)
{
  final rooms = data.roomByTeacher[lane.personTaxCode]?.roomsInOrder ?? const <({String name, bool supervised})>[];

  return _cell(pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(lane.person.fullName, style: styles.cellName),
      if (data.isByStudent)
        for (final window in laneWhenLines(lane, bandStart: data.bandStart, bandEnd: data.bandEnd))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(window.said, style: styles.cellAside),
          ),
      for (final room in rooms)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: _roomLine(styles, room),
        ),
    ],
  ));
}

// A supervised room is a teal tag with the white shield; any other keeps the app's door.
pw.Widget _roomLine(_Styles styles, ({String name, bool supervised}) room)
{
  const double icon = 7;

  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(2.5, 1.2, 4, 1.2),
    decoration: room.supervised
        ? pw.BoxDecoration(color: kPdfPresence, borderRadius: pw.BorderRadius.circular(2))
        : null,
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SvgImage(
          svg: room.supervised ? _shieldIn(kPdfWhite) : _doorIn(kPdfPresence),
          width: icon,
          height: icon,
        ),
        pw.SizedBox(width: 2.5),
        pw.Flexible(
          child: pw.Text(room.name, style: room.supervised ? styles.cellSupervisedRoom : styles.cellRoom),
        ),
      ],
    ),
  );
}

pw.Widget _lessonsHeadCell(CalendarExportData data, _Styles styles, double gutter)
{
  return pw.Padding(
    padding: pw.EdgeInsets.fromLTRB(5 + gutter + _stripLead, 4, 5 + _stripTrail, 4),
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

// One strip of a row: a stretch of lessons or an activity.
typedef _Hour = ({int startMinutes, int endMinutes, List<LessonItem>? stretch, ScheduledActivity? activity});

List<_Hour> _hoursOf(CalendarExportData data, CalendarLane lane)
{
  return [
    for (final stretch in exportStretches(data, lane))
      (
        startMinutes: stretch.first.startMinutes,
        endMinutes: stretch.last.endMinutes,
        stretch: stretch,
        activity: null,
      ),
    for (final activity in lane.activities)
      (startMinutes: activity.startMinutes, endMinutes: activity.endMinutes, stretch: null, activity: activity),
  ]..sort((a, b) => a.startMinutes != b.startMinutes
      ? a.startMinutes.compareTo(b.startMinutes)
      : a.endMinutes.compareTo(b.endMinutes));
}

(int, int) _spanOf(_Hour hour) => (hour.startMinutes, hour.endMinutes);

// A pair of lessons held together, its track, and where it meets its two strips (from their tops).
typedef _Bracket = ({int first, int second, int track, double opensAt, double closesAt});

List<_Bracket> _bracketsOf(List<_Hour> hours)
{
  final pairs = togetherPairs([for (final hour in hours) hour.stretch == null ? null : _spanOf(hour)]);
  final opening = {for (final pair in pairs) pair.first};
  final closing = {for (final pair in pairs) pair.second};

  // A strip closing one pair and opening the next meets them at different heights, so they never read as one.
  double opensAt(int index) => closing.contains(index) ? 0.72 : 0.5;
  double closesAt(int index) => opening.contains(index) ? 0.28 : 0.5;

  final reach = <double>[];
  final brackets = <_Bracket>[];

  for (final pair in pairs)
  {
    final from = pair.first + opensAt(pair.first);
    var track = reach.indexWhere((end) => end < from);

    if (track < 0)
    {
      track = reach.length;
      reach.add(0);
    }

    reach[track] = pair.second + closesAt(pair.second);
    brackets.add((
      first: pair.first,
      second: pair.second,
      track: track,
      opensAt: opensAt(pair.first),
      closesAt: closesAt(pair.second),
    ));
  }

  return brackets;
}

// Every hour of a row as its strip, bracketed with the other of its pair.
List<pw.Widget> _lessonStrips(CalendarExportData data, _Styles styles, CalendarLane lane, double gutter)
{
  final hours = _hoursOf(data, lane);
  final brackets = _bracketsOf(hours);

  // Beside each pupil, the hours they share with the other of the pair.
  List<String> togetherWith(int index) => [
        for (final bracket in brackets)
          if (bracket.first == index || bracket.second == index)
            togetherLabel([_spanOf(hours[bracket.first]), _spanOf(hours[bracket.second])]),
      ];

  return [
    for (final (index, hour) in hours.indexed)
      _bracketed(
        index: index,
        brackets: brackets,
        gutter: gutter,
        strip: hour.stretch == null
            ? _activityStrip(styles, hour.activity!)
            : _lessonStrip(data, styles, hour.stretch!, together: togetherWith(index)),
      ),
  ];
}

pw.Widget _lessonsCell(_Styles styles, List<pw.Widget> strips, double gutter)
{
  if (strips.isEmpty)
  {
    return pw.Padding(
      padding: pw.EdgeInsets.fromLTRB(5 + gutter + _stripLead, 5, 5, 5),
      child: pw.Text('Nessuna lezione', style: styles.cellQuiet),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(5, 5, 5, 5 - _stripGap),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: strips,
    ),
  );
}

pw.Widget _bracketed({
  required pw.Widget strip,
  required int index,
  required List<_Bracket> brackets,
  required double gutter,
})
{
  final crossing = [
    for (final bracket in brackets)
      if (bracket.first <= index && index <= bracket.second) bracket,
  ];
  final body = pw.Padding(padding: pw.EdgeInsets.only(left: gutter, bottom: _stripGap), child: strip);

  if (crossing.isEmpty)
  {
    return body;
  }

  return pw.Stack(
    children: [
      body,
      pw.Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: pw.CustomPaint(
          size: PdfPoint(gutter, 0),
          painter: (canvas, size) => _paintBrackets(canvas, size, index, crossing),
        ),
      ),
    ],
  );
}

// Drawn strip by strip: a bracket opens on its first strip, runs past those between, closes on its second.
void _paintBrackets(PdfGraphics canvas, PdfPoint size, int index, List<_Bracket> brackets)
{
  final strip = size.y - _stripGap;
  final edge = size.x - 0.8;

  // PDF heights grow upwards; the fractions are measured from the strip's top.
  double at(double fraction) => size.y - fraction * strip;

  for (final bracket in brackets)
  {
    final x = size.x - _bracketReach - (bracket.track + 0.5) * _bracketTrack;

    _strokeBracket(canvas, [
      if (index == bracket.first) ...[
        PdfPoint(edge, at(bracket.opensAt)),
        PdfPoint(x, at(bracket.opensAt)),
      ]
      else
        PdfPoint(x, size.y),
      if (index == bracket.second) ...[
        PdfPoint(x, at(bracket.closesAt)),
        PdfPoint(edge, at(bracket.closesAt)),
      ]
      else
        PdfPoint(x, 0),
    ]);
  }
}

void _strokeBracket(PdfGraphics canvas, List<PdfPoint> points)
{
  canvas
    ..setStrokeColor(kPdfViolet)
    ..setLineWidth(_bracketStroke)
    ..setLineJoin(PdfLineJoin.round)
    ..moveTo(points.first.x, points.first.y);

  for (final point in points.skip(1))
  {
    canvas.lineTo(point.x, point.y);
  }

  canvas.strokePath();
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

pw.Widget _lessonStrip(
  CalendarExportData data,
  _Styles styles,
  List<LessonItem> stretch, {
  List<String> together = const [],
})
{
  final lesson = stretch.first;
  final fields = exportStretchFields(data, stretch);
  final subject = fields.subject;

  return _strip(
    accent: pdfLessonAccent(lesson.mode),
    surface: pdfLessonSurface(lesson.mode),
    child: _columns(
      hours: pw.Text(fields.hours, style: styles.cellHours(lesson.mode)),
      who: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(fields.who, style: styles.cellLesson),
          for (final label in together)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1.5),
              child: pw.Text(label, style: styles.together),
            ),
        ],
      ),
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
