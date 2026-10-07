import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/people/models/person_item.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_current_card.dart';

const double _radius = 22;
const double _border = 1;
const double _gap = 12;

const double _tileWidth = 128;
const double _tileFace = 80;
const double _tileTop = 18;
const double _tileBottom = 14;
const double _sidePadding = 8;
const double _nameGap = 12;

const double _capsuleFace = 48;
const double _capsulePad = 6;
const double _capsuleNameGap = 12;
const double _capsuleEnd = 20;
const double _capsuleGap = 10;

const double _bleed = 8;

TextStyle _nameStyle({required bool tablet})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: tablet ? 17 : 15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.1,
    // Explicit, so the theme's line height does not break the row's measure.
    height: 1.25,
    color: Colors.white,
  );
}

class MobileChildTiles extends StatefulWidget
{
  final List<PersonItem> children;
  final PersonItem shown;
  final ValueChanged<PersonItem> onShow;

  final bool tablet;

  final double margin;

  const MobileChildTiles({
    super.key,
    required this.children,
    required this.shown,
    required this.onShow,
    required this.tablet,
    required this.margin,
  });

  @override
  State<MobileChildTiles> createState() => _MobileChildTilesState();
}

class _MobileChildTilesState extends State<MobileChildTiles>
{
  final ScrollController _scroll = ScrollController();

  @override
  void dispose()
  {
    _scroll.dispose();
    super.dispose();
  }

  double get _spacing => widget.tablet ? _gap : _capsuleGap;

  double _extentOf(int index)
  {
    return widget.tablet ? _tileWidth : MobileChildTile.capsuleWidth(context, widget.children[index]);
  }

