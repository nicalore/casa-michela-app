import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/wizard_dialog.dart';

// Keeps 'INVIA SEGNALAZIONE' on one line.
const double _footerWidth = 576;

void showProblemReportDialog(BuildContext context)
{
  showBlurredDialog<void>(
    context: context,
    barrierLabel: 'ProblemReportDialog',
    builder: (_) => const _ProblemReportDialog(),
  );
}

class _ProblemReportDialog extends StatefulWidget
{
  const _ProblemReportDialog();

  @override
  State<_ProblemReportDialog> createState() => _ProblemReportDialogState();
}

class _ProblemReportDialogState extends State<_ProblemReportDialog>
{
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose()
  {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _send() async
  {
    if (_isSending)
    {
      return;
    }

    final String description = _descriptionController.text.trim();

    if (description.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'La descrizione non può essere vuota.',
        isError: true,
      );

      return;
    }

    setState(() => _isSending = true);

    try
    {
      await ApiService().reportProblem(description);

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: 'Segnalazione inviata con successo. Grazie!', isError: false);
      Navigator.of(context).pop();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Segnalazione',
      title: 'Segnala un problema',
      maxWidth: kWizardDialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'INVIA SEGNALAZIONE',
          icon: Icons.send_rounded,
          busy: _isSending,
          height: kWizardButtonHeight,
          fontSize: kWizardButtonFontSize,
          onPressed: _send,
        ),
        maxWidth: _footerWidth,
      ),
      children: [
        AppDialogPill(
          child: AppTextField(
            controller: _descriptionController,
            label: 'Descrizione',
            hintText: 'Descrivi il problema riscontrato...',
            maxLength: FieldLimits.description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            nothingAbove: true,
          ),
        ),
      ],
    );
  }
}
