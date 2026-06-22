import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/role_label_mapper.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/study_program_item.dart';
import './models/person_item.dart';
import '../../../shared/widgets/snackbar.dart';

class WizardAnimatedActionButton extends StatefulWidget {
  final String       text;
  final IconData     icon;
  final Color        baseColor;
  final Color        hoverColor;
  final VoidCallback onPressed;

  const WizardAnimatedActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.baseColor,
    required this.hoverColor,
    required this.onPressed,
  });

  @override
  State<WizardAnimatedActionButton> createState() => _WizardAnimatedActionButtonState();
}

class _WizardAnimatedActionButtonState extends State<WizardAnimatedActionButton> {
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
                BoxShadow(
                  color: widget.baseColor.withValues(alpha: _isHovered ? 0.4 : 0.2), 
                  offset: Offset(0, _isHovered ? 8 : 4), 
                  blurRadius: _isHovered ? 16 : 8,
                )
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.text, 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, 
                    fontWeight: FontWeight.w700, 
                    color: Colors.white, 
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WizardOutlinedActionButton extends StatefulWidget {
  final String       text; 
  final IconData     icon; 
  final VoidCallback onPressed; 
  
  const WizardOutlinedActionButton({
    super.key,
    required this.text, 
    required this.icon, 
    required this.onPressed,
  }); 
  
  @override 
  State<WizardOutlinedActionButton> createState() => _WizardOutlinedActionButtonState(); 
}

class _WizardOutlinedActionButtonState extends State<WizardOutlinedActionButton> {
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
              color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: const Color(0xFF003C82), width: 1.5),
            ), 
            alignment: Alignment.center, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(widget.icon, color: const Color(0xFF003C82), size: 20), 
                const SizedBox(width: 8), 
                Text(
                  widget.text, 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, 
                    fontWeight: FontWeight.w700, 
                    color: const Color(0xFF003C82), 
                    letterSpacing: 1.2,
                  ),
                ),
              ]
            ),
          ),
        ),
      ),
    ); 
  } 
}

class WizardAnimatedTextField extends StatefulWidget {
  final TextEditingController     controller;
  final String                    hint;
  final String?                   errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType?            keyboardType;
  final ValueChanged<String>?     onChanged;

  const WizardAnimatedTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.errorText,
    this.inputFormatters,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<WizardAnimatedTextField> createState() => _WizardAnimatedTextFieldState();
}

class _WizardAnimatedTextFieldState extends State<WizardAnimatedTextField> {
  final FocusNode _focusNode = FocusNode();
  bool            _isFocused = false;

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
    final hasError    = widget.errorText != null;
    final borderColor = hasError ? const Color(0xFFE53935) : (_isFocused ? const Color(0xFF003C82) : const Color(0xFFE2E8F0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor, 
              width: (_isFocused || hasError) ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  inputFormatters: widget.inputFormatters,
                  keyboardType: widget.keyboardType,
                  cursorColor: const Color(0xFF003C82), 
                  onChanged: widget.onChanged,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600, 
                    color: const Color(0xFF2A2A2A),
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 16, 
                      fontWeight: FontWeight.w500, 
                      color: const Color(0xFFB3B3B3),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(left: 16, right: hasError ? 8 : 16), 
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Tooltip(
                    message: widget.errorText!,
                    textStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 22),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class WizardAnimatedOverlayDropdown extends StatefulWidget {
  final String?              value;
  final List<String>         items;
  final String               hint;
  final String?              errorText;
  final ValueChanged<String> onChanged;

  const WizardAnimatedOverlayDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    this.errorText,
    required this.onChanged,
  });

  @override
  State<WizardAnimatedOverlayDropdown> createState() => _WizardAnimatedOverlayDropdownState();
}

class _WizardAnimatedOverlayDropdownState extends State<WizardAnimatedOverlayDropdown> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_WizardOverlayDropdownContentState> _menuKey = GlobalKey();
  
