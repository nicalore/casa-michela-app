import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';

class StatFilterOption<T>
{
  final T value;
  final String label;

  const StatFilterOption({required this.value, required this.label});
}

// Dropdown used across the statistics tabs. Deliberately separate from
// CustomFilterMenu in shared/widgets: this variant prints the hint next to the
// value, carries a rotating chevron and sizes its overlay to the content, which
// would need several extra flags on the shared one.
class StatFilterMenu<T> extends StatefulWidget
{
  final String hint;
  final T value;
  final List<StatFilterOption<T>> options;
  final ValueChanged<T> onChanged;

  const StatFilterMenu({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  @override
  State<StatFilterMenu<T>> createState() => _StatFilterMenuState<T>();
}

class _StatFilterMenuState<T> extends State<StatFilterMenu<T>>
{
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey<_StatFilterOverlayContentState<T>> _menuKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;
  bool _isMenuOpen = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    setState(() => _isMenuOpen = true);

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
            child: _StatFilterOverlayContent<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
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

    // The statistics tabs wrap their content in a nested Navigator, which brings
    // its own Overlay: inserting there would offset the menu by the nested
    // route's origin. The root overlay is the only place whose coordinates match
    // the localToGlobal values computed above.
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

    setState(() => _isMenuOpen = false);
    await _menuKey.currentState?.hide();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedOption = widget.options.firstWhere(
      (option) => option.value == widget.value,
      orElse: () => StatFilterOption(value: widget.value, label: ''),
    );

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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.surfaceHover : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.hint}: ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText,
                ),
              ),
              Text(
                selectedOption.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _isMenuOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatFilterOverlayContent<T> extends StatefulWidget
{
  final T currentValue;
  final List<StatFilterOption<T>> options;
  final ValueChanged<T> onSelected;

  const _StatFilterOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_StatFilterOverlayContent<T>> createState() => _StatFilterOverlayContentState<T>();
}

class _StatFilterOverlayContentState<T> extends State<_StatFilterOverlayContent<T>>
{
  // The same value drives the AnimatedSize and the delay awaited by hide():
  // they must stay in sync or the overlay is torn down mid animation.
  static const Duration _expandDuration = Duration(milliseconds: 180);

  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    // Expanding on the next frame is what makes the opening animation visible:
    // on the first frame the overlay is laid out collapsed.
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
      // IntrinsicWidth lets the panel follow the longest option instead of a
      // fixed width, since these menus hold anything from months to years.
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 300, minWidth: 130),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.options.map((option)
                        {
                          return _StatFilterMenuItem(
                            text: option.label,
                            isSelected: widget.currentValue == option.value,
                            onTap: () => widget.onSelected(option.value),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _StatFilterMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatFilterMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_StatFilterMenuItem> createState() => _StatFilterMenuItemState();
}

class _StatFilterMenuItemState extends State<_StatFilterMenuItem>
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