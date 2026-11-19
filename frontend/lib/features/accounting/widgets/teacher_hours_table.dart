import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_text_link.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';
import 'hours_table_parts.dart';

// Shares of the width left once the action column is taken: names, times, hours, money.
const double _nameShare = 18;
const double _timeShare = 10.8;
const double _hoursShare = 8.2;
const double _moneyShare = 8.8;
const double _shares = _nameShare + 4 * _timeShare + 2 * _hoursShare + 2 * _moneyShare;

// As on the narrowest wide window: narrower, the table keeps this width and scrolls under its names.
const double _leastWidth = 930;

enum TeacherHoursAction { addStretch, dropLastStretch, markAbsent, markPresent, align, takeOut }

typedef WorkEdit = void Function(TeacherHoursRow row, int index, HoursSpan span);
typedef VolunteerEdit = void Function(TeacherHoursRow row, HoursSpan? span);

class TeacherHoursTable extends StatelessWidget
{
  final TeacherHoursBand band;

  // False once confirmed: values only, no fields or menus.
  final bool editable;

  // The band's whole span: the times offered.
  final int firstMinute;
  final int lastMinute;

  final WorkEdit onWork;
  final VolunteerEdit onVolunteer;
  final void Function(TeacherHoursRow row, TeacherHoursAction action) onAction;
  final VoidCallback onAddTeacher;

  // A teacher's name leads to their pay.
  final ValueChanged<TeacherHoursRow> onOpenTeacher;

