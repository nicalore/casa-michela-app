import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/bookings/widgets/move_lesson_dialog.dart';
import '../../../../features/lessons/models/presence_item.dart';
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/band_schedule.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_band_editor.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../mobile_bookings_tour.dart';
import 'mobile_booking_parts.dart';

const Duration _move = Duration(milliseconds: 200);

// A tour counts the hours as changed once they rest this long.
const Duration _hoursRest = Duration(milliseconds: 700);

const EdgeInsets _tourInflate = EdgeInsets.all(6);
const double _tourDaysRadius = 20;
const double _tourOptionsRadius = 25;
const EdgeInsets _tourButtonInflate = EdgeInsets.all(4);
const double _tourButtonRadius = 22;

// [hours]: the stretches in the band moved to, the row grown first; empty when none were asked.
typedef MobileMoveChoice = ({MoveDay day, MoveOption option, List<(TimeOfDay, TimeOfDay)> hours});

// [tourFor]: whose tour explains the sheet, null for none.
Future<MobileMoveChoice?> showMobileMoveSheet({
  required BuildContext context,
  required DateTime from,
  required String title,
  String? subtitle,
  required int count,
  required List<MoveDay> days,
  String? tourFor,
})
{
  return showMobileSheet<MobileMoveChoice>(
    context: context,
    builder: (context) => _MoveSheet(
      from: from,
      title: title,
      subtitle: subtitle,
      count: count,
      days: days,
      tourFor: tourFor,
    ),
  );
}

class _MoveSheet extends StatefulWidget
{
  final DateTime from;
  final String title;
  final String? subtitle;
  final int count;
  final List<MoveDay> days;
  final String? tourFor;

  const _MoveSheet({
    required this.from,
    required this.title,
    this.subtitle,
    required this.count,
    required this.days,
    required this.tourFor,
  });

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet>
{
  MoveDay? _day;
  MoveOption? _chosen;

  BandSchedule<PresenceItem> _hours = BandSchedule<PresenceItem>();

  final MoveTourPulse _tourPulse = MoveTourPulse();
  Timer? _hoursQuiet;

  @override
  void initState()
  {
    super.initState();

    _day = widget.days.where((day) => isSameDate(day.day, widget.from) && day.refusal == null).firstOrNull ??
        widget.days.where((day) => day.viable).firstOrNull;

    mobileTourChanges.addListener(_tourLater);
    _tourLater();
  }

  @override
  void dispose()
  {
    _hoursQuiet?.cancel();
    mobileTourChanges.removeListener(_tourLater);

    // Not while the tree is locked: a tour ends, and redraws, on hearing it.
    final MoveTourPulse pulse = _tourPulse;

    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      pulse.leave();
      pulse.dispose();
    });

    super.dispose();
  }

  bool _asksHours(MoveOption? option) => option != null && option.asksHours && option.window != null;

  void _tourLater()
  {
    if (widget.tourFor == null)
    {
      return;
    }

    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  // Once the sheet stands still, the parts never explained; hours when an option shows them.
  Future<void> _tourCheck() async
  {
    final String? taxCode = widget.tourFor;

    if (!mounted || taxCode == null || isMobileTourShown)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _tourLater();

      return;
    }

    await startMoveTour(
      taxCode: taxCode,
      pulse: _tourPulse,
      hasOptions: () => mounted && (_day?.options.isNotEmpty ?? false),
      hours: () => mounted && _asksHours(_chosen),
      hoursMayCome: () => mounted && (_day?.options.any((option) => option.refusal == null && _asksHours(option)) ?? false),
      bins: () => mounted && _asksHours(_chosen) && _hours.of(_chosen!.band).length > 1,
    );
  }

  void _tourUse(MoveMark mark)
  {
    _tourPulse.use(mark);
    _tourLater();
  }

  void _onBandUsed(MobileBandPart part)
  {
    if (part == MobileBandPart.hours)
    {
      _hoursQuiet?.cancel();
      _hoursQuiet = Timer(_hoursRest, _hoursRested);
    }

    // A second stretch brings the bins: explained then, if never before.
    if (part == MobileBandPart.add)
    {
      _tourLater();
    }
  }

  // Not while an hour is being typed: it counts once confirmed.
  void _hoursRested()
  {
    if (!mounted)
    {
      return;
    }

    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;

    if (focused != null && focused.findAncestorStateOfType<EditableTextState>() != null)
    {
      _hoursQuiet = Timer(_hoursRest, _hoursRested);

      return;
    }

    _tourUse(MoveMark.hours);
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
      _hours = BandSchedule<PresenceItem>();
    });

    _tourUse(MoveMark.days);
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
      _hours = moveScheduleFor(option);
    });

    _tourUse(MoveMark.options);
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

    final bool asked = _asksHours(chosen);
    final String? refusal = asked ? moveHoursRefusal(_hours, chosen) : null;

    if (refusal != null)
    {
      MobileNotice.show(context, refusal, error: true);

      return;
    }

    finishMobileSheet<MobileMoveChoice>(context, (
      day: day,
      option: chosen,
      hours: asked ? moveHoursOf(_hours, chosen.band) : const [],
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: MobileBandEditor<PresenceItem>(
        schedule: _hours,
        mode: option.mode,
        bucket: option.band,
        window: window,
        shutLabel: '',
        offLabel: '',
        fixed: true,
        onChanged: () => setState(() {}),
        tour: MobileBandTour(
          hours: moveTourTarget(MoveMark.hours),
          add: moveTourTarget(MoveMark.add),
          bin: moveTourTarget(MoveMark.bin),
          onUsed: _onBandUsed,
        ),
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
        // Hugging the days, not the sheet's width.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MobileTourTarget(
            id: moveTourTarget(MoveMark.days),
            inflate: _tourInflate,
            radius: _tourDaysRadius,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final option in widget.days) _buildDay(option)],
            ),
          ),
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
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: MobileTourTarget(
                        id: moveTourTarget(MoveMark.options),
                        inflate: _tourInflate,
                        radius: _tourOptionsRadius,
                        child: Wrap(
                          spacing: kMobileChipGap,
                          runSpacing: kMobileChipGap,
                          children: [for (final option in day.options) _buildOption(option)],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        _Unfold(
          child: chosen != null && _asksHours(chosen) && window != null
              ? Column(
                  key: const ValueKey('hours'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    MobileQuietLine(chosen.isNew ? kMoveAddHours : kMoveStretchHours, centred: false),
                    _buildHours(chosen, window),
                  ],
                )
              : const SizedBox(key: ValueKey('none'), width: double.infinity),
        ),
        const SizedBox(height: 6),
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobileTourTarget(
          id: moveTourTarget(MoveMark.confirm),
          inflate: _tourButtonInflate,
          radius: _tourButtonRadius,
          child: MobileGoldButton(label: 'Sposta', icon: Icons.swap_horiz_rounded, onPressed: _confirm),
        ),
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
