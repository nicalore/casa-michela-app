import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../features/auth/models/me_response.dart';
import '../../../../features/onboarding/onboarding_steps.dart';
import '../../../../features/onboarding/widgets/contacts_card.dart' show ContactsDraft;
import '../../../../features/onboarding/widgets/teacher_education_card.dart' show TeacherEducationDraft;
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/widgets/person_detail_cards.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_text_field.dart';
import '../../profile/mobile_face_editor.dart';
import '../../profile/widgets/mobile_card_grid.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import '../../profile/widgets/mobile_own_face.dart';
import 'mobile_card_deck.dart';

const double _phoneFace = 72;
const double _tabletFace = 80;
const double _fieldGap = 16;

class MobileRecordStep extends StatefulWidget
{
  final PersonItem person;

  // Set on one's own record, whose face is the signed-in person's to change.
  final MeResponse? owner;

  // Backend role codes of the signed-in account; read on one's own record only.
  final List<String> accountRoles;

  final ValueChanged<ContactsDraft> onContactsChanged;
  final ValueChanged<TeacherEducationDraft> onEducationChanged;

  final bool tablet;
  final double margin;

  const MobileRecordStep({
    super.key,
    required this.person,
    required this.accountRoles,
    required this.onContactsChanged,
    required this.onEducationChanged,
    required this.tablet,
    required this.margin,
    this.owner,
  });

  @override
  State<MobileRecordStep> createState() => _MobileRecordStepState();
}

class _MobileRecordStepState extends State<MobileRecordStep>
{
  late final TextEditingController _email =
      TextEditingController(text: widget.person.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: formatPhoneNumber(widget.person.phoneNumber));

  late final TextEditingController _school =
      TextEditingController(text: widget.person.schoolEducation ?? '');
  late final TextEditingController _university =
      TextEditingController(text: widget.person.universityEducation ?? '');

  bool _faceBusy = false;

  bool get _own => widget.owner != null;

  bool get _teacher => _own && widget.accountRoles.contains(kTeacherRole);

  // The server refuses a university course for somebody still at school.
  bool get _atSchool => widget.person.isHighSchoolStudent ?? false;

  @override
  void initState()
  {
    super.initState();

    _email.addListener(_publishContacts);
    _phone.addListener(_publishContacts);
    _school.addListener(_publishEducation);
    _university.addListener(_publishEducation);
  }

  @override
  void dispose()
  {
    _email.dispose();
    _phone.dispose();
    _school.dispose();
    _university.dispose();
    super.dispose();
  }

  // Spacing is display only: the record keeps digits, with an optional plus.
  void _publishContacts()
  {
    widget.onContactsChanged(ContactsDraft(
      email: _email.text.trim(),
      phoneNumber: barePhoneNumber(_phone.text),
    ));
  }

  void _publishEducation()
  {
    String? cleaned(TextEditingController controller)
    {
      final String text = controller.text.trim();

      return text.isEmpty ? null : text;
    }

    widget.onEducationChanged(TeacherEducationDraft(
      schoolEducation: cleaned(_school),
      universityEducation: _atSchool ? null : cleaned(_university),
    ));
  }

  Future<void> _editFace(MeResponse user) async
  {
    await editMobileFace(
      context: context,
      user: user,
      onBusy: (busy)
      {
        if (mounted)
        {
          setState(() => _faceBusy = busy);
        }
      },
    );
  }

  // The face is read off the identity, which the photo sheet fetches again.
  Widget _buildFace(MeResponse owner)
  {
    return ValueListenableBuilder<MeResponse?>(
      valueListenable: ApiService().identity,
      builder: (context, identity, _)
      {
        final MeResponse user = identity ?? owner;

        return MobileOwnFace(
          user: user,
          size: widget.tablet ? _tabletFace : _phoneFace,
          busy: _faceBusy,
          onTap: () => _editFace(user),
        );
      },
    );
  }

  Widget _buildIdentity()
  {
    final PersonDetailCard card = identityCard(widget.person);
    final MeResponse? owner = widget.owner;

    return MobileDetailCard(
      icon: card.icon,
      title: card.title,
      rows: card.rows.whereType<DetailRowData>().toList(),
      trailing: owner == null ? null : _buildFace(owner),
    );
  }

  Widget _buildContacts()
  {
    return MobileDetailCard(
      icon: Icons.alternate_email_rounded,
      title: 'Contatti',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          MobileTextField(
            controller: _email,
            label: 'Email',
            hintText: 'nome@esempio.it',
            keyboardType: TextInputType.emailAddress,
            maxLength: FieldLimits.email,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _fieldGap),
          MobileTextField(
            controller: _phone,
            label: 'Telefono',
            hintText: '+39 …',
            keyboardType: TextInputType.phone,
            inputFormatters: const [PhoneInputFormatter()],
            maxLength: FieldLimits.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildStudies()
  {
    return MobileDetailCard(
      icon: Icons.school_rounded,
      title: 'I tuoi studi',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          MobileTextField(
            controller: _school,
            label: 'Studi scolastici',
            hintText: 'Es. Liceo scientifico',
            maxLength: FieldLimits.education,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: _atSchool ? TextInputAction.done : TextInputAction.next,
          ),
          if (!_atSchool) ...[
            const SizedBox(height: _fieldGap),
            MobileTextField(
              controller: _university,
              label: 'Studi universitari',
              hintText: 'Es. Ingegneria informatica',
              maxLength: FieldLimits.education,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _cards()
  {
    final PersonItem person = widget.person;

    final bool withAssociation = !_own ||
        includesAssociationCards(isAdult: person.isAdult, roles: widget.accountRoles);

    return [
      _buildIdentity(),
      MobileDetailCard.of(birthCard(person)),
      MobileDetailCard.of(residenceCard(person)),
      _buildContacts(),
      if (withAssociation) ...[
        for (final card in roleDetailCards(person, includeTeacherDetails: !_teacher))
          MobileDetailCard.of(card),
        if (_teacher) _buildStudies(),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    if (!widget.tablet)
    {
      return MobileCardDeck(pages: _cards(), margin: widget.margin);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.margin),
      child: MobileCardGrid(tablet: true, cards: _cards()),
    );
  }
}
