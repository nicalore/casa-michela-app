import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../association/models/school_item.dart';
import '../../association/models/study_program_item.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import 'person_detail_widgets.dart';
import 'person_row_models.dart';

// Cascade: picking the school clears programme and class; picking the
// programme clears the class.

const Color kFormDisabledText = Color(0xFFCBD5E1);

const int _schoolYearStartMonth = 9;

// Must cover all eight years a programme can span: a shorter map would turn an
// unknown label back into the first year.
const Map<int, String> kGradeLabels = {
  1: 'I',
  2: 'II',
  3: 'III',
  4: 'IV',
  5: 'V',
  6: 'VI',
  7: 'VII',
  8: 'VIII',
};

final Map<String, int> kGradeNumbers = {
  for (final entry in kGradeLabels.entries) entry.value: entry.key,
};

int currentSchoolYearStart()
{
  final now = DateTime.now();

  return now.month < _schoolYearStartMonth ? now.year - 1 : now.year;
}

String gradeLabel(int grade) => kGradeLabels[grade] ?? grade.toString();


List<String> gradeOptionsFor(StudyProgramItem? program)
{
  if (program == null)
  {
    return const [];
  }

  final List<String> options = [];

  for (var year = program.minYear; year <= program.maxYear; year++)
  {
    final String? label = kGradeLabels[year];

    if (label != null && !options.contains(label))
    {
      options.add(label);
    }
  }

  return options.isEmpty ? const ['I', 'II', 'III', 'IV', 'V'] : options;
}

String schoolLabel(SchoolItem school) => '${school.name} (${school.city})';

// A school can carry a programme the association has removed.
List<String> programNamesFor(SchoolItem? school, List<StudyProgramItem> allPrograms)
{
  if (school == null)
  {
    return const [];
  }

  final List<String> names = [];

  for (final option in school.studyPrograms)
  {
    // Compare on fullName: two programmes can share a name under different
    // sectors.
    final bool isKnown = allPrograms.any((program) => program.fullName == option.name);

    if (isKnown && !names.contains(option.name))
    {
      names.add(option.name);
    }
  }

  return names;
}

class SchoolEnrollmentEditRow extends StatelessWidget
{
  final SchoolEnrollmentRowData row;
  final List<SchoolItem> allSchools;
  final List<StudyProgramItem> allPrograms;

  // This row's errors, by field: `year`, `school`, `program`, `grade`.
  final Map<String, String?> errors;

  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const SchoolEnrollmentEditRow({
    super.key,
    required this.row,
    required this.allSchools,
    required this.allPrograms,
    required this.errors,
    required this.onChanged,
    required this.onRemove,
  });

  Widget _labelled(String label, Widget field)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return PersonEditRow(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: _FourFieldRow(
          onRemove: onRemove,
          yearField: _labelled(
            'Anno inizio',
            _CompactTextField(
              controller: row.yearCtrl,
              hint: 'Es. 2024',
              errorText: errors['year'],
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
            ),
          ),
          schoolField: _labelled(
            'Scuola',
            _SchoolAutocompleteField(
              value: row.school == null ? null : schoolLabel(row.school!),
              options: allSchools.map(schoolLabel).toList(),
              hint: 'Seleziona scuola',
              errorText: errors['school'],
              onSelected: (label)
              {
                row.school = allSchools.firstWhere((school) => schoolLabel(school) == label);
                row.program = null;
                row.grade = null;
                onChanged();
              },
              onCleared: ()
              {
                row.school = null;
                row.program = null;
                row.grade = null;
                onChanged();
              },
            ),
          ),
          programField: _labelled(
            'Percorso',
            PersonFormDropdown(
              value: row.program?.fullName,
              options: programNamesFor(row.school, allPrograms),
              hint: 'Seleziona percorso',
              errorText: errors['program'],
              onSelected: (name)
              {
                row.program = allPrograms.firstWhere((program) => program.fullName == name);
                row.grade = null;
                onChanged();
              },
            ),
          ),
          gradeField: _labelled(
            'Classe',
            PersonFormDropdown(
              value: row.grade,
              options: gradeOptionsFor(row.program),
              hint: '',
              errorText: errors['grade'],
              onSelected: (grade)
              {
                row.grade = grade;
                onChanged();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FourFieldRow extends StatelessWidget
{
  static const double _breakpoint = 700;

  static const double _shortFieldWidth = 110;

  // Label height + gap + half the box/button difference, so the trash centres
  // on the 50px box.
  static const double _labelBlockHeight = 14 + 8;
  static const double _removeInset =
      _labelBlockHeight + (50 - kPersonFieldButtonSize) / 2;

  final Widget yearField;
  final Widget schoolField;
  final Widget programField;
  final Widget gradeField;
  final VoidCallback onRemove;

  const _FourFieldRow({
    required this.yearField,
    required this.schoolField,
    required this.programField,
    required this.gradeField,
    required this.onRemove,
  });

  Widget _buildRemove()
  {
    return Padding(
      padding: const EdgeInsets.only(top: _removeInset, left: 12),
      child: FadeHoverIconButton(
        icon: Icons.delete_outline_rounded,
        color: AppTheme.trialDanger,
        hoverColor: AppTheme.trialGoldSurface,
        onTap: onRemove,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              yearField,
              const SizedBox(height: 16),
              schoolField,
              const SizedBox(height: 16),
              programField,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: gradeField),
                  _buildRemove(),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: _shortFieldWidth, child: yearField),
            const SizedBox(width: 16),
            Expanded(child: schoolField),
            const SizedBox(width: 16),
            Expanded(child: programField),
            const SizedBox(width: 16),
            SizedBox(width: _shortFieldWidth, child: gradeField),
            _buildRemove(),
          ],
        );
      },
    );
  }
}

class PersonFormDropdown extends StatefulWidget
{
  final String? value;
  final List<String> options;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onSelected;

  const PersonFormDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.hint,
    required this.onSelected,
    this.errorText,
  });

