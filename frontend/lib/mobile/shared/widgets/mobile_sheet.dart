import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';
import 'mobile_glass_panel.dart';
import 'mobile_nav_sheet.dart';

const double _grabberWidth = 38;
const double _grabberHeight = 5;

const double _topPadding = 14;
const double _bottomPadding = 24;

const double _topClearance = 24;

const double _sidePadding = 24;

// A face's gold ring and halo reach this far past its circle; the page clips at the head.
const double _leadingRoom = 8;

int _openSheets = 0;

const Duration _turnDuration = Duration(milliseconds: 380);
// Gentle at both ends: a fast start showed its first, heaviest frame as a jump.
const Curve _turnCurve = Curves.easeInOutCubic;

const double _turnDrift = 0.3;

const double _swipeDistance = 60;
const double _swipeVelocity = 500;

// From inside a sheet, turns that sheet to the new page instead of raising another.
Future<T?> showMobileSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool draggable = true,
})
{
  final _HostScope? scope = context.getInheritedWidgetOfExactType<_HostScope>();

  if (scope != null && scope.host.mounted)
  {
    return scope.host.push<T>(builder);
  }

  _openSheets += 1;
  MobileNavSheet.hidden.value = true;

  // The route strips the top inset; captured here to keep tall sheets below the status bar.
  final double statusBar = MediaQuery.paddingOf(context).top;

  // Built once: the route rebuilds every keyboard frame.
  Widget? sheet;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: draggable,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppTheme.trialDeepWater.withValues(alpha: 0.42),
    constraints: const BoxConstraints(maxWidth: MobileNavSheet.tabletWidth),
    builder: (context) => _StatusBarInset(statusBar: statusBar, child: sheet ??= _SheetHost(builder: builder)),
  ).whenComplete(()
  {
    _openSheets -= 1;

    // Deferred a turn, so a sheet handing over to another keeps the bar down.
    Future<void>.delayed(Duration.zero, ()
    {
      if (_openSheets == 0)
      {
        MobileNavSheet.hidden.value = false;
      }
    });
  });
}

// A later page's answer goes to its caller; the page stays until the caller turns back or closes.
void finishMobileSheet<T>(BuildContext context, [T? result])
{
  if (!context.mounted)
  {
    return;
  }

  final _HostScope? scope = context.getInheritedWidgetOfExactType<_HostScope>();

  if (scope == null || scope.depth == 0)
  {
    Navigator.of(context).pop(result);

    return;
  }

  scope.host.finish(scope.depth, result);
}

void closeMobileSheet(BuildContext context)
{
  if (!context.mounted)
  {
    return;
  }

  final _HostScope? scope = context.getInheritedWidgetOfExactType<_HostScope>();

  if (scope != null && scope.host.mounted)
  {
    scope.host.close();
  }
}

void backMobileSheet(BuildContext context)
{
  if (!context.mounted)
  {
    return;
  }

  final _HostScope? scope = context.getInheritedWidgetOfExactType<_HostScope>();

  if (scope == null || !scope.host.mounted)
  {
    return;
  }

  if (scope.depth > 0)
  {
    scope.host.returnTo(scope.depth - 1);
  }
  else
  {
    scope.host.close();
  }
}

void returnToMobileSheetPage(BuildContext context)
{
  if (!context.mounted)
  {
    return;
  }

  final _HostScope? scope = context.getInheritedWidgetOfExactType<_HostScope>();

  if (scope != null && scope.host.mounted)
  {
    scope.host.returnTo(scope.depth);
  }
}

class _HostScope extends InheritedWidget
{
  final _SheetHostState host;
  final int depth;

  const _HostScope({required this.host, required this.depth, required super.child});

  @override
  bool updateShouldNotify(_HostScope oldWidget) => false;
}

class _HostPage
{
  final Key key;
  final Widget child;

  final Completer<Object?>? answer;

  _HostPage({required this.key, required this.child, this.answer});

