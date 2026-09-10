import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_field_label.dart';
import '../../../../shared/widgets/app_selectable_chip.dart';

const double _disabledOpacity = 0.6;

class PersonChipGroupField extends StatelessWidget
{
  final String label;
  final List<String> options;

  // Either value/onChanged or values/onToggled is set, never both.
  final String? value;
  final ValueChanged<String?>? onChanged;

  final Set<String>? values;
  final ValueChanged<String>? onToggled;

  final bool enabled;

  final String? note;

  final String? errorText;

  const PersonChipGroupField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required ValueChanged<String?> this.onChanged,
    this.enabled = true,
    this.note,
    this.errorText,
  })  : values = null,
        onToggled = null;

  const PersonChipGroupField.multiple({
    super.key,
    required this.label,
    required this.options,
    required Set<String> this.values,
    required ValueChanged<String> this.onToggled,
    this.enabled = true,
    this.note,
    this.errorText,
  })  : value = null,
        onChanged = null;

  bool _isChosen(String option)
  {
    final Set<String>? values = this.values;

    return values != null ? values.contains(option) : value == option;
  }

  Widget _chip(String option)
  {
    final Set<String>? values = this.values;

    final Widget chip = values != null
        ? AppSelectableChip(
            label: option,
            selected: values.contains(option),
            onSelected: (_) => onToggled!(option),
          )
        : AppSelectableChip(
            label: option,
            selected: value == option,
            // Single choice cannot be cleared by tapping the selected chip again.
            onSelected: (selected) => onChanged!(selected ? option : value),
          );

    // A disabled chip keeps full colour when chosen; only the ones not taken fade.
    if (enabled || _isChosen(option))
    {
      return chip;
    }

    return Opacity(opacity: _disabledOpacity, child: chip);
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 10),
        IgnorePointer(
          ignoring: !enabled,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in options) _chip(option),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialDanger,
            ),
          ),
        ],
      ],
    );
  }
}
