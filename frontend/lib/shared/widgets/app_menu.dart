import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import 'app_tooltip.dart';
import 'close_on_resize.dart';
import 'desktop_tour.dart';
import 'overflow_tooltip_text.dart';

const double _itemRadius = 10;
const double _markHeight = 20;
const double _leadingSpace = 14;
const double _iconSize = 18;
const double _iconTextGap = 10;

const Duration _hoverFade = Duration(milliseconds: 150);

const Duration _openIn = Duration(milliseconds: 180);
const double _openRise = 8;

// The least room kept between a menu and the window's sides.
const double _windowMargin = 8;

class AppMenuCard extends StatelessWidget
{
  final double width;
  final List<Widget> children;

  const AppMenuCard({super.key, required this.width, required this.children});

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class AppMenuHeading extends StatelessWidget
{
  final String text;

  const AppMenuHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
      ),
    );
  }
}

class AppMenuItem extends StatefulWidget
{
  final IconData? icon;

  // In the icon's place, as wide as it lays out (a face).
  final Widget? leading;

  final String text;
  final Color color;

  // Null with [enabled] false: listed, not built yet.
  final VoidCallback? onTap;

  // The gold mark stays without the pointer: the open page, or something waiting there.
  final bool marked;

  final bool current;

  final bool enabled;

  final Widget? trailing;

  final bool dense;

  const AppMenuItem({
    super.key,
    this.icon,
    this.leading,
    required this.text,
    this.color = AppTheme.trialTealDeep,
    required this.onTap,
    this.marked = false,
    this.current = false,
    this.enabled = true,
    this.trailing,
    this.dense = false,
  });

  @override
  State<AppMenuItem> createState() => _AppMenuItemState();
}

class _AppMenuItemState extends State<AppMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool enabled = widget.enabled && widget.onTap != null;
    final Color color = enabled ? widget.color : AppTheme.trialMutedText.withValues(alpha: 0.55);
    final IconData? icon = widget.icon;
    final bool lit = enabled && (_hover || widget.marked || widget.current);

    final Widget entry = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.dense ? 10 : 12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: _hoverFade,
            curve: Curves.easeOut,
            width: 2,
            height: lit ? _markHeight : 0,
            decoration: BoxDecoration(
              color: AppTheme.trialGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: _leadingSpace),
              if (icon != null) ...[
                SizedBox(width: _iconSize, child: Icon(icon, size: _iconSize, color: color)),
                const SizedBox(width: _iconTextGap),
              ],
              if (widget.leading case final Widget leading) ...[
                leading,
                const SizedBox(width: _iconTextGap),
              ],
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.current ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (widget.trailing case final Widget trailing) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );

    if (!enabled)
    {
      return AppTooltip(
        waitDuration: const Duration(milliseconds: 400),
        message: 'In arrivo',
        child: entry,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(_itemRadius),
        child: entry,
      ),
    );
  }
}

// A menu hung under the thing that opens it; a click outside or Esc closes it.
class AppAnchoredMenu extends StatefulWidget
{
  final Widget Function(BuildContext context, bool open, VoidCallback toggle) builder;

  final Widget Function(BuildContext context, VoidCallback close) menu;

  // The trigger's corner the menu hangs from, and the menu's own matching corner.
  final bool alignEnd;

  final double gap;

  const AppAnchoredMenu({
    super.key,
    required this.builder,
    required this.menu,
    this.alignEnd = false,
    this.gap = 10,
  });

  @override
  State<AppAnchoredMenu> createState() => _AppAnchoredMenuState();
}

class _AppAnchoredMenuState extends State<AppAnchoredMenu> with SingleTickerProviderStateMixin, CloseOnResize
{
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  // Built in initState: a late controller first touched in dispose() would be created there.
  late final AnimationController _reveal;
  late final Animation<double> _curve;

  // Nudged sideways once laid out, so the whole menu stays inside the window.
  final GlobalKey _menuKey = GlobalKey();
  double _shift = 0;

  bool get _isOpen => _portal.isShowing && _reveal.status != AnimationStatus.reverse;

  @override
  bool get menuShown => _isOpen;

  @override
  void closeMenuForResize() => _close();

  @override
  void initState()
  {
    super.initState();

    _reveal = AnimationController(vsync: this, duration: _openIn);
    _curve = CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose()
  {
    _reveal.dispose();
    super.dispose();
  }

  void _toggle()
  {
    if (_isOpen)
    {
      _close();

      return;
    }

    _shift = 0;
    setState(_portal.show);

    if (VisualEffects.on)
    {
      _reveal.forward();
    }
    else
    {
      _reveal.value = 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _keepInside());
  }

  void _keepInside()
  {
    final RenderObject? menu = _menuKey.currentContext?.findRenderObject();

    if (!mounted || menu is! RenderBox || !menu.hasSize)
    {
      return;
    }

    final double window = MediaQuery.sizeOf(context).width;
    final Rect rect = menu.localToGlobal(Offset.zero) & menu.size;
    final double over = rect.right - (window - _windowMargin);
    final double under = _windowMargin - rect.left;

    if (over > 0 || under > 0)
    {
      setState(() => _shift += under > 0 ? under : -over);
    }
  }

  Future<void> _close() async
  {
    if (!_isOpen)
    {
      return;
    }

    setState(() {});

    if (VisualEffects.on)
    {
      await _reveal.reverse();
    }
    else
    {
      _reveal.value = 0;
    }

    // Reopened while leaving: it stays.
    if (mounted && _reveal.isDismissed)
    {
      setState(_portal.hide);
    }
  }

  Widget _buildMenu(BuildContext context)
  {
    final bool end = widget.alignEnd;

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: end ? Alignment.bottomRight : Alignment.bottomLeft,
        followerAnchor: end ? Alignment.topRight : Alignment.topLeft,
        offset: Offset(_shift, widget.gap),
        child: TapRegion(
          groupId: _link,
          // A tour over the menu takes the clicks around it.
          onTapOutside: (_)
          {
            if (!isDesktopTourShown)
            {
              _close();
            }
          },
          child: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
            child: Focus(
              autofocus: true,
              child: FadeTransition(
                opacity: _curve,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_openRise * (1 - _curve.value)),
                    child: child,
                  ),
                  child: RepaintBoundary(key: _menuKey, child: widget.menu(context, _close)),
                ),
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
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildMenu,
        child: TapRegion(
          groupId: _link,
          child: widget.builder(context, _isOpen, _toggle),
        ),
      ),
    );
  }
}
