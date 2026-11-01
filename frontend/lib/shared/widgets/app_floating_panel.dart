import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';

// Edges grabbed to resize; corners wider than the panel's rounding.
const double _edgeGrip = 8;
const double _cornerGrip = 22;

const double _hiddenScale = 0.94;

const double _radius = 24;

// Between a docked panel and the page beside it.
const double kFloatingDockGap = 16;

// The panel against an edge and the hand this much further offers to dock it there,
// wherever the panel was taken: a panel only laid against an edge stays free.
const double _dockPush = 32;

// Left to the page beside a docked panel, however far the panel is pulled.
const double _leastBehind = 160;

// How far under the grab point the panel's top stays when it is torn off a dock.
const double _tearGrab = 40;

const Duration _morphDuration = Duration(milliseconds: 220);

double _fit(double value, double least, double most)
{
  final double top = math.max(0, most);

  return value.clamp(math.min(least, top), top).toDouble();
}

enum AppFloatingDock
{
  none,
  top,
  left,
  right,
  bottom,
}

// Where a floating panel was left: kept from the nearer side, so a resize keeps it there;
// and how wide or tall it was docked, for the next time it docks.
@immutable
class AppFloatingPlace
{
  final AppFloatingDock dock;

  // Floating: from the left edge, or from the right one when [fromRight].
  final double side;
  final bool fromRight;

  final double top;
  final double width;

  // Infinite: as tall as the room.
  final double height;

  // Docked on a side, and docked at the top or the bottom.
  final double sideWidth;
  final double stripHeight;

  const AppFloatingPlace({
    this.dock = AppFloatingDock.none,
    this.side = 0,
    this.fromRight = true,
    this.top = 0,
    required this.width,
    this.height = double.infinity,
    double? sideWidth,
    required this.stripHeight,
  }) : sideWidth = sideWidth ?? width;

  bool get isDocked => dock != AppFloatingDock.none;

  AppFloatingPlace _copy({
    AppFloatingDock? dock,
    double? side,
    bool? fromRight,
    double? top,
    double? width,
    double? height,
    double? sideWidth,
    double? stripHeight,
  })
  {
    return AppFloatingPlace(
      dock: dock ?? this.dock,
      side: side ?? this.side,
      fromRight: fromRight ?? this.fromRight,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      sideWidth: sideWidth ?? this.sideWidth,
      stripHeight: stripHeight ?? this.stripHeight,
    );
  }

  // Floating where [rect] stands.
  AppFloatingPlace floatingAt(Rect rect, Size room)
  {
    final double right = room.width - rect.right;
    final bool fromRight = right <= rect.left;

    return _copy(
      dock: AppFloatingDock.none,
      side: fromRight ? right : rect.left,
      fromRight: fromRight,
      top: rect.top,
      width: rect.width,
      height: rect.height >= room.height ? double.infinity : rect.height,
    );
  }

  AppFloatingPlace dockedTo(AppFloatingDock dock) => _copy(dock: dock);

  // Docked as wide or as tall as [rect].
  AppFloatingPlace dockedAs(Rect rect)
  {
    return dock == AppFloatingDock.top || dock == AppFloatingDock.bottom
        ? _copy(stripHeight: rect.height)
        : _copy(sideWidth: rect.width);
  }

  Rect floatingWithin(Size room, Size least)
  {
    final double width = _fit(this.width, least.width, room.width);
    final double height = _fit(this.height, least.height, room.height);
    final double left = (fromRight ? room.width - side - width : side).clamp(0, room.width - width).toDouble();

    return Rect.fromLTWH(left, top.clamp(0, room.height - height).toDouble(), width, height);
  }

  Rect within(Size room, Size least) => dockedWithin(dock, room, least) ?? floatingWithin(room, least);

  // Where it would stand docked to [dock]; null for none.
  Rect? dockedWithin(AppFloatingDock dock, Size room, Size least)
  {
    final double wide = _fit(sideWidth, least.width, room.width - _leastBehind - kFloatingDockGap);
    final double tall = _fit(stripHeight, least.height, room.height - _leastBehind - kFloatingDockGap);

    return switch (dock)
    {
      AppFloatingDock.none => null,
      AppFloatingDock.left => Rect.fromLTWH(0, 0, wide, room.height),
      AppFloatingDock.right => Rect.fromLTWH(room.width - wide, 0, wide, room.height),
      AppFloatingDock.top => Rect.fromLTWH(0, 0, room.width, tall),
      AppFloatingDock.bottom => Rect.fromLTWH(0, room.height - tall, room.width, tall),
    };
  }

