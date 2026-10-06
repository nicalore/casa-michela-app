import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
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

const double _cardGap = 24;
const double _faceSize = 96;

const double _yearRadius = 16;
const double _columnGap = 28;
const double _yearPaddingH = 20;
const double _yearPaddingV = 14;

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

  const StudentSheet({
    super.key,
    required this.student,
    required this.ownTaxCode,
    required this.onEditCertifications,
    required this.onAddNote,
    required this.onEditNote,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context)
  {
    return PageTransitionScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: pageTransitionBlocks([
            _IdentityCard(student: student),
            const SizedBox(height: _cardGap),
            _buildCertifications(),
            const SizedBox(height: _cardGap),
            _SchoolCard(student: student),
            const SizedBox(height: _cardGap),
            if (_otherInformation.isNotEmpty) ...[
              _buildOtherInformation(),
              const SizedBox(height: _cardGap),
            ],
            StudentNotesCard(
              title: kMethodologicalNotesTitle,
              icon: Icons.psychology_rounded,
              notes: student.methodologicalNotes ?? const [],
              onAdd: onAddNote,
              mayChange: (note) => note.authorTaxCode == ownTaxCode,
              onEdit: onEditNote,
              onDelete: onDeleteNote,
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

  Widget _fact(String label, String value)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle()),
        const SizedBox(height: 4),
        Text(value, style: _valueStyle()),
      ],
    );
  }

  Widget _buildCertifications()
  {
    final List<String> codes = [
      for (final code in kCertificationLabels.keys)
        if (student.certificationTypes.contains(code)) code,
    ];

    final String? dsa = student.certificationDsaDetail?.trim();
    final String? other = student.certificationOtherDetail?.trim();

    final List<Widget> details = [
      if (codes.contains(_dsaCode)) _fact(kDsaDetailLabel, dsa == null || dsa.isEmpty ? missingValue : dsa),
      if (codes.contains(_otherCode))
        _fact(kOtherDetailLabel, other == null || other.isEmpty ? missingValue : other),
    ];

    return AppCard(
      title: kCertificationsTitle,
      compact: true,
      leading: const AppCardBadge(icon: Icons.assignment_outlined, compact: true),
      trailing: _cardButton(kEditLabel, Icons.edit_rounded, onEditCertifications),
      child: codes.isEmpty
          ? Text(missingValue, style: _valueStyle())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final code in codes) CertificationChip(kCertificationLabels[code]!, large: true)],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Wrap(spacing: 48, runSpacing: 16, children: details),
                ],
              ],
            ),
    );
  }

  List<String> get _otherInformation => [
    for (final value in [student.allergiesNotes, student.medicationsNotes])
      if (value != null && value.trim().isNotEmpty) value.trim(),
  ];

  Widget _buildOtherInformation()
  {
    return AppCard(
      title: kOtherInformationTitle,
      compact: true,
      leading: const AppCardBadge(icon: Icons.health_and_safety_outlined, compact: true),
      child: Text(_otherInformation.join('\n'), style: _bodyStyle),
    );
  }
}

class CertificationChip extends StatelessWidget
{
  final String label;

  final bool large;

  const CertificationChip(this.label, {super.key, this.large = false});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 15, vertical: 7)
          : const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(AppTheme.trialViolet.withValues(alpha: 0.1), Colors.white),
        borderRadius: BorderRadius.circular(large ? 16 : 9),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: large ? 15 : 11,
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

  Widget _fact(String label, String value)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle()),
        const SizedBox(height: 2),
        Text(value, style: _valueStyle()),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime? birthDate = student.birthDate;
    final int? age = student.age;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          PersonAvatar(person: student, size: _faceSize),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${student.firstName} ${student.lastName}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialOcean,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 34,
                  runSpacing: 12,
                  children: [
                    _fact(
                      kBirthDateLabel,
                      birthDate == null ? missingValue : DateFormat('dd/MM/yyyy').format(birthDate),
                    ),
                    _fact(kAgeLabel, age == null ? missingValue : ageValue(age)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _eyebrow(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
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
    final List<SchoolEnrollmentItem> years = [...?widget.student.schoolEnrollments]
      ..sort((a, b) => b.startYear.compareTo(a.startYear));

    final int now = currentSchoolYearStart();
    final SchoolEnrollmentItem? current = years.where((item) => item.startYear == now).firstOrNull;
    final List<SchoolEnrollmentItem> past = years.where((item) => item.startYear < now).toList();

    final _NarrowWidths widths = _NarrowWidths.of(context, years);

    return AppCard(
      title: kSchoolTitle,
      compact: true,
      leading: const AppCardBadge(icon: Icons.school_rounded, compact: true),
      child: current == null && past.isEmpty
          ? Text(kNoSchoolYears, style: _labelStyle(16))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current != null) ...[
                  _eyebrow(kCurrentSchoolYear),
                  TodayFrame(
                    radius: _yearRadius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _yearPaddingH - TodayFrame.rim,
                        vertical: _yearPaddingV - TodayFrame.rim,
                      ),
                      child: _YearRow(item: current, all: years, widths: widths),
                    ),
                  ),
                ],
                if (current != null && past.isNotEmpty) const SizedBox(height: 22),
                if (past.isNotEmpty) ...[
                  _eyebrow(kPastSchoolYears),
                  for (var i = 0; i < past.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _yearPaddingH - 1,
                        vertical: _yearPaddingV - 1,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_yearRadius),
                        border: Border.all(color: AppTheme.trialLine),
                      ),
                      child: _YearRow(item: past[i], all: years, widths: widths),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _NarrowWidths
{
  final double year;
  final double grade;
  final double repeating;

  const _NarrowWidths({required this.year, required this.grade, required this.repeating});

  factory _NarrowWidths.of(BuildContext context, List<SchoolEnrollmentItem> years)
  {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // TextPainter misses DefaultTextStyle; merged in so letter spacing counts.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    double widest(String label, Iterable<String> values)
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

      double result = measure(label, _labelStyle(13));

      for (final value in values)
      {
        final double width = measure(value, _valueStyle(16));

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
    );
  }
}

String _yearLabel(SchoolEnrollmentItem item) => '${item.startYear}/${item.startYear + 1}';

class _YearRow extends StatelessWidget
{
  final SchoolEnrollmentItem item;
  final List<SchoolEnrollmentItem> all;
  final _NarrowWidths widths;

  const _YearRow({required this.item, required this.all, required this.widths});

  Widget _cell(String label, String value)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle(13)),
        const SizedBox(height: 3),
        Text(value, style: _valueStyle(16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: widths.year, child: _cell(kSchoolYearLabel, _yearLabel(item))),
        const SizedBox(width: _columnGap),
        Expanded(child: _cell(kSchoolLabel, item.schoolName)),
        const SizedBox(width: _columnGap),
        Expanded(child: _cell(kProgrammeLabel, item.studyProgramNameOnly)),
        const SizedBox(width: _columnGap),
        SizedBox(width: widths.grade, child: _cell(kClassLabel, gradeLabel(item.grade))),
        const SizedBox(width: _columnGap),
        SizedBox(
          width: widths.repeating,
          child: _cell(kRepeatingLabel, isRepeatingYear(item, all) ? 'Sì' : 'No'),
        ),
      ],
    );
  }
}
