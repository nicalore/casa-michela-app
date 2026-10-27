import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../../services/seen_tours.dart';
import '../../../shared/widgets/tour_cues.dart';
import '../../layout/mobile_breakpoints.dart';
import '../mobile_line_breaks.dart';
import 'mobile_baseline_hang.dart';
import 'mobile_button_label.dart';
import 'mobile_entrance_motion.dart';
import 'mobile_handover.dart';
import 'mobile_load_switcher.dart';
import 'mobile_nav_sheet.dart';
import 'mobile_notice.dart';

const String kMobileTourGlyph = '\u{FFFC}';
const String _nextLabel = 'Avanti';
const String _endLabel = 'Fine';

const String kMobileTourNavSheet = 'nav.sheet';
const String kMobileTourNavHead = 'nav.head';
const String kMobileTourNavSections = 'nav.sections';

const String kMobileTourSheetClose = 'sheet.close';

const double _sideMargin = 16;
const double _surfaceGap = 12;
const double _bannerRadius = 18;
const double _rimWidth = 3;
const double _buttonSize = 30;
const double _nextHeight = 34;

// Centres the title's capitals on the close button beside it.
const double _titleTop = 8;

const double _textSize = 14;

// Under the line's 1.4 height once centred on the capitals, so the line keeps its height.
const double _glyphEm = 1.3;

const double _bannerGuess = 96;

const double _shortestHole = 24;

// A read hole running this far under the banner still counts as clear of it.
const double _cutTolerance = 8;

const double _dimAlpha = 0.62;

const Duration _fadeDuration = Duration(milliseconds: 260);

const Duration _pageTurn = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _pageSettled = 0.001;
const Duration _moveDuration = Duration(milliseconds: 380);
const Duration _revealDuration = Duration(milliseconds: 420);

// Long enough to follow a page turn, the menu's spring and a scroll into view.
const Duration _followWindow = Duration(milliseconds: 900);

const Duration _scrollPause = Duration(milliseconds: 1200);
const double _scrollMsPerPixel = 4;
const Duration _scrollShortest = Duration(milliseconds: 700);
const Duration _scrollLongest = Duration(milliseconds: 2400);
const Duration _scrollBack = Duration(milliseconds: 420);

const int _stillFrames = 3;
const Duration _settleLongest = Duration(milliseconds: 900);

// Sizes measured on a moving page wobble in their last digits; less than this is no resize.
const double _sizeTolerance = 0.5;

const int _startLongest = 60;

// Holes less than this far into their move restart toward where a reveal scroll lands.
const double _justSetOff = 0.2;

class MobileTourStep
{
  final String text;

  // Lit to be read: they take no touch and stop above the banner.
  final List<String> shown;

  final List<String> touched;

  // Without them the step moves on with the forward button.
  final Listenable? watch;
  final bool Function()? reached;

  final String? reveal;

  // Puts the screen back as it was before this step's touch, when stepping back to it.
  final VoidCallback? undo;

  // Where a touch is awaited and steps follow, the forward button touches this part, else the first touched.
  final String? tapping;

  final VoidCallback? enter;

  // Drawn where the text holds kMobileTourGlyph, as tall as given.
  final Widget Function(double size)? glyph;

  final List<Widget Function(double size)> glyphs;

  final bool tapMovesOn;

  final bool tapEnds;

  // Scrolls parts read out from under the banner; off for a list longer than any screen.
  final bool scrolls;

  final bool high;

  final bool lightsAll;

  final bool joined;

  // Moves on once [watch] fires and this holds, never at step start; the forward button stays.
  final bool Function()? acted;

  final bool Function()? present;

  // Counted ahead while not present yet, as what an earlier step's touch may bring.
  final bool Function()? coming;

  // Marked seen with the tour, once the step has been shown.
  final (String, int)? seen;

  const MobileTourStep({
    required this.text,
    this.shown = const [],
    this.touched = const [],
    this.watch,
    this.reached,
    this.reveal,
    this.undo,
    this.tapping,
    this.enter,
    this.glyph,
    this.glyphs = const [],
    this.tapMovesOn = false,
    this.tapEnds = false,
    this.scrolls = true,
    this.high = false,
    this.lightsAll = false,
    this.joined = false,
    this.acted,
    this.present,
    this.coming,
    this.seen,
  });

  bool get isPresent => present?.call() ?? true;

  List<Widget Function(double size)> get drawn => glyphs.isNotEmpty ? glyphs : [?glyph];

  bool get isCounted => isPresent || (coming?.call() ?? false);

  bool get awaitsTouch => reached != null && !tapMovesOn;
}

class MobileTour
{
  final String slug;
  final String title;

  // Bumped on every change, so whoever had seen the tour sees it again.
  final int version;

  final List<MobileTourStep> steps;

  // Other tours marked seen with this one, at their versions; the second list only if closed early.
  final List<(String, int)> covers;
  final List<(String, int)> coversIfClosed;

  // Once true, what the tour lights has gone: it stops, not marked seen.
  final Listenable? leave;
  final bool Function()? left;

  // Puts the screen where the first step expects it: it may have moved while the tour waited to show.
  final VoidCallback? prepare;

  const MobileTour({
    required this.slug,
    required this.title,
    required this.version,
    required this.steps,
    this.covers = const [],
    this.coversIfClosed = const [],
    this.leave,
    this.left,
    this.prepare,
  });
}

// For [MobileTour.prepare]: back to [index], as a touch on the strip would turn the pages.
void turnMobileTourPages(PageController pages, int index)
{
  if (pages.hasClients && ((pages.page ?? 0) - index).abs() >= _pageSettled)
  {
    pages.animateToPage(index, duration: _pageTurn, curve: Curves.easeInOutCubic);
  }
}

class _Run
{
  final MobileTour tour;
  final String taxCode;

  const _Run(this.tour, this.taxCode);
}

final ValueNotifier<_Run?> _requested = ValueNotifier<_Run?>(null);

bool mobileTourSettled(BuildContext context)
{
  final MobileHandover? handover = MobileHandover.maybeOf(context);
  final MobileEntranceMotion? entrance = MobileEntranceMotion.maybeOf(context);

  return !MobileHoldScope.waitingOf(context) &&
      !(handover?.moving ?? false) &&
      !(handover?.waiting ?? false) &&
      !(entrance?.moving ?? false) &&
      !(entrance?.waiting ?? false);
}

bool get isMobileTourShown => _requested.value != null;

Listenable get mobileTourChanges => _requested;

Future<bool> isMobileTourSeen({required String taxCode, required MobileTour tour})
{
  return SeenTours.mobile.hasSeen(taxCode: taxCode, slug: tour.slug, version: tour.version);
}

Future<void> startMobileTourOnce({required String taxCode, required MobileTour tour}) async
{
  if (_requested.value != null || await isMobileTourSeen(taxCode: taxCode, tour: tour))
  {
    return;
  }

  _requested.value ??= _Run(tour, taxCode);
}

Future<void> resetMobileTours(String taxCode) => SeenTours.mobile.reset(taxCode);

// Menu sections with tours, by slug; a section's tours are slugged after it.
const Set<String> kMobileTourSections = {
  'home',
  'availability',
  'bookings',
  'children',
  'subjects',
  'calendar',
  'association',
  'profile',
  'settings',
};

Future<void> resetMobileToursOf(String taxCode, Iterable<String> sections) =>
    SeenTours.mobile.reset(taxCode, sections);

class MobileTourOnRise extends StatefulWidget
{
  final VoidCallback? onRisen;
  final Widget child;

  const MobileTourOnRise({super.key, required this.onRisen, required this.child});

  @override
  State<MobileTourOnRise> createState() => _MobileTourOnRiseState();
}

class _MobileTourOnRiseState extends State<MobileTourOnRise>
{
  Animation<double>? _rise;
  bool _done = false;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final Animation<double>? rise = ModalRoute.of(context)?.animation;

    if (rise == _rise)
    {
      return;
    }

    _rise?.removeStatusListener(_onStatus);
    _rise = rise;
    rise?.addStatusListener(_onStatus);

