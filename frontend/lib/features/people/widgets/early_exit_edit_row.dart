import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/shared_components.dart';
import '../edit/widgets/person_chip_group_field.dart';
import 'person_detail_widgets.dart';
import 'person_row_models.dart';

// Chip labels stand for ISO weekdays; the short names are all distinct.
final Map<String, int> kWeekdayByShortName = {
  for (var weekday = 1; weekday <= 7; weekday++) weekdayShortName(weekday): weekday,
};

class EarlyExitEditRow extends StatelessWidget
{
  static const double _breakpoint = 420;

  final EarlyExitRowData row;

  // Errors by field: `weekdays`, `time`, `reason`.
  final Map<String, String?> errors;

  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const EarlyExitEditRow({
    super.key,
    required this.row,
    required this.errors,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget days = PersonChipGroupField.multiple(
      label: 'Giorni',
      options: kWeekdayByShortName.keys.toList(),
      values: {
        for (final entry in kWeekdayByShortName.entries)
          if (row.weekdays.contains(entry.value)) entry.key,
      },
      errorText: errors['weekdays'],
      onToggled: (option)
      {
        final int weekday = kWeekdayByShortName[option]!;

        if (!row.weekdays.remove(weekday))
        {
          row.weekdays.add(weekday);
        }

        onChanged();
      },
    );

    final Widget timeField = AppTextField(
      controller: row.timeCtrl,
      label: 'Orario',
      hintText: 'hh:mm',
      errorText: errors['time'],
      keyboardType: TextInputType.number,
      inputFormatters: [TimeInputFormatter()],
      onChanged: (_) => onChanged(),
    );

    final Widget reasonField = AppTextField(
      controller: row.reasonCtrl,
      label: 'Motivo',
      hintText: 'Es. Nuoto',
      maxLength: FieldLimits.earlyExitReason,
      errorText: errors['reason'],
      onChanged: (_) => onChanged(),
    );

    final Widget remove = Padding(
      padding: const EdgeInsets.only(left: 10, top: kPersonFieldButtonInset),
      child: FadeHoverIconButton(
        icon: Icons.delete_outline_rounded,
        color: AppTheme.trialDanger,
        hoverColor: AppTheme.trialGoldSurface,
        onTap: onRemove,
      ),
    );

    return PersonEditRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          days,
          LayoutBuilder(
            builder: (context, constraints)
            {
              if (constraints.maxWidth < _breakpoint)
              {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    timeField,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: reasonField),
                        remove,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: timeField),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: reasonField),
                  remove,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