  void settle()
  {
    final Completer<Object?>? answer = this.answer;

    if (answer != null && !answer.isCompleted)
    {
      answer.complete();
    }
  }
}

enum _Turning { still, hidden, entering, covered, returning, leaving }

// Covered pages stay built offstage, so each keeps its state for the way back.
class _SheetHost extends StatefulWidget
{
  final WidgetBuilder builder;

  const _SheetHost({required this.builder});

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> with SingleTickerProviderStateMixin
{
  int _keys = 0;

  late final List<_HostPage> _pages = [_page(widget.builder, depth: 0)];

  _HostPage? _leaving;

  // Built offstage two frames first: frame one is the heaviest, a step pager measures on frame two.
  _HostPage? _preparing;

  bool _forward = true;

  late final AnimationController _turn = AnimationController(vsync: this, duration: _turnDuration, value: 1)
    ..addStatusListener(_turned);

  late final Animation<double> _eased = CurvedAnimation(parent: _turn, curve: _turnCurve);

  _HostPage _page(WidgetBuilder builder, {required int depth, Completer<Object?>? answer})
  {
    return _HostPage(
      key: ValueKey<int>(_keys++),
      child: _HostScope(host: this, depth: depth, child: Builder(builder: builder)),
      answer: answer,
    );
  }

  Future<T?> push<T>(WidgetBuilder builder) async
  {
    final Completer<Object?> answer = Completer<Object?>();

    FocusManager.instance.primaryFocus?.unfocus();

    final _HostPage page = _page(builder, depth: _pages.length, answer: answer);

    setState(()
    {
      _forward = true;
      _leaving = null;
      _preparing = page;
      _pages.add(page);
    });

    _afterFrame(() => _afterFrame(()
    {
      if (mounted && identical(_preparing, page))
      {
        setState(() => _preparing = null);
        _turn.forward(from: 0);
      }
    }));

    return await answer.future as T?;
  }

  void _afterFrame(VoidCallback then)
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => then())
      ..scheduleFrame();
  }

  void finish(int depth, Object? result)
  {
    if (depth < _pages.length)
    {
      final Completer<Object?>? answer = _pages[depth].answer;

      if (answer != null && !answer.isCompleted)
      {
        answer.complete(result);
      }
    }
  }

  void returnTo(int depth)
  {
    if (depth >= _pages.length - 1)
    {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final List<_HostPage> gone = _pages.sublist(depth + 1);

    setState(()
    {
      _forward = false;
      _pages.removeRange(depth + 1, _pages.length);
      _leaving = identical(gone.last, _preparing) ? null : gone.last;
      _preparing = null;
    });

    _turn.forward(from: 0);

    for (final page in gone)
    {
      page.settle();
    }
  }

  void close()
  {
    Navigator.of(context).pop();
  }

  void _turned(AnimationStatus status)
  {
    if (status == AnimationStatus.completed && mounted)
    {
      setState(() => _leaving = null);
    }
  }

  @override
  void dispose()
  {
    for (final page in [..._pages, ?_leaving])
    {
      page.settle();
    }

    _turn.dispose();
    super.dispose();
  }

  _Turning _turningOf(int index)
  {
    final int top = _pages.length - 1;
    final bool moving = _turn.isAnimating;

    if (_preparing != null)
    {
      return index == top ? _Turning.hidden : (index == top - 1 ? _Turning.still : _Turning.hidden);
    }

    if (index == top)
    {
      if (!moving)
      {
        return _Turning.still;
      }

      return _forward ? _Turning.entering : _Turning.returning;
    }

    return moving && _forward && index == top - 1 ? _Turning.covered : _Turning.hidden;
  }

  // Same wrappers in every state, so a page is never built anew as it turns.
  Widget _slot(_HostPage page, _Turning turning)
  {
    final bool sizing = turning == _Turning.still || turning == _Turning.entering || turning == _Turning.returning;
    final bool hidden = turning == _Turning.hidden;

    return _PageSlot(
      key: page.key,
      sizing: sizing,
      child: Offstage(
        offstage: hidden,
        child: TickerMode(
          enabled: !hidden,
          child: _TurnMotion(turn: _eased, turning: turning, child: page.child),
        ),
      ),
    );
  }

  // Downward, from where no list scrolls; the sheet's own drag would close it whole.
  double _swipe = 0;

  void _swiped(DragEndDetails details)
  {
    if (_pages.length > 1 && (_swipe > _swipeDistance || (details.primaryVelocity ?? 0) > _swipeVelocity))
    {
      returnTo(_pages.length - 2);
    }

    _swipe = 0;
  }

  @override
  Widget build(BuildContext context)
  {
    final _HostPage? leaving = _leaving;
    final bool turned = _pages.length > 1;

    // Barrier taps and system back pop; on a turned page they go back a page instead.
    return PopScope(
      canPop: !turned,
      onPopInvokedWithResult: (didPop, _)
      {
        if (!didPop && _pages.length > 1)
        {
          returnTo(_pages.length - 2);
        }
      },
      // Same detector at every depth, so pages are never built anew; it takes the drag once turned.
      child: GestureDetector(
        onVerticalDragStart: turned ? (_) => _swipe = 0 : null,
        onVerticalDragUpdate: turned ? (details) => _swipe += details.primaryDelta ?? 0 : null,
        onVerticalDragEnd: turned ? _swiped : null,
        child: _buildFrame(leaving),
      ),
    );
  }

  Widget _buildFrame(_HostPage? leaving)
  {
    return _SheetFrame(
      child: MobileSmoothHeight(
        duration: _turnDuration,
        curve: _turnCurve,
        turn: _preparing == null ? _pages.last.key : _pages[_pages.length - 2].key,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (i, page) in _pages.indexed) _slot(page, _turningOf(i)),
            if (leaving != null) _slot(leaving, _Turning.leaving),
          ],
        ),
      ),
    );
  }
}

