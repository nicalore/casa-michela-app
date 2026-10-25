import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../association/notices/notice_message_view.dart' show noticeTextStyle;
import '../models/student_note_item.dart';
import '../utils/student_notes_strings.dart';
import 'person_detail_widgets.dart' show missingValue;
import 'student_note_text.dart';

// "2 ottobre 2026".
String noteDate(DateTime date) => '${formatDayMonthFull(date)} ${date.year}';

class StudentNotesCard extends StatelessWidget
{
  final String title;
  final IconData icon;

  // The pupil and the kind: where the notes' images are fetched from.
  final String taxCode;
  final StudentNoteKind kind;

  final List<StudentNoteItem> notes;

  // Null for a reader who only reads.
  final VoidCallback? onAdd;

  // In the head when there is no AGGIUNGI.
  final Widget? trailing;

  final bool Function(StudentNoteItem note) mayChange;
  final ValueChanged<StudentNoteItem>? onEdit;
  final ValueChanged<StudentNoteItem>? onDelete;

  // Desktop tour ids for the date and the tools of the newest note the reader may change.
  final String? tourDate;
  final String? tourTools;

  const StudentNotesCard({
    super.key,
    required this.title,
    required this.icon,
    required this.taxCode,
    required this.kind,
    required this.notes,
    this.onAdd,
    this.trailing,
    this.mayChange = _never,
    this.onEdit,
    this.onDelete,
    this.tourDate,
    this.tourTools,
  });

  static bool _never(StudentNoteItem note) => false;

  static const double _dotGap = 8;

  static TextStyle get _authorStyle => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.trialMutedText,
  );

  static final TextStyle _bodyStyle = noticeTextStyle(fontSize: 16.5, height: 1.6);

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

  Widget _buildNote(StudentNoteItem note, {required bool toured})
  {
    final bool changeable = mayChange(note);
    final String? subject = note.subject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DesktopTourTarget(
              id: toured ? tourDate : null,
              child: Text(
                // A teacher's note goes by the day of its lesson.
                noteDate(note.lessonDate ?? note.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialOcean,
                ),
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
                  ? DesktopTourTarget(
                      id: toured ? tourTools : null,
                      child: Row(
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
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        StudentNoteText(taxCode: taxCode, kind: kind, note: note, style: _bodyStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? add = onAdd;

    // Newest first: the tour lights the latest the reader wrote.
    final int firstChangeable = notes.indexWhere(mayChange);

    return AppCard(
      title: title,
      compact: true,
      leading: AppCardBadge(icon: icon, compact: true),
      trailing: add == null
          ? trailing
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
                  _buildNote(notes[i], toured: i == firstChangeable),
                ],
              ],
            ),
    );
  }
}
