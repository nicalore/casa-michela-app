import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/platform/visual_effects.dart';
import '../../core/theme/app_theme.dart';
import 'app_tooltip.dart';
import 'dialog_density.dart';
import 'close_on_resize.dart';
import 'overflow_tooltip_text.dart';
import 'page_density.dart';
import 'scroll_edge_fade.dart';

const Color _fieldSurface = Color(0xFFFBFDFC);
const double _fieldRadius = 14;
const double _fieldBorder = 2;
const double _fieldHeight = 50;

// Inside a dense dialog, level with its text fields.
const double _denseFieldRadius = 12;
const double _denseFieldHeight = 44;

// In a row of a dense page (AppPageDensity), as tall as its other controls.
const double _pageFieldHeight = 38;

const double _menuRadius = 16;
const double _scrollbarLane = 10;

// An option's room beside its label: the sides, the gold bar and its gap.
const double _itemSides = 16 + 2 + 10 + 16;

// A menu wider than its field keeps this far from the window's edge.
const double _menuMargin = 8;

const double _mutedOpacity = 0.55;

// Gold with no alpha: a border fading in over a filled face never shows another hue on the way.
final Color _clearGold = AppTheme.trialGold.withValues(alpha: 0);

TextStyle _itemStyle({required bool selected}) => GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: AppTheme.trialTealDeep,
    );

// The marked option: a green pill inset from the menu's left edge as from its scrollbar lane.
const Color _markSurface = Color(0xFFE2F5EC);
const Color _markAccent = AppTheme.trialLagoon;
const double _markInset = _scrollbarLane;
const double _markRadius = 10;

class AppDropdownOption<T>
{
  final T?     value;
  final String label;
  final bool   isSeparator;

  // Before the label, in the menu and in the field once chosen.
  final Widget? leading;

  // After the label, in the menu only.
  final Widget? trailing;

  // False for an option shown but not to be picked: muted and inert.
  final bool enabled;

  // Why a muted option cannot be picked, in a tooltip under the pointer.
  final String? disabledReason;

  AppDropdownOption({
    this.value,
    this.label       = '',
    this.isSeparator = false,
    this.leading,
    this.trailing,
    this.enabled     = true,
    this.disabledReason,
  });
}

class AppDropdownField<T> extends StatefulWidget
{
  final String                   hint;
  final T?                       value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?>         onChanged;

  // Filled with it, text and arrow in white: a value that stands out, a changed one say.
  final Gradient? fill;

  // Tinted green in the menu, the icon right after it: a value worth finding again.
  final T? markedValue;
  final IconData? markIcon;

  // Overrides the density's: a field inside a table row.
  final double? height;

  // Wider than the field when the field is narrow.
  final double? menuWidth;

  // The hint in grey while nothing is chosen.
  final bool hintMuted;

  const AppDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.fill,
    this.markedValue,
    this.markIcon,
    this.height,
    this.menuWidth,
    this.hintMuted = false,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> with CloseOnResize
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry?   _overlayEntry;

  final GlobalKey<_DropdownOverlayState> _menuKey = GlobalKey();
  bool _isHovered = false;

  @override
  bool get menuShown => _overlayEntry != null;

  @override
  void closeMenuForResize() => _closeMenu();

  // As wide as its widest label needs to stand whole, set as a chosen one; options with
  // a leading or trailing widget count their label only.
  double _menuNeed()
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle style = DefaultTextStyle.of(context).style.merge(_itemStyle(selected: true));
    var widest = 0.0;

    for (final option in widget.options)
    {
      if (option.isSeparator)
      {
        continue;
      }

      final painter = TextPainter(
        text: TextSpan(text: option.label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();

      final bool marked = widget.markIcon != null && widget.markedValue != null && widget.markedValue == option.value;

      widest = math.max(widest, painter.width + (marked ? 8 + 16 + _markInset : 0));
    }

    // And a pixel or two against rounding.
    return widest + _itemSides + _scrollbarLane + 2;
  }

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);
    final screenH   = MediaQuery.of(context).size.height;
    final screenW   = MediaQuery.of(context).size.width;

