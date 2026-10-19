import 'package:flutter/material.dart';

import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/models/school_enrollment_item.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart';
import '../../../../features/people/widgets/school_enrollment_edit_row.dart';
import '../../../layout/mobile_breakpoints.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_empty_card.dart';
import 'mobile_card_grid.dart';
import 'mobile_detail_card.dart';

const double _cardRadius = 22;

class MobileSchoolYears extends StatelessWidget
{
  final PersonItem person;

  // Null leaves the years read-only.
  final ValueChanged<SchoolEnrollmentItem>? onEdit;

  const MobileSchoolYears({super.key, required this.person, this.onEdit});

  // Most recent first, as the desktop wizard reads them.
  static List<SchoolEnrollmentItem> yearsOf(PersonItem person)
  {
    return [...?person.schoolEnrollments]..sort((a, b) => b.startYear.compareTo(a.startYear));
  }

  Widget _buildYear(SchoolEnrollmentItem year)
  {
    final bool current = year.startYear == currentSchoolYearStart();
    final ValueChanged<SchoolEnrollmentItem>? onEdit = this.onEdit;

    final Widget card = MobileDetailCard(
      icon: current ? Icons.school_rounded : Icons.history_rounded,
      eyebrow: current ? 'Anno scolastico attuale' : null,
      title: 'Anno scolastico ${year.startYear}/${year.startYear + 1}',
      rows: [
        DetailRowData('Scuola', year.schoolName),
        DetailRowData('Percorso', year.studyProgramNameOnly),
        DetailRowData('Classe', gradeLabel(year.grade)),
      ],
      onEdit: onEdit == null ? null : () => onEdit(year),
      editLabel: onEdit == null ? null : 'Modifica anno scolastico',
    );

    if (!current)
    {
      return card;
    }

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const MobileCurrentCard(BorderRadius.all(Radius.circular(_cardRadius))),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<SchoolEnrollmentItem> years = yearsOf(person);

    if (years.isEmpty)
    {
      return Center(
        child: MobileEmptyCard(
          icon: Icons.school_rounded,
          message: 'Nessun anno scolastico registrato.',
          tablet: MobileBreakpoints.of(context).isTablet,
        ),
      );
    }

    return MobileCardGrid(
      tablet: false,
      cards: [for (final year in years) _buildYear(year)],
    );
  }
}
