import 'package:flutter/material.dart';

import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../people/models/person_item.dart';
import '../../people/widgets/person_detail_cards.dart';
import '../../people/widgets/person_detail_widgets.dart';
import '../../settings/widgets/profile_avatar.dart';
import '../onboarding_steps.dart';
import 'contacts_card.dart';
import 'teacher_education_card.dart';

const double _cardMaxWidth = 720;

// One record read a card at a time, the way the creation wizard asks its
// questions: arrows move between cards, the buttons underneath move between
// steps.
class OnboardingRecordStep extends StatefulWidget
{
  final PersonItem person;

  // The account's own record gets the editable face and, for a teacher, the
  // editable studies; a child's record is read as the register holds it.
  final bool isOwnRecord;

  // Backend role codes of the signed-in account; only read on its own record.
  final List<String> accountRoles;

  final ValueChanged<TeacherEducationDraft>? onEducationChanged;

  final ValueChanged<ContactsDraft> onContactsChanged;

  final VoidCallback onUpdated;

  final Widget footer;

  const OnboardingRecordStep({
    super.key,
    required this.person,
    required this.isOwnRecord,
    required this.accountRoles,
    required this.onUpdated,
    required this.footer,
    required this.onContactsChanged,
    this.onEducationChanged,
  });

  @override
  State<OnboardingRecordStep> createState() => _OnboardingRecordStepState();
}

class _OnboardingRecordStepState extends State<OnboardingRecordStep>
{
  int _index = 0;
  bool _movingForward = true;

  bool get _isTeacher => widget.isOwnRecord && widget.accountRoles.contains(kTeacherRole);

  List<Widget> _cards()
  {
    final PersonItem person = widget.person;

    final bool withAssociation = !widget.isOwnRecord ||
        includesAssociationCards(isAdult: person.isAdult, roles: widget.accountRoles);

    // The owner's face sits in the identity card's badge, editable on hover,
    // rather than on a card of its own.
    final Widget? face = widget.isOwnRecord
        ? ProfileAvatar(
            profileImageUrl: person.profileImageUrl,
            firstName: person.firstName,
            lastName: person.lastName,
            onImageUpdated: widget.onUpdated,
          )
        : null;

    return [
      identityCard(person, leading: face),
      birthCard(person),
      residenceCard(person),
      ContactsCard(
        person: person,
        onChanged: widget.onContactsChanged,
      ),
      if (withAssociation) ...[
        ...roleDetailCards(person, includeTeacherDetails: !_isTeacher),
        if (_isTeacher)
          TeacherEducationCard(
            person: person,
            onChanged: widget.onEducationChanged ?? (_) {},
          ),
      ],
    ];
  }

  void _turn(int to)
  {
    setState(()
    {
      _movingForward = to > _index;
      _index = to;
    });
  }

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> cards = _cards();

    // A new record starts from its first card.
    final int index = _index.clamp(0, cards.length - 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: pageTransitionBlocks([
          AppCarouselFrame(
            index: index,
            movingForward: _movingForward,
            maxContentWidth: _cardMaxWidth,
            canGoBack: index > 0,
            canGoForward: index < cards.length - 1,
            onBack: () => _turn(index - 1),
            onForward: () => _turn(index + 1),
            child: SizedBox(width: double.infinity, child: cards[index]),
          ),
          const SizedBox(height: kPersonSectionGap),
          widget.footer,
        ]),
      ),
    );
  }
}
