import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'casa_michela_loader.dart';

// How one page gives way to the next. Walking between the top bar's
// destinations changes what is inside a shell that does not move: they are
// branches of one page, all alive at once, held by [ShellDestinations], and the
// content leaves and arrives one element at a time. Everything else really is a
// change of page.

// One duration for the two of them, so a step reads the same whatever kind it
// is, and the timeline below is that duration divided between the half that
// empties and the half that fills in.
const Duration _pageTransition = Duration(milliseconds: 1200);

// The timeline of a shell step, in fractions of the whole: the page leaving
// empties first, the page arriving fills in after, and in the middle the two
// identical backgrounds are crossfaded so the shell never appears to move.
const double _slotDelay = 0.038;
const int _lastDelayedSlot = 6;

const double _exitSpan = 0.22;
const double _enterStart = 0.40;
const double _enterSpan = 0.32;

// Where each half of the timeline is done: the last slot to be delayed, plus
// the span that slot is given.
const double _exitEnd = _lastDelayedSlot * _slotDelay + _exitSpan;
const double _enterEnd = _enterStart + _lastDelayedSlot * _slotDelay + _enterSpan;

// The turn of a step made in place — see [_HandoverState._held]. With a single
// child the two halves cannot overlap: it has to be empty before what it shows
// can be swapped, so they are laid end to end on the one controller.
const double _reentryTurn = 0.5;

double _reentryProgress(double value)
{
  return value < _reentryTurn
      ? value / _reentryTurn * _exitEnd
      : _enterStart + (value - _reentryTurn) / (1 - _reentryTurn) * (_enterEnd - _enterStart);
}

// Where the page arriving stops holding itself back. It begins before the last
// element has finished leaving on purpose: a moment with nothing on the paper
// reads as a page that failed to load rather than as a page changing.
const double _arrivalFadeStart = 0.36;
const double _arrivalFadeEnd = 0.46;

// A step the wrong way before the dash, and the share of the element's time it
// takes. The pause at the end of it is what makes leaving read as a decision.
const double _runUp = 22;
const double _runUpShare = 0.32;

// Where an element coming in overshoots to before settling back, and the share
// of its time left for that settling.
const double _overshoot = 7;
const double _overshootShare = 0.84;

// Measured on the window and not fixed: a step that reads as leaving on a phone
// is a twitch on a desktop. Out is longer — it has to look gone, not moved.
double _exitTravel(double width) => (width * 0.50).clamp(260.0, 760.0);

double _enterTravel(double width) => (width * 0.22).clamp(130.0, 340.0);

// The page every route of the app is wrapped in: the mark over a white blur.
CustomTransitionPage<void> buildAppTransitionPage({
  required LocalKey key,
  required Widget child,
})
{
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    // The page below has to keep being drawn: it is what the white is laid over.
    opaque: false,
    transitionDuration: _pageTransition,
    reverseTransitionDuration: _pageTransition,
    transitionsBuilder: (context, animation, secondaryAnimation, child)
    {
      return _ScreenTransition(animation: animation, child: child);
    },
  );
}

// One element of a page, in reading order. What is left unwrapped is handed over
// in the crossfade, which is what the shell wants.
//
// The slot is a rank and not a strict index: same slot means moving together,
// and past [_lastDelayedSlot] all at once. Counted within the page, and an
// element must not sit inside another: the transforms would compound.
class PageTransitionItem extends StatelessWidget
{
  // What frames the page: the section rail, the greeting, the heading that
  // stands in for the rail on a narrow window.
  static const int frame = 0;

  // What heads the content: the search field, the button beside it, the
  // filters, the count under them.
  static const int header = 1;

  // The first of the cards. The ones after it follow, one slot each.
  static const int list = 2;

  final int slot;
  final Widget child;

  const PageTransitionItem({
    super.key,
    required this.slot,
    required this.child,
  });