  // Not ensureVisible: it would also scroll the page the row sits in.
  void _reveal(int index)
  {
    if (!_scroll.hasClients)
    {
      return;
    }

    double start = 0;

    for (var i = 0; i < index; i++)
    {
      start += _extentOf(i) + _spacing;
    }

    final ScrollPosition position = _scroll.position;
    final double end = start + _extentOf(index) + widget.margin * 2;
    double target = position.pixels;

    if (target > start)
    {
      target = start;
    }
    else if (target < end - position.viewportDimension)
    {
      target = end - position.viewportDimension;
    }

    if (target != position.pixels)
    {
      _scroll.animateTo(
        target.clamp(0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _show(int index)
  {
    _reveal(index);
    widget.onShow(widget.children[index]);
  }

  double _heightOf(BuildContext context)
  {
    if (!widget.tablet)
    {
      return MobileChildTile.capsuleHeight;
    }

    final TextPainter name = TextPainter(
      text: TextSpan(text: 'Ag', style: _nameStyle(tablet: true)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();

    // The border insets the content too; text boxes round up on the device.
    return _tileTop + _tileFace + _nameGap + name.height.ceilToDouble() + _tileBottom + _border * 2;
  }

  @override
  Widget build(BuildContext context)
  {
    return SizedBox(
      height: _heightOf(context) + _bleed * 2,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(horizontal: widget.margin, vertical: _bleed),
        itemCount: widget.children.length,
        separatorBuilder: (context, index) => SizedBox(width: _spacing),
        itemBuilder: (context, index)
        {
          final PersonItem child = widget.children[index];

          return MobileChildTile(
            key: ValueKey(child.fiscalCode),
            child: child,
            current: child.fiscalCode == widget.shown.fiscalCode,
            tablet: widget.tablet,
            onTap: () => _show(index),
          );
        },
      ),
    );
  }
}

class MobileChildRail extends StatefulWidget
{
  static const double width = _tileWidth;

  static const double gap = 28;

  final List<PersonItem> children;
  final PersonItem shown;
  final ValueChanged<PersonItem> onShow;

  final double bottom;

  const MobileChildRail({
    super.key,
    required this.children,
    required this.shown,
    required this.onShow,
    required this.bottom,
  });

  @override
  State<MobileChildRail> createState() => _MobileChildRailState();
}

class _MobileChildRailState extends State<MobileChildRail>
{
  final ScrollController _scroll = ScrollController();

  @override
  void dispose()
  {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      controller: _scroll,
      primary: false,
      clipBehavior: Clip.none,
      padding: EdgeInsets.only(top: _bleed, bottom: widget.bottom),
      child: Column(
        children: [
          for (final (i, child) in widget.children.indexed) ...[
            if (i > 0) const SizedBox(height: _gap),
            MobileChildTile(
              key: ValueKey(child.fiscalCode),
              child: child,
              current: child.fiscalCode == widget.shown.fiscalCode,
              tablet: true,
              onTap: () => widget.onShow(child),
            ),
          ],
        ],
      ),
    );
  }
}

// Clips sliding pages at the rail's edge: through its glass, cards showed over the children.
class MobileRailClip extends StatelessWidget
{
  static const double clearance = 10;

  final PageController pages;

  final double margin;

  final Widget child;

  const MobileRailClip({super.key, required this.pages, required this.margin, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return ClipRect(clipper: _RailEdge(pages, margin - MobileChildRail.gap + clearance), child: child);
  }
}

class _RailEdge extends CustomClipper<Rect>
{
  static const double _run = 4000;

  final PageController pages;
  final double inset;

  _RailEdge(this.pages, this.inset) : super(reclip: pages);

  // Every position: while a page swaps in, two views can share the controller.
  bool get _sliding
  {
    for (final ScrollPosition position in pages.positions)
    {
      if (!position.hasPixels || !position.hasViewportDimension || position.viewportDimension == 0)
      {
        continue;
      }

      final double page = position.pixels / position.viewportDimension;

      if ((page - page.roundToDouble()).abs() > 0.001)
      {
        return true;
      }
    }

    return false;
  }

  @override
  Rect getClip(Size size) => Rect.fromLTRB(_sliding ? inset : -_run, -_run, size.width + _run, size.height + _run);

  @override
  bool shouldReclip(_RailEdge oldClipper) => oldClipper.pages != pages || oldClipper.inset != inset;
}

class MobileChildTile extends StatelessWidget
{
  final PersonItem child;
  final bool current;
  final bool tablet;
  final VoidCallback onTap;

  const MobileChildTile({
    super.key,
    required this.child,
    required this.current,
    required this.tablet,
    required this.onTap,
  });

  static const double capsuleHeight = _capsuleFace + _capsulePad * 2 + _border * 2;

  // Must match the capsule's layout: face, gap, name and ends.
  static double capsuleWidth(BuildContext context, PersonItem child)
  {
    final TextPainter name = TextPainter(
      text: TextSpan(text: child.firstName, style: _nameStyle(tablet: false)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = _border * 2 + _capsulePad + _capsuleFace + _capsuleNameGap + name.width.ceilToDouble() + _capsuleEnd;

    name.dispose();

    return width;
  }

  Widget _buildTile()
  {
    return Container(
      width: _tileWidth,
      padding: const EdgeInsets.fromLTRB(_sidePadding, _tileTop, _sidePadding, _tileBottom),
      decoration: _glass(BorderRadius.circular(_radius)),
      foregroundDecoration: _rim(BorderRadius.circular(_radius)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MobileAvatar(
            firstName: child.firstName,
            lastName: child.lastName,
            imageUrl: child.profileImageUrl,
            size: _tileFace,
            gold: current,
          ),
          const SizedBox(height: _nameGap),
          Text(
            child.firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _nameStyle(tablet: true),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsule()
  {
    const BorderRadius radius = BorderRadius.all(Radius.circular(capsuleHeight / 2));

    return Container(
      height: capsuleHeight,
      padding: const EdgeInsets.fromLTRB(_capsulePad, _capsulePad, _capsuleEnd, _capsulePad),
      decoration: _glass(radius),
      foregroundDecoration: _rim(radius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MobileAvatar(
            firstName: child.firstName,
            lastName: child.lastName,
            imageUrl: child.profileImageUrl,
            size: _capsuleFace,
            gold: current,
          ),
          const SizedBox(width: _capsuleNameGap),
          Text(child.firstName, maxLines: 1, style: _nameStyle(tablet: false)),
        ],
      ),
    );
  }

  BoxDecoration _glass(BorderRadius radius)
  {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: radius,
      border: Border.all(color: Colors.white.withValues(alpha: 0.26), width: _border),
    );
  }

  Decoration? _rim(BorderRadius radius) => current ? MobileCurrentCard(radius) : null;

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      selected: current,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tablet ? _buildTile() : _buildCapsule(),
      ),
    );
  }
}
