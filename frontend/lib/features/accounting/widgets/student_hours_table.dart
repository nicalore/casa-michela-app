import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_text_link.dart';
import '../../people/utils/payments_strings.dart'
    show hoursLineUnit, hoursText, kAheadExhaustedBadge, kCostColumn, kExhaustedBadge, kTariffKindLabels, leftLabel, tariffCost;
import '../models/student_hours_items.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';
import 'hours_table_parts.dart';
import '../utils/opening_strings.dart' show kOpeningPending;

// Shares of the width left once the action column is taken.
const double _nameShare = 21;
const double _timeShare = 11;
const double _hoursShare = 8.5;
const double _tariffShare = 14.5;
const double _situationShare = 27;
const double _costShare = 9;
const double _shares = _nameShare + 2 * _timeShare + _hoursShare + _tariffShare + _situationShare + _costShare;

// Room for a tariff's cost and a situation whole: narrower, the table keeps it and scrolls under its names.
const double _leastWidth = 1090;

// The second line of a situation starts under its text, past the icon.
const double _situationIcon = 17;
const double _situationGap = 6;

enum StudentHoursAction { addStretch, dropLastStretch, markAbsent, markPresent, align, takeOut }

typedef StudentWorkEdit = void Function(StudentHoursRow row, int index, HoursSpan span);

class StudentHoursTable extends StatelessWidget
{
  final StudentHoursBand band;

  // False once confirmed: values only, no fields or menus.
  final bool editable;

  // The band's whole span: the times offered.
  final int firstMinute;
  final int lastMinute;

  final StudentWorkEdit onWork;
  final void Function(StudentHoursRow row, StudentHoursAction action) onAction;
  final VoidCallback onAddStudent;

  // A pupil's name leads to their payments.
  final ValueChanged<StudentHoursRow> onOpenStudent;

  const StudentHoursTable({
    super.key,
    required this.band,
    required this.editable,
    required this.firstMinute,
    required this.lastMinute,
    required this.onWork,
    required this.onAction,
    required this.onAddStudent,
    required this.onOpenStudent,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final _Columns columns = _Columns.of(context, constraints.maxWidth);
        final List<StudentHoursRow> rows = band.rows;
        final int? lastEnd = band.lastEnd;

        Widget line(StudentHoursRow row, int index, HoursPart part)
        {
          return _Row(
            row: row,
            day: band.date,
            columns: columns,
            part: part,
            first: index == 0,
            editable: editable,
            firstMinute: firstMinute,
            lastMinute: lastMinute,
            onWork: onWork,
            onAction: onAction,
            onOpen: onOpenStudent,
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (columns.scrolls)
                HoursSideScroll(
                  nameWidth: columns.name,
                  width: columns.width,
                  part: (part) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Head(columns: columns, part: part),
                      for (final (index, row) in rows.indexed) line(row, index, part),
                      _Totals(rows: rows, columns: columns, part: part),
                      const SizedBox(height: kHoursScrollBarRoom),
                    ],
                  ),
                )
              else ...[
                _Head(columns: columns),
                for (final (index, row) in rows.indexed) line(row, index, HoursPart.whole),
                _Totals(rows: rows, columns: columns),
              ],
              if (band.waiting.isNotEmpty && lastEnd != null) HoursNote(text: stillToCome(band.waiting, lastEnd)),
              if (editable) HoursAddRow(label: kAddStudent, onTap: onAddStudent),
            ],
          ),
        );
      },
    );
  }
}

class _Columns
{
  final double width;
  final double name;
  final double time;
  final double hours;
  final double tariff;
  final double situation;
  final double cost;

  // Too narrow for its least width: it keeps that and scrolls.
  final bool scrolls;

  factory _Columns.of(BuildContext context, double width)
  {
    final double least = hoursLeastWidth(context, _leastWidth);

    return width < least ? _Columns(least, scrolls: true) : _Columns(width);
  }

  _Columns(this.width, {this.scrolls = false})
      : name = (width - kHoursActionWidth) * _nameShare / _shares,
        time = (width - kHoursActionWidth) * _timeShare / _shares,
        hours = (width - kHoursActionWidth) * _hoursShare / _shares,
        tariff = (width - kHoursActionWidth) * _tariffShare / _shares,
        situation = (width - kHoursActionWidth) * _situationShare / _shares,
        cost = (width - kHoursActionWidth) * _costShare / _shares;
}

