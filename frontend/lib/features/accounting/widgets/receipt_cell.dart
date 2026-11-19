import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../people/utils/student_notes_strings.dart'
    show kCancelLabel, kConfirmTitle, kDeleteLabel, kDeletionEyebrow;
import '../models/teacher_month_items.dart';
import '../utils/accounting_strings.dart';

// The cell's button: as wide as the column ever needs.
const double kReceiptButtonWidth = 38;
const double _buttonHeight = 30;
const double _radius = 10;
const Duration _fade = Duration(milliseconds: 150);

Color get _receiptSurface => ThemeColours.of(0xFFE3F1F0);

const double _confirmWidth = 480;

// A paid teacher's receipt for the month: a button to upload it, or the receipt
// itself with its menu.
class ReceiptCell extends StatelessWidget
{
  final PaymentReceipt? receipt;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const ReceiptCell({
    super.key,
    required this.receipt,
    required this.busy,
    required this.onUpload,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context)
  {
    final PaymentReceipt? receipt = this.receipt;

    // The same button as the one that saves a rule, and the same sweep on hover.
    if (busy || receipt == null)
    {
      return AppGradientButton(
        label: kUploadReceipt,
        icon: Icons.upload_file_rounded,
        iconOnlyTooltip: kUploadReceipt,
        width: kReceiptButtonWidth,
        height: _buttonHeight,
        fontSize: 14,
        radius: _radius,
        busy: busy,
        onPressed: busy ? () {} : onUpload,
      );
    }

    return AppAnchoredMenu(
      alignEnd: true,
      gap: 6,
      builder: (context, open, toggle) => AppTooltip(
        message: '${receipt.fileName}\n${receiptUploadedOn(receipt.uploadedAt)}',
        child: _ReceiptButton(lit: open, onTap: toggle),
      ),
      menu: (context, close) => AppMenuCard(
        width: 200,
        children: [
          AppMenuItem(
            icon: Icons.open_in_new_rounded,
            text: kOpenReceipt,
            dense: true,
            onTap: ()
            {
              close();
              onOpen();
            },
          ),
          AppMenuItem(
            icon: Icons.autorenew_rounded,
            text: kReplaceReceipt,
            dense: true,
            onTap: ()
            {
              close();
              onUpload();
            },
          ),
          AppMenuItem(
            icon: Icons.delete_outline_rounded,
            text: kDeleteReceipt,
            color: AppTheme.trialDangerText,
            dense: true,
            onTap: ()
            {
              close();
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}

// The receipt that is there: tinted, with a teal rim under the pointer and while its menu is open.
class _ReceiptButton extends StatefulWidget
{
  final bool lit;
  final VoidCallback onTap;

  const _ReceiptButton({required this.lit, required this.onTap});

  @override
  State<_ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends State<_ReceiptButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final BorderRadius corners = BorderRadius.circular(_radius);

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: kReceiptButtonWidth,
            height: _buttonHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: _receiptSurface, borderRadius: corners),
                  child: const SizedBox.expand(),
                ),
                AnimatedOpacity(
                  opacity: _hover || widget.lit ? 1 : 0,
                  duration: _fade,
                  curve: Curves.easeOut,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: corners,
                      border: Border.all(color: AppTheme.trialTurquoise, width: 1.5),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Icon(Icons.receipt_long_rounded, size: 18, color: AppTheme.trialTealDeepText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmReceiptDeletion(BuildContext context) async
{
  final bool? confirmed = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'ConfirmReceiptDeletion',
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
            kDeleteReceiptQuestion,
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