  bool _isFocused = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }
    
    setState(() => _isFocused = true);

    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);

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
            width: size.width,
            child: _WizardOverlayDropdownContent(
              key: _menuKey,
              currentValue: widget.value,
              items: widget.items,
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
      if (mounted) {
        setState(() => _isFocused = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool  hasValue    = widget.value != null;
    final bool  hasError    = widget.errorText != null;
    final Color borderColor = hasError ? const Color(0xFFE53935) : (_isFocused ? const Color(0xFF003C82) : const Color(0xFFE2E8F0));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: (_isFocused || hasError) ? 2.0 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasValue ? widget.value! : widget.hint,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: hasValue ? const Color(0xFF2A2A2A) : const Color(0xFFB3B3B3),
                  ),
                ),
              ),
              if (hasError) ...[
                Tooltip(
                  message: widget.errorText!,
                  textStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 22),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded, 
                color: _isFocused ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardOverlayDropdownContent extends StatefulWidget {
  final String?              currentValue;
  final List<String>         items;
  final ValueChanged<String> onSelected;

  const _WizardOverlayDropdownContent({
    super.key,
    required this.currentValue,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_WizardOverlayDropdownContent> createState() => _WizardOverlayDropdownContentState();
}

class _WizardOverlayDropdownContentState extends State<_WizardOverlayDropdownContent> {
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
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.items.map((item) {
                      return WizardDropdownMenuItem(
                        text: item, 
                        isSelected: widget.currentValue == item, 
                        onTap: () => widget.onSelected(item),
                      );
                    }).toList(),
                  ),
                ),
              ) 
            : const SizedBox(width: double.infinity, height: 0),
        ),
      ),
    );
  }
}

class WizardDropdownMenuItem extends StatefulWidget {
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const WizardDropdownMenuItem({
    super.key,
    required this.text, 
    required this.isSelected, 
    required this.onTap,
  });

  @override
  State<WizardDropdownMenuItem> createState() => _WizardDropdownMenuItemState();
}

class _WizardDropdownMenuItemState extends State<WizardDropdownMenuItem> {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent, 
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF003C82), 
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFF2A2A2A),
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

class WizardDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text.length >= newValue.text.length) {
      return newValue;
    }
    
    String text = newValue.text;
    
    if (text.length == 2 && !text.contains('/')) {
      text += '/';
    } else if (text.length == 5 && text.indexOf('/', 3) == -1) {
      text += '/';
    }
    
    if (text.length > 10) {
      return oldValue;
    }
    
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class WizardFormSectionCard extends StatelessWidget {
  final String       title;
  final Widget       leadingIcon;
  final List<Widget> children;
  final bool         isCompact;

  const WizardFormSectionCard({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.children,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 28 : 40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCompact)
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leadingIcon,
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 40, 
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0xFFE8EEF7), shape: BoxShape.circle),
                  child: leadingIcon is WizardStaticAvatar 
                      ? Icon((leadingIcon as WizardStaticAvatar).icon, size: 20, color: const Color(0xFF003C82)) 
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003C82),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: isCompact ? 16.0 : 24.0),
            child: const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF1F5F9),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WizardFormInputRow extends StatelessWidget {
  final String label;
  final Widget inputWidget;

  const WizardFormInputRow({
    super.key,
    required this.label,
    required this.inputWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 140,
          height: 50,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7A7A7A),
              height: 1.2,
            ),
          ),
        ),
        Expanded(child: inputWidget),
      ],
    );
  }
}

class WizardStaticAvatar extends StatelessWidget {
  final IconData icon;

  const WizardStaticAvatar({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 44,
        color: const Color(0xFF003C82),
      ),
    );
  }
}

class WizardProfilePhotoUploader extends StatefulWidget {
  final Uint8List?               imageBytes;
  final ValueChanged<Uint8List?> onImagePicked;

  const WizardProfilePhotoUploader({
    super.key,
    required this.imageBytes, 
    required this.onImagePicked,
  });

  @override
  State<WizardProfilePhotoUploader> createState() => _WizardProfilePhotoUploaderState();
}

class _WizardProfilePhotoUploaderState extends State<WizardProfilePhotoUploader> {
  final ImagePicker _picker = ImagePicker();
  bool _isHoveringUpload = false;
  bool _isHoveringTrash = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      widget.onImagePicked(bytes);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context: context, message: 'Errore durante la selezione dell\'immagine.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF7),
            shape: BoxShape.circle,
            image: widget.imageBytes != null 
                ? DecorationImage(image: MemoryImage(widget.imageBytes!), fit: BoxFit.cover) 
                : null,
          ),
          child: widget.imageBytes == null 
              ? const Icon(Icons.person_outline, size: 48, color: Color(0xFF003C82)) 
              : null,
        ),
        const SizedBox(width: 24),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHoveringUpload = true),
                onExit: (_) => setState(() => _isHoveringUpload = false),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isHoveringUpload ? const Color(0xFFF5F8FC) : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF003C82), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_rounded, size: 20, color: Color(0xFF003C82)),
                        const SizedBox(width: 8),
                        Text(
                          widget.imageBytes == null ? 'Carica foto' : 'Cambia foto',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF003C82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.imageBytes != null) ...[
                const SizedBox(width: 12),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHoveringTrash = true),
                  onExit: (_) => setState(() => _isHoveringTrash = false),
                  child: GestureDetector(
                    onTap: () => widget.onImagePicked(null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isHoveringTrash 
                            ? const Color(0xFFE53935).withValues(alpha: 0.15) 
                            : const Color(0xFFE53935).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 22, color: Color(0xFFE53935)),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}

