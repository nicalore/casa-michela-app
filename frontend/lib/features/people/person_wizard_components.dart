import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_config.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/overflow_tooltip_text.dart';
import '../association/models/association_subject_item.dart';
import '../association/models/school_item.dart';
import '../association/models/study_program_item.dart';
import './models/parental_relationship_draft.dart';
import './models/person_item.dart';
import 'widgets/role_chips_row.dart';

class WizardEnrollmentRowData
{
  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;

  WizardEnrollmentRowData({required this.yearCtrl, required this.dateCtrl});
}

class WizardSchoolRowData
{
  TextEditingController yearCtrl;
  SchoolItem? selectedSchool;
  StudyProgramItem? selectedProgram;
  String? selectedGrade;

  WizardSchoolRowData({
    required this.yearCtrl,
    this.selectedSchool,
    this.selectedProgram,
    this.selectedGrade,
  });
}

class WizardAnimatedActionButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final Color baseColor;
  final Color hoverColor;
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
  State<WizardAnimatedActionButton> createState() =>
      _WizardAnimatedActionButtonState();
}

class _WizardAnimatedActionButtonState
    extends State<WizardAnimatedActionButton>
{
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_)
        {
          setState(()
          {
            _isPressed = true;
          });
        },
        onTapUp: (_)
        {
          setState(()
          {
            _isPressed = false;
          });
          widget.onPressed();
        },
        onTapCancel: ()
        {
          setState(()
          {
            _isPressed = false;
          });
        },
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
                  color: widget.baseColor.withValues(
                    alpha: _isHovered ? 0.4 : 0.2,
                  ),
                  offset: Offset(0, _isHovered ? 8 : 4),
                  blurRadius: _isHovered ? 16 : 8,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: OverflowTooltipText(
                    text: widget.text,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
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

class WizardOutlinedActionButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const WizardOutlinedActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<WizardOutlinedActionButton> createState() =>
      _WizardOutlinedActionButtonState();
}