// No surface of the pages' own: it changed shade against the glass and as the turn ended.
class _TurnMotion extends AnimatedWidget
{
  final _Turning turning;
  final Widget child;

  const _TurnMotion({required Animation<double> turn, required this.turning, required this.child}) : super(listenable: turn);

  @override
  Widget build(BuildContext context)
  {
    final double t = (listenable as Animation<double>).value;
    final bool moving = t < 1;

    // [upTo]: where the page on top begins, in widths of the page underneath.
    final (double dx, bool edged, double? upTo) = switch (turning)
    {
      _Turning.entering => (1 - t, moving, null),
      _Turning.leaving => (t, moving, null),
      _Turning.covered => (-_turnDrift * t, false, _turnDrift + (1 - _turnDrift) * (1 - t)),
      _Turning.returning => (-_turnDrift * (1 - t), false, _turnDrift + (1 - _turnDrift) * t),
      _ => (0.0, false, null),
    };

    return FractionalTranslation(
      translation: Offset(dx, 0),
      child: ClipRect(
        clipper: _UpTo(upTo ?? 1),
        clipBehavior: upTo == null ? Clip.none : Clip.hardEdge,
        child: CustomPaint(
          painter: edged ? const _EdgeShadow() : null,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}

class _StatusBarInset extends StatelessWidget
{
  final double statusBar;
  final Widget child;

  const _StatusBarInset({required this.statusBar, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData media = MediaQuery.of(context);

    return MediaQuery(data: media.copyWith(padding: media.padding.copyWith(top: statusBar)), child: child);
  }
}

class MobileSheet extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final String? subtitle;

  final Widget? leading;

  final List<Widget> body;

  final Widget? footer;

  // Outside the scrolling body.
  final Widget? subhead;

  // Off, the keyboard covers the sheet's end.
  final bool aboveKeyboard;

  // Replaces [body]; runs edge to edge and scrolls itself.
  final Widget? content;

  const MobileSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.leading,
    this.body = const [],
    this.footer,
    this.subhead,
    this.aboveKeyboard = false,
    this.content,
  });

  // For [content], which the sheet does not inset.
  static const double sidePadding = _sidePadding;

  static Widget _inset(Widget child)
  {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: _sidePadding), child: child);
  }