  const TeacherHoursTable({
    super.key,
    required this.band,
    required this.editable,
    required this.firstMinute,
    required this.lastMinute,
    required this.onWork,
    required this.onVolunteer,
    required this.onAction,
    required this.onAddTeacher,
    required this.onOpenTeacher,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final _Columns columns = _Columns.of(context, constraints.maxWidth);
        final List<TeacherHoursRow> rows = band.rows;
        final int? lastEnd = band.lastEnd;

        Widget line(TeacherHoursRow row, int index, HoursPart part)
        {
          return _Row(
            row: row,
            columns: columns,
            part: part,
            first: index == 0,
            editable: editable,
            firstMinute: firstMinute,
            lastMinute: lastMinute,
            onWork: onWork,
            onVolunteer: onVolunteer,
            onAction: onAction,
            onOpen: onOpenTeacher,
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.surface,
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
              if (editable) HoursAddRow(label: kAddTeacher, onTap: onAddTeacher),
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
  final double money;

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
        money = (width - kHoursActionWidth) * _moneyShare / _shares;
}

class _Head extends StatelessWidget
{
  final _Columns columns;
  final HoursPart part;

  const _Head({required this.columns, this.part = HoursPart.whole});

  Widget _group(String label, double width, {bool opens = true})
  {
    return HoursCell(
      width: width,
      opensGroup: opens,
      padding: const EdgeInsets.only(top: 6),
      child: Text(label.toUpperCase(), maxLines: 1, style: hoursGroupStyle),
    );
  }

  Widget _head(String label, double width, {bool opens = false})
  {
    return HoursCell(width: width, opensGroup: opens, child: Text(label, maxLines: 1, style: hoursHeadStyle));
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
              _group(kWorkGroup, 2 * c.time + c.hours),
              _group(kVolunteerGroup, 2 * c.time + c.hours),
              _group(kPayGroup, 2 * c.money),
              const SizedBox(width: kHoursActionWidth),
            ], part),
          ),
          Container(
            height: 28,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine))),
            child: hoursCellsOf([
              HoursCell(
                width: c.name,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: kHoursNameInset),
                child: Text(kTeacherColumn, maxLines: 1, style: hoursHeadStyle),
              ),
              _head(kStartColumn, c.time, opens: true),
              _head(kEndColumn, c.time),
              _head(kHoursColumn, c.hours),
              _head(kStartColumn, c.time, opens: true),
              _head(kEndColumn, c.time),
              _head(kHoursColumn, c.hours),
              _head(kGrossColumn, c.money, opens: true),
              _head(kNetColumn, c.money),
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
  final TeacherHoursRow row;
  final _Columns columns;
  final HoursPart part;
  final bool first;
  final bool editable;
  final int firstMinute;
  final int lastMinute;
  final WorkEdit onWork;
  final VolunteerEdit onVolunteer;
  final void Function(TeacherHoursRow row, TeacherHoursAction action) onAction;
  final ValueChanged<TeacherHoursRow> onOpen;

  const _Row({
    required this.row,
    required this.columns,
    required this.part,
    required this.first,
    required this.editable,
    required this.firstMinute,
    required this.lastMinute,
    required this.onWork,
    required this.onVolunteer,
    required this.onAction,
    required this.onOpen,
  });

  // The calendar's stretches stand struck for an absent teacher.
  List<HoursSpan> get _shownWork => row.absent ? (row.planned ?? const []) : row.work;

  Widget _workField(int index, {required bool end})
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

  Widget _volunteerField({required bool end})
  {
    final HoursSpan? volunteer = row.volunteer;

    if (!row.mayVolunteer || row.work.isEmpty)
    {
      return editable ? const HoursOffField(text: '—') : const HoursReadOnly(text: '—');
    }

    final int? value = volunteer == null ? null : (end ? volunteer.end : volunteer.start);

    if (!editable)
    {
      return HoursReadOnly(text: value == null ? '—' : clockOf(value), changed: row.volunteerChanged(end: end));
    }

    final HoursSpan work = row.work.first;
    final HoursSpan? proposed = row.volunteerProposed;

    return HoursTimeField(
      value: value,
      options: [
        kNoTime,
        ...(end ? hoursSteps(work.start + kQuarterHour, work.end) : hoursSteps(work.start, work.end - kQuarterHour)),
      ],
      allowed: (minute) => minute == kNoTime || volunteer == null || (end ? minute > volunteer.start : minute < volunteer.end),
      marked: proposed == null ? null : (end ? proposed.end : proposed.start),
      changed: row.volunteerChanged(end: end),
      onChanged: (minute)
      {
        if (minute == kNoTime)
        {
          onVolunteer(row, null);

          return;
        }

        // From nothing, one side picked: the hour around it, inside the work.
        final HoursSpan next = volunteer == null
            ? (end
                ? HoursSpan(math.max(work.start, minute - 60), minute)
                : HoursSpan(minute, math.min(work.end, minute + 60)))
            : (end ? HoursSpan(volunteer.start, minute) : HoursSpan(minute, volunteer.end));

        onVolunteer(row, next);
      },
    );
  }

  List<Widget> _workCells({required bool asVolunteering})
  {
    final _Columns c = columns;
    final int count = _shownWork.length;
    final bool shows = row.isVolunteer == asVolunteering;

    Widget times({required bool end})
    {
      if (!shows || count == 0)
      {
        return hoursStack([editable ? const HoursOffField(text: '—') : const HoursReadOnly(text: '—')]);
      }

      return hoursStack([for (var index = 0; index < count; index++) _workField(index, end: end)]);
    }

    final String hours = row.absent || !shows ? '—' : formatMinutes(row.workedMinutes);

    return [
      HoursCell(width: c.time, opensGroup: true, child: times(end: false)),
      HoursCell(width: c.time, child: times(end: true)),
      HoursCell(
        width: c.hours,
        child: Text(hours, style: hoursCellStyle(strong: hours != '—', color: hours == '—' ? kHoursDashInk : null)),
      ),
    ];
  }

  List<Widget> _volunteerCells()
  {
    final _Columns c = columns;
    final String hours = row.volunteerMinutes == 0 ? '—' : formatMinutes(row.volunteerMinutes);

    return [
      HoursCell(width: c.time, opensGroup: true, child: hoursStack([_volunteerField(end: false)])),
      HoursCell(width: c.time, child: hoursStack([_volunteerField(end: true)])),
      HoursCell(
        width: c.hours,
        child: Text(hours, style: hoursCellStyle(strong: hours != '—', color: hours == '—' ? kHoursDashInk : null)),
      ),
    ];
  }

  List<Widget> _moneyCells()
  {
    final _Columns c = columns;
    final int? gross = row.gross;
    final int? net = row.net;
    final bool none = gross == null || net == null || row.absent;

    return [
      HoursCell(
        width: c.money,
        opensGroup: true,
        child: Text(none ? '—' : formatAmount(gross), style: hoursCellStyle(strong: !none, color: none ? kHoursDashInk : null)),
      ),
      HoursCell(
        width: c.money,
        child: Text(none ? '—' : formatAmount(net), style: hoursCellStyle(color: none ? kHoursDashInk : null)),
      ),
    ];
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
            color: row.absent ? AppTheme.trialMutedText : AppTheme.trialOceanText,
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

    final double height = hoursRowHeight(_shownWork.length, first: first);

    return Container(
      height: height,
      decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: kHoursRowLine))),
      child: hoursCellsOf([
        HoursCell(
          width: c.name,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: kHoursNameInset, right: 8),
          child: _name(),
        ),
        ..._workCells(asVolunteering: false),
        if (row.isVolunteer) ..._workCells(asVolunteering: true) else ..._volunteerCells(),
        ..._moneyCells(),
        SizedBox(
          width: kHoursActionWidth,
          child: Center(child: editable ? _RowMenu(row: row, onAction: onAction) : null),
        ),
      ], part),
    );
  }
}

