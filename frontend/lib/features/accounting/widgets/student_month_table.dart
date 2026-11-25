import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/search_terms.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_text_link.dart';
import '../../people/utils/payments_strings.dart' show kTariffKindLabels, tariffCost;
import '../models/student_month_items.dart';
import '../utils/accounting_strings.dart';
import 'hours_table_parts.dart' show HoursPart;
import 'summary_search.dart';
import 'teacher_month_table.dart' show PendingBandsNote;

const double _nameInset = 20;
const double _headRow = 28;

// One tariff's line: a split row is as many of these.
const double _partHeight = 52;

// A row's first two text lines need this much, a line under the situation too.
const double _lineGap = 2;

// Tariff and situation read from the left, off the group's rule.
const double _tariffInset = 14;
const double _situationInset = 16;

// The situation's mark, the gap after it, and a badge's room.
const double _markSize = 17;
const double _markGap = 6;
const double _badgeGap = 8;
const double _badgeSide = 8;

// Shares of the room left once every column shows its widest text whole:
// name; days three; hours three; tariff; situation.
const List<double> _shares = [190, 52, 80, 58, 76, 86, 72, 210, 230];

// Beyond this a name wraps on a second line.
const double _nameMost = 220;

// Room beside a column's widest text, and beside a group's title.
const double _cellSlack = 3;
const double _compactCellSlack = 1;
const double _titleSlack = 20;
const double _loneTitleSide = 12;

// Under a scrolling table, room for its bar.
const double _scrollBarRoom = 12;

Color get _headSurface => ThemeColours.of(0xFFF5F8F8);
Color get _rowLine => ThemeColours.of(0xFFEDF2F1);
Color get _partLine => ThemeColours.fixed(0xFFDDE3EA);
Color get _groupLine => ThemeColours.fixed(0xFFDDE3EA);
Color get _cellInk => ThemeColours.fixed(0xFF33495A);
Color get _dashInk => ThemeColours.fixed(0xFFA9B7BF);

const String _dash = '—';

class StudentMonthTable extends StatelessWidget
{
  final StudentMonth month;
  final ValueChanged<StudentMonthRow> onOpenStudent;
  final ValueChanged<PendingBand> onOpenBand;

  // Who is looked for by name.
  final ValueListenable<SearchTerms?>? search;

  const StudentMonthTable({
    super.key,
    required this.month,
    required this.onOpenStudent,
    required this.onOpenBand,
    this.search,
  });

  Widget _part(_Columns columns, _Part part)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(columns: columns, part: part, situation: _situationTitle(month)),
        for (final (index, row) in month.rows.indexed)
          _Row(
            row: row,
            month: month.month,
            columns: columns,
            part: part,
            first: index == 0,
            onOpen: onOpenStudent,
            search: search,
          ),
        _Totals(rows: month.rows, columns: columns, part: part),
        if (columns.scrolls) const SizedBox(height: _scrollBarRoom),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final _Columns columns = _Columns.fitting(context, month, constraints.maxWidth);

        // Too narrow even when compact: the names stay, the rest scrolls beside them.
        final Widget body = columns.scrolls
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: columns.name,
                    foregroundDecoration: BoxDecoration(border: Border(right: _groupSide)),
                    child: _part(columns, _Part.pinned),
                  ),
                  Expanded(
                    child: _SideScroll(
                      child: SizedBox(width: columns.width - columns.name, child: _part(columns, _Part.scrolled)),
                    ),
                  ),
                ],
              )
            : _part(columns, _Part.whole);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow,
          ),
          foregroundDecoration: AppTheme.cardEdge(24),
          child: _CellInset(
            inset: columns.inset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                if (month.pending.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(_nameInset, 13, _nameInset, 13),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: _rowLine))),
                    child: PendingBandsNote(pending: month.pending, onOpen: onOpenBand),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// "Situazione attuale" in the month under way, "Situazione al 31 ottobre" once it is past.
String _situationTitle(StudentMonth month)
{
  final DateTime? on = month.situationOn;

  return on == null ? kSituationNow : situationAt(on);
}

