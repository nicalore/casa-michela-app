import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_field_label.dart';
import '../../../../shared/widgets/app_selectable_chip.dart';

class PersonChipGroupField extends StatelessWidget
{
  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  final bool enabled;

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
                    // Pressing the lit chip again switches nothing off.
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
