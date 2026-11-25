import 'package:flutter/material.dart';

import 'mobile_entrance_motion.dart';
import 'mobile_handover.dart';

const Duration kMobileRiseDuration = Duration(milliseconds: 520);

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

// Loading and content swap in place: no rise, no drop.
class MobileLoadSwitcher extends StatelessWidget
{
  final Widget? child;

  // Defaults to whether child is a MobileWaiting.
  final bool? waiting;

  const MobileLoadSwitcher({super.key, required this.child, this.waiting});

  @override
  Widget build(BuildContext context)
  {
    final Widget? child = this.child;

    if (child == null)
    {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(key: ValueKey(waiting ?? child is MobileWaiting), child: child);
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
