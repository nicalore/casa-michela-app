import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/utils/settings_strings.dart';
import '../../services/seen_tours.dart';
import 'app_gradient_button.dart';
import 'page_transition.dart';
import 'shared_components.dart';
import 'snackbar.dart';
import 'tour_cues.dart';

const String _backLabel = 'INDIETRO';
const String _nextLabel = 'AVANTI';
const String _endLabel = 'FINE';

// As a dialog without blur: the page stays readable.
const double _dimOpacity = 0.32;

const double _bubbleWidth = 410;
// Narrower, "INDIETRO" and "AVANTI" side by side would break their words.
const double _narrowestBubble = 400;
const double _bubbleGap = 20;
const double _windowMargin = 20;

// Same colour as the desktop tooltips (AppTheme.tooltipDecoration).
final Color _bubbleColor = AppTheme.trialOcean.withValues(alpha: 0.97);
final Color _closeHover = Color.alphaBlend(Colors.white.withValues(alpha: 0.14), AppTheme.trialOcean);

// Above or below a part, the bubble needs at least this much height.
const double _shortestRoom = 170;

// Only clickable parts get a rim: read ones are just left undimmed.
const double _rimWidth = 3;

// Past a scroll view's bottom fade.
const double _revealEdge = 48;

const Duration _move = Duration(milliseconds: 380);
const Duration _fade = Duration(milliseconds: 220);

// Same as the hole's move, so page, hole and card come to rest together.
const Duration _reveal = _move;

// A part that moved less than this since the last frame stands still.
const double _stillness = 0.5;

// Parts keep moving a while after a step begins (menus opening, pages scrolling).
const Duration _watch = Duration(milliseconds: 900);

const Duration _startPause = Duration(milliseconds: 150);

const Duration _windowGone = Duration(milliseconds: 300);

// A double click on AVANTI passes one step: the new card's buttons wait this long.
const Duration _doubleClick = Duration(milliseconds: 300);

// Clicks are never held back longer, whatever goes wrong meanwhile.
const Duration _longestHold = Duration(seconds: 10);

const Duration _longestWait = Duration(seconds: 8);
const Duration _waitStep = Duration(milliseconds: 50);

String _eyebrow(int index, int count) => 'TUTORIAL · $index DI $count';

final Map<String, List<_DesktopTourTargetState>> _targets = {};

// A null id marks nothing, so lighting a part or not keeps the tree the same.
class DesktopTourTarget extends StatefulWidget
{
  final String? id;
  final Widget child;

  const DesktopTourTarget({super.key, required this.id, required this.child});

  @override
  State<DesktopTourTarget> createState() => _DesktopTourTargetState();
}

class _DesktopTourTargetState extends State<DesktopTourTarget>
{
  @override
  void initState()
  {
    super.initState();
    _register(widget.id);
  }

