import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/iban.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/person_item.dart';
import '../utils/compensation_strings.dart';
import '../utils/student_notes_strings.dart'
    show kCancelLabel, kConfirmTitle, kDeleteLabel, kDeletionEyebrow, kSaveLabel;

const double _dialogWidth = 600;
const double _confirmWidth = 480;

// The new IBAN, null if nothing changed.
Future<String?> showIbanDialog({
  required BuildContext context,
  required PersonItem person,
  required String? iban,
}) async
{
  return showBlurredDialog<String>(
    context: context,
    barrierLabel: 'Iban',
    builder: (context) => _IbanDialog(person: person, iban: iban),
  );
}

Future<bool> confirmIbanDeletion(BuildContext context) async
{
  final bool? confirmed = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmIbanDeletion',
    builder: (confirmContext) => AppDialogStack(
      eyebrow: kDeletionEyebrow,
      title: kConfirmTitle,
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kCancelLabel,
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialVioletText,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.pop(confirmContext, false),
        ),
        primary: AppGradientButton(
          label: kDeleteLabel,
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.pop(confirmContext, true),
        ),
      ),
      children: [
        AppDialogPill(
          child: Text(
            kDeleteIbanQuestion,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

class _IbanDialog extends StatefulWidget
{
  final PersonItem person;
  final String? iban;

  const _IbanDialog({required this.person, required this.iban});

  @override
  State<_IbanDialog> createState() => _IbanDialogState();
}

class _IbanDialogState extends State<_IbanDialog>
{
  late final TextEditingController _field = TextEditingController(text: widget.iban);

  bool _saving = false;

  @override
  void dispose()
  {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    if (_saving)
    {
      return;
    }

    final String iban = normalizedIban(_field.text);

    if (!isItalianIban(iban))
    {
      CustomSnackBar.show(context: context, message: kInvalidIban, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      await ApiService().updateIban(widget.person.fiscalCode, iban);

      if (mounted)
      {
        Navigator.of(context).pop(iban);
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
      eyebrow: kIbanLabel,
      title: widget.iban == null ? kAddIbanTitle : kEditIbanTitle,
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
          child: AppTextField(
            controller: _field,
            label: kIbanLabel,
            hintText: kIbanHint,
            maxLength: FieldLimits.iban,
            nothingAbove: true,
            // Before the limit: a pasted IBAN often comes in groups of four.
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            onSubmitted: (_) => _save(),
          ),
        ),
      ],
    );
  }
}
