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
import '../../../services/seen_tours.dart';
import '../../layout/mobile_breakpoints.dart';
import '../mobile_line_breaks.dart';
import 'mobile_baseline_hang.dart';
import 'mobile_button_label.dart';
import 'mobile_entrance_motion.dart';
import 'mobile_handover.dart';
import 'mobile_load_switcher.dart';
import 'mobile_nav_sheet.dart';
import 'mobile_notice.dart';


const String kMobileTourClosedEarly = 'Puoi riattivare il tutorial dalle impostazioni.';

// Stands in a step's text where its glyph goes.
const String kMobileTourGlyph = '\u{FFFC}';
const String _nextLabel = 'Avanti';
const String _endLabel = 'Fine';

// Targets of the menu, lit by any tour.
const String kMobileTourNavSheet = 'nav.sheet';
const String kMobileTourNavSections = 'nav.sections';

// A sheet's close button; the top sheet's when several are up.
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

// Until the banner has been laid out once.
const double _bannerGuess = 96;

// A hole cut shorter than this by the banner is left out.
const double _shortestHole = 24;

// A read hole running this far under the banner still counts as clear of it.
const double _cutTolerance = 8;

const double _dimAlpha = 0.62;

const Duration _fadeDuration = Duration(milliseconds: 260);
const Duration _moveDuration = Duration(milliseconds: 380);
const Duration _revealDuration = Duration(milliseconds: 420);

// Long enough to follow a page turn, the menu's spring and a scroll into view.
const Duration _followWindow = Duration(milliseconds: 900);

// What the banner hides of a described part comes up: at once if it fits, else after a pause.
const Duration _scrollSettle = Duration(milliseconds: 450);
const Duration _scrollPause = Duration(milliseconds: 1200);
const double _scrollMsPerPixel = 4;
const Duration _scrollShortest = Duration(milliseconds: 700);
const Duration _scrollLongest = Duration(milliseconds: 2400);
const Duration _scrollBack = Duration(milliseconds: 420);

// A step's start changing the page: its holes wait until they stand still this many frames, or this long.
const int _stillFrames = 3;
const Duration _settleLongest = Duration(milliseconds: 900);

// How far into their move holes still count as setting off, a reveal joining them.
const double _justSetOff = 0.2;

class MobileTourStep
{
  final String text;

  // Lit to be read: they take no touch and stop above the banner.
  final List<String> shown;

  // Lit to be touched: the touch reaches them.
  final List<String> touched;

  // Without them the step moves on with the forward button.
  final Listenable? watch;
  final bool Function()? reached;

  // Scrolled into view when the step starts, unless already in sight.
  final String? reveal;

  // Puts the screen back as it was before this step's touch, when stepping back to it.
  final VoidCallback? undo;

  // Run as the step begins, as a list put back to the one the step speaks of.
  final VoidCallback? enter;

  // Drawn where the text holds kMobileTourGlyph, as tall as given.
  final Widget Function(double size)? glyph;

  // In place of [glyph] when they differ: one per kMobileTourGlyph, in order.
  final List<Widget Function(double size)> glyphs;

  // A tap on a touched part moves on too, as the forward button does.
  final bool tapMovesOn;

  // A tap on a touched part ends the tour: what it opens or closes leaves the later steps nothing to light.
  final bool tapEnds;

  // What the banner hides of the parts read comes up; off for a list longer than any screen.
  final bool scrolls;

  // The banner under the status bar, whatever is lit.
  final bool high;

  // Nothing dimmed: the step is about the whole screen.
  final bool lightsAll;

  // The parts read lit as one hole around them all, as a heading and the table under it.
  final bool joined;

  // Moves on once [watch] tells of the touch and this holds, never as the step begins; the forward button stays.
  final bool Function()? acted;

  // While false the step is passed over; the touches before it may make it true.
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

  const MobileTour({
    required this.slug,
    required this.title,
    required this.version,
    required this.steps,
    this.covers = const [],
    this.coversIfClosed = const [],
    this.leave,
    this.left,
  });
}

