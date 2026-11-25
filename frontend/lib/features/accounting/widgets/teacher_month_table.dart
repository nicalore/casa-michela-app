import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/search_terms.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_text_link.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/page_density.dart';
import '../models/teacher_month_items.dart';
import '../utils/accounting_strings.dart';
import 'receipt_cell.dart';
import '../utils/opening_strings.dart' show kOpeningPending;
import 'hours_table_parts.dart' show HoursPart;
import 'opening_pending_pill.dart';
import 'summary_search.dart';

const double _nameInset = 20;
const double _rowHeight = 50;
const double _headRow = 28;
// Three labels in the switch: less room beside each, and less again in a tight table.
const double _ruleFont = 12.5;
const double _tightRuleFont = 12;
const double _ruleSegmentPadding = 10;
const double _tightRuleSegmentPadding = 7;
const double _ruleInset = 10;
const double _tightRuleInset = 6;

// The button that saves a new rule: its room is kept, so the switch never moves.
const double _confirmWidth = 42;
const double _confirmHeight = 34;
const double _confirmGap = 8;
const Duration _confirmFade = Duration(milliseconds: 160);

// The rule as a menu, when the table has no room for the switch.
const double _menuHeight = 34;

// Shares of the room left once every column shows its widest text whole:
// name; days; hours; money and the receipt; availability.
const List<double> _shares = [190, 58, 80, 58, 94, 104, 94, 112, 102, 106, 70, 84, 108];

// Beyond this a name wraps on a second line.
const double _nameMost = 220;

// Room beside a column's widest text, and beside a group's title.
const double _cellSlack = 3;
const double _compactCellSlack = 1;
const double _titleSlack = 20;

// A title alone across the head: the rule's has 12 a side, availability's 4.
const double _loneTitleSide = 12;
const double _availabilityTitleSide = 4;

// Totals change with a rule picked and not saved: a little room for that.
const double _totalSlack = 2;

// A warning: its icon and the gap before the words.
const double _warningIcon = 17;
const double _warningGap = 4;

// Under a scrolling table, room for its bar.
const double _scrollBarRoom = 12;

// More than this many bands and the last ones are only counted.
const int kNamedPendingBands = 4;

Color get _headSurface => ThemeColours.of(0xFFF5F8F8);
Color get _rowLine => ThemeColours.of(0xFFEDF2F1);
Color get _groupLine => ThemeColours.fixed(0xFFDDE3EA);
Color get _cellInk => ThemeColours.fixed(0xFF33495A);
Color get _dashInk => ThemeColours.fixed(0xFFA9B7BF);

// A row with a file dragged over it, and the label that says whose it will be.
Color get _dropSurface => ThemeColours.of(0xFFEAF6F5);
const double _dropRim = 2;
const Duration _dropFade = Duration(milliseconds: 150);

const String _dash = '—';

class TeacherMonthTable extends StatelessWidget
{
  final TeacherMonth month;

  // Rules chosen and not saved yet, by tax code; the one being saved.
  final Map<String, VolunteeringRule> chosen;
  final String? saving;

  final void Function(TeacherMonthRow row, VolunteeringRule rule) onRule;
  final ValueChanged<TeacherMonthRow> onConfirmRule;
  final ValueChanged<TeacherMonthRow> onOpenTeacher;
  final ValueChanged<PendingBand> onOpenBand;

  // Receipts on their way, by tax code; the row a file is dragged over.
  final Set<String> receiptBusy;
  final String? dropOver;

  final ValueChanged<TeacherMonthRow> onUploadReceipt;
  final ValueChanged<TeacherMonthRow> onOpenReceipt;
  final ValueChanged<TeacherMonthRow> onDeleteReceipt;
  final void Function(TeacherMonthRow row, DropItem file) onDropReceipt;
  final void Function(TeacherMonthRow row, bool over) onDragReceipt;

  // Who is looked for by name.
  final ValueListenable<SearchTerms?>? search;

