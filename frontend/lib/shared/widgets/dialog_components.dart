import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _dialogBlurSigma = 8.0;

// Logical pixels per snapshot pixel: on web toImageSync reads the pixels back
// from the GPU, and under a blur this wide a quarter scale loses nothing visible.
const double _snapshotScale = 0.25;

const Color _dialogTint = Colors.black;
const double _dialogTintOpacity = 0.15;

// Clamped like the snapshot's blur, so swapping one for the other leaves no seam at the edges.
final ui.ImageFilter _liveBlur = ui.ImageFilter.blur(
  sigmaX: _dialogBlurSigma,
  sigmaY: _dialogBlurSigma,
  tileMode: ui.TileMode.clamp,
);

// Wraps everything a dialog covers: its last frame is what the dialog shows blurred.
final GlobalKey dialogBackdropKey = GlobalKey(debugLabel: 'dialogBackdrop');

// True from a dialog's push until it is gone, closing animation included.
bool get isBlurredDialogOpen => _BlurredDialogRoute._open > 0;

Future<T?> showBlurredDialog<T>({
  required BuildContext context,
  required String barrierLabel,
  required WidgetBuilder builder,
  // Off for every dialog: the paper between floating pieces counts as "outside",
  // and a tap landing there must not throw the edit away.
  bool barrierDismissible = false,
  Duration transitionDuration = const Duration(milliseconds: 560),
})
{
  return Navigator.of(context, rootNavigator: true).push<T>(
    _BlurredDialogRoute<T>(
      builder: builder,
      label: barrierLabel,
      dismissible: barrierDismissible,
      duration: transitionDuration,
    ),
  );
}

// A popup that turns opaque once its snapshot stands in for the routes below:
// the framework then stops painting and ticking them.
class _BlurredDialogRoute<T> extends PopupRoute<T>
{
  final WidgetBuilder builder;
  final String label;
  final bool dismissible;
  final Duration duration;

  bool _covers = false;

  static int _open = 0;

  _BlurredDialogRoute({
    required this.builder,
    required this.label,
    required this.dismissible,
    required this.duration,
  });

  @override
  void install()
  {
    super.install();
    _open++;
  }

  @override
  void dispose()
  {
    _open--;
    super.dispose();
  }

  // The tint is painted with the backdrop, over the snapshot rather than under it.
  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String get barrierLabel => label;

  @override
  Duration get transitionDuration => duration;

  @override
  bool get opaque => _covers;

  void coverBelow()
  {
    _covers = true;

    // The framework applies opaque only when the transition settles; here it may have already.
    if (animation?.isCompleted ?? false)
    {
      overlayEntries.first.opaque = true;
    }

    changedInternalState();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  )
  {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  )
  {
    return _DialogBackdrop(route: this, animation: animation, child: child);
  }
}

// The window behind a dialog, rasterised and blurred once: a texture per frame
// instead of a full-window BackdropFilter on every frame the dialog is open.
class _Backdrop
{
  final ui.Image image;

  _Backdrop(this.image);

  static _Backdrop? capture()
  {
    final RenderObject? boundary = dialogBackdropKey.currentContext?.findRenderObject();

    if (boundary is! RenderRepaintBoundary || !boundary.hasSize)
    {
      return null;
    }

    try
    {
      final ui.Image sharp = boundary.toImageSync(pixelRatio: _snapshotScale);
      final ui.Image blurred = _blur(sharp, _dialogBlurSigma * _snapshotScale);

      sharp.dispose();

      return _Backdrop(blurred);
    }
    catch (_)
    {
      // No snapshot: the dialog falls back to a live BackdropFilter.
      return null;
    }
  }

  static ui.Image _blur(ui.Image source, double sigma)
  {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.drawImage(
      source,
      Offset.zero,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.clamp,
        ),
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image blurred = picture.toImageSync(source.width, source.height);

    picture.dispose();

    return blurred;
  }

  void dispose() => image.dispose();
}

class _DialogBackdrop extends StatefulWidget
{
  final _BlurredDialogRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  const _DialogBackdrop({
    required this.route,
    required this.animation,
    required this.child,
  });

  @override
  State<_DialogBackdrop> createState() => _DialogBackdropState();
}

// Outlives the transition ticks and frees the snapshot with the route.
class _DialogBackdropState extends State<_DialogBackdrop>
{
  // Share of the opening over which the snapshot fades in. Quick on purpose:
  // the window behind is gone before the hover of the button that opened the
  // dialog visibly fades, so the button stays lit under the blur instead of
  // going out and coming back with the snapshot.
  static const double _fadeInShare = 0.2;

  // Share of the closing, at its end, over which the snapshot fades out: the
  // length of a button's hover animation, so the button it froze lit goes out
  // as it would on its own, and the blur leaves with the last piece.
  static const double _fadeOutShare = 0.32;

  _Backdrop? _backdrop;

  late CurvedAnimation _fade = _fadeOf(widget.animation);

  @override
  void initState()
  {
    super.initState();
    _captureAfterFrame();
  }