class _Run
{
  final MobileTour tour;
  final String taxCode;

  const _Run(this.tour, this.taxCode);
}

final ValueNotifier<_Run?> _requested = ValueNotifier<_Run?>(null);

// True once the page is loaded and no entrance is moving it.
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

// Told as a tour is asked for and as it ends.
Listenable get mobileTourChanges => _requested;

Future<bool> isMobileTourSeen({required String taxCode, required MobileTour tour})
{
  return SeenTours.mobile.hasSeen(taxCode: taxCode, slug: tour.slug, version: tour.version);
}

// Once per person and tour, whatever the device.
Future<void> startMobileTourOnce({required String taxCode, required MobileTour tour}) async
{
  if (_requested.value != null || await isMobileTourSeen(taxCode: taxCode, tour: tour))
  {
    return;
  }

  _requested.value ??= _Run(tour, taxCode);
}

Future<void> resetMobileTours(String taxCode) => SeenTours.mobile.reset(taxCode);

// Menu sections having tours, by slug; a section's tours are slugged after it. Add one with its first tour.
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

// Every tour of these sections shows again, its main one and those of its single parts.
Future<void> resetMobileToursOf(String taxCode, Iterable<String> sections) =>
    SeenTours.mobile.reset(taxCode, sections);

// Calls back once its sheet has finished rising, so a tour measures it in place.
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

// Whether a part a tour can light is built now, as a mark that shows only sometimes.
bool isMobileTourTargetShown(String id) => _MobileTourTargetState.find(id) != null;

// Marks what a tour can light; touches inside a lit target reach it.
class MobileTourTarget extends StatefulWidget
{
  // Null marks nothing, so lighting a part or not keeps the tree the same.
  final String? id;

  // Negative values pull the hole in.
  final EdgeInsets inflate;
  final double radius;

  // Cut to the vertical scroll view holding it, so a list longer than its view lights only what shows.
  final bool clipped;

  // Runs down to the screen's bottom: a part and everything under it.
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

  // The latest mounted one wins, as when a page is rebuilt for a new role.
  static _MobileTourTargetState? find(String id)
  {
    final List<_MobileTourTargetState>? all = _live[id];

    return all == null || all.isEmpty ? null : all.last;
  }

  // Every one with the id, in mounting order: one per child, say.
  static List<_MobileTourTargetState> findAll(String id) => List.of(_live[id] ?? const []);

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
  void dispose()
  {
    _live[widget.id]?.remove(this);
    super.dispose();
  }

