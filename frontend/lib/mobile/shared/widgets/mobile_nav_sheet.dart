import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../features/auth/models/me_response.dart';
import '../../layout/mobile_breakpoints.dart';
import '../navigation/mobile_destinations.dart';
import 'mobile_avatar.dart';
import 'mobile_glass_panel.dart';
import 'mobile_pill.dart';

const double _headTop = 8;
const double _grabberWidth = 38;
const double _grabberHeight = 5;
const double _grabberGap = 6;
const double _headRowHeight = 32;
const double _headBottom = 11;
const double _collapsedHeight = _headTop + _grabberHeight + _grabberGap + _headRowHeight + _headBottom;

const double _radius = 28;
const double _sidePadding = 20;
const double _bottomPadding = 20;

const double _topClearance = 24;

const Duration _hideDuration = Duration(milliseconds: 260);

const Duration _rollDuration = Duration(milliseconds: 260);

const double _rowHeight = 52;
const double _separatorHeight = 17;
const double _identityHeight = 70;

const double _scrimAlpha = 0.42;

enum MobileNavAction { changeRole, logout }

// Pages scroll under the sheet and pad their end by collapsedHeightFor.
class MobileNavSheet extends StatefulWidget
{
  final MeResponse user;
  final List<MobileDestination> destinations;
  final List<MobileDestination> userDestinations;

  final String current;

  final ValueChanged<String> onDestination;
  final ValueChanged<MobileNavAction> onAction;

  // Raised while a contextual sheet is up; set by showMobileSheet.
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);

  // Shared on tablets by the login card and the contextual sheets.
  static const double tabletWidth = 520;

  // 0 closed, 1 open, clamped; the page underneath follows it.
  static ValueListenable<double> get openness => _openness;
  static final ValueNotifier<double> _openness = ValueNotifier<double>(0);

  // The login card turns into this glass on sign-in.
  static final BoxDecoration glass = BoxDecoration(
    color: MobileGlassPanel.sheetTint.withValues(alpha: MobileGlassPanel.sheetAlpha),
    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.7))),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(_radius)),
    boxShadow: MobileGlassPanel.sheetShadow,
  );

  const MobileNavSheet({
    super.key,
    required this.user,
    required this.destinations,
    required this.userDestinations,
    required this.current,
    required this.onDestination,
    required this.onAction,
  });

  static double collapsedHeightFor(BuildContext context)
  {
    return _collapsedHeight + MediaQuery.paddingOf(context).bottom;
  }

  static Rect collapsedRectFor(BuildContext context, Size size)
  {
    final double width = MobileBreakpoints.of(context).isTablet ? tabletWidth : size.width;
    final double height = collapsedHeightFor(context);

    return Rect.fromLTWH((size.width - width) / 2, size.height - height, width, height);
  }

  @override
  State<MobileNavSheet> createState() => _MobileNavSheetState();
}

class _MobileNavSheetState extends State<MobileNavSheet> with SingleTickerProviderStateMixin
{
  // A spring stops within a tolerance of its target, never exactly on it.
  static const double _epsilon = 0.001;

  static const double _nearlyClosed = 0.01;

  // In sheet travels per second.
  static const double _flickVelocity = 1.2;

