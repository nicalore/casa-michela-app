import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../association/tabs/opening_hours/hours_grid.dart' show TodayFrame;
import '../../lessons/widgets/person_avatar.dart';
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';
import '../../people/models/student_note_item.dart';
import '../../people/widgets/person_detail_widgets.dart' show missingValue;
import '../../people/widgets/school_enrollment_edit_row.dart' show currentSchoolYearStart, gradeLabel;
import '../../people/widgets/student_notes_card.dart';
import '../psychologist_strings.dart';
import 'certifications_dialog.dart' show kCertificationLabels;

const String kTourStudentSchool = 'psychologist.school';
const String kTourStudentCertifications = 'psychologist.certifications';
const String kTourStudentNotes = 'psychologist.notes';
const String kTourStudentNoteDate = 'psychologist.note.date';
const String kTourStudentNoteTools = 'psychologist.note.tools';

const double _cardGap = 24;
const double _faceSize = 96;

const double _yearRadius = 16;
const double _columnGap = 28;
const double _yearPaddingH = 20;
const double _yearPaddingV = 14;

// Below the wide window (AppPageDensity).
const double _denseCardGap = 14;
const double _denseFaceSize = 56;
const double _denseNameSize = 22;
const double _denseLabelSize = 12;
const double _denseValueSize = 14.5;
const double _denseYearRadius = 14;
const double _denseColumnGap = 24;
const double _denseYearPaddingH = 16;
const double _denseYearPaddingV = 10;
const double _denseLineGap = 8;

const String _otherCode = 'OTHER';
const String _dsaCode = 'DSA';

TextStyle _labelStyle([double size = 14]) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: FontWeight.w500,
  color: AppTheme.trialMutedText,
);

TextStyle _valueStyle([double size = 18]) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: AppTheme.trialInk,
);

TextStyle get _bodyStyle => GoogleFonts.plusJakartaSans(
  fontSize: 16.5,
  fontWeight: FontWeight.w500,
  height: 1.6,
  color: AppTheme.trialInk,
);

class StudentSheet extends StatelessWidget
{
  final PersonItem student;

  // Author-only edits: only this person's notes get the pencil and the bin.
  final String? ownTaxCode;

  final VoidCallback onEditCertifications;
  final VoidCallback onAddNote;
  final ValueChanged<StudentNoteItem> onEditNote;
  final ValueChanged<StudentNoteItem> onDeleteNote;

  // False when the page's heading already shows the pupil (below 1000 px).
  final bool identity;

  const StudentSheet({
    super.key,
    required this.student,
    required this.ownTaxCode,
    required this.onEditCertifications,
    required this.onAddNote,
    required this.onEditNote,
    required this.onDeleteNote,
    this.identity = true,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final Widget gap = SizedBox(height: dense ? _denseCardGap : _cardGap);

    return PageTransitionScrollView(
      child: Padding(
        padding: EdgeInsets.only(bottom: dense ? 24 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: pageTransitionBlocks([
            if (identity) ...[
              _IdentityCard(student: student),
              gap,
            ],
            DesktopTourTarget(id: kTourStudentSchool, child: _SchoolCard(student: student)),
            gap,
            DesktopTourTarget(id: kTourStudentCertifications, child: _buildCertifications(dense)),
            gap,
            if (_otherInformation.isNotEmpty) ...[
              _buildOtherInformation(dense),
              gap,
            ],
            DesktopTourTarget(
              id: kTourStudentNotes,
              child: StudentNotesCard(
                title: kMethodologicalNotesTitle,
                icon: Icons.psychology_rounded,
                taxCode: student.fiscalCode,
                kind: StudentNoteKind.methodological,
                notes: student.methodologicalNotes ?? const [],
                onAdd: onAddNote,
                mayChange: (note) => note.authorTaxCode == ownTaxCode,
                onEdit: onEditNote,
                onDelete: onDeleteNote,
                tourDate: kTourStudentNoteDate,
                tourTools: kTourStudentNoteTools,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cardButton(String label, IconData icon, VoidCallback onPressed)
  {
    return AppGradientButton(
      label: label,
      icon: icon,
      height: 40,
      radius: 20,
      fontSize: 13,
      onPressed: onPressed,
    );
  }

  Widget _fact(String label, String value, bool dense)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: dense ? _labelStyle(12.5) : _labelStyle()),
        SizedBox(height: dense ? 2 : 4),
        Text(value, style: dense ? _valueStyle(15) : _valueStyle()),
      ],
    );
  }

  Widget _buildCertifications(bool dense)
  {
    final List<String> codes = [
      for (final code in kCertificationLabels.keys)
        if (student.certificationTypes.contains(code)) code,
    ];

    final String? dsa = student.certificationDsaDetail?.trim();
    final String? other = student.certificationOtherDetail?.trim();

    final List<Widget> details = [
      if (codes.contains(_dsaCode)) _fact(kDsaDetailLabel, dsa == null || dsa.isEmpty ? missingValue : dsa, dense),
      if (codes.contains(_otherCode))
        _fact(kOtherDetailLabel, other == null || other.isEmpty ? missingValue : other, dense),
    ];

    return AppCard(
      title: kCertificationsTitle,
      compact: !dense,
      leading: AppCardBadge(icon: Icons.assignment_outlined, compact: !dense),
      trailing: _cardButton(kEditLabel, Icons.edit_rounded, onEditCertifications),
      child: codes.isEmpty
          ? Text(missingValue, style: dense ? _valueStyle(15) : _valueStyle())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final code in codes) CertificationChip(kCertificationLabels[code]!, large: true, dense: dense),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  SizedBox(height: dense ? 14 : 20),
                  Wrap(spacing: dense ? 32 : 48, runSpacing: dense ? 12 : 16, children: details),
                ],
              ],
            ),
    );
  }

  List<String> get _otherInformation => [
    for (final value in [student.allergiesNotes, student.medicationsNotes])
      if (value != null && value.trim().isNotEmpty) value.trim(),
  ];

  Widget _buildOtherInformation(bool dense)
  {
    return AppCard(
      title: kOtherInformationTitle,
      compact: !dense,
      leading: AppCardBadge(icon: Icons.health_and_safety_outlined, compact: !dense),
      child: Text(
        _otherInformation.join('\n'),
        style: dense ? _bodyStyle.copyWith(fontSize: _denseValueSize, height: 1.5) : _bodyStyle,
      ),
    );
  }
}

class CertificationChip extends StatelessWidget
{
  final String label;