  const TeacherMonthTable({
    super.key,
    required this.month,
    required this.chosen,
    required this.saving,
    required this.onRule,
    required this.onConfirmRule,
    required this.onOpenTeacher,
    required this.onOpenBand,
    required this.receiptBusy,
    required this.dropOver,
    required this.onUploadReceipt,
    required this.onOpenReceipt,
    required this.onDeleteReceipt,
    required this.onDropReceipt,
    required this.onDragReceipt,
    this.search,
  });

  Widget _part(_Columns columns, _Part part)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(columns: columns, part: part),
        for (final (index, row) in month.rows.indexed)
          _Row(
            row: row,
            columns: columns,
            part: part,
            first: index == 0,
            chosen: chosen[row.taxCode],
            saving: saving == row.taxCode,
            locked: saving != null,
            onRule: onRule,
            onConfirm: onConfirmRule,
            onOpen: onOpenTeacher,
            month: month.month,
            receiptBusy: receiptBusy.contains(row.taxCode),
            dropLit: dropOver == row.taxCode,
            onUploadReceipt: onUploadReceipt,
            onOpenReceipt: onOpenReceipt,
            onDeleteReceipt: onDeleteReceipt,
            onDropReceipt: onDropReceipt,
            onDragReceipt: onDragReceipt,
            search: search,
          ),
        _Totals(rows: month.rows, chosen: chosen, columns: columns, part: part),
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
        final _Columns columns = _Columns.fitting(context, month.rows, constraints.maxWidth);

        // Too narrow even with the menu: the names stay, the rest scrolls beside them.
        final Widget body = columns.scrolls
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The rule is drawn over the names' edge: it takes none of their room.
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

        final String? over = dropOver;
        final TeacherMonthRow? target = over == null
            ? null
            : month.rows.where((row) => row.taxCode == over).firstOrNull;

        final Widget card = Container(
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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: target == null ? 0 : 1,
                    duration: _dropFade,
                    child: _DropLabel(name: target?.fullName ?? ''),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Over the table while a file is dragged on a row: whose receipt it will be.
class _DropLabel extends StatelessWidget
{
  final String name;

  const _DropLabel({required this.name});

  @override
  Widget build(BuildContext context)
  {
    final TextStyle plain = GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.tooltipSurface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upload_file_rounded, size: 19, color: Colors.white),
          const SizedBox(width: 8),
          Text(dropReceiptFor(name), style: plain),
        ],
      ),
    );
  }
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
enum _Fit
{
  // The switch, type at its size.
  wide,
  // The switch, type a step down.
  tight,
  // The rule a menu, availability one column.
  compact,
}

// Type of one step: cells, column heads, warnings.
typedef _Type = ({double cell, double head, double warning});

const _Type _wideType = (cell: 14.5, head: 12.5, warning: 13.5);
const _Type _tightType = (cell: 14, head: 12, warning: 13);
// Compact, the receipt's column must fit beside the rest in the window with the rail.
const _Type _compactType = (cell: 13, head: 11, warning: 12);

_Type _typeOf(_Fit fit) => switch (fit)
{
  _Fit.wide => _wideType,
  _Fit.tight => _tightType,
  _Fit.compact => _compactType,
};

class _Columns
{
  final _Fit fit;

  // The switch's width, or the menu's.
  final double ruleControl;

  // Name; days and hours three each; money three and the receipt; availability two,
  // or one when compact.
  final List<double> cells;

  // Even the compact table does not fit: the names stay, the rest scrolls.
  final bool scrolls;

  const _Columns(this.fit, this.ruleControl, this.cells, {this.scrolls = false});

  // Every column as wide as its widest text; whatever room is left, shared out. A table
  // that cannot fit even when compact keeps those widths and scrolls.
  static _Columns fitting(BuildContext context, List<TeacherMonthRow> rows, double width)
  {
    _Columns? last;

    for (final fit in _Fit.values)
    {
      final _Columns columns = _Columns(fit, _ruleControl(context, fit), _needs(context, rows, fit));
      final double room = width - columns.width;

      if (room >= 0)
      {
        return columns._spread(room);
      }

      last = columns;
    }

    return _Columns(last!.fit, last.ruleControl, last.cells, scrolls: true);
  }