class WizardDisabledDropdownPlaceholder extends StatelessWidget {
  final String hint;
  
  const WizardDisabledDropdownPlaceholder({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hint,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFCBD5E1),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded, 
            color: Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }
}

class WizardSelectionCard extends StatefulWidget {
  final String       title; 
  final String       subtitle; 
  final IconData     icon; 
  final bool         isSelected; 
  final bool         isHorizontal; 
  final bool         isCompact;
  final VoidCallback onTap;

  const WizardSelectionCard({
    super.key,
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.isSelected, 
    required this.onTap, 
    this.isHorizontal = false,
    this.isCompact = false,
  });

  @override 
  State<WizardSelectionCard> createState() => _WizardSelectionCardState();
}

class _WizardSelectionCardState extends State<WizardSelectionCard> {
  bool _hover = false;

  @override 
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _hover = true), 
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.isHorizontal ? (widget.isCompact ? 600 : 700) : (widget.isCompact ? 400 : 500),
          constraints: BoxConstraints(
            minHeight: widget.isHorizontal ? (widget.isCompact ? 80 : 110) : (widget.isCompact ? 140 : 200),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 24 : 32, 
            vertical: widget.isCompact ? 16 : 24
          ),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (_hover || widget.isSelected) ? const Color(0xFF003C82) : Colors.transparent, 
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000), 
                offset: Offset(0, 6), 
                blurRadius: 20,
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.icon, 
                size: widget.isCompact ? 32 : 42, 
                color: const Color(0xFF003C82),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title, 
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: widget.isCompact ? 18 : 20, 
                        fontWeight: FontWeight.w700, 
                        color: const Color(0xFF003C82),
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      SizedBox(height: widget.isCompact ? 4 : 6),
                      Text(
                        widget.subtitle, 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: widget.isCompact ? 13 : 15, 
                          color: const Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WizardCarouselArrowButton extends StatefulWidget {
  final IconData     icon;
  final bool         isDisabled;
  final VoidCallback onTap;

  const WizardCarouselArrowButton({
    super.key,
    required this.icon,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<WizardCarouselArrowButton> createState() => _WizardCarouselArrowButtonState();
}

class _WizardCarouselArrowButtonState extends State<WizardCarouselArrowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: widget.isDisabled 
                ? const Color(0xFFF1F5F9) 
                : (_isHovered ? const Color(0xFF003C82) : Colors.white),
            shape: BoxShape.circle,
            boxShadow: widget.isDisabled ? null : const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              )
            ],
          ),
          child: Icon(
            widget.icon,
            size: 32,
            color: widget.isDisabled 
                ? const Color(0xFFB3B3B3) 
                : (_isHovered ? Colors.white : const Color(0xFF003C82)),
          ),
        ),
      ),
    );
  }
}

class WizardAnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  final String                hintText;

  const WizardAnimatedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<WizardAnimatedSearchBar> createState() => _WizardAnimatedSearchBarState();
}

class _WizardAnimatedSearchBarState extends State<WizardAnimatedSearchBar> {
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
          fontSize: 16, 
          fontWeight: FontWeight.w600, 
          color: const Color(0xFF003C82),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            color: const Color(0xFFB3B3B3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28, bottom: 2), 
          suffixIcon: Icon(
            Icons.search, 
            size: 24, 
            color: _isFocused ? const Color(0xFF003C82) : const Color(0xFFB3B3B3),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 64, minHeight: 50),
        ),
      ),
    );
  }
}

class WizardFilterOption<T> {
  final T      value;
  final String label;

  WizardFilterOption({required this.value, required this.label});
}

class WizardFilterMenu<T> extends StatefulWidget {
  final String                 hint;
  final IconData               icon;
  final T?                     value;
  final List<WizardFilterOption<T>> options;
  final ValueChanged<T>        onChanged;
  final VoidCallback           onClear;
  final double                 menuWidth;
  final bool                   showClearIcon;

