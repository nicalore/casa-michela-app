import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/utils/phone_number.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../people/models/person_item.dart';

// Edited directly, not through a correction request.
class ContactsCard extends StatefulWidget
{
  final PersonItem person;

  final ValueChanged<ContactsDraft> onChanged;

  const ContactsCard({
    super.key,
    required this.person,
    required this.onChanged,
  });

  @override
  State<ContactsCard> createState() => _ContactsCardState();
}

class ContactsDraft
{
  final String email;
  final String phoneNumber;

  const ContactsDraft({required this.email, required this.phoneNumber});

  // Spacing is display only: the record keeps digits, with an optional plus.
  bool differsFrom(PersonItem person)
  {
    return email != (person.email ?? '') ||
        barePhoneNumber(phoneNumber) != barePhoneNumber(person.phoneNumber);
  }
}

class _ContactsCardState extends State<ContactsCard>
{
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState()
  {
    super.initState();

    _email = TextEditingController(text: widget.person.email ?? '');
    _phone = TextEditingController(text: formatPhoneNumber(widget.person.phoneNumber));

    _email.addListener(_publish);
    _phone.addListener(_publish);
  }

  @override
  void dispose()
  {
    _email.dispose();
    _phone.dispose();

    super.dispose();
  }

  void _publish()
  {
    widget.onChanged(ContactsDraft(
      email: _email.text.trim(),
      phoneNumber: barePhoneNumber(_phone.text),
    ));
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Contatti',
      leading: const AppCardBadge(icon: Icons.alternate_email_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _email,
            label: 'Email',
            hintText: 'nome@esempio.it',
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
    );
  }
}
