import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../../features/association/tabs/opening_hours/hours_strings.dart';
import '../../../../features/association/tabs/opening_hours/mode_hours_parts.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_hours_parts.dart';
import 'mobile_hours_table.dart';
import 'mobile_standard_hours_card.dart';

const double _radius = 22;

// Room for today's rim between the rows and the glass.
const double _weekInset = 10;

const Duration _slideDuration = Duration(milliseconds: 300);

class MobileHoursWeekTables extends StatefulWidget
{
  // Monday first; read while loading, so none of it shows until [weekReady].
  final List<CombinedDay> days;
  final bool weekReady;
  final String? weekFailure;

  final DateTime today;

  // Days outside are not kept or not generated yet.
  final DateTime first;
  final DateTime last;

  final StandardSchedule schedule;
  final bool scheduleReady;
  final String? scheduleFailure;

  final double gap;

  const MobileHoursWeekTables({
    super.key,
    required this.days,
    required this.weekReady,
    this.weekFailure,
    required this.today,
    required this.first,
    required this.last,
    required this.schedule,
    required this.scheduleReady,
    this.scheduleFailure,
    required this.gap,
  });

  @override
  State<MobileHoursWeekTables> createState() => _MobileHoursWeekTablesState();
}

class _MobileHoursWeekTablesState extends State<MobileHoursWeekTables> with SingleTickerProviderStateMixin
{
  late final AnimationController _slide;
  late final Animation<double> _eased;

  List<CombinedDay>? _shown;
  List<CombinedDay>? _leaving;
  bool _forward = true;

  @override
  void initState()
  {
    super.initState();

    _slide = AnimationController(vsync: this, duration: _slideDuration)..addStatusListener(_settle);
    _eased = CurvedAnimation(parent: _slide, curve: Curves.easeInOutCubic);
    _shown = widget.weekReady ? widget.days : null;
  }

  @override
  void didUpdateWidget(MobileHoursWeekTables old)
  {
    super.didUpdateWidget(old);

    if (widget.weekFailure != null)
    {
      _shown = null;
      _leaving = null;

      return;
    }

    if (!widget.weekReady)
    {
      return;
    }

    final List<CombinedDay>? shown = _shown;

    if (shown != null && !isSameDate(shown.first.date, widget.days.first.date))
    {
      _leaving = shown;
      _forward = widget.days.first.date.isAfter(shown.first.date);
      _slide.forward(from: 0);
    }

    _shown = widget.days;
  }

  @override
  void dispose()
  {
    _slide.dispose();

    super.dispose();
  }

  void _settle(AnimationStatus status)
  {
    if (status == AnimationStatus.completed && mounted)
    {
      setState(() => _leaving = null);
    }
  }

  MobileHoursTable get _table => const MobileHoursTable(tablet: true);

  String _weekLabel(DateTime date) => '${weekdayShortName(date.weekday)} ${date.day}';

  // Digits are tabular, so the widest weekday with any two-digit day is the widest label.
  double _weekLabelWidth(BuildContext context)
  {
    return _table.labelWidth(context, [for (var weekday = 1; weekday <= 7; weekday++) '${weekdayShortName(weekday)} 00']);
  }

  bool _isToday(List<CombinedDay> days, int index) => index >= 0 && index < days.length && isSameDate(days[index].date, widget.today);

