import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../services/seen_tours.dart';
import 'app_gradient_button.dart';
import 'page_transition.dart';
import 'shared_components.dart';

const String _backLabel = 'INDIETRO';
const String _nextLabel = 'AVANTI';
const String _endLabel = 'FINE';

// As a dialog without blur: the page stays readable.
const double _dimOpacity = 0.32;

const double _bubbleWidth = 410;
const double _narrowestBubble = 300;
const double _bubbleGap = 20;
const double _windowMargin = 20;

// The desktop tooltips' colour: the card reads as a layer over the page, the lit parts as page.
final Color _bubbleColor = AppTheme.trialOcean.withValues(alpha: 0.97);
final Color _closeHover = Color.alphaBlend(Colors.white.withValues(alpha: 0.14), AppTheme.trialOcean);

// Above or below a part, the bubble needs at least this much height.
const double _shortestRoom = 170;

// Past a scroll view's bottom fade.
const double _revealEdge = 48;

const Duration _move = Duration(milliseconds: 380);
const Duration _fade = Duration(milliseconds: 220);
const Duration _reveal = Duration(milliseconds: 450);

// Parts keep moving a while after a step begins (menus opening, pages scrolling).
const Duration _watch = Duration(milliseconds: 900);

const Duration _startPause = Duration(milliseconds: 300);

// A page still moving after this long is not waited for any more.
const Duration _longestWait = Duration(seconds: 8);
const Duration _waitStep = Duration(milliseconds: 100);

String _eyebrow(int index, int count) => 'TUTORIAL · $index DI $count';

final Map<String, List<_DesktopTourTargetState>> _targets = {};

// Marks a part a desktop tour can light; a null id leaves the child as it is.
class DesktopTourTarget extends StatefulWidget
{
  final String? id;
  final Widget child;

  const DesktopTourTarget({super.key, required this.id, required this.child});

  @override
  State<DesktopTourTarget> createState() => _DesktopTourTargetState();
}

class _DesktopTourTargetState extends State<DesktopTourTarget>
{
  @override
  void initState()
  {
    super.initState();
    _register(widget.id);
  }