  @override
  void didUpdateWidget(DesktopTourTarget oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id != widget.id)
    {
      _unregister(oldWidget.id);
      _register(widget.id);
    }
  }

  @override
  void dispose()
  {
    _unregister(widget.id);
    super.dispose();
  }

  void _register(String? id)
  {
    if (id != null)
    {
      (_targets[id] ??= []).add(this);
    }
  }

  void _unregister(String? id)
  {
    if (id != null)
    {
      _targets[id]?.remove(this);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Sections kept behind are laid out offstage, where they would show.
bool _onShow(BuildContext context)
{
  RenderObject? node = context.findRenderObject();

  while (node != null)
  {
    if (node is RenderOffstage && node.offstage)
    {
      return false;
    }

    node = node.parent;
  }

  return true;
}

bool _visible(BuildContext context) => isDestinationShownNow(context) && _onShow(context);

// Destinations and sections kept behind build parts too: the one on show wins, then the latest.
BuildContext? _contextOf(String id)
{
  final Iterable<_DesktopTourTargetState> built = _targets[id]?.where((state) => state.mounted) ?? const [];

  return (built.where((state) => _visible(state.context)).lastOrNull ?? built.lastOrNull)?.context;
}

Rect? _boxOf(BuildContext context)
{
  final RenderObject? box = context.findRenderObject();

  if (box is! RenderBox || !box.attached || !box.hasSize)
  {
    return null;
  }

  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
}

Rect? _shownOf(BuildContext context)
{
  Rect? rect = _boxOf(context);
  ScrollableState? scrollable = Scrollable.maybeOf(context);

  while (rect != null && scrollable != null)
  {
    final Rect? port = _boxOf(scrollable.context);

    if (port != null && port.overlaps(rect))
    {
      rect = rect.intersect(port);
    }

    scrollable = Scrollable.maybeOf(scrollable.context);
  }

  return rect;
}

Rect? _rectOf(String id)
{
  final BuildContext? context = _contextOf(id);

  return context == null ? null : _shownOf(context);
}

List<Rect> _rectsOf(String id)
{
  final Iterable<_DesktopTourTargetState> built = _targets[id]?.where((state) => state.mounted) ?? const [];
  final List<Rect> shown = [
    for (final _DesktopTourTargetState state in built)
      if (_visible(state.context)) ?_shownOf(state.context),
  ];

  return shown.isNotEmpty ? shown : [?_rectOf(id)];
}

bool isDesktopTourTargetShown(String id) => _contextOf(id) != null;

enum DesktopTourSide { right, left, below, above }

class DesktopTourStep
{
  // Lit together as one part; none: the bubble alone, in the middle.
  final List<String> targets;

  // A hole per target, for parts with others between them; every copy on show gets one.
  final bool apart;

  final String text;

  // Tried in order; the first with room enough wins.
  final List<DesktopTourSide> sides;

  final double pad;
  final double radius;

  // With [apart]: one radius per target, in order.
  final List<double>? radii;

  // No forward button: the lit part takes clicks; done once [reached] holds on a [listen] notify.
  final Listenable? listen;
  final bool Function()? reached;

  // The lit part takes clicks, forward button kept: [reached] then only hurries the step on.
  final bool interactive;

  // The lit part takes clicks, forward button kept; a click inside it moves the tour on, or ends it.
  final bool clickMovesOn;
  final bool clickEnds;

  // Where a click is awaited and steps follow, the forward button clicks this part, else the first target.
  final String? tapping;

  // Checked on [listen] too: true ends the tour, its part gone (a window closed under it).
  final bool Function()? gone;

  final bool doneByLeaving;

  // The part is scrolled into sight as the step begins; [revealing] names a larger one to show.
  final bool reveal;
  final String? revealing;

  // Run as the step begins, and when stepping back from it.
  final VoidCallback? enter;
  final VoidCallback? undo;

  // False skips the step as it comes up; [coming] counts it ahead while it waits for its part.
  final bool Function()? present;
  final bool Function()? coming;

  // Another tour this step stands for: marked with the tour once the step was shown.
  final (String, int)? seen;

  const DesktopTourStep({
    this.targets = const [],
    this.apart = false,
    required this.text,
    this.sides = const [DesktopTourSide.right, DesktopTourSide.left, DesktopTourSide.below, DesktopTourSide.above],
    this.pad = 8,
    this.radius = 20,
    this.radii,
    this.listen,
    this.reached,
    this.interactive = false,
    this.clickMovesOn = false,
    this.clickEnds = false,
    this.tapping,
    this.gone,
    this.doneByLeaving = false,
    this.reveal = false,
    this.revealing,
    this.enter,
    this.undo,
    this.present,
    this.coming,
    this.seen,
  });

  bool get waitsForClick => (reached != null && !interactive) || doneByLeaving;

  bool get takesClicks => waitsForClick || interactive || clickMovesOn || clickEnds;

  bool get isPresent => present?.call() ?? true;

  bool get isAhead => isPresent || (coming?.call() ?? false);
}

// A part listed twice in one tour (this week and next) is told by the first copy that shows it.
// [told] keeps, per seen mark, the copy that told it; [when] is an extra presence check.
DesktopTourStep desktopTourStepOnce(DesktopTourStep step, Map<(String, int), Object> told, {bool Function()? when})
{
  final Object copy = Object();

  return DesktopTourStep(
    targets: step.targets,
    apart: step.apart,
    text: step.text,
    sides: step.sides,
    pad: step.pad,
    radius: step.radius,
    radii: step.radii,
    interactive: step.interactive,
    clickMovesOn: step.clickMovesOn,
    clickEnds: step.clickEnds,
    reveal: step.reveal,
    revealing: step.revealing,
    enter: () => told.putIfAbsent(step.seen!, () => copy),
    present: () => (when?.call() ?? true) && step.isPresent && identical(told[step.seen] ?? copy, copy),
    seen: step.seen,
  );
}

class DesktopTour
{
  final String slug;
  final String title;

  // Bumped on every change, so whoever had seen the tour sees it again.
  final int version;

  final List<DesktopTourStep> steps;

  const DesktopTour({required this.slug, required this.title, required this.version, required this.steps});
}

class _Run
{
  final DesktopTour tour;
  final List<DesktopTourStep> steps;
  final String taxCode;

  final int first;

  final ValueListenable<RouteInformation>? address;
  final String? path;

  final Animation<double>? route;

  _Run(this.tour, this.steps, this.first, this.taxCode, this.address, this.path, this.route);
}

Future<void> settleDesktopPage(BuildContext context) async
{
  final Animation<double>? entrance = ModalRoute.of(context)?.animation;
  final Stopwatch waited = Stopwatch()..start();

  while (waited.elapsed < _longestWait)
  {
    if (!context.mounted)
    {
      return;
    }

    final bool coming = entrance != null && entrance.status == AnimationStatus.forward;

    if (!coming && !isPageTransitionMoving(context) && isDestinationShown(context))
    {
      return;
    }

    await Future<void>.delayed(_waitStep);
  }
}

_Run? _run;
OverlayEntry? _entry;

bool get isDesktopTourShown => _run != null;

// Parts lit by the current step; one may change for it, as a row showing its hover-only bins.
final ValueNotifier<Set<String>> desktopTourLit = ValueNotifier(const {});

// Never mid-build: the parts listening would rebuild during it.
void _setLit(Set<String> ids, bool Function() still)
{
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks)
  {
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      if (still())
      {
        desktopTourLit.value = ids;
      }
    });

    return;
  }

  desktopTourLit.value = ids;
}

// The administrator has none: the shell is the home, and the settings are the same for every role.
const Set<String> kDesktopTourRoles = {'TEACHER', 'PARENT', 'STUDENT', 'PSYCHOLOGIST'};