const EdgeInsets _leftPadding = EdgeInsets.only(left: 14, right: 8);

class _Head extends StatelessWidget
{
  final _Columns columns;
  final HoursPart part;

  const _Head({required this.columns, this.part = HoursPart.whole});

  Widget _group(String label, double width)
  {
    return HoursCell(
      width: width,
      opensGroup: true,
      padding: const EdgeInsets.only(top: 6),
      child: Text(label.toUpperCase(), maxLines: 1, style: hoursGroupStyle),
    );
  }

  Widget _head(String label, double width, {bool opens = false, bool left = false})
  {
    return HoursCell(
      width: width,
      opensGroup: opens,
      alignment: left ? Alignment.centerLeft : Alignment.center,
      padding: left ? _leftPadding : const EdgeInsets.symmetric(horizontal: 4),
      child: Text(label, maxLines: 1, style: hoursHeadStyle),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    return Container(
      color: kHoursHeadSurface,
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: hoursCellsOf([
              SizedBox(width: c.name),
              _group(kLessonsGroup, 2 * c.time + c.hours),
              _group(kPaymentGroup, c.tariff + c.situation + c.cost),
              const SizedBox(width: kHoursActionWidth),
            ], part),
          ),
          Container(
            height: 28,
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine))),
            child: hoursCellsOf([
              HoursCell(
                width: c.name,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: kHoursNameInset),
                child: Text(kStudentColumn, maxLines: 1, style: hoursHeadStyle),
              ),
              _head(kStartColumn, c.time, opens: true),
              _head(kEndColumn, c.time),
              _head(kHoursColumn, c.hours),
              _head(kTariffColumn, c.tariff, opens: true, left: true),
              _head(kSituationColumn, c.situation, left: true),
              _head(kCostColumn, c.cost),
              const SizedBox(width: kHoursActionWidth),
            ], part),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget
{
  final StudentHoursRow row;
  final DateTime day;
  final _Columns columns;
  final HoursPart part;
  final bool first;
  final bool editable;
  final int firstMinute;
  final int lastMinute;
  final StudentWorkEdit onWork;
  final void Function(StudentHoursRow row, StudentHoursAction action) onAction;
  final ValueChanged<StudentHoursRow> onOpen;

  const _Row({
    required this.row,
    required this.day,
    required this.columns,
    required this.part,
    required this.first,
    required this.editable,
    required this.firstMinute,
    required this.lastMinute,
    required this.onWork,
    required this.onAction,
    required this.onOpen,
  });

  // The calendar's stretches stand struck for an absent pupil.
  List<HoursSpan> get _shownWork => row.absent ? (row.planned ?? const []) : row.work;

  Widget _timeField(int index, {required bool end})
  {
    final HoursSpan span = _shownWork[index];
    final int value = end ? span.end : span.start;

    if (row.absent)
    {
      return editable ? HoursOffField(text: clockOf(value), struck: true) : HoursReadOnly(text: clockOf(value), struck: true);
    }

    if (!editable)
    {
      return HoursReadOnly(text: clockOf(value), changed: row.changedAt(index, end: end));
    }

    final List<HoursSpan>? planned = row.planned;
    final int? marked = planned != null && index < planned.length ? (end ? planned[index].end : planned[index].start) : null;

    return HoursTimeField(
      value: value,
      options: end ? hoursSteps(firstMinute + kQuarterHour, lastMinute) : hoursSteps(firstMinute, lastMinute - kQuarterHour),
      allowed: (minute) => end ? minute > span.start : minute < span.end,
      marked: marked,
      changed: row.changedAt(index, end: end),
      onChanged: (minute) => onWork(row, index, end ? HoursSpan(span.start, minute) : HoursSpan(minute, span.end)),
    );
  }

  Widget _times({required bool end})
  {
    final int count = _shownWork.length;

    if (count == 0)
    {
      return hoursStack([editable ? const HoursOffField(text: '—') : const HoursReadOnly(text: '—')]);
    }

    return hoursStack([for (var index = 0; index < count; index++) _timeField(index, end: end)]);
  }

  Widget _name()
  {
    return Wrap(
      spacing: 8,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppTextLink(
          text: row.fullName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: row.absent ? AppTheme.trialMutedText : AppTheme.trialOcean,
          ),
          onTap: () => onOpen(row),
        ),
        if (row.isOnline) const HoursBadge(text: kOnlineBadge, online: true),
        if (row.absent) const HoursBadge(text: kAbsentBadge),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;
    final String hours = row.absent ? '—' : formatMinutes(row.minutes);
    final int cost = row.situation.costCents;

    return Container(
      height: hoursRowHeight(_shownWork.length, first: first),
      decoration: first ? null : const BoxDecoration(border: Border(top: BorderSide(color: kHoursRowLine))),
      child: hoursCellsOf([
        HoursCell(
          width: c.name,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: kHoursNameInset, right: 8),
          child: _name(),
        ),
        HoursCell(width: c.time, opensGroup: true, child: _times(end: false)),
        HoursCell(width: c.time, child: _times(end: true)),
        HoursCell(
          width: c.hours,
          child: Text(hours, style: hoursCellStyle(strong: hours != '—', color: hours == '—' ? kHoursDashInk : null)),
        ),
        HoursCell(
          width: c.tariff,
          opensGroup: true,
          alignment: Alignment.centerLeft,
          padding: _leftPadding,
          child: _Tariff(situation: row.situation),
        ),
        HoursCell(
          width: c.situation,
          alignment: Alignment.centerLeft,
          padding: _leftPadding,
          // Absent, the band changes nothing: a dash, as in the cost.
          child: row.absent
              ? Text('—', style: hoursCellStyle(color: kHoursDashInk))
              : _Situation(situation: row.situation, day: day),
        ),
        HoursCell(
          width: c.cost,
          child: Text(
            cost == 0 ? '—' : formatAmount(cost),
            style: hoursCellStyle(strong: cost != 0, color: cost == 0 ? kHoursDashInk : null),
          ),
        ),
        SizedBox(
          width: kHoursActionWidth,
          child: Center(child: editable ? _RowMenu(row: row, onAction: onAction) : null),
        ),
      ], part),
    );
  }
}

