import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/language/app_language.dart';
import '../../core/theme/app_theme.dart';
import 'app_tooltip.dart';
import 'desktop_tour.dart';
import 'scroll_edge_fade.dart';
import 'whole_words.dart';

const Duration _markFade = Duration(milliseconds: 150);

const double _markWidth = 3;
const double _markHeight = 20;

const double _markInset = 9;

const double _entryHeight = 42;

// Above and below a label that wraps.
const double _labelVerticalInset = 9;

const double _labelInset = 20;
const double _nestedLabelInset = 32;

const double _labelTrailingInset = 14;

const double _unavailableAlpha = 0.55;

class RailGroup
{
  final String? title;
  final List<String> entries;

  // Listed but not built yet: muted and unclickable.
  final Set<String> unavailable;

  // Beside an entry, at the right: a count, a mark.
  final Map<String, Widget> trailing;

  const RailGroup({this.title, required this.entries, this.unavailable = const {}, this.trailing = const {}});

  bool isAvailable(String entry) => !unavailable.contains(entry);
}

String railEntryAt(List<RailGroup> groups, int index)
{
  final entries = [for (final group in groups) ...group.entries];

  if (index < 0 || index >= entries.length)
  {
    return '';
  }

  return entries[index];
}

class AppSectionRail extends StatelessWidget
{
  static const double width = 240;

  static const double gap = 32;

  final String title;

  final List<RailGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  // Entries a tour can light, by index.
  final Map<int, String> tours;

  const AppSectionRail({
    super.key,
    required this.title,
    required this.groups,
    required this.selectedIndex,
    required this.onSelected,
    this.tours = const {},
  });

  Widget _buildTitle()
  {
    return Padding(
      padding: const EdgeInsets.only(left: _labelInset, right: 16, bottom: 16),
      child: WholeWords(
        child: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOceanText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    var entryIndex = 0;

    final children = <Widget>[];

    // Untitled groups keep the same rhythm, told apart by inset alone.
    for (final group in groups)
    {
      final groupTitle = group.title;

      if (groupTitle != null)
      {
        children.add(AppRailHeading(groupTitle));
      }

      for (final entry in group.entries)
      {
        final index = entryIndex++;

        children.add(DesktopTourTarget(
          id: tours[index],
          child: AppRailEntry(
            label: entry,
            nested: groupTitle != null,
            selected: index == selectedIndex,
            enabled: group.isAvailable(entry),
            trailing: group.trailing[entry],
            onTap: () => onSelected(index),
          ),
        ));
      }
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitle(),
          Flexible(
            child: ScrollEdgeFade(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppRailHeading extends StatelessWidget
{
  final String text;

  const AppRailHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(left: _labelInset, right: 16, top: 18, bottom: 8),
      child: WholeWords(
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
      ),
    );
  }
}

class AppRailEntry extends StatefulWidget
{
  final String label;
  final bool nested;
  final bool selected;

  // False for an entry not built yet: paler, no mark, deaf to the pointer.
  final bool enabled;

  final Widget? trailing;

  final VoidCallback onTap;

  const AppRailEntry({
    super.key,
    required this.label,
    required this.nested,
    required this.selected,
    this.enabled = true,
    this.trailing,
    required this.onTap,
  });

  @override
  State<AppRailEntry> createState() => _AppRailEntryState();
}

class _AppRailEntryState extends State<AppRailEntry>
{
  bool _hover = false;

  Color get _labelColor
  {
    if (!widget.enabled)
    {
      return AppTheme.trialMutedText.withValues(alpha: _unavailableAlpha);
    }

    return widget.selected || _hover ? AppTheme.trialTealDeepText : AppTheme.trialMutedText;
  }

  TextStyle _labelStyle({required bool bold}) => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.25,
        color: _labelColor,
      );

  // As tall as the bold label, so selecting an entry moves no row below it.
  Widget _buildLabel()
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final DefaultTextStyle inherited = DefaultTextStyle.of(context);
        final TextPainter bold = TextPainter(
          text: TextSpan(text: widget.label, style: inherited.style.merge(_labelStyle(bold: true))),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          textHeightBehavior: inherited.textHeightBehavior,
        )..layout(maxWidth: constraints.maxWidth);
        final double height = bold.height;

        bold.dispose();

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: WholeWords(child: Text(widget.label, style: _labelStyle(bold: widget.selected))),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final marked = widget.enabled && (widget.selected || _hover);

    final Widget entry = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _entryHeight),
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          Positioned(
            left: _markInset,
            top: 0,
            bottom: 0,
            child: Center(
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
              top: _labelVerticalInset,
              bottom: _labelVerticalInset,
            ),
            child: Row(
              children: [
                Expanded(child: _buildLabel()),
                ?widget.trailing,
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.enabled)
    {
      return AppTooltip(
        waitDuration: const Duration(milliseconds: 400),
        message: tr('In arrivo', 'Coming soon'),
        child: entry,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: entry,
      ),
    );
  }
}
