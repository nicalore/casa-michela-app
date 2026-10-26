import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import 'app_menu.dart';
import 'app_section_rail.dart';
import 'app_tooltip.dart';
import 'app_top_nav.dart';
import 'desktop_tour.dart';

const double _titleSize = 21;
const double _tabSize = 14;
const double _titleGap = 28;
const double _tabGap = 20;
const double _tabPadding = 2;
const double _sidePadding = 4;
const double _chevronSize = 18;
const double _separatorWidth = 1;
const double _underlineHeight = 3;
const double _underlineGap = 10;
const double _menuWidth = 240;

// A heading that opens a menu: its chevron and the room its tint keeps after it.
const double _titleChevronSize = 22;
const double _titleChevronGap = 2;
const double _titleMenuEnd = 8;

const double kSectionTabsGap = 16;

// A note at the line's end (a day's figures), or under the line when it does not fit there.
const double _noteSize = 13.5;
const double _noteGap = 24;
const double _noteUnder = 10;

const Duration _hoverFade = Duration(milliseconds: 150);

// One weight for all, as on the bar: choosing a tab never moves the others.
TextStyle _tabStyle({required bool lit, required bool enabled})
{
  return GoogleFonts.plusJakartaSans(
    fontSize: _tabSize,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: !enabled
        ? AppTheme.trialMutedText.withValues(alpha: 0.55)
        : lit
            ? AppTheme.trialTealDeep
            : AppTheme.trialMutedText,
  );
}

TextStyle get _noteStyle => GoogleFonts.plusJakartaSans(
  fontSize: _noteSize,
  fontWeight: FontWeight.w600,
  height: 1.3,
  color: AppTheme.trialMutedText,
);

TextStyle _titleStyle([double size = _titleSize])
{
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppTheme.trialOcean,
  );
}

// One place on the row: a section, or a titled group that opens its sections in a menu.
class _Tab
{
  final RailGroup? group;
  final String? entry;

  // The index of the entry, or of the group's first entry.
  final int index;

  // A thin line before it: it starts another group.
  final bool parted;

  const _Tab.entry(String this.entry, this.index, {this.parted = false}) : group = null;

  const _Tab.group(RailGroup this.group, this.index, {this.parted = false}) : entry = null;

  // A group names the section open in it, as a filter pill names its value.
  String labelFor(int selected)
  {
    final RailGroup? group = this.group;

    if (group == null)
    {
      return entry!;
    }

    return holds(selected) ? '${group.title}: ${group.entries[selected - index]}' : group.title!;
  }

  bool holds(int selected)
  {
    final RailGroup? group = this.group;

    return group == null ? selected == index : selected >= index && selected < index + group.entries.length;
  }
}

List<_Tab> _tabsOf(List<RailGroup> groups)
{
  final List<_Tab> tabs = [];
  var index = 0;

  // A lone group needs no menu of its own: its title says no more than the page's.
  final bool alone = groups.length == 1;

  for (final (number, group) in groups.indexed)
  {
    final bool parted = number > 0;

    if (group.title != null && !alone)
    {
      tabs.add(_Tab.group(group, index, parted: parted));
      index += group.entries.length;

      continue;
    }

    for (final (position, entry) in group.entries.indexed)
    {
      tabs.add(_Tab.entry(entry, index, parted: parted && position == 0));
      index++;
    }
  }

  return tabs;
}

bool _isAvailable(List<RailGroup> groups, int index)
{
  var start = 0;

  for (final group in groups)
  {
    if (index < start + group.entries.length)
    {
      return group.isAvailable(group.entries[index - start]);
    }

    start += group.entries.length;
  }

  return false;
}

// Below the wide window the sections of a page sit beside its title instead of in a rail.
class AppSectionTabs extends StatefulWidget
{
  final String title;

  final List<RailGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  // Entries a tour can light, by index.
  final Map<int, String> tours;

  // Before the title (a back button, a face), as wide as said with the gap after it.
  final Widget? leading;
  final double leadingWidth;

  // After the title (the roles beside a name), as wide as said with the gap before it.
  // Measured here: the page's own context sits above the theme's text style.
  final Widget? titleTrailing;
  final double Function(BuildContext context)? titleTrailingWidthOf;

  // A person's name reads smaller than a page's title.
  final double titleSize;

  // Makes leading, title and trailing one button opening this menu, a chevron after them (a parent's children).
  final Widget Function(BuildContext context, VoidCallback close)? titleMenu;

  // At the line's end while it fits beside the title and the tabs, else under the line.
  final String? note;

  const AppSectionTabs({
    super.key,
    required this.title,
    required this.groups,
    required this.selectedIndex,
    required this.onSelected,
    this.tours = const {},
    this.leading,
    this.leadingWidth = 0,
    this.titleTrailing,
    this.titleTrailingWidthOf,
    this.titleSize = _titleSize,
    this.titleMenu,
    this.note,
  });

  @override
  State<AppSectionTabs> createState() => _AppSectionTabsState();
}

