import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../association/models/ministry_subject_item.dart';
import '../utils/booking_wizard_strings.dart' show kSingleDisciplineLabel;

const int kLongestBookingMinutes = 300;

// Mirrors the backend's booking_duration_step check constraint.
final List<int> bookingDurationOptions = [
  for (var minutes = kQuarterHour; minutes <= kLongestBookingMinutes; minutes += kQuarterHour) minutes,
];

// Values must stay aligned with BookingTagEnum on the backend.
class BookingTagOption
{
  final String value;
  final String label;

  const BookingTagOption(this.value, this.label);
}

List<BookingTagOption> get bookingTagOptions => <BookingTagOption>[
  BookingTagOption('STUDY', tr('Studio', 'Study')),
  BookingTagOption('HOMEWORK', tr('Compiti', 'Homework')),
  BookingTagOption('ORAL_TEST', tr('Preparazione interrogazione', 'Oral test preparation')),
  BookingTagOption('WRITTEN_TEST', tr('Preparazione verifica', 'Written test preparation')),
  BookingTagOption('ENRICHMENT', tr('Potenziamento', 'Enrichment')),
  BookingTagOption('OUTLINES', tr('Schemi', 'Outlines')),
  BookingTagOption('EXAM_PREPARATION', tr('Preparazione esami', 'Exam preparation')),
  BookingTagOption('CERTIFICATION', tr('Preparazione certificazione', 'Certification preparation')),
];

// Labels in option order, not press order; unknown values are left out.
List<String> bookingTagLabels(List<String> tags)
{
  return [
    for (final option in bookingTagOptions)
      if (tags.contains(option.value)) option.label,
  ];
}

class BookingFieldsSection extends StatelessWidget
{
  final List<MinistrySubjectItem> ministrySubjects;
  final int? ministrySubjectId;
  final ValueChanged<int?> onMinistrySubjectChanged;
  final Set<int> selectedAssociationSubjectIds;
  final ValueChanged<Set<int>> onAssociationSubjectIdsChanged;
  final int? duration;
  final ValueChanged<int> onDurationChanged;

  const BookingFieldsSection({
    super.key,
    required this.ministrySubjects,
    required this.ministrySubjectId,
    required this.onMinistrySubjectChanged,
    required this.selectedAssociationSubjectIds,
    required this.onAssociationSubjectIdsChanged,
    required this.duration,
    required this.onDurationChanged,
  });

  MinistrySubjectItem? get _selectedMinistrySubject
  {
    for (final subject in ministrySubjects)
    {
      if (subject.id == ministrySubjectId)
      {
        return subject;
      }
    }

    return null;
  }

  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final selectedMinistrySubject = _selectedMinistrySubject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ministrySubjects.isEmpty)
          Text(
            tr(
              'Nessuna materia ministeriale disponibile per il percorso di studi dello studente.',
              "No curriculum subjects available for the student's study programme.",
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        _buildFieldLabel(tr('Materia ministeriale', 'Curriculum subject'), first: true),
        AppDropdownField<int?>(
          hint: tr('Seleziona una materia', 'Select a subject'),
          options: ministrySubjects
              .map((subject) => AppDropdownOption<int?>(value: subject.id, label: subject.name))
              .toList(),
          value: ministrySubjectId,
          onChanged: (value)
          {
            onMinistrySubjectChanged(value);

            // A new subject drops the old disciplines; a lone discipline is auto-selected.
            final newSubject = ministrySubjects.where((subject) => subject.id == value).firstOrNull;
            final disciplines = newSubject?.associationSubjects ?? const [];

            onAssociationSubjectIdsChanged(disciplines.length == 1 ? {disciplines.single.id} : {});
          },
        ),
        if (selectedMinistrySubject != null) ...[
          _buildFieldLabel(tr('Discipline interne', 'Internal disciplines')),
          if (selectedMinistrySubject.associationSubjects.isEmpty)
            Text(
              tr('Nessuna disciplina interna collegata a questa materia.', 'No internal disciplines linked to this subject.'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.trialMutedText,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (selectedMinistrySubject.associationSubjects.length == 1)
            Text(
              '$kSingleDisciplineLabel${selectedMinistrySubject.associationSubjects.single.name}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialInk,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: selectedMinistrySubject.associationSubjects.map((subject)
              {
                return AppSelectableChip(
                  label: subject.name,
                  selected: selectedAssociationSubjectIds.contains(subject.id),
                  onSelected: (selected)
                  {
                    final updated = Set<int>.from(selectedAssociationSubjectIds);

                    if (selected)
                    {
                      updated.add(subject.id);
                    }
                    else
                    {
                      updated.remove(subject.id);
                    }

                    onAssociationSubjectIdsChanged(updated);
                  },
                );
              }).toList(),
            ),
        ],
        _buildFieldLabel(tr('Durata', 'Duration')),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: bookingDurationOptions.map((minutes)
          {
            return AppSelectableChip(
              label: '$minutes min',
              selected: duration == minutes,
              onSelected: (selected) => onDurationChanged(minutes),
            );
          }).toList(),
        ),
      ],
    );
  }
}