  // [clip] false: where the part stands, seen or not.
  RRect? holeIn(RenderBox ancestor, {bool clip = true})
  {
    final RenderObject? box = context.findRenderObject();

    if (box is! RenderBox || !box.attached || !box.hasSize || !ancestor.attached)
    {
      return null;
    }

    // Through the screen: a target in a sheet's route is no descendant of the frame.
    final Offset origin = ancestor.globalToLocal(box.localToGlobal(Offset.zero));
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

// Views that make room at their end: a tour can always scroll a part of theirs out from under the banner.
final Set<ScrollableState> _runwayViews = Set.identity();

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
        _runwayViews.add(view);
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

// Lives in the shell, draws in a root overlay entry, which stays above every route and sheet.
// [ready] holds a tour back while the shell is moving.
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

  // The steps shown so far, in order: going back walks it; and every one shown, for its seen mark.
  final List<int> _path = [];
  final Set<int> _visited = {};

  // Not lazy: a layer that never showed a tour would create them in dispose(), on an unmounted element.
  late final AnimationController _shown;
  late final AnimationController _move;

  // 0 above the menu, 1 under the status bar.
  late final AnimationController _anchor;
  bool _high = false;

  // The first place is taken at once.
  bool _placed = false;

  late final Ticker _follow;
  Duration _followed = Duration.zero;
  Duration _followUntil = Duration.zero;

  List<RRect> _from = const [];
  List<RRect> _to = const [];
  List<RRect> _touch = const [];

  // The last holes drawn, kept when what they lit goes away, as a sheet closed by its close button.
  List<RRect> _lastLit = const [];

  // Where this step's holes head while they move: a part read still under the banner too, where it stands.
  List<RRect> _aim = const [];

  // Where this step's first part stood as it began, and how far its page has moved it since.
  Rect? _setOut;
  Offset _carried = Offset.zero;

  // How far the tour's own scroll moves that part in all, once known: the holes head where it stops.
  Offset? _landing;

  // Set while the page a step's start changed still moves: the holes, the banner and the scroll then set off.
  VoidCallback? _settling;
  List<RRect> _lastStill = const [];
  int _still = 0;
  Timer? _settleCap;

  // Meanwhile the last holes stay on the step left's part, as it moves with the page: its first, where it stood.
  String? _leftLead;
  Rect? _leftAt;
  Offset _leftMoved = Offset.zero;
  Rect? _surface;

  // From the last measure: where the described parts run, and the window the banner leaves.
  double _readTop = double.infinity;
  double _readBottom = double.negativeInfinity;
  double _windowTop = 0;
  double _floor = double.infinity;

  // Scrolled by the current step; put back when the step is left.
  _PageScroll? _scrolled;

  // Set when scrolling the part read cannot bring its end above a low banner: the banner goes up.
  bool _endUp = false;
  Timer? _scrollWait;

  // Moved on when the step's scroll is put back, so a frame awaited for it is let go.
  int _scrollRun = 0;
  Timer? _runwayDrop;
  Timer? _revealWait;
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

  // The entry is built apart from this widget.
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
    _revealWait?.cancel();
    _settleCap?.cancel();
    _entry?.remove();
    _entry?.dispose();

    // Left by sign-out: not marked, so shown again next time.
    _requested.value = null;

    _follow.dispose();
    _shown.dispose();
    _move.dispose();
    _anchor.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => _kick();

  MobileTourStep get _current => _run!.tour.steps[_step];

  void _onRequested()
  {
    final _Run? run = _requested.value;

    if (!mounted || run == null || _run != null || !widget.ready)
    {
      return;
    }

    final int? start = _presentAfter(run.tour, -1);

    if (start == null)
    {
      _requested.value = null;

      return;
    }

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

  // A tap on a touched part, on a step that lets it move on.
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

    // A part read keeps the page moved; one only revealed lets it go back, never to be put back later, under a sheet.
    final bool goingBack = _unscroll(keepFor: step.scrolls ? step.shown.firstOrNull : null);

    _watching?.removeListener(_onWatched);
    _watching = step.watch;
    _watching?.addListener(_onWatched);

    final List<RRect> now = _holesNow();

    // Its part gone, the step before still hands its last place on: the next holes move from there.
    _from = first ? const [] : (now.isEmpty ? _lastLit : now);
    _step = index;
    _endUp = false;
    _setOut = null;
    _carried = Offset.zero;
    _landing = null;
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

    // After the next layout: the page may have just been moved, as to the lesson under way, and not laid out yet.
    final _Run run = _run!;
    final int mine = _scrollRun;

    void reveal()
    {
      SchedulerBinding.instance
        ..addPostFrameCallback((_)
        {
          if (mounted && _run == run && !_closing && _scrollRun == mine)
          {
            _reveal(step.reveal);
          }
        })
        ..scheduleFrame();
    }

    void setOff()
    {
      // As long as the page going back, so the holes land with it.
      _move.duration = goingBack ? _scrollBack : _moveDuration;
      _move.forward(from: first ? 1 : 0);

      // Measured while the page went back, the part came only halfway in: the header stayed cut.
      if (goingBack && step.reveal != null)
      {
        _revealWait = Timer(_scrollBack, reveal);
      }
      else
      {
        reveal();
      }

      if (step.shown.isNotEmpty && step.scrolls)
      {
        _scrollWait = Timer(_scrollSettle, _scrollThrough);
      }
    }

    // A list sliding to another, a sheet growing with it: lit while they moved, two holes slid and the banner crossed.
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

  // Brought into the window the banner leaves, by the least scroll, its top kept in sight.
  void _reveal(String? id)
  {
    final List<_MobileTourTargetState> all = id == null ? const [] : _MobileTourTargetState.findAll(id);
    final _MobileTourTargetState? target = all.isEmpty ? null : all.first;
    final RenderBox? layer = _frame;

    if (target == null || !target.mounted || layer == null)
    {
      return;
    }

    final Rect? whole = target.holeIn(layer, clip: false)?.outerRect;
    final Rect? view = target._viewIn(layer);
    final _PageScroll? scroll = _PageScroll.of(target.context);

    if (whole != null)
    {
      _revealAcross(target, whole, layer);
    }

    if (whole == null || scroll == null)
    {
      return;
    }

    final double top = math.max(_windowTop, view?.top ?? double.negativeInfinity) + _surfaceGap;
    final double bottom = math.min(_floor, view?.bottom ?? double.infinity) - _surfaceGap;

    final double by = whole.top < top
        ? whole.top - top
        : whole.bottom > bottom
            ? math.min(whole.bottom - bottom, whole.top - top)
            : 0;

    if (by.abs() >= 1)
    {
      final double from = scroll.offset;
      final double to = scroll.to(scroll.start + by, _revealDuration);

      // The step's own part, its holes just setting off: they head where it stops, and arrive with it.
      if (id == _lead(_current) && _move.isAnimating && _move.value < _justSetOff)
      {
        _landing = _carried + Offset(0, from - to);
        _move.duration = _revealDuration;
        _move.forward(from: 0);
      }

      _kick(_revealDuration + _followWindow);
    }
  }

  // Where the step left's part stands now, if still there.
  Rect? _leftStands()
  {
    final String? lead = _leftLead;
    final RenderBox? layer = _frame;

    return lead == null || layer == null ? null : _MobileTourTargetState.findAll(lead).firstOrNull?.holeIn(layer)?.outerRect;
  }

  // The part the step's holes follow: the first read, else the first touched.
  String? _lead(MobileTourStep step) => step.shown.isNotEmpty ? step.shown.first : step.touched.firstOrNull;

  // Once what a step's start changed stands still: the step sets off from where the last one left its holes.
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
      MobileNotice.show(context, kMobileTourClosedEarly);
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

  // Brings up what the banner hides of the parts described, scrolling their page.
  void _scrollThrough({bool waited = false, bool grown = false})
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

    // Taller than the window, it is read from its top before the rest comes up.
    if (!waited && _readBottom - _readTop > _floor - _windowTop)
    {
      _scrollWait = Timer(_scrollPause - _scrollSettle, () => _scrollThrough(waited: true));

      return;
    }

    final List<_MobileTourTargetState> targets = _MobileTourTargetState.findAll(_current.shown.first);
    final _PageScroll? scroll = targets.isEmpty ? null : _PageScroll.of(targets.first.context);

    final double by = _readBottom - _floor;

    // Its view ends too soon: room is made at its end, where it has a runway, a frame before scrolling.
    if (scroll != null && !grown && by > scroll.room + _cutTolerance)
    {
      final int mine = _scrollRun;

      _scrolled = _held(scroll);
      _runway.value = _Runway(scroll._innerView, scroll.runwayFor(by));
      SchedulerBinding.instance
        ..addPostFrameCallback((_)
        {
          if (mounted && _run == run && !_closing && _scrollRun == mine)
          {
            _scrollThrough(waited: true, grown: true);
          }
        })
        ..scheduleFrame();

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
    }

    // Its view ends before its end comes clear of a low banner: once scrolled, the banner makes way.
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

  // True while the page goes back to where the step found it; with [keepFor], a part the next step reads in that
  // same page, only as far as shows it, a frame on, once the banner holds the next text.
  bool _unscroll({String? keepFor})
  {
    _scrollWait?.cancel();
    _scrollWait = null;
    _revealWait?.cancel();
    _revealWait = null;
    _scrollRun++;

    final _PageScroll? scroll = _scrolled;
    final _Runway? runway = _runway.value;
    final List<_MobileTourTargetState> kept = keepFor == null ? const [] : _MobileTourTargetState.findAll(keepFor);
    final bool sameView = kept.isNotEmpty && _PageScroll.of(kept.first.context)?._innerView == scroll?._innerView;

    if (scroll != null && scroll._alive && sameView)
    {
      final _Run? run = _run;
      final int mine = _scrollRun;

      SchedulerBinding.instance
        ..addPostFrameCallback((_)
        {
          if (mounted && _run == run && !_closing && _scrollRun == mine)
          {
            _goBackFor(scroll);
          }
        })
        ..scheduleFrame();
      _kick(_scrollBack + _followWindow);

      return true;
    }

    _scrolled = null;

    if (scroll != null)
    {
      scroll.to(scroll.start, _scrollBack);
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

  // The parts read measured as if the page were back where the step before found it; moved from there by the
  // least that shows them, their top first.
  void _goBackFor(_PageScroll scroll)
  {
    double by = 0;

    if (_frame != null && scroll._alive)
    {
      _measure(_current);

      final double back = scroll.offset - scroll.start;
      final double top = _windowTop + _surfaceGap;
      final double partTop = _readTop + back;
      final double partBottom = _readBottom + back;

      if (partTop.isFinite)
      {
        by = partTop < top
            ? partTop - top
            : partBottom > _floor + _cutTolerance
                ? math.min(partBottom - _floor, partTop - top)
                : 0;
      }
    }

    final double from = scroll.offset;

    // The holes set off again with the page: a frame behind it, they bulged on the way.
    _move.forward(from: 0);
    _landing = _carried + Offset(0, from - scroll.to(scroll.start + by, _scrollBack));
    _kick(_scrollBack + _followWindow);
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

      if ((_leftAt, _leftStands()) case (final Rect at, final Rect now) when now.topLeft - at.topLeft != _leftMoved)
      {
        setState(() => _leftMoved = now.topLeft - at.topLeft);
      }
    }

    if (!listEquals(holes, _to) || !listEquals(touch, _touch) || _surfaceChanged)
    {
      setState(()
      {
        _to = holes;
        _touch = touch;
      });
    }

    if (elapsed > _followUntil)
    {
      _follow.stop();
    }
  }

  RRect? _hole(String id, RenderBox layer) => _MobileTourTargetState.find(id)?.holeIn(layer);

  List<RRect> _holes(String id, RenderBox layer)
  {
    return [
      for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
        if (target.holeIn(layer) case final RRect hole) hole,
    ];
  }

  // Every lit hole and the touchable ones; places the banner, then cuts what is read above it.
  (List<RRect>, List<RRect>) _measure(MobileTourStep step)
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

    _surfaceChanged = surface != _surface;
    _surface = surface;

    final List<RRect> touched = [for (final String id in step.touched) ..._holes(id, layer)];

    final double height = _bannerHeight();
    final double safeTop = MediaQuery.paddingOf(context).top + _surfaceGap;
    final double low = (surface?.top ?? 0) - _surfaceGap - height;

    final List<RRect> read = [for (final String id in step.shown) ..._holes(id, layer)];

    bool cutBelow(double floor) => read.any((hole) => hole.outerRect.bottom > floor + _cutTolerance);
    bool cutAbove(double ceiling) => read.any((hole) => hole.outerRect.top < ceiling);

    // Scrolled out from under the banner by the step: rising midway made the banner bounce.
    // Not by a view that cannot move it far enough and makes no room at its end: there the banner rises at once.
    bool scrolledOut(_MobileTourTargetState target)
    {
      final _PageScroll? scroll = _PageScroll.of(target.context);
      final Rect? whole = target.holeIn(layer, clip: false)?.outerRect;

      if (scroll == null || whole == null)
      {
        return false;
      }

      return _runwayViews.contains(scroll._innerView) || whole.bottom - (low - _surfaceGap) <= scroll.room + _cutTolerance;
    }

    final bool scrollsOut =
        step.scrolls && step.shown.isNotEmpty && _MobileTourTargetState.findAll(step.shown.first).any(scrolledOut);

    // For the scroll: the parts whole, and the window their own views leave, in a sheet above its buttons.
    double readTop = double.infinity;
    double readBottom = double.negativeInfinity;
    double viewTop = double.negativeInfinity;
    double viewBottom = double.infinity;

    for (final String id in step.shown)
    {
      for (final _MobileTourTargetState target in _MobileTourTargetState.findAll(id))
      {
        if (target.holeIn(layer, clip: false)?.outerRect case final Rect whole)
        {
          readTop = math.min(readTop, whole.top);
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


    // Over the menu, unless it covers what is touched, or cuts a part read it cannot scroll out and on top
    // would show whole, or the part read from its top could not scroll its end out from under it.
    // Until the banner holds this step's text, its height is an earlier step's: it stays where it is; so too while
    // the page this step's start changed still moves.
    final Widget? built = _bannerKey.currentWidget;
    final bool high = _settling != null || (_placed && built is _TourBanner && built.step != _step)
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

    _place(high);

    final double ceiling = high ? safeTop + height + _surfaceGap : double.negativeInfinity;
    final double floor = high ? (surface?.top ?? double.infinity) - _surfaceGap : low - _surfaceGap;

    _floor = math.min(floor, viewBottom);
    _windowTop = math.max(high ? ceiling : MediaQuery.paddingOf(context).top, viewTop);
    _readTop = readTop;
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

    // A part wholly under the banner is not lit until it comes out; holes on their way head for it all the same.
    _aim = [
      ...drawn([for (final RRect hole in read) _cut(hole, ceiling, floor) ?? hole]),
      ...touched,
    ];

    return ([...drawn(cut), ...touched], touched);
  }

  // A hole the banner leaves whole is kept whatever its size; of a cut one, only a part worth seeing.
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

  // The height the banner is heading to as its text changes; until laid out once, a guess.
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

  // Where the holes are drawn this frame, between the last step's and this one's.
  List<RRect> _holesNow()
  {
    final double t = Curves.easeInOutCubic.transform(_move.value);
    final List<RRect> holes = _from.isEmpty || _aim.isEmpty || t >= 1 ? _to : _between(t, _aim);

    if (holes.isNotEmpty)
    {
      _lastLit = holes;
    }

    return holes;
  }

  // Fewer now: each goes to the nearest, so they join as they move; more now: they part from where all were.
  // While the page under this step's part moves, they head straight where it stops: there at once, if the tour
  // knows it; else the last holes ride with that page, measured a frame late.
  List<RRect> _between(double t, List<RRect> holes)
  {
    final Offset? landing = _landing;
    final List<RRect> carried = [
      for (final RRect hole in _from) landing == null ? hole.shift(_carried + _leftMoved) : hole,
    ];
    final List<RRect> to = [
      for (final RRect hole in holes) landing == null ? hole : hole.shift(landing - _carried),
    ];

    if (carried.length > to.length)
    {
      return [for (final RRect from in carried) RRect.lerp(from, _nearest(from, to), t)!];
    }

    final RRect whole = _union(carried);

    return [
      for (var i = 0; i < to.length; i++)
        RRect.lerp(carried.length == to.length ? carried[i] : whole, to[i], t)!,
    ];
  }

  RRect _nearest(RRect from, List<RRect> holes)
  {
    final Offset centre = from.outerRect.center;

    return holes.reduce((a, b) =>
        (a.outerRect.center - centre).distanceSquared <= (b.outerRect.center - centre).distanceSquared ? a : b);
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

    final bool forward = step.reached == null || step.tapMovesOn;

    // Counted as they stand now: a touch may bring a later step in; but a forward button with none there yet ends
    // the tour, so it reads «Fine» and promises none (they come on their own once the touch brings them).
    final int later = forward && _presentAfter(run.tour, _step) == null ? 0 : _countedLater;
    final int total = _path.length + later;

    final Widget banner = _TourBanner(
      key: _bannerKey,
      textKey: _bannerTextKey,
      title: total > 1 ? '${run.tour.title} · ${_path.length} di $total' : run.tour.title,
      text: step.text,
      glyphs: step.drawn,
      step: _step,
      onClose: () => _end(early: true),
      onBack: _path.length > 1 ? _back : null,
      onNext: forward ? _advance : null,
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
                onTap: step.tapMovesOn || step.tapEnds ? _onTouchTap : null,
                child: AnimatedBuilder(
                  animation: _move,
                  builder: (context, _) => CustomPaint(
                    painter: _DimPainter(
                      holes: _holesNow(),
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

  // Gone with its sheet: nothing left to scroll, or to put back.
  bool get _alive => _innerView.mounted && (_outerView?.mounted ?? true);

  // Where it was before the tour moved it.
  final double start;

  // How much further the content can move up from there; a nested body grows by what its header gives up.
  double get room
  {
    if (!_alive)
    {
      return 0;
    }

    final ScrollPosition? head = outer;

    if (!inner.hasPixels || (head != null && !head.hasPixels))
    {
      return 0;
    }

    final double body = inner.maxScrollExtent - inner.minScrollExtent;
    final double last = head == null
        ? inner.maxScrollExtent
        : head.maxScrollExtent + math.max(0, body - (head.maxScrollExtent - head.pixels));

    return math.max(0, last - start);
  }

  // How far the content has moved up now, header and body together.
  double get offset
  {
    final ScrollPosition? head = outer;

    if (!_alive || !inner.hasPixels || (head != null && !head.hasPixels))
    {
      return start;
    }

    return _offset(inner, head);
  }

  // Room to add at the view's end for the content to move up by [by], a nested header leaving or not.
  double runwayFor(double by) => by - (inner.maxScrollExtent - inner.pixels);

  _PageScroll._(this._innerView, this._outerView) : start = _offset(_innerView.position, _outerView?.position);

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

  // How far the content has moved up the screen, header and body together.
  static double _offset(ScrollPosition inner, ScrollPosition? outer)
  {
    return outer == null ? inner.pixels : outer.pixels + inner.pixels - inner.minScrollExtent;
  }

  // Where it goes, within its extent.
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

    // Either drives the nested view's coordinator: the outer up to the header's end, the inner past it.
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

  // Null: the screen less the side margins.
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

  // Told of a tap inside a hole, after what is underneath had it.
  final VoidCallback? onTap;

  const _Holes({required this.holes, this.onTap, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context)
  {
    return _RenderHoles(holes, MediaQuery.maybeGestureSettingsOf(context))..onTap = onTap;
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHoles renderObject)
  {
    renderObject
      ..holes = holes
      ..onTap = onTap
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  }
}

class _RenderHoles extends RenderProxyBox
{
  List<RRect> holes;
  VoidCallback? onTap;

  // Where each pointer that went down in a hole did, to tell a tap from a drag.
  final Map<int, Offset> _downs = {};

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
    else if (event is PointerUpEvent)
    {
      final Offset? down = _downs.remove(event.pointer);

      if (down != null && (event.position - down).distance < kTouchSlop)
      {
        onTap?.call();
      }
    }
    else if (event is PointerCancelEvent)
    {
      _downs.remove(event.pointer);
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

class _DimPainter extends CustomPainter
{
  final List<RRect> holes;
  final Color color;

  const _DimPainter({required this.holes, required this.color});

  @override
  void paint(Canvas canvas, Size size)
  {
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

    for (final RRect hole in holes)
    {
      canvas.drawRRect(hole.inflate(_rimWidth / 2), rim);
    }
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate) => !listEquals(holes, oldDelegate.holes) || color != oldDelegate.color;
}

class _TourBanner extends StatelessWidget
{
  final String title;
  final String text;
  final List<Widget Function(double size)> glyphs;
  final int step;

  // On the part whose height follows the text.
  final GlobalKey textKey;

  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  // The forward button then ends the tour.
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
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
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
                            if (next != null) _NextButton(onTap: next, last: last),
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
