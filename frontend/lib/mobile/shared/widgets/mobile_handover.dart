import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'mobile_entrance_motion.dart';
import 'mobile_glass_panel.dart';
import 'mobile_nav_sheet.dart';

// Fractions of the sign-in timeline, 0 login to 1 signed in; sign-out runs it backwards.
const double _formEnd = 0.28;
const double _brandEnd = 0.55;
const double _footerEnd = 0.35;
const double _morphStart = _formEnd;
const double _morphEnd = 0.82;
const double _pageStart = 0.3;
const double _pageEnd = 0.92;
const double _headStart = 0.8;

// Enough for the form's first row to clear the card's bottom edge.
const double _formDrop = 1.2;

// Share of the screen height.
const double _footerDrop = 0.3;

double _span(double p, double start, double end) => ((p - start) / (end - start)).clamp(0.0, 1.0);

// Present while both the sign-in page and the signed-in area are on screen.
class MobileHandover extends InheritedWidget
{
  final Animation<double> progress;
  final GlobalKey cardKey;

  final bool moving;

  // Signed in, the area loading out of sight before anything moves.
  final bool waiting;


  const MobileHandover({
    super.key,
    required this.progress,
    required this.cardKey,
    required this.moving,
    required this.waiting,
    required super.child,
  });

  static MobileHandover? maybeOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<MobileHandover>();
  }

  static double formOut(double p) => Curves.easeInCubic.transform(_span(p, 0, _formEnd)) * _formDrop;

  static double brandOut(double p) => Curves.easeInOutCubic.transform(_span(p, 0, _brandEnd));

  static double footerOut(double p) => Curves.easeInCubic.transform(_span(p, 0, _footerEnd)) * _footerDrop;

  // Past this the signed-in area draws the card's glass itself.
  static bool cardShown(double p) => p < _morphStart;

  static double pageIn(double p) => Curves.easeOutCubic.transform(_span(p, _pageStart, _pageEnd));

  Rect? get cardRect
  {
    final RenderObject? card = cardKey.currentContext?.findRenderObject();

    if (card is! RenderBox || !card.hasSize)
    {
      return null;
    }

    return card.localToGlobal(Offset.zero) & card.size;
  }

  @override
  bool updateShouldNotify(MobileHandover oldWidget)
  {
    return progress != oldWidget.progress ||
        cardKey != oldWidget.cardKey ||
        moving != oldWidget.moving ||
        waiting != oldWidget.waiting;
  }
}

class MobileHandoverRise extends StatelessWidget
{
  final Widget child;

  const MobileHandoverRise({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final Animation<double> signIn = MobileHandover.maybeOf(context)?.progress ?? kAlwaysCompleteAnimation;
    final MobileEntranceMotion? entrance = MobileEntranceMotion.maybeOf(context);
    final double height = MediaQuery.sizeOf(context).height;

    return AnimatedBuilder(
      animation: Listenable.merge([signIn, entrance?.progress ?? kAlwaysCompleteAnimation]),
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          (1 - MobileHandover.pageIn(signIn.value) + (entrance?.shift(MobileEntrancePart.area) ?? 0)) * height,
        ),
        child: child,
      ),
      child: child,
    );
  }
}

// Stands in for the nav sheet until the login card has turned into it.
class MobileHandoverBar extends StatelessWidget
{
  final Widget head;
  final Widget child;

  const MobileHandoverBar({super.key, required this.head, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final MobileHandover? handover = MobileHandover.maybeOf(context);
    final MobileEntranceMotion? entrance = MobileEntranceMotion.maybeOf(context);
    final Animation<double> signIn = handover?.progress ?? kAlwaysCompleteAnimation;
    final Size size = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([signIn, entrance?.progress ?? kAlwaysCompleteAnimation]),
      builder: (context, sheet)
      {
        final double p = signIn.value;
        final Rect bar = MobileNavSheet.collapsedRectFor(context, size);

        // With no card to grow from, the bar rises from below the screen.
        final bool rising = entrance != null && !entrance.leaving && entrance.progress.value < 1;
        final double sinking = entrance != null && entrance.leaving ? entrance.shift(MobileEntrancePart.area) : 0;

        final Widget? glass = rising
            ? _MorphingGlass(
                rect: Rect.lerp(bar.shift(Offset(0, bar.height)), bar, entrance.barRise)!,
                look: 1,
                headIn: entrance.barHead,
                head: head,
              )
            : p < 1 && !MobileHandover.cardShown(p)
                ? _MorphingGlass(
                    rect: Rect.lerp(handover?.cardRect ?? bar, bar, _morph(p))!,
                    look: _morph(p),
                    headIn: _headIn(p),
                    head: head,
                  )
                : null;

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(0, sinking * size.height),
              child: Offstage(offstage: rising || p < 1, child: sheet),
            ),
            ?glass,
          ],
        );
      },
      child: child,
    );
  }
}

double _morph(double p) => Curves.easeInOutCubic.transform(_span(p, _morphStart, _morphEnd));

double _headIn(double p) => Curves.easeOutCubic.transform(_span(p, _headStart, 1));

class _MorphingGlass extends StatelessWidget
{
  final Rect rect;

  // 0 the login card's glass, 1 the bar's.
  final double look;

  // 0 below the glass's bottom edge, 1 in place.
  final double headIn;

  final Widget head;

  const _MorphingGlass({required this.rect, required this.look, required this.headIn, required this.head});

  // A rounded Border needs one colour, so the sides thin out instead of fading.
  static Border _border(double t)
  {
    final Color edge = Colors.white.withValues(alpha: lerpDouble(MobileGlassPanel.edgeAlpha, 0.7, t)!);
    final BorderSide side = t < 1 ? BorderSide(color: edge, width: 1 - t) : BorderSide.none;

    return Border(top: BorderSide(color: edge), left: side, right: side, bottom: side);
  }

  @override
  Widget build(BuildContext context)
  {
    final double t = look;
    final BoxDecoration bar = MobileNavSheet.glass;
    final BorderRadius radius = BorderRadius.lerp(MobileGlassPanel.cardRadius, bar.borderRadius as BorderRadius, t)!;
    final double highlightInset = radius.topLeft.x;
    final double highlight = MobileGlassPanel.highlightAlpha * (1 - t);

    return Positioned.fromRect(
      rect: rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: BoxShadow.lerpList(MobileGlassPanel.cardShadow, bar.boxShadow, t),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white.withValues(alpha: MobileGlassPanel.cardAlpha), bar.color, t),
                  borderRadius: radius,
                  border: _border(t),
                ),
              ),
              Positioned(
                top: 0,
                left: highlightInset,
                right: highlightInset,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: highlight),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, (1 - headIn) * rect.height),
                  child: head,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
