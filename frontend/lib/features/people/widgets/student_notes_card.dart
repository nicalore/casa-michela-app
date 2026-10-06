import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/shared_components.dart';
import '../models/student_note_item.dart';
import '../utils/student_notes_strings.dart';
import 'person_detail_widgets.dart' show missingValue;

// "2 ottobre 2026".
String noteDate(DateTime date) => '${formatDayMonthFull(date)} ${date.year}';

class StudentNotesCard extends StatelessWidget
{
  final String title;
  final IconData icon;

  final List<StudentNoteItem> notes;

  // Null for a reader who only reads.
  final VoidCallback? onAdd;

  final bool Function(StudentNoteItem note) mayChange;
  final ValueChanged<StudentNoteItem>? onEdit;
  final ValueChanged<StudentNoteItem>? onDelete;

  const StudentNotesCard({
    super.key,
    required this.title,
    required this.icon,
    required this.notes,
    this.onAdd,
    this.mayChange = _never,
    this.onEdit,
    this.onDelete,
  });

  static bool _never(StudentNoteItem note) => false;

  static const double _dotGap = 8;

  static TextStyle get _authorStyle => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.trialMutedText,
  );

  static TextStyle get _bodyStyle => GoogleFonts.plusJakartaSans(
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    height: 1.6,
    color: AppTheme.trialInk,
  );

  Widget _buildSubject(String subject)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        subject,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }

  Widget _buildNote(StudentNoteItem note)
  {
    final bool changeable = mayChange(note);
    final String? subject = note.subject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              // A teacher's note goes by the day of its lesson.
              noteDate(note.lessonDate ?? note.createdAt),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialOcean,
              ),
            ),
            const SizedBox(width: _dotGap),
            Text('·', style: _authorStyle),
            const SizedBox(width: _dotGap),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(note.authorName, overflow: TextOverflow.ellipsis, style: _authorStyle),
                  ),
                  if (subject != null) ...[
                    const SizedBox(width: 10),
                    _buildSubject(subject),
                  ],
                ],
              ),
            ),
            // Same height either way: a note without tools keeps the line where it was.
            SizedBox(
              height: 40,
              child: changeable
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onEdit case final ValueChanged<StudentNoteItem> edit) ...[
                          FadeHoverIconButton(
                            icon: Icons.edit_outlined,
                            color: AppTheme.trialTealDeep,
                            hoverColor: AppTheme.trialGoldSurface,
                            onTap: () => edit(note),
                          ),
                          const SizedBox(width: 4),
                        ],
                        FadeHoverIconButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppTheme.trialDanger,
                          hoverColor: AppTheme.trialGoldSurface,
                          onTap: () => onDelete?.call(note),
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(note.text, style: _bodyStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? add = onAdd;

    return AppCard(
      title: title,
      compact: true,
      leading: AppCardBadge(icon: icon, compact: true),
      trailing: add == null
          ? null
          : AppGradientButton(
              label: kAddLabel,
              icon: Icons.add_rounded,
              height: 40,
              radius: 20,
              fontSize: 13,
              onPressed: add,
            ),
      child: notes.isEmpty
          ? Text(
              missingValue,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialInk,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < notes.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                    ),
                  _buildNote(notes[i]),
                ],
              ],
            ),
    );
  }
}