    // Never narrower than its options need, within the window; past its right edge it moves left.
    final double menuWidth = math.min(
      math.max(widget.menuWidth ?? size.width, _menuNeed()),
      screenW - 2 * _menuMargin,
    );
    final double menuLeft = math.max(_menuMargin, math.min(offset.dx, screenW - _menuMargin - menuWidth));

    final spaceBottom = screenH - offset.dy - size.height;
    final spaceTop    = offset.dy;
    final showAbove   = spaceBottom < 250 && spaceTop > spaceBottom;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:    _closeMenu,
              child:    Container(),
            ),
          ),
          Positioned(
            top:    showAbove ? null : offset.dy + size.height + 8,
            bottom: showAbove ? screenH - offset.dy + 8 : null,
            left:   menuLeft,
            width:  menuWidth,
            child: _DropdownOverlay<T>(
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              showAbove:    showAbove,
              markedValue:  widget.markedValue,
              markIcon:     widget.markIcon,
              onSelected:   (val)
              {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _closeMenu() async
  {
    if (_overlayEntry != null)
    {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted)
      {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedOption = widget.options.firstWhere(
      (o) => !o.isSeparator && o.value == widget.value,
      orElse: () => AppDropdownOption(value: widget.value, label: widget.hint),
    );

    final String displayText = selectedOption.label;
    final bool   isExpanded  = _overlayEntry != null;
    final bool   page        = AppPageDensity.of(context);
    final bool   dense       = page || AppDialogDensity.of(context);
    final Gradient? fill     = widget.fill;
    final bool   lit         = _isHovered || isExpanded;
    final bool   unchosen    = widget.hintMuted && !widget.options.any((o) => !o.isSeparator && o.value == widget.value);

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        // Sized outside the animation: only the border fades, a resize never animates the height.
        child: SizedBox(
          key:    _buttonKey,
          height: widget.height ?? (page ? _pageFieldHeight : (dense ? _denseFieldHeight : _fieldHeight)),
          // The fill is painted outside the animation: a surface lerped into a gradient passes through pink.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill == null ? _fieldSurface : null,
              gradient: fill,
              borderRadius: BorderRadius.circular(dense ? _denseFieldRadius : _fieldRadius),
            ),
            child: AnimatedContainer(
              duration:   const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dense ? _denseFieldRadius : _fieldRadius),
                border: Border.all(
                  color: lit ? AppTheme.trialGold : (fill == null ? AppTheme.trialLine : _clearGold),
                  width: _fieldBorder,
                ),
              ),
              child: Padding(
                padding: widget.height == null
                    ? EdgeInsets.symmetric(horizontal: dense ? 14 : 16)
                    : const EdgeInsets.only(left: 12, right: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (selectedOption.leading case final Widget leading) ...[
                      leading,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        displayText,
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize:   page ? 13.5 : (dense ? 14 : 15),
                          fontWeight: fill == null ? FontWeight.w600 : FontWeight.w700,
                          color:      fill != null ? Colors.white : (unchosen ? AppTheme.trialMutedText : AppTheme.trialInk),
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: widget.height == null ? null : 20,
                      color: fill == null ? AppTheme.trialTealDeep : Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlay<T> extends StatefulWidget
{
  final T?                       currentValue;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?>         onSelected;
  final bool                     showAbove;
  final T?                       markedValue;
  final IconData?                markIcon;

  const _DropdownOverlay({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    this.showAbove = false,
    this.markedValue,
    this.markIcon,
  });

  @override
  State<_DropdownOverlay<T>> createState() => _DropdownOverlayState<T>();
}

class _DropdownOverlayState<T> extends State<_DropdownOverlay<T>>
{
  final bool _animates = VisualEffects.on;

  late bool              _expanded         = !_animates;
  final ScrollController _scrollController = ScrollController();

  // The chosen option, so a long menu opens on it.
  final GlobalKey _selectedKey = GlobalKey();

  @override
  void initState()
  {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (!mounted)
      {
        return;
      }

      if (_animates)
      {
        setState(() => _expanded = true);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _showSelected());
    });
  }

  // A third of the way down: the options before it stay in sight.
  void _showSelected()
  {
    final BuildContext? item = _selectedKey.currentContext;

    if (!mounted || item == null || !_scrollController.hasClients)
    {
      return;
    }

    final RenderBox box = item.findRenderObject()! as RenderBox;
    final RenderBox list = context.findRenderObject()! as RenderBox;
    final double top = box.localToGlobal(Offset.zero, ancestor: list).dy + _scrollController.offset;
    final double room = _scrollController.position.viewportDimension;
    final double target = (top - room / 3).clamp(0, _scrollController.position.maxScrollExtent);

    _scrollController.jumpTo(target);
  }

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> hide() async
  {
    if (!_animates)
    {
      return;
    }

    if (mounted)
    {
      setState(() => _expanded = false);
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(_menuRadius),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          // Not zero: a zero-length AnimatedSize finishes inside its own layout and asserts.
          duration:  _animates ? const Duration(milliseconds: 180) : const Duration(microseconds: 1),
          curve:     Curves.easeOut,
          alignment: widget.showAbove ? Alignment.bottomCenter : Alignment.topCenter,
          child:     _expanded
              ? ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: RawScrollbar(
                    controller:      _scrollController,
                    thumbVisibility: true,
                    thickness:       6,
                    radius:          const Radius.circular(10),
                    thumbColor:      AppTheme.trialMutedText,
                    child: ScrollEdgeFade(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding:    const EdgeInsets.only(top: 8, bottom: 8, right: _scrollbarLane),
                        child: Column(
                          mainAxisSize:       MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:           widget.options.map((option)
                          {
                            if (option.isSeparator)
                            {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical:   4.0,
                                ),
                                child: Divider(
                                  height:    1,
                                  thickness: 1,
                                  color:     AppTheme.trialLine,
                                ),
                              );
                            }

                            final bool isSelected = widget.currentValue == option.value;

                            return _DropdownItem(
                              key:        isSelected ? _selectedKey : null,
                              text:       option.label,
                              isSelected: isSelected,
                              marked:     widget.markedValue != null && widget.markedValue == option.value,
                              markIcon:   widget.markIcon,
                              leading:    option.leading,
                              trailing:   option.trailing,
                              enabled:    option.enabled,
                              disabledReason: option.disabledReason,
                              onTap:      () => widget.onSelected(option.value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(height: 0, width: double.infinity),
        ),
      ),
    );
  }
}

class _DropdownItem extends StatefulWidget
{
  final String       text;
  final bool         isSelected;
  final bool         marked;
  final IconData?    markIcon;
  final Widget?      leading;
  final Widget?      trailing;
  final bool         enabled;
  final String?      disabledReason;
  final VoidCallback onTap;

  const _DropdownItem({
    super.key,
    required this.text,
    required this.isSelected,
    this.marked = false,
    this.markIcon,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.disabledReason,
    required this.onTap,
  });

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool enabled = widget.enabled;
    final bool lit = enabled && _hover;

    final Widget row = Row(
      children: [
        AnimatedContainer(
          duration:   const Duration(milliseconds: 150),
          width:      2,
          height:     (lit || widget.isSelected) ? 16 : 0,
          decoration: BoxDecoration(
            color:        AppTheme.trialGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        if (widget.leading case final Widget leading) ...[
          leading,
          const SizedBox(width: 10),
        ],
        // The mark right after the label, which keeps its whole width: never shrunk to make room.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style:    _itemStyle(selected: widget.isSelected),
                ),
              ),
              if (widget.marked && widget.markIcon != null) ...[
                const SizedBox(width: 8),
                Icon(widget.markIcon, size: 16, color: _markAccent),
              ],
            ],
          ),
        ),
        if (widget.trailing case final Widget trailing) ...[
          const SizedBox(width: 10),
          trailing,
        ],
      ],
    );

    final Widget item = MouseRegion(
      cursor:  enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: double.infinity,
          margin: widget.marked ? const EdgeInsets.only(left: _markInset) : EdgeInsets.zero,
          padding: EdgeInsets.only(
            left: widget.marked ? 16 - _markInset : 16,
            right: 16,
            top: 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: widget.marked ? _markSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(_markRadius),
          ),
          child: enabled ? row : Opacity(opacity: _mutedOpacity, child: row),
        ),
      ),
    );

    final String? reason = widget.disabledReason;

    if (enabled || reason == null)
    {
      return item;
    }

    return AppTooltip(waitDuration: const Duration(milliseconds: 400), message: reason, child: item);
  }
}
