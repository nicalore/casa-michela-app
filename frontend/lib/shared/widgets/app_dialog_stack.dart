import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import 'carousel_arrow_button.dart';
import 'dialog_density.dart';
import 'overflow_tooltip_text.dart';
import 'scroll_edge_fade.dart';

const double _pieceGap = 26;
const double _densePieceGap = 16;
const double _windowMargin = 16;
const double _denseWindowMargin = 12;

const double _staggerStep = 0.11;
const double _staggerSpan = 0.54;

const double _pieceScale = 0.92;

const double _shadowRoom = 12;

const double _pillRadius = 28;
const double _densePillRadius = 22;
const double kDialogPillPadding = 28;
const double kDenseDialogPillPadding = 20;

const double _closeSize = 44;

const double _arrowsGap = 12;

// A wizard's arrows in the footer, as the carousel hands them over.
const double _handedArrowSize = 44;

// Beside the buttons while these keep this much room; else on a row of their own above them.
const double _buttonsBesideArrowsLeast = 300;
const double _denseCloseSize = 40;

// A face beside the title is drawn at this height in a dense dialog.
const double _denseLeadingHeight = 56;

const double _titleRowRoom = 460;

class AppDialogStack extends StatelessWidget
{
  final String eyebrow;
  final String title;

  final Widget? leading;

  final Widget? subtitle;

  // Takes the place of eyebrow, title, leading and subtitle in the top pill.
  final Widget? header;

  final List<Widget> children;

  final Widget? footer;

  final double maxWidth;

  final Alignment alignment;

  final bool showClose;

  final VoidCallback? onClose;

  final bool fillLast;

  // A title too long for the pill shrinks to fit instead of trailing off.
  final bool shrinkTitle;

  const AppDialogStack({
    super.key,
    this.eyebrow = '',
    this.title = '',
    required this.children,
    this.leading,
    this.subtitle,
    this.header,
    this.footer,
    this.maxWidth = 720,
    this.alignment = Alignment.center,
    this.showClose = true,
    this.onClose,
    this.fillLast = false,
    this.shrinkTitle = false,
  });

  Widget _buildTitle(bool dense)
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 21 : 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: AppTheme.trialOcean,
    );

    if (shrinkTitle)
    {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(title, maxLines: 1, softWrap: false, style: style),
      );
    }

    return OverflowTooltipText(text: title, maxLines: 1, style: style);
  }

  Widget _buildTitleRow(BuildContext context, bool dense)
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
            fontSize: dense ? 10 : 11,
            fontWeight: FontWeight.w600,
            letterSpacing: dense ? 1.2 : 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 2),
        _buildTitle(dense),
        if (subtitle != null) ...[
          SizedBox(height: dense ? 6 : 8),
          subtitle!,
        ],
      ],
    );

    final bool tight = MediaQuery.sizeOf(context).width < _titleRowRoom;
    final bool besideAFace = leading != null && !tight;

    final EdgeInsets padding = switch ((besideAFace, dense))
    {
      (true, false) => const EdgeInsets.fromLTRB(22, 20, 36, 20),
      (true, true) => const EdgeInsets.fromLTRB(14, 12, 24, 12),
      (false, false) => EdgeInsets.fromLTRB(tight ? 20 : 36, 22, tight ? 20 : 36, 24),
      (false, true) => EdgeInsets.fromLTRB(tight ? 18 : 26, 14, tight ? 18 : 26, 16),
    };

    final Widget pill = AppDialogPill(
      padding: padding,
      child: switch (header)
      {
        final header? => header,
        null when besideAFace => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dense)
                SizedBox(height: _denseLeadingHeight, child: FittedBox(child: leading))
              else
                leading!,
              SizedBox(width: dense ? 14 : 18),
              Flexible(child: heading),
            ],
          ),
        null => heading,
      },
    );

    if (!showClose)
    {
      return pill;
    }

    final double close = dense ? _denseCloseSize : _closeSize;

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: tight
              ? EdgeInsets.only(right: close + 8)
              : EdgeInsets.symmetric(horizontal: close + (dense ? 10 : 16)),
          child: pill,
        ),
        Positioned(
          right: 0,
          child: CarouselArrowButton(
            size: close,
            iconSize: dense ? 18 : CarouselArrowButton.defaultIconSize,
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

  List<Widget> _buildBody(double width, double gap)
  {
    if (!fillLast)
    {
      return [
        Flexible(
          child: _atMost(width, ScrollEdgeFade(
            child: SingleChildScrollView(
              // Default hit-testing is opaque: gap taps must reach the barrier, not stop here.
              hitTestBehavior: HitTestBehavior.deferToChild,
              padding: const EdgeInsets.all(_shadowRoom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) SizedBox(height: gap),
                    AppDialogPiece(index: i + 1, child: children[i]),
                  ],
                ],
              ),
            ),
          )),
        ),
      ];
    }

    return [
      for (var i = 0; i < children.length - 1; i++) ...[
        if (i > 0) SizedBox(height: gap),
        _atMost(width, AppDialogPiece(index: i + 1, child: children[i])),
      ],
      if (children.length > 1) SizedBox(height: gap),
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

    final bool dense = AppBreakpoints.of(context).isDense;
    final double margin = dense ? _denseWindowMargin : _windowMargin;
    final double gap = dense ? _densePieceGap : _pieceGap;

    final double room = window.width - 2 * margin;
    final double pieceWidth = math.min(maxWidth, room);

    Widget frame(AppDialogArrows arrows)
    {
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: _WhileItIsThere(
          // Full screen on purpose: the pieces are aligned within the whole window.
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: room,
                maxHeight: window.height - keyboard - 2 * margin,
              ),
              // Gives text a Material (no yellow underline); transparent, so taps pass through.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppDialogPiece(index: 0, child: _buildTitleRow(context, dense)),
                    SizedBox(height: gap),
                    ..._buildBody(pieceWidth, gap),
                    ListenableBuilder(
                      listenable: arrows,
                      builder: (context, _) => _buildFooter(arrows.arrows, pieceWidth, gap),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _ArrowsHost(
      builder: (arrows) => AppDialogArrowsScope(
        arrows: arrows,
        child: AppDialogDensity(dense: dense, child: frame(arrows)),
      ),
    );
  }

  // A wizard's arrows, when its carousel hands them over: beside the buttons, or above them if room is short.
  Widget _buildFooter((Widget, Widget)? arrows, double width, double gap)
  {
    final Widget? footer = this.footer;

    final bool beside = footer == null || width - 2 * (_handedArrowSize + _arrowsGap) >= _buttonsBesideArrowsLeast;

    final Widget? bottom = switch (arrows)
    {
      null => footer,
      (final Widget back, final Widget forward) when beside => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            back,
            const SizedBox(width: _arrowsGap),
            if (footer != null) ...[
              Flexible(child: footer),
              const SizedBox(width: _arrowsGap),
            ],
            forward,
          ],
        ),
      (final Widget back, final Widget forward) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [back, const SizedBox(width: _arrowsGap), forward],
            ),
            const SizedBox(height: _arrowsGap),
            footer,
          ],
        ),
    };

    if (bottom == null)
    {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: gap),
        _atMost(width, AppDialogPiece(index: children.length + 1, child: bottom)),
      ],
    );
  }
}