// «Pacchetto» over «€ 260,00 per 20 ore».
class _Tariff extends StatelessWidget
{
  final StudentSituation situation;

  const _Tariff({required this.situation});

  @override
  Widget build(BuildContext context)
  {
    final String? kind = situation.tariffKind;
    final int? cents = situation.tariffCents;

    if (kind == null || cents == null)
    {
      return Text('—', style: hoursCellStyle(color: kHoursDashInk));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kTariffKindLabels[kind] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
        ),
        const SizedBox(height: 1),
        Text(
          tariffCost(kind, cents, situation.packageHours),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
        ),
      ],
    );
  }
}

// The pupil's state after the band: teal when in order, gold when something is to pay.
class _Situation extends StatelessWidget
{
  final StudentSituation situation;

  // The band's day: its month's fee is the one the situation speaks of.
  final DateTime day;

  const _Situation({required this.situation, required this.day});

  ({String text, String? below, String? badge, bool ahead})? get _said
  {
    final int minutes = situation.minutes;

    return switch (situation.kind)
    {
      StudentSituationKind.packageLeft => (
          text: leftLabel(minutes),
          below: null,
          badge: situation.renewed ? kRenewalBadge : null,
          ahead: false,
        ),
      StudentSituationKind.packageEnded => (
          text: kExhaustedBadge,
          below: minutes == 0 ? null : '${hoursText(minutes)} ${hoursLineUnit('OVER_PACKAGE', minutes)}',
          badge: null,
          ahead: false,
        ),
      StudentSituationKind.monthPaid => (text: monthPaidSituation(day), below: null, badge: null, ahead: false),
      StudentSituationKind.monthUnpaid => (text: monthUnpaidSituation(day), below: null, badge: null, ahead: false),
      StudentSituationKind.settle => (text: kToSettleSituation, below: null, badge: null, ahead: false),
      StudentSituationKind.aheadLeft => (text: leftLabel(minutes), below: null, badge: kAheadBadge, ahead: true),
      StudentSituationKind.aheadEnded => (
          text: kAheadExhaustedBadge,
          below: minutes == 0 ? null : '${hoursText(minutes)} ${kToSettleSituation.toLowerCase()}',
          badge: null,
          ahead: false,
        ),
      StudentSituationKind.pending => (text: kOpeningPending, below: null, badge: null, ahead: false),
      StudentSituationKind.none => null,
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final said = _said;

    if (said == null)
    {
      return Text('—', style: hoursCellStyle(color: kHoursDashInk));
    }

    final bool due = situation.isDue;
    final Color ink = due ? AppTheme.modifiedAccent : AppTheme.trialOcean;
    final String? below = said.below;
    final String? badge = said.badge;

    final Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          due ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
          size: _situationIcon,
          color: due ? AppTheme.trialGold : AppTheme.trialTurquoise,
        ),
        const SizedBox(width: _situationGap),
        Flexible(
          child: Text(
            said.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          _Chip(text: badge, ahead: said.ahead),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line,
        if (below != null)
          Padding(
            padding: const EdgeInsets.only(left: _situationIcon + _situationGap, top: 2),
            child: Text(
              below,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
            ),
          ),
      ],
    );
  }
}

