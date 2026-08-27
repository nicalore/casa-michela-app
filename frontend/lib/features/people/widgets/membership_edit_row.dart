import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import 'person_detail_widgets.dart';

// Shared by the two dialogs that edit memberships (the tab's and the person's).
class MembershipEditRow extends StatelessWidget
{
  static const double _breakpoint = 360;

  final TextEditingController yearController;
  final TextEditingController dayMonthController;
  final String? yearError;
  final String? startError;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onDayMonthChanged;

  // Null when the row cannot be removed.
  final VoidCallback? onRemove;

  const MembershipEditRow({
    super.key,
    required this.yearController,
    required this.dayMonthController,
    required this.yearError,
    required this.startError,
    required this.onYearChanged,
    required this.onDayMonthChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget yearField = AppTextField(
      controller: yearController,
      label: 'Anno',
      hintText: 'Es. 2024',
      errorText: yearError,
      keyboardType: TextInputType.number,
      onChanged: onYearChanged,
    );

    final Widget dayMonthField = AppTextField(
      controller: dayMonthController,
      label: 'Data inizio',
      hintText: 'gg/mm',
      errorText: startError,
      inputFormatters: [DayMonthInputFormatter()],
      keyboardType: TextInputType.number,
      onChanged: onDayMonthChanged,
    );

    // Centred on the boxes, not the whole field: the label above would put the
    // button too high.
    final Widget remove = Padding(
      padding: const EdgeInsets.only(left: 10, top: kPersonFieldButtonInset),
      child: onRemove == null
          ? const SizedBox(width: kPersonFieldButtonSize, height: kPersonFieldButtonSize)
          : FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDanger,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: onRemove!,
            ),
    );

    return PersonEditRow(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          if (constraints.maxWidth < _breakpoint)
          {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                yearField,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: dayMonthField),
                    remove,
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: yearField),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: dayMonthField),
              remove,
            ],
          );
        },
      ),
    );
  }
}
