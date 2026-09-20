import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/calendar_day.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingTagLabels;
import '../../lessons/widgets/calendar_lesson_block.dart' show lessonAbout, lessonTitle;
import '../../lessons/widgets/person_avatar.dart';
import 'own_lesson_block.dart' show kSharedLessonIcon;
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';
import '../../people/widgets/person_detail_widgets.dart'
    show kObscuredLetterSpacing, kObscuredValue;

const double _dialogWidth = 1280;

const double _cardGap = 20;

const double _columnGap = 32;

// Read off the window: a LayoutBuilder cannot sit inside the IntrinsicHeight that levels the cards.
const double _twoColumnsFromWindow = 1160;

const double _voiceGap = 18;

const double _headingGap = 14;

const String _empty = '—';

const String _otherCertification = 'OTHER';

const String _studentFailedNote = 'Non è stato possibile leggere i dati dello studente.';

const String _sharedWith = 'Questa lezione è in compresenza con un altro studente';
const String _teacherFailedNote = 'Non è stato possibile leggere i dati del docente.';

class _Voice
{
  final String label;
  final String value;

  final bool alone;

  final bool sensitive;

  const _Voice({
    required this.label,
    required this.value,
    required this.alone,
    this.sensitive = false,
  });
}

Future<void> showOwnLessonDialog({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required CalendarView view,
  required Future<PersonItem> other,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'OwnLessonDetails',
    builder: (dialogContext) => _OwnLessonDialog(
      lesson: lesson,
      ministrySubjects: ministrySubjects,
      view: view,
      other: other,
    ),
  );
}

String _joined(Iterable<String> values, {String separator = ', '})
{
  final kept = [for (final value in values) if (value.trim().isNotEmpty) value.trim()];

  return kept.isEmpty ? _empty : kept.join(separator);
}

String _certifications(PersonItem person)
{
  final types = [
    for (final type in person.certificationTypes)
      if (type == _otherCertification)
        person.certificationOtherDetail?.trim() ?? ''
      else if (type == 'DSA' && (person.certificationDsaDetail?.trim().isNotEmpty ?? false))
        'DSA (${person.certificationDsaDetail!.trim()})'
      else
        type,
  ];

  return _joined(types, separator: ' – ');
}

SchoolEnrollmentItem? _currentYear(PersonItem person)
{
  final years = person.schoolEnrollments ?? const [];

  if (years.isEmpty)
  {
    return null;
  }

  return years.reduce((a, b) => a.startYear >= b.startYear ? a : b);
}

