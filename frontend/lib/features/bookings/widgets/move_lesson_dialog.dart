import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/booking_wizard_strings.dart' show hoursOverlap;
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/band_schedule.dart';
import '../bookings_tour.dart';

const double _width = 560;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;


class MoveOption
{
  final String mode;
  final TimeBucket band;

  final PresenceItem? slot;

  final OpeningWindow? window;

  final int needed;

  final String? refusal;

  const MoveOption({
    required this.mode,
    required this.band,
    required this.slot,
    required this.window,
    required this.needed,
    this.refusal,
  });

  bool get isNew => slot == null;

  bool get asksHours
  {
    final PresenceItem? row = slot;

    return row == null || minutesOfTimeOfDay(row.endTime) - minutesOfTimeOfDay(row.startTime) < needed;
  }

  String get label
  {
    final PresenceItem? row = slot;

    if (row == null)
    {
      return '${modeLabel(mode)} · ${bandLabel(band).toLowerCase()}';
    }

    return '${modeLabel(mode)} · ${formatTimeRange(row.startTime, row.endTime)}';
  }
}

class MoveDay
{
  final DateTime day;

  final List<MoveOption> options;

  final String? refusal;

  const MoveDay({required this.day, required this.options, this.refusal});

  bool get viable => refusal == null && options.any((option) => option.refusal == null);
}

const String kMoveDayLabel = 'Giorno';
const String kMoveTargetLabel = 'Sposta in';
const String kMoveAddHours = 'Aggiungi gli orari.';
const String kMoveStretchHours = 'La presenza non copre tutte le lezioni: allunga gli orari.';

String moveNothingChosen(int count) => 'Scegli dove spostare ${count == 1 ? 'la lezione' : 'le lezioni'}.';

// The row's own hours where it has them, stretched to [needed] and clamped inside [window].
(TimeOfDay, TimeOfDay) moveHoursFor(OpeningWindow window, int needed, {PresenceItem? row})
{
  int start = row == null ? window.startMinutes : minutesOfTimeOfDay(row.startTime);
  int end = row == null ? start + needed : minutesOfTimeOfDay(row.endTime);

  start = start.clamp(window.startMinutes, window.endMinutes);
  end = end.clamp(start, window.endMinutes);

  if (end - start < needed)
  {
    end = (start + needed).clamp(start, window.endMinutes);
    start = (end - needed).clamp(window.startMinutes, end);
  }

  return (timeOfDayFromMinutes(start), timeOfDayFromMinutes(end));
}

String moveTooShort(int needed) => 'Le ore devono coprire le lezioni (${formatMinutes(needed)}).';

// Starts from the row's hours as the band's only stretch; a grown row keeps its stretch.
BandSchedule<PresenceItem> moveScheduleFor(MoveOption option)
{
  final BandSchedule<PresenceItem> schedule = BandSchedule<PresenceItem>();
  final OpeningWindow? window = option.window;

  if (option.asksHours && window != null)
  {
    final (start, end) = moveHoursFor(window, option.needed, row: option.slot);

    schedule.addStored(option.band, BandStretch(startTime: start, endTime: end, existing: option.slot));
  }

  return schedule;
}

// Why the hours cannot go, or null.
String? moveHoursRefusal(BandSchedule<PresenceItem> schedule, MoveOption option)
{
  if (schedule.overlapping != null)
  {
    return hoursOverlap(option.mode, option.band);
  }

  if (schedule.minutesIn(option.band) < option.needed)
  {
    return moveTooShort(option.needed);
  }

  return null;
}

// As the planner takes them: touching stretches as one, the row grown first.
List<(TimeOfDay, TimeOfDay)> moveHoursOf(BandSchedule<PresenceItem> schedule, TimeBucket band)
{
  final List<BandStretch<PresenceItem>> stretches = schedule.fused().of(band);

  return [
    for (final stretch in [
      ...stretches.where((stretch) => stretch.existing != null),
      ...stretches.where((stretch) => stretch.existing == null),
    ])
      (stretch.startTime, stretch.endTime),
  ];
}

Widget _hint(String text)
{
  return Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: AppTheme.trialMutedText,
    ),
  );
}

Widget _footer({required VoidCallback onMove})
{
  return AppDialogFooter.single(
    DesktopTourTarget(
      id: kTourBookingsMoveConfirm,
      child: AppGradientButton(
        label: 'SPOSTA',
        icon: Icons.swap_horiz_rounded,
        height: _buttonHeight,
        fontSize: _buttonFontSize,
        onPressed: onMove,
      ),
    ),
  );
}

class MoveLessonDialog extends StatefulWidget
{
  final DateTime day;
  final String title;

  final int count;

  final List<MoveDay> days;

  // [hours] is empty unless hours were asked.
  final void Function(MoveDay day, MoveOption option, List<(TimeOfDay, TimeOfDay)> hours) onMove;

  const MoveLessonDialog({
    super.key,
    required this.day,
    required this.title,
    this.count = 1,
    required this.days,
    required this.onMove,
  });

  @override
  State<MoveLessonDialog> createState() => _MoveLessonDialogState();
}

class _MoveLessonDialogState extends State<MoveLessonDialog>
{
  MoveDay? _day;
  MoveOption? _chosen;