  _Columns _spread(double room)
  {
    final List<double> shares = compact
        ? [..._shares.sublist(0, 11), _shares[11] + _shares[12]]
        : _shares;
    final double total = shares.reduce((a, b) => a + b);

    return _Columns(fit, ruleControl, [
      for (final (index, cell) in cells.indexed) cell + room * shares[index] / total,
    ]);
  }

  bool get compact => fit == _Fit.compact;

  bool get tight => fit != _Fit.wide;

  _Type get type => _typeOf(fit);

  double get rule => ruleControl + _confirmGap + _confirmWidth + 2 * ruleInset;

  // The table's own width, more than it is given when it scrolls.
  double get width => cells.fold(0.0, (sum, cell) => sum + cell) + rule;

  double get ruleInset => tight ? _tightRuleInset : _ruleInset;

  double get ruleFont => tight ? _tightRuleFont : _ruleFont;

  double get ruleSegmentPadding => tight ? _tightRuleSegmentPadding : _ruleSegmentPadding;

  double get name => cells[0];

  double at(int index) => cells[index];

  double get cellFont => type.cell;

  double get headFont => type.head;

  double get warningFont => type.warning;

  EdgeInsets get inset => EdgeInsets.symmetric(horizontal: tight ? 2 : 4);
}

final List<String> _ruleLabels = [for (final rule in VolunteeringRule.values) kMonthRuleNames[rule]!];

// The menu is set as on a dense page, the size AppDropdownField takes there.
const double _menuFont = 13.5;