class _OwnLessonDialog extends StatelessWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;
  final CalendarView view;
  final Future<PersonItem> other;

  const _OwnLessonDialog({
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.other,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  String _perBooking(String Function(BookingSummaryItem booking) said)
  {
    return _joined([for (final entry in lesson.bookings) said(entry.booking)]);
  }

  List<_Voice> get _lessonVoices
  {
    final topic = _perBooking((booking) => booking.topic ?? '');
    final notes = _perBooking((booking) => booking.notes ?? '');

    final disciplines = lessonAbout(lesson, ministrySubjects).disciplines;

    return [
      _Voice(
        label: 'Orario',
        value: '${formatTimeRange(lesson.startTime, lesson.endTime)} · ${formatMinutes(lesson.minutes)}',
        alone: false,
      ),
      _Voice(
        label: 'Materia',
        value: _perBooking((booking) => bookingTitle(booking, ministrySubjects)),
        alone: false,
      ),
      if (disciplines != null) _Voice(label: 'Discipline', value: disciplines, alone: false),
      _Voice(
        label: 'Tipo di lezione',
        value: _perBooking((booking) => bookingTagLabels(booking.tags).join(', ')),
        alone: disciplines == null,
      ),
      _Voice(label: 'Argomento', value: topic, alone: true),
      _Voice(label: 'Note', value: notes, alone: true),
    ];
  }

  List<_Voice> _studentVoices(PersonItem person)
  {
    final age = person.age;
    final year = _currentYear(person);
    final repeating = year != null && isRepeatingYear(year, person.schoolEnrollments ?? const []);

    return [
      _Voice(label: 'Età', value: age == null ? _empty : '$age anni', alone: false),
      _Voice(
        label: 'Certificazioni',
        value: _certifications(person),
        alone: false,
        sensitive: true,
      ),
      _Voice(label: 'Scuola', value: person.schoolName?.trim() ?? _empty, alone: true),
      _Voice(label: 'Livello', value: person.educationLevel?.trim() ?? _empty, alone: true),
      _Voice(
        label: 'Percorso di studi',
        value: person.studyProgram == null ? _empty : studyProgramNameOnlyOf(person.studyProgram!),
        alone: true,
      ),
      _Voice(label: 'Classe', value: person.schoolClass?.trim() ?? _empty, alone: false),
      _Voice(label: 'Ripetente', value: year == null ? _empty : (repeating ? 'Sì' : 'No'), alone: false),
      // Not stored by the backend yet.
      _Voice(label: 'Osservazioni tecniche', value: _empty, alone: true),
      _Voice(label: 'Osservazioni metodologiche', value: _empty, alone: true),
    ];
  }

  // Empty when the hour is shared throughout.
  String get _sharedSentence
  {
    if (!lesson.isPartlyShared)
    {
      return _sharedWith;
    }

    final stretches = [
      for (final (start, end) in lesson.overlaps)
        'dalle ${formatTimeOfDayShort(start)} alle ${formatTimeOfDayShort(end)}',
    ];

    return '$_sharedWith ${stretches.join(' e ')}';
  }

  Widget _buildSharedLine()
  {
    return Padding(
      padding: const EdgeInsets.only(top: _voiceGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(kSharedLessonIcon, size: 18, color: AppTheme.trialTealDeep),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _sharedSentence,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Voice> _teacherVoices(PersonItem person)
  {
    final age = person.age;

    return [
      _Voice(label: 'Età', value: age == null ? _empty : '$age anni', alone: true),
      _Voice(label: 'Studi scolastici', value: person.schoolEducation?.trim() ?? _empty, alone: true),
      _Voice(label: 'Studi universitari', value: person.universityEducation?.trim() ?? _empty, alone: true),
    ];
  }

  Widget _buildHeading(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: _headingGap),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildNote(String text)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontStyle: FontStyle.italic,
        height: 1.4,
        color: AppTheme.trialMutedText,
      ),
    );
  }

  Widget _buildSection(String heading, Widget body)
  {
    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeading(heading),
          body,
        ],
      ),
    );
  }

  Widget _buildLessonSection({required bool wide})
  {
    return _buildSection(
      'Lezione',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VoicesGrid(voices: _lessonVoices, wide: wide),
          if (_byStudent && lesson.isShared) _buildSharedLine(),
        ],
      ),
    );
  }

  Widget _buildOtherSection({required bool wide})
  {
    return _buildSection(
      _byStudent ? 'Docente' : 'Studente',
      FutureBuilder<PersonItem>(
        future: other,
        builder: (context, snapshot)
        {
          final person = snapshot.data;

          if (person != null)
          {
            return _VoicesGrid(
              voices: _byStudent ? _teacherVoices(person) : _studentVoices(person),
              wide: wide,
            );
          }

          if (snapshot.hasError)
          {
            return _buildNote(_byStudent ? _teacherFailedNote : _studentFailedNote);
          }

          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.trialTurquoise),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final face = _byStudent ? lesson.teacher : lesson.bookings.firstOrNull?.presence.student;
    final wide = MediaQuery.sizeOf(context).width >= _twoColumnsFromWindow;

    return AppDialogStack(
      eyebrow: 'Lezione',
      title: lessonTitle(lesson, view: view),
      leading: face == null ? null : PersonAvatar(person: face, size: PersonAvatar.titleSize),
      subtitle: Text(
        formatWeekdayColumnLabel(lesson.date),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppTheme.trialMutedText,
        ),
      ),
      maxWidth: _dialogWidth,
      children: [
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildLessonSection(wide: true)),
                const SizedBox(width: _cardGap),
                Expanded(child: _buildOtherSection(wide: true)),
              ],
            ),
          )
        else ...[
          _buildLessonSection(wide: false),
          _buildOtherSection(wide: false),
        ],
      ],
    );
  }
}

class _VoiceValue extends StatelessWidget
{
  final String value;

  final double letterSpacing;

  const _VoiceValue({required this.value, this.letterSpacing = 0});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      value,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.45,
        letterSpacing: letterSpacing,
        color: value == _empty ? AppTheme.trialMutedText : AppTheme.trialInk,
      ),
    );
  }
}

class _ObscurableValue extends StatefulWidget
{
  final String value;

  const _ObscurableValue({required this.value});

  @override
  State<_ObscurableValue> createState() => _ObscurableValueState();
}

class _ObscurableValueState extends State<_ObscurableValue>
{
  bool _isVisible = false;

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _VoiceValue(
            value: _isVisible ? widget.value : kObscuredValue,
            letterSpacing: _isVisible ? 0 : kObscuredLetterSpacing,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => setState(() => _isVisible = !_isVisible),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            _isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 22,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }
}

class _VoicesGrid extends StatelessWidget
{
  final List<_Voice> voices;

  final bool wide;

  const _VoicesGrid({required this.voices, required this.wide});

  List<List<_Voice>> get _rows
  {
    final rows = <List<_Voice>>[];

    for (final voice in voices)
    {
      if (voice.alone || rows.isEmpty || rows.last.length == 2 || rows.last.single.alone)
      {
        rows.add([voice]);

        continue;
      }

      rows.last.add(voice);
    }

    return rows;
  }

  Widget _buildVoice(_Voice voice)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(voice.label),
        const SizedBox(height: 6),
        if (voice.sensitive && voice.value != _empty)
          _ObscurableValue(value: voice.value)
        else
          _VoiceValue(value: voice.value),
      ],
    );
  }

  Widget _buildRow(List<_Voice> row, {required bool wide})
  {
    if (!wide || row.length == 1)
    {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < row.length; index++) ...[
            if (index > 0) const SizedBox(height: _voiceGap),
            _buildVoice(row[index]),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < row.length; index++) ...[
          if (index > 0) const SizedBox(width: _columnGap),
          Expanded(child: _buildVoice(row[index])),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final rows = _rows;

    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: _voiceGap),
            _buildRow(rows[index], wide: wide),
          ],
        ],
      ),
    );
  }
}