    if (rise == null || rise.isCompleted)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => _risen());
    }
  }

  @override
  void dispose()
  {
    _rise?.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status)
  {
    if (status.isCompleted)
    {
      _risen();
    }
  }

  void _risen()
  {
    if (_done || !mounted)
    {
      return;
    }

    _done = true;
    widget.onRisen?.call();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool isMobileTourTargetShown(String id) => _MobileTourTargetState.find(id) != null;

class MobileTourTarget extends StatefulWidget
{
  // Null marks nothing, so lighting a part or not keeps the tree the same.
  final String? id;

  final EdgeInsets inflate;
  final double radius;

  // Clipped to its vertical scroll view: a list longer than the view lights only what shows.
  final bool clipped;

  final bool toBottom;

  final Widget child;

  const MobileTourTarget({
    super.key,
    required this.id,
    this.inflate = EdgeInsets.zero,
    this.radius = 16,
    this.clipped = false,
    this.toBottom = false,
    required this.child,
  });

  @override
  State<MobileTourTarget> createState() => _MobileTourTargetState();
}

class _MobileTourTargetState extends State<MobileTourTarget>
{
  static final Map<String, List<_MobileTourTargetState>> _live = {};

  // Taken out of the tree during this frame's build: still listed until the frame ends, but gone.
  bool _active = true;

  // The latest mounted one wins, as when a page is rebuilt for a new role.
  static _MobileTourTargetState? find(String id) => findAll(id).lastOrNull;

  static List<_MobileTourTargetState> findAll(String id) => [
        for (final _MobileTourTargetState target in _live[id] ?? const <_MobileTourTargetState>[])
          if (target._active) target,
      ];

  void _register(String? id)
  {
    if (id != null)
    {
      _live.putIfAbsent(id, () => []).add(this);
    }
  }

  @override
  void initState()
  {
    super.initState();
    _register(widget.id);
  }

  @override
  void didUpdateWidget(MobileTourTarget oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id != widget.id)
    {
      _live[oldWidget.id]?.remove(this);
      _register(widget.id);
    }
  }

  @override
  void activate()
  {
    super.activate();
    _active = true;
  }

  @override
  void deactivate()
  {
    _active = false;
    super.deactivate();
  }

  @override
  void dispose()
  {
    _live[widget.id]?.remove(this);
    super.dispose();
  }

  RRect? holeIn(RenderBox ancestor, {bool clip = true, double shift = 0})
  {
    final RenderObject? box = context.findRenderObject();

    if (box is! RenderBox || !box.attached || !box.hasSize || !ancestor.attached)
    {
      return null;
    }

    // Through the screen: a target in a sheet's route is no descendant of the frame.
    final Offset origin = ancestor.globalToLocal(box.localToGlobal(Offset.zero)) + Offset(0, shift);
    final Rect inflated = widget.inflate.inflateRect(origin & box.size);
    final Rect rect = widget.toBottom
        ? Rect.fromLTRB(inflated.left, inflated.top, inflated.right, ancestor.size.height)
        : inflated;
    final Rect? view = widget.clipped && clip ? _viewIn(ancestor) : null;
    final Rect shown = view == null
        ? rect
        : Rect.fromLTRB(rect.left, math.max(rect.top, view.top), rect.right, math.min(rect.bottom, view.bottom));

    return RRect.fromRectAndRadius(shown, Radius.circular(widget.radius));
  }

  ScrollableState? get _vertical
  {
    ScrollableState? scrollable = Scrollable.maybeOf(context);

    while (scrollable != null && scrollable.position.axis != Axis.vertical)
    {
      scrollable = Scrollable.maybeOf(scrollable.context);
    }

    return scrollable;
  }

  Rect? _viewIn(RenderBox ancestor)
  {
    final RenderObject? view = _vertical?.context.findRenderObject();

    if (view is! RenderBox || !view.attached || !view.hasSize)
    {
      return null;
    }

    return ancestor.globalToLocal(view.localToGlobal(Offset.zero)) & view.size;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Runway
{
  final ScrollableState view;
  final double height;

  const _Runway(this.view, this.height);
}

final ValueNotifier<_Runway?> _runway = ValueNotifier<_Runway?>(null);

final Map<ScrollableState, _MobileTourRunwayState> _runwayViews = Map.identity();

// At a scroll view's end: room for a tour to scroll a part read there out from under its banner.
class MobileTourRunway extends StatefulWidget
{
  const MobileTourRunway({super.key});

  @override
  State<MobileTourRunway> createState() => _MobileTourRunwayState();
}

class _MobileTourRunwayState extends State<MobileTourRunway>
{
  ScrollableState? _view;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final ScrollableState? view = _PageScroll._vertical(Scrollable.maybeOf(context));

    if (view != _view)
    {
      _runwayViews.remove(_view);
      _view = view;

      if (view != null)
      {
        _runwayViews[view] = this;
      }
    }
  }

  @override
  void dispose()
  {
    _runwayViews.remove(_view);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final ScrollableState? view = _view;

    return ValueListenableBuilder<_Runway?>(
      valueListenable: _runway,
      builder: (context, runway, _) => SizedBox(height: runway != null && runway.view == view ? runway.height : 0),
    );
  }
}

class MobileTourLayer extends StatefulWidget
{
  final bool ready;

  const MobileTourLayer({super.key, required this.ready});

  @override
  State<MobileTourLayer> createState() => _MobileTourLayerState();
}

class _MobileTourLayerState extends State<MobileTourLayer> with TickerProviderStateMixin, WidgetsBindingObserver
{
  _Run? _run;
  int _step = 0;
  bool _closing = false;

  // Counts the steps entered: the banner's buttons answer only for the one they were drawn for.
  int _visit = 0;

  final List<int> _path = [];
  final Set<int> _visited = {};

  // Not lazy: never shown, it would be created in dispose() on an unmounted element.
  late final AnimationController _shown;
  late final AnimationController _move;

  // 0 above the menu, 1 under the status bar.
  late final AnimationController _anchor;
  bool _high = false;

  bool _placed = false;

  late final Ticker _follow;
  Duration _followed = Duration.zero;
  Duration _followUntil = Duration.zero;

  List<RRect> _from = const [];
  List<RRect> _to = const [];
  List<RRect> _touch = const [];

  // The last holes drawn, kept when what they lit goes away, as a sheet closed by its close button.
  List<RRect> _lastLit = const [];

  List<RRect> _aim = const [];

  // Per hole drawn, how touchable it is, 0 to 1: the touched parts come last in [_to] and [_aim].
  List<double> _fromTouch = const [];
  List<double> _lastTouch = const [];
  List<double> _litTouch = const [];
  int _touchCount = 0;

  late final TourBreath _breath;
  late final AnimationController _nudge;

  // The visits whose touchable parts breathed, and whose forward button touched for the user.
  int _breathed = -1;
  int _performed = -1;

  // Where this step's first part stood as it began, and how far its page has moved it since.
  Rect? _setOut;
  Offset _carried = Offset.zero;

  // Total shift the tour's own scroll gives that part, once known; the holes head there.
  Offset? _landing;
  ScrollableState? _landingView;

  // Holes are measured at paint, after the frame's layout; this triggers a repaint.
  final _Repaint _repaint = _Repaint();

  bool _watchingFrames = false;
  List<Rect> _lastSeen = const [];

  bool _planned = false;
  List<Size>? _lastSizes;
  bool _resized = false;
  int _sizesStill = 0;

  // How far the camera's page scrolls; a reveal planned while that changes waits for it to stand.
  ScrollableState? _endView;
  double _endExtent = 0;
  int _endStill = 0;
  bool _awaitingEnd = false;
  bool _endAwaited = false;
  int _endFrames = 0;

  _Run? _waiting;
  List<double>? _waitSeen;
  int _waitStill = 0;
  int _waitFrames = 0;

  // Set while a page changed by step start still moves; holes, banner and scroll start after it.
  VoidCallback? _settling;
  List<RRect> _lastStill = const [];
  int _still = 0;
  Timer? _settleCap;

  // While settling, the old holes follow the left step's lead part as the page moves it.
  String? _leftLead;
  Rect? _leftAt;
  Offset _leftMoved = Offset.zero;
  Rect? _surface;

  // From the last measure: where the described parts end, and the window the banner leaves.
  double _readBottom = double.negativeInfinity;
  double _windowTop = 0;
  double _floor = double.infinity;

  _PageScroll? _scrolled;

  // Kept for the step just entered: its own scroll starts from where this one found the page.
  _PageScroll? _backTo;

  ScrollableState? _driving;

  bool _endUp = false;
  Timer? _scrollWait;

  // Bumped by _unscroll, so a post-frame callback awaited for the left scroll is dropped.
  int _scrollRun = 0;
  Timer? _runwayDrop;
  bool _surfaceChanged = false;

  Listenable? _watching;
  Listenable? _leaving;

  final GlobalKey _bannerKey = GlobalKey();
  final GlobalKey _bannerTextKey = GlobalKey();
  final GlobalKey _frameKey = GlobalKey();

  OverlayEntry? _entry;

  @override
  void initState()
  {
    super.initState();
    _shown = AnimationController(vsync: this, duration: _fadeDuration);
    _move = AnimationController(vsync: this, duration: _moveDuration, value: 1);
    _anchor = AnimationController(vsync: this, duration: _moveDuration);
    _breath = TourBreath(this);
    _nudge = AnimationController(vsync: this, duration: kTourNudgeDuration, value: 1);
    _move.addStatusListener(_onMoved);
    _follow = createTicker(_onFollow);
    WidgetsBinding.instance.addObserver(this);
    _requested.addListener(_onRequested);
    MobileNavSheet.openness.addListener(_kick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRequested());
  }

  @override
  void didUpdateWidget(MobileTourLayer oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.ready && !oldWidget.ready)
    {
      // Not during this build: the start inserts into the overlay.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onRequested());
    }
  }

  // The overlay entry is its own element: it does not rebuild with this state.
  @override
  void setState(VoidCallback fn)
  {
    super.setState(fn);

    final OverlayEntry? entry = _entry;

    if (entry == null)
    {
      return;
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks)
    {
      SchedulerBinding.instance.addPostFrameCallback((_) => _entry?.markNeedsBuild());
    }
    else
    {
      entry.markNeedsBuild();
    }
  }

  @override
  void dispose()
  {
    WidgetsBinding.instance.removeObserver(this);
    _requested.removeListener(_onRequested);
    MobileNavSheet.openness.removeListener(_kick);
    _watching?.removeListener(_onWatched);
    _leaving?.removeListener(_onLeave);
    _scrollWait?.cancel();
    _runwayDrop?.cancel();
    _settleCap?.cancel();
    _entry?.remove();
    _entry?.dispose();

    // Left by sign-out: not marked, so shown again next time.
    _requested.value = null;

    _repaint.dispose();
    _follow.dispose();
    _shown.dispose();
    _move.dispose();
    _anchor.dispose();
    _breath.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _kick();

  MobileTourStep get _current => _run!.tour.steps[_step];

  void _onRequested()
  {
    final _Run? run = _requested.value;

    if (!mounted || run == null || _run != null || !widget.ready || _waiting == run)
    {
      return;
    }

    _waiting = run;
    _waitSeen = null;
    _waitStill = 0;
    _waitFrames = 0;

    // A menu opened while the tour waited goes; its first part is then awaited where the tour expects it.
    MobileNavSheet.close();
    run.tour.prepare?.call();
    _awaitStill(run);
  }

  // Shown once its first step's parts stand still, or an unfolding list is measured half open.
  void _awaitStill(_Run run)
  {
    if (!mounted || _requested.value != run || _run != null || !widget.ready)
    {
      if (_waiting == run)
      {
        _waiting = null;
      }

      return;
    }

    final int? start = _presentAfter(run.tour, -1);

    if (start == null)
    {
      _waiting = null;
      _requested.value = null;

      return;
    }

    final List<double> seen = _stillness(run.tour.steps[start]);

    _waitStill = listEquals(seen, _waitSeen) ? _waitStill + 1 : 0;
    _waitSeen = seen;

    if (_waitStill < _stillFrames && ++_waitFrames < _startLongest)
    {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => _awaitStill(run))
        ..scheduleFrame();

      return;
    }

    _waiting = null;
    _begin(run, start);
  }

  // Part positions and view extents: a list easing taller after an unfold still grows the page.
  List<double> _stillness(MobileTourStep step)
  {
    return [
      for (final Rect part in _partsOf(step)) ...[part.left, part.top, part.right, part.bottom],
      for (final String id in [...step.shown, ...step.touched])
        for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
          if (target._vertical?.position case final ScrollPosition view when view.hasContentDimensions)
            ...[view.maxScrollExtent, view.viewportDimension],
    ];
  }

  List<Rect> _partsOf(MobileTourStep step, {bool camera = false})
  {
    final RenderBox? layer = _frame;

    if (layer == null)
    {
      return const [];
    }

    final List<String> ids = camera
        ? [?step.reveal, if (step.scrolls) ...step.shown]
        : [...step.shown, ...step.touched];

    return [
      for (final String id in ids)
        for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
          if (target.holeIn(layer, clip: false) case final RRect hole) hole.outerRect,
    ];
  }

  void _begin(_Run run, int start)
  {
    setState(()
    {
      _run = run;
      _closing = false;
      _placed = false;
      _path.clear();
      _visited.clear();
    });

    final OverlayEntry entry = OverlayEntry(builder: _buildOverlay);

    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);

    _leaving = run.tour.leave;
    _leaving?.addListener(_onLeave);

    _enter(start, first: true);
    _shown.forward(from: 0);

    if (!_watchingFrames)
    {
      _watchingFrames = true;
      SchedulerBinding.instance.addPostFrameCallback(_watchFrame);
    }
  }

  // Runs after every frame drawn for any reason while a tour is up, and asks for none.
  void _watchFrame(Duration _)
  {
    if (!mounted || _run == null)
    {
      _watchingFrames = false;
      _lastSeen = const [];

      return;
    }

    SchedulerBinding.instance.addPostFrameCallback(_watchFrame);

    final RenderBox? layer = _frame;

    if (layer == null)
    {
      return;
    }

    final MobileTourStep step = _current;
    final List<Rect> seen = _partsOf(step);

    if (!listEquals(seen, _lastSeen))
    {
      _lastSeen = seen;
      _kick();
    }

    // The scroll's subject resizing, as rows unfold: once still, the scroll is planned again.
    final List<Size> sizes = [for (final Rect part in _partsOf(step, camera: true)) part.size];

    if (!_sameSizes(sizes, _lastSizes))
    {
      _resized = _resized || (_planned && _lastSizes != null);
      _lastSizes = sizes;
      _sizesStill = 0;
    }
    else if (_resized && ++_sizesStill >= _stillFrames && !_move.isAnimating && _settling == null)
    {
      _resized = false;
      _replan();
    }

    _watchEnd(step);
  }

  void _watchEnd(MobileTourStep step)
  {
    final String? camera = _camera(step);
    final _MobileTourTargetState? focus = camera == null ? null : _MobileTourTargetState.findAll(camera).firstOrNull;
    final _PageScroll? scroll = focus == null || !focus.mounted ? null : _PageScroll.of(focus.context);

    if (scroll == null || !scroll._alive)
    {
      return;
    }

    final double extent = scroll.extent;

    if (scroll._innerView != _endView)
    {
      _endView = scroll._innerView;
      _endExtent = extent;
      _endStill = _stillFrames;
    }
    else if ((extent - _endExtent).abs() >= _sizeTolerance)
    {
      _endExtent = extent;
      _endStill = 0;

      // Frames keep coming until the end has stood still.
      if (_awaitingEnd)
      {
        _kick();
      }
    }
    else
    {
      _endStill++;
    }

    if (_awaitingEnd &&
        (_endStill >= _stillFrames || ++_endFrames >= _startLongest) &&
        !_move.isAnimating &&
        _settling == null)
    {
      _awaitingEnd = false;
      _endAwaited = true;
      _replan();
    }
  }

  // Against the sizes last taken as changed, so a slow growth still adds up to one.
  static bool _sameSizes(List<Size> now, List<Size>? before)
  {
    if (before == null || now.length != before.length)
    {
      return false;
    }

    for (var i = 0; i < now.length; i++)
    {
      if ((now[i].width - before[i].width).abs() >= _sizeTolerance ||
          (now[i].height - before[i].height).abs() >= _sizeTolerance)
      {
        return false;
      }
    }

    return true;
  }

  void _replan()
  {
    final String? camera = _camera(_current);
    final ScrollableState? view = camera == null
        ? null
        : _MobileTourTargetState.findAll(camera).firstOrNull?._vertical;
    final _PageScroll? held = _scrolled;

    _backTo = held != null && held._alive && held.holds(view) ? held : null;
    _bringIn();
  }

  int? _presentAfter(MobileTour tour, int index)
  {
    for (var i = index + 1; i < tour.steps.length; i++)
    {
      if (tour.steps[i].isPresent)
      {
        return i;
      }
    }

    return null;
  }

  int get _countedLater => _run!.tour.steps.skip(_step + 1).where((step) => step.isCounted).length;

  void _onLeave()
  {
    final bool Function()? left = _run?.tour.left;

    if (left != null && left())
    {
      _end(early: false, mark: false);
    }
  }

  void _onTouchTap()
  {
    final _Run? run = _run;
    final int step = _step;

    if (run == null || _closing || !(_current.tapMovesOn || _current.tapEnds))
    {
      return;
    }

    // At once: what it closes would otherwise stop the tour unmarked first.
    if (_current.tapEnds)
    {
      _end(early: false);

      return;
    }

    // After what the tap set off has started.
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      if (mounted && _run == run && _step == step && !_closing)
      {
        _advance();
      }
    });
  }

  // Holes are measured on the entry once built, on the shell before; both fill the screen.
  RenderBox? get _frame
  {
    final RenderObject? drawn = _frameKey.currentContext?.findRenderObject();

    if (drawn is RenderBox && drawn.attached && drawn.hasSize)
    {
      return drawn;
    }

    final RenderObject? own = context.findRenderObject();

    return own is RenderBox && own.attached && own.hasSize ? own : null;
  }

  void _nextFrom(int visit)
  {
    if (_run == null || _closing || visit != _visit)
    {
      return;
    }

    final MobileTourStep step = _current;

    if (!_performs)
    {
      _advance();

      return;
    }

    final String? part = step.tapping ?? step.touched.firstOrNull;
    final BuildContext? target = part == null ? null : _MobileTourTargetState.find(part)?.context;

    if (_performed != visit && !step.reached!() && target != null && tapTourPart(target))
    {
      _performed = visit;
    }
  }

  // A touch awaited with steps after it: the forward button does it, the step moves on as after the user's.
  bool get _performs => _current.awaitsTouch && _countedLater > 0;

  void _onMoved(AnimationStatus status)
  {
    if (status == AnimationStatus.completed)
    {
      _breatheIn();
    }
  }

  // Once per step as its holes land; [again] after a touch that missed.
  void _breatheIn({bool again = false})
  {
    if (_run == null || _closing || _current.touched.isEmpty || (!again && _breathed == _visit))
    {
      return;
    }

    _breathed = _visit;

    if (!MediaQuery.disableAnimationsOf(context))
    {
      _breath.start();
    }
  }

  void _onMiss()
  {
    if (_run == null || _closing)
    {
      return;
    }

    if (!MediaQuery.disableAnimationsOf(context))
    {
      _nudge.forward(from: 0);
    }

    _breatheIn(again: true);
  }

  void _backFrom(int visit)
  {
    if (visit == _visit)
    {
      _back();
    }
  }

  void _back()
  {
    if (_run == null || _closing || _path.length < 2)
    {
      return;
    }

    _path.removeLast();

    final int index = _path.last;

    // Watching the earlier step first, so the screen going back does not count as this one done.
    _enter(index, back: true);
    _run!.tour.steps[index].undo?.call();
  }

  // Back: no check right away, the screen is still where the later step left it.
  void _enter(int index, {bool first = false, bool back = false})
  {
    final MobileTourStep step = _run!.tour.steps[index];
    final MobileTourStep? left = first ? null : _current;

    _visit++;

    // A page this step scrolls too is moved once, by the step's own scroll, not put back first.
    final bool goingBack = _unscroll(keepFor: _camera(step));

    _watching?.removeListener(_onWatched);
    _watching = step.watch;
    _watching?.addListener(_onWatched);

    final List<RRect> now = _holesNow();

    _from = first ? const [] : (now.isEmpty ? _lastLit : now);
    _fromTouch = first ? const [] : (now.isEmpty ? _lastTouch : _litTouch);
    _step = index;
    _endUp = false;
    _setOut = null;
    _carried = Offset.zero;
    _landing = null;
    _landingView = null;
    _planned = false;
    _lastSizes = null;
    _resized = false;
    _awaitingEnd = false;
    _endAwaited = false;
    _settling = null;
    _settleCap?.cancel();
    _leftLead = null;
    _leftMoved = Offset.zero;

    step.enter?.call();

    if (!back)
    {
      _path.add(index);
    }

    _visited.add(index);
    final (List<RRect> holes, List<RRect> touch) = _measure(step);

    _to = holes;
    _touch = touch;
    _touchCount = touch.length;

    void setOff()
    {
      // Lasts as long as the page's scroll back, so the holes land with it.
      _move.duration = goingBack ? _scrollBack : _moveDuration;
      _move.forward(from: first ? 1 : 0);

      if (!_move.isAnimating)
      {
        _breatheIn();
      }

      // A part taller than the window is read from its top before the rest comes up.
      if (step.shown.isNotEmpty && step.scrolls)
      {
        _scrollWait = Timer(_scrollPause, _scrollThrough);
      }

      // After the next layout, with the banner on this step's text; the page may have moved too.
      _afterLayout(_bringIn);
    }

    // An enter step moves the page: settle first, or two holes slide and the banner crosses.
    if (step.enter != null && left != null)
    {
      final String? lead = _lead(left);

      _move.value = 0;
      _settling = setOff;
      _lastStill = holes;
      _still = 0;
      _settleCap = Timer(_settleLongest, _settle);
      _leftLead = lead;
      _leftAt = _leftStands();
      _leftMoved = Offset.zero;
    }
    else
    {
      setOff();
    }

    setState(() {});
    _kick();

    if (!back)
    {
      _onWatched(entering: true);
    }
  }

  String? _camera(MobileTourStep step) => step.reveal ?? (step.scrolls ? step.shown.firstOrNull : null);

  void _afterLayout(VoidCallback then)
  {
    final _Run? run = _run;
    final int mine = _scrollRun;

    SchedulerBinding.instance
      ..addPostFrameCallback((_)
      {
        if (mounted && _run == run && !_closing && _scrollRun == mine)
        {
          then();
        }
      })
      ..scheduleFrame();
  }

  // One scroll per step: the revealed part into view, read parts whole if they fit, else their top.
  void _bringIn({bool grown = false})
  {
    final MobileTourStep step = _current;
    final RenderBox? layer = _frame;
    final _PageScroll? held = _backTo;

    _backTo = null;

    if (layer == null)
    {
      return;
    }

    _planned = true;

    // The banner now holds this step's text: the window it leaves is its own.
    _measure(step);

    final String? camera = _camera(step);
    final _MobileTourTargetState? focus = camera == null ? null : _MobileTourTargetState.findAll(camera).firstOrNull;

    if (step.reveal != null && focus != null)
    {
      if (focus.holeIn(layer, clip: false) case final RRect whole)
      {
        _revealAcross(focus, whole.outerRect, layer);
      }
    }

    final _PageScroll? scroll = held ?? (focus == null || !focus.mounted ? null : _PageScroll.of(focus.context));

    if (scroll == null || !scroll._alive)
    {
      // Nothing to scroll: a part read running under the banner has it make way now.
      if (step.scrolls && step.shown.isNotEmpty)
      {
        _scrollWait?.cancel();
        _scrollWait = Timer(Duration.zero, _scrollThrough);
      }

      return;
    }

    final double base = held?.start ?? scroll.offset;

    // Offsets showing the parts: from the first up to the second.
    // Up to the third a read part still fits, its top in the gap under the window's edge.
    (double, double, double) limits(Iterable<String> ids, {required bool read})
    {
      double low = double.negativeInfinity;
      double high = double.infinity;
      double tight = double.infinity;

      for (final String id in ids)
      {
        for (final _MobileTourTargetState part in _MobileTourTargetState.findAll(id))
        {
          final ScrollableState? view = part._vertical;
          final Rect? whole = part.holeIn(layer, clip: false)?.outerRect;

          if (view == null || whole == null || !scroll.holds(view))
          {
            continue;
          }

          final Rect? frame = part._viewIn(layer);
          final double? viewTop = frame?.top;
          final double bottom = read
              ? math.min(_floor, (frame?.bottom ?? double.infinity) - _surfaceGap)
              : math.min(_floor, frame?.bottom ?? double.infinity) - _surfaceGap;

          (double, double) within(double gap) => scroll.range(
                view,
                whole,
                top: _windowTop + gap,
                viewTop: viewTop == null ? null : viewTop + gap,
                bottom: bottom,
              );

          final (double from, double to) = within(_surfaceGap);

          low = math.max(low, from);
          high = math.min(high, to);
          tight = math.min(tight, read ? within(0).$2 : to);
        }
      }

      return (low, high, tight);
    }

    // The nearest to where the page was found; taller than the window, its top kept.
    double nearest(double low, double high, double tight) =>
        low > base ? (low <= tight ? low : high) : math.min(base, high);

    final bool reads = step.scrolls && step.shown.isNotEmpty;
    final (double revealLow, double revealHigh, _) = limits([?step.reveal], read: false);
    final (double cutFrom, double readHigh, double readTight) =
        reads ? limits(step.shown, read: true) : (double.negativeInfinity, double.infinity, double.infinity);
    final double readLow = cutFrom - base <= _cutTolerance ? double.negativeInfinity : cutFrom;
    final double target = nearest(
      math.max(revealLow, readLow),
      math.min(revealHigh, readHigh),
      math.min(revealHigh, readTight),
    );

    // A view ending too soon gets room at its end first, a frame before it scrolls.
    if (reads && !grown && target > scroll.last + 0.5 && _runwayViews.containsKey(scroll._innerView))
    {
      _growRunway(scroll, target - scroll.last);
      _backTo = held;
      _afterLayout(() => _bringIn(grown: true));

      return;
    }

    // A page still growing, as a sector's rows unfold, moves what it reveals: one scroll, once it stands.
    if (!reads && !_endAwaited && scroll._innerView == _endView && _endStill < _stillFrames)
    {
      _awaitingEnd = true;
      _endFrames = 0;

      return;
    }

    final double from = scroll.offset;
    final bool moves = (target - from).abs() >= 1;

    // Already in place but still carried by an earlier step's scroll: it stops there.
    if (!moves && scroll._innerView == _driving)
    {
      scroll.hold();
    }

    if (moves)
    {
      final ScrollableState? view = _leadTarget(step)?._vertical;
      final double to = scroll.to(target, _revealDuration);

      _driving = scroll._innerView;

      if (_from.isNotEmpty && _move.isAnimating && _move.value < _justSetOff && view != null && scroll.holds(view))
      {
        _from = _lastLit;
        _fromTouch = _lastTouch;
        _landingView = view;
        _landing = _carried + Offset(0, scroll.shiftTo(view, to));
        _move.duration = _revealDuration;
        _move.forward(from: 0);
      }

      _kick(_revealDuration + _followWindow);
    }

    if (reads)
    {
      // Put back, once left, as far as what the step reveals alone would have brought it.
      _scrolled = held ?? scroll._from(nearest(revealLow, revealHigh, revealHigh));

      // Not taller than the window: whatever still runs under the banner then has it make way.
      if (readLow <= readTight)
      {
        _scrollWait?.cancel();
        _scrollWait = Timer(moves ? _revealDuration : Duration.zero, _scrollThrough);
      }
    }
    else if (held != null)
    {
      // Only revealed: left there, not to be put back later under a sheet.
      _scrolled = null;
    }
  }

  _MobileTourTargetState? _leadTarget(MobileTourStep step)
  {
    final String? lead = _lead(step);

    return lead == null ? null : _MobileTourTargetState.findAll(lead).firstOrNull;
  }

  void _growRunway(_PageScroll scroll, double short)
  {
    final _Runway? had = _runway.value;
    final double kept = had != null && had.view == scroll._innerView ? had.height : 0;

    _runway.value = _Runway(scroll._innerView, kept + short + _runwayGap(scroll));
  }

  // Content ending above the view's lowest bottom scrolls only once the runway has filled that gap.
  double _runwayGap(_PageScroll scroll)
  {
    final RenderObject? end = _runwayViews[scroll._innerView]?.context.findRenderObject();
    final RenderObject? view = scroll._innerView.context.findRenderObject();

    if (end is! RenderBox || view is! RenderBox || !end.attached || !view.attached || !end.hasSize || !view.hasSize)
    {
      return 0;
    }

    // Under loose constraints a short view shrinks to its content: it grows up to their height first.
    final double height = view.constraints.hasBoundedHeight ? view.constraints.maxHeight : view.size.height;

    // A nested header still showing lifts the content as it goes, and the body grows by as much.
    final ScrollPosition? head = scroll.outer;
    final double header = head != null && head.hasPixels ? head.maxScrollExtent - head.pixels : 0;
    final double reached = end.localToGlobal(Offset(0, end.size.height)).dy - header;

    return math.max(0, view.localToGlobal(Offset.zero).dy + height - reached);
  }

  Rect? _leftStands()
  {
    final String? lead = _leftLead;
    final RenderBox? layer = _frame;

    return lead == null || layer == null ? null : _MobileTourTargetState.findAll(lead).firstOrNull?.holeIn(layer)?.outerRect;
  }

  String? _lead(MobileTourStep step) => step.shown.isNotEmpty ? step.shown.first : step.touched.firstOrNull;

  void _settle()
  {
    final VoidCallback? setOff = _settling;

    _settleCap?.cancel();
    _settleCap = null;
    _settling = null;

    if (setOff == null || _run == null || _closing)
    {
      return;
    }

    _setOut = null;
    _carried = Offset.zero;
    _from = [for (final RRect hole in _from) hole.shift(_leftMoved)];
    _leftLead = null;
    _leftMoved = Offset.zero;

    final (List<RRect> holes, List<RRect> touch) = _measure(_current);

    setState(()
    {
      _to = holes;
      _touch = touch;
      _touchCount = touch.length;
    });
    setOff();
    _kick();
  }


  // A tab of a strip running past the screen's edge slides in; pages being swiped are left alone.
  void _revealAcross(_MobileTourTargetState target, Rect whole, RenderBox layer)
  {
    final ScrollableState? across = Scrollable.maybeOf(target.context, axis: Axis.horizontal);

    if (across == null || across.widget.controller is PageController || !across.position.hasPixels)
    {
      return;
    }

    final double right = layer.size.width - _sideMargin;
    final double by = whole.left < _sideMargin
        ? whole.left - _sideMargin
        : whole.right > right
            ? whole.right - right
            : 0;

    if (by.abs() >= 1)
    {
      final ScrollPosition position = across.position;

      position.animateTo(
        (position.pixels + by).clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: _revealDuration,
        curve: Curves.easeInOutCubic,
      );
      _kick(_revealDuration + _followWindow);
    }
  }

  void _onWatched({bool entering = false})
  {
    final _Run? run = _run;

    if (run == null || _closing)
    {
      return;
    }

    _kick();

    // What the touch changed may change the count too.
    if (!entering)
    {
      setState(() {});
    }

    final int step = _step;
    final bool Function()? reached = _current.reached;
    final bool Function()? acted = entering ? null : _current.acted;

    bool done() => (reached != null && reached()) || (acted != null && acted());

    if (done())
    {
      // After the frame that changed it, and once even if told several times in it.
      SchedulerBinding.instance.addPostFrameCallback((_)
      {
        if (mounted && _run == run && _step == step && !_closing && done())
        {
          _advance();
        }
      });
    }
  }

  void _advance()
  {
    final int? next = _presentAfter(_run!.tour, _step);

    if (next != null)
    {
      _enter(next);
    }
    else
    {
      _end(early: false);
    }
  }

  Future<void> _end({required bool early, bool mark = true}) async
  {
    final _Run? run = _run;

    if (run == null || _closing)
    {
      return;
    }

    setState(() => _closing = true);
    _settling = null;
    _settleCap?.cancel();
    _watching?.removeListener(_onWatched);
    _watching = null;
    _leaving?.removeListener(_onLeave);
    _leaving = null;
    _unscroll();

    if (early)
    {
      MobileNotice.show(context, kTutorialClosedEarly);
    }

    // Left halfway, the steps already passed still count: only the rest comes again.
    final List<int> shown = mark ? _visited.toList() : _path.where((index) => index != _step).toList();
    final List<(String, int)> seen = [
      if (mark) (run.tour.slug, run.tour.version),
      if (mark) ...run.tour.covers,
      for (final int index in shown) ?run.tour.steps[index].seen,
      if (mark && early) ...run.tour.coversIfClosed,
    ];

    await SeenTours.mobile.markSeen(run.taxCode, {for (final (String slug, int version) in seen) slug: version});

    await _shown.reverse();

    if (!mounted)
    {
      return;
    }

    _follow.stop();
    _requested.value = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    setState(()
    {
      _run = null;
      _from = const [];
      _to = const [];
      _touch = const [];
      _lastLit = const [];
      _aim = const [];
      _fromTouch = const [];
      _lastTouch = const [];
      _litTouch = const [];
      _touchCount = 0;
    });
  }

  // Follows moving targets for a while after anything moved, then stops asking for frames.
  void _kick([Duration window = _followWindow])
  {
    if (_run == null)
    {
      return;
    }

    if (_follow.isActive)
    {
      final Duration until = _followed + window;

      if (until > _followUntil)
      {
        _followUntil = until;
      }

      return;
    }

    _followed = Duration.zero;
    _followUntil = window;
    _follow.start();
  }

  void _scrollThrough({int grown = 0})
  {
    _scrollWait = null;

    final _Run? run = _run;

    if (run == null || _closing)
    {
      return;
    }

    _measure(_current);

    if (_readBottom - _floor <= _cutTolerance)
    {
      return;
    }

    final List<_MobileTourTargetState> targets = _MobileTourTargetState.findAll(_current.shown.first);
    final _PageScroll? scroll = targets.isEmpty ? null : _PageScroll.of(targets.first.context);

    final double by = _readBottom - _floor;

    if (scroll != null && grown < 2 && by > scroll.room + _cutTolerance && _runwayViews.containsKey(scroll._innerView))
    {
      _scrolled = _held(scroll);
      _growRunway(scroll, by - scroll.room);
      _afterLayout(() => _scrollThrough(grown: grown + 1));

      return;
    }

    final double room = scroll?.room ?? 0;
    final double moved = math.min(by, room);
    final Duration duration = Duration(milliseconds: (moved * _scrollMsPerPixel).round());
    final Duration clamped = duration < _scrollShortest
        ? _scrollShortest
        : duration > _scrollLongest
            ? _scrollLongest
            : duration;

    final bool scrolls = scroll != null && moved >= 1;

    if (scrolls)
    {
      _scrolled = _held(scroll);
      scroll.to(scroll.start + moved, clamped);
      _driving = scroll._innerView;
    }

    // View ends before the part clears a low banner: once scrolled, the banner makes way.
    if (by > room + _cutTolerance && !_high)
    {
      _scrollWait = Timer(scrolls ? clamped : Duration.zero, ()
      {
        _scrollWait = null;

        if (mounted && _run == run && !_closing)
        {
          setState(() => _endUp = true);
          _kick();
        }
      });
    }

    _kick(clamped + _followWindow);
  }

  // A page already moved by an earlier step keeps where it was found.
  _PageScroll _held(_PageScroll scroll)
  {
    final _PageScroll? earlier = _scrolled;

    return earlier != null && earlier._innerView == scroll._innerView ? earlier : scroll;
  }

  // A page holding [keepFor], a next-step part, is not put back: the next step scrolls it.
  bool _unscroll({String? keepFor})
  {
    _scrollWait?.cancel();
    _scrollWait = null;
    _backTo = null;
    _scrollRun++;

    final _PageScroll? scroll = _scrolled;
    final _Runway? runway = _runway.value;
    final _MobileTourTargetState? kept = keepFor == null ? null : _MobileTourTargetState.findAll(keepFor).firstOrNull;

    if (scroll != null && scroll._alive && scroll.holds(kept?._vertical))
    {
      _backTo = scroll;

      return true;
    }

    _scrolled = null;

    if (scroll != null)
    {
      scroll.to(scroll.start, _scrollBack);
      _driving = scroll._innerView;
      _kick(_scrollBack + _followWindow);
    }

    // Taken away once the view is back, so nothing jumps; unless a later step made its own.
    if (runway != null)
    {
      _runwayDrop?.cancel();
      _runwayDrop = Timer(_scrollBack, ()
      {
        if (identical(_runway.value, runway))
        {
          _runway.value = null;
        }
      });
    }

    return scroll != null;
  }

  void _onFollow(Duration elapsed)
  {
    _followed = elapsed;

    if (_run == null)
    {
      _follow.stop();

      return;
    }

    final (List<RRect> holes, List<RRect> touch) = _measure(_current);

    if (_settling != null)
    {
      _still = listEquals(holes, _lastStill) ? _still + 1 : 0;
      _lastStill = holes;

      if (_still >= _stillFrames)
      {
        _settle();

        return;
      }

      _leftMoved = _leftMovedNow();
    }

    if (!listEquals(touch, _touch) || _surfaceChanged)
    {
      setState(() => _touch = touch);
    }

    _to = holes;
    _touchCount = touch.length;
    _repaint.tick();

    if (elapsed > _followUntil)
    {
      _follow.stop();
    }
  }

  Offset _leftMovedNow()
  {
    return switch ((_leftAt, _leftStands()))
    {
      (final Rect at, final Rect now) => now.topLeft - at.topLeft,
      _ => _leftMoved,
    };
  }

  RRect? _hole(String id, RenderBox layer) => _MobileTourTargetState.find(id)?.holeIn(layer);

  List<RRect> _holes(String id, RenderBox layer, {double shift = 0, ScrollableState? view})
  {
    return [
      for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
        if (target.holeIn(layer, shift: view != null && target._vertical == view ? shift : 0) case final RRect hole)
          hole,
    ];
  }

  // Measured a frame earlier, the holes would trail a moving page by one frame.
  List<RRect> _paintedHoles()
  {
    if (_run == null)
    {
      return const [];
    }

    if (_settling != null)
    {
      _leftMoved = _leftMovedNow();
    }

    final (List<RRect> holes, List<RRect> touch) = _measure(_current, placing: false);

    _to = holes;
    _touchCount = touch.length;

    return _holesNow();
  }

  // Returns (lit, touchable) holes; places the banner too, unless [placing] is off (at paint).
  (List<RRect>, List<RRect>) _measure(MobileTourStep step, {bool placing = true})
  {
    final RenderBox? layer = _frame;

    if (layer == null)
    {
      return (const [], const []);
    }

    // A bar slid away for a sheet still leaves the screen's bottom inset, or the keyboard, clear.
    // The keyboard read where the entry is: the shell's place may have it taken out.
    final Rect? bar = _hole(kMobileTourNavSheet, layer)?.outerRect;
    final double keyboard = MediaQuery.viewInsetsOf(_frameKey.currentContext ?? context).bottom;
    final double lowest = layer.size.height - math.max(MediaQuery.paddingOf(context).bottom, keyboard);
    final Rect? surface = bar == null || bar.top <= lowest
        ? bar
        : Rect.fromLTWH(bar.left, lowest, bar.width, bar.height);

    if (placing)
    {
      _surfaceChanged = surface != _surface;
      _surface = surface;
    }

    final List<RRect> touched = [for (final String id in step.touched) ..._holes(id, layer)];

    final double height = _bannerHeight();
    final double safeTop = MediaQuery.paddingOf(context).top + _surfaceGap;
    final double low = (surface?.top ?? 0) - _surfaceGap - height;

    final List<RRect> read = [for (final String id in step.shown) ..._holes(id, layer)];

    bool cutBelow(double floor) => read.any((hole) => hole.outerRect.bottom > floor + _cutTolerance);
    bool cutAbove(double ceiling) => read.any((hole) => hole.outerRect.top < ceiling);

    // Scrolled out from under the banner by the step, so the banner does not bounce midway.
    // Not by a view too short and without runway: there the banner rises at once.
    bool scrolledOut(_MobileTourTargetState target)
    {
      final _PageScroll? scroll = _PageScroll.of(target.context);
      final Rect? whole = target.holeIn(layer, clip: false)?.outerRect;

      if (scroll == null || whole == null)
      {
        return false;
      }

      return _runwayViews.containsKey(scroll._innerView) || whole.bottom - (low - _surfaceGap) <= scroll.room + _cutTolerance;
    }

    final bool scrollsOut =
        step.scrolls && step.shown.isNotEmpty && _MobileTourTargetState.findAll(step.shown.first).any(scrolledOut);

    double readBottom = double.negativeInfinity;
    double viewTop = double.negativeInfinity;
    double viewBottom = double.infinity;

    for (final String id in step.shown)
    {
      for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
      {
        if (target.holeIn(layer, clip: false)?.outerRect case final Rect whole)
        {
          readBottom = math.max(readBottom, whole.bottom);
        }

        if (target.widget.clipped)
        {
          if (target._viewIn(layer) case final Rect view)
          {
            viewTop = math.max(viewTop, view.top);
            viewBottom = math.min(viewBottom, view.bottom);
          }
        }
      }
    }

    // Low over the menu unless it covers a touched part or hides a read part it cannot scroll out.
    // Stays put until it holds this step's text, and while a page changed by the step still moves.
    final Widget? built = _bannerKey.currentWidget;
    bool high = _settling != null || (_placed && built is _TourBanner && built.step != _step)
        ? _high
        : step.high ||
            surface == null ||
            low < safeTop ||
            touched.any((hole) => hole.outerRect.top < surface.top - _surfaceGap && hole.outerRect.bottom > low) ||
            (cutBelow(low - _surfaceGap) &&
                !scrollsOut &&
                !cutAbove(safeTop + height + _surfaceGap) &&
                !cutBelow(surface.top - _surfaceGap)) ||
            _endUp;

    if (placing)
    {
      _place(high);
    }
    else
    {
      high = _high;
    }

    final double ceiling = high ? safeTop + height + _surfaceGap : double.negativeInfinity;
    final double floor = high ? (surface?.top ?? double.infinity) - _surfaceGap : low - _surfaceGap;

    _floor = math.min(floor, viewBottom);
    _windowTop = math.max(high ? ceiling : MediaQuery.paddingOf(context).top, viewTop);
    _readBottom = readBottom;

    final String? lead = _lead(step);
    final List<_MobileTourTargetState> leads = lead == null ? const [] : _MobileTourTargetState.findAll(lead);

    if (leads.isNotEmpty && _settling == null)
    {
      if (leads.first.holeIn(layer, clip: false)?.outerRect case final Rect standing)
      {
        _carried = standing.topLeft - (_setOut ??= standing).topLeft;
      }
    }

    final List<RRect> cut = [
      for (final RRect hole in read)
        if (_cut(hole, ceiling, floor) case final RRect kept) kept,
    ];

    List<RRect> drawn(List<RRect> holes) => [
          if (step.joined && holes.length > 1)
            RRect.fromRectAndRadius(
              _union(holes).outerRect,
              holes.map((hole) => hole.tlRadius).reduce((a, b) => a.x >= b.x ? a : b),
            )
          else
            ...holes,
          if (step.lightsAll) RRect.fromRectAndRadius(Offset.zero & layer.size, Radius.zero),
        ];

    // A part wholly under the banner is lit only once out, but moving holes head for it anyway.
    final Offset? landing = _landing;
    final double rest = landing == null ? 0 : (landing - _carried).dy;

    List<RRect> landed(List<String> ids, List<RRect> now) =>
        landing == null ? now : [for (final String id in ids) ..._holes(id, layer, shift: rest, view: _landingView)];

    _aim = [
      ...drawn([for (final RRect hole in landed(step.shown, read)) _cut(hole, ceiling, floor) ?? hole]),
      ...landed(step.touched, touched),
    ];

    return ([...drawn(cut), ...touched], touched);
  }

  RRect? _cut(RRect hole, double ceiling, double floor)
  {
    final double top = math.max(hole.top, ceiling);
    final double bottom = math.min(hole.bottom, floor);

    if (top == hole.top && bottom == hole.bottom)
    {
      return hole;
    }

    if (bottom - top <= _shortestHole)
    {
      return null;
    }

    return RRect.fromRectAndRadius(Rect.fromLTRB(hole.left, top, hole.right, bottom), hole.tlRadius);
  }

  // The height the banner is heading to while its text changes size.
  double _bannerHeight()
  {
    final RenderObject? banner = _bannerKey.currentContext?.findRenderObject();

    if (banner is! RenderBox || !banner.hasSize)
    {
      return _bannerGuess;
    }

    // The text growing or shrinking: the switcher's stack ends with the text coming in.
    final RenderObject? sized = _bannerTextKey.currentContext?.findRenderObject();
    final RenderObject? texts = sized is RenderAnimatedSize ? sized.child : null;
    final RenderBox? text = texts is RenderStack ? texts.lastChild : null;

    if (sized is! RenderAnimatedSize || !sized.hasSize || text == null || !text.hasSize)
    {
      return banner.size.height;
    }

    return banner.size.height - sized.size.height + text.size.height;
  }

  void _place(bool high)
  {
    if (!_placed)
    {
      _placed = true;
      _high = high;
      _anchor.value = high ? 1 : 0;

      return;
    }

    if (high != _high)
    {
      _high = high;
      high ? _anchor.forward() : _anchor.reverse();
    }
  }

  List<RRect> _holesNow()
  {
    final double t = Curves.easeInOutCubic.transform(_move.value);
    final (List<RRect> holes, List<double> touch) =
        _from.isEmpty || _aim.isEmpty || t >= 1 ? (_to, _touchOf(_to.length)) : _between(t, _aim);

    if (holes.isNotEmpty)
    {
      _lastLit = holes;
      _lastTouch = touch;
    }

    _litTouch = touch;

    return holes;
  }

  List<double> _touchOf(int count) => [for (var i = 0; i < count; i++) i >= count - _touchCount ? 1.0 : 0.0];

  // Fewer holes: each goes to the nearest and they join; more: they part from where all were.
  // While this step's page moves, they head where it stops if known, else ride with the page.
  (List<RRect>, List<double>) _between(double t, List<RRect> to)
  {
    final List<RRect> carried = [
      for (final RRect hole in _from) _landing == null ? hole.shift(_carried + _leftMoved) : hole,
    ];
    final List<double> from = _fromTouch.length == carried.length ? _fromTouch : List.filled(carried.length, 0.0);
    final List<double> touch = _touchOf(to.length);

    if (carried.length > to.length)
    {
      final List<int> nearest = [for (final RRect hole in carried) _nearest(hole, to)];

      return (
        [for (final (int i, RRect hole) in carried.indexed) RRect.lerp(hole, to[nearest[i]], t)!],
        [for (final (int i, double was) in from.indexed) ui.lerpDouble(was, touch[nearest[i]], t)!],
      );
    }

    final bool same = carried.length == to.length;
    final RRect whole = _union(carried);
    final double wholeTouch = from.fold(0.0, math.max);

    return (
      [for (var i = 0; i < to.length; i++) RRect.lerp(same ? carried[i] : whole, to[i], t)!],
      [for (var i = 0; i < to.length; i++) ui.lerpDouble(same ? from[i] : wholeTouch, touch[i], t)!],
    );
  }

  int _nearest(RRect from, List<RRect> holes)
  {
    final Offset centre = from.outerRect.center;
    int best = 0;

    for (var i = 1; i < holes.length; i++)
    {
      if ((holes[i].outerRect.center - centre).distanceSquared < (holes[best].outerRect.center - centre).distanceSquared)
      {
        best = i;
      }
    }

    return best;
  }

  RRect _union(List<RRect> holes)
  {
    Rect rect = holes.first.outerRect;

    for (final RRect hole in holes.skip(1))
    {
      rect = rect.expandToInclude(hole.outerRect);
    }

    return RRect.fromRectAndRadius(rect, holes.first.tlRadius);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  Widget _buildOverlay(BuildContext context)
  {
    final _Run? run = _run;

    if (run == null)
    {
      return const SizedBox.shrink();
    }

    final MobileTourStep step = _current;
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double safeTop = MediaQuery.paddingOf(context).top;

    // With none present yet the forward button ends the tour: it reads "Fine" and promises none.
    final bool performs = _performs;
    final int later = !performs && _presentAfter(run.tour, _step) == null ? 0 : _countedLater;
    final int total = _path.length + later;

    final int visit = _visit;
    final Widget banner = _TourBanner(
      key: _bannerKey,
      textKey: _bannerTextKey,
      title: total > 1 ? '${run.tour.title} · ${_path.length} di $total' : run.tour.title,
      text: step.text,
      glyphs: step.drawn,
      step: _step,
      onClose: () => _end(early: true),
      onBack: _path.length > 1 ? () => _backFrom(visit) : null,
      onNext: () => _nextFrom(visit),
      nudge: _nudge,
      last: later == 0,
    );

    return SizedBox.expand(
      key: _frameKey,
      child: IgnorePointer(
        ignoring: _closing,
        child: FadeTransition(
          opacity: _shown,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Holes(
                holes: _touch,
                onTouch: _kick,
                onTap: step.tapMovesOn || step.tapEnds ? _onTouchTap : null,
                onMiss: _onMiss,
                child: AnimatedBuilder(
                  animation: _move,
                  builder: (context, _) => CustomPaint(
                    painter: _DimPainter(
                      measure: _paintedHoles,
                      touch: () => _litTouch,
                      glow: () => _breath.glow,
                      repaint: Listenable.merge([_repaint, _breath.listenable]),
                      color: AppTheme.trialDeepWater.withValues(alpha: _dimAlpha),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _anchor,
                builder: (context, child) => CustomSingleChildLayout(
                  delegate: _BannerLayout(
                    surfaceTop: _surface?.top,
                    safeTop: safeTop + _surfaceGap,
                    high: Curves.easeInOutCubic.transform(_anchor.value),
                    width: tablet ? MobileNavSheet.tabletWidth : null,
                  ),
                  child: child,
                ),
                child: banner,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A page's vertical scroll; in a nested scroll view the header goes first, then the body.
class _PageScroll
{
  final ScrollableState _innerView;
  final ScrollableState? _outerView;

  ScrollPosition get inner => _innerView.position;
  ScrollPosition? get outer => _outerView?.position;

  bool get _alive => _innerView.mounted && (_outerView?.mounted ?? true);

  final double start;

  double get room => math.max(0, last - start);

  // The furthest the content can move up, header and body together.
  double get last
  {
    final ScrollPosition? head = outer;

    if (!_alive || !inner.hasPixels || (head != null && !head.hasPixels))
    {
      return start;
    }

    final double body = inner.maxScrollExtent - inner.minScrollExtent;

    return head == null
        ? inner.maxScrollExtent
        : head.maxScrollExtent + math.max(0, body - (head.maxScrollExtent - head.pixels));
  }

  bool holds(ScrollableState? view) => view != null && (view == _innerView || view == _outerView);

  // How far header and body can scroll in all, wherever they stand.
  double get extent
  {
    final ScrollPosition? head = outer;
    double length(ScrollPosition? view) =>
        view != null && view.hasContentDimensions ? view.maxScrollExtent - view.minScrollExtent : 0;

    return _alive ? length(inner) + length(head) : 0;
  }

  // Offsets keeping [part] below [top] and [viewTop], above [bottom]: from the first to the second.
  // A nested header moves only until gone; the body's top rises with it.
  (double, double) range(ScrollableState view, Rect part, {required double top, double? viewTop, required double bottom})
  {
    final ScrollPosition? head = outer;
    final bool nested = head != null && head.hasPixels;

    if (view == _outerView && nested)
    {
      final double from = head.pixels + part.bottom - bottom;
      final double to = head.pixels + part.top - math.max(top, viewTop ?? double.negativeInfinity);

      return (
        from <= head.minScrollExtent ? double.negativeInfinity : from,
        to >= head.maxScrollExtent ? double.infinity : to,
      );
    }

    final double to = offset + part.top - top;

    if (viewTop == null)
    {
      return (offset + part.bottom - bottom, to);
    }

    // In a nested body the part stays under the body's top until the body scrolls past it.
    final double under = nested
        ? head.maxScrollExtent + math.max(0, inner.pixels - inner.minScrollExtent + part.top - viewTop)
        : offset + part.top - viewTop;

    return (offset + part.bottom - bottom, math.min(to, under));
  }

  // How far [view]'s content moves down at [offset]; a nested header moves only with the outer.
  double shiftTo(ScrollableState view, double offset)
  {
    final ScrollPosition? head = outer;

    if (view == _outerView && head != null && head.hasPixels)
    {
      return head.pixels - offset.clamp(head.minScrollExtent, head.maxScrollExtent);
    }

    return view == _innerView ? this.offset - offset : 0;
  }

  double get offset
  {
    final ScrollPosition? head = outer;

    if (!_alive || !inner.hasPixels || (head != null && !head.hasPixels))
    {
      return start;
    }

    return _offset(inner, head);
  }

  _PageScroll._(this._innerView, this._outerView, [double? start])
      : start = start ?? _offset(_innerView.position, _outerView?.position);

  _PageScroll _from(double start) => _PageScroll._(_innerView, _outerView, start);

  // Stops in place as a finger would; a nested coordinator stops header and body together.
  void hold()
  {
    if (_alive && inner.hasPixels)
    {
      inner.hold(() {}).cancel();
    }
  }

  static _PageScroll? of(BuildContext context)
  {
    final ScrollableState? inner = _vertical(Scrollable.maybeOf(context));

    if (inner == null)
    {
      return null;
    }

    final ScrollableState? outer = _vertical(Scrollable.maybeOf(inner.context));

    return _PageScroll._(inner, outer);
  }

  static ScrollableState? _vertical(ScrollableState? from)
  {
    ScrollableState? state = from;

    while (state != null && state.position.axis != Axis.vertical)
    {
      state = Scrollable.maybeOf(state.context);
    }

    return state;
  }

  static double _offset(ScrollPosition inner, ScrollPosition? outer)
  {
    return outer == null ? inner.pixels : outer.pixels + inner.pixels - inner.minScrollExtent;
  }

  double to(double offset, Duration duration)
  {
    if (!_alive)
    {
      return this.offset;
    }

    final ScrollPosition? head = outer;

    if (!inner.hasPixels || (head != null && !head.hasPixels))
    {
      return this.offset;
    }

    if (head == null)
    {
      final double target = offset.clamp(inner.minScrollExtent, inner.maxScrollExtent);

      inner.animateTo(target, duration: duration, curve: Curves.easeInOutCubic);

      return target;
    }

    final double last = head.maxScrollExtent + inner.maxScrollExtent - inner.minScrollExtent;
    final double target = offset.clamp(head.minScrollExtent, last);

    // Either drives the nested coordinator: the outer up to the header's end, the inner past it.
    if (target <= head.maxScrollExtent)
    {
      head.animateTo(target, duration: duration, curve: Curves.easeInOutCubic);
    }
    else
    {
      inner.animateTo(
        target - head.maxScrollExtent + inner.minScrollExtent,
        duration: duration,
        curve: Curves.easeInOutCubic,
      );
    }

    return target;
  }
}

class _BannerLayout extends SingleChildLayoutDelegate
{
  final double? surfaceTop;
  final double safeTop;
  final double high;

  final double? width;

  const _BannerLayout({required this.surfaceTop, required this.safeTop, required this.high, required this.width});

  double _widthIn(Size size) => width ?? size.width - _sideMargin * 2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints)
  {
    final double w = _widthIn(constraints.biggest);

    return BoxConstraints(minWidth: w, maxWidth: w, maxHeight: constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize)
  {
    final double? surface = surfaceTop;
    final double low = surface == null ? safeTop : surface - _surfaceGap - childSize.height;

    return Offset((size.width - childSize.width) / 2, ui.lerpDouble(low, safeTop, high)!);
  }

  @override
  bool shouldRelayout(_BannerLayout oldDelegate)
  {
    return surfaceTop != oldDelegate.surfaceTop ||
        safeTop != oldDelegate.safeTop ||
        high != oldDelegate.high ||
        width != oldDelegate.width;
  }
}

// Takes every touch outside the holes; inside them a tap reaches what is below, a drag does not.
class _Holes extends SingleChildRenderObjectWidget
{
  final List<RRect> holes;

  // Told of a tap inside a hole, after what is underneath had it; [onTouch] of any lift there.
  final VoidCallback? onTap;
  final VoidCallback? onTouch;

  // A tap anywhere else, which nothing answers.
  final VoidCallback? onMiss;

  const _Holes({required this.holes, this.onTap, this.onTouch, this.onMiss, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context)
  {
    return _RenderHoles(holes, MediaQuery.maybeGestureSettingsOf(context))
      ..onTap = onTap
      ..onTouch = onTouch
      ..onMiss = onMiss;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHoles renderObject)
  {
    renderObject
      ..holes = holes
      ..onTap = onTap
      ..onTouch = onTouch
      ..onMiss = onMiss
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  }
}

class _RenderHoles extends RenderProxyBox
{
  List<RRect> holes;
  VoidCallback? onTap;
  VoidCallback? onTouch;
  VoidCallback? onMiss;

  final Map<int, Offset> _downs = {};
  final Map<int, Offset> _missed = {};

  // Dispatched before the scroll views and sheets below, with the same slop: they lose every drag.
  late final VerticalDragGestureRecognizer _vertical = VerticalDragGestureRecognizer(debugOwner: this)
    ..onStart = _ignore;
  late final HorizontalDragGestureRecognizer _horizontal = HorizontalDragGestureRecognizer(debugOwner: this)
    ..onStart = _ignore;

  _RenderHoles(this.holes, DeviceGestureSettings? settings)
  {
    gestureSettings = settings;
  }

  set gestureSettings(DeviceGestureSettings? settings)
  {
    _vertical.gestureSettings = settings;
    _horizontal.gestureSettings = settings;
  }

  static void _ignore(DragStartDetails details) {}

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position})
  {
    if (!size.contains(position))
    {
      return false;
    }

    result.add(BoxHitTestEntry(this, position));

    // Inside a hole what is underneath is hit too.
    return !holes.any((hole) => hole.contains(position));
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry)
  {
    if (event is PointerDownEvent && holes.any((hole) => hole.contains(entry.localPosition)))
    {
      _vertical.addPointer(event);
      _horizontal.addPointer(event);
      _downs[event.pointer] = event.position;
    }
    else if (event is PointerDownEvent)
    {
      _missed[event.pointer] = event.position;
    }
    else if (event is PointerUpEvent)
    {
      final Offset? down = _downs.remove(event.pointer);
      final Offset? missed = _missed.remove(event.pointer);

      if (down != null)
      {
        onTouch?.call();
      }

      if (down != null && (event.position - down).distance < kTouchSlop)
      {
        onTap?.call();
      }

      if (missed != null && (event.position - missed).distance < kTouchSlop)
      {
        onMiss?.call();
      }
    }
    else if (event is PointerCancelEvent)
    {
      _downs.remove(event.pointer);
      _missed.remove(event.pointer);
    }
  }

  @override
  void dispose()
  {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }
}

class _Repaint extends ChangeNotifier
{
  void tick() => notifyListeners();
}

class _DimPainter extends CustomPainter
{
  final List<RRect> Function() measure;

  // Read after [measure], one per hole.
  final List<double> Function() touch;
  final double Function() glow;

  final Color color;

  _DimPainter({required this.measure, required this.touch, required this.glow, required this.color, super.repaint});

  List<RRect> get holes => measure();

  @override
  void paint(Canvas canvas, Size size)
  {
    final List<RRect> holes = this.holes;
    final Path lit = Path();

    for (final RRect hole in holes)
    {
      lit.addRRect(hole);
    }

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), lit),
      Paint()..color = color,
    );

    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rimWidth
      ..color = AppTheme.trialGold;
    final List<double> touch = this.touch();
    final double glow = this.glow();

    for (final (int i, RRect hole) in holes.indexed)
    {
      if (i < touch.length)
      {
        paintTourHalo(canvas, hole.inflate(_rimWidth), touch[i] * glow);
      }

      canvas.drawRRect(hole.inflate(_rimWidth / 2), rim);
    }
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate) => true;
}

class _TourBanner extends StatelessWidget
{
  final String title;
  final String text;
  final List<Widget Function(double size)> glyphs;
  final int step;

  final GlobalKey textKey;

  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  final Animation<double> nudge;

  final bool last;

  const _TourBanner({
    super.key,
    required this.title,
    required this.text,
    required this.glyphs,
    required this.step,
    required this.textKey,
    required this.onClose,
    required this.onBack,
    required this.onNext,
    required this.nudge,
    required this.last,
  });

  Widget _text(BuildContext context)
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: _textSize,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Colors.white,
    );
    final String text = withoutOrphans(this.text);
    final List<String> parts = text.split(kMobileTourGlyph);

    if (glyphs.isEmpty || parts.length < 2)
    {
      return Text(text, style: style);
    }

    final double em = MediaQuery.textScalerOf(context).scale(_textSize);
    final double size = (em * _glyphEm).roundToDouble();

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, part) in parts.indexed) ...[
            if (i > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ExcludeSemantics(
                    child: _CapitalsCentred(
                      above: kCapitalsMiddle * em,
                      child: glyphs[math.min(i, glyphs.length) - 1](size),
                    ),
                  ),
                ),
              ),
            TextSpan(text: part),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? back = onBack;
    final VoidCallback? next = onNext;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 13),
        decoration: BoxDecoration(
          color: AppTheme.trialDeepWater,
          borderRadius: BorderRadius.circular(_bannerRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(0, 12), blurRadius: 32)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedSize(
                key: textKey,
                duration: _moveDuration,
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: _moveDuration,
                  switchInCurve: Curves.easeOutCubic,
                  // Runs in reverse on the way out, so it eases out too.
                  switchOutCurve: Curves.easeInCubic,
                  // Outgoing text takes no touch: its buttons lie under a shorter new one.
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [
                      for (final Widget child in previous) IgnorePointer(key: child.key, child: child),
                      if (current != null) IgnorePointer(key: current.key, ignoring: false, child: current),
                    ],
                  ),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(step),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: _titleTop),
                              child: Text(
                                title.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: const Color(0xFFF3C766),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _text(context),
                          ],
                        ),
                      ),
                      if (back != null || next != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (back != null) _BackButton(onTap: back),
                            if (back != null && next != null) const SizedBox(width: 8),
                            if (next != null)
                              ScaleTransition(scale: kTourNudge.animate(nudge), child: _NextButton(onTap: next, last: last)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _CloseButton(onTap: onClose),
          ],
        ),
      ),
    );
  }
}