  @override
  Widget build(BuildContext context)
  {
    final scope = _PageTransitionScope.maybeOf(context);

    Offset offset = Offset.zero;
    double opacity = 1;

    // No scope means nothing is moving: either this is not a destination of the
    // shell at all — a person's page, the login — or the one it is in is being
    // read rather than left.
    if (scope != null)
    {
      final Size window = MediaQuery.sizeOf(context);

      // The same journey on whichever axis: destinations run along the bar,
      // sections up the rail. Only which measurement of the window changes.
      final bool sideways = scope.axis == Axis.horizontal;
      final double extent = sideways ? window.width : window.height;

      final double elapsed = _slotProgress(scope.progress, slot, leaving: scope.leaving);

      final double travelled = scope.leaving
          ? _exitOffset(elapsed, _exitTravel(extent))
          : _enterOffset(elapsed, _enterTravel(extent));

      offset = sideways ? Offset(travelled, 0) : Offset(0, travelled);
      opacity = scope.leaving ? _exitOpacity(elapsed) : _enterOpacity(elapsed);
    }

    // The same two widgets whatever is happening: Flutter pairs widgets to
    // elements by position, so handing the element back bare at rest rebuilds
    // everything below it — here whole pages, which then refetched their data.
    // At rest neither costs anything.
    return Transform.translate(
      offset: offset,
      child: Opacity(opacity: opacity, child: child),
    );
  }
}

// Every block of a column on its own beat: left whole, a page of forms leaves as
// one slab, which beside a page of cards reads as two different apps.
//
// The children a Column would have been given, handed back wrapped, so the page
// keeps its own spacing: the air passes through and only what can be seen gets a
// beat. Counted here and not at the call, which is how two blocks share one.
List<Widget> pageTransitionBlocks(List<Widget> children)
{
  var slot = PageTransitionItem.header;

  return [
    for (final child in children)
      if (child is SizedBox && child.child == null)
        child
      else
        PageTransitionItem(slot: slot++, child: child),
  ];
}

// A scroll view that opens its sides while a page is changing: a viewport clips
// all four, so an element walking off was cut at its own column and vanished
// halfway across. It clips nothing and the two scrolling edges are put back by
// hand, opened only during a step and by the width of the window.
//
// Sideways only: between sections the clip does its job, or a card would fly
// over the field and filters above the list.
class PageTransitionScrollView extends StatelessWidget
{
  final Widget child;

  const PageTransitionScrollView({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final scope = _PageTransitionScope.maybeOf(context);

    final bool opening = scope != null && scope.moving && scope.axis == Axis.horizontal;
    final double overhang = opening ? MediaQuery.sizeOf(context).width : 0;

    return ClipRect(
      clipper: _SidewaysClip(overhang),
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        child: child,
      ),
    );
  }
}

class _SidewaysClip extends CustomClipper<Rect>
{
  // How far past either side the content is allowed to be seen. At zero this is
  // the plain bounds of the box, which is what a viewport clips to anyway.
  final double overhang;

  const _SidewaysClip(this.overhang);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(-overhang, 0, size.width + overhang, size.height);

  @override
  bool shouldReclip(_SidewaysClip oldClipper) => oldClipper.overhang != overhang;
}

// Where an element is along its own share of the step: 0 before its turn comes,
// 1 once it is done.
double _slotProgress(double progress, int slot, {required bool leaving})
{
  final int delayed = slot.clamp(0, _lastDelayedSlot);
  final double start = (leaving ? 0.0 : _enterStart) + delayed * _slotDelay;
  final double span = leaving ? _exitSpan : _enterSpan;

  return ((progress - start) / span).clamp(0.0, 1.0);
}

double _exitOffset(double elapsed, double travel)
{
  if (elapsed <= _runUpShare)
  {
    return _runUp * Curves.easeOut.transform(elapsed / _runUpShare);
  }

  final double dash = (elapsed - _runUpShare) / (1 - _runUpShare);

  // Accelerating away from the standstill the run-up ends on, gently: sharper,
  // the element has barely moved by the time it has faded, and the page reads as
  // fading rather than leaving.
  return _runUp + (-travel - _runUp) * Curves.easeIn.transform(dash);
}

