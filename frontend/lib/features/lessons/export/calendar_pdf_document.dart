import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../models/calendar_day.dart';
import '../models/calendar_publication_item.dart';
import '../models/lesson_item.dart';
import '../utils/opening_window.dart';
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
      document.addPage(_gridPages(data, styles));
    }
    on Exception
    {
      gridFailed = true;
    }
  }

  document.addPage(_listPages(data, styles, withGridNote: gridFailed));

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

  late final pw.TextStyle rulerHour = _style(7, fonts.bold, kPdfInk);
  late final pw.TextStyle rulerHalf = _style(6.5, fonts.regular, kPdfMuted);

  late final pw.TextStyle laneName = _style(8, fonts.bold, kPdfInk);
  late final pw.TextStyle laneRoom = _style(6.5, fonts.bold, kPdfPresence);
  late final pw.TextStyle laneOnline = _style(6.5, fonts.bold, kPdfOnline);
  late final pw.TextStyle laneSupervisor = _style(6, fonts.semiBold, kPdfPresence);
  late final pw.TextStyle laneWhen = _style(6, fonts.regular, kPdfMuted);

  late final pw.TextStyle blockSubject = _style(6, fonts.regular, kPdfBody);
  late final pw.TextStyle blockWho = _style(6.5, fonts.bold, kPdfInk);
  late final pw.TextStyle marker = _style(7, fonts.bold, kPdfWhite);

  pw.TextStyle blockHours(String mode) => _style(6.5, fonts.bold, pdfLessonAccent(mode));

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

pw.MultiPage _gridPages(CalendarExportData data, _Styles styles)
{
  final window = data.window!;

  return pw.MultiPage(
    pageFormat: _gridFormat,
    maxPages: 60,
    header: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (context.pageNumber == 1) _titleBlock(data, styles),
        _ruler(data, styles, window),
      ],
    ),
    footer: (context) => _footer(context, data, styles),
    build: (context) => [
      for (var i = 0; i < data.lanes.length; i++)
        _trackRow(data, styles, data.lanes[i], window, striped: i.isOdd),
    ],
  );
}

pw.Widget _ruler(CalendarExportData data, _Styles styles, (int, int) window)
{
  final track = _gridFormat.availableWidth - kNameColumnWidth;

  double at(int minute) => atMinuteOfTrack(
        minute,
        windowStart: window.$1,
        windowEnd: window.$2,
        track: track,
      );

  final slots = <pw.Widget>[];

  for (var minute = window.$1; minute < window.$2; minute += 30)
  {
    final isHour = minute % 60 == 0;
    final width = at(minute + 30) - at(minute);

    final crowded = minute + 30 >= window.$2 && width < _closingLabelRoom;

    slots.add(pw.SizedBox(
      width: width,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: isHour ? kPdfRule : kPdfLine, width: 0.5)),
        ),
        padding: const pw.EdgeInsets.only(left: 2, bottom: 3),
        child: crowded
            ? pw.SizedBox()
            : pw.Text(
                formatTimeOfDayShort(timeOfDayFromMinutes(minute)),
                style: isHour ? styles.rulerHour : styles.rulerHalf,
              ),
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
            formatTimeOfDayShort(timeOfDayFromMinutes(window.$2)),
            style: window.$2 % 60 == 0 ? styles.rulerHour : styles.rulerHalf,
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
  (int, int) window, {
  required bool striped,
})
{
  final subLanes = lane.subLanesWith();

  final track = _gridFormat.availableWidth - kNameColumnWidth;
  final minutes = window.$2 - window.$1;

  double widthOf(LessonItem lesson)
  {
    final start = lesson.startMinutes.clamp(window.$1, window.$2);
    final end = lesson.endMinutes.clamp(window.$1, window.$2);

    return track * (end - start) / minutes - 2 * kBlockGap;
  }

  return CalendarPdfTrackRow(
    name: _laneHead(data, styles, lane),
    blocks: [
      for (final lesson in lane.lessons)
        _block(data, styles, lesson, widthOf(lesson)),
    ],
    spans: [for (final lesson in lane.lessons) (lesson.startMinutes, lesson.endMinutes)],
    laneOf: subLanes.laneOf,
    laneCount: subLanes.laneCount,
    windowStart: window.$1,
    windowEnd: window.$2,
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
  final usable = width - kBlockChrome;
  final where = lessonWhere(lesson);
  final about = lessonAbout(lesson, data.ministrySubjects);

  return pw.Container(
    decoration: pw.BoxDecoration(
      color: pdfLessonSurface(lesson.mode),
      border: pw.Border.all(color: accent, width: 0.6),
      borderRadius: pw.BorderRadius.circular(2.5),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_hoursFor(data, lesson, usable), style: styles.blockHours(lesson.mode)),
        pw.Text(lessonTitle(lesson, view: data.view), style: styles.blockWho),
        pw.Text(about.subject, style: styles.blockSubject),
        if (data.isByStudent) pw.Text(where.label, style: styles.blockWhere(lesson.mode)),
      ],
    ),
  );
}

String _hoursFor(CalendarExportData data, LessonItem lesson, double usable)
{
  final online = !data.isByStudent && lesson.mode == kOnlineMode;
  final range = formatTimeRange(lesson.startTime, lesson.endTime);

  if (online && usable >= 78 * _typeScale)
  {
    return '$range · ${modeLabel(kOnlineMode)}';
  }

  if (usable >= 40 * _typeScale)
  {
    return range;
  }

  return formatTimeOfDayShort(lesson.startTime);
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
  if (lane.lessons.isEmpty)
  {
    return _cell(pw.Text('Nessuna lezione', style: styles.cellQuiet));
  }

  return _cell(pw.Table(
    columnWidths: _lessonColumnsFor(data),
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: kPdfLine, width: 0.4),
    ),
    children: [
      for (final lesson in lane.lessons) _lessonRow(data, styles, lesson),
    ],
  ));
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
