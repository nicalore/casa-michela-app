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
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../lessons/models/presence_item.dart';
import '../../lessons/utils/booking_window.dart';
import '../../lessons/utils/opening_window.dart';

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

// The row's own hours where it has them, stretched to [needed] and clamped inside [window].
(TimeOfDay, TimeOfDay) _hoursFor(OpeningWindow window, int needed, {PresenceItem? row})
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

String _tooShort(int needed) => 'Le ore devono coprire le lezioni (${formatMinutes(needed)}).';

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

Widget _slider({
  required TimeBucket band,
  required OpeningWindow window,
  required TimeOfDay? start,
  required TimeOfDay? end,
  required void Function(TimeOfDay? start, TimeOfDay? end) onChanged,
})
{
  return BandTimeRangeSlider(
    bucket: band,
    startTime: start,
    endTime: end,
    windowStartMinutes: window.startMinutes,
    windowEndMinutes: window.endMinutes,
    minimumMinutes: kMinimumBandMinutes,
    trailing: const SizedBox.shrink(),
    onChanged: onChanged,
  );
}

int _minutesBetween(TimeOfDay? start, TimeOfDay? end)
{
  if (start == null || end == null)
  {
    return 0;
  }

  return minutesOfTimeOfDay(end) - minutesOfTimeOfDay(start);
}

Widget _footer({required String? blockedReason, required VoidCallback onMove})
{
  return AppDialogFooter.single(
    AppGradientButton(
      label: 'SPOSTA',
      icon: Icons.swap_horiz_rounded,
      height: _buttonHeight,
      fontSize: _buttonFontSize,
      disabledReason: blockedReason,
      onPressed: onMove,
    ),
  );
}

class MoveLessonDialog extends StatefulWidget
{
  final DateTime day;
  final String title;

  final int count;

  final List<MoveDay> days;

  // start and end are null unless hours were asked.
  final void Function(MoveDay day, MoveOption option, TimeOfDay? start, TimeOfDay? end) onMove;

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

  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState()
  {
    super.initState();

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

  void _chooseDay(MoveDay day)
  {
    setState(()
    {
      _day = day;
      _chosen = null;
      _start = null;
      _end = null;
    });
  }

  void _choose(MoveOption? option)
  {
    setState(()
    {
      _chosen = option;
      _start = null;
      _end = null;

      final OpeningWindow? window = option?.window;

      if (option != null && option.asksHours && window != null)
      {
        final (start, end) = _hoursFor(window, option.needed, row: option.slot);

        _start = start;
        _end = end;
      }
    });
  }

  String get _what => widget.count == 1 ? 'la lezione' : 'le lezioni';

  String? get _blockedReason
  {
    final MoveDay? day = _day;

    final MoveOption? chosen = _chosen;

    if (day == null || chosen == null)
    {
      return 'Scegli dove spostare $_what.';
    }

    if (chosen.asksHours && _minutesBetween(_start, _end) < chosen.needed)
    {
      return _tooShort(chosen.needed);
    }

    return null;
  }

  List<Widget> _buildOptions(List<MoveOption> options)
  {
    final MoveOption? chosen = _chosen;
    final OpeningWindow? window = chosen?.window;

    return [
      const AppFieldLabel('Sposta in'),
      const SizedBox(height: 12),
      Wrap(
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
      if (chosen != null && chosen.asksHours && window != null) ...[
        const SizedBox(height: 20),
        _hint(chosen.isNew
            ? 'Aggiungi gli orari.'
            : 'La presenza non copre tutte le lezioni: allunga gli orari.'),
        const SizedBox(height: 12),
        _slider(
          band: chosen.band,
          window: window,
          start: _start,
          end: _end,
          onChanged: (start, end) => setState(()
          {
            _start = start;
            _end = end;
          }),
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
        blockedReason: _blockedReason,
        onMove: ()
        {
          if (day != null && chosen != null)
          {
            widget.onMove(day, chosen, _start, _end);
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
              const AppFieldLabel('Giorno'),
              const SizedBox(height: 12),
              Wrap(
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
