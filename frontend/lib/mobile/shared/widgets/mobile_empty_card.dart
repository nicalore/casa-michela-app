import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_empty_card.dart';
import 'mobile_glass_panel.dart';

class MobileEmptyCard extends StatelessWidget
{
  final IconData icon;
  final String message;
  final bool tablet;

  const MobileEmptyCard({super.key, required this.icon, required this.message, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppTheme.trialTealDeep),
          const SizedBox(height: 10),
          Text(
            emptyCardText(message),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 17 : 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }
}

// A page's scroll view; when [fill] is set its body takes the room left below the head.
class MobileEmptyScroll extends StatefulWidget
{
  final EdgeInsets padding;
  final List<Widget> head;

  // Centres an empty card itself: filling, it is handed the whole room.
  final Widget body;

  final bool fill;

  // After the body, as a tour runway.
  final List<Widget> tail;

  final ScrollController? controller;

  const MobileEmptyScroll({
    super.key,
    required this.padding,
    this.head = const [],
    required this.body,
    required this.fill,
    this.tail = const [],
    this.controller,
  });

  @override
  State<MobileEmptyScroll> createState() => _MobileEmptyScrollState();
}

class _MobileEmptyScrollState extends State<MobileEmptyScroll>
{
  // Keeps the body's state, a load switcher's above all, as it moves between slivers.
  final GlobalKey _body = GlobalKey();

  @override
  Widget build(BuildContext context)
  {
    final EdgeInsets padding = widget.padding;
    final EdgeInsets below = widget.head.isEmpty ? padding : padding.copyWith(top: 0);
    final Widget body = KeyedSubtree(key: _body, child: widget.body);

    return CustomScrollView(
      controller: widget.controller,
      clipBehavior: Clip.none,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // One box, never dropped while scrolled away, and in place whichever way the body goes.
        if (widget.head.isNotEmpty)
          SliverPadding(
            padding: padding.copyWith(bottom: 0),
            sliver: SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.head),
            ),
          ),
        if (widget.fill)
          SliverFillRemaining(hasScrollBody: false, child: Padding(padding: below, child: body))
        else
          SliverPadding(padding: below, sliver: SliverToBoxAdapter(child: body)),
        if (widget.tail.isNotEmpty) SliverList.list(children: widget.tail),
      ],
    );
  }
}