  // Inside a sheet's host, which draws the glass once for all its pages.
  @override
  Widget build(BuildContext context)
  {
    if (context.getInheritedWidgetOfExactType<_HostScope>() != null)
    {
      return inner(context);
    }

    return _SheetFrame(child: inner(context));
  }

  Widget inner(BuildContext context)
  {
    final Widget? footer = this.footer;
    final Widget? subhead = this.subhead;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inset(_buildHead(context)),
        if (subhead != null) _inset(subhead),
        // A ListView, so only visible rows lay out: some bodies run to dozens.
        Flexible(
          child: content ??
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                children: body,
              ),
        ),
        if (footer != null) _inset(footer),
        if (aboveKeyboard) const _KeyboardGap(),
      ],
    );
  }

  Widget _buildHead(BuildContext context)
  {
    final String? subtitle = this.subtitle;
    final Widget? leading = this.leading;

    return Row(
      crossAxisAlignment: leading == null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: _leadingRoom), child: leading),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.9,
                  color: AppTheme.trialTealDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  height: 1.15,
                  color: AppTheme.trialInk,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: MobilePalette.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        MobileSheetCloseButton(onTap: () => backMobileSheet(context)),
      ],
    );
  }
}

// Its own widget, so only it rebuilds as the keyboard moves.
class _KeyboardGap extends StatelessWidget
{
  const _KeyboardGap();

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(height: MediaQuery.viewInsetsOf(context).bottom);
  }
}

class _SheetFrame extends StatelessWidget
{
  final Widget child;

  const _SheetFrame({required this.child});

  @override
  Widget build(BuildContext context)
  {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);

    final double bottom = padding.bottom + _bottomPadding;
    final double maxHeight = screen.height - padding.top - _topClearance - _topPadding - bottom;