class _WizardOutlinedActionButtonState
    extends State<WizardOutlinedActionButton>
{
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_)
        {
          setState(()
          {
            _isPressed = true;
          });
        },
        onTapUp: (_)
        {
          setState(()
          {
            _isPressed = false;
          });
          widget.onPressed();
        },
        onTapCancel: ()
        {
          setState(()
          {
            _isPressed = false;
          });
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuint,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuint,
            height: 56,
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.surfaceHover : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: OverflowTooltipText(
                    text: widget.text,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      letterSpacing: 1.2,
                    ),
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

class WizardAnimatedTextField extends StatefulWidget
{
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const WizardAnimatedTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.errorText,
    this.inputFormatters,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<WizardAnimatedTextField> createState() =>
      _WizardAnimatedTextFieldState();
}

class _WizardAnimatedTextFieldState extends State<WizardAnimatedTextField>
{
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(()
    {
      setState(()
      {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final bool hasError = widget.errorText != null;
    final Color borderColor = !widget.enabled
        ? const Color(0xFFCBD5E1)
        : (hasError
              ? AppTheme.danger
              : (_isFocused
                    ? AppTheme.primary
                    : AppTheme.slate200));

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
            color: !widget.enabled ? const Color(0xFFF8FAFC) : Colors.white,
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
                  enabled: widget.enabled,
                  inputFormatters: widget.inputFormatters,
                  keyboardType: widget.keyboardType,
                  cursorColor: AppTheme.primary,
                  onChanged: widget.onChanged,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: !widget.enabled
                        ? AppTheme.slate400
                        : const Color(0xFF2A2A2A),
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: widget.hint,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.hint,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(
                      left: 16,
                      right: hasError ? 8 : 16,
                    ),
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Tooltip(
                    message: widget.errorText!,
                    textStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.danger,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Free-text field with a filtered, tappable suggestions list, used to pick a
/// school by typing its name instead of scrolling a dropdown: school names are
/// often too long for a fixed-width dropdown button to show in full.
class WizardSchoolAutocompleteField extends StatefulWidget
{
  final String? value;
  final List<String> options;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onSelected;

  /// Called when the field is emptied and then loses focus, so the caller can
  /// clear the row's actual selection instead of the field silently reverting
  /// to the last confirmed value.
  final VoidCallback onCleared;

  const WizardSchoolAutocompleteField({
    super.key,
    required this.value,
    required this.options,
    required this.hint,
    this.errorText,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  State<WizardSchoolAutocompleteField> createState() =>
      _WizardSchoolAutocompleteFieldState();
}

class _WizardSchoolAutocompleteFieldState
    extends State<WizardSchoolAutocompleteField>
{
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant WizardSchoolAutocompleteField oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Keeps the field in sync when the row's school changes from outside (for
    // example a reset, or another row shifting into this position after one
    // above it is removed), without fighting the user while they are typing.
    if (!_focusNode.hasFocus && widget.value != oldWidget.value && widget.value != _controller.text)
    {
      _controller.text = widget.value ?? '';
    }
  }

  void _handleFocusChange()
  {
    final bool hasFocus = _focusNode.hasFocus;

    setState(() => _isFocused = hasFocus);

    if (hasFocus)
    {
      // Selects the current text so the next keystroke replaces it outright,
      // instead of the suggestions filtering against the old value with
      // nothing new typed yet.
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      return;
    }

    // An intentional clear stays cleared, instead of snapping back to the old
    // school: the caller resets the row's actual selection to match.
    if (_controller.text.isEmpty)
    {
      if (widget.value != null)
      {
        widget.onCleared();
      }
      return;
    }

    // Leaving the field without picking a real suggestion would otherwise show
    // text that does not match the row's actual school, so it snaps back to
    // the last confirmed value.
    if (!widget.options.contains(_controller.text))
    {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Iterable<String> _optionsFor(TextEditingValue textEditingValue)
  {
    if (textEditingValue.text.isEmpty)
    {
      return const Iterable<String>.empty();
    }

    return widget.options.where(
      (option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool hasError = widget.errorText != null;
    final Color borderColor = hasError
        ? AppTheme.danger
        : (_isFocused ? AppTheme.primary : AppTheme.slate200);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        return RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: _optionsFor,
          onSelected: widget.onSelected,
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted)
          {
            return AnimatedContainer(
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
                      controller: textEditingController,
                      focusNode: focusNode,
                      cursorColor: AppTheme.primary,
                      onSubmitted: (_) => onFieldSubmitted(),
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
                          color: AppTheme.hint,
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
                        textStyle: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.danger,
                          size: 22,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Icon(
                        Icons.search_rounded,
                        color: _isFocused ? AppTheme.primary : AppTheme.mutedText,
                        size: 20,
                      ),
                    ),
                ],
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) => _WizardAutocompleteOptionsList(
            width: constraints.maxWidth,
            options: options,
            onSelected: onSelected,
          ),
        );
      },
    );
  }
}

// Fixed height shared by the ListView itemExtent and each row: the two must
// match for the scroll-into-view math below to stay correct.
const double _wizardAutocompleteOptionHeight = 44.0;

// Scrollable suggestions list that follows the keyboard-highlighted option,
// auto-scrolling it into view. Same pattern and grey hover highlight as the
// people list filters.
class _WizardAutocompleteOptionsList extends StatefulWidget
{
  final double width;
  final Iterable<String> options;
  final AutocompleteOnSelected<String> onSelected;

  const _WizardAutocompleteOptionsList({
    required this.width,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_WizardAutocompleteOptionsList> createState() =>
      _WizardAutocompleteOptionsListState();
}

class _WizardAutocompleteOptionsListState
    extends State<_WizardAutocompleteOptionsList>
{
  static const double _verticalPadding = 8;

  final ScrollController _scrollController = ScrollController();
  int? _lastHighlightedIndex;

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  // Brings the highlighted item into view, scrolling only the minimum needed
  // rather than always centering it.
  void _ensureHighlightedVisible(int index)
  {
    if (!_scrollController.hasClients)
    {
      return;
    }

    final itemTop = _verticalPadding + (index * _wizardAutocompleteOptionHeight);
    final itemBottom = itemTop + _wizardAutocompleteOptionHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final visibleTop = _scrollController.offset;
    final visibleBottom = visibleTop + viewportHeight;

    double? target;

    if (itemTop < visibleTop)
    {
      target = itemTop;
    }
    else if (itemBottom > visibleBottom)
    {
      target = itemBottom - viewportHeight;
    }

    if (target != null)
    {
      final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    // Reading the highlighted index here subscribes to the notifier, so this
    // widget rebuilds on every arrow-key change.
    final highlightedIndex = AutocompleteHighlightedOption.of(context);

    if (_lastHighlightedIndex != highlightedIndex)
    {
      _lastHighlightedIndex = highlightedIndex;
      // Scheduled after the frame: the scrollable must be laid out before its
      // viewportDimension and maxScrollExtent are known.
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _ensureHighlightedVisible(highlightedIndex);
        }
      });
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: widget.width,
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 250),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.overlayShadow,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbColor: AppTheme.hint,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
                shrinkWrap: true,
                itemExtent: _wizardAutocompleteOptionHeight,
                itemCount: widget.options.length,
                itemBuilder: (context, index)
                {
                  final option = widget.options.elementAt(index);

                  return _WizardAutocompleteOptionTile(
                    text: option,
                    isHighlighted: index == highlightedIndex,
                    onTap: () => widget.onSelected(option),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// A suggestion row, highlighted on hover or via keyboard arrows with the same
// grey wash used by the search filters, so the two feel like the same
// component.
class _WizardAutocompleteOptionTile extends StatefulWidget
{
  final String text;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _WizardAutocompleteOptionTile({
    required this.text,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_WizardAutocompleteOptionTile> createState() => _WizardAutocompleteOptionTileState();
}

class _WizardAutocompleteOptionTileState extends State<_WizardAutocompleteOptionTile>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool active = widget.isHighlighted || _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          height: _wizardAutocompleteOptionHeight,
          color: active ? AppTheme.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: active ? 16 : 0,
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.text,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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

class WizardAnimatedOverlayDropdown extends StatefulWidget
{
  final String? value;
  final List<String> items;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const WizardAnimatedOverlayDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    this.errorText,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<WizardAnimatedOverlayDropdown> createState() =>
      _WizardAnimatedOverlayDropdownState();
}

class _WizardAnimatedOverlayDropdownState
    extends State<WizardAnimatedOverlayDropdown>
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_WizardOverlayDropdownContentState> _menuKey = GlobalKey();

  bool _isFocused = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    setState(()
    {
      _isFocused = true;
    });

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

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
              onSelected: (val)
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
        setState(()
        {
          _isFocused = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool hasValue = widget.value != null;
    final bool hasError = widget.errorText != null;
    final Color borderColor = !widget.enabled
        ? AppTheme.slate200
        : (hasError
              ? AppTheme.danger
              : (_isFocused
                    ? AppTheme.primary
                    : AppTheme.slate200));

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? _toggleMenu : null,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: !widget.enabled ? const Color(0xFFF8FAFC) : Colors.white,
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
                child: _DropdownOverflowTooltipText(
                  text: hasValue ? widget.value! : widget.hint,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: !widget.enabled
                        ? AppTheme.slate400
                        : (hasValue
                              ? const Color(0xFF2A2A2A)
                              : AppTheme.hint),
                  ),
                ),
              ),
              if (hasError) ...[
                Tooltip(
                  message: widget.errorText!,
                  textStyle: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _isFocused
                    ? AppTheme.primary
                    : AppTheme.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOverflowTooltipText extends StatelessWidget
{
  final String text;
  final TextStyle style;

  const _DropdownOverflowTooltipText({required this.text, required this.style});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);

        final Widget textWidget = Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

        if (!painter.didExceedMaxLines)
        {
          return textWidget;
        }

        return Tooltip(
          message: text,
          waitDuration: const Duration(milliseconds: 600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: textWidget,
        );
      },
    );
  }
}

class _WizardOverlayDropdownContent extends StatefulWidget
{
  final String? currentValue;
  final List<String> items;
  final ValueChanged<String> onSelected;

  const _WizardOverlayDropdownContent({
    super.key,
    required this.currentValue,
    required this.items,
    required this.onSelected,
  });

  @override
  State<_WizardOverlayDropdownContent> createState() =>
      _WizardOverlayDropdownContentState();
}

class _WizardOverlayDropdownContentState
    extends State<_WizardOverlayDropdownContent>
{
  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(()
        {
          _expanded = true;
        });
      }
    });
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(()
      {
        _expanded = false;
      });
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.overlayShadow,
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
                      children: widget.items.map((item)
                      {
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

class WizardDropdownMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
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

class _WizardDropdownMenuItemState extends State<WizardDropdownMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _hover = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _hover = false;
        });
      },
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
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DropdownOverflowTooltipText(
                  text: widget.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
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

class WizardDateInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  )
  {
    if (oldValue.text.length >= newValue.text.length)
    {
      return newValue;
    }

    String text = newValue.text;
    // Follows the caret instead of forcing it to the end, so editing a digit
    // in the middle of an already typed date leaves the cursor where it was.
    int caret = newValue.selection.baseOffset;

    if (text.length == 2 && !text.contains('/'))
    {
      text += '/';

      if (caret == 2)
      {
        caret = 3;
      }
    }
    else if (text.length == 5 && text.indexOf('/', 3) == -1)
    {
      text += '/';

      if (caret == 5)
      {
        caret = 6;
      }
    }

    if (text.length > 10)
    {
      return oldValue;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }
}

class WizardDayMonthInputFormatter extends TextInputFormatter
{
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  )
  {
    if (oldValue.text.length >= newValue.text.length)
    {
      return newValue;
    }

    String text = newValue.text;

    if (text.length == 2 && !text.contains('/'))
    {
      text += '/';
    }

    if (text.length > 5)
    {
      return oldValue;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class WizardFormSectionCard extends StatelessWidget
{
  final String title;
  final Widget leadingIcon;
  final List<Widget> children;
  final bool isCompact;

  const WizardFormSectionCard({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.children,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context)
  {
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
                        color: AppTheme.primary,
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EEF7),
                    shape: BoxShape.circle,
                  ),
                  child: leadingIcon is WizardStaticAvatar
                      ? Icon(
                          (leadingIcon as WizardStaticAvatar).icon,
                          size: 20,
                          color: AppTheme.primary,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
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

class WizardFormInputRow extends StatelessWidget
{
  final String label;
  final Widget inputWidget;

  const WizardFormInputRow({
    super.key,
    required this.label,
    required this.inputWidget,
  });

  @override
  Widget build(BuildContext context)
  {
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

class WizardStaticAvatar extends StatelessWidget
{
  final IconData icon;

  const WizardStaticAvatar({super.key, required this.icon});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: 90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: AppTheme.primary),
    );
  }
}

class WizardProfilePhotoUploader extends StatefulWidget
{
  final Uint8List? imageBytes;
  final String? initialImageUrl;
  final ValueChanged<Uint8List?> onImagePicked;

  const WizardProfilePhotoUploader({
    super.key,
    required this.imageBytes,
    this.initialImageUrl,
    required this.onImagePicked,
  });

  @override
  State<WizardProfilePhotoUploader> createState() =>
      _WizardProfilePhotoUploaderState();
}

class _WizardProfilePhotoUploaderState
    extends State<WizardProfilePhotoUploader>
{
  final ImagePicker _picker = ImagePicker();
  bool _isHoveringUpload = false;
  bool _isHoveringTrash = false;
  bool _isDeleted = false;
  late String _cacheBustTimestamp;

  @override
  void initState()
  {
    super.initState();
    _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _pickImage() async
  {
    try
    {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null)
      {
        return;
      }

      final Uint8List bytes = await image.readAsBytes();

      setState(()
      {
        _isDeleted = false;
      });

      widget.onImagePicked(bytes);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Errore durante la selezione dell\'immagine.',
          isError: true,
        );
      }
    }
  }

  void _removeImage()
  {
    setState(()
    {
      _isDeleted = true;
    });

    widget.onImagePicked(null);
  }

  @override
  Widget build(BuildContext context)
  {
    ImageProvider? imageProvider;

    if (widget.imageBytes != null)
    {
      imageProvider = MemoryImage(widget.imageBytes!);
    }
    else if (!_isDeleted &&
        widget.initialImageUrl != null &&
        widget.initialImageUrl!.isNotEmpty)
    {
      String url = widget.initialImageUrl!;

      if (url.startsWith('/'))
      {
        url = url = '${ApiConfig.buildUrl(url)}?v=$_cacheBustTimestamp';
      }

      imageProvider = NetworkImage(url);
    }

    final bool hasImage = imageProvider != null;

    final Widget avatar = Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF7),
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: !hasImage
          ? const Icon(
              Icons.person_outline,
              size: 48,
              color: AppTheme.primary,
            )
          : null,
    );

    // The buttons row has a minimum intrinsic width (~155px) that can exceed the
    // available space even when stacked, and horizontal scroll would clip it with
    // no visual cue. FittedBox scales the whole row as one block so it stays fully
    // visible and clickable.
    final Widget buttonsRow = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 48,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_)
            {
              setState(()
              {
                _isHoveringUpload = true;
              });
            },
            onExit: (_)
            {
              setState(()
              {
                _isHoveringUpload = false;
              });
            },
            child: GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isHoveringUpload
                      ? AppTheme.surfaceHover
                      : Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: AppTheme.primary,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.upload_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      !hasImage ? 'Carica foto' : 'Cambia foto',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(width: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_)
              {
                setState(()
                {
                  _isHoveringTrash = true;
                });
              },
              onExit: (_)
              {
                setState(()
                {
                  _isHoveringTrash = false;
                });
              },
              child: GestureDetector(
                onTap: _removeImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isHoveringTrash
                        ? AppTheme.danger.withValues(alpha: 0.15)
                        : AppTheme.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );

    // The row wants avatar (110) + spacing (24) + buttons (~150-190) of width,
    // which the labelled form row above rarely grants, so on narrow screens it
    // stacks vertically instead of overflowing to the right.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < 320;

        if (isCompact)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(height: 16),
              buttonsRow,
            ],
          );
        }

        return Row(
          children: [
            avatar,
            const SizedBox(width: 24),
            Flexible(child: buttonsRow),
          ],
        );
      },
    );
  }
}

class WizardDisabledDropdownPlaceholder extends StatelessWidget
{
  final String hint;

  const WizardDisabledDropdownPlaceholder({super.key, required this.hint});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200, width: 1.5),
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

class WizardSelectionCard extends StatefulWidget
{
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isHorizontal;
  final bool isCompact;
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

class _WizardSelectionCardState extends State<WizardSelectionCard>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _hover = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _hover = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.isHorizontal
              ? (widget.isCompact ? 600 : 700)
              : (widget.isCompact ? 400 : 500),
          constraints: BoxConstraints(
            minHeight: widget.isHorizontal
                ? (widget.isCompact ? 80 : 110)
                : (widget.isCompact ? 140 : 200),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 24 : 32,
            vertical: widget.isCompact ? 16 : 24,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (_hover || widget.isSelected)
                  ? AppTheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 6),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: widget.isCompact ? 32 : 42,
                color: AppTheme.primary,
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
                        color: AppTheme.primary,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      SizedBox(height: widget.isCompact ? 4 : 6),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: widget.isCompact ? 13 : 15,
                          color: AppTheme.slate500,
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

class WizardCarouselArrowButton extends StatefulWidget
{
  final IconData icon;
  final bool isDisabled;
  final VoidCallback onTap;

  const WizardCarouselArrowButton({
    super.key,
    required this.icon,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<WizardCarouselArrowButton> createState() =>
      _WizardCarouselArrowButtonState();
}

class _WizardCarouselArrowButtonState extends State<WizardCarouselArrowButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? const Color(0xFFF1F5F9)
                : (_isHovered ? AppTheme.primary : Colors.white),
            shape: BoxShape.circle,
            boxShadow: widget.isDisabled
                ? null
                : AppTheme.cardShadow,
          ),
          child: Icon(
            widget.icon,
            size: 32,
            color: widget.isDisabled
                ? AppTheme.hint
                : (_isHovered ? Colors.white : AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

class WizardAnimatedSearchBar extends StatefulWidget
{
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const WizardAnimatedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cerca...',
  });

  @override
  State<WizardAnimatedSearchBar> createState() =>
      _WizardAnimatedSearchBarState();
}

class _WizardAnimatedSearchBarState extends State<WizardAnimatedSearchBar>
{
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(()
    {
      setState(()
      {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose()
  {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuint,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: _isFocused
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? const Color(0x15003C82)
                : const Color(0x0A000000),
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
        cursorColor: AppTheme.primary,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.hint,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(left: 28, bottom: 2),
          suffixIcon: Icon(
            Icons.search,
            size: 24,
            color: _isFocused
                ? AppTheme.primary
                : AppTheme.hint,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 64,
            minHeight: 50,
          ),
        ),
      ),
    );
  }
}

class WizardFilterOption<T>
{
  final T value;
  final String label;

  WizardFilterOption({required this.value, required this.label});
}

class WizardFilterMenu<T> extends StatefulWidget
{
  final String hint;
  final IconData icon;
  final T? value;
  final List<WizardFilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback onClear;
  final double menuWidth;
  final bool showClearIcon;

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

class _WizardFilterMenuState<T> extends State<WizardFilterMenu<T>>
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_WizardFilterOverlayContentState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu()
  {
    if (_overlayEntry != null)
    {
      _closeMenu();
      return;
    }

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

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
              onSelected: (val)
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
  }

  void _closeMenu() async
  {
    if (_overlayEntry != null)
    {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool isActive = widget.value != null;
    String displayText = widget.hint;

    if (isActive)
    {
      final Iterable<WizardFilterOption<T>> matches =
          widget.options.where((o) => o.value == widget.value);
      displayText = matches.isEmpty ? '' : matches.first.label;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: EdgeInsets.only(
            left: 16,
            right: (isActive && widget.showClearIcon) ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: _isHovered || isActive
                ? AppTheme.surfaceHover
                : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _isHovered || isActive
                  ? AppTheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppTheme.cardShadow,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppTheme.primary
                        : AppTheme.mutedText,
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
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppTheme.danger,
                    ),
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

class _WizardFilterOverlayContent<T> extends StatefulWidget
{
  final T? currentValue;
  final List<WizardFilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;

  const _WizardFilterOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_WizardFilterOverlayContent<T>> createState() =>
      _WizardFilterOverlayContentState<T>();
}

class _WizardFilterOverlayContentState<T>
    extends State<_WizardFilterOverlayContent<T>>
{
  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(()
        {
          _expanded = true;
        });
      }
    });
  }

  Future<void> hide() async
  {
    if (mounted)
    {
      setState(()
      {
        _expanded = false;
      });
    }
    await Future.delayed(const Duration(milliseconds: 180));
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
                      children: widget.options.map((option)
                      {
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

class WizardFilterMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
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

class _WizardFilterMenuItemState extends State<WizardFilterMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _hover = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _hover = false;
        });
      },
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
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
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

class WizardSubjectGridCard extends StatefulWidget
{
  final AssociationSubjectItem subject;
  final bool isSelected;
  final int selectedCount;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const WizardSubjectGridCard({
    super.key,
    required this.subject,
    required this.isSelected,
    required this.selectedCount,
    required this.onTap,
    this.onRemove,
  });

  @override
  State<WizardSubjectGridCard> createState() => _WizardSubjectGridCardState();
}

class _WizardSubjectGridCardState extends State<WizardSubjectGridCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: widget.isSelected
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovering = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.isSelected ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 360,
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (_isHovering || widget.isSelected)
                  ? AppTheme.primary
                  : AppTheme.slate200,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Icon(
                Icons.subject_rounded,
                size: 32,
                color: widget.isSelected
                    ? AppTheme.primary
                    : AppTheme.hint,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowTooltipText(
                      text: widget.subject.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.isSelected
                            ? AppTheme.primary
                            : const Color(0xFF2A2A2A),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isSelected
                          ? (widget.selectedCount == 1
                                ? '1 percorso'
                                : '${widget.selectedCount} percorsi')
                          : 'Non assegnata',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.isSelected
                            ? AppTheme.primary
                            : AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSelected) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onTap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onRemove ?? () {},
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.backspace_rounded,
                            size: 18,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WizardProgramsSelectionDialog extends StatefulWidget
{
  final AssociationSubjectItem subject;
  final List<StudyProgramItem> programs;
  final Set<int> initialSelected;
  final ValueChanged<Set<int>> onSave;
  final VoidCallback onCancel;

  const WizardProgramsSelectionDialog({
    super.key,
    required this.subject,
    required this.programs,
    required this.initialSelected,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<WizardProgramsSelectionDialog> createState() =>
      _WizardProgramsSelectionDialogState();
}

class _WizardProgramsSelectionDialogState
    extends State<WizardProgramsSelectionDialog>
{
  late Set<int> _selected;

  @override
  void initState()
  {
    super.initState();
    _selected = Set.from(widget.initialSelected);
    if (_selected.isEmpty)
    {
      _selected = Set.from(widget.programs.map((p) => p.id));
    }
  }

  void _selectAll()
  {
    setState(()
    {
      _selected = Set.from(widget.programs.map((p) => p.id));
    });
  }

  void _deselectAll()
  {
    setState(()
    {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        // Responsive width: fills the available space but never past 600. Without
        // it the breakpoint on the buttons row below would never trigger.
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
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
                    child: OverflowTooltipText(
                      text: widget.subject.name,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  WizardHoverCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              // Wrap instead of Row: invisible when both labels fit on one line,
              // wraps below instead of overflowing when they do not.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 24,
                runSpacing: 8,
                children: [
                  WizardTextLinkButton(
                    text: 'Seleziona tutti',
                    onTap: _selectAll,
                  ),
                  WizardTextLinkButton(
                    text: 'Deseleziona tutti',
                    onTap: _deselectAll,
                  ),
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
                  children: widget.programs.map((prog)
                  {
                    final bool isProgSelected = _selected.contains(prog.id);
                    return _WizardDisciplineChip(
                      label: prog.name,
                      isSelected: isProgSelected,
                      onSelected: (val)
                      {
                        setState(()
                        {
                          if (val)
                          {
                            _selected.add(prog.id);
                          }
                          else
                          {
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
              padding: const EdgeInsets.only(
                left: 32,
                right: 32,
                bottom: 32,
                top: 16,
              ),
              // Stacks vertically when the dialog is too narrow for both buttons
              // side by side; fixed width in both branches, never stretches.
              child: _ResponsiveWizardDialogButtonsRow(
                secondaryButton: WizardAnimatedActionButton(
                  text: 'ANNULLA',
                  icon: Icons.close_rounded,
                  baseColor: AppTheme.danger,
                  hoverColor: AppTheme.dangerHover,
                  onPressed: ()
                  {
                    widget.onCancel();
                    Navigator.of(context).pop();
                  },
                ),
                primaryButton: WizardAnimatedActionButton(
                  text: 'CONFERMA',
                  icon: Icons.check_circle_outline,
                  baseColor: AppTheme.primary,
                  hoverColor: AppTheme.primaryHover,
                  onPressed: ()
                  {
                    widget.onSave(_selected);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Chooses row vs column from the actual available width and never lets the buttons
// stretch to fill it. Same criterion as the person wizard's main bottom bar:
// Conferma always on top, Annulla always below.
class _ResponsiveWizardDialogButtonsRow extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;

  const _ResponsiveWizardDialogButtonsRow({
    required this.secondaryButton,
    required this.primaryButton,
  });

  static const double _kButtonWidth = 240;
  static const double _kSpacing = 16;
  static const double _kBreakpoint = _kButtonWidth * 2 + _kSpacing + 40;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        if (isCompact)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: _kButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: _kButtonWidth, child: secondaryButton),
            const SizedBox(width: _kSpacing),
            SizedBox(width: _kButtonWidth, child: primaryButton),
          ],
        );
      },
    );
  }
}

class _WizardDisciplineChip extends StatefulWidget
{
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _WizardDisciplineChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<_WizardDisciplineChip> createState() => _WizardDisciplineChipState();
}

class _WizardDisciplineChipState extends State<_WizardDisciplineChip>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primary
                : (_isHovered ? AppTheme.surfaceHover : Colors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected
                  ? AppTheme.primary
                  : AppTheme.border,
              width: 1.0,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : AppTheme.primary,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class WizardHoverCloseButton extends StatefulWidget
{
  final VoidCallback onTap;

  const WizardHoverCloseButton({super.key, required this.onTap});

  @override
  State<WizardHoverCloseButton> createState() => _WizardHoverCloseButtonState();
}

class _WizardHoverCloseButtonState extends State<WizardHoverCloseButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.iconHover
                : AppTheme.iconHover.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.close, color: AppTheme.primary, size: 24),
        ),
      ),
    );
  }
}

class WizardTextLinkButton extends StatefulWidget
{
  final String text;
  final IconData? icon;
  final VoidCallback onTap;

  const WizardTextLinkButton({
    super.key,
    required this.text,
    this.icon,
    required this.onTap,
  });

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
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _isHovered
                      ? const Color(0xFF002244)
                      : AppTheme.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          begin: AppTheme.primary,
                          end: _isHovered
                              ? const Color(0xFF002244)
                              : AppTheme.primary,
                        ),
                        duration: const Duration(milliseconds: 200),
                        builder: (context, color, child)
                        {
                          return Icon(widget.icon, size: 20, color: color);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(widget.text),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LayoutBuilder(
                builder: (context, constraints)
                {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutQuint,
                      height: 2,
                      width: _isHovered ? constraints.maxWidth : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF002244),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WizardRemoveRowButton extends StatefulWidget
{
  final VoidCallback onTap;

  const WizardRemoveRowButton({super.key, required this.onTap});

  @override
  State<WizardRemoveRowButton> createState() => _WizardRemoveRowButtonState();
}

class _WizardRemoveRowButtonState extends State<WizardRemoveRowButton>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _isHovering
                ? AppTheme.danger.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.remove_circle_outline,
            size: 24,
            color: AppTheme.danger,
          ),
        ),
      ),
    );
  }
}

class WizardHeaderBackButton extends StatelessWidget
{
  final VoidCallback onTap;

  const WizardHeaderBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 88,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class WizardMiniActionPillButton extends StatefulWidget
{
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const WizardMiniActionPillButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  State<WizardMiniActionPillButton> createState() =>
      _WizardMiniActionPillButtonState();
}

class _WizardMiniActionPillButtonState
    extends State<WizardMiniActionPillButton>
{
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_)
        {
          setState(()
          {
            _isPressed = true;
          });
        },
        onTapUp: (_)
        {
          setState(()
          {
            _isPressed = false;
          });
          widget.onTap();
        },
        onTapCancel: ()
        {
          setState(()
          {
            _isPressed = false;
          });
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _isHovered ? AppTheme.surfaceHover : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: _isHovered
                    ? AppTheme.primary
                    : AppTheme.border,
                width: 1.5,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: OverflowTooltipText(
                    text: widget.text,
                    maxLines: 1,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
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

class WizardSelectablePersonCard extends StatefulWidget
{
  final PersonItem person;
  final bool isSelected;
  final VoidCallback onTap;
  // When selected and given at least one callback, shows the edit/delete icons
  // instead of being directly tappable (same pattern as WizardSubjectGridCard).
  // With both absent the behaviour is unchanged.
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  const WizardSelectablePersonCard({
    super.key,
    required this.person,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
    this.onRemove,
  });

  @override
  State<WizardSelectablePersonCard> createState() =>
      _WizardSelectablePersonCardState();
}

class _WizardSelectablePersonCardState
    extends State<WizardSelectablePersonCard>
{
  bool _isHovering = false;

  Widget _buildAvatar()
  {
    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'
            .toUpperCase();

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();
    if (imageUrl != null && imageUrl.startsWith('/'))
    {
      imageUrl = ApiConfig.buildUrl(imageUrl);
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.slate200,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 2.5),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace)
                {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> processedRoles = RoleLabelMapper.processRoles(
      widget.person.roles,
    );
    final String fullName =
        '${widget.person.firstName} ${widget.person.lastName}';
    final bool showActionIcons =
        widget.isSelected && (widget.onEdit != null || widget.onRemove != null);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _isHovering = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _isHovering = false;
        });
      },
      child: GestureDetector(
        onTap: showActionIcons ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 420,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFE8F0FA) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: (_isHovering || widget.isSelected)
                  ? AppTheme.primary
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
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
                    OverflowTooltipText(
                      text: fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RoleChipsRow(
                      roles: processedRoles,
                      safetyMargin: 6,
                      applyTextScaler: true,
                    ),
                  ],
                ),
              ),
              if (showActionIcons) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.onEdit != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onEdit,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onEdit != null && widget.onRemove != null)
                      const SizedBox(height: 6),
                    if (widget.onRemove != null)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onRemove,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.backspace_rounded,
                              size: 18,
                              color: AppTheme.danger,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable yes/no switch, used both in the pickup authorization dialog and in
// place of the early-exit dropdown. The white thumb slides horizontally:
// true = Yes (left), false = No (right).
class WizardYesNoSwitch extends StatelessWidget
{
  final bool value;
  final ValueChanged<bool> onChanged;
  final double width;
  final double height;
  final bool isError;

  const WizardYesNoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 240,
    this.height = 54,
    this.isError = false,
  });

  Widget _buildLabel({
    required String text,
    required IconData icon,
    required bool active,
  })
  {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: active ? AppTheme.primary : AppTheme.slate400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: active ? AppTheme.primary : AppTheme.slate400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    const double pad = 4;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(height / 2),
            // Same error red as WizardAnimatedTextField, for visual consistency.
            border: isError ? Border.all(color: AppTheme.danger, width: 1.5) : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints)
            {
              final double thumbWidth = constraints.maxWidth / 2;
              final double thumbHeight = constraints.maxHeight;

              return Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: value ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      width: thumbWidth,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular((height - pad * 2) / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Positioned.fill gives the Row the Stack's full height; otherwise
                  // it would only take its intrinsic height and stick to the top.
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLabel(
                            text: 'Sì',
                            icon: Icons.check_circle_outline,
                            active: value,
                          ),
                        ),
                        Expanded(
                          child: _buildLabel(
                            text: 'No',
                            icon: Icons.block_rounded,
                            active: !value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<ParentalRelationshipDraft?> showAuthorizedPickupDialog(
  BuildContext context, {
  required String personTaxCode,
  required String parentName,
  required String childName,
  ParentalRelationshipDraft? existing,
})
{
  return showGeneralDialog<ParentalRelationshipDraft?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AuthorizedPickup',
    barrierColor: Colors.black.withValues(alpha: .15),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (animation, secondaryAnimation, child) =>
        const SizedBox.shrink(),
    transitionBuilder: (context, animation, secondaryAnimation, child)
    {
      final blurValue = animation.value * 8.0;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: _AuthorizedPickupDialog(
              personTaxCode: personTaxCode,
              parentName: parentName,
              childName: childName,
              existing: existing,
            ),
          ),
        ),
      );
    },
  );
}

class _AuthorizedPickupDialog extends StatefulWidget
{
  final String personTaxCode;
  final String parentName;
  final String childName;
  final ParentalRelationshipDraft? existing;

  const _AuthorizedPickupDialog({
    required this.personTaxCode,
    required this.parentName,
    required this.childName,
    this.existing,
  });

  @override
  State<_AuthorizedPickupDialog> createState() =>
      _AuthorizedPickupDialogState();
}

class _AuthorizedPickupDialogState extends State<_AuthorizedPickupDialog>
{
  late bool _authorized;
  late final TextEditingController _reasonCtrl;

  @override
  void initState()
  {
    super.initState();
    _authorized = widget.existing?.authorizedPickup ?? true;
    _reasonCtrl = TextEditingController(
      text: widget.existing?.restrictionReason ?? '',
    );
  }

  @override
  void dispose()
  {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // The reason stays optional even when pickup is not authorized: no blocking
  // validation.
  void _confirm()
  {
    final String reason = _reasonCtrl.text.trim();

    Navigator.of(context).pop(
      ParentalRelationshipDraft(
        taxCode: widget.personTaxCode,
        authorizedPickup: _authorized,
        restrictionReason: (_authorized || reason.isEmpty) ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        // Wider dialog: leaves room for the two buttons on one row without stacking.
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Autorizzazione al ritiro',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.parentName} ha l\'autorizzazione a ritirare ${widget.childName} in caso di uscita anticipata?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2A2A2A),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: WizardYesNoSwitch(
                      value: _authorized,
                      onChanged: (val) => setState(() => _authorized = val),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // The space is always reserved (fixed-height SizedBox) and only
                  // the opacity changes, so the dialog never resizes and the widgets
                  // below stay put as the field appears or disappears. Label above,
                  // full-width field below, rather than WizardFormInputRow which
                  // reserved 140px for the label and shortened the textbox.
                  AnimatedOpacity(
                    opacity: _authorized ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: _authorized,
                      child: SizedBox(
                        height: 82,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Motivo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF7A7A7A),
                                ),
                              ),
                            ),
                            WizardAnimatedTextField(
                              controller: _reasonCtrl,
                              hint: '',
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              // Conferma and Annulla always share one row: the dialog is now wide
              // enough to fit them without stacking.
              child: Row(
                children: [
                  Expanded(
                    child: WizardAnimatedActionButton(
                      text: 'ANNULLA',
                      icon: Icons.close_rounded,
                      baseColor: AppTheme.danger,
                      hoverColor: AppTheme.dangerHover,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WizardAnimatedActionButton(
                      text: 'CONFERMA',
                      icon: Icons.check_circle_outline,
                      baseColor: AppTheme.primary,
                      hoverColor: AppTheme.primaryHover,
                      onPressed: _confirm,
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

// Chooses whether to lay the year and start date side by side or stacked, like MembershipEditRow in PersonMembershipsTab.
// When stacked, the remove button moves next to the last field.
class WizardEnrollmentFieldRow extends StatelessWidget
{
  final TextEditingController yearCtrl;
  final TextEditingController dateCtrl;
  final String?               yearError;
  final String?               dateError;
  final ValueChanged<String>  onYearChanged;
  final ValueChanged<String>  onDateChanged;
  final VoidCallback?         onRemove;

  const WizardEnrollmentFieldRow
  ({
    super.key,
    required this.yearCtrl,
    required this.dateCtrl,
    required this.yearError,
    required this.dateError,
    required this.onYearChanged,
    required this.onDateChanged,
    required this.onRemove,
  });

  static const double _kBreakpoint = 360;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 8),
      child:   Text
      (
        text, 
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   14, 
          fontWeight: FontWeight.w600, 
          color:      const Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget yearField = Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            _buildLabel('Anno'),
            WizardAnimatedTextField
            (
              controller:   yearCtrl, 
              hint:         'Es. 2024', 
              keyboardType: TextInputType.number,
              errorText:    yearError,
              onChanged:    onYearChanged,
            ),
          ],
        );

        final Widget dateField = Column
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            _buildLabel('Data inizio'),
            WizardAnimatedTextField
            (
              controller:      dateCtrl, 
              hint:            'gg/mm', 
              keyboardType:    TextInputType.number,
              inputFormatters: [WizardDayMonthInputFormatter()],
              errorText:       dateError,
              onChanged:       onDateChanged,
            ),
          ],
        );

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              yearField,
              const SizedBox(height: 16),
              onRemove == null
                  ? dateField
                  : Row
                    (
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: 
                      [
                        Expanded(child: dateField),
                        const SizedBox(width: 8),
                        WizardRemoveRowButton(onTap: onRemove!),
                      ],
                    ),
            ],
          );
        }

        return Row
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: 
          [
            Expanded(flex: 2, child: yearField),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: dateField),
            // Recalibrated from the original: top:6 was tuned when the label only appeared on the first row.
            // Here the label always appears, so the field shifts down by about 27px.
            onRemove != null
                ? Padding
                  (
                    padding: const EdgeInsets.only(top: 32, left: 8),
                    child:   WizardRemoveRowButton(onTap: onRemove!),
                  )
                : const SizedBox(width: 48),
          ],
        );
      },
    );
  }
}

// Chooses whether to place search and filters side by side or stacked, only below the threshold, not always.
// Above the threshold: Row(Expanded(searchBar), individual filters); below: full-width search plus Wrap(filters).
class WizardResponsiveSearchFilterRow extends StatelessWidget
{
  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;

  const WizardResponsiveSearchFilterRow
  ({
    super.key,
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              searchBar,
              SizedBox(height: 12),
              Wrap
              (
                spacing:    12,
                runSpacing: 12,
                children:   filterWidgets,
              ),
            ],
          );
        }

        final List<Widget> rowChildren = [Expanded(child: searchBar)];
        for (final w in filterWidgets)
        {
          rowChildren.add(SizedBox(width: 12));
          rowChildren.add(w);
        }

        return Row(children: rowChildren);
      },
    );
  }
}

