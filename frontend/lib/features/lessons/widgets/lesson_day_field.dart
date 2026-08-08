import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../utils/booking_window.dart';

// The days a slot falls on, chosen among the days the booking window has open.
//
// Chips and not a dropdown, for the reason the app chooses chips everywhere
// else it has a handful of fixed answers — a person's sex, the level of a
// subject, the areas it belongs to: a dropdown hides the whole question behind
// a click, while these show it. The set is small and it is the same set the
// rail is showing on the left, so what is open is worth having in sight.
//
// Several at once, because the same slot is usually the same slot all week: a
// teacher free on Monday afternoon is free on Wednesday afternoon too, and
// filling that in used to mean opening this window once per day.
//
// The labels are the short form. Ten days at their full length — "Mercoledì 12
// agosto" — wrap three times over and read as a wall.
class LessonDayField extends StatelessWidget
{
  final List<DateTime> days;

  // Can be emptied: the last lit chip goes out like any other. Refusing it made
  // the field the one place in the app where pressing a chip that is on does
  // nothing, and whoever wanted to start over from no days had to light a
  // second one to be allowed to put out the first.
  //
  // What an empty set is not is a request: the wizards holding this field ask
  // for a day before they let one past the card, and refuse the save.
  final Set<DateTime> values;

  final ValueChanged<Set<DateTime>> onChanged;

  // What is written under the chips once more than one is lit, so that how many
  // things are about to be created is said before they are.
  final String Function(int count) summary;

  /// Which days can still be answered. A day that cannot is shown all the same,
  /// struck through and dead, with [disabledTooltip] saying why: a chip that is
  /// missing is a question nobody can ask about, while a dead one is an answer
  /// with a reason. Null leaves every day open.
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
