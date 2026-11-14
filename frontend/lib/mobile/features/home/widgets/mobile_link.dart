import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const double _pressedOpacity = 0.55;
const Duration _pressFade = Duration(milliseconds: 90);

const double _seaRadius = 18;
const double _glassRadius = 14;

// What on the home leads elsewhere. Without [onTap] the child stands alone.
// [dims]: false leaves the fading under the finger to the MobileLinkTile inside.
class MobileLink extends StatefulWidget
{
  final VoidCallback? onTap;
  final bool dims;
  final Widget child;

  const MobileLink({super.key, required this.onTap, this.dims = true, required this.child});

  @override
  State<MobileLink> createState() => _MobileLinkState();
}

class _MobileLinkState extends State<MobileLink>
{
  bool _pressed = false;

  void _press(bool value)
  {
    if (_pressed != value)
    {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onTap = widget.onTap;

    if (onTap == null)
    {
      return widget.child;
    }

    final bool pressed = _pressed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: onTap,
      child: widget.dims
          ? _Fade(pressed: pressed, child: widget.child)
          : _HandedPress(pressed: pressed, child: widget.child),
    );
  }
}

class _HandedPress extends InheritedWidget
{
  final bool pressed;

  const _HandedPress({required this.pressed, required super.child});

  @override
  bool updateShouldNotify(_HandedPress oldWidget) => pressed != oldWidget.pressed;
}

class _Fade extends StatelessWidget
{
  final bool pressed;
  final Widget child;

  const _Fade({required this.pressed, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return AnimatedOpacity(opacity: pressed ? _pressedOpacity : 1, duration: _pressFade, child: child);
  }
}

// The home's sign of what opens something: a tile under it. [onSea]: straight on the backdrop, not on glass.
// Unlit it keeps only the padding, so what opens nothing stays level with what does.
class MobileLinkTile extends StatelessWidget
{
  final bool onSea;
  final bool lit;
  final EdgeInsets padding;

  // How far the tile reaches past the child's box, without moving it.
  final EdgeInsets bleed;

  final Widget child;

  const MobileLinkTile({
    super.key,
    required this.child,
    this.onSea = false,
    this.lit = true,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 10, 8),
    this.bleed = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget padded = Padding(padding: padding, child: child);

    if (!lit)
    {
      return padded;
    }

    final bool pressed = context.dependOnInheritedWidgetOfExactType<_HandedPress>()?.pressed ?? false;

    return _Fade(
      pressed: pressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -bleed.left,
            right: -bleed.right,
            top: -bleed.top,
            bottom: -bleed.bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: onSea ? Colors.white.withValues(alpha: 0.09) : AppTheme.trialInk.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(onSea ? _seaRadius : _glassRadius),
                border: onSea ? Border.all(color: Colors.white.withValues(alpha: 0.16)) : null,
              ),
            ),
          ),
          padded,
        ],
      ),
    );
  }
}
