import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/bookings/widgets/move_lesson_dialog.dart';
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_time_field.dart';
import 'mobile_booking_parts.dart';

const Duration _move = Duration(milliseconds: 200);

typedef MobileMoveChoice = ({MoveDay day, MoveOption option, TimeOfDay? start, TimeOfDay? end});

Future<MobileMoveChoice?> showMobileMoveSheet({
  required BuildContext context,
  required DateTime from,
  required String title,
  String? subtitle,
  required int count,
  required List<MoveDay> days,
})
{
  return showMobileSheet<MobileMoveChoice>(
    context: context,
    builder: (context) => _MoveSheet(from: from, title: title, subtitle: subtitle, count: count, days: days),
  );
}

class _MoveSheet extends StatefulWidget
{
  final DateTime from;
  final String title;
  final String? subtitle;
  final int count;
  final List<MoveDay> days;

  const _MoveSheet({
    required this.from,
    required this.title,
    this.subtitle,
    required this.count,
    required this.days,
  });

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet>
{
  MoveDay? _day;
  MoveOption? _chosen;

  int? _start;
  int? _end;

  @override
  void initState()
  {
    super.initState();

    _day = widget.days.where((day) => isSameDate(day.day, widget.from) && day.refusal == null).firstOrNull ??
        widget.days.where((day) => day.viable).firstOrNull;
  }

  void _chooseDay(MoveDay day)
  {
    final String? refusal = day.refusal;

    if (refusal != null)
    {
      MobileNotice.show(context, refusal, error: true);

      return;
    }

    setState(()
    {
      _day = day;
      _chosen = null;
      _start = null;
      _end = null;
    });
  }

  void _choose(MoveOption option)
  {
    final String? refusal = option.refusal;

    if (refusal != null)
    {
      MobileNotice.show(context, refusal, error: true);

      return;
    }

    setState(()
    {
      _chosen = option;
      _start = null;
      _end = null;

      final OpeningWindow? window = option.window;

      if (option.asksHours && window != null)
      {
        final (start, end) = moveHoursFor(window, option.needed, row: option.slot);

        _start = minutesOfTimeOfDay(start);
        _end = minutesOfTimeOfDay(end);
      }
    });
  }

  void _confirm()
  {
    final MoveDay? day = _day;
    final MoveOption? chosen = _chosen;

    if (day == null || chosen == null)
    {
      MobileNotice.show(context, moveNothingChosen(widget.count), error: true);

      return;
    }

    final int? start = _start;
    final int? end = _end;

    if (chosen.asksHours && (start == null || end == null || end - start < chosen.needed))
    {
      MobileNotice.show(context, moveTooShort(chosen.needed), error: true);

      return;
    }

    finishMobileSheet<MobileMoveChoice>(context, (
      day: day,
      option: chosen,
      start: start == null ? null : timeOfDayFromMinutes(start),
      end: end == null ? null : timeOfDayFromMinutes(end),
    ));
  }

  Widget _buildDay(MoveDay day)
  {
    final bool chosen = identical(day, _day);
    final bool off = day.refusal != null;

    final Color rest = off ? AppTheme.trialInk.withValues(alpha: 0.04) : Colors.white;
    final Color ink = chosen ? Colors.white : (off ? AppTheme.trialInk.withValues(alpha: 0.3) : AppTheme.trialInk);

    return Semantics(
      button: true,
      selected: chosen,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _chooseDay(day),
        child: AnimatedContainer(
          duration: _move,
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            gradient: mobileSelectFill(rest, chosen ? 1 : 0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: chosen ? AppTheme.trialTealDeep.withValues(alpha: 0) : AppTheme.trialInk.withValues(alpha: off ? 0 : 0.12),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                weekdayShortName(day.day.weekday).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: chosen ? Colors.white.withValues(alpha: 0.8) : (off ? ink : MobilePalette.mutedText),
                  decoration: off ? TextDecoration.lineThrough : null,
                  decorationThickness: MobilePalette.strikeThickness,
                  decorationColor: ink,
                ),
              ),
              Text(
                '${day.day.day}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  decoration: off ? TextDecoration.lineThrough : null,
                  decorationThickness: MobilePalette.strikeThickness,
                  decorationColor: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(MoveOption option)
  {
    final bool off = option.refusal != null;

    if (!off)
    {
      return MobileSelectChip(label: option.label, selected: identical(option, _chosen), onTap: () => _choose(option));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _choose(option),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: AppTheme.trialInk.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Align(
          widthFactor: 1,
          child: Text(
            option.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialInk.withValues(alpha: 0.35),
              decoration: TextDecoration.lineThrough,
              decorationThickness: MobilePalette.strikeThickness,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHours(MoveOption option, OpeningWindow window)
  {
    final int start = _start ?? window.startMinutes;
    final int end = _end ?? window.endMinutes;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.06)),
        boxShadow: const [BoxShadow(color: Color(0x14122438), offset: Offset(0, 6), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Text(
                  bandLabel(option.band).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: MobilePalette.mutedText,
                  ),
                ),
                const Spacer(),
                Icon(lessonModeIcon(option.mode), size: 15, color: MobilePalette.mutedText),
                const SizedBox(width: 4),
                Text(
                  formatMinutesRange(window.startMinutes, window.endMinutes),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: MobilePalette.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, margin: const EdgeInsets.only(top: 4, bottom: 12), color: AppTheme.trialInk.withValues(alpha: 0.08)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MobileTimeField(
                  label: 'Dalle',
                  minutes: start,
                  min: window.startMinutes,
                  max: end - kMinimumBandMinutes,
                  onChanged: (value) => setState(() => _start = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MobileTimeField(
                  label: 'Alle',
                  minutes: end,
                  min: start + kMinimumBandMinutes,
                  max: window.endMinutes,
                  onChanged: (value) => setState(() => _end = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MoveDay? day = _day;
    final MoveOption? chosen = _chosen;
    final OpeningWindow? window = chosen?.window;

    return MobileSheet(
      eyebrow: formatAvailableDayLabel(widget.from),
      title: widget.title,
      subtitle: widget.subtitle,
      aboveKeyboard: true,
      body: [
        const SizedBox(height: 18),
        const MobileFieldHead(kMoveDayLabel),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [for (final option in widget.days) _buildDay(option)],
        ),
        AnimatedSize(
          duration: _move,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          child: day == null
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const MobileFieldHead(kMoveTargetLabel),
                    Wrap(
                      spacing: kMobileChipGap,
                      runSpacing: kMobileChipGap,
                      children: [for (final option in day.options) _buildOption(option)],
                    ),
                  ],
                ),
        ),
        _Unfold(
          child: chosen != null && chosen.asksHours && window != null
              ? Column(
                  key: const ValueKey('hours'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    MobileQuietLine(chosen.isNew ? kMoveAddHours : kMoveStretchHours),
                    _buildHours(chosen, window),
                  ],
                )
              : const SizedBox(key: ValueKey('none'), width: double.infinity),
        ),
        const SizedBox(height: 6),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobileGoldButton(label: 'Sposta', icon: Icons.swap_horiz_rounded, onPressed: _confirm),
      ),
    );
  }
}

// Unclipped, so the card keeps its shadow.
class _Unfold extends StatelessWidget
{
  final Widget child;

  const _Unfold({required this.child});

  @override
  Widget build(BuildContext context)
  {
    return AnimatedSwitcher(
      duration: _move,
      switchInCurve: Curves.easeOutCubic,
      // Runs on a reversing value: easeIn here eases the fold out in time.
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Align(alignment: Alignment.topCenter, heightFactor: animation.value, child: child),
        child: child,
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}
