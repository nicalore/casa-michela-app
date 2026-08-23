import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

Widget _question(String sentence)
{
  return AppDialogPill(
    child: Text(
      sentence,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppTheme.trialInk,
      ),
    ),
  );
}

AppGradientButton _dismiss(BuildContext context)
{
  return AppGradientButton(
    label: 'ANNULLA',
    icon: Icons.close_rounded,
    gradient: AppTheme.dismissGradient,
    accent: AppTheme.trialViolet,
    height: _dialogButtonHeight,
    fontSize: _dialogButtonFontSize,
    onPressed: () => Navigator.pop(context, false),
  );
}

Future<bool?> showPublishConfirmation({required BuildContext context})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmPublish',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: 'Pubblicazione',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: 'PUBBLICA',
          icon: Icons.send_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question('Il calendario verrà inviato a docenti, genitori e studenti.'),
      ],
    ),
  );
}

Future<bool?> showDraftConfirmation({required BuildContext context})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmDraft',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: 'Ritorno in bozza',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: 'MODIFICA',
          icon: Icons.edit_outlined,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(
          'Il calendario attuale resterà visibile a docenti, genitori e studenti. '
              'Le modifiche saranno inviate solo se confermate.',
        ),
      ],
    ),
  );
}

// Asked only where there is something to throw away: a bozza nobody touched
// simply closes, and a question about nothing is a window about nothing.
Future<bool?> showDiscardDraftConfirmation({required BuildContext context})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmDiscardDraft',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: 'Uscita dalla bozza',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: 'ESCI',
          icon: Icons.undo_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question('Le modifiche effettuate verranno annullate.'),
      ],
    ),
  );
}

Future<bool?> showPublishChangesConfirmation({required BuildContext context})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmPublishChanges',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: 'Modifiche',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: 'PUBBLICA',
          icon: Icons.send_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(
          'Il calendario aggiornato verrà inviato a docenti, genitori e studenti.',
        ),
      ],
    ),
  );
}