  const WizardFilterMenu({
    super.key,
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
    required this.showClearIcon,
  });

  @override
  State<WizardFilterMenu<T>> createState() => _WizardFilterMenuState<T>();
}

class _WizardFilterMenuState<T> extends State<WizardFilterMenu<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_WizardFilterOverlayContentState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }
    
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);

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
            child: _WizardFilterOverlayContent<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              menuWidth: widget.menuWidth,
              onSelected: (val) {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          )
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
    final bool isActive = widget.value != null;
    String displayText  = widget.hint;

    if (isActive) {
      final selectedOption = widget.options.firstWhere(
        (o) => o.value == widget.value,
        orElse: () => WizardFilterOption(value: widget.value!, label: ''),
      );
      displayText = selectedOption.label;
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
          height: 50,
          padding: EdgeInsets.only(left: 16, right: (isActive && widget.showClearIcon) ? 12 : 16),
          decoration: BoxDecoration(
            color: _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _isHovered || isActive ? const Color(0xFF003C82) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: const Color(0xFF003C82), size: 18),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
                  ),
                ),
              ),
              if (isActive && widget.showClearIcon) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    widget.onClear();
                    if (_overlayEntry != null) _closeMenu();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935)),
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

class _WizardFilterOverlayContent<T> extends StatefulWidget {
  final T?                     currentValue;
  final List<WizardFilterOption<T>> options;
  final ValueChanged<T>        onSelected;
  final double                 menuWidth;

  const _WizardFilterOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_WizardFilterOverlayContent<T>> createState() => _WizardFilterOverlayContentState<T>();
}

