import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/lessons/utils/booking_window.dart';
import '../mobile_line_breaks.dart';
import '../mobile_palette.dart';
import 'mobile_glass_panel.dart';
import 'mobile_height_reporter.dart';
import 'mobile_notice.dart';
import 'mobile_sheet.dart';

const double _dotWidth = 14;
const double _dotCurrentWidth = 30;
const double _dotHeight = 5;
const double _dotGap = 6;

const double _backRadius = 18;

// How far a swipe pulls past a refused step, as a share of the page, and how stiffly.
const double _pullRoom = 0.1;
const double _pullGive = 0.5;

const List<BoxShadow> _shadow = [
  BoxShadow(color: Color(0x29000000), offset: Offset(0, 8), blurRadius: 18),
];

class MobileWizardDots extends StatelessWidget
{
  final int count;
  final PageController position;
  final int fallback;

  const MobileWizardDots({
    super.key,
    required this.count,
    required this.position,
    required this.fallback,
  });

  static const Color _ahead = Color(0x29122438);

  @override
  Widget build(BuildContext context)
  {
    return AnimatedBuilder(
      animation: position,
      builder: (context, _)
      {
        final double page = position.hasClients && position.position.haveDimensions
            ? position.page ?? fallback.toDouble()
            : fallback.toDouble();

        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _dotGap),
                _buildDot(i, page),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index, double page)
  {
    // 1 on the current step, 0 a step or more away.
    final double near = (1 - (page - index).abs()).clamp(0.0, 1.0);
    final double behind = (page - index).clamp(0.0, 1.0);

    final Color rest = Color.lerp(_ahead, AppTheme.trialTealDeep.withValues(alpha: 0.45), behind)!;

    return Container(
      width: ui.lerpDouble(_dotWidth, _dotCurrentWidth, near),
      height: _dotHeight,
      decoration: BoxDecoration(
        color: Color.lerp(rest, AppTheme.trialGold, near),
        borderRadius: BorderRadius.circular(_dotHeight / 2),
      ),
    );
  }
}

class MobileWizardBackButton extends StatelessWidget
{
  static const double size = 58;

  final VoidCallback? onTap;

  const MobileWizardBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Indietro',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_backRadius),
            color: Colors.white.withValues(alpha: MobileGlassPanel.cardAlpha),
            border: Border.all(color: AppTheme.trialOcean.withValues(alpha: 0.14)),
            boxShadow: _shadow,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: AppTheme.trialInk.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class MobileWizardBackSlot extends StatelessWidget
{
  static const Duration _duration = Duration(milliseconds: 340);
  static const double _gap = 12;

  // Null on a step with no way back.
  final VoidCallback? onBack;
  final bool busy;

  const MobileWizardBackSlot({super.key, required this.onBack, this.busy = false});

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onBack = this.onBack;

    return AnimatedSize(
      duration: _duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.centerLeft,
      child: onBack != null
          ? Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: MobileWizardBackButton(onTap: busy ? null : onBack),
            )
          : const SizedBox(height: MobileWizardBackButton.size),
    );
  }
}

class MobileWizardGuide extends StatelessWidget
{
  final String question;
  final String hint;

  const MobileWizardGuide({super.key, required this.question, required this.hint});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          withoutOrphans(question),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.2,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          withoutOrphans(hint),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: MobilePalette.mutedText,
          ),
        ),
      ],
    );
  }
}

class MobileDaysTag extends StatelessWidget
{
  final List<DateTime> days;

  const MobileDaysTag({super.key, required this.days});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${(days.length == 1 ? 'Giornata' : 'Giornate').toUpperCase()}  ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppTheme.trialTealDeep,
              ),
            ),
            TextSpan(text: days.map(formatAvailableDayLabel).join(', ')),
          ],
        ),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          height: 1.45,
          color: AppTheme.trialInk,
        ),
      ),
    );
  }
}

// Page snapping where a swipe forward stops at the first step still refused, as «Avanti» does.
class MobileStepPhysics extends PageScrollPhysics
{
  final String? Function(int index) blockedReason;

  // Called as a swipe pulls past a refused step.
  final ValueChanged<String> onRefused;

  const MobileStepPhysics({required this.blockedReason, required this.onRefused, super.parent});

  @override
  MobileStepPhysics applyTo(ScrollPhysics? ancestor)
  {
    return MobileStepPhysics(blockedReason: blockedReason, onRefused: onRefused, parent: buildParent(ancestor));
  }

