import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../features/association/models/ministry_subject_item.dart';
import '../../features/association/models/study_program_item.dart';

const Color _chipBackground = Color(0xFFF5F7FA);
const Color _tooltipBackground = AppTheme.slate800;
const Color _tooltipBorder = AppTheme.slate700;
const Color _tooltipLabel = AppTheme.slate400;
const Color _tooltipBullet = AppTheme.slate500;

// A ministry subject rendered as a chip that, on hover, reveals its internal
// disciplines in a dark tooltip. Shared by the school and study program detail
// dialogs, which display the same information the same way.
class MinistrySubjectChip extends StatelessWidget
{
  final MinistrySubjectOption option;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  const MinistrySubjectChip({
    super.key,
    required this.option,
    required this.availableMinistrySubjects,
  });

  // Resolves the option against the full list to recover its disciplines,
  // falling back to a placeholder built from the option itself when the
  // subject is not present in the loaded data.
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

  // Builds the "name • name • name" run, inserting a bullet between names.
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
      decoration: BoxDecoration(
        color: _tooltipBackground.withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tooltipBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          option.name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}