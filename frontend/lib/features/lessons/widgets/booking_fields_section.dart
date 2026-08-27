import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../association/models/ministry_subject_item.dart';

// Mirrors the backend's booking_duration_step check constraint.
final List<int> bookingDurationOptions = [
  for (var minutes = 30; minutes <= 120; minutes += 15) minutes,
];

// Per-discipline daily ceiling per mode. The backend holds the same ceiling and
// is what actually refuses; this only lets the window say so before the round trip.
const int maxDailyMinutesPerDiscipline = 120;

// Values must stay aligned with BookingTagEnum on the backend.
class BookingTagOption
{
  final String value;
  final String label;

  const BookingTagOption(this.value, this.label);
}

const List<BookingTagOption> bookingTagOptions = <BookingTagOption>[
  BookingTagOption('STUDY', 'Studio'),
  BookingTagOption('HOMEWORK', 'Compiti'),
  BookingTagOption('ORAL_TEST', 'Preparazione interrogazione'),
  BookingTagOption('WRITTEN_TEST', 'Preparazione verifica'),
  BookingTagOption('ENRICHMENT', 'Potenziamento'),
  BookingTagOption('OUTLINES', 'Schemi'),
  BookingTagOption('EXAM_PREPARATION', 'Preparazione esami'),
  BookingTagOption('CERTIFICATION', 'Preparazione certificazione'),
];

// Labels in option order, not press order; unknown values are left out.
List<String> bookingTagLabels(List<String> tags)
{
  return [
    for (final option in bookingTagOptions)
      if (tags.contains(option.value)) option.label,
  ];
}

// Controlled form section for a booking's own fields, reused standalone and
// inside the presence creation wizard.
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
            'Nessuna materia ministeriale disponibile per il percorso di studi dello studente.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppTheme.trialMutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        _buildFieldLabel('Materia ministeriale', first: true),
        AppDropdownField<int?>(
          hint: 'Seleziona una materia',
          options: ministrySubjects
              .map((subject) => AppDropdownOption<int?>(value: subject.id, label: subject.name))
              .toList(),
          value: ministrySubjectId,
          onChanged: (value)
          {
            onMinistrySubjectChanged(value);

            // A new ministry subject invalidates the old disciplines; a lone
            // discipline is auto-selected.
            final newSubject = ministrySubjects.where((subject) => subject.id == value).firstOrNull;
            final disciplines = newSubject?.associationSubjects ?? const [];

            onAssociationSubjectIdsChanged(disciplines.length == 1 ? {disciplines.single.id} : {});
          },
        ),
        if (selectedMinistrySubject != null) ...[
          _buildFieldLabel('Discipline interne'),
          if (selectedMinistrySubject.associationSubjects.isEmpty)
            Text(
              'Nessuna disciplina interna collegata a questa materia.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.trialMutedText,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (selectedMinistrySubject.associationSubjects.length == 1)
            Text(
              'Disciplina: ${selectedMinistrySubject.associationSubjects.single.name}',
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
        _buildFieldLabel('Durata'),
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
