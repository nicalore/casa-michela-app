import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'mobile_subject_card.dart';

const Duration _settleDuration = Duration(milliseconds: 220);
const Duration _collapseDuration = Duration(milliseconds: 260);

// Share of the width that commits the swipe, capped in pixels for tablets.
const double _threshold = 0.4;
const double _thresholdCap = 120;

// Of the others' touch slop: decide just before them, as the first to accept wins.
const double _decisionShare = 0.9;

// A flick faster than this commits on its own.
const double _flickVelocity = 700;

// Keeps the card's shadow inside the clip.
const double _shadowSlack = 60;

// Half the gap to the next card: bleed into the gap, never onto the neighbour.
const double _gapSlack = 6;

// Rightwards only: Dismissible claims both directions and swallows the page swipe.
class _RightwardDragRecognizer extends HorizontalDragGestureRecognizer
{
  Offset? _down;

  // Android reports 8, iOS leaves Flutter's 18; the page view below claims at it.
  double get _slop => (gestureSettings?.touchSlop ?? kTouchSlop) * _decisionShare;

  @override
  void addAllowedPointer(PointerDownEvent event)
  {
    _down = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event)
  {
    final Offset? down = _down;

    if (down != null && event is PointerMoveEvent)
    {
      final Offset moved = event.position - down;

      if (moved.distance >= _slop)
      {
        _down = null;

        if (moved.dx <= moved.dy.abs())
        {
          resolve(GestureDisposition.rejected);
          stopTrackingPointer(event.pointer);

          return;
        }

        // Accept now rather than at our own slop: the first to accept wins.
        super.handleEvent(event);
        resolve(GestureDisposition.accepted);

        return;
      }
    }

    super.handleEvent(event);
  }
}

// The red covers only the uncovered strip: the glass card above is see-through.
class MobileRemovableRow extends StatefulWidget
{
  final Widget child;

  // True removes the row, which stays held open while it waits.
  final Future<bool> Function() onConfirm;

  final VoidCallback onRemoved;

  final double gap;

  // Removal confirmed elsewhere: the row leaves as after a slide.
  final bool leaving;

  const MobileRemovableRow({
    super.key,
    required this.child,
    required this.onConfirm,
    required this.onRemoved,
    this.gap = 0,
    this.leaving = false,
  });

  @override
  State<MobileRemovableRow> createState() => _MobileRemovableRowState();
}

class _MobileRemovableRowState extends State<MobileRemovableRow>
    with SingleTickerProviderStateMixin
{
  // Not lazy: dispose() would otherwise create it on an unmounted element.
  late final AnimationController _controller;

  double _offset = 0;
  double _width = 1;

  bool _asking = false;
  bool _leaving = false;

  // Null until the card has slid away.
  double? _height;
  double _standing = 1;

  @override
  void initState()
  {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _settleDuration);
  }

  @override
  void didUpdateWidget(MobileRemovableRow oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.leaving && !oldWidget.leaving && !_asking)
    {
      _leave();
    }
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Duration duration, Curve curve, ValueChanged<double> apply)
  {
    final Animation<double> progress = CurvedAnimation(parent: _controller, curve: curve);

    void follow()
    {
      setState(() => apply(progress.value));
    }

    _controller
      ..duration = duration
      ..reset()
      ..addListener(follow);

    return _controller.forward().whenComplete(() => _controller.removeListener(follow));
  }

  Future<void> _animateTo(double target)
  {
    final double from = _offset;

    return _run(_settleDuration, Curves.easeOutCubic, (t) => _offset = from + (target - from) * t);
  }

  Future<void> _collapse()
  {
    _height = context.size?.height ?? 0;

    return _run(_collapseDuration, Curves.easeInOutCubic, (t) => _standing = 1 - t);
  }

  Future<void> _leave() async
  {
    if (_leaving)
    {
      return;
    }

    _leaving = true;

    await _animateTo(_width);

    if (!mounted)
    {
      return;
    }

    await _collapse();

    if (mounted)
    {
      widget.onRemoved();
    }
  }

  void _onStart(DragStartDetails details)
  {
    if (!_leaving)
    {
      _controller.stop();
    }
  }

  void _onUpdate(DragUpdateDetails details)
  {
    if (!_leaving)
    {
      setState(() => _offset = (_offset + details.delta.dx).clamp(0.0, _width));
    }
  }

  Future<void> _onEnd(DragEndDetails details) async
  {
    if (_leaving)
    {
      return;
    }

    final double velocity = details.primaryVelocity ?? 0;
    final double enough = math.min(_width * _threshold, _thresholdCap);
    final bool asked = _offset >= enough || velocity > _flickVelocity;

    if (!asked || _asking)
    {
      await _animateTo(0);

      return;
    }

    _asking = true;

    final bool removed = await widget.onConfirm();

    if (!mounted)
    {
      return;
    }

    _asking = false;

    if (!removed)
    {
      await _animateTo(0);

      return;
    }

    await _leave();
  }

  // Clip only while sliding: never cross a neighbour, keep the whole shadow at rest.
  Widget _clipped(Widget child)
  {
    if (_offset <= 0)
    {
      return child;
    }

    return ClipRect(clipper: const _CellClipper(), child: child);
  }

  Widget _red({required double height, double iconOpacity = 1})
  {
    return ClipRRect(
      borderRadius: BorderRadius.circular(math.min(MobileSubjectCard.radius, height / 2)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.dangerGradient),
        child: Center(
          child: Opacity(
            opacity: iconOpacity,
            child: const Icon(Icons.delete_outline_rounded, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _closing(double height)
  {
    final double red = (height - widget.gap) * _standing;

    return SizedBox(
      height: height * _standing,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: red,
          // Gone before the red is too thin to hold it.
          child: _red(height: red, iconOpacity: ((_standing - 0.5) * 2).clamp(0.0, 1.0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_height case final double height)
    {
      return _closing(height);
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        _width = constraints.maxWidth;

        return RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
            _RightwardDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_RightwardDragRecognizer>(
              _RightwardDragRecognizer.new,
              (recognizer) => recognizer
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                ..onStart = _onStart
                ..onUpdate = _onUpdate
                ..onEnd = _onEnd,
            ),
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.gap),
            child: _clipped(Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: _offset,
                      height: double.infinity,
                      child: _red(height: double.infinity),
                    ),
                  ),
                ),
                Transform.translate(offset: Offset(_offset, 0), child: widget.child),
              ],
            )),
          ),
        );
      },
    );
  }
}

class _CellClipper extends CustomClipper<Rect>
{
  const _CellClipper();

  @override
  Rect getClip(Size size)
  {
    return Rect.fromLTRB(
      -_gapSlack,
      -_shadowSlack,
      size.width + _gapSlack,
      size.height + _shadowSlack,
    );
  }

  @override
  bool shouldReclip(_CellClipper oldClipper) => false;
}