// Bar sections with tours, by role and slug; a section's tours are slugged after it.
const Map<String, Set<String>> kDesktopTourSections = {
  'TEACHER': {'subjects', 'availability', 'calendar', 'association'},
  'PARENT': {'bookings', 'calendar', 'children', 'association'},
  'STUDENT': {'bookings', 'calendar', 'association'},
  'PSYCHOLOGIST': {'students'},
};

Future<void> resetDesktopToursOf(String taxCode, Iterable<String> sections) =>
    SeenTours.desktop.reset(taxCode, sections);

// Storage out of reach: better no tour than one shown at every visit.
Future<bool> _seen(String taxCode, DesktopTour tour) async
{
  try
  {
    return await SeenTours.desktop.hasSeen(taxCode: taxCode, slug: tour.slug, version: tour.version);
  }
  catch (_)
  {
    return true;
  }
}

Future<bool> isDesktopTourSeen({required String taxCode, required DesktopTour tour}) => _seen(taxCode, tour);

// Unseen steps on show, as one tour under the first one's mark; null when none is due.
Future<DesktopTour?> dueDesktopTour({
  required String taxCode,
  required String title,
  required List<DesktopTourStep> steps,
}) async
{
  final List<DesktopTourStep> due = [];

  for (final DesktopTourStep step in steps)
  {
    final (String slug, int version) = step.seen!;
    final DesktopTour alone = DesktopTour(slug: slug, title: title, version: version, steps: const []);

    if (step.isPresent && !await _seen(taxCode, alone))
    {
      due.add(step);
    }
  }

  if (due.isEmpty)
  {
    return null;
  }

  final (String slug, int version) = due.first.seen!;

  return DesktopTour(slug: slug, title: title, version: version, steps: due);
}

// No route above [context]'s, in its navigator or any ancestor one: windows open on the root.
bool _onTop(BuildContext context)
{
  ModalRoute<Object?>? route = ModalRoute.of(context);

  while (route != null)
  {
    if (!route.isCurrent)
    {
      return false;
    }

    final BuildContext? holder = route.navigator?.context;
    final ModalRoute<Object?>? outer = holder == null || !holder.mounted ? null : ModalRoute.of(holder);

    if (identical(outer, route))
    {
      return true;
    }

    route = outer;
  }

  return true;
}

// Holds clicks while a tour gets ready to show: one would change what it is about to tell.
// Given to [startDesktopTourOnce] for a wait (a reload); let go once the tour shows or is dropped.
class DesktopTourHold
{
  OverlayEntry? _entry;
  Timer? _cap;

  DesktopTourHold();

  factory DesktopTourHold.over(BuildContext context) => DesktopTourHold()..hold(context);

  void hold(BuildContext context)
  {
    if (_entry != null || _run != null || !context.mounted || !isDestinationShown(context) || !_onTop(context))
    {
      return;
    }

    _entry = OverlayEntry(builder: (context) => const AbsorbPointer(child: SizedBox.expand()));
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _cap = Timer(_longestHold, release);
  }