double _ruleControl(BuildContext context, _Fit fit)
{
  final TextScaler scaler = MediaQuery.textScalerOf(context);

  if (fit != _Fit.compact)
  {
    return AppSegmentedTabs.widthOf(
      _ruleLabels,
      fontSize: fit == _Fit.wide ? _ruleFont : _tightRuleFont,
      scaler: scaler,
      segmentPadding: fit == _Fit.wide ? _ruleSegmentPadding : _tightRuleSegmentPadding,
    );
  }

  final TextStyle style = DefaultTextStyle.of(context).style.merge(
    GoogleFonts.plusJakartaSans(fontSize: _menuFont, fontWeight: FontWeight.w600),
  );

  // Its text, its side room and the arrow, as AppDropdownField lays them out.
  return _ruleLabels.map((label) => _widthOf(label, style, scaler)).reduce(math.max) + 12 + 6 + 20 + 8;
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

String? _minutesOf(int? value) => value == null || value == 0 ? null : formatMinutes(value);

String? _amountOf(int? cents) => cents == null ? null : formatAmount(cents);

List<String> _warningsOf(TeacherMonthRow row) => [
      if (row.belowMonthly) availabilityShort(row.availabilities),
      if (row.shortWeeks > 0) shortWeeks(row.shortWeeks),
    ];

// What each column needs to show its widest text whole, in the page's text style
// (whose letter spacing every text takes too).
List<double> _needs(BuildContext context, List<TeacherMonthRow> rows, _Fit fit)
{
  final _Type type = _typeOf(fit);
  final TextScaler scaler = MediaQuery.textScalerOf(context);
  final TextStyle base = DefaultTextStyle.of(context).style;

  TextStyle styled(double size, FontWeight weight, {double? spacing}) =>
      base.merge(GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, letterSpacing: spacing));

  final TextStyle strong = styled(type.cell, FontWeight.w700);
  final TextStyle plain = styled(type.cell, FontWeight.w500);
  final TextStyle head = styled(type.head, FontWeight.w600);
  final TextStyle warning = styled(type.warning, FontWeight.w600);
  final TextStyle title = base.merge(_groupStyle);

  final double side = 2 * (fit == _Fit.wide ? 4 : 2) + (fit == _Fit.compact ? _compactCellSlack : _cellSlack);
  final List<double> cells = List.filled(fit == _Fit.compact ? 12 : 13, 0);

  void need(int index, String? text, TextStyle style, {double extra = 0})
  {
    cells[index] = math.max(cells[index], _widthOf(text ?? _dash, style, scaler) + side + extra);
  }

  double warned(String text) => _warningIcon + _warningGap + _widthOf(text, warning, scaler);

  // A name past the most wraps; its inset, the room on its right and the group rule.
  var name = _widthOf(kTeacherColumn, head, scaler);

  for (final row in rows)
  {
    name = math.max(name, _widthOf(row.fullName, strong, scaler));

    // The pill under the name: its icon, gap and padding around the words.
    if (row.openingPending)
    {
      name = math.max(name, _widthOf(kOpeningPending, strong, scaler) + strong.fontSize! * 2.6);
    }
  }

  cells[0] = math.min(name, _nameMost) + _nameInset + 8 + 2;

  final List<String> heads = [
    kTotalColumn, kPresenceColumn, kOnlineColumn,
    kTotalColumn, kVolunteerColumn, kPaidColumn,
    kGrossColumn, kWithholdingColumn, kNetColumn, kReceiptColumn,
  ];

  for (final (index, label) in heads.indexed)
  {
    need(index + 1, label, head);
  }

  var worked = 0;
  var gross = 0;
  var net = 0;

  // The receipt's button, and the count of receipts under it.
  cells[10] = math.max(cells[10], kReceiptButtonWidth + side);
  need(10, receiptsCount(rows.length, rows.length), strong, extra: _totalSlack);

  for (final row in rows)
  {
    need(1, _countOf(row.days), strong);
    need(2, _countOf(row.presenceDays), plain);
    need(3, _countOf(row.onlineDays), plain);
    need(4, _minutesOf(row.workedMinutes), strong);

    // Every rule's figures: picking one never widens a column.
    final List<RuleFigures> figures = [
      RuleFigures(volunteerMinutes: row.volunteerMinutes, paidMinutes: row.paidMinutes ?? 0, gross: row.gross, net: row.net),
      ...?row.ruleFigures?.values,
    ];

    for (final figure in figures)
    {
      need(5, _minutesOf(figure.volunteerMinutes), strong);
      need(6, _minutesOf(figure.paidMinutes), strong);
      need(7, _amountOf(figure.gross), strong);
      need(8, _amountOf(withholdingOf(figure.gross, figure.net)), plain);
      need(9, _amountOf(figure.net), plain);
    }

    worked += row.workedMinutes;
    gross += row.gross ?? 0;
    net += row.net ?? 0;
  }

  // The totals, with room for what a rule picked and not saved adds.
  need(4, formatMinutes(worked), strong, extra: _totalSlack);
  need(5, formatMinutes(worked), strong, extra: _totalSlack);
  need(6, formatMinutes(worked), strong, extra: _totalSlack);
  need(7, formatAmount(gross), strong, extra: _totalSlack);
  need(8, formatAmount(gross - net), strong, extra: _totalSlack);
  need(9, formatAmount(net), strong, extra: _totalSlack);

  final List<String> month = [for (final row in rows) if (row.belowMonthly) availabilityShort(row.availabilities)];
  final List<String> week = [for (final row in rows) if (row.shortWeeks > 0) shortWeeks(row.shortWeeks)];

  if (fit == _Fit.compact)
  {
    // One column: its title on its own, the two warnings one under the other.
    cells[11] = [
      _widthOf(kAvailabilityGroup.toUpperCase(), title, scaler) + 2 * _availabilityTitleSide + 6,
      for (final text in [...month, ...week]) warned(text) + side,
    ].reduce(math.max);
  }
  else
  {
    cells[11] = math.max(_widthOf(kMonthColumn, head, scaler) + side, month.map((text) => warned(text) + side).fold(0, math.max));
    cells[12] = math.max(_widthOf(kWeekColumn, head, scaler) + side, week.map((text) => warned(text) + side).fold(0, math.max));
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
  titled(kPayGroup, 7, 10);

  if (fit != _Fit.compact)
  {
    titled(kAvailabilityGroup, 11, 12);
  }

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

  const _Head({required this.columns, required this.part});

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

  // A column whose title stands alone across the head.
  Widget _single(String title, double width, {double side = _loneTitleSide})
  {
    return _Cell(
      width: width,
      opensGroup: true,
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Text(title.toUpperCase(), maxLines: 2, textAlign: TextAlign.center, style: _groupStyle),
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
        child: Text(kTeacherColumn, maxLines: 1, style: _headStyle(columns)),
      ),
      _group(kDaysGroup, [(kTotalColumn, 1), (kPresenceColumn, 2), (kOnlineColumn, 3)], opens: !columns.scrolls),
      _group(kHoursGroup, [(kTotalColumn, 4), (kVolunteerColumn, 5), (kPaidColumn, 6)]),
      _group(kPayGroup, [(kGrossColumn, 7), (kWithholdingColumn, 8), (kNetColumn, 9), (kReceiptColumn, 10)]),
      if (columns.compact)
        _single(kAvailabilityGroup, columns.at(11), side: _availabilityTitleSide)
      else
        _group(kAvailabilityGroup, [(kMonthColumn, 11), (kWeekColumn, 12)]),
      _single(kRuleColumn, columns.rule),
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

class _Warning extends StatelessWidget
{
  final String text;
  final double size;

  const _Warning({required this.text, required this.size});

  @override
  Widget build(BuildContext context)
  {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: _warningIcon, color: AppTheme.modifiedAccent),
          const SizedBox(width: _warningGap),
          Text(
            text,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: FontWeight.w600, color: AppTheme.modifiedAccent),
          ),
        ],
      ),
    );
  }
}

