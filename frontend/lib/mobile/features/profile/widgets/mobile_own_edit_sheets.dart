import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../features/onboarding/widgets/contacts_card.dart' show ContactsDraft;
import '../../../../features/people/models/person_item.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

const double _fieldGap = 16;

// Resolves to true once the contacts are saved, so the page reloads them.
Future<bool> showMobileContactsSheet({
  required BuildContext context,
  required PersonItem person,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    builder: (context) => _ContactsSheet(person: person),
  );

  return saved ?? false;
}

Future<bool> showMobileStudiesSheet({
  required BuildContext context,
  required PersonItem person,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    builder: (context) => _StudiesSheet(person: person),
  );

  return saved ?? false;
}

class _EditSheet extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final List<Widget> fields;
  final bool busy;
  final VoidCallback onSave;

  const _EditSheet({
    required this.eyebrow,
    required this.title,
    required this.fields,
    required this.busy,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: eyebrow,
        title: title,
        aboveKeyboard: true,
        body: [
          const SizedBox(height: 20),
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(height: _fieldGap),
            fields[i],
          ],
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: 'Salva',
            icon: Icons.check_rounded,
            busy: busy,
            onPressed: onSave,
          ),
        ),
      ),
    );
  }
}

class _ContactsSheet extends StatefulWidget
{
  final PersonItem person;

  const _ContactsSheet({required this.person});

  @override
  State<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends State<_ContactsSheet>
{
  late final TextEditingController _email = TextEditingController(text: widget.person.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: formatPhoneNumber(widget.person.phoneNumber));

  bool _busy = false;

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
    final ContactsDraft draft = ContactsDraft(
      email: _email.text.trim(),
      phoneNumber: barePhoneNumber(_phone.text),
    );

    if (!draft.differsFrom(widget.person))
    {
      Navigator.of(context).pop(false);

      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().updateContacts(
        taxCode: widget.person.fiscalCode,
        email: draft.email,
        phoneNumber: draft.phoneNumber,
      );

      if (mounted)
      {
        MobileNotice.show(context, 'Contatti aggiornati con successo!');
        Navigator.of(context).pop(true);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return _EditSheet(
      eyebrow: 'Contatti',
      title: 'Modifica contatti',
      busy: _busy,
      onSave: _save,
      fields: [
        MobileTextField(
          controller: _email,
          label: 'Email',
          icon: Icons.mail_rounded,
          hintText: 'nome@esempio.it',
          keyboardType: TextInputType.emailAddress,
          maxLength: FieldLimits.email,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        MobileTextField(
          controller: _phone,
          label: 'Telefono',
          icon: Icons.call_rounded,
          hintText: '+39 …',
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneInputFormatter()],
          maxLength: FieldLimits.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}

class _StudiesSheet extends StatefulWidget
{
  final PersonItem person;

  const _StudiesSheet({required this.person});

  @override
  State<_StudiesSheet> createState() => _StudiesSheetState();
}

class _StudiesSheetState extends State<_StudiesSheet>
{
  late final TextEditingController _school =
      TextEditingController(text: widget.person.schoolEducation ?? '');
  late final TextEditingController _university =
      TextEditingController(text: widget.person.universityEducation ?? '');

  bool _busy = false;

  // Not editable here; the server rejects university education for a high-school student.
  bool get _atSchool => widget.person.isHighSchoolStudent ?? false;

  @override
  void dispose()
  {
    _school.dispose();
    _university.dispose();

    super.dispose();
  }

  String? _cleaned(TextEditingController controller)
  {
    final String text = controller.text.trim();

    return text.isEmpty ? null : text;
  }

  Future<void> _save() async
  {
    setState(() => _busy = true);

    try
    {
      await ApiService().updateTeacherEducation(
        taxCode: widget.person.fiscalCode,
        schoolEducation: _cleaned(_school),
        universityEducation: _atSchool ? null : _cleaned(_university),
      );

      if (mounted)
      {
        MobileNotice.show(context, 'Studi aggiornati con successo!');
        Navigator.of(context).pop(true);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return _EditSheet(
      eyebrow: 'Studi',
      title: 'Modifica studi',
      busy: _busy,
      onSave: _save,
      fields: [
        MobileTextField(
          controller: _school,
          label: 'Studi scolastici',
          icon: Icons.school_rounded,
          hintText: 'Es. Liceo scientifico',
          maxLength: FieldLimits.education,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: _atSchool ? TextInputAction.done : TextInputAction.next,
        ),
        if (!_atSchool)
          MobileTextField(
            controller: _university,
            label: 'Studi universitari',
            icon: Icons.account_balance_rounded,
            hintText: 'Es. Ingegneria informatica',
            maxLength: FieldLimits.education,
            textCapitalization: TextCapitalization.sentences,
          ),
      ],
    );
  }
}