  @override
  State<PersonFormDropdown> createState() => PersonFormDropdownState();
}

class PersonFormDropdownState extends State<PersonFormDropdown>
{
  final GlobalKey _buttonKey = GlobalKey();
  final GlobalKey<_FormOverlayContentState> _menuKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isHovered = false;

  bool get _isDisabled => widget.options.isEmpty;

  void _toggleMenu()
  {
    if (_overlayEntry != null || _isDisabled)
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
            top: offset.dy + size.height + 4,
            left: offset.dx,
            child: _FormOverlayContent(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              width: size.width,
              onSelected: (value)
              {
                widget.onSelected(value);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  // Removed only after the collapse animation has run.
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

  Color get _borderColor
  {
    if (widget.errorText != null)
    {
      return AppTheme.trialDanger;
    }

    return _isHovered ? AppTheme.trialGold : AppTheme.trialLine;
  }

  Color get _valueColor
  {
    if (_isDisabled)
    {
      return kFormDisabledText;
    }

    return widget.value != null ? AppTheme.trialInk : AppTheme.trialMutedText;
  }

  Widget _buildErrorBadge(String message)
  {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: message,
        textStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        decoration: AppTheme.tooltipDecoration,
        child: const Icon(Icons.error_outline_rounded, color: AppTheme.trialDanger, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final errorText = widget.errorText;

    return MouseRegion(
      cursor: _isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _isDisabled ? null : _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 50,
          padding: EdgeInsets.only(left: 16, right: errorText != null ? 8 : 16),
          decoration: BoxDecoration(
            color: _isDisabled ? AppTheme.trialPaper : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: OverflowTooltipText(
                  text: widget.value ?? widget.hint,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: widget.value != null ? FontWeight.w600 : FontWeight.w500,
                    color: _valueColor,
                  ),
                ),
              ),
              if (errorText != null) _buildErrorBadge(errorText),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _isDisabled
                    ? kFormDisabledText
                    : (_isHovered ? AppTheme.trialGold : AppTheme.trialMutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOverlayContent extends StatefulWidget
{
  final String? currentValue;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final double width;

  const _FormOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.width,
  });

  @override
  State<_FormOverlayContent> createState() => _FormOverlayContentState();
}

class _FormOverlayContentState extends State<_FormOverlayContent>
{
  // Drives both the AnimatedSize and the delay awaited by hide(): out of sync,
  // the overlay is torn down mid animation.
  static const Duration _expandDuration = Duration(milliseconds: 180);

  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    // Expanding on the next frame is what makes the opening animation visible.
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
        width: widget.width,
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                        return _FormOverlayMenuItem(
                          text: option,
                          isSelected: widget.currentValue == option,
                          onTap: () => widget.onSelected(option),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : SizedBox(width: widget.width, height: 0),
        ),
      ),
    );
  }
}

class _FormOverlayMenuItem extends StatefulWidget
{
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormOverlayMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FormOverlayMenuItem> createState() => _FormOverlayMenuItemState();
}

class _FormOverlayMenuItemState extends State<_FormOverlayMenuItem>
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
                  color: AppTheme.trialGold,
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
                    fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                    color: AppTheme.trialTealDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }}

class _CompactTextField extends StatefulWidget
{
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  bool get enabled => true;

  const _CompactTextField({
    required this.controller,
    required this.hint,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  State<_CompactTextField> createState() =>
      __CompactTextFieldState();
}

class __CompactTextFieldState extends State<_CompactTextField>
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
    // Still shared with the un-migrated person wizard.
    final Color borderColor = !widget.enabled
        ? const Color(0xFFCBD5E1)
        : (hasError
              ? AppTheme.trialDanger
              : (_isFocused
                    ? AppTheme.trialGold
                    : AppTheme.trialLine));

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

class _SchoolAutocompleteField extends StatefulWidget
{
  final String? value;
  final List<String> options;
  final String hint;
  final String? errorText;
  final ValueChanged<String> onSelected;

  // Called when the field is emptied and loses focus, so the caller clears the
  // row's actual selection.
  final VoidCallback onCleared;

  const _SchoolAutocompleteField({
    required this.value,
    required this.options,
    required this.hint,
    this.errorText,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  State<_SchoolAutocompleteField> createState() =>
      __SchoolAutocompleteFieldState();
}

class __SchoolAutocompleteFieldState
    extends State<_SchoolAutocompleteField>
{
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SchoolAutocompleteField oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Syncs when the school changes from outside, without fighting the user
    // while they are typing.
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
      // Select-all so the next keystroke replaces the old value outright.
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      return;
    }

    // An intentional clear stays cleared; the caller resets the row's selection.
    if (_controller.text.isEmpty)
    {
      if (widget.value != null)
      {
        widget.onCleared();
      }
      return;
    }

    // Text not matching a real option snaps back to the last confirmed value.
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

    final bool isLit = _isFocused || _isHovered;

    final Color borderColor = hasError
        ? AppTheme.trialDanger
        : (isLit ? AppTheme.trialGold : AppTheme.trialLine);

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
            return MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: AnimatedContainer(
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
                          decoration: AppTheme.tooltipDecoration,
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.trialDanger,
                            size: 22,
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.search_rounded,
                          color: AppTheme.trialMutedText,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) => AutocompleteOptionsList<String>(
            width: constraints.maxWidth,
            options: options,
            label: (option) => option,
            onSelected: onSelected,
          ),
        );
      },
    );
  }
}