Widget get _reached => Icon(Icons.check_rounded, size: 18, color: AppTheme.trialTurquoise);

class _Row extends StatelessWidget
{
  final TeacherMonthRow row;
  final _Columns columns;
  final _Part part;
  final bool first;

  // The rule picked and not saved yet; null while it is the saved one.
  final VolunteeringRule? chosen;
  final bool saving;

  // Another row's rule being saved: no new choice meanwhile.
  final bool locked;

  final void Function(TeacherMonthRow row, VolunteeringRule rule) onRule;
  final DateTime month;
  final ValueChanged<TeacherMonthRow> onConfirm;
  final ValueChanged<TeacherMonthRow> onOpen;

  final bool receiptBusy;
  final bool dropLit;
  final ValueChanged<TeacherMonthRow> onUploadReceipt;
  final ValueChanged<TeacherMonthRow> onOpenReceipt;
  final ValueChanged<TeacherMonthRow> onDeleteReceipt;
  final void Function(TeacherMonthRow row, DropItem file) onDropReceipt;
  final void Function(TeacherMonthRow row, bool over) onDragReceipt;
  final ValueListenable<SearchTerms?>? search;

  const _Row({
    required this.row,
    required this.columns,
    required this.part,
    required this.first,
    required this.chosen,
    required this.saving,
    required this.locked,
    required this.onRule,
    required this.onConfirm,
    required this.onOpen,
    required this.month,
    required this.receiptBusy,
    required this.dropLit,
    required this.onUploadReceipt,
    required this.onOpenReceipt,
    required this.onDeleteReceipt,
    required this.onDropReceipt,
    required this.onDragReceipt,
    required this.search,
  });

  // A paid month takes a receipt; one left from before stays reachable to remove.
  bool get _takesReceipt => row.isPaid || row.receipt != null;

  Widget _receipt()
  {
    if (!_takesReceipt)
    {
      return _value(columns, null);
    }

    return ReceiptCell(
      key: ValueKey('receipt-${row.taxCode}'),
      receipt: row.receipt,
      busy: receiptBusy,
      onUpload: () => onUploadReceipt(row),
      onOpen: () => onOpenReceipt(row),
      onDelete: () => onDeleteReceipt(row),
    );
  }