double _enterOffset(double elapsed, double travel)
{
  if (elapsed <= _overshootShare)
  {
    return travel + (-_overshoot - travel) * Curves.easeOutCubic.transform(elapsed / _overshootShare);
  }

  final double settle = (elapsed - _overshootShare) / (1 - _overshootShare);

  return -_overshoot * (1 - Curves.easeInOut.transform(settle));
}

// Fading once properly under way and gone before it stops travelling: what says
// "left the page" is the speed and not the distance, and fading at the run-up
// emptied the page before anything had visibly moved.
double _exitOpacity(double elapsed) => 1 - ((elapsed - 0.45) / 0.5).clamp(0.0, 1.0);

double _enterOpacity(double elapsed) => (elapsed / 0.45).clamp(0.0, 1.0);

double _arrivalOpacity(double progress)
{
  return ((progress - _arrivalFadeStart) / (_arrivalFadeEnd - _arrivalFadeStart)).clamp(0.0, 1.0);
}

// What the elements of a page read to know where they are in the step.
class _PageTransitionScope extends InheritedWidget
{
  // 0 at the start of the step and 1 at the end of it, whichever side of the
  // handover this page is on.
  final double progress;

  final bool leaving;

  // Which way the step is being made: along the row for a change of
  // destination, up the column for a change of section.
  final Axis axis;

  // Whether there is anything to get out of the way of. A page that has arrived
  // and is being read sits at the end of its own animation and is not moving;
  // one still to arrive sits at the start of it and is.
  bool get moving => leaving || progress < 1;

  const _PageTransitionScope({
    required this.progress,
    required this.leaving,
    required this.axis,
    required super.child,
  });

  static _PageTransitionScope? maybeOf(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_PageTransitionScope>();
  }

  @override
  bool updateShouldNotify(_PageTransitionScope oldWidget)
  {
    return oldWidget.progress != progress ||
        oldWidget.leaving != leaving ||
        oldWidget.axis != axis;
  }
}

// The destinations of the shell, every one alive at once and kept offstage with
// their tickers stopped, so coming back finds one as it was left. The step
// between two crossfades the identical backgrounds, so the shell never moves.
class ShellDestinations extends StatelessWidget
{
  // Which of [children] is the destination being shown.
  final int currentIndex;

  // The destinations, in the order they are declared. It is also the order they
  // are drawn in, which is why the crossfade is laid on whichever of the two
  // happens to be the upper one rather than always on the same one.
  final List<Widget> children;

