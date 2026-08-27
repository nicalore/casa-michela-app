import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_entity_chip.dart';
import '../../features/association/models/ministry_subject_item.dart';
import '../../features/association/models/study_program_item.dart';

const Color _tooltipLabel = AppTheme.slate400;
const Color _tooltipBullet = AppTheme.slate500;

class MinistrySubjectChip extends StatelessWidget
{
  final MinistrySubjectOption option;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  const MinistrySubjectChip({
    super.key,
    required this.option,
    required this.availableMinistrySubjects,
  });

  MinistrySubjectItem get _resolvedSubject
  {
    return availableMinistrySubjects.firstWhere(
      (subject) => subject.id == option.id,
      orElse: () => MinistrySubjectItem(
        id: option.id,
        name: option.name,
        level: '',
        areas: const [],
        description: '',
        createdAt: DateTime.now(),
        associationSubjects: const [],
      ),
    );
  }

  List<Widget> _buildDisciplineRun(MinistrySubjectItem subject)
  {
    final widgets = <Widget>[];

    for (var i = 0; i < subject.associationSubjects.length; i++)
    {
      if (i > 0)
      {
        widgets.add(Text(
          '•',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _tooltipBullet),
        ));
      }

      widgets.add(Text(
        subject.associationSubjects[i].name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context)
  {
    final subject = _resolvedSubject;

    return Tooltip(
      constraints: const BoxConstraints(maxWidth: 400),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: 'Discipline interne:\n',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _tooltipLabel,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          if (subject.associationSubjects.isEmpty)
            TextSpan(
              text: 'Nessuna disciplina associata',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            )
          else
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _buildDisciplineRun(subject),
                ),
              ),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      waitDuration: const Duration(milliseconds: 200),
      child: AppEntityChip(label: option.name),
    );
  }
}