  void _pick(VolunteeringRule? rule, VolunteeringRule shown)
  {
    if (rule != null && !locked && rule != shown)
    {
      onRule(row, rule);
    }
  }

  Widget _control(BuildContext context, VolunteeringRule shown)
  {
    if (columns.compact)
    {
      return SizedBox(
        width: columns.ruleControl,
        child: AppPageDensity(
          dense: true,
          child: AppDropdownField<VolunteeringRule>(
            hint: kMonthRuleNames[shown]!,
            value: shown,
            height: _menuHeight,
            options: [
              for (final rule in VolunteeringRule.values) AppDropdownOption(value: rule, label: kMonthRuleNames[rule]!),
            ],
            onChanged: (rule) => _pick(rule, shown),
          ),
        ),
      );
    }

    return SizedBox(
      width: columns.ruleControl,
      child: AppSegmentedTabs(
        labels: _ruleLabels,
        selectedIndex: shown.index,
        onSelected: (index) => _pick(VolunteeringRule.values[index], shown),
        height: 32,
        fontSize: columns.ruleFont,
        padding: EdgeInsets.zero,
        hugContent: true,
        segmentPadding: columns.ruleSegmentPadding,
      ),
    );
  }

  Widget _rule(BuildContext context)
  {
    if (!row.isPaid)
    {
      return _value(columns, null);
    }

    final VolunteeringRule shown = chosen ?? row.volunteering;
    final Widget control = _control(context, shown);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chosen for this month alone: the tooltip says what the Compensi say.
        if (row.monthOnly)
          AppTooltip(message: monthOnlyRuleTooltip(month, row.standingVolunteering), child: control)
        else
          control,
        const SizedBox(width: _confirmGap),
        _ConfirmRule(
          key: ValueKey('confirm-rule-${row.taxCode}'),
          shown: chosen != null,
          saving: saving,
          onTap: () => onConfirm(row),
        ),
      ],
    );
  }

  // Compact, both checks share a column: a tick when all is well, else each warning.
  Widget _availability()
  {
    final List<String> warnings = _warningsOf(row);

    if (warnings.isEmpty)
    {
      return _reached;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, text) in warnings.indexed) ...[
          if (index > 0) const SizedBox(height: 3),
          _Warning(text: text, size: columns.warningFont),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    // A rule picked and not saved: its pay shows at once, before the tick saves it.
    final VolunteeringRule? picked = chosen;
    final RuleFigures? preview = picked == null ? null : row.figuresFor(picked);

    final int volunteer = preview?.volunteerMinutes ?? row.volunteerMinutes;
    final int? paid = preview?.paidMinutes ?? row.paidMinutes;
    final int? gross = preview == null ? row.gross : preview.gross;
    final int? net = preview == null ? row.net : preview.net;

    final List<Widget> cells = [
      _Cell(
        width: c.name,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: _nameInset, right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextLink(
              text: row.fullName,
              style: GoogleFonts.plusJakartaSans(fontSize: c.cellFont, fontWeight: FontWeight.w700, color: AppTheme.trialOceanText),
              onTap: () => onOpen(row),
            ),
            if (row.openingPending) ...[
              const SizedBox(height: 4),
              OpeningPendingPill(fontSize: c.cellFont - 2.5),
            ],
          ],
        ),
      ),
      _Cell(width: c.at(1), opensGroup: !c.scrolls, child: _value(c, _countOf(row.days), strong: true)),
      _Cell(width: c.at(2), child: _value(c, _countOf(row.presenceDays))),
      _Cell(width: c.at(3), child: _value(c, _countOf(row.onlineDays))),
      _Cell(width: c.at(4), opensGroup: true, child: _value(c, _minutesOf(row.workedMinutes), strong: true)),
      _Cell(width: c.at(5), child: _value(c, _minutesOf(volunteer), strong: true)),
      _Cell(width: c.at(6), child: _value(c, _minutesOf(paid), strong: true)),
      _Cell(width: c.at(7), opensGroup: true, child: _value(c, _amountOf(gross), strong: true)),
      _Cell(width: c.at(8), child: _value(c, _amountOf(withholdingOf(gross, net)))),
      _Cell(width: c.at(9), child: _value(c, _amountOf(net))),
      _Cell(width: c.at(10), child: _receipt()),
      if (c.compact)
        _Cell(width: c.at(11), opensGroup: true, child: _availability())
      else ...[
        _Cell(
          width: c.at(11),
          opensGroup: true,
          child: row.belowMonthly ? _Warning(text: availabilityShort(row.availabilities), size: c.warningFont) : _reached,
        ),
        _Cell(
          width: c.at(12),
          child: row.shortWeeks > 0 ? _Warning(text: shortWeeks(row.shortWeeks), size: c.warningFont) : _reached,
        ),
      ],
      _Cell(
        width: c.rule,
        opensGroup: true,
        padding: EdgeInsets.symmetric(horizontal: c.ruleInset - 1),
        child: _rule(context),
      ),
    ];

    final Widget box = AnimatedContainer(
      duration: _dropFade,
      height: _rowHeight + (first ? 0 : 1),
      decoration: BoxDecoration(
        color: dropLit ? _dropSurface : Colors.white.withValues(alpha: 0),
        border: first ? null : Border(top: BorderSide(color: _rowLine)),
      ),
      foregroundDecoration: dropLit
          ? BoxDecoration(border: Border.all(color: AppTheme.trialTurquoise, width: _dropRim))
          : null,
      child: _cellsOf(cells, part),
    );

    final Widget line = SummarySearchRow(search: search, name: row.fullName, part: part, child: box);

    // A file dropped on a paid teacher's row is their receipt for the month.
    if (!_takesReceipt)
    {
      return line;
    }

    return DropTarget(
      onDragEntered: (_) => onDragReceipt(row, true),
      onDragExited: (_) => onDragReceipt(row, false),
      onDragDone: (details)
      {
        onDragReceipt(row, false);

        if (details.files.isNotEmpty)
        {
          onDropReceipt(row, details.files.first);
        }
      },
      child: line,
    );
  }
}