  @override
  bool operator ==(Object other)
  {
    return other is AppFloatingPlace &&
        other.dock == dock &&
        other.side == side &&
        other.fromRight == fromRight &&
        other.top == top &&
        other.width == width &&
        other.height == height &&
        other.sideWidth == sideWidth &&
        other.stripHeight == stripHeight;
  }

  @override
  int get hashCode => Object.hash(dock, side, fromRight, top, width, height, sideWidth, stripHeight);
}

// What a gesture moves: x and y are -1 for the start edge, 1 for the end one, 0 for neither.
@immutable
class _Grip
{
  final int x;
  final int y;

  const _Grip(this.x, this.y);

  static const _Grip move = _Grip(0, 0);

  static const List<_Grip> edges = [
    _Grip(-1, 0),
    _Grip(1, 0),
    _Grip(0, -1),
    _Grip(0, 1),
    _Grip(-1, -1),
    _Grip(1, -1),
    _Grip(-1, 1),
    _Grip(1, 1),
  ];

  bool get moves => x == 0 && y == 0;

  // Docked, only the edge facing the page moves.
  static _Grip? facingPage(AppFloatingDock dock)
  {
    return switch (dock)
    {
      AppFloatingDock.none => null,
      AppFloatingDock.left => const _Grip(1, 0),
      AppFloatingDock.right => const _Grip(-1, 0),
      AppFloatingDock.top => const _Grip(0, 1),
      AppFloatingDock.bottom => const _Grip(0, -1),
    };
  }

  MouseCursor get cursor
  {
    if (y == 0)
    {
      return SystemMouseCursors.resizeLeftRight;
    }

    if (x == 0)
    {
      return SystemMouseCursors.resizeUpDown;
    }

    return x == y ? SystemMouseCursors.resizeUpLeftDownRight : SystemMouseCursors.resizeUpRightDownLeft;
  }
}

// A panel over [behind] that is moved by its [AppFloatingGrip] and resized from its edges.
// Carried to an edge it docks there and [behind] keeps the rest of the room.
// It fades in and out where it stands, its place being anyone's guess.
class AppFloatingPanel extends StatefulWidget
{
  final AppFloatingPlace place;

  // Smaller only when the room is.
  final Size least;

  final bool open;

  // Something is carried out of it: floating, it steps aside; docked, it covers nothing.
  final bool carrying;

  final ValueChanged<AppFloatingPlace>? onPlaceChanged;

  final Widget behind;

  final Widget child;

  const AppFloatingPanel({
    super.key,
    required this.place,
    required this.least,
    this.open = true,
    this.carrying = false,
    this.onPlaceChanged,
    required this.behind,
    required this.child,
  });

  @override
  State<AppFloatingPanel> createState() => _AppFloatingPanelState();
}

class _AppFloatingPanelState extends State<AppFloatingPanel> with SingleTickerProviderStateMixin
{
  late AppFloatingPlace _place = widget.place;

  // While a gesture runs: the rect in hand, and the dock it would land in.
  Rect? _live;
  _Grip? _grip;
  AppFloatingDock _offered = AppFloatingDock.none;

  // The last dock offered, kept while its outline fades.
  AppFloatingDock _outlined = AppFloatingDock.none;

  Rect _start = Rect.zero;
  Offset _origin = Offset.zero;
  Size _room = Size.zero;

  // Where the panel stood when it last went somewhere at once; it travels from there.
  Rect? _from;
  Rect _drawn = Rect.zero;

  late final AnimationController _morph = AnimationController(vsync: this, duration: _morphDuration, value: 1)
    ..addStatusListener((status)
    {
      if (status == AnimationStatus.completed && _from != null)
      {
        setState(() => _from = null);
      }
    });

  late final Animation<double> _travel = CurvedAnimation(parent: _morph, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(AppFloatingPanel oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.place != oldWidget.place)
    {
      _place = widget.place;
    }
  }

  @override
  void dispose()
  {
    _morph.dispose();
    super.dispose();
  }

  // Docked while not torn off by the hand.
  AppFloatingDock get _dock => _grip?.moves ?? false ? AppFloatingDock.none : _place.dock;

  bool get _shown => widget.open && (_dock != AppFloatingDock.none || !widget.carrying);

  Rect get _target => _live ?? _place.within(_room, widget.least);

  void _travelFromHere()
  {
    if (!VisualEffects.on)
    {
      return;
    }

    _from = _drawn;
    _morph.forward(from: 0);
  }

  Offset? _local(Offset global)
  {
    final RenderObject? box = context.findRenderObject();

    return box is RenderBox && box.hasSize ? box.globalToLocal(global) : null;
  }

