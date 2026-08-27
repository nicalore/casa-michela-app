import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';

// Mirrors AppTextField's surface, radius, border and height.
const Color _fieldSurface = Color(0xFFFBFDFC);
const double _fieldRadius = 14;
const double _fieldBorderWidth = 2;
const double _fieldHeight = 50;

Widget _fieldLabel(String text, [TextStyle? style])
{
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: style == null ? AppFieldLabel(text) : Text(text, style: style),
  );
}

// Shared tappable field shell used by every picker in this feature.
class _PickerFieldShell extends StatefulWidget
{
  final String label;
  final String displayText;
  final bool isPlaceholder;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  const _PickerFieldShell({
    required this.label,
    required this.displayText,
    required this.isPlaceholder,
    required this.trailingIcon,
    required this.onTap,
  });

  @override
  State<_PickerFieldShell> createState() => _PickerFieldShellState();
}

class _PickerFieldShellState extends State<_PickerFieldShell>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final bool isEnabled = widget.onTap != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(widget.label),
        MouseRegion(
          cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _fieldHeight,
              padding: const EdgeInsets.only(left: 16, right: 12),
              decoration: BoxDecoration(
                color: isEnabled ? _fieldSurface : AppTheme.closedSurface,
                borderRadius: BorderRadius.circular(_fieldRadius),
                border: Border.all(
                  color: isEnabled
                      ? (_isHovered ? AppTheme.trialGold : AppTheme.trialLine)
                      : AppTheme.closedLine,
                  width: _fieldBorderWidth,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OverflowTooltipText(
                      text: widget.displayText,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: widget.isPlaceholder ? FontWeight.w500 : FontWeight.w600,
                        color: widget.isPlaceholder ? AppTheme.trialMutedText : AppTheme.trialInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(widget.trailingIcon, size: 20, color: AppTheme.trialMutedText),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SelectionOption<T>
{
  final T value;
  final String label;
  final String? subtitle;

  final Widget? leading;

  const SelectionOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
  });
}

// Tappable field opening a searchable single-select list.
class SelectionField<T> extends StatelessWidget
{
  final String label;
  final String placeholder;
  final String dialogTitle;
  final String searchHint;
  final List<SelectionOption<T>> options;
  final T? value;
  final ValueChanged<T> onSelected;
  final bool enabled;

  const SelectionField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.dialogTitle,
    required this.searchHint,
    required this.options,
    required this.value,
    required this.onSelected,
    this.enabled = true,
  });

  void _openPicker(BuildContext context)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SelectionFieldDialog',
      builder: (dialogContext) => _SelectionListDialog<T>(
        title: dialogTitle,
        hint: searchHint,
        options: options,
        onSelected: onSelected,
      ),
    );
  }

  SelectionOption<T>? get _selectedOption
  {
    for (final option in options)
    {
      if (option.value == value)
      {
        return option;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context)
  {
    final selected = _selectedOption;

    return _PickerFieldShell(
      label: label,
      displayText: selected?.label ?? placeholder,
      isPlaceholder: selected == null,
      trailingIcon: Icons.expand_more_rounded,
      onTap: enabled ? () => _openPicker(context) : null,
    );
  }
}

class _SelectionListDialog<T> extends StatefulWidget
{
  final String title;
  final String hint;
  final List<SelectionOption<T>> options;
  final ValueChanged<T> onSelected;

  const _SelectionListDialog({
    required this.title,
    required this.hint,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_SelectionListDialog<T>> createState() => _SelectionListDialogState<T>();
}

class _SelectionListDialogState<T> extends State<_SelectionListDialog<T>>
{
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<SelectionOption<T>> get _filteredOptions
  {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty)
    {
      return widget.options;
    }

    return widget.options.where((option)
    {
      return option.label.toLowerCase().contains(query) ||
          (option.subtitle?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _select(T value)
  {
    widget.onSelected(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    final options = _filteredOptions;

    return AppDialogStack(
      eyebrow: 'Selezione',
      title: widget.title,
      maxWidth: 520,
      alignment: const Alignment(0, -0.1),
      fillLast: true,
      children: [
        AppDialogPill(
          expand: true,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                hintText: widget.hint,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: options.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Nessun risultato.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.trialMutedText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: options.length,
                        itemBuilder: (context, index)
                        {
                          final option = options[index];

                          return _SelectionListItem(
                            option: option,
                            onTap: () => _select(option.value),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectionListItem<T> extends StatefulWidget
{
  final SelectionOption<T> option;
  final VoidCallback onTap;

  const _SelectionListItem({required this.option, required this.onTap});

  @override
  State<_SelectionListItem<T>> createState() => _SelectionListItemState<T>();
}

class _SelectionListItemState<T> extends State<_SelectionListItem<T>>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    final subtitle = widget.option.subtitle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: _isHovered ? AppTheme.trialGoldSurface : Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: _isHovered ? 16 : 0,
                decoration: BoxDecoration(
                  color: AppTheme.trialGold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              if (widget.option.leading != null) ...[
                widget.option.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OverflowTooltipText(
                      text: widget.option.label,
                      maxLines: 1,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.trialInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.trialMutedText,
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

// Free-text field with filtered, keyboard-navigable suggestions.
class AutocompleteField<T> extends StatefulWidget
{
  final String label;
  final T? value;
  final List<SelectionOption<T>> options;
  final String hint;
  final ValueChanged<T> onSelected;

  // Called when the field is emptied and then loses focus, so the caller can
  // clear the selection instead of the field reverting to the last value.
  final VoidCallback? onCleared;

  // When true, an empty field shows every option — for small fixed sets meant
  // to be browsed by click.
  final bool showAllOptionsWhenEmpty;

  // Trailing icon; null leaves the end of the field bare.
  final IconData? icon;

  final TextStyle? labelStyle;

  // When null the field owns its node.
  final FocusNode? focusNode;

  const AutocompleteField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.hint,
    required this.onSelected,
    this.onCleared,
    this.showAllOptionsWhenEmpty = false,
    this.icon = Icons.search_rounded,
    this.labelStyle,
    this.focusNode,
  });

  @override
  State<AutocompleteField<T>> createState() => _AutocompleteFieldState<T>();
}

class _AutocompleteFieldState<T> extends State<AutocompleteField<T>>
{
  late final TextEditingController _controller = TextEditingController(text: _labelFor(widget.value) ?? '');
  FocusNode? _ownedFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  String? _labelFor(T? value)
  {
    if (value == null)
    {
      return null;
    }

    for (final option in widget.options)
    {
      if (option.value == value)
      {
        return option.label;
      }
    }

    return null;
  }

  @override
  void initState()
  {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AutocompleteField<T> oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    // Sync external selection changes, without fighting the user while typing.
    if (!_focusNode.hasFocus && widget.value != oldWidget.value)
    {
      final label = _labelFor(widget.value) ?? '';

      if (_controller.text != label)
      {
        _controller.text = label;
      }
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

    if (_controller.text.isEmpty)
    {
      if (widget.value != null)
      {
        widget.onCleared?.call();
      }
      return;
    }

    // Snap back to the confirmed value when leaving without picking a suggestion.
    final confirmedLabel = _labelFor(widget.value);

    if (confirmedLabel != _controller.text)
    {
      _controller.text = confirmedLabel ?? '';
    }
  }

  @override
  void dispose()
  {
    _focusNode.removeListener(_handleFocusChange);
    _ownedFocusNode?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Iterable<SelectionOption<T>> _optionsFor(TextEditingValue textEditingValue)
  {
    if (textEditingValue.text.isEmpty)
    {
      return widget.showAllOptionsWhenEmpty ? widget.options : <SelectionOption<T>>[];
    }

    final query = textEditingValue.text.toLowerCase();

    return widget.options.where((option) => option.label.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context)
  {
    final bool hasValue = widget.value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(widget.label, widget.labelStyle),
        LayoutBuilder(
          builder: (context, constraints)
          {
            return RawAutocomplete<SelectionOption<T>>(
              textEditingController: _controller,
              focusNode: _focusNode,
              displayStringForOption: (option) => option.label,
              optionsBuilder: _optionsFor,
              onSelected: (option) => widget.onSelected(option.value),
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted)
              {
                // Same box AppTextField draws, down to the numbers.
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 54,
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBFDFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isFocused ? AppTheme.trialGold : AppTheme.trialLine,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.trialGold.withValues(alpha: _isFocused ? 0.15 : 0),
                        spreadRadius: _isFocused ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          cursorColor: AppTheme.trialTealDeep,
                          onSubmitted: (_) => onFieldSubmitted(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                            color: AppTheme.trialInk,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            hintText: widget.hint,
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.trialMutedText,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (widget.icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          widget.icon,
                          size: 20,
                          color: _isFocused ? AppTheme.trialGold : AppTheme.trialMutedText,
                        ),
                      ],
                    ],
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) =>
                  AutocompleteOptionsList<SelectionOption<T>>(
                width: constraints.maxWidth,
                options: options,
                label: (option) => option.label,
                leading: (option) => option.leading,
                subtitle: (option) => option.subtitle,
                subtitlePlacement: AutocompleteSubtitlePlacement.below,
                onSelected: onSelected,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Read-only fact shown in place of a field the dialog no longer asks for.
class WizardFact extends StatelessWidget
{
  final String label;
  final String value;

  const WizardFact({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialInk,
          ),
        ),
      ],
    );
  }
}