// Chooses row vs column from the available width; both buttons keep a fixed width and never stretch to fill the space.
class WizardResponsiveBottomBar extends StatelessWidget
{
  final Widget secondaryButton;
  final Widget primaryButton;

  const WizardResponsiveBottomBar
  ({
    super.key,
    required this.secondaryButton,
    required this.primaryButton,
  });

  static const double _kButtonWidth = 240;
  static const double _kSpacing = 24;
  static const double _kBreakpoint = _kButtonWidth * 2 + _kSpacing + 40;

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        if (isCompact)
        {
          return Column
          (
            mainAxisSize: MainAxisSize.min,
            children:
            [
              SizedBox(width: _kButtonWidth, child: primaryButton),
              const SizedBox(height: 16),
              SizedBox(width: _kButtonWidth, child: secondaryButton),
            ],
          );
        }

        return Row
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children:
          [
            SizedBox(width: _kButtonWidth, child: secondaryButton),
            const SizedBox(width: _kSpacing),
            SizedBox(width: _kButtonWidth, child: primaryButton),
          ],
        );
      },
    );
  }
}

// Lays street type, name and number side by side, or stacks them with per-field labels when narrow.
class WizardAddressFieldsRow extends StatelessWidget
{
  final TextEditingController tipoViaCtrl;
  final String?               tipoViaError;
  final ValueChanged<String>  onTipoViaChanged;