// What a row shows of its cells: all of them, or the name alone and the rest beside it.
typedef _Part = HoursPart;

Widget _cellsOf(List<Widget> cells, _Part part)
{
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (part)
    {
      _Part.whole => cells,
      _Part.pinned => [cells.first],
      _Part.scrolled => cells.sublist(1),
    },
  );
}

class _SideScroll extends StatefulWidget
{
  final Widget child;

  const _SideScroll({required this.child});

  @override
  State<_SideScroll> createState() => _SideScrollState();
}

class _SideScrollState extends State<_SideScroll>
{
  final ScrollController _controller = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}

// One step of the table's fit, from the roomiest down.
enum _Fit { wide, tight, compact }

// Type of one step: cells, column heads, the line under a tariff or a situation.
typedef _Type = ({double cell, double head, double small});

const _Type _wideType = (cell: 14.5, head: 12.5, small: 12.5);
const _Type _tightType = (cell: 14, head: 12, small: 12);
const _Type _compactType = (cell: 13, head: 11, small: 11.5);

_Type _typeOf(_Fit fit) => switch (fit)
{
  _Fit.wide => _wideType,
  _Fit.tight => _tightType,
  _Fit.compact => _compactType,
};

class _Columns
{
  final _Fit fit;

  // Name; days three; hours three; tariff; situation.
  final List<double> cells;

  // Even the compact table does not fit: the names stay, the rest scrolls.
  final bool scrolls;

  // No situation column once the month after has a day confirmed: its cell is zero wide and not drawn.
  final bool situation;

  const _Columns(this.fit, this.cells, {this.scrolls = false, this.situation = true});

  // Every column as wide as its widest text; whatever room is left, shared out. A table
  // that cannot fit even when compact keeps those widths and scrolls.
  static _Columns fitting(BuildContext context, StudentMonth month, double width)
  {
    _Columns? last;

    for (final fit in _Fit.values)
    {
      final _Columns columns = _Columns(fit, _needs(context, month, fit), situation: month.situationShown);
      final double room = width - columns.width;

      if (room >= 0)
      {
        return columns._spread(room);
      }

      last = columns;
    }

    return _Columns(last!.fit, last.cells, scrolls: true, situation: month.situationShown);
  }

  _Columns _spread(double room)
  {
    final List<double> shares = [..._shares.sublist(0, 8), situation ? _shares[8] : 0];
    final double total = shares.reduce((a, b) => a + b);

    return _Columns(
      fit,
      [for (final (index, cell) in cells.indexed) cell + room * shares[index] / total],
      situation: situation,
    );
  }

  _Type get type => _typeOf(fit);

  double get width => cells.fold(0.0, (sum, cell) => sum + cell);

  double get name => cells[0];

  double at(int index) => cells[index];

  // The parts' columns, between the name and the situation.
  double get parts => cells.sublist(1, 8).fold(0.0, (sum, cell) => sum + cell);

  double get cellFont => type.cell;

  double get headFont => type.head;

  double get smallFont => type.small;

  EdgeInsets get inset => EdgeInsets.symmetric(horizontal: fit == _Fit.wide ? 4 : 2);
}

double _widthOf(String text, TextStyle style, TextScaler scaler)
{
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();

  return painter.width;
}

String? _countOf(int value) => value == 0 ? null : '$value';

String? _minutesOf(int value) => value == 0 ? null : formatMinutes(value);

String _kindOf(TariffPart part) => kTariffKindLabels[part.tariffKind] ?? '';

String? _costOf(TariffPart part)
{
  final String? kind = part.tariffKind;
  final int? cents = part.amountCents;

  return kind == null || cents == null ? null : tariffCost(kind, cents, part.packageHours);
}

// Beside the kind, only where the row splits: "fino all'11", "dal 12".
String? _spanOf(StudentMonthRow row, TariffPart part, DateTime month)
{
  if (!row.split)
  {
    return null;
  }

  final String span = tariffSpan(month, part.startsOn, part.endsOn);

  return span.isEmpty ? null : span;
}

