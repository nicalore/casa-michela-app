import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import 'person_detail_widgets.dart';

// A membership: the year and the day it began, side by side, stacked when the
// row narrows. Once stacked, the delete button moves next to the last field.
//
// Here and not inside a dialog because two dialogs edit memberships — the tab's
// and the person's — and two look-alike rows are the quickest way to start
// diverging.
class MembershipEditRow extends StatelessWidget
{
  static const double _breakpoint = 360;

  final TextEditingController yearController;
  final TextEditingController dayMonthController;
  final String? yearError;
  final String? startError;
  final ValueChanged<String> onYearChanged;
  final ValueChanged<String> onDayMonthChanged;

  // Null when the row cannot be removed: a member's first membership is not an
  // addition, it is the reason the dialog is open.
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

    // Centred on the boxes and not on the whole field: the label above is part
    // of the column's height, and centring on that put the button a dozen pixels
    // too high.
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
