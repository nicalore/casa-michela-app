import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../device_notifications.dart';
import '../notification_item.dart';
import '../notification_kinds.dart';
import '../notification_strings.dart';

const double _maxWidth = 640;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _rowGap = 8;
const Duration _fade = Duration(milliseconds: 160);

// Every kind of the account's roles, the ones on ticked; saved for every device on confirm.
Future<void> showNotificationKindsDialog(BuildContext context)
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'NotificationKinds',
    builder: (_) => const _KindsDialog(),
  );
}

class _KindsDialog extends StatefulWidget
{
  const _KindsDialog();

  @override
  State<_KindsDialog> createState() => _KindsDialogState();
}

class _KindsDialogState extends State<_KindsDialog>
{
  late final List<NotificationKindChoice> _choices = NotificationKinds.instance.choices ?? const [];

  late final Map<NotificationKind, bool> _picked = {
    for (final choice in _choices) choice.kind: choice.enabled,
  };

  bool _saving = false;

  Future<void> _confirm() async
  {
    setState(() => _saving = true);

    try
    {
      await DeviceNotifications.chooseKinds([
        for (final choice in _choices) choice.turned(_picked[choice.kind] ?? choice.enabled),
      ]);

      // Closed by its close button meanwhile, a pop would take the page under it.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false))
      {
        Navigator.of(context).pop();
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _saving = false);
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kNotificationsSettingTitle,
      title: kNotificationKindsTitle,
      maxWidth: _maxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kNotificationKindsConfirm.toUpperCase(),
          icon: Icons.check_rounded,
          busy: _saving,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Text(
            kNotificationKindsHint,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, choice) in _choices.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index > 0 ? _rowGap : 0),
                  child: _KindRow(
                    kind: choice.kind,
                    selected: _picked[choice.kind] ?? false,
                    onTap: () => setState(() => _picked[choice.kind] = !(_picked[choice.kind] ?? false)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KindRow extends StatefulWidget
{
  final NotificationKind kind;
  final bool selected;
  final VoidCallback onTap;

  const _KindRow({required this.kind, required this.selected, required this.onTap});

  @override
  State<_KindRow> createState() => _KindRowState();
}

class _KindRowState extends State<_KindRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final (String title, String text) = kNotificationKindLabels[widget.kind] ?? ('', '');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _fade,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            // Not Colors.transparent: the fade would pass through grey.
            color: widget.selected ? kPickedSurface : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AppCheckMark(selected: widget.selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
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
    );
  }
}
