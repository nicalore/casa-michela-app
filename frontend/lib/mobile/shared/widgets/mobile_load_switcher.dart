import 'package:flutter/material.dart';

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

    final Widget switcher = AnimatedSwitcher(
      duration: kMobileRiseDuration,
      reverseDuration: _dropDuration,
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