  final TextEditingController nomeCtrl;
  final String?               nomeError;
  final ValueChanged<String>  onNomeChanged;

  final TextEditingController civicoCtrl;
  final String?               civicoError;
  final ValueChanged<String>  onCivicoChanged;

  const WizardAddressFieldsRow
  ({
    super.key,
    required this.tipoViaCtrl,
    required this.tipoViaError,
    required this.onTipoViaChanged,
    required this.nomeCtrl,
    required this.nomeError,
    required this.onNomeChanged,
    required this.civicoCtrl,
    required this.civicoError,
    required this.onCivicoChanged,
  });

  static const double _kBreakpoint = 420;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 6),
      child:   Text
      (
        text,
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   13,
          fontWeight: FontWeight.w600,
          color:      const Color(0xFF7A7A7A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder
    (
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kBreakpoint;

        final Widget tipoViaField = WizardAnimatedTextField
        (
          controller: tipoViaCtrl,
          hint:       'Via/Strada/...',
          errorText:  tipoViaError,
          onChanged:  onTipoViaChanged,
        );

        final Widget nomeField = WizardAnimatedTextField
        (
          controller: nomeCtrl,
          hint:       'Nome',
          errorText:  nomeError,
          onChanged:  onNomeChanged,
        );

        final Widget civicoField = WizardAnimatedTextField
        (
          controller: civicoCtrl,
          hint:       'N°',
          errorText:  civicoError,
          onChanged:  onCivicoChanged,
        );

        if (isCompact)
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              _buildLabel('Via / Piazza'),
              tipoViaField,
              const SizedBox(height: 16),
              _buildLabel('Nome via'),
              nomeField,
              const SizedBox(height: 16),
              _buildLabel('Numero civico'),
              civicoField,
            ],
          );
        }

        return Row
        (
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
          [
            Expanded(flex: 3, child: tipoViaField),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: nomeField),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: civicoField),
          ],
        );
      },
    );
  }
}

