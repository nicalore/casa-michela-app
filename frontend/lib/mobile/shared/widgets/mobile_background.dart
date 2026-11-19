import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colour_theme_scope.dart';
import '../../../core/theme/dark_colours.dart';
import '../../../core/theme/theme_colours.dart';
import '../mobile_palette.dart';

// The sea passes from one theme's colours to the next, and between light and dark, instead of snapping
// (at sign-in; a choice in the settings fades the whole app instead).
const Duration _themeChange = Duration(milliseconds: 700);

class MobileBackground extends StatefulWidget
{
  final Widget? child;

  const MobileBackground({super.key, this.child});

  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  State<MobileBackground> createState() => _MobileBackgroundState();
}

class _MobileBackgroundState extends State<MobileBackground> with SingleTickerProviderStateMixin
{
  late final AnimationController _change = AnimationController(vsync: this, duration: _themeChange, value: 1);
  late final Animation<double> _progress = CurvedAnimation(parent: _change, curve: Curves.easeInOut);

  _Look _from = _lookInForce();
  _Look _to = _lookInForce();

  @override
  void initState()
  {
    super.initState();
    ThemeColours.current.addListener(_themeChanged);
    ThemeColours.dark.addListener(_themeChanged);
  }

  @override
  void dispose()
  {
    ThemeColours.current.removeListener(_themeChanged);
    ThemeColours.dark.removeListener(_themeChanged);
    _change.dispose();
    super.dispose();
  }

  void _themeChanged()
  {
    final _Look next = _lookInForce();

    if (next == _to)
    {
      return;
    }

    // A choice in the settings fades under the app's own picture: a second fade here would lag behind it.
    if (ColourThemeScope.isFading)
    {
      setState(()
      {
        _from = next;
        _to = next;
      });
      _change.value = 1;

      return;
    }

    // Changed again halfway: it sets off from the nearer of the two.
    setState(()
    {
      _from = _change.value < 0.5 ? _from : _to;
      _to = next;
    });

    _change.forward(from: 0);
  }

  @override
  Widget build(BuildContext context)
  {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MobileBackground.overlayStyle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _BackdropPainter(from: _from, to: _to, progress: _progress)),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}

// A colour theme in light or dark.
typedef _Look = ({ColourTheme theme, bool dark});

_Look _lookInForce() => (theme: ThemeColours.current.value, dark: ThemeColours.dark.value);

class _BackdropPainter extends CustomPainter
{
  final List<Color> _fromColours;
  final List<Color> _toColours;
  final Animation<double> progress;

  _BackdropPainter({required _Look from, required _Look to, required this.progress})
    : _fromColours = ThemeColours.painted(from.theme, _colours, dark: from.dark),
      _toColours = ThemeColours.painted(to.theme, _colours, dark: to.dark),
      super(repaint: progress);

  // The sea's four stops, then the gold and the violet glows; in the dark the sea sinks toward the night
  // and the glows fade, gold turning muddy on near-black.
  static List<Color> _colours()
  {
    final bool dark = ThemeColours.isDark;
    final Color night = ThemeColours.darkSea;

    Color sea(Color colour, double share) => dark ? Color.lerp(colour, night, share)! : colour;

    return [
      sea(MobilePalette.seaTop, darkSeaTopMix),
      sea(AppTheme.trialTealDeep, darkSeaMix),
      sea(AppTheme.trialSeaGreen, darkSeaMix),
      sea(AppTheme.trialLagoon, darkSeaMix),
      AppTheme.trialGold.withValues(alpha: dark ? darkGoldGlowAlpha : 0.25),
      AppTheme.trialViolet.withValues(alpha: dark ? darkVioletGlowAlpha : 0.18),
    ];
  }

  // CSS angle: 0 points up, growing clockwise.
  static const double _angleDegrees = 160;

  static const List<double> _seaStops = [0.0, 0.45, 0.75, 1.0];

  @override
  void paint(Canvas canvas, Size size)
  {
    final rect = Offset.zero & size;
    final List<Color> colours = [
      for (var i = 0; i < _toColours.length; i++) Color.lerp(_fromColours[i], _toColours[i], progress.value)!,
    ];

    canvas.drawRect(rect, Paint()..shader = _sea(size, colours.sublist(0, 4)).createShader(rect));

    _paintGlow(
      canvas,
      center: Offset(size.width * 0.85, -size.height * 0.10),
      radiusX: 1200,
      radiusY: 800,
      color: colours[4],
      fadeAt: 0.60,
    );

    _paintGlow(
      canvas,
      center: Offset(-size.width * 0.10, size.height * 1.10),
      radiusX: 1000,
      radiusY: 700,
      color: colours[5],
      fadeAt: 0.55,
    );
  }

  // Ends land on the corners as in CSS linear-gradient, so the tilt holds on any aspect ratio.
  LinearGradient _sea(Size size, List<Color> seaColours)
  {
    final radians = _angleDegrees * math.pi / 180;
    final dx = math.sin(radians);
    final dy = -math.cos(radians);
    final length = (size.width * dx).abs() + (size.height * dy).abs();

    final end = Alignment(dx * length / size.width, dy * length / size.height);

    return LinearGradient(begin: -end, end: end, colors: seaColours, stops: _seaStops);
  }

  // Fading to the tint at zero alpha, not to black, keeps the mid-tones from greying.
  void _paintGlow(
    Canvas canvas, {
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double fadeAt,
  })
  {
    final shader = ui.Gradient.radial(
      Offset.zero,
      radiusX,
      [color, color.withValues(alpha: 0)],
      [0.0, fadeAt],
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, radiusY / radiusX);
    canvas.drawCircle(Offset.zero, radiusX, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      !listEquals(oldDelegate._fromColours, _fromColours) || !listEquals(oldDelegate._toColours, _toColours);
}
