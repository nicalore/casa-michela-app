import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_top_bar.dart';
import '../../../shared/widgets/descender_room.dart';
import '../notification_board.dart';
import '../notification_item.dart';
import '../notification_look.dart';

const double _width = 440;
const double _gapBelowBar = 16;
const double _radius = 18;
const double _iconSize = 40;
const double _lineHeight = 3;
const double _rimWidth = 2;
const double _closeSize = 28;

const Duration _stay = Duration(seconds: 8);
const Duration _slide = Duration(milliseconds: 320);
const Duration _hoverFade = Duration(milliseconds: 150);

const List<BoxShadow> _shadows = [
  BoxShadow(color: Color(0x330B3350), offset: Offset(0, 14), blurRadius: 34),
  BoxShadow(color: Color(0x140B3350), offset: Offset(0, 2), blurRadius: 6),
];

// A notification the system did not show, in the corner below the bar of every desktop page.
class NotificationToastLayer extends StatefulWidget
{
  const NotificationToastLayer({super.key});

  @override
  State<NotificationToastLayer> createState() => _NotificationToastLayerState();
}

class _NotificationToastLayerState extends State<NotificationToastLayer> with TickerProviderStateMixin
{
  final NotificationBoard _board = NotificationBoard.instance;

  late final AnimationController _presence;
  late final AnimationController _countdown;
  late final Animation<double> _eased;

  NotificationItem? _item;
  bool _hover = false;

  // Bumped on every change, so an exit finishing late leaves a newer one alone.
  int _turn = 0;

  @override
  void initState()
  {
    super.initState();
    _presence = AnimationController(vsync: this, duration: _slide);
    _countdown = AnimationController(vsync: this, duration: _stay)..addStatusListener(_onCountdown);
    _eased = CurvedAnimation(parent: _presence, curve: Curves.easeInOutCubic);
    _board.arrival.addListener(_onArrival);
    _board.addListener(_onBoard);
  }

  @override
  void dispose()
  {
    _board.arrival.removeListener(_onArrival);
    _board.removeListener(_onBoard);
    _presence.dispose();
    _countdown.dispose();
    super.dispose();
  }

  void _onArrival()
  {
    final NotificationItem? item = _board.arrival.value;

    if (item == null)
    {
      unawaited(_leave());

      return;
    }

    unawaited(_show(item));
  }

  // Read here or elsewhere, or withdrawn: no longer news.
  void _onBoard()
  {
    final NotificationItem? item = _item;

    if (item == null)
    {
      return;
    }

    final bool unread = _board.items?.any((other) => other.id == item.id && !other.read) ?? false;

    if (!unread)
    {
      unawaited(_leave());
    }
  }

  void _onCountdown(AnimationStatus status)
  {
    if (status == AnimationStatus.completed)
    {
      unawaited(_leave());
    }
  }

  // A newer one takes the place of the one on show.
  Future<void> _show(NotificationItem item) async
  {
    final int turn = ++_turn;

    _presence.duration = VisualEffects.on ? _slide : VisualEffects.plainFade;

    if (_item != null && !await _hidden())
    {
      return;
    }

    if (!mounted || turn != _turn)
    {
      return;
    }

    setState(()
    {
      _item = item;
      _hover = false;
    });

    _countdown.forward(from: 0);
    _presence.forward(from: 0);
  }

  Future<void> _leave() async
  {
    if (_item == null)
    {
      return;
    }

    final int turn = ++_turn;

    _countdown.stop();

    if (!await _hidden() || !mounted || turn != _turn)
    {
      return;
    }

    setState(() => _item = null);
  }

  // False when a newer turn interrupted the way out.
  Future<bool> _hidden() async
  {
    try
    {
      await _presence.reverse().orCancel;

      return true;
    }
    on TickerCanceled
    {
      return false;
    }
  }

  void _open(NotificationItem item)
  {
    unawaited(_leave());
    unawaited(_board.open(item));
  }

  void _hovering(bool hover)
  {
    setState(() => _hover = hover);

    if (hover)
    {
      _countdown.stop();
    }
    else if (_item != null && _presence.status != AnimationStatus.reverse)
    {
      _countdown.forward();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final NotificationItem? item = _item;

    if (item == null)
    {
      return const SizedBox.shrink();
    }

    final Size window = MediaQuery.sizeOf(context);
    final AppWindowSize size = AppBreakpoints.fromSize(window);
    final double margin = AppBreakpoints.pageMargin(size);
    final double width = math.min(_width, window.width - 2 * margin);
    final bool effects = VisualEffects.of(context);

    return Stack(
      children: [
        Positioned(
          top: AppTopBar.bottomFor(size) + _gapBelowBar,
          right: margin,
          width: width,
          child: AnimatedBuilder(
            animation: _eased,
            // Above the pages' own Material: text needs one of its own.
            child: RepaintBoundary(
              child: Material(type: MaterialType.transparency, child: _card(item, showLine: effects)),
            ),
            builder: (context, child)
            {
              if (!effects)
              {
                return Opacity(opacity: _presence.value, child: child);
              }

              // In from the window's right edge, shadow and all.
              return Transform.translate(
                offset: Offset((1 - _eased.value) * (width + margin + 40), 0),
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _card(NotificationItem item, {required bool showLine})
  {
    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationIcon(kind: item.kind, unread: true, size: _iconSize, surface: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DescenderRoom(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: AppTheme.trialInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  DescenderRoom(
                    child: Text(
                      item.desktopBody,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CloseButton(onTap: () => unawaited(_leave())),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hovering(true),
      onExit: (_) => _hovering(false),
      child: GestureDetector(
        onTap: () => _open(item),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _hover ? 1 : 0),
          duration: _hoverFade,
          curve: Curves.easeOut,
          builder: (context, lit, child) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: _shadows,
            ),
            // Gold kept at full colour, only its alpha fading, as on the card's rows.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _rimWidth),
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Stack(
              children: [
                content,
                if (showLine)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _lineHeight,
                    child: AnimatedBuilder(
                      animation: _countdown,
                      builder: (context, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1 - _countdown.value,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.trialGold,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(_lineHeight)),
                          ),
                        ),
                      ),
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

class _CloseButton extends StatefulWidget
{
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _hoverFade,
          curve: Curves.easeOut,
          width: _closeSize,
          height: _closeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hover ? AppTheme.trialPaper : AppTheme.trialPaper.withValues(alpha: 0),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: _hover ? AppTheme.trialInk : AppTheme.trialMutedText,
          ),
        ),
      ),
    );
  }
}