// Lays the four school fields side by side or stacked; the remove button follows the last field when stacked.
class WizardSchoolFieldRow extends StatelessWidget
{
  final TextEditingController yearCtrl;
  final String?                yearError;
  final ValueChanged<String>   onYearChanged;

  final String?                 schoolValue;
  final List<String>            schoolOptions;
  final String?                 schoolError;
  final ValueChanged<String>    onSchoolSelected;
  final VoidCallback            onSchoolCleared;

  final String?                 programValue;
  final List<String>            programOptions;
  final bool                    programEnabled;
  final String?                 programError;
  final ValueChanged<String>    onProgramSelected;

  final String?                 gradeValue;
  final List<String>            gradeOptions;
  final bool                    gradeEnabled;
  final String?                 gradeError;
  final ValueChanged<String>    onGradeSelected;

  final VoidCallback?           onRemove;

  const WizardSchoolFieldRow
  ({
    super.key,
    required this.yearCtrl,
    required this.yearError,
    required this.onYearChanged,
    required this.schoolValue,
    required this.schoolOptions,
    required this.schoolError,
    required this.onSchoolSelected,
    required this.onSchoolCleared,
    required this.programValue,
    required this.programOptions,
    required this.programEnabled,
    required this.programError,
    required this.onProgramSelected,
    required this.gradeValue,
    required this.gradeOptions,
    required this.gradeEnabled,
    required this.gradeError,
    required this.onGradeSelected,
    required this.onRemove,
  });