// «Rinnovo» in blue, where the renewed package starts; «Anticipo» in teal.
class _Chip extends StatelessWidget
{
  final String text;
  final bool ahead;

  const _Chip({required this.text, required this.ahead});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      decoration: BoxDecoration(
        color: ahead ? AppTheme.paidSurface : AppTheme.laterBlueSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ahead ? AppTheme.trialTealDeep : AppTheme.laterBlue,
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget
{
  final List<StudentHoursRow> rows;
  final _Columns columns;
  final HoursPart part;

  const _Totals({required this.rows, required this.columns, this.part = HoursPart.whole});

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;
    final int minutes = rows.fold(0, (sum, row) => sum + (row.absent ? 0 : row.minutes));
    final int cost = rows.fold(0, (sum, row) => sum + row.situation.costCents);
    final TextStyle strong = hoursCellStyle(strong: true);

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: kHoursHeadSurface,
        border: Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: hoursCellsOf([
        HoursCell(
          width: c.name,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: kHoursNameInset),
          child: Text(kTotalRow.toUpperCase(), style: hoursGroupStyle.copyWith(fontSize: 12)),
        ),
        HoursCell(width: c.time, opensGroup: true, child: const SizedBox.shrink()),
        SizedBox(width: c.time),
        HoursCell(width: c.hours, child: Text(formatMinutes(minutes), style: strong)),
        HoursCell(width: c.tariff, opensGroup: true, child: const SizedBox.shrink()),
        SizedBox(width: c.situation),
        HoursCell(width: c.cost, child: Text(formatAmount(cost), style: strong)),
        const SizedBox(width: kHoursActionWidth),
      ], part),
    );
  }
}

class _RowMenu extends StatelessWidget
{
  final StudentHoursRow row;
  final void Function(StudentHoursRow row, StudentHoursAction action) onAction;

  const _RowMenu({required this.row, required this.onAction});

  List<(IconData, String, StudentHoursAction)> get _entries
  {
    final bool present = !row.absent;
    final bool split = present && row.work.length > 1;

    if (row.added)
    {
      return [
        if (present) (Icons.add_rounded, kAddStretch, StudentHoursAction.addStretch),
        if (split) (Icons.remove_rounded, kDropLastStretch, StudentHoursAction.dropLastStretch),
        (Icons.delete_outline_rounded, kTakeOut, StudentHoursAction.takeOut),
      ];
    }

    return [
      if (present) (Icons.add_rounded, kAddStretch, StudentHoursAction.addStretch),
      if (split) (Icons.remove_rounded, kDropLastStretch, StudentHoursAction.dropLastStretch),
      row.absent
          ? (Icons.how_to_reg_outlined, kMarkPresent, StudentHoursAction.markPresent)
          : (Icons.person_off_outlined, kMarkAbsent, StudentHoursAction.markAbsent),
      if (row.corrected) (Icons.restart_alt_rounded, kAlignToCalendar, StudentHoursAction.align),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return HoursRowMenu(
      entries: [for (final (icon, text, action) in _entries) (icon, text, () => onAction(row, action))],
    );
  }
}
