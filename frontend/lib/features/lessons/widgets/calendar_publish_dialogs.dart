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

Widget _caution(List<String> warnings)
{
  return AppDialogPill(
    expand: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.modifiedAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (at, sentence) in warnings.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: at == 0 ? 0 : 6),
                    child: Text(
                      sentence,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: AppTheme.modifiedAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

Future<bool?> showPublishConfirmation({
  required BuildContext context,
  List<String> warnings = const [],
})
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
        if (warnings.isNotEmpty) _caution(warnings),
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

Future<bool?> showPublishChangesConfirmation({
  required BuildContext context,
  List<String> warnings = const [],
})
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
        if (warnings.isNotEmpty) _caution(warnings),
      ],
    ),
  );
}
