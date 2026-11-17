import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_calendar_button.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/opening_day_item.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/lessons_day_bar.dart';
import '../../people/models/person_item.dart';
import '../../people/utils/compensation_strings.dart';
import '../accounting_page.dart';
import '../export/accounting_pdf_export.dart';
import '../export/teacher_hours_pdf.dart';
import '../../lessons/utils/calendar_jump.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_jump.dart';
import '../utils/accounting_strings.dart';
import '../widgets/add_teacher_dialog.dart';
import '../widgets/hours_table_parts.dart' show hoursDayLabelWidth;
import '../widgets/teacher_hours_table.dart';

const double _dayLabelWidth = 250;
const double _denseDayLabelWidth = 200;
const double _confirmWidth = 300;

const String _teacherRole = 'Docente';

// Accounting reaches back to the association's first month.
final DateTime _firstDay = DateTime(2023, 1, 1);

// The band under way, or the last one gone by.
TimeBucket _bandOf(DateTime now)
{
  return bucketFor(TimeOfDay(hour: now.hour, minute: now.minute)) ??
      (now.hour < 12 ? TimeBucket.morning : TimeBucket.evening);
}

class TeacherHoursTab extends StatefulWidget
{
  // On screen among the page's summaries: shown again, it reads the band anew.
  final bool shown;

  const TeacherHoursTab({super.key, this.shown = true});

  @override
  State<TeacherHoursTab> createState() => _TeacherHoursTabState();
}

class _TeacherHoursTabState extends State<TeacherHoursTab> with DestinationRefresh
{
  final ApiService _api = ApiService();

  late DateTime _today = _dateOf(romeNow());
  late DateTime _day = _today;
  late TimeBucket _band = _bandOf(romeNow());

  List<OpeningDayItem> _openings = const [];
  TeacherHoursBand? _data;
  Object? _error;
  bool _busy = false;
  bool _exporting = false;

  // A later answer for another day or band drops an earlier one.
  int _request = 0;

  Timer? _arrival;

  static DateTime _dateOf(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

  @override
  void initState()
  {
    super.initState();

    final CalendarJump? jump = AccountingJumps.teacherHours.take();

    if (jump != null)
    {
      _day = jump.day;
      _band = jump.band;
    }

    AccountingJumps.teacherHours.asked.addListener(_jump);
    unawaited(_load(pickOpenBand: jump == null));
  }

  @override
  void didUpdateWidget(TeacherHoursTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.shown && !oldWidget.shown)
    {
      unawaited(_load());
    }
  }

  @override
  void dispose()
  {
    AccountingJumps.teacherHours.asked.removeListener(_jump);
    _arrival?.cancel();
    super.dispose();
  }

  // Asked from a teacher's Compensi while the page stood behind it.
  void _jump()
  {
    final CalendarJump? jump = AccountingJumps.teacherHours.take();

    if (jump == null || !mounted)
    {
      return;
    }

    setState(()
    {
      _day = jump.day;
      _band = jump.band;
      _data = null;
    });

    unawaited(_load());
  }

  @override
  void onDestinationShown()
  {
    unawaited(_load());
  }

  bool _isClosed(TimeBucket band) => unionOpeningWindow(_openings, _day, band) == null;

  Future<void> _load({bool pickOpenBand = false}) async
  {
    final int request = ++_request;
    _arrival?.cancel();
    _today = _dateOf(romeNow());

    try
    {
      final List<OpeningDayItem> openings = await _api.getOpeningDays(dateFrom: _day, dateTo: _day);

      if (!mounted || request != _request)
      {
        return;
      }

      _openings = openings;

      // A shut band is not offered: the first open one after it, else the first open one at all.
      if (pickOpenBand && _isClosed(_band))
      {
        final List<TimeBucket> open = [for (final band in TimeBucket.values) if (!_isClosed(band)) band];

        if (open.isNotEmpty)
        {
          _band = open.firstWhere((band) => band.index >= _band.index, orElse: () => open.last);
        }
      }

      final TeacherHoursBand data = await _api.getTeacherHours(_day, _band);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _data = data;
        _error = null;
      });

