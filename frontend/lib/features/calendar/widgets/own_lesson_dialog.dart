import 'dart:math' as math;

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

const double _labelGap = 24;

const double _rowPadding = 11;

// Read off the window: a LayoutBuilder cannot sit inside the IntrinsicHeight that levels the cards.
const double _twoColumnsFromWindow = 1160;

const double _voiceGap = 18;

const double _headingGap = 14;

const String kVoiceEmpty = '—';

const String _empty = kVoiceEmpty;

const String _otherCertification = 'OTHER';

const String kStudentFailedNote = 'Non è stato possibile leggere i dati dello studente.';

const String _sharedWith = 'Questa lezione è in compresenza con un altro studente';
const String kTeacherFailedNote = 'Non è stato possibile leggere i dati del docente.';

class LessonVoice
{
  final String label;
  final String value;

  final bool sensitive;

  const LessonVoice({
    required this.label,
    required this.value,
    this.sensitive = false,
  });
}

Future<void> showOwnLessonDialog({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required CalendarView view,
  required Future<PersonItem> other,
}) async
{
  // Read before opening, so the cards come up at their final size.
  PersonItem? person;

  try
  {
    person = await other;
  }
  catch (_) {}

  if (!context.mounted)
  {
    return;
  }

  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'OwnLessonDetails',
    builder: (dialogContext) => _OwnLessonDialog(
      lesson: lesson,
      ministrySubjects: ministrySubjects,
      view: view,
      other: person,
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

List<LessonVoice> lessonVoicesOf(LessonItem lesson, List<MinistrySubjectItem> ministrySubjects)
{
  String perBooking(String Function(BookingSummaryItem booking) said)
  {
    return _joined([for (final entry in lesson.bookings) said(entry.booking)]);
  }

  final topic = perBooking((booking) => booking.topic ?? '');
  final notes = perBooking((booking) => booking.notes ?? '');

  final disciplines = lessonAbout(lesson, ministrySubjects).disciplines;

  return [
    LessonVoice(
      label: 'Orario',
      value: '${formatTimeRange(lesson.startTime, lesson.endTime)} · ${formatMinutes(lesson.minutes)}',
    ),
    LessonVoice(
      label: 'Materia',
      value: perBooking((booking) => bookingTitle(booking, ministrySubjects)),
    ),
    if (disciplines != null) LessonVoice(label: 'Discipline', value: disciplines),
    LessonVoice(
      label: 'Tipo di lezione',
      value: perBooking((booking) => bookingTagLabels(booking.tags).join(', ')),
    ),
    LessonVoice(label: 'Argomento', value: topic),
    LessonVoice(label: 'Note', value: notes),
  ];
}

List<LessonVoice> studentVoicesOf(PersonItem person)
{
  final age = person.age;
  final year = _currentYear(person);
  final repeating = year != null && isRepeatingYear(year, person.schoolEnrollments ?? const []);

  return [
    LessonVoice(label: 'Età', value: age == null ? _empty : '$age anni'),
    LessonVoice(
      label: 'Certificazioni',
      value: _certifications(person),
      sensitive: true,
    ),
    LessonVoice(label: 'Scuola', value: person.schoolName?.trim() ?? _empty),
    LessonVoice(label: 'Livello', value: person.educationLevel?.trim() ?? _empty),
    LessonVoice(
      label: 'Percorso di studi',
      value: person.studyProgram == null ? _empty : studyProgramNameOnlyOf(person.studyProgram!),
    ),
    LessonVoice(label: 'Classe', value: person.schoolClass?.trim() ?? _empty),
    LessonVoice(label: 'Ripetente', value: year == null ? _empty : (repeating ? 'Sì' : 'No')),
    // Not stored by the backend yet.
    LessonVoice(label: 'Osservazioni tecniche', value: _empty),
    LessonVoice(label: 'Osservazioni metodologiche', value: _empty),
  ];
}

List<LessonVoice> teacherVoicesOf(PersonItem person)
{
  final age = person.age;

  return [
    LessonVoice(label: 'Età', value: age == null ? _empty : '$age anni'),
    LessonVoice(label: 'Studi scolastici', value: person.schoolEducation?.trim() ?? _empty),
    LessonVoice(label: 'Studi universitari', value: person.universityEducation?.trim() ?? _empty),
  ];
}

class _OwnLessonDialog extends StatelessWidget
{
  final LessonItem lesson;
  final List<MinistrySubjectItem> ministrySubjects;
  final CalendarView view;

  // Null when it could not be read.
  final PersonItem? other;

  const _OwnLessonDialog({
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.other,
  });

  bool get _byStudent => view == CalendarView.byStudent;

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

  Widget _buildLessonSection()
  {
    return _buildSection(
      'Lezione',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VoicesTable(voices: lessonVoicesOf(lesson, ministrySubjects)),
          if (_byStudent && lesson.isShared) _buildSharedLine(),
        ],
      ),
    );
  }

  Widget _buildOtherSection()
  {
    final person = other;

    return _buildSection(
      _byStudent ? 'Docente' : 'Studente',
      person == null
          ? _buildNote(_byStudent ? kTeacherFailedNote : kStudentFailedNote)
          : _VoicesTable(voices: _byStudent ? teacherVoicesOf(person) : studentVoicesOf(person)),
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
                // The row is one piece of the stack; nested pieces stagger the two cards.
                Expanded(
                  child: AppDialogPiece(index: 1, named: false, child: _buildLessonSection()),
                ),
                const SizedBox(width: _cardGap),
                Expanded(
                  child: AppDialogPiece(index: 2, named: false, child: _buildOtherSection()),
                ),
              ],
            ),
          )
        else ...[
          _buildLessonSection(),
          _buildOtherSection(),
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

class _VoicesTable extends StatelessWidget
{
  final List<LessonVoice> voices;

  const _VoicesTable({required this.voices});

  // Measured over the ambient style, as the labels are drawn.
  double _labelWidth(BuildContext context)
  {
    final TextStyle style = DefaultTextStyle.of(context).style.merge(fieldLabelStyle());
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    var widest = 0.0;

    for (final voice in voices)
    {
      final painter = TextPainter(
        text: TextSpan(text: voice.label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();

      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return widest.ceilToDouble();
  }

  Widget _buildValue(LessonVoice voice)
  {
    return voice.sensitive && voice.value != _empty
        ? _ObscurableValue(value: voice.value)
        : _VoiceValue(value: voice.value);
  }

  @override
  Widget build(BuildContext context)
  {
    // Measured again once fonts load, as the labels themselves are laid out again.
    return ListenableBuilder(
      listenable: PaintingBinding.instance.systemFonts,
      builder: (context, _) => _buildRows(context, _labelWidth(context)),
    );
  }

  Widget _buildRows(BuildContext context, double labelWidth)
  {
    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, voice) in voices.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: index == 0 ? null : const Border(top: BorderSide(color: AppTheme.trialLine)),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : _rowPadding, bottom: _rowPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(width: labelWidth, child: AppFieldLabel(voice.label)),
                    const SizedBox(width: _labelGap),
                    Expanded(child: _buildValue(voice)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
