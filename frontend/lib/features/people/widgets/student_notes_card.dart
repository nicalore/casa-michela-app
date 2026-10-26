import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_density.dart';
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
  static const double _denseDotGap = 6;

  static TextStyle _authorStyle(bool dense) => GoogleFonts.plusJakartaSans(
    fontSize: dense ? 12.5 : 14,
    fontWeight: FontWeight.w600,
    color: AppTheme.trialMutedText,
  );

  static final TextStyle _bodyStyle = noticeTextStyle(fontSize: 16.5, height: 1.6);

  // Below the wide window (AppPageDensity).
  static final TextStyle _denseBodyStyle = noticeTextStyle(fontSize: 14.5, height: 1.5);

  Widget _buildSubject(String subject, bool dense)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 3),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        subject,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 11.5 : 12.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }

  Widget _buildNote(StudentNoteItem note, {required bool toured, required bool dense})
  {
    final bool changeable = mayChange(note);
    final String? subject = note.subject;
    final double dotGap = dense ? _denseDotGap : _dotGap;

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
                  fontSize: dense ? 13.5 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialOcean,
                ),
              ),
            ),
            SizedBox(width: dotGap),
            Text('·', style: _authorStyle(dense)),
            SizedBox(width: dotGap),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(note.authorName, overflow: TextOverflow.ellipsis, style: _authorStyle(dense)),
                  ),
                  if (subject != null) ...[
                    SizedBox(width: dense ? 8 : 10),
                    _buildSubject(subject, dense),
                  ],
                ],
              ),
            ),
            // Same height either way: a note without tools keeps the line where it was.
            SizedBox(
              height: dense ? 32 : 40,
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
                              iconSize: dense ? 18 : 24,
                              padding: dense ? 7 : 6,
                              onTap: () => edit(note),
                            ),
                            SizedBox(width: dense ? 2 : 4),
                          ],
                          FadeHoverIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppTheme.trialDanger,
                            hoverColor: AppTheme.trialGoldSurface,
                            iconSize: dense ? 18 : 24,
                            padding: dense ? 7 : 6,
                            onTap: () => onDelete?.call(note),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
        SizedBox(height: dense ? 2 : 6),
        StudentNoteText(taxCode: taxCode, kind: kind, note: note, style: dense ? _denseBodyStyle : _bodyStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? add = onAdd;
    final bool dense = AppPageDensity.of(context);

    // Newest first: the tour lights the latest the reader wrote.
    final int firstChangeable = notes.indexWhere(mayChange);

    return AppCard(
      title: title,
      compact: !dense,
      leading: AppCardBadge(icon: icon, compact: !dense),
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
                fontSize: dense ? 15 : 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.trialInk,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < notes.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: dense ? 12 : 18),
                      child: const Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                    ),
                  _buildNote(notes[i], toured: i == firstChangeable, dense: dense),
                ],
              ],
            ),
    );
  }
}