  // Critically damped: no bounce at the ends.
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
  );

  // 0 closed, 1 open.
  late final AnimationController _open = AnimationController.unbounded(vsync: this, value: 0)
    ..addListener(() => MobileNavSheet._openness.value = _open.value.clamp(0.0, 1.0));

  // Pixels between closed and open; set in build, read by the drag.
  double _travel = 0;

  @override
  void dispose()
  {
    _open.dispose();
    super.dispose();
  }

  bool get _isOpen => _open.value > 0.5;

  bool get _isClosed => _open.value <= _epsilon;

  void _settle(double target, {double velocity = 0})
  {
    _open
        .animateWith(SpringSimulation(_spring, _open.value, target, velocity))
        .whenComplete(()
    {
      // Also called when a new drag cancels the spring, which must not snap.
      if (mounted && !_open.isAnimating && (_open.value - target).abs() < 0.01)
      {
        _open.value = target;
      }
    });
  }

  void _toggle() => _settle(_isOpen ? 0 : 1);

  void _onDragUpdate(DragUpdateDetails details)
  {
    if (_travel <= 0)
    {
      return;
    }

    _open.value = (_open.value - details.primaryDelta! / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details)
  {
    if (_travel <= 0)
    {
      return;
    }

    final double velocity = -details.primaryVelocity! / _travel;

    final double target = velocity.abs() > _flickVelocity
        ? (velocity > 0 ? 1 : 0)
        : (_open.value > 0.5 ? 1 : 0);

    _settle(target, velocity: velocity);
  }

  List<MobileDestination> get _others
  {
    return [for (final d in widget.destinations) if (d.slug != widget.current) d];
  }

  List<MobileDestination> get _otherUserDestinations
  {
    return [for (final d in widget.userDestinations) if (d.slug != widget.current) d];
  }

  // Must mirror _buildRows.
  double _contentHeight(double inset)
  {
    final int userRows = _otherUserDestinations.length +
        (widget.user.availableRoles.length > 1 ? 1 : 0) +
        1;

    return _collapsedHeight +
        inset +
        _separatorHeight +
        _others.length * _rowHeight +
        _separatorHeight +
        userRows * _rowHeight +
        _separatorHeight +
        _identityHeight +
        _bottomPadding +
        inset;
  }

  void _choose(VoidCallback act)
  {
    _settle(0);
    act();
  }

  // Sign-out turns the bar back into the login card, so wait until nearly closed.
  void _chooseOnceClosed(VoidCallback act)
  {
    _settle(0);

    void check()
    {
      // A drag cancelling the spring still commits the choice.
      if (_open.value <= _nearlyClosed || !_open.isAnimating)
      {
        _open.removeListener(check);
        act();
      }
    }

    _open.addListener(check);
  }

  Widget _buildHead()
  {
    final MobileDestination current = [...widget.destinations, ...widget.userDestinations]
        .firstWhere((d) => d.slug == widget.current);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: MobileNavHead(destination: current, turn: _open),
    );
  }

  Widget _buildSeparator()
  {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: _sidePadding + 12, vertical: (_separatorHeight - 1) / 2),
      color: AppTheme.trialInk.withValues(alpha: 0.12),
    );
  }

  Widget _buildIdentity()
  {
    final MeResponse user = widget.user;

    return SizedBox(
      height: _identityHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _sidePadding + 4),
        child: Row(
          children: [
            MobileAvatar(
              firstName: user.firstName,
              lastName: user.lastName,
              imageUrl: user.profileImageUrl,
              size: 46,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    RoleLabelMapper.toLabel(user.activeRole).toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppTheme.trialInk.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRows(double inset)
  {
    final MeResponse user = widget.user;

    return [
      // Keeps the system inset under the closed head blank.
      SizedBox(height: inset),
      _buildSeparator(),
      for (final destination in _others)
        _SheetRow(
          icon: destination.icon,
          label: destination.label,
          muted: !destination.available,
          trailing: destination.available
              ? null
              : const MobilePill('In arrivo', tone: MobilePillTone.teal),
          onTap: destination.available
              ? () => _choose(() => widget.onDestination(destination.slug))
              : null,
        ),
      _buildSeparator(),
      for (final destination in _otherUserDestinations)
        _SheetRow(
          icon: destination.icon,
          label: destination.label,
          onTap: () => _choose(() => widget.onDestination(destination.slug)),
        ),
      if (user.availableRoles.length > 1)
        _SheetRow(
          icon: Icons.swap_horiz_rounded,
          label: 'Cambia ruolo',
          onTap: () => _choose(() => widget.onAction(MobileNavAction.changeRole)),
        ),
      _SheetRow(
        icon: Icons.logout_rounded,
        label: 'Logout',
        danger: true,
        onTap: () => _chooseOnceClosed(() => widget.onAction(MobileNavAction.logout)),
      ),
      _buildSeparator(),
      _buildIdentity(),
      SizedBox(height: _bottomPadding + inset),
    ];
  }

  Widget _buildScrim()
  {
    return AnimatedBuilder(
      animation: _open,
      builder: (context, _)
      {
        final double progress = _open.value.clamp(0.0, 1.0);

        return IgnorePointer(
          ignoring: _isClosed,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _settle(0),
            child: ColoredBox(
              color: AppTheme.trialDeepWater.withValues(alpha: _scrimAlpha * progress),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData media = MediaQuery.of(context);
    final double inset = media.padding.bottom;
    final bool tablet = MobileBreakpoints.of(context).isTablet;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double closed = _collapsedHeight + inset;
        final double tallest = constraints.maxHeight - media.padding.top - _topClearance;
        final double open = math.min(_contentHeight(inset), tallest);

        _travel = open - closed;

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildScrim(),
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: MobileNavSheet.hidden,
                builder: (context, away, child) => AnimatedSlide(
                  offset: Offset(0, away ? 1 : 0),
                  duration: _hideDuration,
                  curve: Curves.easeOutCubic,
                  child: child,
                ),
                child: SizedBox(
                  width: tablet ? MobileNavSheet.tabletWidth : double.infinity,
                  child: AnimatedBuilder(
                    animation: _open,
                    builder: (context, child) => PopScope(
                      canPop: _isClosed,
                      onPopInvokedWithResult: (didPop, _)
                      {
                        if (!didPop)
                        {
                          _settle(0);
                        }
                      },
                      child: SizedBox(
                        height: closed + _travel * _open.value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                    child: GestureDetector(
                      // The list wins the arena when it can scroll.
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: _Glass(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHead(),
                            Expanded(
                              child: ListView(
                                padding: EdgeInsets.zero,
                                physics: open < _contentHeight(inset)
                                    ? const ClampingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                children: _buildRows(inset),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Also drawn by the sign-in handover.
class MobileNavHead extends StatelessWidget
{
  final MobileDestination destination;
  final Animation<double> turn;

  const MobileNavHead({super.key, required this.destination, this.turn = kAlwaysDismissedAnimation});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_sidePadding + 2, _headTop, _sidePadding + 2, _headBottom),
      child: Column(
        children: [
          Container(
            width: _grabberWidth,
            height: _grabberHeight,
            decoration: BoxDecoration(
              color: AppTheme.trialOcean.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(_grabberHeight / 2),
            ),
          ),
          const SizedBox(height: _grabberGap),
          SizedBox(
            height: _headRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: _rollDuration,
                      switchInCurve: Curves.easeOutCubic,
                      // Runs in reverse on the way out, so it eases out too.
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation)
                      {
                        final bool incoming = child.key == ValueKey(destination.slug);

                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, incoming ? 1 : -1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      child: Row(
                        key: ValueKey(destination.slug),
                        children: [
                          Icon(destination.icon, size: 24, color: AppTheme.trialTealDeep),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.trialDeepWater,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: turn,
                  builder: (context, child) => Transform.rotate(
                    angle: math.pi * turn.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 26,
                    color: AppTheme.trialInk.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// No blur: it would run every frame while pages scroll underneath.
class _Glass extends StatelessWidget
{
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: MobileNavSheet.glass,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(_radius)),
        child: child,
      ),
    );
  }
}

class _SheetRow extends StatelessWidget
{
  final IconData icon;
  final String label;

  final bool muted;
  final bool danger;

  final Widget? trailing;
  final VoidCallback? onTap;

  const _SheetRow({
    required this.icon,
    required this.label,
    this.muted = false,
    this.danger = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color text = danger
        ? AppTheme.trialDanger
        : muted
            ? AppTheme.trialInk.withValues(alpha: 0.45)
            : AppTheme.trialInk;

    final Color glyph = danger
        ? AppTheme.trialDanger
        : muted
            ? AppTheme.trialTealDeep.withValues(alpha: 0.45)
            : AppTheme.trialTealDeep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
      child: Semantics(
        button: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 25, color: glyph),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