TextStyle _styled(BuildContext context, double size, FontWeight weight, {double? spacing}) =>
    DefaultTextStyle.of(context).style.merge(GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, letterSpacing: spacing));

// What each column needs to show its widest text whole, in the page's text style.
List<double> _needs(BuildContext context, StudentMonth month, _Fit fit)
{
  final _Type type = _typeOf(fit);
  final TextScaler scaler = MediaQuery.textScalerOf(context);

  final TextStyle strong = _styled(context, type.cell, FontWeight.w700);
  final TextStyle plain = _styled(context, type.cell, FontWeight.w500);
  final TextStyle head = _styled(context, type.head, FontWeight.w600);
  final TextStyle small = _styled(context, type.small, FontWeight.w600);
  final TextStyle kind = _styled(context, type.cell, FontWeight.w700);
  final TextStyle situation = _styled(context, type.cell - 0.5, FontWeight.w700);
  final TextStyle badge = _styled(context, 11, FontWeight.w700);
  final TextStyle title = DefaultTextStyle.of(context).style.merge(_groupStyle);

  final double side = 2 * (fit == _Fit.wide ? 4 : 2) + (fit == _Fit.compact ? _compactCellSlack : _cellSlack);
  final List<double> cells = List.filled(9, 0);

  void need(int index, String? text, TextStyle style, {double extra = 0})
  {
    cells[index] = math.max(cells[index], _widthOf(text ?? _dash, style, scaler) + side + extra);
  }

  var name = _widthOf(kStudentColumn, head, scaler);

  for (final row in month.rows)
  {
    name = math.max(name, _widthOf(row.fullName, strong, scaler));
  }

  cells[0] = math.min(name, _nameMost) + _nameInset + 8 + 2;

  final List<String> heads = [
    kTotalColumn, kPresenceColumn, kOnlineColumn,
    kTotalColumn, kPresenceColumn, kOnlineColumn,
  ];

  for (final (index, label) in heads.indexed)
  {
    need(index + 1, label, head);
  }

  // The tariff's title stands alone over its column.
  cells[7] = _widthOf(kTariffColumn.toUpperCase(), title, scaler) + 2 * _loneTitleSide + 4;

  var minutes = 0;
  var presence = 0;
  var online = 0;

  for (final row in month.rows)
  {
    for (final part in row.parts)
    {
      need(1, _countOf(part.days), strong);
      need(2, _countOf(part.presenceDays), plain);
      need(3, _countOf(part.onlineDays), plain);
      need(4, _minutesOf(part.minutes), strong);
      need(5, _minutesOf(part.presenceMinutes), plain);
      need(6, _minutesOf(part.onlineMinutes), plain);

      final String? span = _spanOf(row, part, month.month);
      final double spanWidth = span == null ? 0 : 6 + _widthOf(span, small, scaler);

      need(7, _kindOf(part), kind, extra: _tariffInset + spanWidth);
      need(7, _costOf(part), small, extra: _tariffInset);

      minutes += part.minutes;
      presence += part.presenceMinutes;
      online += part.onlineMinutes;
    }

    final StandingWords? said = month.situationShown ? row.situation?.wordsIn(month.month) : null;

    if (said != null)
    {
      final String? chip = said.badge;
      final double chipWidth = chip == null ? 0 : _badgeGap + 2 * _badgeSide + _widthOf(chip, badge, scaler);

      need(8, said.text, situation, extra: _situationInset + _markSize + _markGap + chipWidth);

      if (said.below case final String below)
      {
        need(8, below, small, extra: _situationInset + _markSize + _markGap);
      }
    }
  }

  need(4, formatMinutes(minutes), strong);
  need(5, formatMinutes(presence), strong);
  need(6, formatMinutes(online), strong);

  // The situation's title stands on two lines: its longer word decides.
  final String heading = _situationTitle(month).toUpperCase();
  final List<String> words = heading.split(' ');
  final int half = (words.length / 2).ceil();

  for (final line in [words.sublist(0, half).join(' '), words.sublist(half).join(' ')])
  {
    if (month.situationShown)
    {
      cells[8] = math.max(cells[8], _widthOf(line, title, scaler) + 2 * _loneTitleSide + 4);
    }
  }

  // A group's columns leave room for its title.
  void titled(String text, int from, int to)
  {
    final double short = _widthOf(text.toUpperCase(), title, scaler) + _titleSlack -
        cells.sublist(from, to + 1).fold(0.0, (sum, cell) => sum + cell);

    if (short > 0)
    {
      for (var index = from; index <= to; index++)
      {
        cells[index] += short / (to - from + 1);
      }
    }
  }

  titled(kDaysGroup, 1, 3);
  titled(kHoursGroup, 4, 6);

  return cells;
}