class _ArrowsHost extends StatefulWidget
{
  final Widget Function(AppDialogArrows arrows) builder;

  const _ArrowsHost({required this.builder});

  @override
  State<_ArrowsHost> createState() => _ArrowsHostState();
}

class _ArrowsHostState extends State<_ArrowsHost>
{
  final AppDialogArrows _arrows = AppDialogArrows();

  @override
  void dispose()
  {
    _arrows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_arrows);
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

class AppDialogPiece extends StatefulWidget
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
  State<AppDialogPiece> createState() => _AppDialogPieceState();
}

// Owns its curves: a CurvedAnimation listens to the route and must be disposed, not made per build.
class _AppDialogPieceState extends State<AppDialogPiece>
{
  Animation<double>? _route;
  int? _index;

  CurvedAnimation? _fade;
  CurvedAnimation? _pop;
  Animation<double>? _scale;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _sync(ModalRoute.of(context)?.animation);
  }

  @override
  void didUpdateWidget(AppDialogPiece oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    _sync(_route);
  }

  @override
  void dispose()
  {
    _release();
    super.dispose();
  }

  void _release()
  {
    _fade?.dispose();
    _pop?.dispose();
    _fade = null;
    _pop = null;
    _scale = null;
  }

  void _sync(Animation<double>? route)
  {
    if (identical(route, _route) && widget.index == _index)
    {
      return;
    }

    _route = route;
    _index = widget.index;
    _release();

    if (route == null)
    {
      return;
    }

    // Effects off: the whole dialog fades as one, its pieces stay put.
    final Animation<double> parent = VisualEffects.on ? route : kAlwaysCompleteAnimation;

    final start = (widget.index * _staggerStep).clamp(0.0, 1.0 - _staggerSpan);

    _fade = CurvedAnimation(
      parent: parent,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    final pop = CurvedAnimation(
      parent: parent,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutBack),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    _pop = pop;
    _scale = Tween<double>(begin: _pieceScale, end: 1).animate(pop);
  }

  @override
  Widget build(BuildContext context)
  {
    final Animation<double>? fade = _fade;
    final Animation<double>? scale = _scale;

    if (fade == null || scale == null)
    {
      return widget.child;
    }

    return FadeTransition(
      key: widget.named ? ValueKey('appDialogPiece${widget.index}') : null,
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: widget.child,
      ),
    );
  }
}

class AppDialogPill extends StatelessWidget
{
  final Widget child;

  // Both default to the dialog's density.
  final EdgeInsets? padding;
  final double? radius;

  final bool expand;

  final List<BoxShadow> shadow;

  const AppDialogPill({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.shadow = AppTheme.dialogShadow,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppDialogDensity.of(context);
    final borderRadius = BorderRadius.circular(radius ?? (dense ? _densePillRadius : _pillRadius));

    final Widget piece = Container(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: Material(
        color: Colors.white,
        borderRadius: borderRadius,
        elevation: 0,
        child: Padding(
          padding: padding ?? EdgeInsets.all(dense ? kDenseDialogPillPadding : kDialogPillPadding),
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: piece) : piece;
  }
}

// For fillLast: the content scrolls inside, the card keeps its corners and shadow whole.
class AppScrollingDialogPill extends StatelessWidget
{
  final Widget child;

  const AppScrollingDialogPill({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppDialogDensity.of(context);

    return AppDialogPill(
      expand: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dense ? _densePillRadius : _pillRadius),
        child: ScrollEdgeFade(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(dense ? kDenseDialogPillPadding : kDialogPillPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