  void release()
  {
    _cap?.cancel();
    _cap = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

// Pointers down now: a tour asked during a drag (hours being moved) shows once the hand lifts.
final Set<int> _pressed = {};
bool _trackingPointers = false;

void _trackPointers()
{
  if (_trackingPointers)
  {
    return;
  }

  _trackingPointers = true;

  GestureBinding.instance.pointerRouter.addGlobalRoute((event)
  {
    if (event is PointerDownEvent)
    {
      _pressed.add(event.pointer);
    }
    else if (event is PointerUpEvent || event is PointerCancelEvent)
    {
      _pressed.remove(event.pointer);
    }
  });
}

final Set<String> _coming = {};

// Clicks are held until it shows ([hold] if given); [still] false right before showing drops it.
Future<void> startDesktopTourOnce(
  BuildContext context, {
  required String taxCode,
  required DesktopTour tour,
  bool Function()? still,
  DesktopTourHold? hold,
}) async
{
  if (_coming.contains(tour.slug))
  {
    hold?.release();

    return;
  }

  _coming.add(tour.slug);
  _trackPointers();

  final DesktopTourHold held = hold ?? DesktopTourHold.over(context);

  try
  {
    // A tour still running is checked once the page has settled: one fading out has gone by then.
    if (await _seen(taxCode, tour) || !context.mounted)
    {
      return;
    }

    await settleDesktopPage(context);
    await Future<void>.delayed(_startPause);

    // With a window over the page, the tour waits for it to go; the window stays usable.
    if (context.mounted && !_onTop(context))
    {
      held.release();

      while (context.mounted && !_onTop(context))
      {
        await Future<void>.delayed(_waitStep);
      }

      if (!context.mounted)
      {
        return;
      }

      held.hold(context);
      await Future<void>.delayed(_windowGone);
    }

    final Stopwatch pressed = Stopwatch()..start();

    while (context.mounted && _pressed.isNotEmpty && pressed.elapsed < _longestWait)
    {
      await Future<void>.delayed(_waitStep);
    }

    if (!context.mounted || _run != null || !isDestinationShown(context) || !_onTop(context) || !(still?.call() ?? true))
    {
      return;
    }

    final GoRouteInformationProvider? address = GoRouter.maybeOf(context)?.routeInformationProvider;

    final int first = tour.steps.indexWhere((step) => step.isPresent);

    if (first < 0)
    {
      return;
    }

    final _Run run = _Run(
      tour,
      tour.steps,
      first,
      taxCode,
      address,
      address?.value.uri.path,
      ModalRoute.of(context)?.animation,
    );

    _run = run;
    _entry = OverlayEntry(builder: (context) => _TourLayer(run: run));
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }
  finally
  {
    held.release();
    _coming.remove(tour.slug);
  }
}

class _TourLayer extends StatefulWidget
{
  final _Run run;

  const _TourLayer({required this.run});

  @override
  State<_TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<_TourLayer> with TickerProviderStateMixin, WidgetsBindingObserver
{
  late final AnimationController _shown = AnimationController(vsync: this, duration: _fade)
    ..addListener(_redraw);
  late final Ticker _ticker = createTicker(_tick);

  int _step = 0;
  final List<int> _path = [];

  // Counts the steps entered: the card's buttons answer only for the one they were drawn for.
  int _visit = 0;

  // The holes as drawn, where they began their move, and where their parts are now.
  List<Rect> _holes = const [];
  List<Rect> _from = const [];
  List<Rect> _aim = const [];

  final _BubbleTrack _track = _BubbleTrack();
  Offset? _bubbleFrom;
  double? _widthFrom;
  double _glide = 1;

  Duration _elapsed = Duration.zero;
  Duration _moveStart = Duration.zero;
  Duration _watchUntil = Duration.zero;

  // Start of the wait for the current step's parts.
  Duration _since = Duration.zero;

  Listenable? _listening;

  // The step entered waits for its parts; the card and the holes still show the last one.
  bool _waiting = false;

  // The step on show, as the visit it was set off in, and its card as built then.
  int _drawn = 0;
  int _drawnVisit = 0;
  Widget? _drawnBubble;

  // Parts measured a frame ago: still ones measure the same twice.
  List<Rect> _lastMeasured = const [];

  // How clickable the holes drawn are, 0 to 1, and from where their move set off.
  double _clickFrom = 0;
  double _clickNow = 0;

  late final TourBreath _breath = TourBreath(this);
  late final AnimationController _nudge = AnimationController(vsync: this, duration: kTourNudgeDuration, value: 1);

  // The visits whose clickable parts breathed, and whose forward button clicked for the user.
  int _breathed = -1;
  int _performed = -1;

  Timer? _cardFresh;

  bool _closing = false;

  DesktopTourStep get _current => widget.run.steps[_step];

  bool get _animates => VisualEffects.on;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    widget.run.address?.addListener(_onAddress);
    widget.run.route?.addStatusListener(_onRoute);
    _breath.listenable.addListener(_redraw);

    _enter(widget.run.first);
    _shown.duration = _animates ? _fade : Duration.zero;
    _shown.forward();
  }

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    widget.run.address?.removeListener(_onAddress);
    widget.run.route?.removeStatusListener(_onRoute);
    _listening?.removeListener(_onListened);
    _breath.listenable.removeListener(_redraw);
    _cardFresh?.cancel();
    _ticker.dispose();
    _shown.dispose();
    _breath.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _watchFor(_watch);

  void _redraw()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  void _onAddress()
  {
    if (widget.run.address?.value.uri.path == widget.run.path)
    {
      return;
    }

    _end(mark: _current.doneByLeaving, fade: false);
  }

  // Not marked: a window closed halfway shows its tour again the next time it opens.
  void _onRoute(AnimationStatus status)
  {
    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed)
    {
      _end(mark: false);
    }
  }

  void _onListened()
  {
    if (_closing)
    {
      return;
    }

    if (_current.gone?.call() ?? false)
    {
      _end(mark: true);

      return;
    }

    if (!(_current.reached?.call() ?? false))
    {
      return;
    }

    // Ended by the user's own click, the tour leaves at once: what the click opened is coming in.
    if (_nextIndex == null)
    {
      _end(mark: true, fade: false);

      return;
    }

    // The clicked part stays lit while what it opened comes in.
    _next();
  }

  // Kept offstage, or still out of sight with its section: not to be lit yet.
  bool _coming(DesktopTourStep step)
  {
    return step.targets.any((id)
    {
      final BuildContext? part = _contextOf(id);

      return part != null && part.mounted && (!_onShow(part) || isPageTransitionPartComing(part));
    });
  }

  // In a section sliding in, a part counts once in sight; elsewhere once still for a frame.
  bool _ready(DesktopTourStep step, List<Rect> measured, List<Rect> before)
  {
    if (_coming(step))
    {
      return false;
    }

    final bool sliding = step.targets.any((id)
    {
      final BuildContext? part = _contextOf(id);

      return part != null && part.mounted && isPageTransitionMoving(part);
    });

    return sliding || _same(measured, before);
  }

  // Steps are judged as they come up: what one does may bring or drop the parts of the next.
  int? get _nextIndex
  {
    final List<DesktopTourStep> steps = widget.run.steps;

    for (var index = _step + 1; index < steps.length; index++)
    {
      if (steps[index].isPresent)
      {
        return index;
      }
    }

    return null;
  }

  int get _count => _path.length + 1 + widget.run.steps.skip(_step + 1).where((step) => step.isAhead).length;

  List<Rect> _measure(DesktopTourStep step)
  {
    final List<Rect> parts = [
      for (final String id in step.targets)
        if (step.apart) ..._rectsOf(id) else ?_rectOf(id),
    ];

    if (parts.isEmpty)
    {
      return const [];
    }

    return [for (final Rect part in step.apart ? parts : [_bounds(parts)!]) part.inflate(step.pad)];
  }

  List<double> _radiiOf(DesktopTourStep step)
  {
    final List<double>? radii = step.radii;

    if (!step.apart || radii == null)
    {
      return const [];
    }

    return [
      for (final (int index, String id) in step.targets.indexed)
        for (final Rect _ in _rectsOf(id)) radii[index] + step.pad / 2,
    ];
  }

  void _enter(int index, {bool back = false})
  {
    _listening?.removeListener(_onListened);
    _step = index;
    _visit++;

    final DesktopTourStep step = _current;
    final int visit = _visit;

    step.enter?.call();
    _setLit({...step.targets}, () => !_closing && visit == _visit);

    _listening = step.listen;
    _listening?.addListener(_onListened);

    // Measured now, a part already standing still sets off on the next frame.
    _lastMeasured = _measure(step);

    if (_drawnBubble == null || step.targets.isEmpty)
    {
      _begin();

      return;
    }

    // The card keeps telling of the last part until this step's are ready to be lit.
    _waiting = true;
    _watchFor(_watch + _move);
    _since = _elapsed;
  }

  // The card and the holes set off for the step entered.
  void _begin()
  {
    final DesktopTourStep step = _current;
    final int visit = _visit;

    _waiting = false;
    _drawn = _step;
    _drawnVisit = visit;
    _from = _holes;
    _clickFrom = _clickNow;
    _cardFresh?.cancel();
    _cardFresh = Timer(_doubleClick, () {});
    _bubbleFrom = _track.position;
    _widthFrom = _track.width;
    _glide = _bubbleFrom == null || !_animates ? 1 : 0;
    _watchFor(_watch + _move);
    _moveStart = _elapsed;
    _since = _elapsed;

    if (step.reveal && step.targets.isNotEmpty)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealPart(step.revealing ?? step.targets.first, visit));
    }
  }

  void _watchFor(Duration span)
  {
    final Duration until = _elapsed + span;

    if (until > _watchUntil)
    {
      _watchUntil = until;
    }

    if (!_ticker.isActive)
    {
      // The ticker rests only once a move has ended: it stays ended.
      _elapsed = Duration.zero;
      _moveStart = -_move;
      _since = Duration.zero;
      _watchUntil = span;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed)
  {
    _elapsed = elapsed;

    final DesktopTourStep step = _current;
    final List<Rect> measured = _measure(step);
    final List<Rect> before = _lastMeasured;
    final bool late = elapsed - _since >= _longestWait;

    _lastMeasured = measured;

    if (step.targets.isEmpty)
    {
      final Offset middle = (_bounds(_holes) ?? Offset.zero & MediaQuery.sizeOf(context)).center;

      _aim = [Rect.fromCenter(center: middle, width: 0, height: 0)];
    }
    // Parts still coming in, or moving into place, are waited for: the hole never chases them.
    else if (measured.isNotEmpty && (late || (_waiting ? _ready(step, measured, before) : !_coming(step))))
    {
      if (_waiting)
      {
        _begin();
      }

      _aim = measured;
    }
    // Its part not drawn yet, its data on the way: measured again for a while.
    else if (!late)
    {
      _waiting = true;
      _watchFor(_watch);
    }
    // It never came: the card tells of it all the same.
    else if (_drawnVisit != _visit)
    {
      _begin();
    }

    final double moved = _animates
        ? ((elapsed - _moveStart).inMicroseconds / _move.inMicroseconds).clamp(0.0, 1.0)
        : 1.0;
    final double t = Curves.easeInOutCubic.transform(moved);

    _glide = _bubbleFrom != null ? moved : 1.0;

    Rect start(int index) => _from.length == _aim.length ? _from[index] : _bounds(_from)!;

    _holes = _from.isEmpty ? _aim : [for (var i = 0; i < _aim.length; i++) Rect.lerp(start(i), _aim[i], t)!];

    final bool clickable = widget.run.steps[_drawn].takesClicks;

    _clickNow = _from.isEmpty ? (clickable ? 1 : 0) : _clickFrom + ((clickable ? 1 : 0) - _clickFrom) * t;

    if (t >= 1 && clickable && _breathed != _drawnVisit)
    {
      _breathe();
    }

    if (t >= 1 && _glide >= 1 && elapsed >= _watchUntil)
    {
      _ticker.stop();
    }

    setState(() {});
  }

  Future<void> _revealPart(String id, int visit) async
  {
    final Stopwatch waited = Stopwatch()..start();

    // Measured at rest: a part still sliding in is not yet where it stays.
    while (waited.elapsed < _longestWait)
    {
      final BuildContext? part = _contextOf(id);

      if (part == null || !part.mounted || !isPageTransitionPartMoving(part))
      {
        break;
      }

      await Future<void>.delayed(_waitStep);
    }

    final BuildContext? target = _contextOf(id);

    if (!mounted || _closing || visit != _visit || target == null || !target.mounted)
    {
      return;
    }

    final ScrollableState? scrollable = Scrollable.maybeOf(target);
    final Rect? part = _boxOf(target);
    final RenderObject? view = scrollable?.context.findRenderObject();

    if (scrollable == null || part == null || view is! RenderBox || !view.hasSize)
    {
      return;
    }

    final Rect port = MatrixUtils.transformRect(view.getTransformTo(null), Offset.zero & view.size);

    double delta = 0;

    if (part.bottom > port.bottom - _revealEdge)
    {
      delta = part.bottom - (port.bottom - _revealEdge);
    }

    // A part taller than the view keeps its top in sight.
    if (part.top - delta < port.top + _bubbleGap)
    {
      delta = part.top - (port.top + _bubbleGap);
    }

    final ScrollPosition position = scrollable.position;
    final double to = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((to - position.pixels).abs() < 1)
    {
      return;
    }

    _watchFor(_reveal + _watch);

    if (_animates)
    {
      await position.animateTo(to, duration: _reveal, curve: Curves.easeInOutCubic);
    }
    else
    {
      position.jumpTo(to);
    }
  }

  void _nextFrom(int visit)
  {
    if (_closing || visit != _visit || (_cardFresh?.isActive ?? false))
    {
      return;
    }

    if (!_performs)
    {
      _next();

      return;
    }

    final DesktopTourStep step = _current;
    final String? id = step.tapping ?? step.targets.firstOrNull;
    final BuildContext? part = id == null ? null : _contextOf(id);

    if (_performed != visit && !(step.reached?.call() ?? false) && part != null && part.mounted && tapTourPart(part))
    {
      _performed = visit;
    }
  }

  // A click awaited with steps after it: the forward button clicks, the step moves on as after the user's.
  bool get _performs => _current.waitsForClick && widget.run.steps.skip(_step + 1).any((step) => step.isAhead);

  // [again] after a click that missed.
  void _breathe({bool again = false})
  {
    if (!again && _breathed == _drawnVisit)
    {
      return;
    }

    _breathed = _drawnVisit;

    if (_animates)
    {
      _breath.start();
    }
  }

  void _onMiss()
  {
    if (_closing || _waiting)
    {
      return;
    }

    if (_animates)
    {
      _nudge.forward(from: 0);
    }

    if (widget.run.steps[_drawn].takesClicks)
    {
      _breathe(again: true);
    }
  }

  void _onHit()
  {
    final DesktopTourStep step = _current;
    final int visit = _visit;

    if (_closing || _waiting)
    {
      return;
    }

    // At once: what the click closes would otherwise end the tour unmarked first.
    if (step.clickEnds)
    {
      _end(mark: true, fade: false);

      return;
    }

    if (step.clickMovesOn)
    {
      // After what the click set off has started.
      SchedulerBinding.instance.addPostFrameCallback((_)
      {
        if (mounted && !_closing && visit == _visit)
        {
          _next();
        }
      });
    }
  }

  void _backFrom(int visit)
  {
    if (!_closing && visit == _visit)
    {
      _back();
    }
  }

  void _next()
  {
    final int? next = _nextIndex;

    if (next == null)
    {
      _end(mark: true);

      return;
    }

    _path.add(_step);
    setState(() => _enter(next));
  }

  void _back()
  {
    if (_path.isEmpty)
    {
      return;
    }

    // Undone once the step is left: a window it closes must not count as closed under it.
    final DesktopTourStep left = _current;

    setState(() => _enter(_path.removeLast(), back: true));
    left.undo?.call();
  }

  void _close()
  {
    if (_closing)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: kTutorialClosedEarly);
    _end(mark: true, all: true);
  }

  Future<void> _end({required bool mark, bool fade = true, bool all = false}) async
  {
    if (_closing)
    {
      return;
    }

    _closing = true;
    _listening?.removeListener(_onListened);
    _listening = null;

    if (mark)
    {
      // Closed by its close button, every step counts as told; otherwise only those shown.
      final Iterable<DesktopTourStep> told = all ? widget.run.steps : [..._path, _step].map((i) => widget.run.steps[i]);

      unawaited(SeenTours.desktop.markSeen(widget.run.taxCode, {
        widget.run.tour.slug: widget.run.tour.version,
        for (final step in told)
          if (step.seen case (final String slug, final int version)) slug: version,
      }));
    }

    if (fade && _animates)
    {
      await _shown.reverse();
    }

    _run = null;
    _setLit(const {}, () => _run == null);
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  @override
  Widget build(BuildContext context)
  {
    final Size window = MediaQuery.sizeOf(context);

    // Narrow windows lose the menus the tour speaks of: it waits for a wider one.
    if (AppBreakpoints.isNarrowWidth(window.width))
    {
      return const SizedBox.shrink();
    }

    // Until the step entered sets off, the last one stays drawn, its buttons inert.
    final DesktopTourStep step = widget.run.steps[_drawn];
    final List<Rect> holes = _holes.where((hole) => !hole.isEmpty).toList();
    final List<double> stepRadii = _radiiOf(step);
    final List<double> radii = stepRadii.length == holes.length ? stepRadii : const [];
    final Rect? place = step.targets.isEmpty ? null : _bounds(_aim);

    if (_drawnVisit == _visit || _drawnBubble == null)
    {
      final int visit = _visit;

      _drawnBubble = _Bubble(
        step: _step,
        animates: _animates,
        eyebrow: _eyebrow(_path.length + 1, _count),
        title: widget.run.tour.title,
        text: _current.text,
        onClose: _close,
        onBack: _path.isEmpty ? null : () => _backFrom(visit),
        onNext: () => _nextFrom(visit),
        nudge: _nudge,
        last: _nextIndex == null && !_performs,
      );
    }

    final Widget bubble = _drawnBubble!;

    return FadeTransition(
      opacity: _shown,
      child: Stack(
        children: [
          Positioned.fill(
            child: _Blocker(
              hole: step.takesClicks ? _bounds(_aim) : null,
              onHit: _onHit,
              onMiss: _onMiss,
              child: CustomPaint(
                painter: _DimPainter(
                  holes: holes,
                  radius: step.radius + step.pad / 2,
                  radii: radii,
                  clickable: _clickNow,
                  glow: _breath.glow,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _BubblePlace(
                hole: place,
                sides: step.sides,
                from: _bubbleFrom,
                widthFrom: _widthFrom,
                t: Curves.easeInOutCubic.transform(_glide),
                track: _track,
              ),
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

Rect? _bounds(List<Rect> rects) => rects.isEmpty ? null : rects.reduce((a, b) => a.expandToInclude(b));

bool _same(List<Rect> now, List<Rect> before)
{
  if (now.length != before.length)
  {
    return false;
  }

  for (final (int index, Rect rect) in now.indexed)
  {
    final Rect other = before[index];

    if ((rect.left - other.left).abs() > _stillness ||
        (rect.top - other.top).abs() > _stillness ||
        (rect.right - other.right).abs() > _stillness ||
        (rect.bottom - other.bottom).abs() > _stillness)
    {
      return false;
    }
  }

  return true;
}

class _DimPainter extends CustomPainter
{
  final List<Rect> holes;
  final double radius;

  final List<double> radii;

  // Clickable parts, and only they, get a rim and its glow.
  final double clickable;
  final double glow;

  const _DimPainter({
    required this.holes,
    required this.radius,
    this.radii = const [],
    required this.clickable,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    // Holes meeting while they move are cut as one, never dimmed where they overlap.
    final Path cut = Path();
    final List<RRect> shapes = [];

    for (final (int index, Rect hole) in holes.indexed)
    {
      final double corner = radii.isEmpty ? radius : radii[index];
      final RRect shape = RRect.fromRectAndRadius(hole, Radius.circular(math.min(corner, hole.shortestSide / 2)));

      shapes.add(shape);
      cut.addRRect(shape);
    }

    // The web keeps the result's contours but not its fill: even-odd gives the same area anywhere.
    final Path dim = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), cut)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: _dimOpacity));

    if (clickable <= 0)
    {
      return;
    }

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rimWidth
      ..color = AppTheme.trialGold.withValues(alpha: clickable);

    for (final RRect shape in shapes)
    {
      paintTourHalo(canvas, shape.inflate(_rimWidth), clickable * glow);
      canvas.drawRRect(shape.inflate(_rimWidth / 2), rim);
    }
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate)
  {
    return !listEquals(oldDelegate.holes, holes) ||
        oldDelegate.radius != radius ||
        !listEquals(oldDelegate.radii, radii) ||
        oldDelegate.clickable != clickable ||
        oldDelegate.glow != glow;
  }
}

class _Blocker extends SingleChildRenderObjectWidget
{
  final Rect? hole;

  // A click inside the hole, after what is underneath had it, and one anywhere else.
  final VoidCallback onHit;
  final VoidCallback onMiss;

  const _Blocker({required this.hole, required this.onHit, required this.onMiss, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlocker(hole)
    ..onHit = onHit
    ..onMiss = onMiss;

  @override
  void updateRenderObject(BuildContext context, _RenderBlocker renderObject)
  {
    renderObject
      ..hole = hole
      ..onHit = onHit
      ..onMiss = onMiss;
  }
}

class _RenderBlocker extends RenderProxyBox
{
  Rect? hole;
  VoidCallback? onHit;
  VoidCallback? onMiss;

  // Where each pointer went down, and whether inside the hole.
  final Map<int, (Offset, bool)> _downs = {};

  _RenderBlocker(this.hole);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position})
  {
    if (!size.contains(position))
    {
      return false;
    }

    result.add(BoxHitTestEntry(this, position));

    // Inside the hole what is underneath is hit too.
    return !(hole?.contains(localToGlobal(position)) ?? false);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry)
  {
    if (event is PointerDownEvent)
    {
      _downs[event.pointer] = (event.position, hole?.contains(event.position) ?? false);
    }
    else if (event is PointerUpEvent)
    {
      if (_downs.remove(event.pointer) case (final Offset down, final bool inside)
          when (event.position - down).distance < kTouchSlop)
      {
        (inside ? onHit : onMiss)?.call();
      }
    }
    else if (event is PointerCancelEvent)
    {
      _downs.remove(event.pointer);
    }
  }
}

// Where the bubble was last laid out: the next step's glide starts there.
class _BubbleTrack
{
  Offset? position;
  double? width;
}

class _BubblePlace extends SingleChildLayoutDelegate
{
  final Rect? hole;
  final List<DesktopTourSide> sides;

  final Offset? from;
  final double? widthFrom;
  final double t;

  final _BubbleTrack track;

  const _BubblePlace({
    required this.hole,
    required this.sides,
    required this.from,
    required this.widthFrom,
    required this.t,
    required this.track,
  });

  // [card]: the card's size once laid out; a side must then hold it whole, or the next is tried.
  (DesktopTourSide?, double) _choose(Size size, {Size? card})
  {
    final Rect? hole = this.hole;

    if (hole == null)
    {
      return (null, _bubbleWidth);
    }

    for (final DesktopTourSide side in sides)
    {
      final double room = switch (side)
      {
        DesktopTourSide.right => size.width - _windowMargin - hole.right - _bubbleGap,
        DesktopTourSide.left => hole.left - _bubbleGap - _windowMargin,
        DesktopTourSide.below => size.height - _windowMargin - hole.bottom - _bubbleGap,
        DesktopTourSide.above => hole.top - _bubbleGap - _windowMargin,
      };

      final bool across = side == DesktopTourSide.right || side == DesktopTourSide.left;

      if (across && room >= math.max(_narrowestBubble, card?.width ?? 0))
      {
        return (side, math.min(_bubbleWidth, room));
      }

      if (!across && room >= math.max(_shortestRoom, card?.height ?? 0))
      {
        return (side, math.min(_bubbleWidth, size.width - 2 * _windowMargin));
      }
    }

    return (null, _bubbleWidth);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints)
  {
    final double aimed = _choose(constraints.biggest).$2;
    final double width = widthFrom == null ? aimed : widthFrom! + (aimed - widthFrom!) * t;

    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0, constraints.maxHeight - 2 * _windowMargin),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize)
  {
    final Offset aimed = _aimed(size, childSize);
    final Offset at = from == null ? aimed : Offset.lerp(from, aimed, t)!;

    track
      ..position = at
      ..width = childSize.width;

    return at;
  }

  Offset _aimed(Size size, Size childSize)
  {
    final Rect? hole = this.hole;
    final DesktopTourSide? side = _choose(size, card: childSize).$1;

    double across(double x) => x.clamp(_windowMargin, math.max(_windowMargin, size.width - _windowMargin - childSize.width));
    double down(double y) => y.clamp(_windowMargin, math.max(_windowMargin, size.height - _windowMargin - childSize.height));

    if (hole == null || side == null)
    {
      return Offset((size.width - childSize.width) / 2, (size.height - childSize.height) / 2);
    }

    return switch (side)
    {
      DesktopTourSide.right => Offset(hole.right + _bubbleGap, down(hole.top)),
      DesktopTourSide.left => Offset(hole.left - _bubbleGap - childSize.width, down(hole.top)),
      DesktopTourSide.below => Offset(across(hole.center.dx - childSize.width / 2), hole.bottom + _bubbleGap),
      DesktopTourSide.above => Offset(across(hole.center.dx - childSize.width / 2), hole.top - _bubbleGap - childSize.height),
    };
  }

  @override
  bool shouldRelayout(_BubblePlace oldDelegate) =>
      oldDelegate.hole != hole ||
      oldDelegate.sides != sides ||
      oldDelegate.from != from ||
      oldDelegate.widthFrom != widthFrom ||
      oldDelegate.t != t;
}

class _Bubble extends StatelessWidget
{
  final int step;
  final bool animates;

  final String eyebrow;
  final String title;
  final String text;

  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final Animation<double> nudge;
  final bool last;

  const _Bubble({
    required this.step,
    required this.animates,
    required this.eyebrow,
    required this.title,
    required this.text,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.nudge,
    required this.last,
  });

  Widget _button(String label, IconData icon, VoidCallback onPressed, {required bool forward})
  {
    return AppGradientButton(
      label: label,
      icon: icon,
      gradient: forward ? AppTheme.brandGradient : AppTheme.dismissGradient,
      accent: forward ? AppTheme.trialTealDeep : AppTheme.trialViolet,
      height: 46,
      fontSize: 14,
      onPressed: onPressed,
    );
  }

  Widget _footer()
  {
    final VoidCallback? back = onBack;
    final VoidCallback? next = onNext;

    final Widget? backButton = back == null ? null : _button(_backLabel, Icons.arrow_back_rounded, back, forward: false);
    final Widget? nextButton = next == null
        ? null
        : ScaleTransition(
            scale: kTourNudge.animate(nudge),
            child: _button(
              last ? _endLabel : _nextLabel,
              last ? Icons.check_rounded : Icons.arrow_forward_rounded,
              next,
              forward: true,
            ),
          );

    if (backButton == null || nextButton == null)
    {
      return Center(child: FractionallySizedBox(widthFactor: 0.5, child: backButton ?? nextButton));
    }

    return Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 12),
        Expanded(child: nextButton),
      ],
    );
  }

  Widget _head()
  {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Chiudi',
          child: FadeHoverIconButton(
            icon: Icons.close_rounded,
            color: Colors.white,
            hoverColor: _closeHover,
            onTap: onClose,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bubbleColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 10), blurRadius: 28)],
        ),
        // While the card grows, the content still to come is cut by its rounded edge.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AnimatedSize(
            duration: animates ? _move : Duration.zero,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: animates ? _fade : Duration.zero,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // The text going out takes no click: its buttons lie uncovered under a shorter one.
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [
                  for (final Widget child in previous) IgnorePointer(key: child.key, child: child),
                  if (current != null) IgnorePointer(key: current.key, ignoring: false, child: current),
                ],
              ),
              child: Padding(
                key: ValueKey<int>(step),
                padding: const EdgeInsets.fromLTRB(26, 18, 14, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _head(),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                    if (onBack != null || onNext != null) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _footer(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
