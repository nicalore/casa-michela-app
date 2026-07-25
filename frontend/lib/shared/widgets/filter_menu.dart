import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'overflow_tooltip_text.dart';

enum SortCriterion
{
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const SortCriterion(this.label);
}

class FilterOption<T>
{
  final T value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

class CustomFilterMenu<T> extends StatefulWidget
{
  final String hint;
  final IconData icon;
  final T? value;
  final List<FilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback onClear;
  final double menuWidth;
  final bool showClearIcon;

  const CustomFilterMenu({
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
    required this.showClearIcon,
    super.key,
  });

  @override
  State<CustomFilterMenu<T>> createState() => _CustomFilterMenuState<T>();
}

class _CustomFilterMenuState<T> extends State<CustomFilterMenu<T>>
{
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey<_FilterOverlayContentState> _menuKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 8,
            left: offset.dx,
            child: _FilterOverlayContent<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              menuWidth: widget.menuWidth,
              onSelected: (value)
              {
                widget.onChanged(value);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    // rootOverlay bypasses any nested Navigator between here and the screen, so
    // the menu is positioned in real screen space: without it a menu opened
    // inside a dialog lands offset by the dialog's own origin.
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  // The overlay is removed only after the collapse animation has run, so the
  // menu does not disappear abruptly.
  void _closeMenu() async
  {
    if (_overlayEntry == null)
    {
      return;
    }

    await _menuKey.currentState?.hide();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context)
  {
    final isActive = widget.value != null;
    final isHighlighted = _isHovered || isActive;

    var displayText = widget.hint;

    if (isActive)
    {
      final matches = widget.options.where((option) => option.value == widget.value);
      displayText = matches.isEmpty ? '' : matches.first.label;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: EdgeInsets.only(
            left: 16,
            right: (isActive && widget.showClearIcon) ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.surfaceHover : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: OverflowTooltipText(
                  text: displayText,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppTheme.primary : AppTheme.mutedText,
                  ),
                ),
              ),
              if (isActive && widget.showClearIcon) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: ()
                  {
                    widget.onClear();

                    if (_overlayEntry != null)
                    {
                      _closeMenu();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOverlayContent<T> extends StatefulWidget
{
  final T? currentValue;
  final List<FilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;

  const _FilterOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_FilterOverlayContent<T>> createState() => _FilterOverlayContentState<T>();
}

class _FilterOverlayContentState<T> extends State<_FilterOverlayContent<T>>
{
  // The same value drives the AnimatedSize and the delay awaited by hide():
  // they must stay in sync or the overlay is torn down mid animation.
  static const Duration _expandDuration = Duration(milliseconds: 180);

  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    // Expanding on the next frame is what makes the opening animation
    // visible: on the first frame the overlay is laid out collapsed.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(() => _expanded = false);
    }

    await Future.delayed(_expandDuration);
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.overlayShadow,
        ),
        child: AnimatedSize(
          duration: _expandDuration,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.options.map((option)
                      {
                        return _FilterMenuItem(
                          text: option.label,
                          isSelected: widget.currentValue == option.value,
                          onTap: () => widget.onSelected(option.value),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : SizedBox(width: widget.menuWidth, height: 0),
        ),
      ),
    );
  }
}

class _FilterMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterMenuItem> createState() => _FilterMenuItemState();
}

class _FilterMenuItemState extends State<_FilterMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final isHighlighted = _hover || widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: isHighlighted ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.primary,
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