TextStyle _cellStyle(_Columns c, {bool strong = false, Color? color}) => GoogleFonts.plusJakartaSans(
  fontSize: c.cellFont,
  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
  color: color ?? (strong ? AppTheme.trialOceanText : _cellInk),
);

TextStyle _headStyle(_Columns c) => GoogleFonts.plusJakartaSans(
  fontSize: c.headFont,
  fontWeight: FontWeight.w600,
  color: AppTheme.trialMutedText,
);

TextStyle _smallStyle(_Columns c) => GoogleFonts.plusJakartaSans(
  fontSize: c.smallFont,
  fontWeight: FontWeight.w600,
  color: AppTheme.trialMutedText,
);

TextStyle get _groupStyle => GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  height: 1.35,
  color: AppTheme.trialMutedText,
);

BorderSide get _groupSide => BorderSide(color: _groupLine, width: 1.5);

// A cell: its width, and a rule on its left when it opens a group.
class _Cell extends StatelessWidget
{
  final double width;
  final Widget child;
  final bool opensGroup;
  final Alignment alignment;
  final EdgeInsets? padding;

  const _Cell({
    required this.width,
    required this.child,
    this.opensGroup = false,
    this.alignment = Alignment.center,
    this.padding,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: width,
      alignment: alignment,
      padding: padding ?? _CellInset.of(context),
      decoration: opensGroup ? BoxDecoration(border: Border(left: _groupSide)) : null,
      child: child,
    );
  }
}

// A figure that shrinks rather than spill out, should a column ever be short.
Widget _figure(String text, TextStyle style)
{
  return FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: style));
}

Widget _value(_Columns c, String? text, {bool strong = false})
{
  if (text == null)
  {
    return _figure(_dash, _cellStyle(c, color: _dashInk));
  }

  return _figure(text, _cellStyle(c, strong: strong));
}

// The cells' side room, set once for the table.
class _CellInset extends InheritedWidget
{
  final EdgeInsets inset;

  const _CellInset({required this.inset, required super.child});

  static EdgeInsets of(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_CellInset>()?.inset ?? const EdgeInsets.symmetric(horizontal: 4);
  }

  @override
  bool updateShouldNotify(_CellInset oldWidget) => inset != oldWidget.inset;
}

class _Head extends StatelessWidget
{
  final _Columns columns;
  final _Part part;
  final String situation;

  const _Head({required this.columns, required this.part, required this.situation});