class _WizardFilterOverlayContentState<T> extends State<_WizardFilterOverlayContent<T>> {
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
        width: widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.options.map((option) {
                        return WizardFilterMenuItem(
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

class WizardFilterMenuItem extends StatefulWidget {
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const WizardFilterMenuItem({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<WizardFilterMenuItem> createState() => _WizardFilterMenuItemState();
}

class _WizardFilterMenuItemState extends State<WizardFilterMenuItem> {
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color: const Color(0xFF003C82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF003C82),
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

class WizardSubjectGridCard extends StatefulWidget {
  final AssociationSubjectItem subject;
  final bool                   isSelected;
  final int                    selectedCount;
  final VoidCallback           onTap;

  const WizardSubjectGridCard({
    super.key,
    required this.subject,
    required this.isSelected,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  State<WizardSubjectGridCard> createState() => _WizardSubjectGridCardState();
}

class _WizardSubjectGridCardState extends State<WizardSubjectGridCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 320,
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (_isHovering || widget.isSelected) ? const Color(0xFF003C82) : Colors.transparent, 
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000), 
                offset: Offset(0, 4), 
                blurRadius: 16,
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.subject_rounded,
                size: 32,
                color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFB3B3B3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFF2A2A2A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isSelected ? (widget.selectedCount == 1 ? '1 percorso' : '${widget.selectedCount} percorsi') : 'Non assegnata',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WizardProgramsSelectionDialog extends StatefulWidget {
  final AssociationSubjectItem subject;
  final List<StudyProgramItem> programs;
  final Set<int>               initialSelected;
  final ValueChanged<Set<int>> onSave;
  final VoidCallback           onCancel;

  const WizardProgramsSelectionDialog({
    super.key,
    required this.subject,
    required this.programs,
    required this.initialSelected,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<WizardProgramsSelectionDialog> createState() => _WizardProgramsSelectionDialogState();
}

class _WizardProgramsSelectionDialogState extends State<WizardProgramsSelectionDialog> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelected);
    if (_selected.isEmpty) {
      _selected = Set.from(widget.programs.map((p) => p.id));
    }
  }

  void _selectAll() {
    setState(() {
      _selected = Set.from(widget.programs.map((p) => p.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.subject.name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                      ),
                    ),
                  ),
                  WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WizardTextLinkButton(text: 'Seleziona tutti', onTap: _selectAll),
                  const SizedBox(width: 24),
                  WizardTextLinkButton(text: 'Deseleziona tutti', onTap: _deselectAll),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.programs.map((prog) {
                    final bool isProgSelected = _selected.contains(prog.id);
                    return _WizardDisciplineChip(
                      label: prog.name,
                      isSelected: isProgSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selected.add(prog.id);
                          } else {
                            _selected.remove(prog.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: WizardAnimatedActionButton(
                      text: 'ANNULLA',
                      icon: Icons.close_rounded,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () {
                        widget.onCancel();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WizardAnimatedActionButton(
                      text: 'CONFERMA',
                      icon: Icons.check_circle_outline,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed: () {
                        widget.onSave(_selected);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardDisciplineChip extends StatefulWidget {
  final String             label;
  final bool               isSelected;
  final ValueChanged<bool> onSelected;

  const _WizardDisciplineChip({
    required this.label, 
    required this.isSelected, 
    required this.onSelected,
  });

  @override 
  State<_WizardDisciplineChip> createState() => _WizardDisciplineChipState();
}

class _WizardDisciplineChipState extends State<_WizardDisciplineChip> {
  bool _isHovered = false;

  @override 
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click, 
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFF003C82) : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), 
              width: 1.0,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, 
              fontWeight: FontWeight.w600, 
              color: widget.isSelected ? Colors.white : const Color(0xFF003C82),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class WizardHoverCloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const WizardHoverCloseButton({super.key, required this.onTap});

  @override 
  State<WizardHoverCloseButton> createState() => _WizardHoverCloseButtonState();
}

class _WizardHoverCloseButtonState extends State<WizardHoverCloseButton> {
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
            color: _isHovered ? const Color(0xFFE3F2FD) : const Color(0xFFE3F2FD).withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.close, color: Color(0xFF003C82), size: 24),
        )
      )
    );
  }
}

class WizardTextLinkButton extends StatefulWidget 
{
  final String       text;
  final VoidCallback onTap;
  
  const WizardTextLinkButton({required this.text, required this.onTap});
  
  @override 
  State<WizardTextLinkButton> createState() => WizardTextLinkButtonState();
}

class WizardTextLinkButtonState extends State<WizardTextLinkButton> 
{
  bool _isHovered = false;
  
  @override 
  Widget build(BuildContext context) 
  {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   14, 
                  fontWeight: FontWeight.w700, 
                  color:      _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82),
                ),
                child: Text(widget.text),
              ),
            ),
            Positioned(
              left:   0,
              right:  0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints) 
                {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve:    Curves.easeOutQuint,
                      height:   2,
                      width:    _isHovered ? constraints.maxWidth : 0, 
                      decoration: BoxDecoration(
                        color:        const Color(0xFF002244),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }
              ),
            ),
          ],
        ),
      )
    );
  }
}

class WizardHeaderBackButton extends StatelessWidget {
  final VoidCallback onTap;
  
  const WizardHeaderBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width:  88,
          height: 54,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x0A000000),
                offset:     Offset(0, 4),
                blurRadius: 16,
              )
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF003C82),
            size:  26,
          ),
        ),
      ),
    );
  }
}

class WizardMiniActionPillButton extends StatefulWidget {
  final String       text;
  final IconData     icon;
  final VoidCallback onTap;

  const WizardMiniActionPillButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  State<WizardMiniActionPillButton> createState() => _WizardMiniActionPillButtonState();
}

class _WizardMiniActionPillButtonState extends State<WizardMiniActionPillButton> {
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
        onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50, 
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white,
              borderRadius: BorderRadius.circular(100), 
              border: Border.all(
                color: _isHovered ? const Color(0xFF003C82) : const Color(0xFFE0E5EC),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000), 
                  offset: Offset(0, 4), 
                  blurRadius: 16, 
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: const Color(0xFF003C82), size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF003C82), 
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WizardSelectablePersonCard extends StatefulWidget {
  final PersonItem   person;
  final bool         isSelected;
  final VoidCallback onTap;

  const WizardSelectablePersonCard({
    super.key,
    required this.person,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<WizardSelectablePersonCard> createState() => _WizardSelectablePersonCardState();
}

class _WizardSelectablePersonCardState extends State<WizardSelectablePersonCard> {
  bool _isHovering = false;

  Widget _buildAvatar() {
    final String initials = '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();
    
    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('/')) {
      const String backendBaseUrl = 'http://127.0.0.1:8000'; 
      imageUrl = '$backendBaseUrl$imageUrl';
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF003C82),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final processedRoles = RoleLabelMapper.processRoles(widget.person.roles);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 380,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (_isHovering || widget.isSelected) ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.person.firstName} ${widget.person.lastName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003C82),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: processedRoles.map((role) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE0E5EC)),
                          ),
                          child: Text(
                            role,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}