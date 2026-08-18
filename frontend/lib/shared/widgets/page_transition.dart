import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'casa_michela_loader.dart';

// How one page of the app gives way to the next.
//
// Two different things are called "changing page" here, and they do not deserve
// the same animation.
//
// Walking between the destinations of the top bar changes what is inside a shell
// that does not move: the paper, the two glows, the watermark and the bar itself
// are the same on either side of the step. Those destinations are not pages at
// all in the router's sense — they are branches of one page, all of them alive
// at once, and [ShellDestinations] is what holds them and animates the handover.
// The content on screen takes a short run-up to the right and then leaves to the
// left, one element after the next, and the content arriving slides in from the
// right in the same order.
//
// Everything else — the login, the logout, a person's page — really is a change
// of page, and every route of the app is wrapped in a page that keeps the mark
// and the blur it has always had.

// One duration for the two of them, so a step reads the same whatever kind it
// is, and the timeline below is that duration divided between the half that
// empties and the half that fills in.
const Duration _pageTransition = Duration(milliseconds: 1200);

// The timeline of a shell step, in fractions of the whole.
//
// The page leaving empties itself first, the page arriving fills in after, and
// in the middle the two backgrounds — identical paper, identical bar — are
// crossfaded into each other, which is what makes the shell look like it never
// moved.
const double _slotDelay = 0.038;
const int _lastDelayedSlot = 6;

const double _exitSpan = 0.22;
const double _enterStart = 0.40;
const double _enterSpan = 0.32;

// Where each half of the timeline is done: the last slot to be delayed, plus
// the span that slot is given.
const double _exitEnd = _lastDelayedSlot * _slotDelay + _exitSpan;
const double _enterEnd = _enterStart + _lastDelayedSlot * _slotDelay + _enterSpan;

// The turn of a step made in place — see [_HandoverState._held]. On a proper
// handover the two halves overlap, one page emptying while the other fills in;
// with a single child they cannot, since it has to be empty before what it is
// showing can be swapped. So the two are laid end to end on the one controller,
// each stretched over its half of it.
const double _reentryTurn = 0.5;

double _reentryProgress(double value)
{
  return value < _reentryTurn
      ? value / _reentryTurn * _exitEnd
      : _enterStart + (value - _reentryTurn) / (1 - _reentryTurn) * (_enterEnd - _enterStart);
}

// Where the page arriving stops holding itself back. Until then it is drawn at
// nothing at all, so what is on screen is the page underneath still leaving; by
// the end of it the handover is done. It begins before the last element has
// finished leaving on purpose: a moment with nothing on the paper at all reads
// as a page that failed to load rather than as a page changing.
const double _arrivalFadeStart = 0.36;
const double _arrivalFadeEnd = 0.46;

// The run-up, in logical pixels: a step the wrong way before the dash, and the
// share of the element's own time it is given. It is the pause at the end of it
// — both curves rest there — that makes the leaving read as a decision rather
// than as a slide.
const double _runUp = 22;
const double _runUpShare = 0.32;

// Where an element coming in overshoots to before settling back, and the share
// of its time left for that settling.
const double _overshoot = 7;
const double _overshootShare = 0.84;

// How far an element travels, measured on the window rather than fixed: a step
// that reads as leaving the page on a phone is a twitch on a desktop. Out is the
// longer of the two, because it has to look like the element is gone rather than
// merely moved.
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