  // A group's title over its columns, with the rule on its left reaching the whole head;
  // a scrolling table's first group leans on the names' rule instead.
  Widget _group(String title, List<(String, int)> heads, {bool opens = true})
  {
    final double width = heads.fold(0, (sum, head) => sum + columns.at(head.$2));

    return Container(
      width: width,
      decoration: opens ? BoxDecoration(border: Border(left: _groupSide)) : null,
      child: Column(
        children: [
          Container(
            height: _headRow,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 6),
            child: Text(title.toUpperCase(), maxLines: 1, style: _groupStyle),
          ),
          SizedBox(
            height: _headRow,
            child: Row(
              children: [
                for (final (label, index) in heads)
                  _Cell(
                    width: columns.at(index) - (opens && index == heads.first.$2 ? 1.5 : 0),
                    child: _figure(label, _headStyle(columns)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> cells = [
      _Cell(
        width: columns.name,
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.only(left: _nameInset, bottom: 7),
        child: Text(kStudentColumn, maxLines: 1, style: _headStyle(columns)),
      ),
      _group(kDaysGroup, [(kTotalColumn, 1), (kPresenceColumn, 2), (kOnlineColumn, 3)], opens: !columns.scrolls),
      _group(kHoursGroup, [(kTotalColumn, 4), (kPresenceColumn, 5), (kOnlineColumn, 6)]),
      _Cell(
        width: columns.at(7),
        opensGroup: true,
        padding: const EdgeInsets.symmetric(horizontal: _loneTitleSide),
        child: Text(kTariffColumn.toUpperCase(), maxLines: 1, textAlign: TextAlign.center, style: _groupStyle),
      ),
      if (columns.situation)
        _Cell(
          width: columns.at(8),
          opensGroup: true,
          padding: const EdgeInsets.symmetric(horizontal: _loneTitleSide),
          child: Text(situation.toUpperCase(), maxLines: 2, textAlign: TextAlign.center, style: _groupStyle),
        ),
    ];

    // And the rule under it.
    return Container(
      height: 2 * _headRow + 1,
      decoration: BoxDecoration(
        color: _headSurface,
        border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
      ),
      child: _cellsOf(cells, part),
    );
  }
}

// «Pacchetto» over «€ 260,00 per 20 ore»; in a split row, «dal 12» beside the kind.
class _Tariff extends StatelessWidget
{
  final _Columns columns;
  final TariffPart part;
  final String? span;

  const _Tariff({required this.columns, required this.part, required this.span});

  @override
  Widget build(BuildContext context)
  {
    final String? cost = _costOf(part);

    if (cost == null)
    {
      return _value(columns, null);
    }

    final TextStyle small = _smallStyle(columns);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _kindOf(part),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: columns.cellFont,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialOceanText,
                ),
              ),
              if (span != null) TextSpan(text: '  $span', style: small),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: _lineGap),
        Text(cost, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
      ],
    );
  }
}

// Teal when in order, gold when something is to pay or renew.
class _Situation extends StatelessWidget
{
  final _Columns columns;
  final StudentStanding situation;

  // The summary's month, whose fee a monthly tariff speaks of.
  final DateTime month;

  const _Situation({required this.columns, required this.situation, required this.month});

  @override
  Widget build(BuildContext context)
  {
    final StandingWords? said = situation.wordsIn(month);

    if (said == null)
    {
      return _value(columns, null);
    }

    final bool due = said.due;
    final String? below = said.below;
    final String? badge = said.badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              due ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              size: _markSize,
              color: due ? AppTheme.trialGold : AppTheme.trialTurquoise,
            ),
            const SizedBox(width: _markGap),
            Flexible(
              child: Text(
                said.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: columns.cellFont - 0.5,
                  fontWeight: FontWeight.w700,
                  color: due ? AppTheme.modifiedAccent : AppTheme.trialOceanText,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: _badgeGap),
              _Badge(text: badge, ahead: said.ahead),
            ],
          ],
        ),
        if (below != null)
          Padding(
            padding: const EdgeInsets.only(left: _markSize + _markGap, top: _lineGap),
            child: Text(below, maxLines: 1, overflow: TextOverflow.ellipsis, style: _smallStyle(columns)),
          ),
      ],
    );
  }
}

// «Rinnovo» in blue, «Anticipo» in teal, as in the daily summary.
class _Badge extends StatelessWidget
{
  final String text;
  final bool ahead;

  const _Badge({required this.text, required this.ahead});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _badgeSide, vertical: 1.5),
      decoration: BoxDecoration(
        color: ahead ? AppTheme.paidSurface : AppTheme.laterBlueSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ahead ? AppTheme.trialTealDeepText : AppTheme.laterBlueText,
        ),
      ),
    );
  }
}

// The line between two tariffs of a split row.
class _PartRule extends CustomPainter
{
  const _PartRule();

  @override
  void paint(Canvas canvas, Size size)
  {
    final Paint paint = Paint()
      ..color = _partLine
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 7)
    {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + 4, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_PartRule oldDelegate) => false;
}

