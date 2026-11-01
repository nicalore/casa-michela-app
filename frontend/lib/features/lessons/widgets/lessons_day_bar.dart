import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/utils/day_marks.dart';
import '../../../shared/widgets/app_calendar_button.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart';

const double _titleSize = 21;
const double _noteSize = 16;
const double _dayLabelWidth = 250;
const double _denseDayLabelWidth = 200;
const double _underlineGap = 10;
const double _sidePadding = 4;

const double _noteGap = 16;
const double _navGap = 16;

// The Lezioni page's and its calendar's names, and what they show beside them on one baseline.
TextStyle get lessonsHeadingStyle => GoogleFonts.plusJakartaSans(
  fontSize: _titleSize,
  fontWeight: FontWeight.w700,
  height: 1.2,
  color: AppTheme.trialOcean,
);

TextStyle get lessonsHeadingNoteStyle => GoogleFonts.plusJakartaSans(
  fontSize: _noteSize,
  fontWeight: FontWeight.w600,
  height: 1.3,
  color: AppTheme.trialMutedText,
);

// The Lezioni page's heading: its name, the day's figures, the day chosen with the arrows or the month.
class LessonsDayBar extends StatelessWidget
{
  final DateTime day;
  final DateTime today;

  final String? note;

  final ValueChanged<DateTime> onDay;

  final DayMarksLoader? loadMarks;

  // While a day is read: the arrows wait.
  final bool busy;

  const LessonsDayBar({
    super.key,
    required this.day,
    required this.today,
    required this.onDay,
    this.note,
    this.loadMarks,
    this.busy = false,
  });

  Widget _buildNav(BuildContext context, {required bool stretched})
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final double button = dense ? 36 : CarouselArrowButton.defaultSize;
    final bool isFirstDay = !day.isAfter(oldestKeptDay(today));

    final Widget label = Text(
      '${formatWeekdayColumnLabel(day)} ${day.year}',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    return Row(
      mainAxisSize: stretched ? MainAxisSize.max : MainAxisSize.min,
      children: [
        AppCalendarButton(
          selected: day,
          today: today,
          first: oldestKeptDay(today),
          last: calendarHorizon(today),
          onPicked: onDay,
          loadMarks: loadMarks,
          size: button,
        ),
        SizedBox(width: dense ? 8 : 12),
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          isDisabled: isFirstDay || busy,
          size: button,
          onTap: () => onDay(addDays(day, -1)),
        ),
        SizedBox(width: dense ? 6 : 8),
        if (stretched)
          Expanded(child: Center(child: label))
        else
          SizedBox(width: dense ? _denseDayLabelWidth : _dayLabelWidth, child: Center(child: label)),
        SizedBox(width: dense ? 6 : 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          isDisabled: busy,
          size: button,
          onTap: () => onDay(addDays(day, 1)),
        ),
      ],
    );
  }

  // As a Text draws it here: the ambient style and the text scale count.
  static double _textWidth(BuildContext context, String text, TextStyle style)
  {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final width = painter.width;

    painter.dispose();

    return width.ceilToDouble() + 2;
  }

  static double _navWidth(bool dense)
  {
    return dense
        ? 36 + 8 + 36 + 6 + _denseDayLabelWidth + 6 + 36
        : 3 * CarouselArrowButton.defaultSize + 12 + 8 + _dayLabelWidth + 8;
  }

  @override
  Widget build(BuildContext context)
  {
    final String? note = this.note;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        // The name, the figures whole and the arrows on one line while they fit; else the arrows go under.
        final double named = _textWidth(context, 'Lezioni', lessonsHeadingStyle) +
            (note == null ? 0 : _noteGap + _textWidth(context, note, lessonsHeadingNoteStyle));
        final double room = constraints.maxWidth - 2 * _sidePadding;
        final bool oneLine = named + _navGap + _navWidth(AppBreakpoints.of(context).isDense) <= room;
        final bool stretched = AppBreakpoints.of(context).isMinimal;

        final Widget title = Text('Lezioni', maxLines: 1, style: lessonsHeadingStyle);

        // One paragraph: two would each be rounded to the pixel on their own and miss each other's baseline.
        final Widget titled = note == null
            ? title
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Lezioni', style: lessonsHeadingStyle),
                    const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox(width: _noteGap)),
                    TextSpan(text: note, style: lessonsHeadingNoteStyle),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              );

        final Widget heading = oneLine
            ? Row(
                children: [
                  Expanded(child: titled),
                  const SizedBox(width: _navGap),
                  _buildNav(context, stretched: false),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The figures beside the name while they fit whole, else whole on the line under it.
                  if (note == null || named <= room)
                    titled
                  else ...[
                    title,
                    const SizedBox(height: 4),
                    Text(note, style: lessonsHeadingNoteStyle),
                  ],
                  const SizedBox(height: 10),
                  stretched
                      ? _buildNav(context, stretched: true)
                      : Align(alignment: Alignment.centerRight, child: _buildNav(context, stretched: false)),
                ],
              );

        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.closedLine)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_sidePadding, 0, _sidePadding, _underlineGap),
            child: heading,
          ),
        );
      },
    );
  }
}

