import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_field_label.dart';
import '../../../../shared/widgets/app_selectable_chip.dart';

// A choice among few: the field's label and the chips under it.
//
// In place of a dropdown. Payment method, collaboration type, administrative
// role and certification are three to five fixed values: opening them in a
// dropdown hides the whole question behind a click, whereas the chips show all
// of it.
class PersonChipGroupField extends StatelessWidget
{
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  // Disabled: the answer is decided by something else — a president cannot be
  // paid — and the chip stays there saying which.
  final bool enabled;

  // The line explaining why it is disabled, or what the choice entails.
  final String? note;

  final String? errorText;

  const PersonChipGroupField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.note,
    this.errorText,
  });

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 10),
        Opacity(
          opacity: enabled ? 1 : 0.6,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  AppSelectableChip(
                    label: option,
                    selected: value == option,
                    // Pressing the lit one again switches nothing off: here an
                    // answer is changed, not removed.
                    onSelected: (selected) => onChanged(selected ? option : value),
                  ),
              ],
            ),
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
