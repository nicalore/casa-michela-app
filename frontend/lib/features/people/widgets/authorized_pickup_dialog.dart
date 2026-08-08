import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../models/parental_relationship_draft.dart';

// Who may collect a minor on an early exit, and when they may not, why. It
// opens on ticking a parent or a child, in every dialog that relates the two.

Future<ParentalRelationshipDraft?> showAuthorizedPickupDialog(
  BuildContext context, {
  required String personTaxCode,
  required String parentName,
  required String childName,
  ParentalRelationshipDraft? existing,
})
{
  return showBlurredDialog<ParentalRelationshipDraft?>(
    context: context,
    barrierLabel: 'AuthorizedPickup',
    builder: (context) => _AuthorizedPickupDialog(
      personTaxCode: personTaxCode,
      parentName: parentName,
      childName: childName,
      existing: existing,
    ),
  );
}

class _AuthorizedPickupDialog extends StatefulWidget
{
  final String personTaxCode;
  final String parentName;
  final String childName;
  final ParentalRelationshipDraft? existing;

  const _AuthorizedPickupDialog({
    required this.personTaxCode,
    required this.parentName,
    required this.childName,
    this.existing,
  });

  @override
  State<_AuthorizedPickupDialog> createState() =>
      _AuthorizedPickupDialogState();
}

class _AuthorizedPickupDialogState extends State<_AuthorizedPickupDialog>
{
  late bool _authorized;
  late final TextEditingController _reasonCtrl;

  @override
  void initState()
  {
    super.initState();
    _authorized = widget.existing?.authorizedPickup ?? true;
    _reasonCtrl = TextEditingController(
      text: widget.existing?.restrictionReason ?? '',
    );
  }

  @override
  void dispose()
  {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // The reason stays optional even when pickup is not authorized: no blocking
  // validation.
  void _confirm()
  {
    final String reason = _reasonCtrl.text.trim();

    Navigator.of(context).pop(
      ParentalRelationshipDraft(
        taxCode: widget.personTaxCode,
        authorizedPickup: _authorized,
        restrictionReason: (_authorized || reason.isEmpty) ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Autorizzazione al ritiro',
      title: widget.parentName,
      maxWidth: 580,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CONFERMA',
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${widget.parentName} ha l\'autorizzazione a ritirare '
                '${widget.childName} in caso di uscita anticipata?',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.trialInk,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              AppSegmentedSwitch(
                value: _authorized,
                trueLabel: 'Sì',
                falseLabel: 'No',
                onChanged: (value) => setState(() => _authorized = value),
              ),
              // The room is always kept and only the opacity changes, so the
              // window never resizes as the field comes and goes.
              AnimatedOpacity(
                opacity: _authorized ? 0 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _authorized,
                  child: AppTextField(
                    controller: _reasonCtrl,
                    label: 'Motivo',
                    hintText: 'Es. Divieto di avvicinamento',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Chooses whether to lay the year and start date side by side or stacked, like MembershipEditRow in PersonMembershipsTab.
// When stacked, the remove button moves next to the last field.