class _AppSectionTabsState extends State<AppSectionTabs>
{
  @override
  void initState()
  {
    super.initState();

    // Measured with the page's font: measured again once it has loaded.
    PaintingBinding.instance.systemFonts.addListener(_remeasure);
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_remeasure);
    super.dispose();
  }

  void _remeasure()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  double _textWidth(String text, TextStyle style)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width;
  }

  double _tabWidth(String label, {required bool drop})
  {
    return _textWidth(label, _tabStyle(lit: true, enabled: true)) +
        2 * _tabPadding +
        (drop ? _chevronSize + 1 : 0);
  }

  double _rowWidth(List<_Tab> tabs, {bool more = false})
  {
    double width = 0;

    for (final (i, tab) in tabs.indexed)
    {
      if (i > 0)
      {
        width += _tabGap + (tab.parted ? _separatorWidth + _tabGap : 0);
      }

      width += _tabWidth(tab.labelFor(widget.selectedIndex), drop: tab.group != null);
    }

    if (more)
    {
      width += (tabs.isEmpty ? 0 : _tabGap) + _tabWidth(kMoreEntry, drop: true);
    }

    return width;
  }

  int _fitting(List<_Tab> tabs, double room)
  {
    if (_rowWidth(tabs) <= room)
    {
      return tabs.length;
    }

    for (var kept = tabs.length - 1; kept > 0; kept--)
    {
      if (_rowWidth(tabs.sublist(0, kept), more: true) <= room)
      {
        return kept;
      }
    }

    return 0;
  }

  @override
  Widget build(BuildContext context)
  {
    final List<_Tab> tabs = _tabsOf(widget.groups);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth - 2 * _sidePadding;
        final TextStyle titleStyle = _titleStyle(widget.titleSize);
        final double trailingWidth = widget.titleTrailingWidthOf?.call(context) ?? 0;
        final double button = widget.titleMenu == null ? 0 : _titleChevronGap + _titleChevronSize + _titleMenuEnd;
        final double title = widget.leadingWidth + _textWidth(widget.title, titleStyle) + trailingWidth + button;

        // Beside the title while they all fit there; else on their own line, folding what still does not.
        final bool beside = title + _titleGap + _rowWidth(tabs) <= width;

        final String? note = widget.note;
        final bool noteBeside =
            note != null && beside && title + _titleGap + _rowWidth(tabs) + _noteGap + _textWidth(note, _noteStyle) <= width;
        final int kept = beside ? tabs.length : _fitting(tabs, width);

        final Widget row = _buildTabs(tabs, kept);

        final Widget words = Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);

        // Beside the tabs it has the room it was measured for; alone on its line the name gives way.
        final Widget named = widget.leading == null && widget.titleTrailing == null
            ? words
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?widget.leading,
                  if (beside) words else Flexible(child: words),
                  if (widget.titleTrailing case final Widget trailing)
                    beside
                        ? SizedBox(width: trailingWidth, child: trailing)
                        : Flexible(child: trailing),
                ],
              );

        final Widget heading = Padding(
          padding: const EdgeInsets.only(bottom: _underlineGap),
          child: switch (widget.titleMenu)
          {
            final menu? => AppTitleMenu(menu: menu, child: named),
            null => named,
          },
        );

        final Widget line = DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.closedLine)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
            child: beside
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      heading,
                      const SizedBox(width: _titleGap),
                      if (noteBeside) ...[
                        row,
                        const SizedBox(width: _noteGap),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: _underlineGap + 2),
                            child: Text(note, maxLines: 1, textAlign: TextAlign.end, style: _noteStyle),
                          ),
                        ),
                      ]
                      else
                        Flexible(child: row),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading,
                      row,
                    ],
                  ),
          ),
        );

        if (note == null || noteBeside)
        {
          return line;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line,
            Padding(
              padding: const EdgeInsets.only(left: _sidePadding, right: _sidePadding, top: _noteUnder),
              child: Text(note, style: _noteStyle),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs(List<_Tab> tabs, int kept)
  {
    final int selected = widget.selectedIndex;
    final List<_Tab> folded = tabs.sublist(kept);

    final List<Widget> children = [];

    for (final (i, tab) in tabs.sublist(0, kept).indexed)
    {
      if (i > 0)
      {
        children.add(const SizedBox(width: _tabGap));

        if (tab.parted)
        {
          children.add(const _Separator());
          children.add(const SizedBox(width: _tabGap));
        }
      }

      children.add(_buildTab(tab));
    }

    if (folded.isNotEmpty)
    {
      if (children.isNotEmpty)
      {
        children.add(const SizedBox(width: _tabGap));
      }

      children.add(_MenuTab(
        label: kMoreEntry,
        selected: folded.any((tab) => tab.holds(selected)),
        menu: (context, close) => _menuOf(folded, close),
      ));
    }

    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: children);
  }

  Widget _buildTab(_Tab tab)
  {
    final RailGroup? group = tab.group;

    if (group != null)
    {
      return _MenuTab(
        label: tab.labelFor(widget.selectedIndex),
        selected: tab.holds(widget.selectedIndex),
        menu: (context, close) => _menuOf([tab], close, headed: false),
      );
    }

    final int index = tab.index;

    return DesktopTourTarget(
      id: widget.tours[index],
      child: _EntryTab(
        label: tab.entry!,
        selected: index == widget.selectedIndex,
        enabled: _isAvailable(widget.groups, index),
        onTap: () => widget.onSelected(index),
      ),
    );
  }

  Widget _menuOf(List<_Tab> tabs, VoidCallback close, {bool headed = true})
  {
    final List<Widget> items = [const SizedBox(height: 6)];

    void add(String entry, int index, RailGroup group)
    {
      items.add(AppMenuItem(
        text: entry,
        current: index == widget.selectedIndex,
        enabled: group.isAvailable(entry),
        dense: true,
        onTap: ()
        {
          close();
          widget.onSelected(index);
        },
      ));
    }

    for (final tab in tabs)
    {
      final RailGroup? group = tab.group;

      if (group == null)
      {
        add(tab.entry!, tab.index, _groupOf(tab.index));

        continue;
      }

      if (headed || tabs.length > 1)
      {
        items.add(AppMenuHeading(group.title!));
      }

      for (final (offset, entry) in group.entries.indexed)
      {
        add(entry, tab.index + offset, group);
      }
    }

    items.add(const SizedBox(height: 6));

    return AppMenuCard(width: _menuWidth, children: items);
  }

  RailGroup _groupOf(int index)
  {
    var start = 0;

    for (final group in widget.groups)
    {
      if (index < start + group.entries.length)
      {
        return group;
      }

      start += group.entries.length;
    }

    return widget.groups.last;
  }
}