  @override
  void didUpdateWidget(_DialogBackdrop oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.animation, widget.animation))
    {
      _fade.dispose();
      _fade = _fadeOf(widget.animation);
    }
  }

  @override
  void dispose()
  {
    _fade.dispose();
    _backdrop?.dispose();
    super.dispose();
  }

  // Quick in at the start of the opening, quick out at the end of the closing.
  static CurvedAnimation _fadeOf(Animation<double> animation)
  {
    return CurvedAnimation(
      parent: animation,
      curve: const Interval(0, _fadeInShare, curve: Curves.easeOut),
      reverseCurve: const Interval(0, _fadeOutShare, curve: Curves.easeIn),
    );
  }

  // Right after the first frame, which shows nothing of the dialog yet: the
  // window behind stays as it was at the tap, and every frame of the opening
  // is a cross-fade over a texture rather than a live blur.
  void _captureAfterFrame()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      final RenderObject? veil = mounted ? context.findRenderObject() : null;

      if (_backdrop != null || veil is! _RenderVeil)
      {
        return;
      }

      final _Backdrop? backdrop = veil.paintedOut(_Backdrop.capture);

      if (backdrop == null)
      {
        return;
      }

      setState(() => _backdrop = backdrop);
      widget.route.coverBelow();
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final _Backdrop? backdrop = _backdrop;
    final double progress = widget.animation.value;
    final double fade = _fade.value;

    // Closing over another dialog: that one is leaving underneath, piece by
    // piece, which the snapshot would freeze. The blur goes live for these
    // frames, ramping down as it always did.
    final bool liveClose =
        widget.animation.status == AnimationStatus.reverse && _BlurredDialogRoute._open > 1;

    // The barrier's own easing, painted here so the tint sits on the snapshot.
    final double tint = _dialogTintOpacity * Curves.ease.transform(progress);

    return _Veil(
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: switch (backdrop)
            {
              // Invisible at the start, and a BackdropFilter costs the whole window even then.
              null when fade == 0 => const SizedBox.expand(),
              // The blurred window faded in over the sharp one, as the snapshot is.
              null => BackdropFilter(
                  filter: ui.ImageFilter.compose(
                    outer: ColorFilter.mode(Color.fromRGBO(0, 0, 0, fade), BlendMode.dstIn),
                    inner: _liveBlur,
                  ),
                  child: const SizedBox.expand(),
                ),
              _ when liveClose => BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _dialogBlurSigma * progress,
                    sigmaY: _dialogBlurSigma * progress,
                    tileMode: ui.TileMode.clamp,
                  ),
                  child: const SizedBox.expand(),
                ),
              _ => RawImage(
                  image: backdrop.image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                  opacity: _fade,
                ),
            },
          ),
          IgnorePointer(
            child: ColoredBox(color: _dialogTint.withValues(alpha: tint)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

// Leaves the dialog out of one offscreen repaint, so a capture sees only the window behind it.
class _Veil extends SingleChildRenderObjectWidget
{
  const _Veil({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderVeil();
}

class _RenderVeil extends RenderProxyBox
{
  bool _out = false;

  T paintedOut<T>(T Function() capture)
  {
    final PipelineOwner pipeline = owner!;

    _repaint(pipeline, out: true);

    try
    {
      return capture();
    }
    finally
    {
      _repaint(pipeline, out: false);
    }
  }

  // Updates the layers without compositing a frame: the screen never shows the dialog gone.
  void _repaint(PipelineOwner pipeline, {required bool out})
  {
    _out = out;
    markNeedsPaint();
    pipeline.flushPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    if (!_out)
    {
      super.paint(context, offset);
    }
  }
}

class ResponsiveDialogButtonsRow extends StatelessWidget
{
  static const double _breakpoint = 460;
  static const double _defaultStackedWidth = 240;

  final Widget secondaryButton;
  final Widget primaryButton;

  final double? stackedButtonWidth;

  const ResponsiveDialogButtonsRow({
    required this.secondaryButton,
    required this.primaryButton,
    this.stackedButtonWidth = _defaultStackedWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          final width = stackedButtonWidth;

          Widget sized(Widget button)
          {
            return width == null ? button : SizedBox(width: width, child: button);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                width == null ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            children: [
              sized(primaryButton),
              const SizedBox(height: 16),
              sized(secondaryButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: secondaryButton),
            const SizedBox(width: 16),
            Expanded(child: primaryButton),
          ],
        );
      },
    );
  }
}

class OutlinedActionButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const OutlinedActionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  @override
  State<OutlinedActionButton> createState() => _OutlinedActionButtonState();
}

class _OutlinedActionButtonState extends State<OutlinedActionButton>
{
  static const Duration _animationDuration = Duration(milliseconds: 250);

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_)
        {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: _animationDuration,
          curve: Curves.easeOutQuint,
          child: AnimatedContainer(
            duration: _animationDuration,
            curve: Curves.easeOutQuint,
            height: 56,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.surfaceHover : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
