import 'package:flutter/material.dart';

// Pages move by the screen edges instead of fading, which would lay an opacity over the glass.
const Duration kMobileEntranceDuration = Duration(milliseconds: 900);

double _span(double p, double start, double end) => ((p - start) / (end - start)).clamp(0.0, 1.0);

double _out(double p, double start, double end) => Curves.easeOutCubic.transform(_span(p, start, end));

double _in(double p, double start, double end) => Curves.easeInCubic.transform(_span(p, start, end));

// Enough for a card's first row to clear its bottom edge.
const double _contentDrop = 1.2;

// Share of the screen height.
const double _footDrop = 0.3;

enum MobileEntrancePart
{
  head,
  card,

  // In shares of the card's own height, not the screen's.
  content,

  foot,
  area,
}

class MobileEntranceMotion extends InheritedWidget
{
  final Animation<double> progress;

  final bool leaving;

  final bool moving;

  // The arriving page loading out of sight before anything moves.
  final bool waiting;

  const MobileEntranceMotion({
    super.key,
    required this.progress,
    required this.leaving,
    required this.moving,
    required this.waiting,
    required super.child,
  });

  static MobileEntranceMotion? maybeOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<MobileEntranceMotion>();
  }

  // Downwards, in shares of the screen height; 0 at rest.
  double shift(MobileEntrancePart part)
  {
    final double p = progress.value;

    if (leaving)
    {
      return switch (part)
      {
        MobileEntrancePart.head => -Curves.easeInOutCubic.transform(_span(p, 0, 0.55)),
        MobileEntrancePart.card => _in(p, 0.2, 0.6),
        MobileEntrancePart.content => _in(p, 0, 0.28) * _contentDrop,
        MobileEntrancePart.foot => _in(p, 0, 0.35) * _footDrop,
        MobileEntrancePart.area => _in(p, 0, 0.6),
      };
    }

    return switch (part)
    {
      MobileEntrancePart.head => -(1 - _out(p, 0.35, 0.9)),
      MobileEntrancePart.card => 1 - _out(p, 0.3, 0.8),
      MobileEntrancePart.content => (1 - _out(p, 0.72, 1)) * _contentDrop,
      MobileEntrancePart.foot => (1 - _out(p, 0.55, 0.95)) * _footDrop,
      MobileEntrancePart.area => 1 - _out(p, 0.35, 0.92),
    };
  }

  double get barRise => leaving ? 1 : _out(progress.value, 0.35, 0.75);

  double get barHead => leaving ? 1 : _out(progress.value, 0.7, 1);

  @override
  bool updateShouldNotify(MobileEntranceMotion oldWidget)
  {
    return progress != oldWidget.progress ||
        leaving != oldWidget.leaving ||
        moving != oldWidget.moving ||
        waiting != oldWidget.waiting;
  }
}

class MobileEntranceShift extends StatelessWidget
{
  final MobileEntrancePart part;
  final Widget child;

  const MobileEntranceShift({super.key, required this.part, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MobileEntranceMotion? motion = MobileEntranceMotion.maybeOf(context);
    final double height = MediaQuery.sizeOf(context).height;

    return AnimatedBuilder(
      animation: motion?.progress ?? kAlwaysCompleteAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, (motion?.shift(part) ?? 0) * height),
        child: child,
      ),
      child: child,
    );
  }
}
