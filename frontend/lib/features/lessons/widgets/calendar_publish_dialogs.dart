import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../utils/online_only.dart';
import '../utils/opening_window.dart';
import 'calendar_lesson_block.dart' show lessonModeIcon;
import 'person_avatar.dart';

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
          Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.modifiedAccent),
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

// Who comes in only to connect from the association, with their hours: the last look
// before the convocations go.
Widget _onlineOnly(List<OnlineOnlyTeacher> teachers)
{
  final bool one = teachers.length == 1;

  return AppDialogPill(
    expand: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(lessonModeIcon(kOnlineMode), size: 20, color: AppTheme.trialTealDeepText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(
                  one ? 'Verrà in sede solo per lezioni online' : 'Verranno in sede solo per lezioni online',
                  'On site for online lessons only',
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  color: AppTheme.trialOceanText,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 6, bottom: 4),
          child: Text(
            one
                ? tr(
                    'Ha dato disponibilità solo in presenza: si collegherà dai computer dell\'Associazione.',
                    "They gave in-person availability only: they will connect from the Association's computers.",
                  )
                : tr(
                    'Hanno dato disponibilità solo in presenza: si collegheranno dai computer dell\'Associazione.',
                    "They gave in-person availability only: they will connect from the Association's computers.",
                  ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        for (final teacher in teachers)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.trialLine)),
              ),
              child: Row(
                children: [
                  PersonAvatar(person: teacher.teacher, size: PersonAvatar.listSize),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          teacher.teacher.fullName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialOceanText,
                          ),
                        ),
                        Text(
                          '${formatMinutesRange(teacher.startMinutes, teacher.endMinutes)} ('
                          '${teacher.lessons == 1 ? tr('1 lezione', '1 lesson') : tr('${teacher.lessons} lezioni', '${teacher.lessons} lessons')})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.trialMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

AppGradientButton _dismiss(BuildContext context)
{
  return AppGradientButton(
    label: tr('ANNULLA', 'CANCEL'),
    icon: Icons.close_rounded,
    gradient: AppTheme.dismissGradient,
    accent: AppTheme.dismissAccent,
    height: _dialogButtonHeight,
    fontSize: _dialogButtonFontSize,
    onPressed: () => Navigator.pop(context, false),
  );
}

Future<bool?> showPublishConfirmation({
  required BuildContext context,
  List<String> warnings = const [],
  List<OnlineOnlyTeacher> onlineOnly = const [],
})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmPublish',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: tr('Pubblicazione', 'Publication'),
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: tr('PUBBLICA', 'PUBLISH'),
          icon: Icons.send_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(tr('Il calendario verrà inviato a docenti, genitori e studenti.', 'The calendar will be sent to teachers, parents and students.')),
        if (onlineOnly.isNotEmpty) _onlineOnly(onlineOnly),
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
      eyebrow: tr('Ritorno in bozza', 'Back to draft'),
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: tr('MODIFICA', 'EDIT'),
          icon: Icons.edit_outlined,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(tr(
          'Il calendario attuale resterà visibile a docenti, genitori e studenti. '
              'Le modifiche saranno inviate solo se confermate.',
          'The current calendar will stay visible to teachers, parents and students. Changes will be sent only if confirmed.',
        )),
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
      eyebrow: tr('Uscita dalla bozza', 'Leaving the draft'),
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: tr('ESCI', 'LEAVE'),
          icon: Icons.undo_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(tr('Le modifiche effettuate verranno annullate.', 'The changes made will be discarded.')),
      ],
    ),
  );
}

Future<bool?> showPublishChangesConfirmation({
  required BuildContext context,
  List<String> warnings = const [],
  List<OnlineOnlyTeacher> onlineOnly = const [],
})
{
  return showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmPublishChanges',
    builder: (dialogContext) => AppDialogStack(
      eyebrow: tr('Modifiche', 'Changes'),
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: _dismiss(dialogContext),
        primary: AppGradientButton(
          label: tr('PUBBLICA', 'PUBLISH'),
          icon: Icons.send_rounded,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ),
      children: [
        _question(tr(
          'Il calendario aggiornato verrà inviato a docenti, genitori e studenti.',
          'The updated calendar will be sent to teachers, parents and students.',
        )),
        if (onlineOnly.isNotEmpty) _onlineOnly(onlineOnly),
        if (warnings.isNotEmpty) _caution(warnings),
      ],
    ),
  );
}
