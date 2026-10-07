import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/birthday.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../lessons/models/booking_summary_item.dart';
import '../../lessons/models/calendar_day.dart';
import '../../lessons/models/lesson_item.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingTagLabels;
import '../../lessons/widgets/calendar_lesson_block.dart' show lessonAbout, lessonTitle, lessonWhere;
import '../../lessons/widgets/person_avatar.dart';
import 'own_lesson_block.dart' show kSharedLessonIcon;
import 'teacher_note_dialog.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';
import '../../people/models/student_note_item.dart';
import '../../people/utils/student_notes_strings.dart';
import '../../people/widgets/person_detail_widgets.dart'
    show kObscuredLetterSpacing, kObscuredValue;
import '../../people/widgets/student_notes_card.dart' show noteDate;

const double _dialogWidth = 1280;

const double _singleWidth = 680;

// Twice the button's width: "AGGIUNGI OSSERVAZIONE" keeps to one line.
const double _noteFooterWidth = 680;

const double _cardGap = 20;

const double _labelGap = 24;

const double _rowPadding = 11;

// Read off the window: a LayoutBuilder cannot sit inside the IntrinsicHeight that levels the cards.
const double _twoColumnsFromWindow = 1160;

const double _voiceGap = 18;

const double _headingGap = 14;

const double _noteGap = 14;

// As tall as the eye, so the two column heads end on one line.
const double _columnHeadHeight = 24;

const double _stackedColumnsGap = 26;

const String kVoiceEmpty = '—';

const String _empty = kVoiceEmpty;

const String _otherCertification = 'OTHER';

const String kStudentFailedNote = 'Non è stato possibile leggere i dati dello studente.';

const String _birthdayToday = 'Oggi è il suo compleanno';

const double _voiceIconGap = 6;

const String _sharedWith = 'Questa lezione è in compresenza con un altro studente';
const String kTeacherFailedNote = 'Non è stato possibile leggere i dati del docente.';

class LessonVoice
{
  final String label;
  final String value;

  final bool sensitive;

  final IconData? icon;

  // Counted in [value]; mobile opens them from the row.
  final List<StudentNoteItem>? notes;

  const LessonVoice({
    required this.label,
    required this.value,
    this.sensitive = false,
    this.icon,
    this.notes,
  });
}

Widget voiceValueText(String value, TextStyle style, {IconData? icon})
{
  if (icon == null)
  {
    return Text(value, style: style);
  }

  return Text.rich(
    TextSpan(
      children: [
        TextSpan(text: value),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: _voiceIconGap),
            child: Icon(icon, size: (style.fontSize ?? 16) + 2, color: AppTheme.trialGold),
          ),
        ),
      ],
    ),
    style: style,
  );
}

Future<void> showOwnLessonDialog({
  required BuildContext context,
  required LessonItem lesson,
  required List<MinistrySubjectItem> ministrySubjects,
  required CalendarView view,
  // Null: the lesson's card alone, as for a teacher's day gone by.
  required Future<PersonItem>? other,
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
      withOther: other != null,
    ),
  );
}

String sharedLessonSentence(LessonItem lesson)
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

String _joined(Iterable<String> values, {String separator = ', '})
{
  final kept = [for (final value in values) if (value.trim().isNotEmpty) value.trim()];

  return kept.isEmpty ? _empty : kept.join(separator);
}