  @override
  void didUpdateWidget(DesktopTourTarget oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id != widget.id)
    {
      _unregister(oldWidget.id);
      _register(widget.id);
    }
  }

  @override
  void dispose()
  {
    _unregister(widget.id);
    super.dispose();
  }

  void _register(String? id)
  {
    if (id != null)
    {
      (_targets[id] ??= []).add(this);
    }
  }

  void _unregister(String? id)
  {
    if (id != null)
    {
      _targets[id]?.remove(this);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Destinations kept behind build their parts too: the one on show wins, then the latest built.
BuildContext? _contextOf(String id)
{
  final Iterable<_DesktopTourTargetState> built = _targets[id]?.where((state) => state.mounted) ?? const [];

  return (built.where((state) => isDestinationShownNow(state.context)).lastOrNull ?? built.lastOrNull)?.context;
}

Rect? _rectOf(String id)
{
  final RenderObject? box = _contextOf(id)?.findRenderObject();

  if (box is! RenderBox || !box.attached || !box.hasSize)
  {
    return null;
  }

  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
}

bool isDesktopTourTargetShown(String id) => _contextOf(id) != null;

enum DesktopTourSide { right, left, below, above }

class DesktopTourStep
{
  // Lit together as one part; none: the bubble alone, in the middle.
  final List<String> targets;

  final String text;

  // Tried in order; the first with room enough wins.
  final List<DesktopTourSide> sides;

  final double pad;
  final double radius;

  // A step without a forward button: the lit part takes clicks, and the step is done once
  // [reached] holds, checked whenever [listen] notifies.
  final Listenable? listen;
  final bool Function()? reached;

  // Done when the address changes (a click on a menu that opens another page).
  final bool doneByLeaving;

  // The part is scrolled into sight as the step begins; [revealing] names a larger one to show.
  final bool reveal;
  final String? revealing;

  // Run as the step begins, and when stepping back from it.
  final VoidCallback? enter;
  final VoidCallback? undo;

  // Asked as the tour starts: false leaves the step out.
  final bool Function()? present;

  const DesktopTourStep({
    this.targets = const [],
    required this.text,
    this.sides = const [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above],
    this.pad = 8,
    this.radius = 20,
    this.listen,
    this.reached,
    this.doneByLeaving = false,
    this.reveal = false,
    this.revealing,
    this.enter,
    this.undo,
    this.present,
  });

  bool get waitsForClick => reached != null || doneByLeaving;

  bool get isPresent => present?.call() ?? true;
}

class DesktopTour
{
  final String slug;
  final String title;

  // Bumped on every change, so whoever had seen the tour sees it again.
  final int version;

  final List<DesktopTourStep> steps;

  const DesktopTour({required this.slug, required this.title, required this.version, required this.steps});
}

class _Run
{
  final DesktopTour tour;
  final List<DesktopTourStep> steps;
  final String taxCode;

  // The address the tour belongs to: leaving it ends the tour.
  final ValueListenable<RouteInformation>? address;
  final String? path;

  _Run(this.tour, this.steps, this.taxCode, this.address, this.path);
}

Future<void> _settle(BuildContext context) async
{
  final Animation<double>? entrance = ModalRoute.of(context)?.animation;
  final Stopwatch waited = Stopwatch()..start();

  while (waited.elapsed < _longestWait)
  {
    if (!context.mounted)
    {
      return;
    }

    final bool coming = entrance != null && entrance.status == AnimationStatus.forward;

    if (!coming && !isPageTransitionMoving(context) && isDestinationShown(context))
    {
      return;
    }

    await Future<void>.delayed(_waitStep);
  }
}

_Run? _run;
OverlayEntry? _entry;

bool get isDesktopTourShown => _run != null;

// Storage out of reach: better no tour than one shown at every visit.
Future<bool> _seen(String taxCode, DesktopTour tour) async
{
  try
  {
    return await SeenTours.desktop.hasSeen(taxCode: taxCode, slug: tour.slug, version: tour.version);
  }
  catch (_)
  {
    return true;
  }
}

// Once per account and tour, after the page's own entrance; paused while the window is narrow.
Future<void> startDesktopTourOnce(BuildContext context, {required String taxCode, required DesktopTour tour}) async
{
  if (_run != null || await _seen(taxCode, tour))
  {
    return;
  }

  if (!context.mounted)
  {
    return;
  }

  await _settle(context);
  await Future<void>.delayed(_startPause);

  if (!context.mounted || _run != null || !isDestinationShown(context))
  {
    return;
  }

  final GoRouteInformationProvider? address = GoRouter.maybeOf(context)?.routeInformationProvider;

  final List<DesktopTourStep> steps = tour.steps.where((step) => step.isPresent).toList();

  if (steps.isEmpty)
  {
    return;
  }

  final _Run run = _Run(tour, steps, taxCode, address, address?.value.uri.path);

  _run = run;
  _entry = OverlayEntry(builder: (context) => _TourLayer(run: run));
  Overlay.of(context, rootOverlay: true).insert(_entry!);
}

class _TourLayer extends StatefulWidget
{
  final _Run run;

  const _TourLayer({required this.run});

  @override
  State<_TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<_TourLayer> with TickerProviderStateMixin, WidgetsBindingObserver
{
  late final AnimationController _shown = AnimationController(vsync: this, duration: _fade)
    ..addListener(_redraw);
  late final Ticker _ticker = createTicker(_tick);

  int _step = 0;
  final List<int> _path = [];

  // Counts the steps entered: the card's buttons answer only for the one they were drawn for.
  int _visit = 0;

  // The hole as drawn, where it began its move, and where its part is now.
  Rect? _hole;
  Rect? _from;
  Rect? _aim;

  // The bubble glides with the hole, from where it last stood.
  final _BubbleTrack _track = _BubbleTrack();
  Offset? _bubbleFrom;
  double? _widthFrom;
  double _glide = 1;

  Duration _elapsed = Duration.zero;
  Duration _moveStart = Duration.zero;
  Duration _watchUntil = Duration.zero;

  Listenable? _listening;

  bool _closing = false;

  DesktopTourStep get _current => widget.run.steps[_step];

  bool get _animates => VisualEffects.on;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    widget.run.address?.addListener(_onAddress);

    _enter(0);
    _shown.duration = _animates ? _fade : Duration.zero;
    _shown.forward();
  }

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    widget.run.address?.removeListener(_onAddress);
    _listening?.removeListener(_onListened);
    _ticker.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _watchFor(_watch);

  void _redraw()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  void _onAddress()
  {
    if (widget.run.address?.value.uri.path == widget.run.path)
    {
      return;
    }

    _end(mark: _current.doneByLeaving, fade: false);
  }

  void _onListened()
  {
    if (!_closing && (_current.reached?.call() ?? false))
    {
      _next();
    }
  }

  Rect? _measure(DesktopTourStep step)
  {
    Rect? union;

    for (final String id in step.targets)
    {
      final Rect? rect = _rectOf(id);

      if (rect != null)
      {
        union = union?.expandToInclude(rect) ?? rect;
      }
    }

    return union?.inflate(step.pad);
  }

  void _enter(int index, {bool back = false})
  {
    _listening?.removeListener(_onListened);
    _step = index;
    _visit++;

    final DesktopTourStep step = _current;

    step.enter?.call();

    _listening = step.listen;
    _listening?.addListener(_onListened);

    _from = _hole;
    _bubbleFrom = _track.position;
    _widthFrom = _track.width;
    _glide = _bubbleFrom == null || !_animates ? 1 : 0;
    _moveStart = _elapsed;
    _watchFor(_watch + _move);

    if (step.reveal && step.targets.isNotEmpty)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealPart(step.revealing ?? step.targets.first));
    }
  }

  void _watchFor(Duration span)
  {
    final Duration until = _elapsed + span;

    if (until > _watchUntil)
    {
      _watchUntil = until;
    }

    if (!_ticker.isActive)
    {
      _elapsed = Duration.zero;
      _moveStart = Duration.zero;
      _watchUntil = span;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed)
  {
    _elapsed = elapsed;

    final DesktopTourStep step = _current;
    final Rect? measured = _measure(step);

    if (step.targets.isEmpty)
    {
      final Offset middle = (_hole ?? Offset.zero & MediaQuery.sizeOf(context)).center;

      _aim = Rect.fromCenter(center: middle, width: 0, height: 0);
    }
    else if (measured != null)
    {
      _aim = measured;
    }

    final double moved = _animates
        ? ((elapsed - _moveStart).inMicroseconds / _move.inMicroseconds).clamp(0.0, 1.0)
        : 1.0;
    final double t = _from != null ? moved : 1.0;

    _glide = _bubbleFrom != null ? moved : 1.0;
    final Rect? from = _from ?? (_aim == null ? null : Rect.fromCenter(center: _aim!.center, width: 0, height: 0));

    _hole = from == null || _aim == null ? _aim : Rect.lerp(from, _aim, Curves.easeInOutCubic.transform(t));

    if (t >= 1 && _glide >= 1 && elapsed >= _watchUntil)
    {
      _ticker.stop();
    }

    setState(() {});
  }

  Future<void> _revealPart(String id) async
  {
    final BuildContext? target = _contextOf(id);
    final ScrollableState? scrollable = target == null ? null : Scrollable.maybeOf(target);
    final Rect? part = _rectOf(id);
    final RenderObject? view = scrollable?.context.findRenderObject();

    if (scrollable == null || part == null || view is! RenderBox || !view.hasSize)
    {
      return;
    }

    final Rect port = MatrixUtils.transformRect(view.getTransformTo(null), Offset.zero & view.size);

    double delta = 0;

    if (part.bottom > port.bottom - _revealEdge)
    {
      delta = part.bottom - (port.bottom - _revealEdge);
    }

    // A part taller than the view keeps its top in sight.
    if (part.top - delta < port.top + _bubbleGap)
    {
      delta = part.top - (port.top + _bubbleGap);
    }

    final ScrollPosition position = scrollable.position;
    final double to = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((to - position.pixels).abs() < 1)
    {
      return;
    }

    _watchFor(_reveal + _watch);

    if (_animates)
    {
      await position.animateTo(to, duration: _reveal, curve: Curves.easeInOutCubic);
    }
    else
    {
      position.jumpTo(to);
    }
  }

  // A click on a button fading out with the step left, or a second one before the card is redrawn, does nothing.
  void _nextFrom(int visit)
  {
    if (!_closing && visit == _visit)
    {
      _next();
    }
  }

  void _backFrom(int visit)
  {
    if (!_closing && visit == _visit)
    {
      _back();
    }
  }

  void _next()
  {
    if (_step == widget.run.steps.length - 1)
    {
      _end(mark: true);

      return;
    }

    _path.add(_step);
    setState(() => _enter(_step + 1));
  }

  void _back()
  {
    if (_path.isEmpty)
    {
      return;
    }

    _current.undo?.call();
    setState(() => _enter(_path.removeLast(), back: true));
  }

  Future<void> _end({required bool mark, bool fade = true}) async
  {
    if (_closing)
    {
      return;
    }

    _closing = true;
    _listening?.removeListener(_onListened);
    _listening = null;

    if (mark)
    {
      unawaited(SeenTours.desktop.markSeen(widget.run.taxCode, {widget.run.tour.slug: widget.run.tour.version}));
    }

    if (fade && _animates)
    {
      await _shown.reverse();
    }

    _run = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  Widget build(BuildContext context)
  {
    final Size window = MediaQuery.sizeOf(context);

    // Narrow windows lose the menus the tour speaks of: it waits for a wider one.
    if (AppBreakpoints.fromWidth(window.width).isCompact)
    {
      return const SizedBox.shrink();
    }

    final DesktopTourStep step = _current;
    final List<DesktopTourStep> steps = widget.run.steps;
    final Rect? hole = _hole != null && !_hole!.isEmpty ? _hole : null;
    final Rect? place = step.targets.isEmpty ? null : _aim;

    final bool last = _step == steps.length - 1;
    final int visit = _visit;

    final Widget bubble = _Bubble(
      step: _step,
      animates: _animates,
      eyebrow: _eyebrow(_step + 1, steps.length),
      title: widget.run.tour.title,
      text: step.text,
      onClose: () => _end(mark: true),
      onBack: _path.isEmpty ? null : () => _backFrom(visit),
      onNext: step.waitsForClick ? null : () => _nextFrom(visit),
      last: last,
    );

    return FadeTransition(
      opacity: _shown,
      child: Stack(
        children: [
          Positioned.fill(
            child: _Blocker(
              hole: step.waitsForClick ? _aim : null,
              child: CustomPaint(
                painter: _DimPainter(hole: hole, radius: step.radius + step.pad / 2),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _BubblePlace(
                hole: place,
                sides: step.sides,
                from: _bubbleFrom,
                widthFrom: _widthFrom,
                t: Curves.easeInOutCubic.transform(_glide),
                track: _track,
              ),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

class _DimPainter extends CustomPainter
{
  final Rect? hole;
  final double radius;

  const _DimPainter({required this.hole, required this.radius});

  @override
  void paint(Canvas canvas, Size size)
  {
    final Path dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);

    if (hole case final Rect hole)
    {
      dim.addRRect(RRect.fromRectAndRadius(hole, Radius.circular(math.min(radius, hole.shortestSide / 2))));
    }

    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: _dimOpacity));
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate) => oldDelegate.hole != hole || oldDelegate.radius != radius;
}

// Takes every pointer but those inside [hole], which reach the page below.
class _Blocker extends SingleChildRenderObjectWidget
{
  final Rect? hole;

  const _Blocker({required this.hole, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlocker(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderBlocker renderObject) => renderObject.hole = hole;
}

class _RenderBlocker extends RenderProxyBox
{
  Rect? hole;

  _RenderBlocker(this.hole);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position})
  {
    if (!size.contains(position) || (hole?.contains(localToGlobal(position)) ?? false))
    {
      return false;
    }

    result.add(BoxHitTestEntry(this, position));

    return true;
  }
}

// Where the bubble was last laid out: the next step's glide starts there.
class _BubbleTrack
{
  Offset? position;
  double? width;
}

class _BubblePlace extends SingleChildLayoutDelegate
{
  final Rect? hole;
  final List<DesktopTourSide> sides;

  // Where the glide began and how far it has gone, eased.
  final Offset? from;
  final double? widthFrom;
  final double t;

  final _BubbleTrack track;

  const _BubblePlace({
    required this.hole,
    required this.sides,
    required this.from,
    required this.widthFrom,
    required this.t,
    required this.track,
  });

  (DesktopTourSide?, double) _choose(Size size)
  {
    final Rect? hole = this.hole;

    if (hole == null)
    {
      return (null, _bubbleWidth);
    }

    for (final DesktopTourSide side in sides)
    {
      final double room = switch (side)
      {
        DesktopTourSide.right => size.width - _windowMargin - hole.right - _bubbleGap,
        DesktopTourSide.left => hole.left - _bubbleGap - _windowMargin,
        DesktopTourSide.below => size.height - _windowMargin - hole.bottom - _bubbleGap,
        DesktopTourSide.above => hole.top - _bubbleGap - _windowMargin,
      };

      final bool across = side == DesktopTourSide.right || side == DesktopTourSide.left;

      if (across && room >= _narrowestBubble)
      {
        return (side, math.min(_bubbleWidth, room));
      }

      if (!across && room >= _shortestRoom)
      {
        return (side, math.min(_bubbleWidth, size.width - 2 * _windowMargin));
      }
    }

    return (null, _bubbleWidth);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints)
  {
    final double aimed = _choose(constraints.biggest).$2;
    final double width = widthFrom == null ? aimed : widthFrom! + (aimed - widthFrom!) * t;

    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, constraints.maxHeight - 2 * _windowMargin),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize)
  {
    final Offset aimed = _aimed(size, childSize);
    final Offset at = from == null ? aimed : Offset.lerp(from, aimed, t)!;

    track
      ..position = at
      ..width = childSize.width;

    return at;
  }

  Offset _aimed(Size size, Size childSize)
  {
    final Rect? hole = this.hole;
    final DesktopTourSide? side = _choose(size).$1;

    double across(double x) => x.clamp(_windowMargin, math.max(_windowMargin, size.width - _windowMargin - childSize.width));
    double down(double y) => y.clamp(_windowMargin, math.max(_windowMargin, size.height - _windowMargin - childSize.height));

    if (hole == null || side == null)
    {
      return Offset((size.width - childSize.width) / 2, (size.height - childSize.height) / 2);
    }

    return switch (side)
    {
      DesktopTourSide.right => Offset(hole.right + _bubbleGap, down(hole.top)),
      DesktopTourSide.left => Offset(hole.left - _bubbleGap - childSize.width, down(hole.top)),
      DesktopTourSide.below => Offset(across(hole.center.dx - childSize.width / 2), hole.bottom + _bubbleGap),
      DesktopTourSide.above => Offset(across(hole.center.dx - childSize.width / 2), hole.top - _bubbleGap - childSize.height),
    };
  }

  @override
  bool shouldRelayout(_BubblePlace oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.sides != sides ||
      oldDelegate.from != from ||
      oldDelegate.widthFrom != widthFrom ||
      oldDelegate.t != t;
}

class _Bubble extends StatelessWidget
{
  // Keys the content, which fades from one step to the next while the card glides.
  final int step;
  final bool animates;

  final String eyebrow;
  final String title;
  final String text;

  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final bool last;

  const _Bubble({
    required this.step,
    required this.animates,
    required this.eyebrow,
    required this.title,
    required this.text,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.last,
  });

  Widget _button(String label, IconData icon, VoidCallback onPressed, {required bool forward})
  {
    return AppGradientButton(
      label: label,
      icon: icon,
      gradient: forward ? AppTheme.brandGradient : AppTheme.dismissGradient,
      accent: forward ? AppTheme.trialTealDeep : AppTheme.trialViolet,
      height: 46,
      fontSize: 14,
      onPressed: onPressed,
    );
  }

  Widget _footer()
  {
    final VoidCallback? back = onBack;
    final VoidCallback? next = onNext;

    final Widget? backButton = back == null ? null : _button(_backLabel, Icons.arrow_back_rounded, back, forward: false);
    final Widget? nextButton = next == null
        ? null
        : _button(
            last ? _endLabel : _nextLabel,
            last ? Icons.check_rounded : Icons.arrow_forward_rounded,
            next,
            forward: true,
          );

    if (backButton == null || nextButton == null)
    {
      return Center(child: FractionallySizedBox(widthFactor: 0.5, child: backButton ?? nextButton));
    }

    return Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 12),
        Expanded(child: nextButton),
      ],
    );
  }

  Widget _head()
  {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Chiudi',
          child: FadeHoverIconButton(
            icon: Icons.close_rounded,
            color: Colors.white,
            hoverColor: _closeHover,
            onTap: onClose,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bubbleColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 10), blurRadius: 28)],
        ),
        // While the card grows, the content still to come is cut by its rounded edge.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AnimatedSize(
            duration: animates ? _move : Duration.zero,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: animates ? _fade : Duration.zero,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // The text going out takes no click: its buttons lie uncovered under a shorter one.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [
                  for (final Widget child in previous) IgnorePointer(key: child.key, child: child),
                  if (current != null) IgnorePointer(key: current.key, ignoring: false, child: current),
                ],
              ),
              child: Padding(
                key: ValueKey<int>(step),
                padding: const EdgeInsets.fromLTRB(26, 18, 14, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _head(),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                    if (onBack != null || onNext != null) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _footer(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