  static const double _kBreakpoint = 700;
  static const double _kShortFieldWidth = 110;

  Widget _buildLabel(String text)
  {
    return Padding
    (
      padding: const EdgeInsets.only(bottom: 8),
      child:   Text
      (
        text,
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   12,
          fontWeight: FontWeight.w700,
          color:      AppTheme.slate500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container
    (
      margin:     const EdgeInsets.only(bottom: 16),
      padding:    const EdgeInsets.all(20),
      decoration: BoxDecoration
      (
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppTheme.slate200),
        color:        const Color(0xFFF8FAFC),
      ),
      child: LayoutBuilder
      (
        builder: (context, constraints)
        {
          final bool isCompact = constraints.maxWidth < _kBreakpoint;

          final Widget yearField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              _buildLabel('Anno inizio'),
              WizardAnimatedTextField
              (
                controller:   yearCtrl,
                hint:         'Es. 2024',
                errorText:    yearError,
                keyboardType: TextInputType.number,
                onChanged:    onYearChanged,
              ),
            ],
          );

          final Widget schoolField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              _buildLabel('Scuola'),
              WizardSchoolAutocompleteField
              (
                value:      schoolValue,
                options:    schoolOptions,
                hint:       'Scuola',
                errorText:  schoolError,
                onSelected: onSchoolSelected,
                onCleared:  onSchoolCleared,
              ),
            ],
          );

          final Widget programField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              _buildLabel('Percorso'),
              WizardAnimatedOverlayDropdown
              (
                value:      programValue,
                items:      programOptions,
                hint:       'Seleziona',
                enabled:    programEnabled,
                errorText:  programError,
                onChanged:  onProgramSelected,
              ),
            ],
          );

          final Widget gradeField = Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              _buildLabel('Classe'),
              WizardAnimatedOverlayDropdown
              (
                value:      gradeValue,
                items:      gradeOptions,
                hint:       '',
                enabled:    gradeEnabled,
                errorText:  gradeError,
                onChanged:  onGradeSelected,
              ),
            ],
          );

          if (isCompact)
          {
            return Column
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
              [
                yearField,
                const SizedBox(height: 16),
                schoolField,
                const SizedBox(height: 16),
                programField,
                const SizedBox(height: 16),
                onRemove == null
                    ? gradeField
                    : Row
                      (
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children:
                        [
                          Expanded(child: gradeField),
                          const SizedBox(width: 8),
                          WizardRemoveRowButton(onTap: onRemove!),
                        ],
                      ),
              ],
            );
          }

          return Row
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            [
              // Year and grade only ever hold a short value (a 4-digit year, a
              // roman numeral), so they stay a fixed width and leave the
              // reclaimed space to school and program, which can both run long.
              SizedBox(width: _kShortFieldWidth, child: yearField),
              const SizedBox(width: 16),
              Expanded(child: schoolField),
              const SizedBox(width: 16),
              Expanded(child: programField),
              const SizedBox(width: 16),
              SizedBox(width: _kShortFieldWidth, child: gradeField),
              onRemove != null
                  ? Padding
                    (
                      padding: const EdgeInsets.only(top: 28, left: 16),
                      child:   WizardRemoveRowButton(onTap: onRemove!),
                    )
                  : const SizedBox(width: 48),
            ],
          );
        },
      ),
    );
  }
}
