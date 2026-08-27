import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'overflow_tooltip_text.dart';

const Duration _markFade = Duration(milliseconds: 150);

const double _markWidth = 3;
const double _markHeight = 20;

const double _markInset = 9;

const double _entryHeight = 42;

const double _labelInset = 20;
const double _nestedLabelInset = 32;

const double _labelTrailingInset = 14;

class RailGroup
{
  final String? title;
  final List<String> entries;

  const RailGroup({this.title, required this.entries});
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
