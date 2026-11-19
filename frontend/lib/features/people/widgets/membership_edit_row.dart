import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../models/person_item.dart';
import 'person_detail_widgets.dart';

// Draft: a year after the newest on file goes through «RINNOVA ISCRIZIONE».
const String kNewYearError = 'Usa RINNOVA ISCRIZIONE';

int? newestMembershipYear(PersonItem? person)
{
  final Iterable<int> years = (person?.memberships ?? const []).map((membership) => membership.year);

  return years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b);
}

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

  // Payments hold the year: its number is fixed and a lock stands for the bin.
  final bool locked;

  // The re-enrollment's row: the year is the one in course, not chosen.
  final bool yearFixed;

  static const String lockedTip = 'Ci sono pagamenti registrati in questo periodo.';

  const MembershipEditRow({
    super.key,
    required this.yearController,
    required this.dayMonthController,
    required this.yearError,
    required this.startError,
    required this.onYearChanged,
    required this.onDayMonthChanged,
    required this.onRemove,
    this.locked = false,
    this.yearFixed = false,
  });

  // The latest start a held year allows, as an error for its start field.
  static String? startPastPayments(DateTime? latestStart, String dayMonth, String year)
  {
    final List<String> parts = dayMonth.split('/');
    final int? day = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final int? month = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final int? parsedYear = int.tryParse(year);

    if (latestStart == null || day == null || month == null || parsedYear == null)
    {
      return null;
    }

    if (!DateTime(parsedYear, month, day).isAfter(latestStart))
    {
      return null;
    }

    final String limit =
        '${latestStart.day.toString().padLeft(2, '0')}/${latestStart.month.toString().padLeft(2, '0')}';

    return 'Non dopo il $limit';
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget yearField = AppTextField(
      controller: yearController,
      label: 'Anno',
      hintText: 'Es. 2024',
      errorText: yearError,
      keyboardType: TextInputType.number,
      enabled: !locked && !yearFixed,
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
      padding: EdgeInsets.only(left: 10, top: personFieldButtonInset(context)),
      child: locked
          ? AppTooltip(
              message: lockedTip,
              child: SizedBox(
                width: kPersonFieldButtonSize,
                height: kPersonFieldButtonSize,
                child: Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.trialMutedText),
              ),
            )
          : onRemove == null
          ? const SizedBox(width: kPersonFieldButtonSize, height: kPersonFieldButtonSize)
          : FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDangerText,
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