    return MobileGlassPanel.sheet(
      padding: EdgeInsets.fromLTRB(0, _topPadding, 0, bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                decoration: BoxDecoration(
                  color: AppTheme.trialOcean.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(_grabberHeight / 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

// Slides only: an Opacity over glass trips Impeller.
class MobileSideSwitcher extends StatelessWidget
{
  static const double _drift = 0.3;

  final Widget child;
  final bool forward;
  final Duration duration;

  // Off, both slide the whole way, as tabs do; on, the new page is laid over the old.
  final bool stacked;

  final bool instantHeight;

  // The height runs only through a turn: chasing a step pager's own height lifted the footer.
  final bool heightOnlyTurning;

  const MobileSideSwitcher({
    super.key,
    required this.child,
    required this.forward,
    this.duration = const Duration(milliseconds: 300),
    this.stacked = false,
    this.instantHeight = false,
    this.heightOnlyTurning = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final Key? current = child.key;
    const Curve curve = Curves.easeInOutCubic;

    return MobileSmoothHeight(
      duration: duration,
      curve: curve,
      instant: instantHeight,
      turn: heightOnlyTurning ? current : null,
      child: AnimatedSwitcher(
          duration: duration,
          layoutBuilder: (shown, leaving)
          {
            // One keyed wrapper, shown or leaving: a page that changed wrapper would be built anew.
            Widget slot(Widget page, {required bool sizing})
            {
              return _PageSlot(key: page.key, sizing: sizing, child: page);
            }

            final List<Widget> under = [for (final page in leaving) slot(page, sizing: false)];
            final Widget? over = shown == null ? null : slot(shown, sizing: true);

            return Stack(
              clipBehavior: Clip.none,
              children: forward || !stacked ? [...under, ?over] : [?over, ...under],
            );
          },
          // Rebuilt every time, so a leaving child goes the way of the latest turn.
          transitionBuilder: (child, animation)
          {
            final bool entering = child.key == current;

            // The leaving page runs the curve backwards, so both move as one.
            final Animation<double> eased = CurvedAnimation(parent: animation, curve: curve, reverseCurve: curve.flipped);

            if (!stacked)
            {
              final double side = forward ? 1 : -1;

              return SlideTransition(
                position: Tween<Offset>(begin: Offset(entering ? side : -side, 0), end: Offset.zero).animate(eased),
                child: child,
              );
            }

            final bool onTop = forward == entering;

            return SlideTransition(
              position: Tween<Offset>(begin: Offset(onTop ? 1 : -_drift, 0), end: Offset.zero).animate(eased),
              child: AnimatedBuilder(
                animation: eased,
                builder: (context, page)
                {
                  final bool moving = eased.value < 1;

                  final double? upTo = !onTop && moving ? _drift + (1 - _drift) * eased.value : null;

                  return ClipRect(
                    clipper: _UpTo(upTo ?? 1),
                    clipBehavior: upTo == null ? Clip.none : Clip.hardEdge,
                    child: CustomPaint(painter: onTop && moving ? const _EdgeShadow() : null, child: page),
                  );
                },
                child: child,
              ),
            );
          },
          child: child,
        ),
    );
  }
}

// Not AnimatedSize: a change midway restarts from the current height instead of jumping.
class MobileSmoothHeight extends StatefulWidget
{
  final Widget child;
  final Duration duration;
  final Curve curve;

  final bool instant;

  // When given, the height animates only for [duration] after this changes.
  final Object? turn;

  const MobileSmoothHeight({
    super.key,
    required this.child,
    required this.duration,
    required this.curve,
    this.instant = false,
    this.turn,
  });

  @override
  State<MobileSmoothHeight> createState() => _MobileSmoothHeightState();
}

class _MobileSmoothHeightState extends State<MobileSmoothHeight> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void didUpdateWidget(MobileSmoothHeight oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
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
    return _SmoothHeightBox(
      controller: _controller,
      curve: widget.curve,
      instant: widget.instant,
      turn: widget.turn,
      child: widget.child,
    );
  }
}

class _SmoothHeightBox extends SingleChildRenderObjectWidget
{
  final AnimationController controller;
  final Curve curve;
  final bool instant;
  final Object? turn;

  const _SmoothHeightBox({
    required this.controller,
    required this.curve,
    required this.instant,
    required this.turn,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSmoothHeight(controller, curve, turn)..instant = instant;

  @override
  void updateRenderObject(BuildContext context, _RenderSmoothHeight renderObject)
  {
    renderObject
      ..curve = curve
      ..instant = instant
      ..turn = turn;
  }
}

class _RenderSmoothHeight extends RenderProxyBox
{
  // Room left round the clip for shadows of what sits at the edges.
  static const double _bleed = 30;

  final AnimationController _controller;
  Curve curve;
  bool instant = false;

  Object? _turn;
  final bool _turnsOnly;
  bool _turnStarting = false;

  double? _begin;
  double? _end;

  BoxConstraints? _room;

  // So the restart made inside layout does not ask for another layout.
  double _lastValue = 0;

  _RenderSmoothHeight(this._controller, this.curve, Object? turn) : _turn = turn, _turnsOnly = turn != null;

  set turn(Object? value)
  {
    if (value != _turn)
    {
      _turn = value;
      _turnStarting = _turnsOnly;
      markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner)
  {
    super.attach(owner);
    _controller.addListener(_tick);
  }

  @override
  void detach()
  {
    _controller.removeListener(_tick);
    super.detach();
  }

  void _tick()
  {
    if (_controller.value != _lastValue)
    {
      _lastValue = _controller.value;
      markNeedsLayout();
    }
  }

  double get _height => ui.lerpDouble(_begin, _end, curve.transform(_controller.value))!;

  @override
  void performLayout()
  {
    final RenderBox? child = this.child;

    if (child == null)
    {
      size = constraints.smallest;

      return;
    }

    child.layout(constraints, parentUsesSize: true);

    final double target = child.size.height;

    // Room changing at rest (keyboard, rotation) is followed at once, or the sheet trails it.
    final bool roomChanged = _room != null && constraints != _room && !_controller.isAnimating;

    _room = constraints;

    if (_end == null || roomChanged || instant)
    {
      _begin = target;
      _end = target;
    }
    else if (_turnStarting)
    {
      // Runs the whole turn, so a new page measuring itself a frame late still moves smoothly.
      _turnStarting = false;
      _begin = _height;
      _end = target;
      _lastValue = 0;
      _controller.forward(from: 0);
    }
    else if (target != _end)
    {
      if (_turnsOnly && !_controller.isAnimating)
      {
        _begin = target;
        _end = target;
      }
      else
      {
        _begin = _height;
        _end = target;
        _lastValue = 0;
        _controller.forward(from: 0);
      }
    }

    size = constraints.constrain(Size(child.size.width, _height));
  }

  // Always clipped, as a leaving page paints past the box; tight at the foot while the height runs.
  @override
  void paint(PaintingContext context, Offset offset)
  {
    final double foot = _controller.isAnimating ? 0 : _bleed;

    context.pushClipRect(
      needsCompositing,
      offset,
      Rect.fromLTRB(-_bleed, 0, size.width + _bleed, size.height + foot),
      super.paint,
    );
  }
}

class _PageSlot extends SingleChildRenderObjectWidget
{
  final bool sizing;

  const _PageSlot({super.key, required this.sizing, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPageSlot(sizing);

  @override
  void updateRenderObject(BuildContext context, _RenderPageSlot renderObject)
  {
    renderObject.sizing = sizing;
  }
}

class _RenderPageSlot extends RenderProxyBox
{
  bool _sizing;

  _RenderPageSlot(this._sizing);

  set sizing(bool value)
  {
    if (value != _sizing)
    {
      _sizing = value;
      markNeedsLayout();
    }
  }

  @override
  void performLayout()
  {
    final RenderBox? child = this.child;

    if (child == null)
    {
      size = constraints.smallest;

      return;
    }

    child.layout(constraints, parentUsesSize: true);
    size = _sizing ? child.size : constraints.smallest;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position})
  {
    return _sizing && super.hitTest(result, position: position);
  }
}

class _UpTo extends CustomClipper<Rect>
{
  static const double _run = 4000;

  final double fraction;

  const _UpTo(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-_run, -_run, size.width * fraction, size.height + _run);

  @override
  bool shouldReclip(_UpTo oldClipper) => oldClipper.fraction != fraction;
}

class _EdgeShadow extends CustomPainter
{
  static const double _width = 18;
  static const double _fadeIn = 48;
  static const double _run = 2000;

  const _EdgeShadow();

  @override
  void paint(Canvas canvas, Size size)
  {
    final Rect strip = Rect.fromLTWH(-_width, 0, _width, size.height + _run);

    canvas.saveLayer(strip, Paint());
    canvas.drawRect(
      strip,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0x00000000), Color(0x1F000000)])
            .createShader(Rect.fromLTWH(-_width, 0, _width, 1)),
    );
    canvas.drawRect(
      strip,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(const Rect.fromLTWH(0, 0, 1, _fadeIn)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgeShadow oldDelegate) => false;
}

class MobileSheetCloseButton extends StatelessWidget
{
  final VoidCallback onTap;

  const MobileSheetCloseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Chiudi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.trialInk.withValues(alpha: 0.07),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: AppTheme.trialInk.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class MobileSheetCard extends StatelessWidget
{
  static const double radius = 18;

  final Widget child;

  const MobileSheetCard({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        boxShadow: [BoxShadow(color: Color(0x12122438), offset: Offset(0, 4), blurRadius: 14)],
      ),
      child: child,
    );
  }
}

class MobileSheetText extends StatelessWidget
{
  final String text;

  const MobileSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppTheme.trialInk.withValues(alpha: 0.8),
      ),
    );
  }
}