class _Row extends StatelessWidget
{
  final StudentMonthRow row;
  final DateTime month;
  final _Columns columns;
  final _Part part;
  final bool first;
  final ValueChanged<StudentMonthRow> onOpen;
  final ValueListenable<SearchTerms?>? search;

  const _Row({
    required this.row,
    required this.month,
    required this.columns,
    required this.part,
    required this.first,
    required this.onOpen,
    required this.search,
  });

  Widget _line(TariffPart tariff, {required bool firstPart})
  {
    final _Columns c = columns;

    final Widget cells = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cell(width: c.at(1), opensGroup: !c.scrolls, child: _value(c, _countOf(tariff.days), strong: true)),
        _Cell(width: c.at(2), child: _value(c, _countOf(tariff.presenceDays))),
        _Cell(width: c.at(3), child: _value(c, _countOf(tariff.onlineDays))),
        _Cell(width: c.at(4), opensGroup: true, child: _value(c, _minutesOf(tariff.minutes), strong: true)),
        _Cell(width: c.at(5), child: _value(c, _minutesOf(tariff.presenceMinutes))),
        _Cell(width: c.at(6), child: _value(c, _minutesOf(tariff.onlineMinutes))),
        _Cell(
          width: c.at(7),
          opensGroup: true,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: _tariffInset, right: 4),
          child: _Tariff(columns: c, part: tariff, span: _spanOf(row, tariff, month)),
        ),
      ],
    );

    return SizedBox(
      height: _partHeight,
      child: firstPart ? cells : CustomPaint(foregroundPainter: const _PartRule(), child: cells),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    final List<Widget> cells = [
      _Cell(
        width: c.name,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: _nameInset, right: 8),
        child: AppTextLink(
          text: row.fullName,
          style: GoogleFonts.plusJakartaSans(fontSize: c.cellFont, fontWeight: FontWeight.w700, color: AppTheme.trialOceanText),
          onTap: () => onOpen(row),
        ),
      ),
      SizedBox(
        width: c.parts,
        child: Column(
          children: [
            for (final (index, tariff) in row.parts.indexed) _line(tariff, firstPart: index == 0),
          ],
        ),
      ),
      if (row.situation case final StudentStanding standing when c.situation)
        _Cell(
          width: c.at(8),
          opensGroup: true,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: _situationInset, right: 6),
          child: _Situation(columns: c, situation: standing, month: month),
        ),
    ];

    return SummarySearchRow(
      search: search,
      name: row.fullName,
      part: part,
      child: Container(
        height: _partHeight * row.parts.length + (first ? 0 : 1),
        decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: _rowLine))),
        child: _cellsOf(cells, part),
      ),
    );
  }
}

class _Totals extends StatelessWidget
{
  final List<StudentMonthRow> rows;
  final _Columns columns;
  final _Part part;

  const _Totals({required this.rows, required this.columns, required this.part});

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    var minutes = 0;
    var presence = 0;
    var online = 0;

    for (final row in rows)
    {
      for (final tariff in row.parts)
      {
        minutes += tariff.minutes;
        presence += tariff.presenceMinutes;
        online += tariff.onlineMinutes;
      }
    }

    const Widget none = SizedBox.shrink();

    final List<Widget> cells = [
      _Cell(
        width: c.name,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: _nameInset),
        child: Text(kTotalRow.toUpperCase(), style: _groupStyle.copyWith(fontSize: 12)),
      ),
      _Cell(width: c.at(1), opensGroup: !c.scrolls, child: none),
      SizedBox(width: c.at(2)),
      SizedBox(width: c.at(3)),
      _Cell(width: c.at(4), opensGroup: true, child: _value(c, _minutesOf(minutes), strong: true)),
      _Cell(width: c.at(5), child: _value(c, _minutesOf(presence), strong: true)),
      _Cell(width: c.at(6), child: _value(c, _minutesOf(online), strong: true)),
      _Cell(width: c.at(7), opensGroup: true, child: none),
      if (c.situation) _Cell(width: c.at(8), opensGroup: true, child: none),
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _headSurface,
        border: Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: _cellsOf(cells, part),
    );
  }
}