// Sits with its centre [above] the text's baseline: on the capitals' middle.
class _CapitalsCentred extends SingleChildRenderObjectWidget
{
  final double above;

  const _CapitalsCentred({required this.above, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCapitalsCentred(above);

  @override
  void updateRenderObject(BuildContext context, _RenderCapitalsCentred renderObject)
  {
    renderObject.above = above;
  }
}

class _RenderCapitalsCentred extends RenderProxyBox
{
  double _above;

  _RenderCapitalsCentred(this._above);

  set above(double value)
  {
    if (value != _above)
    {
      _above = value;
      markNeedsLayout();
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height / 2 + _above;
}

class _CloseButton extends StatelessWidget
{
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Chiudi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget
{
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Indietro',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _nextHeight,
          height: _nextHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white.withValues(alpha: 0.9)),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget
{
  final VoidCallback onTap;
  final bool last;

  const _NextButton({required this.onTap, required this.last});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _nextHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.trialGold, Color(0xFFF3C766)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x52E3A83C), offset: Offset(0, 4), blurRadius: 10)],
          ),
          child: MobileButtonLabel(
            label: last ? _endLabel : _nextLabel,
            icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
            color: AppTheme.trialDeepWater,
            fontSize: 12.5,
            iconSize: 16,
          ),
        ),
      ),
    );
  }
}