// One element of a page, in the order the page is read.
//
// Wrapping something in this is what makes it leave and arrive on its own
// account instead of with the page as a block. What is left unwrapped stays
// where it is and is simply handed over in the crossfade, which is what the
// shell — the bar, the glows, the paper — wants.
//
// The slot is the rank of the element among its neighbours, not a strict index:
// two things given the same slot move together, and past [_lastDelayedSlot]
// they all move at once, so a list of eighty cards does not take a minute to
// walk off the page.
//
// Slots are counted within the page, not within the widget that declares them,
// and an element must not sit inside another element: the two transforms would
// compound, and the delay of the outer one would rob the inner ones of theirs.
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

      // The same journey on whichever axis the step is being made: a step
      // between destinations runs along the row of the bar that made it, a step
      // between sections up the column of the rail. What changes is which
      // measurement of the window says how far "off the page" is.
      final bool sideways = scope.axis == Axis.horizontal;
      final double extent = sideways ? window.width : window.height;

      final double elapsed = _slotProgress(scope.progress, slot, leaving: scope.leaving);

      final double travelled = scope.leaving
          ? _exitOffset(elapsed, _exitTravel(extent))
          : _enterOffset(elapsed, _enterTravel(extent));

      offset = sideways ? Offset(travelled, 0) : Offset(0, travelled);
      opacity = scope.leaving ? _exitOpacity(elapsed) : _enterOpacity(elapsed);
    }

    // The same two widgets whatever is happening, standing still when nothing
    // is: handing the element back bare while it is at rest would look like an
    // economy, and is in fact how you throw it away. Flutter pairs a widget with
    // its element by position, so a shape that changes between one build and the
    // next takes everything below it down and builds it again from nothing —
    // twice per step, once on the way out of rest and once on the way back into
    // it. What was underneath, in this app, was whole pages: their data went
    // with them, and they went and asked the server for it all over again.
    //
    // At rest neither of the two costs anything worth counting: an identity
    // translation is a matrix nobody looks at, and Opacity at 1 does not so much
    // as open a layer.
    return Transform.translate(
      offset: offset,
      child: Opacity(opacity: opacity, child: child),
    );
  }
}

// Every block of a column on its own beat, in the order they are read.
//
// What a page of forms or of charts is made of: cards one under the next. Left
// whole, such a page leaves and arrives as one slab — the one thing the step
// was written not to look like — and beside a page of cards, which does run
// block by block, the difference reads as two different apps.
//
// Handed the children a Column would have been given, and handing them back
// wrapped, so a page keeps the spacing it already had: the gaps in these pages
// are not all the same size, and a helper that imposed one size would be
// rewriting the page rather than timing it. The air is passed through
// untouched — a box with nothing in it is exactly that — and only what can be
// seen is given a beat.
//
// The beats are counted here rather than written out at the call, because by
// hand is how two blocks end up sharing one, and how a page whose blocks come
// and go with the data ends up numbering them differently from one build to
// the next.
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

// A vertical scroll view that opens its sides while a page is changing.
//
// A viewport clips what it scrolls, and rightly so: the rows above and below
// the one being read have to stay out of sight. But it clips all four sides,
// and an element walking off the page was being cut at the edge of whatever
// column it happened to sit in rather than at the edge of the window — it
// vanished halfway across the page and came back out of thin air.
//
// So the viewport is told to clip nothing and the two edges that actually hold
// the scrolling are put back by hand. The sides are opened only while a step is
// under way, and by exactly the width of the window, which is more than the
// longest journey any element makes; at rest the shape below is the very rect
// the viewport would have clipped to, so nothing is out of place while a page
// is merely being read.
//
// Only for a step made sideways. A step between sections travels up the page,
// and there the clip is doing its proper job: the top edge of the viewport is
// where the list begins, under the field and the filters that shorten it, and
// a card let out through it would fly over them on its way off the page.
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

  // Accelerating away, from the standstill the run-up ends on. Gently, because
  // the element also has to be seen going: under a sharper acceleration it is
  // still nearly where it was by the time it has faded, and what the eye gets is
  // a page fading rather than a page leaving.
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

// Fading only once it is properly under way, and gone a little before it has
// finished travelling: what says "left the page" is the speed it goes at, not
// the distance it covers, and starting the fade at the run-up would empty the
// page before anything had visibly moved.
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