  final bool large;

  // Below the wide window: each size a step smaller.
  final bool dense;

  const CertificationChip(this.label, {super.key, this.large = false, this.dense = false});

  EdgeInsets get _padding
  {
    if (large)
    {
      return dense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 15, vertical: 7);
    }

    return dense
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: Color.alphaBlend(AppTheme.trialViolet.withValues(alpha: 0.1), Colors.white),
        borderRadius: BorderRadius.circular(large ? (dense ? 12 : 16) : (dense ? 8 : 9)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: large ? (dense ? 13 : 15) : (dense ? 10 : 11),
          fontWeight: FontWeight.w700,
          color: AppTheme.trialViolet,
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget
{
  final PersonItem student;

  const _IdentityCard({required this.student});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(dense ? 24 : 40),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          PersonAvatar(person: student, size: dense ? _denseFaceSize : _faceSize),
          SizedBox(width: dense ? 16 : 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${student.firstName} ${student.lastName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: dense ? _denseNameSize : 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialOcean,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: dense ? 6 : 12),
                StudentFacts(student: student),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Birth date and age, label over value: in the pupil's card, or beside the name in the page's heading.
class StudentFacts extends StatelessWidget
{
  final PersonItem student;

  const StudentFacts({super.key, required this.student});

  Widget _fact(String label, String value, bool dense)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: dense ? _labelStyle(_denseLabelSize) : _labelStyle()),
        SizedBox(height: dense ? 1 : 2),
        Text(value, style: dense ? _valueStyle(_denseValueSize) : _valueStyle()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final DateTime? birthDate = student.birthDate;
    final int? age = student.age;

    return Wrap(
      spacing: dense ? 28 : 34,
      runSpacing: dense ? 8 : 12,
      children: [
        _fact(kBirthDateLabel, birthDate == null ? missingValue : DateFormat('dd/MM/yyyy').format(birthDate), dense),
        _fact(kAgeLabel, age == null ? missingValue : ageValue(age), dense),
      ],
    );
  }
}

class _SchoolCard extends StatefulWidget
{
  final PersonItem student;

  const _SchoolCard({required this.student});

  @override
  State<_SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<_SchoolCard>
{
  @override
  void initState()
  {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_remeasure);
  }

  @override
  void dispose()
  {
    PaintingBinding.instance.systemFonts.removeListener(_remeasure);
    super.dispose();
  }

  // Widths measured before a font face loads come out too narrow.
  void _remeasure() => setState(() {});

  Widget _eyebrow(String text, bool dense)
  {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: dense ? 8 : 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    final List<SchoolEnrollmentItem> years = [...?widget.student.schoolEnrollments]
      ..sort((a, b) => b.startYear.compareTo(a.startYear));

    final int now = currentSchoolYearStart();
    final SchoolEnrollmentItem? current = years.where((item) => item.startYear == now).firstOrNull;
    final List<SchoolEnrollmentItem> past = years.where((item) => item.startYear < now).toList();

    final _NarrowWidths widths = _NarrowWidths.of(context, years, dense: dense);

    final double paddingH = dense ? _denseYearPaddingH : _yearPaddingH;
    final double paddingV = dense ? _denseYearPaddingV : _yearPaddingV;
    final double radius = dense ? _denseYearRadius : _yearRadius;

    Widget list(_YearLayout layout) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          _eyebrow(kCurrentSchoolYear, dense),
          TodayFrame(
            radius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: paddingH - TodayFrame.rim,
                vertical: paddingV - TodayFrame.rim,
              ),
              child: _YearRow(item: current, all: years, widths: widths, dense: dense, layout: layout),
            ),
          ),
        ],
        if (current != null && past.isNotEmpty) SizedBox(height: dense ? 16 : 22),
        if (past.isNotEmpty) ...[
          _eyebrow(kPastSchoolYears, dense),
          for (var i = 0; i < past.length; i++) ...[
            if (i > 0) SizedBox(height: dense ? 8 : 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: paddingH - 1, vertical: paddingV - 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppTheme.trialLine),
              ),
              child: _YearRow(item: past[i], all: years, widths: widths, dense: dense, layout: layout),
            ),
          ],
        ],
      ],
    );

    return AppCard(
      title: kSchoolTitle,
      compact: !dense,
      leading: AppCardBadge(icon: Icons.school_rounded, compact: !dense),
      child: current == null && past.isEmpty
          ? Center(
              child: Text(
                kNoSchoolYears,
                textAlign: TextAlign.center,
                style: _labelStyle(dense ? _denseValueSize : 16),
              ),
            )
          : dense
              ? LayoutBuilder(
                  builder: (context, constraints) => list(widths.layoutFor(constraints.maxWidth - 2 * paddingH)),
                )
              : list(_YearLayout.line),
    );
  }
}

