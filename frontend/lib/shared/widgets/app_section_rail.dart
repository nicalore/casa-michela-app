import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'overflow_tooltip_text.dart';

// Same duration and curve as the mark under a destination in the top bar, so
// the two navigation surfaces answer the pointer with one gesture.
const Duration _markFade = Duration(milliseconds: 150);

const double _markWidth = 3;
const double _markHeight = 20;

// The mark stands off the edge of the card rather than on it: flush against the
// rounded corner it read as part of the card, and the entries above and below
// had nothing to line up with.
const double _markInset = 9;

const double _entryHeight = 42;

// Left edge of a label. Entries under a heading start further in, which is the
// whole reason the rail can hold a level the top bar could not: nesting costs a
// few pixels of indent instead of a second row of words.
const double _labelInset = 20;
const double _nestedLabelInset = 32;

// Kept clear on the right so a long label ellipsises inside the card instead of
// running into its rounded edge.
const double _labelTrailingInset = 14;

// One heading and the entries under it. A group with no title is a run of
// entries standing on their own, which is what a module with no sub-sections
// needs.
class RailGroup
{
  final String? title;
  final List<String> entries;

  const RailGroup({this.title, required this.entries});
}

// The label of the entry a page is showing, counted the way the rail counts:
// entries only, headings skipped, in the order they are declared. The pages need
// it where the rail is not on screen to say it for them.
String railEntryAt(List<RailGroup> groups, int index)
{
  final entries = [for (final group in groups) ...group.entries];

  if (index < 0 || index >= entries.length)
  {
    return '';
  }

  return entries[index];
}

// The sections of a module, down the left side of the page.
//
// It carries the navigation the pages used to spread over a tab bar and a row
// of chips. Vertical is what makes it work: stacked under the top bar, a second
// row of words read as the same control twice, while a column reads as what it
// is, and nesting one level costs an indent rather than a third row.
//
// selectedIndex counts the entries only, headings excluded, in the order they
// are declared: with groups [a], [b, c] the indices are a=0, b=1, c=2. That is
// deliberately the order of the page's own IndexedStack, so the two cannot
// drift apart.
class AppSectionRail extends StatelessWidget
{
  // Wide enough for "Informazioni personali", the longest label any module
  // puts in here, at the size below and with a nested entry's indent in front
  // of it.
  static const double width = 240;

  // Air between the rail and whatever stands beside it. At the page minimum of
  // 1440 the two together leave the content 1088, which keeps the Orari boards
  // above the width where they fold into their compact form.
  static const double gap = 32;

  // The module's name, which is also the page's title: the pages lost theirs
  // when the header pill went away, and the rail is the natural place for it.
  final String title;

  final List<RailGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppSectionRail({
    super.key,
    required this.title,
    required this.groups,
    required this.selectedIndex,
    required this.onSelected,
  });

  Widget _buildTitle()
  {
    return Padding(
      padding: const EdgeInsets.only(left: _labelInset, right: 16, bottom: 16),
      child: OverflowTooltipText(
        text: title,
        maxLines: 1,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppTheme.trialOcean,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // Runs alongside the groups so that every entry knows the index the page
    // will hear back, headings taking no number of their own.
    var entryIndex = 0;

    final children = <Widget>[];

    for (final group in groups)
    {
      final groupTitle = group.title;

      if (groupTitle != null)
      {
        children.add(AppRailHeading(groupTitle));
      }
      else if (children.isNotEmpty)
      {
        // A heading brings its own air with it; a run of entries standing on
        // their own after one would otherwise butt straight against the last
        // entry of the group above and read as part of it.
        children.add(const SizedBox(height: 16));
      }

      for (final entry in group.entries)
      {
        final index = entryIndex++;

        children.add(AppRailEntry(
          label: entry,
          nested: groupTitle != null,
          selected: index == selectedIndex,
          onTap: () => onSelected(index),
        ));
      }
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(),
          // A module whose sections are counted rather than named can put more
          // entries in here than the page is tall — Lezioni lists a day at a
          // time, and how many days there are depends on when you ask. They
          // scroll inside the card rather than running off the bottom of the
          // page. Loose, so a rail that fits is exactly as tall as its entries,
          // which is what every module currently is.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Set like the upper line of the wordmark in the top bar: upper case, tracked,
// muted, small. It names a group without ever looking like something you can
// click.
class AppRailHeading extends StatelessWidget
{
  final String text;

  const AppRailHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(left: _labelInset, right: 16, top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          height: 1.2,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }
}

// One line of the rail. Public because the drawer that replaces the rail on a
// narrow window is made of these same rows: the sections have to answer the
// finger the way they answer the pointer, or moving between the two widths
// would feel like moving between two apps.
class AppRailEntry extends StatefulWidget
{
  final String label;
  final bool nested;
  final bool selected;
  final VoidCallback onTap;

  const AppRailEntry({
    super.key,
    required this.label,
    required this.nested,
    required this.selected,
    required this.onTap,
  });

  @override
  State<AppRailEntry> createState() => _AppRailEntryState();
}

class _AppRailEntryState extends State<AppRailEntry>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final marked = widget.selected || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          height: _entryHeight,
          child: Stack(
            children: [
              Positioned(
                left: _markInset,
                top: 0,
                bottom: 0,
                child: Center(
                  // The mark grows out of the middle of the entry the way the
                  // one in the top bar grows out of the middle of a word, only
                  // along the other axis. It is squeezed by a transform and not
                  // by a size, so it takes no part in layout and the column
                  // cannot shift as the pointer travels down it.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: marked ? 1 : 0),
                    duration: _markFade,
                    curve: Curves.easeOut,
                    builder: (context, factor, child) => Transform.scale(
                      scaleY: factor,
                      alignment: Alignment.center,
                      child: child,
                    ),
                    child: Container(
                      width: _markWidth,
                      height: _markHeight,
                      decoration: BoxDecoration(
                        color: AppTheme.trialGold,
                        borderRadius: BorderRadius.circular(_markWidth),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: widget.nested ? _nestedLabelInset : _labelInset,
                  right: _labelTrailingInset,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OverflowTooltipText(
                    text: widget.label,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                      color: widget.selected || _hover
                          ? AppTheme.trialTealDeep
                          : AppTheme.trialMutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// What the rail says on a window too narrow to hold it. The module it belongs
// to, quietly, over the section you are actually in: the same eyebrow and title
// pairing the dialogs of the app use, and the same two lines the rail carries at
// its head — one of them just moved into the drawer with the entries.
class AppSectionHeading extends StatelessWidget
{
  final String module;
  final String section;

  const AppSectionHeading({
    super.key,
    required this.module,
    required this.section,
  });

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          module.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
          text: section,
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOcean,
          ),
        ),
      ],
    );
  }
}