  // The first refused step from the page in view on; the last page has nothing ahead to refuse.
  (double, String)? _stop(ScrollMetrics position)
  {
    final double width = position.viewportDimension;
    final int last = (position.maxScrollExtent / width).round();

    for (int index = math.max(0, (position.pixels / width).floor()); index < last; index++)
    {
      final String? reason = blockedReason(index);

      if (reason != null)
      {
        return (index * width, reason);
      }
    }

    return null;
  }

  // A negative offset moves forward.
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset)
  {
    final (double, String)? stop = offset < 0 ? _stop(position) : null;

    if (stop == null)
    {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    final (double limit, String reason) = stop;
    final double free = math.max(0.0, limit - position.pixels);

    if (-offset <= free)
    {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    if (position.pixels <= limit)
    {
      onRefused(reason);
    }

    // Past the step the page follows the finger ever more slowly.
    final double past = math.max(0.0, position.pixels - limit);
    final double give = math.max(0.0, 1 - past / (position.viewportDimension * _pullRoom));

    return -(free + (-offset - free) * _pullGive * give * give);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity)
  {
    final (double, String)? stop = velocity >= 0 ? _stop(position) : null;

    if (stop != null && position.pixels >= stop.$1)
    {
      return position.pixels == stop.$1
          ? null
          : ScrollSpringSimulation(spring, position.pixels, stop.$1, 0, tolerance: toleranceFor(position));
    }

    return super.createBallisticSimulation(position, velocity);
  }
}

// Its height follows the pages either side of the finger.
class MobileStepPager extends StatefulWidget
{
  final PageController controller;

  // One per page, so a page keeps its measured height when others come and go.
  final List<String> keys;

  final List<Widget> Function(int index) pageBuilder;
  final ValueChanged<int> onPageChanged;

  // Same as «Avanti»: a swipe forward from a refused step gives the reason and springs back.
  final String? Function(int index) blockedReason;

  const MobileStepPager({
    super.key,
    required this.controller,
    required this.keys,
    required this.pageBuilder,
    required this.onPageChanged,
    required this.blockedReason,
  });

  @override
  State<MobileStepPager> createState() => _MobileStepPagerState();
}

class _MobileStepPagerState extends State<MobileStepPager>
{
  // Assumed page height until measured.
  static const double _unmeasured = 360;

  final ValueNotifier<Map<String, double>> _heights = ValueNotifier(const {});

  // Made once: the scrollable keeps its first physics, so it reads the widget at each call.
  late final MobileStepPhysics _physics = MobileStepPhysics(
    blockedReason: (index) => index < widget.keys.length ? widget.blockedReason(index) : null,
    onRefused: (reason) => MobileNotice.show(context, reason, error: true),
  );

  @override
  void dispose()
  {
    _heights.dispose();
    super.dispose();
  }

  void _measured(String key, double height)
  {
    final double? known = _heights.value[key];

    if (known != null && (known - height).abs() < 0.5)
    {
      return;
    }

    _heights.value = {..._heights.value, key: height};
  }

  double get _page
  {
    final PageController controller = widget.controller;

    return controller.hasClients && controller.position.haveDimensions
        ? controller.page ?? controller.initialPage.toDouble()
        : controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> keys = widget.keys;

    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _heights]),
      builder: (context, child)
      {
        final double page = _page.clamp(0, keys.length - 1).toDouble();
        final int low = page.floor();
        final int high = page.ceil();

        final Map<String, double> heights = _heights.value;
        final double from = heights[keys[low]] ?? heights[keys[high]] ?? _unmeasured;
        final double to = heights[keys[high]] ?? from;

        // Bounded by the Flexible around it in the sheet.
        return SizedBox(height: ui.lerpDouble(from, to, page - low), child: child);
      },
      child: PageView.builder(
        controller: widget.controller,
        // The physics snap to pages themselves.
        pageSnapping: false,
        physics: _physics,
        // Keeps the neighbours laid out, so their height is known before a swipe.
        allowImplicitScrolling: true,
        itemCount: keys.length,
        onPageChanged: (index)
        {
          FocusManager.instance.primaryFocus?.unfocus();
          widget.onPageChanged(index);
        },
        itemBuilder: (context, index) => SingleChildScrollView(
          key: PageStorageKey(keys[index]),
          child: MobileHeightReporter(
            onHeight: (height) => _measured(keys[index], height),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, 20, MobileSheet.sidePadding, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.pageBuilder(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
