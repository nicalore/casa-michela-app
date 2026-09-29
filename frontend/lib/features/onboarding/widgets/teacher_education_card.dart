import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../people/models/person_item.dart';

// Edited directly on first access; the rest of the record goes through a correction request.
class TeacherEducationCard extends StatefulWidget
{
  final PersonItem person;

  final ValueChanged<TeacherEducationDraft> onChanged;

  const TeacherEducationCard({
    super.key,
    required this.person,
    required this.onChanged,
  });

  @override
  State<TeacherEducationCard> createState() => _TeacherEducationCardState();
}

class TeacherEducationDraft
{
  final String? schoolEducation;
  final String? universityEducation;

  const TeacherEducationDraft({this.schoolEducation, this.universityEducation});
}

class _TeacherEducationCardState extends State<TeacherEducationCard>
{
  late final TextEditingController _school;
  late final TextEditingController _university;

  // The server refuses a university course for somebody still at school.
  bool get _atSchool => widget.person.isHighSchoolStudent ?? false;

  @override
  void initState()
  {
    super.initState();

    _school = TextEditingController(text: widget.person.schoolEducation ?? '');
    _university = TextEditingController(text: widget.person.universityEducation ?? '');

    _school.addListener(_publish);
    _university.addListener(_publish);

    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  @override
  void dispose()
  {
    _school.dispose();
    _university.dispose();

    super.dispose();
  }

  void _publish()
  {
    String? cleaned(TextEditingController controller)
    {
      final text = controller.text.trim();

      return text.isEmpty ? null : text;
    }

    widget.onChanged(TeacherEducationDraft(
      schoolEducation: cleaned(_school),
      universityEducation: _atSchool ? null : cleaned(_university),
    ));
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'I tuoi studi',
      leading: const AppCardBadge(icon: Icons.school_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _school,
            label: 'Studi scolastici',
            hintText: 'Es. Liceo scientifico',
            maxLength: FieldLimits.education,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (!_atSchool)
            AppTextField(
              controller: _university,
              label: 'Studi universitari',
              hintText: 'Es. Ingegneria informatica',
              maxLength: FieldLimits.education,
              textCapitalization: TextCapitalization.sentences,
            ),
        ],
      ),
    );
  }
}
