import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../accounting/models/volunteering_rule.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../models/compensation_items.dart';
import '../models/person_item.dart';
import '../utils/compensation_strings.dart';
import '../utils/student_notes_strings.dart' show kSaveLabel;

const double _dialogWidth = 600;
const double _fieldGap = 18;

const Color _previewSurface = Color(0xFFF2F6F7);

// True once saved; the rule holds from [month] until the teacher's next change.
Future<bool> showVolunteeringDialog({
  required BuildContext context,
  required PersonItem person,
  required DateTime month,
  required CompensationMonth shown,
}) async
{
  final bool? saved = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'Volunteering',
    builder: (context) => _VolunteeringDialog(person: person, month: month, shown: shown),
  );

  return saved ?? false;
}

class _VolunteeringDialog extends StatefulWidget
{
  final PersonItem person;
  final DateTime month;
  final CompensationMonth shown;

  const _VolunteeringDialog({required this.person, required this.month, required this.shown});

  @override
  State<_VolunteeringDialog> createState() => _VolunteeringDialogState();
}

class _VolunteeringDialogState extends State<_VolunteeringDialog>
{
  late VolunteeringRule _rule = widget.shown.volunteering;

  bool _saving = false;

  Future<void> _save() async
  {
    setState(() => _saving = true);

    try
    {
      await ApiService().updateVolunteeringRule(
        taxCode: widget.person.fiscalCode,
        month: widget.month,
        rule: _rule,
      );

      if (mounted)
      {
        Navigator.of(context).pop(true);
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _saving = false);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  void _pick(String? name)
  {
    final VolunteeringRule? picked = kVolunteeringRuleNames.entries
        .where((entry) => entry.value == name)
        .map((entry) => entry.key)
        .firstOrNull;

    if (picked != null)
    {
      setState(() => _rule = picked);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle note = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppTheme.trialMutedText,
    );
    final List<DateTime> replaced = widget.shown.volunteeringReplaced;
    final RuleFigures? preview = widget.shown.volunteeringPreviews?[_rule];

    return AppDialogStack(
      eyebrow: kVolunteeringLabel,
      title: kEditVolunteeringTitle,
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kSaveLabel,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(compensationStartsNote(widget.month), style: note),
              if (replaced.isNotEmpty) Text(volunteeringReplacedNote(replaced), style: note),
              const SizedBox(height: _fieldGap),
              PersonChipGroupField(
                label: kVolunteeringLabel,
                options: [for (final rule in VolunteeringRule.values) kVolunteeringRuleNames[rule]!],
                value: kVolunteeringRuleNames[_rule],
                onChanged: _pick,
              ),
              if (preview != null) ...[
                const SizedBox(height: _fieldGap),
                _Preview(month: widget.month, figures: preview),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// The month shown under the rule picked, before it is saved.
class _Preview extends StatelessWidget
{
  final DateTime month;
  final RuleFigures figures;

  const _Preview({required this.month, required this.figures});

  @override
  Widget build(BuildContext context)
  {
    Widget figure(String label, String value)
    {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PageHeading.style().copyWith(fontSize: 10, letterSpacing: 1.3),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialOcean,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final int? gross = figures.gross;
    final int? net = figures.net;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
      decoration: BoxDecoration(color: _previewSurface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            volunteeringPreviewTitle(month),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              figure(kPreviewVolunteer, figures.volunteerMinutes == 0 ? '—' : formatMinutes(figures.volunteerMinutes)),
              const SizedBox(width: 10),
              figure(kPreviewPaid, formatMinutes(figures.paidMinutes)),
              const SizedBox(width: 10),
              figure(kGrossColumn, gross == null ? '—' : formatAmount(gross)),
              const SizedBox(width: 10),
              figure(kNetColumn, net == null ? '—' : formatAmount(net)),
            ],
          ),
        ],
      ),
    );
  }
}