class _Totals extends StatelessWidget
{
  final List<TeacherHoursRow> rows;
  final _Columns columns;
  final HoursPart part;

  const _Totals({required this.rows, required this.columns, this.part = HoursPart.whole});

  @override
  Widget build(BuildContext context)
  {
    final _Columns c = columns;

    var worked = 0;
    var given = 0;
    var gross = 0;
    var net = 0;

    for (final row in rows)
    {
      if (row.isVolunteer)
      {
        given += row.workedMinutes;
      }
      else
      {
        worked += row.workedMinutes;
        given += row.volunteerMinutes;
      }

      if (!row.absent)
      {
        gross += row.gross ?? 0;
        net += row.net ?? 0;
      }
    }

    final TextStyle strong = hoursCellStyle(strong: true);

    return Container(
      height: 44,
      decoration: BoxDecoration(
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
        HoursCell(width: c.hours, child: Text(formatMinutes(worked), style: strong)),
        HoursCell(width: c.time, opensGroup: true, child: const SizedBox.shrink()),
        SizedBox(width: c.time),
        HoursCell(width: c.hours, child: Text(formatMinutes(given), style: strong)),
        HoursCell(width: c.money, opensGroup: true, child: Text(formatAmount(gross), style: strong)),
        HoursCell(width: c.money, child: Text(formatAmount(net), style: strong)),
        const SizedBox(width: kHoursActionWidth),
      ], part),
    );
  }
}

class _RowMenu extends StatelessWidget
{
  final TeacherHoursRow row;
  final void Function(TeacherHoursRow row, TeacherHoursAction action) onAction;

  const _RowMenu({required this.row, required this.onAction});

  bool get _corrected
  {
    final List<HoursSpan>? planned = row.planned;

    if (row.absent || row.volunteerSet || planned == null)
    {
      return true;
    }

    if (planned.length != row.work.length)
    {
      return true;
    }

    for (var index = 0; index < planned.length; index++)
    {
      if (planned[index] != row.work[index])
      {
        return true;
      }
    }

    return false;
  }

  List<(IconData, String, TeacherHoursAction)> get _entries
  {
    // In person too: stretches set apart by hand leave the time between them unpaid.
    final bool working = !row.absent;
    final bool split = working && row.work.length > 1;

    if (row.added)
    {
      return [
        if (working) (Icons.add_rounded, kAddStretch, TeacherHoursAction.addStretch),
        if (split) (Icons.remove_rounded, kDropLastStretch, TeacherHoursAction.dropLastStretch),
        (Icons.delete_outline_rounded, kTakeOut, TeacherHoursAction.takeOut),
      ];
    }

    return [
      if (working) (Icons.add_rounded, kAddStretch, TeacherHoursAction.addStretch),
      if (split) (Icons.remove_rounded, kDropLastStretch, TeacherHoursAction.dropLastStretch),
      row.absent
          ? (Icons.how_to_reg_outlined, kMarkPresent, TeacherHoursAction.markPresent)
          : (Icons.person_off_outlined, kMarkAbsent, TeacherHoursAction.markAbsent),
      if (_corrected) (Icons.restart_alt_rounded, kAlignToCalendar, TeacherHoursAction.align),
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
