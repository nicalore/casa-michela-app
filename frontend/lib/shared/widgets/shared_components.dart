import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 1. Barra di ricerca animata
class AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const AnimatedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuint,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: _isFocused ? const Color(0xFF003C82).withValues(alpha: 0.3) : Colors.transparent, 
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused ? const Color(0x15003C82) : const Color(0x0A000000), 
            offset: const Offset(0, 4), 
            blurRadius: _isFocused ? 24 : 16,
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: const Color(0xFF003C82), 
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18, 
          fontWeight: FontWeight.w500, 
          color: const Color(0xFF003C82),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18, 
            fontWeight: FontWeight.w500, 
            color: const Color(0xFFB3B3B3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28), 
          suffixIcon: Icon(
            Icons.search, 
            size: 32, 
            color: _isFocused ? const Color(0xFF003C82) : const Color(0xFFB3B3B3),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 64, minHeight: 50),
        ),
      ),
    );
  }
}

/// 2. Menù a tendina per l'ordinamento
class SortDropdownMenu extends StatefulWidget {
  final bool isAscending;
  final ValueChanged<bool> onChanged;

  const SortDropdownMenu({super.key, required this.isAscending, required this.onChanged});

  @override
  State<SortDropdownMenu> createState() => _SortDropdownMenuState();
}

class _SortDropdownMenuState extends State<SortDropdownMenu> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_DropdownOverlayContentState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
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
            child: _DropdownOverlayContent(
              key: _menuKey,
              isAscending: widget.isAscending,
              onSelected: (val) {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() async {
    if (_overlayEntry != null) {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _isHovered ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert_rounded, color: Color(0xFF003C82), size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isAscending ? 'Nome (A - Z)' : 'Nome (Z - A)',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF003C82)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOverlayContent extends StatefulWidget {
  final bool isAscending;
  final ValueChanged<bool> onSelected;

  const _DropdownOverlayContent({super.key, required this.isAscending, required this.onSelected});

  @override
  State<_DropdownOverlayContent> createState() => _DropdownOverlayContentState();
}

class _DropdownOverlayContentState extends State<_DropdownOverlayContent> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _expanded = true);
    });
  }

  Future<void> hide() async {
    if (mounted) setState(() => _expanded = false);
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2)],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DropdownMenuItem(text: 'Nome (A - Z)', isSelected: widget.isAscending, onTap: () => widget.onSelected(true)),
                    _DropdownMenuItem(text: 'Nome (Z - A)', isSelected: !widget.isAscending, onTap: () => widget.onSelected(false)),
                  ],
                ),
              ) 
            : const SizedBox(width: 170, height: 0),
        ),
      ),
    );
  }
}

class _DropdownMenuItem extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _DropdownMenuItem({required this.text, required this.isSelected, required this.onTap});

  @override
  State<_DropdownMenuItem> createState() => _DropdownMenuItemState();
}

class _DropdownMenuItemState extends State<_DropdownMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent, 
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(color: const Color(0xFF003C82), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Text(
                widget.text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF003C82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3. Bottone Animato Principale (SALVA, ANNULLA, ELIMINA, CREA)
class AnimatedActionButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color baseColor;
  final Color hoverColor;
  final VoidCallback onPressed;

  const AnimatedActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.baseColor,
    required this.hoverColor,
    required this.onPressed,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuint,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuint,
            height: 56,
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverColor : widget.baseColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: widget.baseColor.withValues(alpha: _isHovered ? 0.4 : 0.2), offset: Offset(0, _isHovered ? 8 : 4), blurRadius: _isHovered ? 16 : 8)
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(widget.text, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 4. Bottone Icona con Dissolvenza Sfondo (usato per Rimuovi - e la X chiudi nei tab con sfocatura)
class FadeHoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const FadeHoverIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<FadeHoverIconButton> createState() => _FadeHoverIconButtonState();
}

class _FadeHoverIconButtonState extends State<FadeHoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.hoverColor.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ),
    );
  }
}

/// 5. Bottone Icona Statico (usato per la X chiudi nei tab normali)
class StaticHoverIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverColor;
  final VoidCallback onTap;

  const StaticHoverIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<StaticHoverIconButton> createState() => _StaticHoverIconButtonState();
}

class _StaticHoverIconButtonState extends State<StaticHoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.hoverColor.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ),
    );
  }
}

/// 6. Testo auto-ridimensionante
class AutoResizeText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final TextStyle style;

  const AutoResizeText({
    super.key,
    required this.text,
    required this.maxFontSize,
    required this.minFontSize,
    required this.maxLines,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double currentFontSize = maxFontSize;
        final textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: maxLines);

        while (currentFontSize > minFontSize) {
          textPainter.text = TextSpan(text: text, style: style.copyWith(fontSize: currentFontSize));
          textPainter.layout(maxWidth: constraints.maxWidth);
          if (!textPainter.didExceedMaxLines) break; 
          currentFontSize -= 1;
        }

        return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: currentFontSize));
      }
    );
  }
}