// Saves the rule just picked; until pressed, nothing is saved.
class _ConfirmRule extends StatelessWidget
{
  final bool shown;
  final bool saving;
  final VoidCallback onTap;

  const _ConfirmRule({super.key, required this.shown, required this.saving, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final bool effects = VisualEffects.of(context);

    return SizedBox(
      width: _confirmWidth,
      height: _confirmHeight,
      child: IgnorePointer(
        ignoring: !shown,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: effects ? _confirmFade : VisualEffects.plainFade,
          child: AnimatedScale(
            scale: shown || !effects ? 1 : 0.6,
            duration: effects ? _confirmFade : Duration.zero,
            curve: Curves.easeOutBack,
            child: AppGradientButton(
              label: kConfirmRule,
              icon: Icons.save_rounded,
              iconOnlyTooltip: kConfirmRule,
              width: _confirmWidth,
              height: _confirmHeight,
              fontSize: 14,
              radius: 12,
              busy: saving,
              onPressed: saving ? () {} : onTap,
            ),
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget
{
  final List<TeacherMonthRow> rows;

  // Rules picked and not saved: the totals follow them too.
  final Map<String, VolunteeringRule> chosen;

  final _Columns columns;
  final _Part part;

  const _Totals({required this.rows, required this.chosen, required this.columns, required this.part});

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    var worked = 0;
    var given = 0;
    var paid = 0;
    var gross = 0;
    var net = 0;

    final int owed = rows.where((row) => row.isPaid).length;
    final int received = rows.where((row) => row.isPaid && row.receipt != null).length;

    for (final row in rows)
    {
      final VolunteeringRule? picked = chosen[row.taxCode];
      final RuleFigures? preview = picked == null ? null : row.figuresFor(picked);

      worked += row.workedMinutes;
      given += preview?.volunteerMinutes ?? row.volunteerMinutes;
      paid += preview?.paidMinutes ?? row.paidMinutes ?? 0;
      gross += (preview == null ? row.gross : preview.gross) ?? 0;
      net += (preview == null ? row.net : preview.net) ?? 0;
    }

    final TextStyle strong = _cellStyle(c, strong: true);
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
      _Cell(width: c.at(4), opensGroup: true, child: _figure(formatMinutes(worked), strong)),
      _Cell(width: c.at(5), child: _figure(formatMinutes(given), strong)),
      _Cell(width: c.at(6), child: _figure(formatMinutes(paid), strong)),
      _Cell(width: c.at(7), opensGroup: true, child: _figure(formatAmount(gross), strong)),
      _Cell(width: c.at(8), child: _figure(formatAmount(gross - net), strong)),
      _Cell(width: c.at(9), child: _figure(formatAmount(net), strong)),
      _Cell(
        width: c.at(10),
        child: owed == 0 ? none : _figure(receiptsCount(received, owed), _cellStyle(c, color: AppTheme.trialMutedText)),
      ),
      _Cell(width: c.at(11), opensGroup: true, child: none),
      if (!c.compact) SizedBox(width: c.at(12)),
      _Cell(width: c.rule, opensGroup: true, child: none),
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

// "lunedì 2 novembre sera".
String pendingBandLabel(PendingBand band)
{
  final String day = formatWeekdayColumnLabel(band.date);

  if (isEnglish)
  {
    return '$day ${bandLabel(band.band).toLowerCase()}';
  }

  return '${day[0].toLowerCase()}${day.substring(1)} ${bandLabel(band.band).toLowerCase()}';
}

// «Ancora da confermare: …», each band a link to its daily summary.
// The links are widgets of their own: a span restyled on hover is a new span to the
// mouse, which leaves and enters again for ever, and its click never lands.
class PendingBandsNote extends StatelessWidget
{
  final List<PendingBand> pending;
  final ValueChanged<PendingBand> onOpen;
  final bool centered;

  const PendingBandsNote({super.key, required this.pending, required this.onOpen, this.centered = false});

  // All of them while few, else the first ones and how many more.
  List<PendingBand> get _named => pending.length <= kNamedPendingBands + 1 ? pending : pending.sublist(0, kNamedPendingBands);

  @override
  Widget build(BuildContext context)
  {
    final TextStyle plain = GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );
    final TextStyle link = plain.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialTealDeepText);

    final List<PendingBand> named = _named;
    final int others = pending.length - named.length;

    final List<InlineSpan> spans = [TextSpan(text: kStillToConfirm)];

    for (final (index, band) in named.indexed)
    {
      if (index > 0)
      {
        spans.add(TextSpan(text: index == named.length - 1 && others == 0 ? tr(' e ', ' and ') : ', '));
      }

      // The sentence scales what sits in it already: the link must not scale again.
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: MediaQuery.withNoTextScaling(
            child: AppTextLink(text: pendingBandLabel(band), style: link, onTap: () => onOpen(band)),
          ),
        ),
      );
    }

    if (others > 0)
    {
      spans.add(TextSpan(text: ' ${andOthers(others)}'));
    }

    spans.add(const TextSpan(text: '.'));

    // Centred and wrapped, the text is only as wide as its longest line: else its lines sit
    // in the middle of the whole width and the clock is left far away from them.
    final Widget text = Text.rich(
      TextSpan(style: plain, children: spans),
      textAlign: centered ? TextAlign.center : TextAlign.start,
      textWidthBasis: centered ? TextWidthBasis.longestLine : TextWidthBasis.parent,
    );

    return Row(
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.schedule_rounded, size: 17, color: AppTheme.trialTurquoise),
        ),
        const SizedBox(width: 8),
        if (centered) Flexible(child: text) else Expanded(child: text),
      ],
    );
  }
}
