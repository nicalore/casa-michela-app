import 'package:flutter/material.dart';

import 'mobile_entrance_motion.dart';
import 'mobile_handover.dart';

const Duration kMobileRiseDuration = Duration(milliseconds: 520);
const Duration _dropDuration = Duration(milliseconds: 260);

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

    // Loaded out of sight before its page comes in: nothing to see rise.
    final bool unseen = (MobileHandover.maybeOf(context)?.waiting ?? false) ||
        (MobileEntranceMotion.maybeOf(context)?.waiting ?? false);

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
            duration: kMobileRiseDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: switcher,
          )
        : switcher;
  }
}

// Around pages that may come in: a page loading what it shows asks every
// transition bringing it in to wait until the release is called, so it comes
// in complete rather than with its wheel.
class MobileHoldScope extends StatelessWidget
{
  final ValueNotifier<int> holds;
  final Widget child;

  const MobileHoldScope({super.key, required this.holds, required this.child});

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

    // After the frame that builds what was loaded: that frame still sees the
    // wait, so the content switches in place instead of rising.
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
  Widget build(BuildContext context) => child;
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
  late final AnimationController _rise = AnimationController(vsync: this, duration: kMobileRiseDuration)..forward();

  late final Animation<double> _curve = CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic);

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
