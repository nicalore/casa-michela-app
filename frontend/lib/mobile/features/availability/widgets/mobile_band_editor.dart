import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/availability/utils/availability_strings.dart';
import '../../../../features/lessons/models/availability_item.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/widgets/band_schedule.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../shared/mobile_palette.dart';
import '../mobile_availability_draft.dart';
import '../../../shared/widgets/mobile_slot_button.dart';
import 'mobile_time_field.dart';

const double _radius = 20;
const double _rowGap = 12;

const Duration _move = Duration(milliseconds: 220);

const List<BoxShadow> _cardShadow = [
  BoxShadow(color: Color(0x14122438), offset: Offset(0, 6), blurRadius: 18),
];

// A closed band shows what it held, read-only.
class MobileBandEditor extends StatefulWidget
{
  final MobileAvailabilityDraft draft;
  final MobileDayGroup group;
  final String mode;
  final TimeBucket bucket;

  final VoidCallback onChanged;

  const MobileBandEditor({
    super.key,
    required this.draft,
    required this.group,
    required this.mode,
    required this.bucket,
    required this.onChanged,
  });

  @override
  State<MobileBandEditor> createState() => _MobileBandEditorState();
}

class _MobileBandEditorState extends State<MobileBandEditor>
{
  // Stretches already shown; later ones animate open.
  final Set<BandStretch<AvailabilityItem>> _shown = Set.identity();

  // Stretches folding away before they leave the schedule.
  final Set<BandStretch<AvailabilityItem>> _leaving = Set.identity();

  bool _wasGiven = false;

  TimeBucket get _bucket => widget.bucket;

  BandSchedule<AvailabilityItem> get _schedule => widget.draft.bandsOf(widget.group)[widget.mode]!;

  void _change(void Function() change)
  {
    change();
    widget.onChanged();
  }

  void _remove(BandStretch<AvailabilityItem> stretch)
  {
    setState(() => _leaving.add(stretch));
  }

  void _removed(BandStretch<AvailabilityItem> stretch)
  {
    _leaving.remove(stretch);
    _shown.remove(stretch);

    final int index = _schedule.of(_bucket).indexOf(stretch);

    if (index >= 0)
    {
      _change(() => _schedule.removeAt(_bucket, index));
    }
  }