enum LessonsBandState
{
  closed,

  // Open, but no pupil has asked for it: nothing to compose, so it does not open.
  empty,

  // Not published yet: requests may be left to plan.
  open,

  draft,

  published,
}

typedef LessonsBandEntry = ({TimeBucket band, String? hours, LessonsBandState state, int toPlan});

// The heading beside the bands, and a day's «Non modificabile» after them.
const double _headingRoom = 128;
const double _trailingRoom = 168;

// A button writes its state in full from this width, its count or icon alone down to the next.
const double _fullButtonMin = 350;
const double _tightButtonMin = 205;

// The day's three bands, each opening its calendar.
class LessonsBandButtons extends StatelessWidget
{
  final List<LessonsBandEntry> bands;

  final ValueChanged<TimeBucket> onOpen;

  // Beside the bands, as a day that can no longer change says it.
  final Widget? trailing;

  const LessonsBandButtons({super.key, required this.bands, required this.onOpen, this.trailing});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final double gap = dense ? 10 : 14;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final Widget? trailing = this.trailing;

        // Narrow: the heading over the buttons.
        final bool beside = constraints.maxWidth >= 760;

        // The room each button gets on one row: its full state, its count or icon alone, or a line each.
        final double row = constraints.maxWidth - (beside ? _headingRoom + (trailing == null ? 0 : _trailingRoom) : 0);
        final double each = (row - (bands.length - 1) * gap) / bands.length;
        final bool tight = each < _fullButtonMin;
        final bool stacked = each < _tightButtonMin;

        final Widget heading = Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Calendario'.toUpperCase(), maxLines: 1, style: PageHeading.style()),
        );

        Widget button(LessonsBandEntry entry) =>
            _BandButton(entry: entry, tight: tight && !stacked, onOpen: () => onOpen(entry.band));

        final Widget buttons = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, entry) in bands.indexed) ...[
                    if (i > 0) SizedBox(height: gap / 2),
                    button(entry),
                  ],
                ],
              )
            : Row(
                children: [
                  for (final (i, entry) in bands.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(child: button(entry)),
                  ],
                ],
              );

        if (beside)
        {
          return Row(
            children: [
              SizedBox(width: _headingRoom - 16, child: heading),
              const SizedBox(width: 16),
              Expanded(child: buttons),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                SizedBox(width: _trailingRoom - 16, child: Align(alignment: Alignment.centerRight, child: trailing)),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: heading),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            buttons,
          ],
        );
      },
    );
  }
}

class _BandButton extends StatefulWidget
{
  final LessonsBandEntry entry;
  final VoidCallback onOpen;

  // Short of room: the count alone, or an icon for the state.
  final bool tight;

  const _BandButton({required this.entry, required this.onOpen, this.tight = false});

  @override
  State<_BandButton> createState() => _BandButtonState();
}

