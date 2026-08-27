import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'carousel_arrow_button.dart';
import 'overflow_tooltip_text.dart';

const double _pieceGap = 26;
const double _windowMargin = 16;

const double _staggerStep = 0.11;
const double _staggerSpan = 0.54;

const double _pieceScale = 0.92;

const double _shadowRoom = 12;

const double _pillRadius = 28;
const double _pillPadding = 28;

const double _closeSize = 44;

const double _titleRowRoom = 460;

class AppDialogStack extends StatelessWidget
{
  final String eyebrow;
  final String title;

  final Widget? leading;

  final Widget? subtitle;

  final List<Widget> children;

  final Widget? footer;

  final double maxWidth;

  final Alignment alignment;

  final bool showClose;

  final VoidCallback? onClose;

  final bool fillLast;

  const AppDialogStack({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.leading,
    this.subtitle,
    this.footer,
    this.maxWidth = 720,
    this.alignment = Alignment.center,
    this.showClose = true,
    this.onClose,
    this.fillLast = false,
  });

  Widget _buildTitleRow(BuildContext context)
  {
    final Widget heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textWidthBasis: TextWidthBasis.longestLine,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 2),
        OverflowTooltipText(
          text: title,
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOcean,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          subtitle!,
        ],
      ],
    );

    final bool tight = MediaQuery.sizeOf(context).width < _titleRowRoom;
    final bool besideAFace = leading != null && !tight;

    final Widget pill = AppDialogPill(
      padding: besideAFace
          ? const EdgeInsets.fromLTRB(22, 20, 36, 20)
          : EdgeInsets.fromLTRB(tight ? 20 : 36, 22, tight ? 20 : 36, 24),
      child: besideAFace
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading!,
                const SizedBox(width: 18),
                Flexible(child: heading),
              ],
            )
          : heading,
    );

    if (!showClose)
    {
      return pill;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: tight
              ? const EdgeInsets.only(right: _closeSize + 8)
              : const EdgeInsets.symmetric(horizontal: _closeSize + 16),
          child: pill,
        ),
        Positioned(
          right: 0,
          child: CarouselArrowButton(
            icon: Icons.close_rounded,
            hoverColor: AppTheme.trialGoldSurface,
            hoverIconColor: AppTheme.trialTealDeep,
            hoverBorderColor: AppTheme.trialGold,
            onTap: onClose ?? () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(double width)
  {
    if (!fillLast)
    {
      return [
        Flexible(
          child: _atMost(width, SingleChildScrollView(
            // The default barrier is opaque and would swallow taps in the gaps, which
            // must reach the barrier.
            hitTestBehavior: HitTestBehavior.deferToChild,
            padding: const EdgeInsets.all(_shadowRoom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: _pieceGap),
                  AppDialogPiece(index: i + 1, child: children[i]),
                ],
              ],
            ),
          )),
        ),
      ];
    }

    return [
      for (var i = 0; i < children.length - 1; i++) ...[
        if (i > 0) const SizedBox(height: _pieceGap),
        _atMost(width, AppDialogPiece(index: i + 1, child: children[i])),
      ],
      if (children.length > 1) const SizedBox(height: _pieceGap),
      Flexible(
        fit: FlexFit.loose,
        child: _atMost(
          width,
          AppDialogPiece(index: children.length, child: children.last),
        ),
      ),
    ];
  }

  static Widget _atMost(double width, Widget child)
  {
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child);
  }

  @override
  Widget build(BuildContext context)
  {
    final window = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    final double room = window.width - 2 * _windowMargin;
    final double pieceWidth = math.min(maxWidth, room);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: _WhileItIsThere(
        // Full screen on purpose: the BackdropFilter of showBlurredDialog sizes
        // itself to its child.
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: room,
              maxHeight: window.height - keyboard - 2 * _windowMargin,
            ),
            // Load-bearing twice: text outside a Material wears the yellow underline, and
            // a transparent Material, unlike an opaque one, does not answer the hit test.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppDialogPiece(index: 0, child: _buildTitleRow(context)),
                  const SizedBox(height: _pieceGap),
                  ..._buildBody(pieceWidth),
                  if (footer != null) ...[
                    const SizedBox(height: _pieceGap),
                    _atMost(
                      pieceWidth,
                      AppDialogPiece(index: children.length + 1, child: footer!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhileItIsThere extends StatelessWidget
{
  final Widget child;

  const _WhileItIsThere({required this.child});

  @override
  Widget build(BuildContext context)
  {
    final ModalRoute<dynamic>? window = ModalRoute.of(context);

    if (window == null)
    {
      return child;
    }

    return AnimatedBuilder(
      animation: window.animation ?? kAlwaysCompleteAnimation,
      builder: (context, _) => IgnorePointer(
        ignoring: !window.isCurrent,
        child: child,
      ),
    );
  }
}

class AppDialogPiece extends StatelessWidget
{
  final int index;
  final Widget child;

  final bool named;

  const AppDialogPiece({
    super.key,
    required this.index,
    required this.child,
    this.named = true,
  });

  @override
  Widget build(BuildContext context)
  {
    final route = ModalRoute.of(context)?.animation;

    if (route == null)
    {
      return child;
    }

    final start = (index * _staggerStep).clamp(0.0, 1.0 - _staggerSpan);

    final animation = CurvedAnimation(
      parent: route,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    final pop = CurvedAnimation(
      parent: route,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutBack),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    return FadeTransition(
      key: named ? ValueKey('appDialogPiece$index') : null,
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: _pieceScale, end: 1).animate(pop),
        child: child,
      ),
    );
  }
}

class AppDialogPill extends StatelessWidget
{
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  final bool expand;

  final List<BoxShadow> shadow;

  const AppDialogPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(_pillPadding),
    this.radius = _pillRadius,
    this.shadow = AppTheme.dialogShadow,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final borderRadius = BorderRadius.circular(radius);

    final Widget piece = Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: Material(
        color: Colors.white,
        borderRadius: borderRadius,
        elevation: 0,
        child: Padding(padding: padding, child: child),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: piece) : piece;
  }
}