  Widget _buildHead({Widget? trailing, bool locked = false})
  {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    bandLabel(_bucket).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline_rounded, size: 14, color: MobilePalette.mutedText),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildShut()
  {
    final List<BandStretch<AvailabilityItem>> held =
        widget.draft.isEditing ? widget.draft.frozen[widget.mode]![_bucket]! : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHead(locked: held.isNotEmpty),
        for (final stretch in held) _Held(mode: widget.mode, stretch: stretch),
        Padding(
          padding: EdgeInsets.only(top: held.isEmpty ? 2 : 8),
          child: Text(
            widget.draft.shutLabelFor(widget.group, widget.mode, _bucket),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: MobilePalette.mutedText.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpening(OpeningWindow window)
  {
    return Row(
      children: [
        Text(
          'Apertura'.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: MobilePalette.mutedText,
          ),
        ),
        const SizedBox(width: 8),
        Icon(lessonModeIcon(widget.mode), size: 15, color: MobilePalette.mutedText),
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
    );
  }

  Widget _buildStretch(OpeningWindow window, BandStretch<AvailabilityItem> stretch)
  {
    final List<BandStretch<AvailabilityItem>> stretches = _schedule.of(_bucket);
    final int index = stretches.indexOf(stretch);
    final (int low, int high) = _schedule.boundsAt(_bucket, window, index);

    final bool leaving = _leaving.contains(stretch);

    void move(int start, int end)
    {
      final int at = _schedule.of(_bucket).indexOf(stretch);

      // Still folding after «No» emptied the band.
      if (at < 0)
      {
        return;
      }

      _change(() => _schedule.move(_bucket, at, timeOfDayFromMinutes(start), timeOfDayFromMinutes(end)));
    }

    final Widget row = Container(
      margin: const EdgeInsets.only(top: _rowGap),
      padding: const EdgeInsets.only(top: _rowGap),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: MobileTimeField(
              label: 'Dalle',
              minutes: stretch.startMinutes,
              min: low,
              max: stretch.endMinutes - kMinimumBandMinutes,
              onChanged: (start) => move(start, stretch.endMinutes),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MobileTimeField(
              label: 'Alle',
              minutes: stretch.endMinutes,
              min: stretch.startMinutes + kMinimumBandMinutes,
              max: high,
              onChanged: (end) => move(stretch.startMinutes, end),
            ),
          ),
          // A lone stretch is cleared with «No»; the bin shows from the second.
          if (stretches.length > 1)
            Semantics(
              button: true,
              label: 'Elimina',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: leaving ? null : () => _remove(stretch),
                child: SizedBox(
                  width: 40,
                  height: 44,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppTheme.trialDanger.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return _Unfold(
      // Keyed by stretch so it survives removals above it.
      key: ObjectKey(stretch),
      appear: !_shown.contains(stretch),
      visible: !leaving,
      onHidden: () => _removed(stretch),
      child: row,
    );
  }

  Widget _buildOpen(OpeningWindow window)
  {
    final List<BandStretch<AvailabilityItem>> stretches = [..._schedule.of(_bucket)];
    final bool given = stretches.isNotEmpty;

    // On «Sì» the stretches open with the whole block, not one by one.
    if (given && !_wasGiven)
    {
      _shown
        ..clear()
        ..addAll(stretches);
    }

    _wasGiven = given;

    final Widget hours = given
        ? Column(
            key: const ValueKey('given'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final stretch in stretches) _buildStretch(window, stretch)],
          )
        : const SizedBox.shrink(key: ValueKey('none'));

    _shown.addAll(stretches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHead(
          trailing: _YesNo(
            yes: given,
            onYes: () => _change(() => _schedule.toggle(_bucket, window.start, window.end)),
            onNo: () => _change(() => _schedule.toggle(_bucket, null, null)),
          ),
        ),
        _buildOpening(window),
        AnimatedSwitcher(
          duration: _move,
          layoutBuilder: (current, previous) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: _fold(animation),
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: hours,
        ),
        _Foot(
          given: given,
          onAdd: !given || _schedule.firstGap(_bucket, window) == null
              ? null
              : () => _change(() => _schedule.addStretch(_bucket, window)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final OpeningWindow? window = widget.draft.windowFor(widget.group, widget.mode, _bucket);

    final bool shut = window == null;

    // Parts size themselves; no clip here, or it would hide what folds at the foot.
    return AnimatedContainer(
      duration: _move,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 14),
      decoration: BoxDecoration(
        color: shut ? Colors.white.withValues(alpha: 0.45) : Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.06)),
        boxShadow: shut ? null : _cardShadow,
      ),
      child: shut ? _buildShut() : _buildOpen(window),
    );
  }
}

Animation<double> _fold(Animation<double> parent)
{
  return CurvedAnimation(parent: parent, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
}

class _Unfold extends StatefulWidget
{
  final bool appear;
  final bool visible;
  final VoidCallback onHidden;
  final Widget child;

  const _Unfold({
    super.key,
    required this.appear,
    required this.visible,
    required this.onHidden,
    required this.child,
  });

  @override
  State<_Unfold> createState() => _UnfoldState();
}

class _UnfoldState extends State<_Unfold> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _move,
    value: widget.appear ? 0 : 1,
  );

  late final Animation<double> _size = _fold(_controller);

  @override
  void initState()
  {
    super.initState();

    if (widget.appear)
    {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_Unfold oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.visible && !widget.visible)
    {
      _controller.reverse().whenComplete(()
      {
        if (mounted)
        {
          widget.onHidden();
        }
      });
    }
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return SizeTransition(sizeFactor: _size, alignment: Alignment.topCenter, child: widget.child);
  }
}

class _Held extends StatelessWidget
{
  final String mode;
  final BandStretch<AvailabilityItem> stretch;

  const _Held({required this.mode, required this.stretch});

  @override
  Widget build(BuildContext context)
  {
    final Color ink = AppTheme.trialInk.withValues(alpha: 0.55);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Icon(lessonModeIcon(mode), size: 18, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              modeLabel(mode),
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink),
            ),
          ),
          Text(
            formatTimeRange(stretch.startTime, stretch.endTime),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _YesNo extends StatelessWidget
{
  final bool yes;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _YesNo({required this.yes, required this.onYes, required this.onNo});

  Widget _buildOption(String label, {required bool on, required VoidCallback onTap})
  {
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: on ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedDefaultTextStyle(
            duration: _move,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: on ? (yes ? AppTheme.trialTealDeep : AppTheme.trialInk) : MobilePalette.mutedText,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.trialInk.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      // Both halves as wide as the wider, so the thumb fits either.
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: _move,
                curve: Curves.easeOutCubic,
                alignment: yes ? Alignment.centerLeft : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: const [BoxShadow(color: Color(0x1F122438), offset: Offset(0, 2), blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: _buildOption('Sì', on: yes, onTap: onYes)),
                Expanded(child: _buildOption('No', on: !yes, onTap: onNo)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Fades through its colour's alpha: an Opacity trips Impeller's check.
class _FadeIn extends StatelessWidget
{
  final Widget Function(double alpha) builder;

  const _FadeIn({super.key, required this.builder});

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _move,
      curve: const Interval(0.5, 1),
      builder: (context, alpha, _) => builder(alpha),
    );
  }
}

class _Foot extends StatelessWidget
{
  final bool given;

  // Null while the opening has no quarter hour left.
  final VoidCallback? onAdd;

  const _Foot({required this.given, required this.onAdd});

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onAdd = this.onAdd;

    final Widget line;

    if (!given)
    {
      line = _FadeIn(
        key: const ValueKey('none'),
        builder: (alpha) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(
            kNotAvailable,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: MobilePalette.mutedText.withValues(alpha: alpha),
            ),
          ),
        ),
      );
    }
    else if (onAdd != null)
    {
      line = _FadeIn(
        key: const ValueKey('add'),
        builder: (alpha) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: MobileSlotButton(
            label: 'Aggiungi orario',
            icon: Icons.add_rounded,
            onPressed: onAdd,
            onLight: true,
            alpha: alpha,
          ),
        ),
      );
    }
    else
    {
      line = const SizedBox(key: ValueKey('full'), width: double.infinity);
    }

    return AnimatedSize(
      duration: _move,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: line,
    );
  }
}
