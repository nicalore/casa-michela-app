import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../utils/booking_window.dart';

class LessonDayField extends StatelessWidget
{
  final List<DateTime> days;

  // May be emptied here; the enclosing wizards refuse to save an empty set.
  final Set<DateTime> values;

  final ValueChanged<Set<DateTime>> onChanged;

  final String Function(int count) summary;

  // Null leaves every day enabled.
  final bool Function(DateTime day)? isEnabled;

  final String Function(DateTime day)? disabledTooltip;

  const LessonDayField({
    super.key,
    required this.days,
    required this.values,
    required this.onChanged,
    required this.summary,
    this.isEnabled,
    this.disabledTooltip,
  });

  void _toggle(DateTime day, bool selected)
  {
    final updated = <DateTime>{
      for (final value in values) value,
    };

    if (selected)
    {
      updated.add(day);
    }
    else
    {
      updated.removeWhere((value) => isSameDate(value, day));
    }

    onChanged(updated);
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: const AppFieldLabel('Giornate'),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final day in days)
              AppSelectableChip(
                label: formatAvailableDayShortLabel(day),
                selected: values.any((value) => isSameDate(value, day)),
                enabled: isEnabled?.call(day) ?? true,
                disabledTooltip: disabledTooltip?.call(day),
                onSelected: (selected) => _toggle(day, selected),
              ),
          ],
        ),
        if (values.length > 1) ...[
          const SizedBox(height: 10),
          Text(
            summary(values.length),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