  BandSchedule<PresenceItem> _hours = BandSchedule<PresenceItem>();

  // Set once a tour start is scheduled for the next frame; later changes add none.
  bool _toursAsked = false;

  @override
  void initState()
  {
    super.initState();

    desktopTourLit.addListener(_onTourLit);
    _startTours();

    for (final day in widget.days)
    {
      if (isSameDate(day.day, widget.day) && day.refusal == null)
      {
        _day = day;

        return;
      }
    }

    for (final day in widget.days)
    {
      if (day.viable)
      {
        _day = day;

        return;
      }
    }
  }

  @override
  void dispose()
  {
    desktopTourLit.removeListener(_onTourLit);
    super.dispose();
  }

  void _startTours()
  {
    WidgetsBinding.instance.addPostFrameCallback((_) async
    {
      if (!mounted || isDesktopTourShown)
      {
        return;
      }

      final DesktopTour? tour = await bookingsMoveTour(
            hoursMayCome: () => _chosen == null && (_day?.options.any((option) => option.refusal == null && _asks(option)) ?? false),
          ) ??
          await bookingsLateMoveTour();

      if (tour != null && mounted)
      {
        startBookingsTour(context, tour);
      }
    });

    WidgetsBinding.instance.scheduleFrame();
  }

  // After a change, at once: the tour waits for a drag to end, clicks held back meanwhile.
  void _startToursSoon()
  {
    if (_toursAsked)
    {
      return;
    }

    _toursAsked = true;

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      _toursAsked = false;
      _startTours();
    });

    WidgetsBinding.instance.scheduleFrame();
  }

  void _onTourLit()
  {
    if (mounted && desktopTourLit.value.isEmpty)
    {
      _startTours();
    }
  }

  // Told after the frame: the step after a pick must find the hours drawn.
  void _tellPicked()
  {
    WidgetsBinding.instance.addPostFrameCallback((_) => bookingsMovePicked.value++);
    WidgetsBinding.instance.scheduleFrame();
    _startToursSoon();
  }

  void _chooseDay(MoveDay day)
  {
    setState(()
    {
      _day = day;
      _chosen = null;
      _hours = BandSchedule<PresenceItem>();
    });

    _tellPicked();
  }

  void _choose(MoveOption? option)
  {
    setState(()
    {
      _chosen = option;
      _hours = option == null ? BandSchedule<PresenceItem>() : moveScheduleFor(option);
    });

    _tellPicked();
  }

  bool _asks(MoveOption option) => option.asksHours && option.window != null;

  String? get _blockedReason
  {
    final MoveDay? day = _day;

    final MoveOption? chosen = _chosen;

    if (day == null || chosen == null)
    {
      return moveNothingChosen(widget.count);
    }

    return _asks(chosen) ? moveHoursRefusal(_hours, chosen) : null;
  }

  List<Widget> _buildOptions(List<MoveOption> options)
  {
    final MoveOption? chosen = _chosen;
    final OpeningWindow? window = chosen?.window;

    return [
      const AppFieldLabel(kMoveTargetLabel),
      const SizedBox(height: 12),
      DesktopTourTarget(
        id: kTourBookingsMoveOptions,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final option in options)
              AppSelectableChip(
                label: option.label,
                selected: identical(chosen, option),
                enabled: option.refusal == null,
                disabledTooltip: option.refusal,
                onSelected: (selected) => _choose(selected ? option : null),
              ),
          ],
        ),
      ),
      if (chosen != null && _asks(chosen) && window != null) ...[
        const SizedBox(height: 20),
        _hint(chosen.isNew ? kMoveAddHours : kMoveStretchHours),
        const SizedBox(height: 12),
        BandScheduleField<PresenceItem>(
          schedule: _hours,
          windowFor: (band) => band == chosen.band ? window : null,
          bands: [chosen.band],
          fixed: true,
          onChanged: ()
          {
            setState(() {});
            _startToursSoon();
          },
          tour: (yesNo: kTourBookingsSwitch, hours: kTourBookingsHours, add: kTourBookingsHoursAdd, bin: kTourBookingsHoursBin),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final MoveDay? day = _day;
    final MoveOption? chosen = _chosen;

    return AppDialogStack(
      eyebrow: formatAvailableDayLabel(widget.day),
      title: widget.title,
      shrinkTitle: true,
      maxWidth: _width,
      footer: _footer(
        onMove: ()
        {
          final String? reason = _blockedReason;

          if (reason != null)
          {
            CustomSnackBar.show(context: context, message: reason, isError: true);

            return;
          }

          if (day != null && chosen != null)
          {
            widget.onMove(day, chosen, _asks(chosen) ? moveHoursOf(_hours, chosen.band) : const []);
          }
        },
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppFieldLabel(kMoveDayLabel),
              const SizedBox(height: 12),
              DesktopTourTarget(
                id: kTourBookingsMoveDays,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final option in widget.days)
                      AppSelectableChip(
                        label: formatAvailableDayShortLabel(option.day),
                        selected: identical(day, option),
                        enabled: option.refusal == null,
                        disabledTooltip: option.refusal,
                        onSelected: (_) => _chooseDay(option),
                      ),
                  ],
                ),
              ),
              if (day != null) ...[
                const SizedBox(height: 20),
                ..._buildOptions(day.options),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
