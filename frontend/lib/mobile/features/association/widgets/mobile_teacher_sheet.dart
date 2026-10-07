import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/association/teacher_opinions.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../features/people/models/teacher_subject_item.dart';
import '../../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../../shared/widgets/app_check_mark.dart' show kPickedSurface;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import '../mobile_teachers_directory.dart';

const String _empty = '—';

const double _faceSize = 58;

const double _cardGap = 12;
const double _areaGap = 14;
const double _tagGap = 7;

const double _chipHeight = 40;
const double _checkSize = 22;

Future<void> showMobileTeacherSheet({
  required BuildContext context,
  required MobileTeachersDirectory directory,
  required PersonItem teacher,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (_) => _TeacherSheet(directory: directory, teacher: teacher),
  );
}

class _TeacherSheet extends StatefulWidget
{
  final MobileTeachersDirectory directory;
  final PersonItem teacher;

  const _TeacherSheet({required this.directory, required this.teacher});

  @override
  State<_TeacherSheet> createState() => _TeacherSheetState();
}

class _TeacherSheetState extends State<_TeacherSheet>
{
  bool _saving = false;

  PersonItem get _teacher => widget.teacher;

  // Saved at once, as on the desktop; taps while one is saving are dropped.
  Future<void> _toggle(OpinionPupil pupil) async
  {
    if (_saving)
    {
      return;
    }

    setState(() => _saving = true);

    try
    {
      await widget.directory.setOpinion(pupil, _teacher, !pupil.dislikes(_teacher));
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _saving = false);
      }
    }
  }

  DetailRowData _row(String label, String? value)
  {
    final String? text = value?.trim();

    if (text == null || text.isEmpty)
    {
      return DetailRowData.drawn(
        label,
        Text(_empty, style: mobileFactValueStyle().copyWith(color: MobilePalette.mutedText)),
      );
    }

    return DetailRowData(label, text);
  }

  Widget _buildProfile()
  {
    final int? age = _teacher.age;

    return MobileSheetCard(
      child: MobileDetailRows(
        rows: [
          _row('Età', age == null ? null : '$age anni'),
          _row('Studi scolastici', _teacher.schoolEducation),
          _row('Studi universitari', _teacher.universityEducation),
        ],
      ),
    );
  }

  Widget _buildSubjects()
  {
    final List<TeacherSubjectItem> subjects = subjectsOf(_teacher);

    return MobileSheetCard(
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              taughtSubjectsLabel(subjects.length),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontStyle: subjects.isEmpty ? FontStyle.italic : FontStyle.normal,
                color: subjects.isEmpty ? MobilePalette.mutedText : AppTheme.trialTealDeep,
              ),
            ),
            for (final group in groupByArea(subjects, (subject) => subject.subjectArea)) ...[
              const SizedBox(height: _areaGap),
              MobileSelectGroupHead(
                title: group.title,
                trailing: [
                  Text(
                    '${group.items.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: _tagGap,
                runSpacing: _tagGap,
                children: [
                  for (final name in [for (final subject in group.items) subject.subjectName]..sort())
                    _Tag(name),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpinion(List<OpinionPupil> pupils)
  {
    final List<Widget> choice;

    if (pupils.length == 1)
    {
      final OpinionPupil pupil = pupils.single;

      choice = [
        _OpinionRow(
          label: opinionSentence(pupil, _teacher, forSelf: widget.directory.speaksForSelf),
          selected: pupil.dislikes(_teacher),
          onTap: () => _toggle(pupil),
        ),
      ];
    }
    else
    {
      choice = [
        Text(
          opinionQuestion(_teacher),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pupil in pupils)
              _ThumbChip(
                label: pupil.firstName,
                selected: pupil.dislikes(_teacher),
                onTap: () => _toggle(pupil),
              ),
          ],
        ),
      ];
    }

    return MobileSheetCard(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...choice,
            const SizedBox(height: 12),
            Text(
              kTeachersOpinionNote,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: MobilePalette.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: widget.directory,
      builder: (context, _)
      {
        final List<OpinionPupil> pupils = widget.directory.pupils;

        return MobileSheet(
          eyebrow: 'Docente',
          title: '${_teacher.firstName} ${_teacher.lastName}',
          leading: MobileAvatar(
            firstName: _teacher.firstName,
            lastName: _teacher.lastName,
            imageUrl: _teacher.profileImageUrl,
            size: _faceSize,
          ),
          body: [
            const SizedBox(height: 18),
            _buildProfile(),
            const SizedBox(height: _cardGap),
            _buildSubjects(),
            if (pupils.isNotEmpty) ...[
              const SizedBox(height: _cardGap),
              _buildOpinion(pupils),
            ],
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _Tag extends StatelessWidget
{
  final String name;

  const _Tag(this.name);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: kPickedSurface, borderRadius: BorderRadius.circular(20)),
      child: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}

// Opaque, so the fade between the two fills passes through no grey.
final Color _restSurface = Color.alphaBlend(AppTheme.trialOcean.withValues(alpha: 0.05), Colors.white);

BoxDecoration _opinionDecoration({required bool selected, required BorderRadius radius})
{
  return BoxDecoration(
    color: selected ? AppTheme.closedOverrideSurface : _restSurface,
    borderRadius: radius,
    border: Border.all(
      color: selected
          ? AppTheme.trialDanger.withValues(alpha: 0.55)
          : AppTheme.trialOcean.withValues(alpha: 0.14),
      width: selected ? 1.5 : 1,
    ),
  );
}

class _ThumbChip extends StatelessWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThumbChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: _chipHeight,
          padding: const EdgeInsets.fromLTRB(12, 0, 15, 0),
          decoration: _opinionDecoration(selected: selected, radius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                size: 17,
                color: selected ? AppTheme.trialDanger : MobilePalette.mutedText,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.trialDanger : AppTheme.trialInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpinionRow extends StatelessWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OpinionRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: _opinionDecoration(selected: selected, radius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(
                selected ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                size: 20,
                color: selected ? AppTheme.trialDanger : MobilePalette.mutedText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: selected ? AppTheme.trialDanger : AppTheme.trialInk,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _RedCheck(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

// AppCheckMark's shape in the opinion's red.
class _RedCheck extends StatelessWidget
{
  final bool selected;

  const _RedCheck({required this.selected});

  @override
  Widget build(BuildContext context)
  {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: _checkSize,
      height: _checkSize,
      decoration: BoxDecoration(
        color: selected ? AppTheme.trialDanger : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: selected ? AppTheme.trialDanger : AppTheme.trialOcean.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }
}