  const ShellDestinations({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  Widget build(BuildContext context)
  {
    return _Handover(
      index: currentIndex,
      step: null,
      axis: Axis.horizontal,
      // The shell fills the screen, and so does every destination in it.
      fit: StackFit.expand,
      // The only thing that tells a page it is being read again. Sections do
      // not: coming back to one is not coming back to the app.
      announces: true,
      children: children,
    );
  }
}

// The sections of a page: the same handover as [ShellDestinations] made up the
// page instead of across it. It stands where an IndexedStack was and keeps every
// section mounted. Nested inside the shell it steps aside, or two scopes would
// pull the same elements two ways.
class PageSections extends StatelessWidget
{
  // Which of [children] is the section being shown.
  final int index;

  // Where one section stands for several rail entries: the lessons walk a week
  // through one pair of lists, so Tuesday to Wednesday leaves [index] alone and
  // the section hands over to itself. Null on every other page.
  final Object? step;

  // The sections, in the order the rail counts them.
  final List<Widget> children;

  const PageSections({
    super.key,
    required this.index,
    this.step,
    required this.children,
  });

  @override
  Widget build(BuildContext context)
  {
    return _Handover(
      index: index,
      step: step,
      axis: Axis.vertical,
      // Loose, unlike the shell: the settings are as tall as whichever section
      // is open rather than being given a height, and a section stretched to a
      // height nobody has would have nothing to stretch to.
      fit: StackFit.loose,
      announces: false,
      children: children,
    );
  }
}

// The machinery both of them are: one child on screen, the others mounted and
// offstage, and a staggered step from one to the next along a given axis.
class _Handover extends StatefulWidget
{
  final int index;

  // What the child on screen is about, for the steps that do not change which
  // child that is. See [PageSections.step].
  final Object? step;

  final Axis axis;
  final StackFit fit;

  // Whether the children are told they are being shown again, for the pages
  // that ask again for their data when they are.
  final bool announces;

  final List<Widget> children;

  const _Handover({
    required this.index,
    required this.step,
    required this.axis,
    required this.fit,
    required this.announces,
    required this.children,
  });

  @override
  State<_Handover> createState() => _HandoverState();
}

class _HandoverState extends State<_Handover> with SingleTickerProviderStateMixin
{
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pageTransition,
    value: 1,
  );

  late int _arriving = widget.index;

  // The one still on screen while it empties itself, and null whenever there is
  // no step under way.
  int? _leaving;

  // What the child showed before a step that does not change which child it is.
  // There cannot be a second subtree — the two days are one widget — so it hands
  // over to itself, holding the last description until the turn. Held and not
  // rebuilt, so the day changes at the turn rather than at the click.
  Widget? _held;

  @override
  void initState()
  {
    super.initState();
    _controller.addStatusListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(_Handover oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // No setState anywhere here: this runs from the rebuild that brought the new
    // index in, and the frame it belongs to has not been laid out yet.
    if (widget.index != _arriving)
    {
      _leaving = _arriving;
      _arriving = widget.index;
      _held = null;

      _controller.forward(from: 0);

      return;
    }

    // The same section about something else — see [_held]. Not while a step
    // between two is running, or a day changes inside a section half off the
    // page.
    if (widget.step == oldWidget.step || _leaving != null || _arriving >= oldWidget.children.length)
    {
      return;
    }

    // What is on screen at this moment is what the step has to empty. Partway
    // through one already, that is still the description held from it rather
    // than the one just built, which nothing has drawn yet.
    if (_held == null || _controller.value >= _reentryTurn)
    {
      _held = oldWidget.children[_arriving];
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  // Once the step is over the one left behind goes offstage, which is what
  // stops it being drawn and laid out until it is asked for again.
  void _onStatusChanged(AnimationStatus status)
  {
    if (status == AnimationStatus.completed && (_leaving != null || _held != null))
    {
      setState(()
      {
        _leaving = null;
        _held = null;
      });
    }
  }

  Widget _child(int index, double progress, _PageTransitionScope? outer, {required bool covered})
  {
    final bool arriving = index == _arriving;
    final bool leaving = index == _leaving;
    final bool onScreen = arriving || leaving;

    // A step made in place: this child is both halves of it, one after the
    // other, and until the turn what it is drawn from is the description it
    // had before the step. See [_held].
    final bool inPlace = _held != null && arriving;
    final bool emptying = inPlace && progress < _reentryTurn;

    // Laid on the one drawn last, which is the one hiding the other. Reordering
    // them would take their state along, and is not needed: the backgrounds are
    // the same paper, so fading the upper one either way is the same picture.
    final bool upper = _leaving != null && index == (_arriving > _leaving! ? _arriving : _leaving!);

    final double opacity = !upper
        ? 1
        : (arriving ? _arrivalOpacity(progress) : 1 - _arrivalOpacity(progress));

    // The shape below never changes, whichever state a child is in: swap a
    // widget in or out of it and what is underneath is built again from
    // nothing, which is the very thing this exists to avoid.
    return Offstage(
      offstage: !onScreen,
      child: TickerMode(
        enabled: onScreen,
        // Nothing answers the pointer while the step is under way: the one
        // leaving is still on screen, and a card caught on its way out would
        // open something the page it belongs to is already halfway out of.
        child: IgnorePointer(
          ignoring: !arriving || _leaving != null || inPlace,
          child: _DestinationScope(
            // A section says nothing about the destination it sits in: the
            // answer stays the one the shell gave, which the scope above this
            // one is still holding.
            current: widget.announces
                ? arriving && !covered
                : _DestinationScope.of(context),
            child: _PageTransitionScope(
              progress: outer?.progress ?? (inPlace ? _reentryProgress(progress) : progress),
              leaving: outer?.leaving ?? (inPlace ? emptying : leaving),
              axis: outer?.axis ?? widget.axis,
              child: Opacity(
                opacity: opacity,
                child: emptying ? _held! : widget.children[index],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // The step this one stands inside of: during a change of destination the
    // whole page travels, section included, and passing that on is what keeps
    // the two from pulling the same elements two ways.
    final enclosing = _PageTransitionScope.maybeOf(context);
    final outer = (enclosing != null && enclosing.moving) ? enclosing : null;

    // How far the shell's page is covered by another: a detail page opens over
    // every destination, so without this closing one returned to a list that
    // never knew it was back. Dialogs do not count — only a page drives it.
    final Animation<double>? covering = ModalRoute.of(context)?.secondaryAnimation;

    return AnimatedBuilder(
      animation: covering == null
          ? _controller
          : Listenable.merge([_controller, covering]),
      builder: (context, _)
      {
        final bool covered = (covering?.value ?? 0) > 0;

        return Stack(
          fit: widget.fit,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _child(i, _controller.value, outer, covered: covered),
          ],
        );
      },
    );
  }
}

// For a page told when its destination is opened again: never taken down means
// never reloaded, so it asks the server again quietly without taking down what
// it shows. Not called the first time, nor outside the shell.
mixin DestinationRefresh<T extends StatefulWidget> on State<T>
{
  bool? _wasShown;

  // Ask again, quietly, for whatever this page is showing.
  void onDestinationShown();

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final bool shown = _DestinationScope.of(context);

    if (_wasShown == false && shown)
    {
      onDestinationShown();
    }

    _wasShown = shown;
  }
}

// Whether the destination this sits in is the one being shown. Outside the shell
// — a person's page, the login — there is no destination to speak of and the
// answer is yes, which leaves whatever reads it alone.
class _DestinationScope extends InheritedWidget
{
  final bool current;

  const _DestinationScope({required this.current, required super.child});

  static bool of(BuildContext context)
  {
    return context.dependOnInheritedWidgetOfExactType<_DestinationScope>()?.current ?? true;
  }

  @override
  bool updateShouldNotify(_DestinationScope oldWidget) => oldWidget.current != current;
}

// The step that changes screen: the mark over a white blur, as it has always
// been. Nothing here reads the slots, so a page playing this one moves as a
// block whatever its elements are wrapped in.
class _ScreenTransition extends StatelessWidget
{
  final Animation<double> animation;
  final Widget child;

  const _ScreenTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final overlayAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(animation);

    final pageOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    ]).animate(animation);

    return AnimatedBuilder(
      animation: overlayAnimation,
      builder: (context, _)
      {
        final double blurIntensity = overlayAnimation.value * 20.0;
        final double backgroundOpacity = overlayAnimation.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: pageOpacity,
              child: child,
            ),
            if (overlayAnimation.value > 0)
              AbsorbPointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: blurIntensity > 0.1 ? blurIntensity : 0.1,
                        sigmaY: blurIntensity > 0.1 ? blurIntensity : 0.1,
                      ),
                      child: Container(
                        color: Colors.white.withValues(
                          alpha: backgroundOpacity,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: overlayAnimation.value,
                      child: const CasaMichelaLoader(isOverlay: false),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
