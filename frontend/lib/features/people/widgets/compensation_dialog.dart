import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../edit/person_edit_form.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../models/compensation_items.dart';
import '../models/person_item.dart';
import '../utils/compensation_strings.dart';
import '../utils/student_notes_strings.dart' show kSaveLabel;

const double _dialogWidth = 600;
const double _fieldGap = 18;

// True once saved; it holds from [month] until the next change.
Future<bool> showCompensationDialog({
  required BuildContext context,
  required PersonItem person,
  required DateTime month,
  required CompensationMonth shown,
}) async
{
  final bool? saved = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'Compensation',
    builder: (context) => _CompensationDialog(person: person, month: month, shown: shown),
  );

  return saved ?? false;
}

class _CompensationDialog extends StatefulWidget
{
  final PersonItem person;
  final DateTime month;
  final CompensationMonth shown;

  const _CompensationDialog({required this.person, required this.month, required this.shown});

  @override
  State<_CompensationDialog> createState() => _CompensationDialogState();
}

class _CompensationDialogState extends State<_CompensationDialog>
{
  late String? _collaboration = labelForServerValue(kCollaborationTypes, widget.shown.collaborationType);

  late final TextEditingController _gross = TextEditingController(text: _text(widget.shown.grossRate));
  late final TextEditingController _net = TextEditingController(text: _text(widget.shown.netRate));

  bool _saving = false;

  bool get _isPaid => kCollaborationTypes[_collaboration] == 'PAID';

  static String _text(int? cents) => cents == null ? '' : formatAmount(cents);

  @override
  void dispose()
  {
    _gross.dispose();
    _net.dispose();
    super.dispose();
  }

  void _onGrossChanged(String text)
  {
    final int? cents = parseAmountCents(text);

    _net.text = cents == null ? '' : formatAmount(netOfCents(cents));
  }

  Future<void> _save() async
  {
    final String rate = _gross.text.trim();

    if (_isPaid && rate.isNotEmpty && parseAmountCents(rate) == null)
    {
      CustomSnackBar.show(context: context, message: kInvalidAmount, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      await ApiService().updateCompensation(
        taxCode: widget.person.fiscalCode,
        month: widget.month,
        collaborationType: kCollaborationTypes[_collaboration] ?? widget.shown.collaborationType,
        grossCompensation: _isPaid ? amountPayloadOf(rate) : null,
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

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kCompensationEyebrow,
      title: kEditCompensationTitle,
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
              Text(
                compensationStartsNote(widget.month),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppTheme.trialMutedText,
                ),
              ),
              const SizedBox(height: _fieldGap),
              PersonChipGroupField(
                label: kCollaborationLabel,
                options: kCollaborationChoices,
                value: _collaboration,
                onChanged: (value) => setState(() => _collaboration = value),
              ),
              if (_isPaid) ...[
                const SizedBox(height: _fieldGap),
                AppTextField(
                  controller: _gross,
                  label: kGrossRateLabel,
                  hintText: kRateHint,
                  keyboardType: TextInputType.number,
                  nothingAbove: true,
                  onChanged: _onGrossChanged,
                ),
                const SizedBox(height: _fieldGap),
                AppTextField(
                  controller: _net,
                  label: kNetRateLabel,
                  hintText: '',
                  nothingAbove: true,
                  enabled: false,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