      _awaitNextArrival(data);
    }
    catch (error)
    {
      if (!mounted || request != _request)
      {
        return;
      }

      setState(() => _error = error);
    }
  }

  // A row comes in when a teacher's last lesson ends: read the band again then.
  void _awaitNextArrival(TeacherHoursBand data)
  {
    final int? next = data.nextArrival;

    if (next == null || !isSameDate(data.date, _today))
    {
      return;
    }

    final DateTime now = romeNow();
    final DateTime due = DateTime(now.year, now.month, now.day, next ~/ 60, next % 60, 5);
    final Duration wait = due.difference(now);

    _arrival = Timer(wait.isNegative ? const Duration(seconds: 5) : wait, () => unawaited(_load()));
  }

  void _showDay(DateTime day)
  {
    setState(()
    {
      _day = _dateOf(day);
      _data = null;
    });

    unawaited(_load(pickOpenBand: true));
  }

  void _showBand(int index)
  {
    setState(()
    {
      _band = TimeBucket.values[index];
      _data = null;
    });

    unawaited(_load());
  }

  // Every write answers with the band as it now stands.
  Future<void> _write(Future<TeacherHoursBand> Function() call) async
  {
    if (_busy)
    {
      return;
    }

    final DateTime day = _day;
    final TimeBucket band = _band;

    setState(() => _busy = true);

    try
    {
      final TeacherHoursBand data = await call();

      // Another day or band is shown by now: its own load has the last word.
      if (mounted && isSameDate(day, _day) && band == _band)
      {
        // A load begun before this write would bring the band back as it was.
        _request++;
        setState(() => _data = data);
        _arrival?.cancel();
        _awaitNextArrival(data);
      }
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _busy = false);
      }
    }
  }

  void _editWork(TeacherHoursRow row, int index, HoursSpan span)
  {
    final List<HoursSpan> work = [for (final (at, old) in row.work.indexed) at == index ? span : old];

    unawaited(_write(() => _api.updateTeacherHours(_day, _band, row.taxCode, work: work)));
  }

  void _editVolunteer(TeacherHoursRow row, HoursSpan? span)
  {
    unawaited(
      _write(() => _api.updateTeacherHours(_day, _band, row.taxCode, setVolunteer: true, volunteer: span)),
    );
  }

  void _act(TeacherHoursRow row, TeacherHoursAction action)
  {
    switch (action)
    {
      case TeacherHoursAction.addStretch:
        _addStretch(row);
      case TeacherHoursAction.dropLastStretch:
        final List<HoursSpan> work = row.work.sublist(0, row.work.length - 1);

        unawaited(_write(() => _api.updateTeacherHours(_day, _band, row.taxCode, work: work)));
      case TeacherHoursAction.markAbsent:
        unawaited(_write(() => _api.updateTeacherHours(_day, _band, row.taxCode, absent: true)));
      case TeacherHoursAction.markPresent:
        unawaited(_write(() => _api.updateTeacherHours(_day, _band, row.taxCode, absent: false)));
      case TeacherHoursAction.align:
      case TeacherHoursAction.takeOut:
        unawaited(_write(() => _api.dropTeacherHours(_day, _band, row.taxCode)));
    }
  }

  // An hour after the last stretch, as far as the band goes.
  void _addStretch(TeacherHoursRow row)
  {
    final int last = row.work.isEmpty ? bandStartMinutes(_band) : row.work.last.end;
    final int end = bandEndMinutes(_band);

    if (last >= end)
    {
      CustomSnackBar.show(context: context, message: kNoRoomForStretch, isError: true);

      return;
    }

    final List<HoursSpan> work = [...row.work, HoursSpan(last, last + 60 > end ? end : last + 60)];

    unawaited(_write(() => _api.updateTeacherHours(_day, _band, row.taxCode, work: work)));
  }

  // The whole day, every band read anew: the tab opens at the tap, before any await.
  Future<void> _exportPdf() async
  {
    if (_exporting)
    {
      return;
    }

    final DateTime day = _day;

    setState(() => _exporting = true);

    await exportAccountingPdf(
      context,
      title: dailyPdfTab(day),
      fileName: dailyPdfFile(day),
      bytes: () async
      {
        final List<TeacherHoursBand> read = await Future.wait([
          for (final band in TimeBucket.values) _api.getTeacherHours(day, band),
        ]);

        return buildTeacherHoursPdf(day, [
          for (final (index, band) in TimeBucket.values.indexed) (band: band, data: read[index]),
        ]);
      },
    );

    if (mounted)
    {
      setState(() => _exporting = false);
    }
  }

  // Their record, on the pay of this summary's month; its way back leads here.
  void _openTeacher(TeacherHoursRow row)
  {
    final String month = '${_day.year}-${_day.month.toString().padLeft(2, '0')}';

    context.go(
      Uri(
        path: '/people/${row.taxCode}',
        queryParameters: {'from': kAccountingRoute, 'section': kCompensationSection, 'month': month},
      ).toString(),
    );
  }

  Future<void> _addTeacher() async
  {
    final TeacherHoursBand? data = _data;

    if (data == null)
    {
      return;
    }

    try
    {
      // Everybody who teaches: the active teachers' list is the families' one.
      final List<PersonItem> teachers = [
        for (final person in await _api.getPeople())
          if (person.roles.contains(_teacherRole)) person,
      ];

      if (!mounted)
      {
        return;
      }

      final TeacherHoursBand? added = await showAddTeacherDialog(
        context,
        day: _day,
        band: _band,
        teachers: teachers,
        present: {for (final row in data.rows) row.taxCode, ...data.waitingTaxCodes},
      );

      if (added != null && mounted)
      {
        setState(() => _data = added);
      }
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  Widget _buildDayNav(bool dense)
  {
    final double button = dense ? 36 : CarouselArrowButton.defaultSize;

    final String day = '${formatWeekdayColumnLabel(_day)} ${_day.year}';
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 14 : 15,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialInk,
    );

    final Widget label = Text(
      day,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );

    // On the narrowest windows the whole line shrinks a little rather than cut the day.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppCalendarButton(
            selected: _day,
            today: _today,
            first: _firstDay,
            last: calendarHorizon(_today),
            onPicked: _showDay,
            size: button,
          ),
          SizedBox(width: dense ? 8 : 12),
          CarouselArrowButton(
            icon: Icons.chevron_left_rounded,
            isDisabled: !_day.isAfter(_firstDay),
            size: button,
            onTap: () => _showDay(addDays(_day, -1)),
          ),
          SizedBox(width: dense ? 6 : 8),
          // Below the wide window the text is larger: the day takes the room it needs.
          SizedBox(
            width: dense ? hoursDayLabelWidth(context, day, style, _denseDayLabelWidth) : _dayLabelWidth,
            child: Center(child: label),
          ),
          SizedBox(width: dense ? 6 : 8),
          CarouselArrowButton(
            icon: Icons.chevron_right_rounded,
            isDisabled: !_day.isBefore(calendarHorizon(_today)),
            size: button,
            onTap: () => _showDay(addDays(_day, 1)),
          ),
        ],
      ),
    );
  }

  // The bands to the left of the days, both on the right.
  Widget _buildNav(bool dense)
  {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: dense ? 16 : 24,
        runSpacing: 10,
        children: [
          AppSegmentedTabs(
            labels: [for (final band in TimeBucket.values) bandLabel(band)],
            selectedIndex: _band.index,
            onSelected: _showBand,
            hugContent: true,
            padding: EdgeInsets.zero,
            height: dense ? 40 : 44,
            fontSize: dense ? 13.5 : 14,
          ),
          _buildDayNav(dense),
        ],
      ),
    );
  }

  Widget? _buildStatus(TeacherHoursBand data)
  {
    return switch (data.status)
    {
      TeacherHoursStatus.live => const BandStatePill(label: kLiveStatus, accent: AppTheme.trialTealDeep, surface: Colors.white),
      TeacherHoursStatus.ready => const BandStatePill(
          label: kReadyStatus,
          accent: AppTheme.modifiedAccent,
          surface: AppTheme.trialGoldSurface,
        ),
      TeacherHoursStatus.confirmed => const BandStatePill(
          label: kConfirmedStatus,
          icon: Icons.check_rounded,
          accent: AppTheme.trialTealDeep,
          surface: AppTheme.todaySurface,
        ),
      _ => null,
    };
  }

  Widget _buildHeading(TeacherHoursBand data, bool dense)
  {
    final Widget? status = _buildStatus(data);

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              teachersCount(data.rows.length),
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: dense ? 15 : 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
          ?status,
        ],
      ),
    );
  }

  Widget _buildButton(TeacherHoursBand data)
  {
    final int? lastEnd = data.lastEnd;

    final Widget button = switch (data.status)
    {
      TeacherHoursStatus.confirmed => AppGradientButton(
          label: kEditHours,
          icon: Icons.edit_rounded,
          width: _confirmWidth,
          height: 50,
          fontSize: 14,
          busy: _busy,
          onPressed: () => unawaited(_write(() => _api.reopenTeacherHours(_day, _band))),
        ),
      TeacherHoursStatus.ready => AppGradientButton(
          label: kConfirmHours,
          icon: Icons.check_rounded,
          width: _confirmWidth,
          height: 50,
          fontSize: 14,
          busy: _busy,
          onPressed: () => unawaited(_write(() => _api.confirmTeacherHours(_day, _band))),
        ),
      _ => AppGradientButton(
          label: kConfirmHours,
          icon: Icons.check_rounded,
          width: _confirmWidth,
          height: 50,
          fontSize: 14,
          disabledReason: lastEnd == null ? null : confirmFrom(lastEnd),
          onPressed: () {},
        ),
    };

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 12,
      children: [
        button,
        AppGradientButton(
          label: kExportPdf,
          icon: Icons.picture_as_pdf_outlined,
          width: _confirmWidth,
          height: 50,
          fontSize: 14,
          busy: _exporting,
          onPressed: () => unawaited(_exportPdf()),
        ),
      ],
    );
  }

  // The server takes nobody written by hand into a band still to come.
  bool get _bandBegun
  {
    final DateTime start = DateTime(_day.year, _day.month, _day.day, 0, bandStartMinutes(_band));

    return !romeNow().isBefore(start);
  }

  // Somebody may have come in for something else, in a band with nothing planned or still under way.
  Widget _buildAddButton()
  {
    return AppAddRowButton(
      label: kAddTeacher,
      dense: true,
      alignment: Alignment.center,
      onTap: () => unawaited(_addTeacher()),
    );
  }

  Widget _buildBody(TeacherHoursBand data, bool dense)
  {
    if (data.status == TeacherHoursStatus.empty)
    {
      return AppEmptyRoom(
        card: const AppEmptyCard(icon: Icons.event_note_rounded, message: kNothingPlanned),
        below: [if (_bandBegun) _buildAddButton()],
      );
    }

    final int? firstEnd = data.firstEnd;

    if (data.status == TeacherHoursStatus.waiting)
    {
      return AppEmptyRoom(
        card: AppEmptyCard(
          icon: Icons.schedule_rounded,
          message: kNothingOver,
          detail: firstEnd == null ? null : firstEndsAt(firstEnd),
        ),
        below: [if (_bandBegun) _buildAddButton()],
      );
    }

    // Each block runs in after the one above it, as on the other pages.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.header, child: _buildHeading(data, dense)),
        const SizedBox(height: kPageHeadingGap),
        Expanded(
          child: PageTransitionScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.list,
                    child: IgnorePointer(
                      // A change made while another is being saved would be lost: none is taken meanwhile.
                      ignoring: _busy,
                      child: TeacherHoursTable(
                        band: data,
                        editable: !data.isConfirmed,
                        firstMinute: bandStartMinutes(_band),
                        lastMinute: bandEndMinutes(_band),
                        onWork: _editWork,
                        onVolunteer: _editVolunteer,
                        onAction: _act,
                        onAddTeacher: () => unawaited(_addTeacher()),
                        onOpenTeacher: _openTeacher,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  PageTransitionItem(slot: PageTransitionItem.list + 1, child: _buildButton(data)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final TeacherHoursBand? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final TeacherHoursBand band, _) => _buildBody(band, dense),
      _ => const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _buildNav(dense)),
        SizedBox(height: dense ? 14 : 18),
        Expanded(child: body),
      ],
    );
  }
}
