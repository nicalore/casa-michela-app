import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/phone_number.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../onboarding/widgets/contacts_card.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_cards.dart';
import '../widgets/person_detail_widgets.dart';

const double _cardsWidth = 1200;

const double _dialogWidth = 560;

class OwnInfoTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Rendered beside the edit button, inside the scroll.
  final Widget? footer;

  const OwnInfoTab({
    super.key,
    required this.person,
    required this.onUpdate,
    this.footer,
  });

  void _edit(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'OwnContactsEdit',
      builder: (context) => _EditContactsDialog(person: person, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pageTransitionBlocks([
              PersonDetailCardPair(
                first: identityCard(person),
                second: residenceCard(person),
              ),
              const SizedBox(height: kPersonCardGap),
              PersonDetailCardPair(
                first: birthCard(person),
                second: contactsCard(person),
              ),
              const SizedBox(height: 48),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    AppGradientButton(
                      label: 'MODIFICA CONTATTI',
                      icon: Icons.edit_rounded,
                      onPressed: () => _edit(context),
                    ),
                    ?footer,
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EditContactsDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _EditContactsDialog({required this.person, required this.onUpdate});

  @override
  State<_EditContactsDialog> createState() => _EditContactsDialogState();
}

class _EditContactsDialogState extends State<_EditContactsDialog>
{
  late final TextEditingController _email;
  late final TextEditingController _phone;

  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();

    _email = TextEditingController(text: widget.person.email ?? '');
    _phone = TextEditingController(text: formatPhoneNumber(widget.person.phoneNumber));
  }

  @override
  void dispose()
  {
    _email.dispose();
    _phone.dispose();

    super.dispose();
  }

  // Written only when something changed; the server says what is wrong.
  Future<void> _save() async
  {
    final draft = ContactsDraft(
      email: _email.text.trim(),
      phoneNumber: barePhoneNumber(_phone.text),
    );

    if (!draft.differsFrom(widget.person))
    {
      Navigator.of(context).pop();

      return;
    }

    setState(() => _isSaving = true);

    try
    {
      await ApiService().updateContacts(
        taxCode: widget.person.fiscalCode,
        email: draft.email,
        phoneNumber: draft.phoneNumber,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Contatti aggiornati con successo!',
          isError: false,
        );

        Navigator.of(context).pop();
        widget.onUpdate();
      }
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Contatti',
      title: 'Modifica contatti',
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _email,
                label: 'Email',
                hintText: 'nome@esempio.it',
                nothingAbove: true,
                maxLength: FieldLimits.email,
              ),
              AppTextField(
                controller: _phone,
                label: 'Telefono',
                hintText: '+39 …',
                maxLength: FieldLimits.phone,
                inputFormatters: const [PhoneInputFormatter()],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
