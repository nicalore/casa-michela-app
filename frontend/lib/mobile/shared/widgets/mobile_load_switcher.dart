import 'package:flutter/material.dart';

import 'mobile_entrance_motion.dart';
import 'mobile_handover.dart';

const Duration kMobileRiseDuration = Duration(milliseconds: 520);
const Duration _dropDuration = Duration(milliseconds: 260);

// Loading out of sight before its page comes in: nothing to animate.
bool mobileUnseen(BuildContext context)
{
  return (MobileHandover.maybeOf(context)?.waiting ?? false) ||
      (MobileEntranceMotion.maybeOf(context)?.waiting ?? false) ||
      MobileHoldScope.waitingOf(context);
}

// Never zero: AnimatedSize would re-dirty itself while laying out.
Duration mobileRiseDurationOf(BuildContext context)
{
  return mobileUnseen(context) ? const Duration(milliseconds: 1) : kMobileRiseDuration;
}

class MobileWaiting extends StatelessWidget
{
  const MobileWaiting({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
        ),
      ),
    );
  }
}

class MobileLoadSwitcher extends StatelessWidget
{
  final Widget? child;

  // Defaults to whether child is a MobileWaiting.
  final bool? waiting;

  // Rises from the card's own bottom edge instead of the screen's.
  final bool contained;

  const MobileLoadSwitcher({super.key, required this.child, this.waiting, this.contained = false});

  @override
  Widget build(BuildContext context)
  {
    final Widget? child = this.child;
    final double height = MediaQuery.sizeOf(context).height;

    final bool unseen = mobileUnseen(context);

    final Widget switcher = AnimatedSwitcher(
      duration: unseen ? Duration.zero : kMobileRiseDuration,
      reverseDuration: unseen ? Duration.zero : _dropDuration,
      switchInCurve: Curves.easeOutCubic,
      // Runs in reverse on the way out, so the leaving child speeds up.
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => contained
          ? ClipRect(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(0, 1 - animation.value),
                  child: child,
                ),
                child: child,
              ),
            )
          : AnimatedBuilder(
              animation: animation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, (1 - animation.value) * height),
                child: child,
              ),
              child: child,
            ),
      child: child == null
          ? null
          : KeyedSubtree(key: ValueKey(waiting ?? child is MobileWaiting), child: child),
    );

    return contained
        ? AnimatedSize(
            duration: mobileRiseDurationOf(context),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: switcher,
          )
        : switcher;
  }
}

// A loading page holds every transition bringing it in until released, so it arrives complete.
class MobileHoldScope extends InheritedWidget
{
  final ValueNotifier<int> holds;

  final bool waiting;

  const MobileHoldScope({super.key, required this.holds, this.waiting = false, required super.child});

  static bool waitingOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<MobileHoldScope>()?.waiting ?? false;
  }

  // Callable from initState.
  static VoidCallback hold(BuildContext context)
  {
    final List<ValueNotifier<int>> scopes = [];

    context.visitAncestorElements((element)
    {
      final Widget widget = element.widget;

      if (widget is MobileHoldScope)
      {
        scopes.add(widget.holds);
      }

      return true;
    });

    for (final ValueNotifier<int> holds in scopes)
    {
      holds.value++;
    }

    bool released = false;

    // Released after the next frame, which still sees the wait, so content switches in place.
    return ()
    {
      if (released)
      {
        return;
      }

      released = true;

      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        for (final ValueNotifier<int> holds in scopes)
        {
          holds.value--;
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    };
  }

  @override
  bool updateShouldNotify(MobileHoldScope oldWidget)
  {
    return waiting != oldWidget.waiting || holds != oldWidget.holds;
  }
}

// For content built anew once data arrives, where no switcher held the wait.
class MobileRiseIn extends StatefulWidget
{
  final Widget child;

  const MobileRiseIn({super.key, required this.child});

  @override
  State<MobileRiseIn> createState() => _MobileRiseInState();
}

class _MobileRiseInState extends State<MobileRiseIn> with SingleTickerProviderStateMixin
{
  late final AnimationController _rise = AnimationController(vsync: this, duration: kMobileRiseDuration);

  late final Animation<double> _curve = CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic);

  bool _started = false;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (_started)
    {
      return;
    }

    _started = true;

    if (mobileUnseen(context))
    {
      _rise.value = 1;
    }
    else
    {
      _rise.forward();
    }
  }

  @override
  void dispose()
  {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final double height = MediaQuery.sizeOf(context).height;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (1 - _curve.value) * height),
        child: child,
      ),
      child: widget.child,
    );
  }
}