  // The edge the hand pushes the panel furthest past, beyond [_dockPush].
  AppFloatingDock _dockPushed(Offset delta)
  {
    final Rect wanted = _start.shift(delta);

    final pushes = {
      AppFloatingDock.top: -wanted.top,
      AppFloatingDock.left: -wanted.left,
      AppFloatingDock.right: wanted.right - _room.width,
      AppFloatingDock.bottom: wanted.bottom - _room.height,
    }..removeWhere((dock, push) => push < _dockPush);

    if (pushes.isEmpty)
    {
      return AppFloatingDock.none;
    }

    return pushes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // Off a dock, at the size it floats at, the grab point where it was across the panel.
  Rect _tornOff(Rect docked, Offset point)
  {
    final Size size = _place.floatingWithin(_room, widget.least).size;
    final double across = docked.width == 0 ? 0 : (point.dx - docked.left) / docked.width;
    final double below = math.min(point.dy - docked.top, _tearGrab);

    return Rect.fromLTWH(
      (point.dx - across * size.width).clamp(0, math.max(0, _room.width - size.width)).toDouble(),
      (point.dy - below).clamp(0, math.max(0, _room.height - size.height)).toDouble(),
      size.width,
      size.height,
    );
  }

  void _begin(_Grip grip, Offset position)
  {
    final Rect here = _place.within(_room, widget.least);

    setState(()
    {
      _origin = position;
      _start = here;

      if (grip.moves && _place.isDocked)
      {
        final Offset? point = _local(position);

        if (point != null)
        {
          _travelFromHere();
          _start = _tornOff(here, point);
        }
      }

      _grip = grip;
      _live = _start;
    });
  }

  void _update(Offset position)
  {
    final _Grip? grip = _grip;

    if (grip == null)
    {
      return;
    }

    final Offset delta = position - _origin;

    setState(()
    {
      if (grip.moves)
      {
        _live = _moved(delta);
        _offered = _dockPushed(delta);

        if (_offered != AppFloatingDock.none)
        {
          _outlined = _offered;
        }
      }
      else
      {
        _live = _resized(grip, delta);
      }
    });
  }

  void _end()
  {
    final Rect? live = _live;
    final _Grip? grip = _grip;

    if (live == null || grip == null)
    {
      return;
    }

    final AppFloatingPlace place;

    if (!grip.moves && _place.isDocked)
    {
      place = _place.dockedAs(live);
    }
    else if (grip.moves && _offered != AppFloatingDock.none)
    {
      _travelFromHere();
      place = _place.floatingAt(live, _room).dockedTo(_offered);
    }
    else
    {
      place = _place.floatingAt(live, _room);
    }

    setState(()
    {
      _place = place;
      _live = null;
      _grip = null;
      _offered = AppFloatingDock.none;
    });

    widget.onPlaceChanged?.call(place);
  }

  Rect _moved(Offset delta)
  {
    return Rect.fromLTWH(
      (_start.left + delta.dx).clamp(0, math.max(0, _room.width - _start.width)).toDouble(),
      (_start.top + delta.dy).clamp(0, math.max(0, _room.height - _start.height)).toDouble(),
      _start.width,
      _start.height,
    );
  }

  Rect _resized(_Grip grip, Offset delta)
  {
    final double width = math.min(widget.least.width, _start.width);
    final double height = math.min(widget.least.height, _start.height);

    // Docked, the page beside keeps its share.
    final double behind = _place.isDocked ? _leastBehind + kFloatingDockGap : 0;

    double left = _start.left;
    double top = _start.top;
    double right = _start.right;
    double bottom = _start.bottom;

    if (grip.x < 0)
    {
      left = (left + delta.dx).clamp(math.min(behind, right - width), right - width).toDouble();
    }
    else if (grip.x > 0)
    {
      right = (right + delta.dx).clamp(left + width, math.max(left + width, _room.width - behind)).toDouble();
    }

    if (grip.y < 0)
    {
      top = (top + delta.dy).clamp(math.min(behind, bottom - height), bottom - height).toDouble();
    }
    else if (grip.y > 0)
    {
      bottom = (bottom + delta.dy).clamp(top + height, math.max(top + height, _room.height - behind)).toDouble();
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  // The page keeps what a docked, open panel leaves of the room.
  EdgeInsets _behindInsets(Rect panel)
  {
    if (!widget.open)
    {
      return EdgeInsets.zero;
    }

    return switch (_dock)
    {
      AppFloatingDock.none => EdgeInsets.zero,
      AppFloatingDock.top => EdgeInsets.only(top: panel.bottom + kFloatingDockGap),
      AppFloatingDock.left => EdgeInsets.only(left: panel.right + kFloatingDockGap),
      AppFloatingDock.right => EdgeInsets.only(right: _room.width - panel.left + kFloatingDockGap),
      AppFloatingDock.bottom => EdgeInsets.only(bottom: _room.height - panel.top + kFloatingDockGap),
    };
  }

  Widget _buildEdge(_Grip grip)
  {
    final Widget area = MouseRegion(
      cursor: grip.cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _begin(grip, details.globalPosition),
        onPanUpdate: (details) => _update(details.globalPosition),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
      ),
    );

    final bool corner = grip.x != 0 && grip.y != 0;
    final double across = corner ? _cornerGrip : _edgeGrip;

    return Positioned(
      left: grip.x > 0 ? null : (grip.x < 0 ? 0 : _cornerGrip),
      right: grip.x < 0 ? null : (grip.x > 0 ? 0 : _cornerGrip),
      top: grip.y > 0 ? null : (grip.y < 0 ? 0 : _cornerGrip),
      bottom: grip.y < 0 ? null : (grip.y > 0 ? 0 : _cornerGrip),
      width: grip.x != 0 ? across : null,
      height: grip.y != 0 ? across : null,
      child: area,
    );
  }

  Widget _buildOutline(Duration fade)
  {
    final Rect? rect = _place.dockedWithin(_outlined, _room, widget.least);

    // Always a Positioned, so the panel after it keeps its place among the children.
    if (rect == null)
    {
      return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());
    }

    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _offered == AppFloatingDock.none ? 0 : 1,
          duration: fade,
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.trialTealDeep.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: AppTheme.trialTealDeep.withValues(alpha: 0.55), width: 2),
            ),
          ),
        ),
      ),
    );
  }

  // The card travels; what it holds is laid out where it is going, and shows through the card as it gets there.
  Widget _buildCard(Rect target, Rect frame)
  {
    final AppFloatingDock dock = _dock;
    final _Grip? facing = _Grip.facingPage(dock);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(color: Color(0x3D0B3350), blurRadius: 48, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x140B3350), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: target.width,
                maxWidth: target.width,
                minHeight: target.height,
                maxHeight: target.height,
                child: Transform.translate(
                  offset: target.topLeft - frame.topLeft,
                  child: RepaintBoundary(child: widget.child),
                ),
              ),
            ),
          ),
          if (_from == null)
            if (facing != null) _buildEdge(facing) else for (final grip in _Grip.edges) _buildEdge(grip),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Duration fade = VisualEffects.of(context) ? VisualEffects.plainFade : const Duration(microseconds: 1);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        _room = constraints.biggest;

        return AnimatedBuilder(
          animation: _travel,
          builder: (context, child)
          {
            final Rect target = _target;
            final Rect? from = _from;
            final Rect frame = from == null ? target : Rect.lerp(from, target, _travel.value)!;
            final EdgeInsets insets = _behindInsets(target);

            _drawn = frame;

            return Stack(
              children: [
                Positioned(
                  left: insets.left,
                  top: insets.top,
                  right: insets.right,
                  bottom: insets.bottom,
                  child: widget.behind,
                ),
                _buildOutline(fade),
                Positioned.fromRect(
                  rect: frame,
                  child: IgnorePointer(
                    ignoring: !_shown,
                    child: AnimatedOpacity(
                      opacity: _shown ? 1 : 0,
                      duration: fade,
                      curve: Curves.easeOutCubic,
                      child: AnimatedScale(
                        scale: _shown ? 1 : _hiddenScale,
                        duration: fade,
                        curve: Curves.easeOutCubic,
                        child: _FloatingScope(panel: this, child: _buildCard(target, frame)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FloatingScope extends InheritedWidget
{
  final _AppFloatingPanelState panel;

  const _FloatingScope({required this.panel, required super.child});

  @override
  bool updateShouldNotify(_FloatingScope oldWidget) => panel != oldWidget.panel;
}

// The part of a floating panel it is carried by; nothing outside one.
class AppFloatingGrip extends StatefulWidget
{
  final Widget child;

  const AppFloatingGrip({super.key, required this.child});

  @override
  State<AppFloatingGrip> createState() => _AppFloatingGripState();
}

class _AppFloatingGripState extends State<AppFloatingGrip>
{
  bool _held = false;

  void _hold(bool held)
  {
    if (held != _held)
    {
      setState(() => _held = held);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final _AppFloatingPanelState? panel = context.dependOnInheritedWidgetOfExactType<_FloatingScope>()?.panel;

    if (panel == null)
    {
      return widget.child;
    }

    return MouseRegion(
      cursor: _held ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details)
        {
          _hold(true);
          panel._begin(_Grip.move, details.globalPosition);
        },
        onPanUpdate: (details) => panel._update(details.globalPosition),
        onPanEnd: (_)
        {
          _hold(false);
          panel._end();
        },
        onPanCancel: ()
        {
          _hold(false);
          panel._end();
        },
        child: widget.child,
      ),
    );
  }
}