class _BandButtonState extends State<_BandButton>
{
  bool _hover = false;

  // Shut or asked nothing of: dimmed, and it opens nothing.
  bool get _closed => widget.entry.state == LessonsBandState.closed || widget.entry.state == LessonsBandState.empty;

  static const String _nobodyBooked = 'Nessuna prenotazione';

  TextStyle get _mutedStyle =>
      GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  Widget? _buildState()
  {
    final entry = widget.entry;
    final bool tight = widget.tight;

    return switch (entry.state)
    {
      LessonsBandState.closed => Text('Chiuso', maxLines: 1, style: _mutedStyle),
      // Short of room the words go to a tooltip over the whole button.
      LessonsBandState.empty when tight => null,
      LessonsBandState.empty => Text(_nobodyBooked, maxLines: 1, style: _mutedStyle),
      LessonsBandState.open when entry.toPlan == 0 => null,
      LessonsBandState.open when tight => _CountBadge(count: entry.toPlan),
      LessonsBandState.open => _StatePill(
          label: 'DA PIANIFICARE',
          accent: AppTheme.modifiedAccent,
          surface: AppTheme.trialGoldSurface,
          count: entry.toPlan,
        ),
      LessonsBandState.draft when tight => const Icon(Icons.edit_outlined, size: 18, color: AppTheme.modifiedAccent),
      LessonsBandState.draft => const _StatePill(
          label: 'IN BOZZA',
          icon: Icons.edit_outlined,
          accent: AppTheme.modifiedAccent,
          surface: AppTheme.modifiedAccentSurface,
        ),
      LessonsBandState.published when tight =>
        const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.trialTealDeep),
      LessonsBandState.published => const _StatePill(
          label: 'PUBBLICATO',
          icon: Icons.check_circle_outline_rounded,
          accent: AppTheme.trialTealDeep,
          surface: AppTheme.todaySurface,
        ),
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final entry = widget.entry;
    final bool lit = _hover && !_closed;
    final Widget? state = _buildState();

    // The name over its hours: the state never squeezes them.
    final Widget face = Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bandLabel(entry.band),
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: dense ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: _closed ? AppTheme.trialMutedText : AppTheme.trialInk,
                ),
              ),
              if (entry.hours case final hours?)
                Text(
                  hours,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: dense ? 11.5 : 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppTheme.trialMutedText,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ?state,
        if (!_closed) ...[
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_rounded, size: 20, color: AppTheme.trialTealDeep),
        ],
      ],
    );

    final Widget button = MouseRegion(
      cursor: _closed ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _closed ? null : widget.onOpen,
        // Sized outside the animation: only the border's colour fades, the face stays white.
        child: SizedBox(
          height: dense ? 44 : 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.only(left: 18, right: 12),
            decoration: BoxDecoration(
              color: _closed ? Colors.white.withValues(alpha: 0.45) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lit ? AppTheme.trialGold : AppTheme.trialLine, width: 1.5),
              boxShadow: _closed ? null : AppTheme.cardShadow,
            ),
            child: face,
          ),
        ),
      ),
    );

    if (entry.state != LessonsBandState.empty || !widget.tight)
    {
      return button;
    }

    return AppTooltip(
      message: _nobodyBooked,
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      child: button,
    );
  }
}

class _CountBadge extends StatelessWidget
{
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: AppTheme.trialGold, borderRadius: BorderRadius.circular(8)),
      child: Text(
        '$count',
        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, height: 1.3, color: Colors.white),
      ),
    );
  }
}

class _StatePill extends StatelessWidget
{
  final String label;
  final IconData? icon;
  final Color accent;
  final Color surface;
  final int? count;

  const _StatePill({required this.label, required this.accent, required this.surface, this.icon, this.count});

  @override
  Widget build(BuildContext context)
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 1.2,
      color: accent,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 5),
          ],
          Text(label, maxLines: 1, style: style),
          if (count case final count?) ...[
            const SizedBox(width: 6),
            _CountBadge(count: count),
          ],
        ],
      ),
    );
  }
}