// A heading that is one button opening [menu], a chevron after it (a parent's children, a psychologist's pupils).
class AppTitleMenu extends StatefulWidget
{
  final Widget Function(BuildContext context, VoidCallback close) menu;
  final Widget child;

  const AppTitleMenu({super.key, required this.menu, required this.child});

  @override
  State<AppTitleMenu> createState() => _AppTitleMenuState();
}

class _AppTitleMenuState extends State<AppTitleMenu>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return AppAnchoredMenu(
      gap: 8,
      menu: widget.menu,
      builder: (context, open, toggle)
      {
        final bool lit = _hover || open;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            // A stadium: a face at the start rounds it off.
            child: AnimatedContainer(
              duration: _hoverFade,
              curve: Curves.easeOut,
              padding: const EdgeInsets.only(right: _titleMenuEnd),
              decoration: BoxDecoration(
                color: AppTheme.trialTealDeep.withValues(alpha: lit ? 0.07 : 0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: widget.child),
                  const SizedBox(width: _titleChevronGap),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: VisualEffects.of(context) ? const Duration(milliseconds: 200) : Duration.zero,
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: _titleChevronSize,
                      color: lit ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Separator extends StatelessWidget
{
  const _Separator();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _separatorWidth,
      height: 16,
      margin: const EdgeInsets.only(bottom: _underlineGap + 2),
      color: AppTheme.closedLine,
    );
  }
}

class _Underline extends StatelessWidget
{
  final bool shown;
  final Widget child;

  const _Underline({required this.shown, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: _tabPadding, right: _tabPadding, bottom: _underlineGap),
          child: child,
        ),
        // Over the header's hairline, as a tab sits on its line.
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: _underlineHeight,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: shown ? 1 : 0),
            duration: _hoverFade,
            curve: Curves.easeOut,
            builder: (context, factor, child) => Transform.scale(scaleX: factor, child: child),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.trialGold,
                borderRadius: BorderRadius.circular(_underlineHeight),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryTab extends StatefulWidget
{
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _EntryTab({required this.label, required this.selected, required this.enabled, required this.onTap});

  @override
  State<_EntryTab> createState() => _EntryTabState();
}

class _EntryTabState extends State<_EntryTab>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final Widget tab = _Underline(
      shown: widget.selected || (_hover && widget.enabled),
      child: Text(
        widget.label,
        maxLines: 1,
        softWrap: false,
        style: _tabStyle(lit: widget.selected || _hover, enabled: widget.enabled),
      ),
    );

    if (!widget.enabled)
    {
      return AppTooltip(waitDuration: const Duration(milliseconds: 400), message: 'In arrivo', child: tab);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: tab),
    );
  }
}

class _MenuTab extends StatefulWidget
{
  final String label;
  final bool selected;
  final Widget Function(BuildContext context, VoidCallback close) menu;

  const _MenuTab({required this.label, required this.selected, required this.menu});

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return AppAnchoredMenu(
      gap: 8,
      menu: widget.menu,
      builder: (context, open, toggle)
      {
        final bool lit = widget.selected || _hover || open;
        final Color color = lit ? AppTheme.trialTealDeep : AppTheme.trialMutedText;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: _Underline(
              shown: lit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    style: _tabStyle(lit: lit, enabled: true),
                  ),
                  const SizedBox(width: 1),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: VisualEffects.of(context) ? const Duration(milliseconds: 200) : Duration.zero,
                    curve: Curves.easeInOut,
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: _chevronSize, color: color),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
