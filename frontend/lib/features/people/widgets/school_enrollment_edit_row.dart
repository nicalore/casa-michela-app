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

// A school year to edit: year, school, programme and class in a row, with the
// delete button at the end. Shared with the school tab's dialog, because editing
// a person's details asks for the same four things, and two look-alike rows are
// the quickest way to start diverging.
//
// The cascade is why this is one row and not four fields: picking the school
// clears programme and class, picking the programme clears the class, because a
// programme belongs to the school offering it and a class to the years the
// programme has.

// The grey a field says with that the one above has to be answered first.
const Color kFormDisabledText = Color(0xFFCBD5E1);

// The month the school year starts in: before September the current year is
// still the previous one.
const int _schoolYearStartMonth = 9;

// Single source of truth for the grade labels, used both to show a saved grade and
// to translate the chosen one back. Study programs can span up to eight years, so
// the map has to cover them all: a shorter one would turn an unknown label back
// into the first year.
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

/// Start year of the running school year.
int currentSchoolYearStart()
{
  final now = DateTime.now();

  return now.month < _schoolYearStartMonth ? now.year - 1 : now.year;
}

String gradeLabel(int grade) => kGradeLabels[grade] ?? grade.toString();


// The classes a programme allows, in Roman numerals. When the programme
// declares a range the labels do not cover, it falls back to the first five.
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

// How a school is named where it has to be told from one of the same name:
// with its city.
String schoolLabel(SchoolItem school) => '${school.name} (${school.city})';

// The programmes the chosen school really teaches, narrowed to those still in
// the catalogue: a school can carry a programme the association has removed.
List<String> programNamesFor(SchoolItem? school, List<StudyProgramItem> allPrograms)
{
  if (school == null)
  {
    return const [];
  }

  final List<String> names = [];

  for (final option in school.studyPrograms)
  {
    // The name arriving with the school is the full one, sector included: the
    // comparison has to be made on the same, or two programmes sharing a name
    // under different sectors cannot be told apart.
    final bool isKnown = allPrograms.any((program) => program.fullName == option.name);

    if (isKnown && !names.contains(option.name))
    {
      names.add(option.name);
    }
  }

  return names;
}

/// Un anno scolastico, con i suoi quattro campi e la sua cascata.
class SchoolEnrollmentEditRow extends StatelessWidget
{
  final SchoolEnrollmentRowData row;
  final List<SchoolItem> allSchools;
  final List<StudyProgramItem> allPrograms;

  // This row's errors, by field: `year`, `school`, `program`, `grade`.
  final Map<String, String?> errors;

  // Called after every change, so whoever holds the row repaints.
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

// Year, school, programme and grade side by side, stacked below the threshold.
// Once stacked the remove button moves next to the grade, on the middle of its
// box as it is beside the fields in the wide layout.
class _FourFieldRow extends StatelessWidget
{
  // Below this width four fields side by side become unreadable, school and
  // programme in particular.
  static const double _breakpoint = 700;

  // Year and grade only ever hold a short value (a 4-digit year, a roman
  // numeral), so they stay a fixed width and leave the reclaimed space to
  // school and program, which can both run long.
  static const double _shortFieldWidth = 110;

  // The label above a field here, its gap, and half of what is left between the
  // 50-pixel box and the 36-pixel button. Measured rather than guessed: the
  // first arithmetic put the trash a pixel and a bit above the middle.
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

  // The same trash the memberships rows carry, on the middle of the boxes rather
  // than of the whole field: the label above them is part of the column's
  // height, and centring against that puts the button too high.
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

// Dropdown for a form field, with a hint, an inline error and support for being
// disabled when there is nothing to choose from. Separate from the filter menus in
// shared/widgets, which are built around clearing rather than picking one value.
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

  // Empty options mean the field upstream has not been chosen yet, so there is
  // nothing to open.
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

  // The overlay is removed only after the collapse animation has run, so the menu
  // does not disappear abruptly.
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

    // Gold under the pointer, as every field and every control of the app.
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
  // The same value drives the AnimatedSize and the delay awaited by hide(): they
  // must stay in sync or the overlay is torn down mid animation.
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
        // Long lists scroll instead of running past the bottom of the dialog.
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

// The field and the autocomplete a school is typed with, used by this row
// alone.

class _CompactTextField extends StatefulWidget
{
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  // Sempre acceso: il campo spento serviva al vecchio wizard, qui l'anno si
  // scrive sempre.
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
    // Gold on focus and the app's line at rest: the same answer AppTextField
    // gives, so a field in an Orari dialog and a field anywhere else in the new
    // interface behave alike. (This widget is still shared with the person
    // wizard, which has not been migrated yet and will show these two colours
    // ahead of the rest of it.)
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

/// Free-text field with a filtered, tappable suggestions list, used to pick a
/// school by typing its name instead of scrolling a dropdown: school names are
/// often too long for a fixed-width dropdown button to show in full.

class _SchoolAutocompleteField extends StatefulWidget
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

    // Gold under the pointer and on focus, the app's line at rest: the same
    // answer the year field and the two dropdowns beside it give, so the four
    // boxes of a row do not light up in two different colours.
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
                      // The same grey whatever the box is doing: the lens says
                      // the field is searchable, not that it is lit, and gold
                      // on it read as a second thing lighting up inside the
                      // one that already had.
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
