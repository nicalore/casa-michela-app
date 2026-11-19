import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../platform/visual_effects.dart';
import 'theme_colours.dart';

// Redoes the whole app when the theme or the light/dark mode changes: colours are read while building and painting,
// so const widgets and painters that would otherwise keep their old ones are redone too.
class ColourThemeScope extends StatefulWidget
{
  final WidgetBuilder builder;

  const ColourThemeScope({super.key, required this.builder});

  // As long as the phone's sea takes to change.
  static const Duration fadeDuration = Duration(milliseconds: 700);

  static _ColourThemeScopeState? _inForce;

  // True while the old look's picture fades out: what fades on its own (the phone's sea) takes the new look at once.
  static bool get isFading => _inForce?._picture != null;

  // A change of colours or of light and dark: a picture of the old look fades out over the new one, so nothing snaps.
  // Completes once the new look stands alone.
  static Future<void> fadeInto(VoidCallback change)
  {
    final _ColourThemeScopeState? scope = _inForce;

    if (scope == null)
    {
      change();

      return Future.value();
    }

    return scope._fadeInto(change);
  }

  @override
  State<ColourThemeScope> createState() => _ColourThemeScopeState();
}

class _ColourThemeScopeState extends State<ColourThemeScope> with SingleTickerProviderStateMixin
{
  final GlobalKey _app = GlobalKey();

  late final AnimationController _fade;
  late final Animation<double> _before;

  ui.Image? _picture;

  @override
  void initState()
  {
    super.initState();
    // Made here, not on first use: a scope that never fades would make it in dispose, off the tree.
    _fade = AnimationController(vsync: this, duration: ColourThemeScope.fadeDuration)..addStatusListener(_faded);
    _before = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: _fade, curve: Curves.easeInOut));
    ColourThemeScope._inForce = this;
    ThemeColours.current.addListener(_changed);
    ThemeColours.dark.addListener(_changed);
  }

  @override
  void dispose()
  {
    if (ColourThemeScope._inForce == this)
    {
      ColourThemeScope._inForce = null;
    }

    ThemeColours.current.removeListener(_changed);
    ThemeColours.dark.removeListener(_changed);
    _fade.dispose();
    _picture?.dispose();
    super.dispose();
  }

  Future<void> _fadeInto(VoidCallback change)
  {
    // With the effects off the change snaps, as every other transition does.
    if (!VisualEffects.on)
    {
      change();

      return Future.value();
    }

    final Completer<void> done = Completer<void>();

    // Right after the next frame the app is painted and clean, still in its old look: picture, then change.
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      final ui.Image? picture = mounted ? _snapshot() : null;

      if (picture != null)
      {
        _picture?.dispose();
        setState(() => _picture = picture);
        _fade.forward(from: 0).orCancel.then((_) {}, onError: (_) {}).whenComplete(done.complete);
      }

      change();

      if (picture == null)
      {
        done.complete();
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();

    return done.future;
  }

  ui.Image? _snapshot()
  {
    final RenderObject? box = _app.currentContext?.findRenderObject();

    if (box is! RenderRepaintBoundary || !box.hasSize)
    {
      return null;
    }

    try
    {
      return box.toImageSync(pixelRatio: View.of(context).devicePixelRatio);
    }
    catch (_)
    {
      // No picture: the change snaps.
      return null;
    }
  }

  void _faded(AnimationStatus status)
  {
    if (status != AnimationStatus.completed || !mounted)
    {
      return;
    }

    setState(()
    {
      _picture?.dispose();
      _picture = null;
    });
  }

  void _changed()
  {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks)
    {
      SchedulerBinding.instance.addPostFrameCallback((_) => _redo());

      return;
    }

    _redo();
  }

  void _redo()
  {
    if (!mounted)
    {
      return;
    }

    setState(() {});

    void redo(Element element)
    {
      element.markNeedsBuild();

      if (element is RenderObjectElement)
      {
        element.renderObject.markNeedsPaint();
      }

      element.visitChildren(redo);
    }

    (context as Element).visitChildren(redo);
  }

  @override
  Widget build(BuildContext context)
  {
    final ui.Image? picture = _picture;

    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [
        RepaintBoundary(key: _app, child: widget.builder(context)),
        // Taps reach the new look underneath at once.
        if (picture != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RawImage(image: picture, opacity: _before, fit: BoxFit.fill),
            ),
          ),
      ],
    );
  }
}