// The destinations of the shell, every one of them alive at once.
//
// One is on screen and the others are kept in the tree, offstage and with their
// tickers stopped, so that coming back to a destination finds it exactly as it
// was left: its data already loaded, its section chosen, its filters set, its
// list where it was scrolled to. Building them afresh on every step is what
// made a change of destination blink and start over from a spinner.
//
// The step between two of them is the staggered one: the destination on screen
// empties itself to the left, the one arriving fills in from the right, and in
// between the two identical backgrounds are crossfaded so that the shell around
// them — the bar, the glows, the paper — never appears to move.
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

// The sections of a page, every one of them alive at once.
//
// The same handover as [ShellDestinations], made up the page instead of across
// it: the section on screen takes a short run-up downwards and then leaves
// upwards, one element after the next, and the section arriving comes up from
// below in the same order. A step taken in the rail and a step taken in the bar
// are the same gesture on the two axes those two controls are drawn along.
//
// It stands where a page had an IndexedStack, and keeps what that gave: every
// section stays mounted, so coming back to one finds it as it was left, with
// its data loaded, its filters set and its list where it was scrolled to.
//
// Nested inside the shell, it steps aside. While a destination is being handed
// over the whole page travels with it — the section on screen included — and
// two scopes pulling the same elements in two directions would tear the page in
// half. So the outer step, while there is one, is the one the elements are
// told about.
class PageSections extends StatelessWidget
{
  // Which of [children] is the section being shown.
  final int index;

  // What the section on screen is about, where one section stands for several
  // entries of the rail. The lessons walk a week a day at a time through one
  // pair of lists rather than one pair per day, so stepping from Tuesday to
  // Wednesday leaves [index] where it was and there is no second section to
  // hand over to. Told the day as well, the section hands over to itself.
  //
  // Null for a rail that counts its entries and its sections the same way,
  // which is every other page: there, a step that changes nothing is a step
  // that changed nothing.
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

  // What the child on screen was showing before a step that does not change
  // which child it is — walking from one day of the lessons to the next.
  //
  // There is no second subtree to hand over to and there cannot be one: the two
  // days are one widget, and inflating its description twice would be two
  // copies of a section fighting over the same keys and the same scroll. So the
  // child hands over to itself, and this is what it empties: the description it
  // was built from last, held until the turn of the step so that what walks off
  // the page is the day being left rather than the one arriving.
  //
  // Held and not rebuilt: it is the same widget object the child is already
  // paired with, so drawing it again asks nothing of the tree at all, and the
  // day is changed once — at the turn — rather than at the click.
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

    // The same section, about something else. See [_held]. Not while a step
    // between two sections is still running: that one is already showing both
    // sides of a handover, and a third would be a day changing inside a section
    // halfway off the page.
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

    // Which of the two the crossfade is laid on: the one drawn last, because it
    // is the one hiding the other. Reordering them so that the arriving one were
    // always on top would take their state along with them, and it is not needed
    // — the two backgrounds are the same paper, so fading the upper one in and
    // fading the upper one out come to the same picture.
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
    // The step this one is standing inside of, while there is one. A page in
    // the shell already sits in a scope, and during a change of destination the
    // whole page travels — the section on screen with it. Passing that answer on
    // is what keeps the two from pulling the same elements two ways at once.
    final enclosing = _PageTransitionScope.maybeOf(context);
    final outer = (enclosing != null && enclosing.moving) ? enclosing : null;

    // How far the page holding the shell is covered by another one.
    //
    // A person detail page does not change destination: it opens over all of
    // them and leaves them where they were. Without this, closing one after
    // editing something returned to a list that never knew it was back, because
    // it had never left.
    //
    // Dialogs do not count, and Flutter is what knows it: a route drives this
    // animation only if it is a page too, and a dialog is not.
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

// For a page that wants to be told when its destination is opened again.
//
// A destination that is never taken down is also never reloaded, and what it
// loaded the first time it was opened would go on being all it knows. This is
// how it asks to be told it is back, so that it can go and ask the server again
// quietly, without taking down what it is already showing.
//
// [onDestinationShown] is not called the first time: the page has only just
// built itself and has asked already. Nor is it called at all outside the shell
// — on a person's page, on the login — where there is no destination to come
// back to.
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