// One line; or year, class and repeating over school and programme, side by side or one over the other.
enum _YearLayout { line, twoLines, stacked }

class _NarrowWidths
{
  final double year;
  final double grade;
  final double repeating;

  // The widest school and programme with their labels: for the dense layout only.
  final double school;
  final double programme;

  const _NarrowWidths({
    required this.year,
    required this.grade,
    required this.repeating,
    required this.school,
    required this.programme,
  });

  factory _NarrowWidths.of(BuildContext context, List<SchoolEnrollmentItem> years, {required bool dense})
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // TextPainter misses DefaultTextStyle; merged in so letter spacing counts.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    final TextStyle label = _labelStyle(dense ? _denseLabelSize : 13);
    final TextStyle value = _valueStyle(dense ? _denseValueSize : 16);

    double widest(String title, Iterable<String> values)
    {
      double measure(String text, TextStyle style)
      {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: text, style: inherited.merge(style)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();

        final double width = painter.width;
        painter.dispose();

        return width;
      }

      double result = measure(title, label);

      for (final text in values)
      {
        final double width = measure(text, value);

        if (width > result)
        {
          result = width;
        }
      }

      return result.ceilToDouble() + 1;
    }

    return _NarrowWidths(
      year: widest(kSchoolYearLabel, [for (final item in years) _yearLabel(item)]),
      grade: widest(kClassLabel, [for (final item in years) gradeLabel(item.grade)]),
      repeating: widest(kRepeatingLabel, const ['Sì', 'No']),
      school: dense ? widest(kSchoolLabel, [for (final item in years) item.schoolName]) : 0,
      programme: dense ? widest(kProgrammeLabel, [for (final item in years) item.studyProgramNameOnly]) : 0,
    );
  }

  // [room]: the inside of a year's box.
  _YearLayout layoutFor(double room)
  {
    if (year + school + programme + grade + repeating + 4 * _denseColumnGap <= room)
    {
      return _YearLayout.line;
    }

    return school + _denseColumnGap + programme <= room ? _YearLayout.twoLines : _YearLayout.stacked;
  }
}

String _yearLabel(SchoolEnrollmentItem item) => '${item.startYear}/${item.startYear + 1}';

class _YearRow extends StatelessWidget
{
  final SchoolEnrollmentItem item;
  final List<SchoolEnrollmentItem> all;
  final _NarrowWidths widths;
  final bool dense;
  final _YearLayout layout;

  const _YearRow({
    required this.item,
    required this.all,
    required this.widths,
    required this.dense,
    required this.layout,
  });

  Widget _cell(String label, String value)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(dense ? _denseLabelSize : 13)),
        SizedBox(height: dense ? 2 : 3),
        Text(value, style: _valueStyle(dense ? _denseValueSize : 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget gap = SizedBox(width: dense ? _denseColumnGap : _columnGap);
    final Widget year = SizedBox(width: widths.year, child: _cell(kSchoolYearLabel, _yearLabel(item)));
    final Widget school = _cell(kSchoolLabel, item.schoolName);
    final Widget programme = _cell(kProgrammeLabel, item.studyProgramNameOnly);
    final Widget grade = SizedBox(width: widths.grade, child: _cell(kClassLabel, gradeLabel(item.grade)));
    final Widget repeating = SizedBox(
      width: widths.repeating,
      child: _cell(kRepeatingLabel, isRepeatingYear(item, all) ? 'Sì' : 'No'),
    );

    if (layout == _YearLayout.line)
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          year,
          gap,
          Expanded(child: school),
          gap,
          Expanded(child: programme),
          gap,
          grade,
          gap,
          repeating,
        ],
      );
    }

    const Widget lineGap = SizedBox(height: _denseLineGap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // At the narrowest windows class and repeating go under the year.
        Wrap(spacing: _denseColumnGap, runSpacing: _denseLineGap, children: [year, grade, repeating]),
        lineGap,
        if (layout == _YearLayout.twoLines)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [school, gap, programme])
        else ...[
          school,
          lineGap,
          programme,
        ],
      ],
    );
  }
}