LessonVoice _notesVoice(String label, List<StudentNoteItem>? notes)
{
  final List<StudentNoteItem> all = notes ?? const [];

  return LessonVoice(label: label, value: all.isEmpty ? _empty : notesCountLabel(all.length), notes: all);
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

// [where]: the room, or "Online", for a pupil, who may change room lesson by lesson.
List<LessonVoice> lessonVoicesOf(LessonItem lesson, List<MinistrySubjectItem> ministrySubjects, {bool where = false})
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
    if (where) LessonVoice(label: 'Stanza', value: lessonWhere(lesson).label),
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

LessonVoice _studentAge(PersonItem person)
{
  const label = 'Età';
  final age = person.age;

  if (age == null)
  {
    return const LessonVoice(label: label, value: _empty);
  }

  if (!isBirthdayToday(person.birthDate, romeNow()))
  {
    return LessonVoice(label: label, value: '$age anni');
  }

  return LessonVoice(label: label, value: '$age anni – $_birthdayToday', icon: Icons.cake_rounded);
}

// [notes]: false on desktop, where the notes take a card of their own.
List<LessonVoice> studentVoicesOf(PersonItem person, {bool notes = true})
{
  final year = _currentYear(person);
  final repeating = year != null && isRepeatingYear(year, person.schoolEnrollments ?? const []);

  return [
    _studentAge(person),
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
    if (notes) ...[
      _notesVoice(kTechnicalNotesTitle, person.technicalNotes),
      _notesVoice(kMethodologicalNotesTitle, person.methodologicalNotes),
    ],
    LessonVoice(
      label: 'Altre informazioni',
      value: _joined([person.allergiesNotes ?? '', person.medicationsNotes ?? ''], separator: '\n'),
      sensitive: true,
    ),
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

  final bool withOther;

  const _OwnLessonDialog({
    required this.lesson,
    required this.ministrySubjects,
    required this.view,
    required this.other,
    required this.withOther,
  });

  bool get _byStudent => view == CalendarView.byStudent;

  // The note goes to the administrators: the lesson's window stays as it was.
  Future<void> _addNote(BuildContext context) async
  {
    if (await showTeacherNoteDialog(context, lesson, ministrySubjects) && context.mounted)
    {
      CustomSnackBar.show(context: context, message: kNoteSent);
    }
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
              sharedLessonSentence(lesson),
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
          _VoicesTable(voices: lessonVoicesOf(lesson, ministrySubjects, where: _byStudent)),
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
          : _VoicesTable(
              voices: _byStudent ? teacherVoicesOf(person) : studentVoicesOf(person, notes: false),
            ),
    );
  }

  Widget _buildNotesSection(PersonItem student, {required bool wide})
  {
    final technical = _NotesColumn(label: 'Tecniche', notes: student.technicalNotes ?? const []);
    final methodological = _NotesColumn(
      label: 'Metodologiche',
      notes: student.methodologicalNotes ?? const [],
      sensitive: true,
    );

    return _buildSection(
      'Osservazioni',
      SelectionArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: technical),
                  const SizedBox(width: _cardGap + 2 * kDialogPillPadding),
                  Expanded(child: methodological),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  technical,
                  const SizedBox(height: _stackedColumnsGap),
                  methodological,
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final face = _byStudent ? lesson.teacher : lesson.bookings.firstOrNull?.presence.student;
    final wide = MediaQuery.sizeOf(context).width >= _twoColumnsFromWindow;
    final PersonItem? student = _byStudent ? null : other;

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
      maxWidth: withOther ? _dialogWidth : _singleWidth,
      footer: _byStudent || !lessonHasBegun(lesson, romeNow())
          ? null
          : AppDialogFooter.single(
              maxWidth: _noteFooterWidth,
              AppGradientButton(
                label: kAddNoteLabel,
                icon: Icons.add_rounded,
                height: 52,
                fontSize: 14,
                onPressed: () => _addNote(context),
              ),
            ),
      children: [
        if (!withOther)
          _buildLessonSection()
        else if (wide) ...[
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
          ),
          // Third after the two cards, as when they stand one under the other.
          if (student != null)
            AppDialogPiece(index: 3, named: false, child: _buildNotesSection(student, wide: true)),
        ]
        else ...[
          _buildLessonSection(),
          _buildOtherSection(),
          if (student != null) _buildNotesSection(student, wide: false),
        ],
      ],
    );
  }
}

class _VoiceValue extends StatelessWidget
{
  final String value;

  final IconData? icon;

  final double letterSpacing;

  const _VoiceValue({required this.value, this.icon, this.letterSpacing = 0});

  @override
  Widget build(BuildContext context)
  {
    return voiceValueText(
      value,
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.45,
        letterSpacing: letterSpacing,
        color: value == _empty ? AppTheme.trialMutedText : AppTheme.trialInk,
      ),
      icon: icon,
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
        _EyeButton(open: _isVisible, onPressed: () => setState(() => _isVisible = !_isVisible)),
      ],
    );
  }
}

class _EyeButton extends StatelessWidget
{
  final bool open;
  final VoidCallback onPressed;

  const _EyeButton({required this.open, required this.onPressed});

  @override
  Widget build(BuildContext context)
  {
    return IconButton(
      onPressed: onPressed,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      // A padded 48 px target hangs the eye below the first line.
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      icon: Icon(
        open ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 22,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}

// [sensitive] notes stay masked until the eye opens them all.
class _NotesColumn extends StatefulWidget
{
  final String label;
  final List<StudentNoteItem> notes;

  final bool sensitive;

  const _NotesColumn({required this.label, required this.notes, this.sensitive = false});

  @override
  State<_NotesColumn> createState() => _NotesColumnState();
}

class _NotesColumnState extends State<_NotesColumn>
{
  bool _isVisible = false;

  bool get _masked => widget.sensitive && widget.notes.isNotEmpty;

  Widget _buildHead()
  {
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.trialLine))),
      child: Padding(
        padding: const EdgeInsets.only(bottom: _rowPadding),
        child: SizedBox(
          height: _columnHeadHeight,
          child: Row(
            children: [
              Expanded(child: AppFieldLabel(widget.label)),
              if (_masked)
                _EyeButton(open: _isVisible, onPressed: () => setState(() => _isVisible = !_isVisible)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNote(int index, StudentNoteItem note)
  {
    final bool last = index == widget.notes.length - 1;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: index == 0 ? null : const Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: _noteGap, bottom: last ? 0 : _noteGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noteDate(note.createdAt),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialOcean,
              ),
            ),
            const SizedBox(height: 4),
            _VoiceValue(value: note.text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<StudentNoteItem> notes = widget.notes;
    final bool hidden = _masked && !_isVisible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHead(),
        if (notes.isEmpty || hidden)
          Padding(
            padding: const EdgeInsets.only(top: _noteGap),
            child: hidden
                ? const _VoiceValue(value: kObscuredValue, letterSpacing: kObscuredLetterSpacing)
                : const _VoiceValue(value: _empty),
          )
        else
          for (final (index, note) in notes.indexed) _buildNote(index, note),
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
        : _VoiceValue(value: voice.value, icon: voice.icon);
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