  Widget? _reasons(CombinedDay day, {required bool past})
  {
    final List<(String, Color)> lines = [];

    for (final mode in kHoursModes)
    {
      final String? note = day.of(mode).note;

      if (note == null)
      {
        continue;
      }

      final int same = lines.indexWhere((line) => line.$1 == note);

      if (same >= 0)
      {
        lines[same] = (note, MobilePalette.mutedText);
      }
      else
      {
        lines.add((note, hoursInk(mode, past: past)));
      }
    }

    if (lines.isEmpty)
    {
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (note, ink)) in lines.indexed)
          Padding(
            padding: EdgeInsets.only(top: i > 0 ? 3 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(kVariationIcon, size: 15, color: ink),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _weekRow(List<CombinedDay> days, int index, double labelWidth)
  {
    final CombinedDay day = days[index];
    final bool past = day.date.isBefore(widget.today);
    final bool kept = !day.date.isBefore(widget.first) && !day.date.isAfter(widget.last);

    final List<Widget> cells;

    if (!kept)
    {
      cells = const [SizedBox.shrink()];
    }
    else if (day.isClosedAllDay)
    {
      cells = [_table.closed(decided: day.isOverrideClosedAllDay)];
    }
    else
    {
      cells = [
        for (final mode in kHoursModes)
          day.of(mode).isClosed
              ? _table.closed(decided: day.of(mode).isOverrideClosure)
              : _table.bands(mode, day.of(mode).bands, past: past, marked: day.of(mode).note == null),
      ];
    }

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _weekInset),
      child: _table.row(
        labelWidth: labelWidth,
        label: _table.label(_weekLabel(day.date), past: past || !kept),
        cells: cells,
        below: kept ? _reasons(day, past: past) : null,
      ),
    );

    final bool today = _isToday(days, index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Today's rim takes the place of the rules beside it.
        if (index > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _weekInset),
            child: _table.rule(hidden: today || _isToday(days, index - 1)),
          ),
        if (today)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            position: DecorationPosition.background,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MobilePalette.currentRim, width: MobilePalette.currentRimWidth),
              ),
              position: DecorationPosition.foreground,
              child: row,
            ),
          )
        else
          row,
      ],
    );
  }

  Widget _sliding(Widget Function(List<CombinedDay> days) build)
  {
    final List<CombinedDay>? shown = _shown;
    final List<CombinedDay>? leaving = _leaving;

    if (shown == null)
    {
      return const SizedBox.shrink();
    }

    if (leaving == null)
    {
      return build(shown);
    }

    final double side = _forward ? 1 : -1;

    return ClipRect(
      child: Stack(
        children: [
          SlideTransition(
            position: Tween<Offset>(begin: Offset.zero, end: Offset(-side, 0)).animate(_eased),
            child: build(leaving),
          ),
          SlideTransition(
            position: Tween<Offset>(begin: Offset(side, 0), end: Offset.zero).animate(_eased),
            child: build(shown),
          ),
        ],
      ),
    );
  }

  Widget _pair(Widget week, Widget standard)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _table.padding.left - _weekInset),
              child: week,
            ),
          ),
          SizedBox(width: widget.gap),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _table.padding.left),
              child: standard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget? cover)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(_radius),
      child: cover == null ? const SizedBox.expand() : Center(child: cover),
    );
  }

  Widget _message(String text)
  {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: MobilePalette.mutedText,
      ),
    );
  }

  Widget get _spinner
  {
    return const SizedBox.square(
      dimension: 26,
      child: CircularProgressIndicator(strokeWidth: 2.6, color: AppTheme.trialTealDeep),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MobileHoursTable table = _table;

    final String? weekFailure = widget.weekFailure;
    final Widget? weekCover = weekFailure != null ? _message(weekFailure) : (_shown == null ? _spinner : null);

    final String? scheduleFailure = widget.scheduleFailure;
    final Widget? standardCover = scheduleFailure != null
        ? _message(scheduleFailure)
        : !widget.scheduleReady
            ? _spinner
            : !hasStandardHours(widget.schedule)
                ? _message(kNoStandardHours)
                : null;

    final bool weekShown = weekCover == null;
    final bool standardShown = standardCover == null;

    // One label column for both, so the hours of either table stand in the same columns.
    final double labelWidth = [
      _weekLabelWidth(context),
      table.labelWidth(context, [for (var weekday = 1; weekday <= 7; weekday++) weekdayFullName(weekday)]),
    ].reduce(math.max);

    const Widget none = SizedBox.shrink();

    Widget weekPart(Widget child) => weekShown ? Padding(padding: const EdgeInsets.symmetric(horizontal: _weekInset), child: child) : none;
    Widget standardPart(Widget child) => standardShown ? child : none;

    final Widget rows = Padding(
      padding: EdgeInsets.only(top: table.padding.top, bottom: table.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pair(weekPart(table.head(labelWidth)), standardPart(table.head(labelWidth))),
          _pair(weekPart(table.rule(strong: true)), standardPart(table.rule(strong: true))),
          for (var index = 0; index < 7; index++)
            _pair(
              weekShown ? _sliding((days) => _weekRow(days, index, labelWidth)) : none,
              standardPart(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (index > 0) table.rule(),
                    standardRow(table, widget.schedule, index + 1, labelWidth),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _panel(weekCover)),
              SizedBox(width: widget.gap),
              Expanded(child: _panel(standardCover)),
            ],
          ),
        ),
        // Room for a cover when neither side has rows to show.
        ConstrainedBox(constraints: const BoxConstraints(minHeight: 180), child: rows),
      ],
    );
  }
}
