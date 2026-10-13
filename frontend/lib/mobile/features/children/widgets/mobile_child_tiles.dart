import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/people/models/person_item.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_choice_sheet.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_filter_chip.dart';
import '../../../shared/widgets/mobile_tour.dart';

const double _radius = 22;
const double _border = 1;
const double _gap = 12;

const double _tileWidth = 128;
const double _tileFace = 80;
const double _tileTop = 18;
const double _tileBottom = 14;
const double _sidePadding = 8;
const double _nameGap = 12;

const double _bleed = 8;

// Clear of the current tile's rim, which stands outside it.
const EdgeInsets _tourInflate = EdgeInsets.all(6);

const String _sheetTitle = 'Figli';
const double _sheetFace = 40;

TextStyle _nameStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.1,
    // Explicit, so the theme's line height does not break the row's measure.
    height: 1.25,
    color: Colors.white,
  );
}

// Keyed by the child, as the tile it holds.
Widget _lit(String? id, PersonItem child, Widget tile)
{
  return MobileTourTarget(
    key: ValueKey(child.fiscalCode),
    id: id,
    inflate: _tourInflate,
    radius: _radius + _tourInflate.left,
    child: tile,
  );
}

// Phones: the child shown as a chip, the others in a sheet.
class MobileChildChip extends StatelessWidget
{
  final List<PersonItem> children;
  final PersonItem shown;
  final ValueChanged<PersonItem> onShow;

  // The page's name, above the sheet's title.
  final String eyebrow;

  const MobileChildChip({
    super.key,
    required this.children,
    required this.shown,
    required this.onShow,
    required this.eyebrow,
  });

  Future<void> _pick(BuildContext context) async
  {
    final MobileChoice<String>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: eyebrow,
      title: _sheetTitle,
      choices: [
        for (final child in children)
          MobileChoice(
            value: child.fiscalCode,
            label: child.firstName,
            leading: MobileAvatar(
              firstName: child.firstName,
              lastName: child.lastName,
              imageUrl: child.profileImageUrl,
              size: _sheetFace,
              gold: child.fiscalCode == shown.fiscalCode,
            ),
          ),
      ],
      value: shown.fiscalCode,
    );

    if (picked == null || !context.mounted)
    {
      return;
    }

    for (final child in children)
    {
      if (child.fiscalCode == picked.value)
      {
        onShow(child);
      }
    }
  }

  // Which child, not a filter: the chip never lights up.
  @override
  Widget build(BuildContext context)
  {
    return MobileFilterChip(
      icon: Icons.face_rounded,
      label: shown.firstName,
      active: false,
      onTap: () => _pick(context),
    );
  }
}

// Tablets standing up: one tile per child in a row.
class MobileChildTiles extends StatefulWidget
{
  final List<PersonItem> children;
  final PersonItem shown;
  final ValueChanged<PersonItem> onShow;

  final double margin;

  // Every tile carries it, for a tour to light them all.
  final String? tourTarget;

  const MobileChildTiles({
    super.key,
    required this.children,
    required this.shown,
    required this.onShow,
    required this.margin,
    this.tourTarget,
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

  // Not ensureVisible: it would also scroll the page the row sits in.
  void _reveal(int index)
  {
    if (!_scroll.hasClients)
    {
      return;
    }

    final double start = index * (_tileWidth + _gap);

    final ScrollPosition position = _scroll.position;
    final double end = start + _tileWidth + widget.margin * 2;
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
    final TextPainter name = TextPainter(
      text: TextSpan(text: 'Ag', style: _nameStyle()),
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
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index)
        {
          final PersonItem child = widget.children[index];

          return _lit(
            widget.tourTarget,
            child,
            MobileChildTile(
              child: child,
              current: child.fiscalCode == widget.shown.fiscalCode,
              onTap: () => _show(index),
            ),
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

  // Every tile carries it, for a tour to light them all.
  final String? tourTarget;

  const MobileChildRail({
    super.key,
    required this.children,
    required this.shown,
    required this.onShow,
    required this.bottom,
    this.tourTarget,
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
            _lit(
              widget.tourTarget,
              child,
              MobileChildTile(
                child: child,
                current: child.fiscalCode == widget.shown.fiscalCode,
                onTap: () => widget.onShow(child),
              ),
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
  final VoidCallback onTap;

  const MobileChildTile({
    super.key,
    required this.child,
    required this.current,
    required this.onTap,
  });

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
            style: _nameStyle(),
          ),
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
        child: _buildTile(),
      ),
    );
  }
}
