import 'package:flutter/material.dart';

import '../../core/constants/field_limits.dart';
import 'app_carousel_frame.dart';
import 'app_dialog_footer.dart';
import 'app_dialog_stack.dart';
import 'app_field_label.dart';
import 'app_gradient_button.dart';
import 'app_text_field.dart';
import 'snackbar.dart';

const double kWizardButtonHeight = 52;
const double kWizardButtonFontSize = 14;

const double kWizardDialogWidth = 540;

class DescriptionField extends StatelessWidget
{
  final TextEditingController controller;

  const DescriptionField(this.controller, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return AppTextField(
      controller: controller,
      label: 'Descrizione (opzionale)',
      hintText: 'Aggiungi una descrizione...',
      maxLength: FieldLimits.description,
      textCapitalization: TextCapitalization.sentences,
      minLines: 1,
      maxLines: 4,
    );
  }
}

class WizardFieldLabel extends StatelessWidget
{
  final String text;

  const WizardFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: AppFieldLabel(text),
    );
  }
}

mixin WizardDialogState<T extends StatefulWidget> on State<T>
{
  bool _saving = false;

  bool get isSaving => _saving;

  bool get isEditing;

  VoidCallback? get onCancelEdit;

  void resetForm();

  void showError(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  void closeDialog()
  {
    Navigator.of(context).pop();

    if (isEditing)
    {
      onCancelEdit?.call();
    }
  }

  // The tail every wizard shares: an edit closes on success, a new entry empties
  // itself so the next one can be typed straight in, and a refusal leaves the
  // form exactly as it was so nothing has to be retyped.
  Future<void> runSave(
    Future<bool> Function(void Function(String) onError) save,
  ) async
  {
    setState(() => _saving = true);

    final success = await save(showError);

    if (!mounted)
    {
      return;
    }

    setState(() => _saving = false);

    if (!success)
    {
      return;
    }

    if (isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      resetForm();
    }
  }

  Widget buildConfirmButton(VoidCallback onSubmit)
  {
    return AppDialogFooter.single(
      AppGradientButton(
        label: isEditing ? 'SALVA' : 'CREA',
        icon: Icons.check_rounded,
        busy: isSaving,
        height: kWizardButtonHeight,
        fontSize: kWizardButtonFontSize,
        onPressed: onSubmit,
      ),
    );
  }

  Widget buildSingleStepDialog({
    required String eyebrow,
    required String title,
    required VoidCallback onSubmit,
    required List<Widget> fields,
  })
  {
    return AppDialogStack(
      eyebrow: eyebrow,
      title: title,
      onClose: closeDialog,
      maxWidth: kWizardDialogWidth,
      footer: buildConfirmButton(onSubmit),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: fields,
          ),
        ),
      ],
    );
  }
}

mixin TwoStepWizardState<T extends StatefulWidget> on WizardDialogState<T>
{
  int _step = 0;
  bool _movingForward = true;

  int get step => _step;

  bool get movingForward => _movingForward;

  String? get firstStepBlockedReason;

  void goToStep(int step)
  {
    setState(()
    {
      _movingForward = step > _step;
      _step = step;
    });
  }

  // Called from inside the caller's own setState, while the rest of the form is
  // being emptied — hence no setState of its own.
  void rewindSteps()
  {
    _step = 0;
    _movingForward = false;
  }

  bool validateFirstStep()
  {
    final reason = firstStepBlockedReason;

    if (reason != null)
    {
      showError(reason);

      return false;
    }

    return true;
  }

  // The arrows are the only way between the two steps, and the first one holds
  // the second shut until it is filled in — hence forwardBlockedReason, which
  // is what the arrow says when it refuses.
  Widget buildTwoStepDialog({
    required String title,
    required double contentMaxWidth,
    required VoidCallback onSubmit,
    required Widget Function() firstStep,
    required Widget Function() secondStep,
  })
  {
    return AppDialogStack(
      eyebrow: 'Passo ${step + 1} di 2',
      title: title,
      onClose: closeDialog,
      maxWidth: contentMaxWidth +
          2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap),
      footer: buildConfirmButton(onSubmit),
      children: [
        AppCarouselFrame(
          index: step,
          movingForward: movingForward,
          maxContentWidth: contentMaxWidth,
          canGoBack: step > 0,
          canGoForward: step == 0,
          forwardBlockedReason: step == 0 ? firstStepBlockedReason : null,
          onBack: () => goToStep(0),
          onForward: () => goToStep(1),
          child: AppDialogPill(child: step == 0 ? firstStep() : secondStep()),
        ),
      ],
    );
  }
}
