import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'overflow_tooltip_text.dart';

// What a field of a dialog is made of. The same numbers AppTextField uses,
// which is what makes a dropdown here look like a plain field there.
const Color _fieldSurface = Color(0xFFFBFDFC);
const double _fieldRadius = 14;
const double _fieldBorder = 2;

// The rounded box a menu opens in, and the room its scrollbar needs on the
// right so that it does not run under the last letters of an option.
const double _menuRadius = 16;
const double _scrollbarLane = 10;

// One row of a dropdown: what it stands for, and what is written on it. A
// separator is a line with nothing behind it, for telling one group of answers
// from the next.
class AppDropdownOption<T>
{
  final T?     value;
  final String label;
  final bool   isSeparator;

  AppDropdownOption({
    this.value,
    this.label       = '',
    this.isSeparator = false
  });
}

// A field that opens its answers under itself.
//
// The app's other way of asking — a field that opens a window with a search in
// it — is what a long list needs: a school, a person, a discipline out of
// hundreds. Where the answers are ten and they all fit under the field, that
// window is a room to walk into and back out of for something that could have
// been a glance.
class AppDropdownField<T> extends StatefulWidget
{
  final String                   hint;
  final T?                       value;
  final List<AppDropdownOption<T>> options;
  final ValueChanged<T?>         onChanged;

  const AppDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>>
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry?   _overlayEntry;

  final GlobalKey<_DropdownOverlayState> _menuKey = GlobalKey();
  bool _isHovered = false;

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
            left:   offset.dx,
            width:  size.width,
            child: _DropdownOverlay<T>(
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              showAbove:    showAbove,
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

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key:        _buttonKey,
          duration:   const Duration(milliseconds: 200),
          height:     50,
          padding:    const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _fieldSurface,
            borderRadius: BorderRadius.circular(_fieldRadius),
            // Gold while the pointer is on it or the list is open, which is the
            // mark this app puts wherever the attention is.
            border: Border.all(
              color: _isHovered || isExpanded ? AppTheme.trialGold : AppTheme.trialLine,
              width: _fieldBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                    color:      AppTheme.trialInk,
                  ),
                ),
              ),
              Icon(
                isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppTheme.trialTealDeep,
              ),
            ],
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

  const _DropdownOverlay({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    this.showAbove = false,
  });

  @override
  State<_DropdownOverlay<T>> createState() => _DropdownOverlayState<T>();
}

class _DropdownOverlayState<T> extends State<_DropdownOverlay<T>>
{
  bool                   _expanded         = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> hide() async
  {
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
        // Clipped, or the scrollbar of a long list is painted down the outside
        // of the rounded box instead of inside it — which is what the list of
        // suggestions next door has always done.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(_menuRadius),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          duration:  const Duration(milliseconds: 180),
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

                          return _DropdownItem(
                            text:       option.label,
                            isSelected: widget.currentValue == option.value,
                            onTap:      () => widget.onSelected(option.value),
                          );
                        }).toList(),
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
  final VoidCallback onTap;

  const _DropdownItem({
    required this.text,
    required this.isSelected,
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
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // The bar on the left is the whole mark, as it is in the rail: a row
          // that also fills reads as chosen rather than as pointed at.
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration:   const Duration(milliseconds: 150),
                width:      2,
                height:     (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color:        AppTheme.trialGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style:    GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:      AppTheme.trialTealDeep,
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
