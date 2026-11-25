import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../bookings/bookings_tour.dart';
import '../models/presence_item.dart';
import '../utils/booking_wizard_strings.dart';

const IconData kBandNoteIcon = Icons.sticky_note_2_outlined;

// Every stretch of a band carries the same note: the first one said stands for all.
String? bandNoteOf(Iterable<PresenceItem> slots)
{
  for (final slot in slots)
  {
    final String? note = slot.notes?.trim();

    if (note != null && note.isNotEmpty)
    {
      return note;
    }
  }

  return null;
}

String? bandNoteIn(
  Iterable<PresenceItem> rows, {
  required String studentTaxCode,
  required DateTime day,
  required TimeBucket band,
})
{
  return bandNoteOf(rows.where((row) =>
      row.studentTaxCode == studentTaxCode && isSameDate(row.date, day) && bucketFor(row.startTime) == band));
}

InlineSpan bandNoteTip(String note)
{
  return TextSpan(
    children: [
      TextSpan(text: '$kBandNotesLabel\n', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      TextSpan(text: note),
    ],
  );
}

// Several bands' notes under one label, a line each.
InlineSpan bandNotesTip(List<String> lines)
{
  return TextSpan(
    children: [
      TextSpan(text: '$kBandNotesLabel\n', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      TextSpan(text: lines.join('\n')),
    ],
  );
}

// The note written out under a band's line; [muted] once the band can no longer change.
class BandNoteLine extends StatelessWidget
{
  final String note;
  final double size;
  final bool muted;

  // The phone's cards keep their own text colours.
  final Color? ink;
  final Color? mutedInk;

  // Right after the text, as the delete action.
  final Widget? trailing;

  const BandNoteLine({
    super.key,
    required this.note,
    this.size = 13.5,
    this.muted = false,
    this.ink,
    this.mutedInk,
    this.trailing,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color quiet = mutedInk ?? AppTheme.trialMutedText;

    final Widget line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: size * 0.08),
          child: Icon(kBandNoteIcon, size: size + 1.5, color: muted ? quiet : AppTheme.trialOceanText),
        ),
        SizedBox(width: size * 0.5),
        Flexible(
          child: Text(
            note,
            style: GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: muted ? quiet : (ink ?? AppTheme.trialInk),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: switch (trailing)
      {
        // Beside the text, centred on it as the band's buttons on their line.
        final Widget trailing => Row(
            children: [
              Flexible(child: line),
              SizedBox(width: size * 0.4),
              trailing,
            ],
          ),
        null => Align(alignment: AlignmentDirectional.centerStart, child: line),
      },
    );
  }
}

// The note in a well of its own, with its label, inside a white card.
class BandNoteWell extends StatelessWidget
{
  final String note;

  // At the end of the label's row, as the delete action.
  final Widget? trailing;

  const BandNoteWell({super.key, required this.note, this.trailing});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.fromLTRB(12, trailing == null ? 11 : 4, trailing == null ? 12 : 4, 12),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kBandNoteIcon, size: 15, color: AppTheme.trialOceanText),
              const SizedBox(width: 6),
              Expanded(child: AppFieldLabel(kBandNotesLabel)),
              ?trailing,
            ],
          ),
          SizedBox(height: trailing == null ? 6 : 0),
          Padding(
            padding: EdgeInsets.only(right: trailing == null ? 0 : 8),
            child: Text(
              note,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
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
}

// [onConfirmed] runs once the dialog has gone; [warning] says what goes.
Future<void> showBandNoteDeletion({
  required BuildContext context,
  required String eyebrow,
  required String warning,
  required VoidCallback onConfirmed,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'ConfirmBandNoteDeletion',
    builder: (confirmContext) => AppDialogStack(
      eyebrow: eyebrow,
      title: tr('Confermi?', 'Confirm?'),
      showClose: false,
      maxWidth: 480,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: tr('ANNULLA', 'CANCEL'),
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.dismissAccent,
          height: 52,
          fontSize: 14,
          onPressed: () => Navigator.pop(confirmContext),
        ),
        primary: AppGradientButton(
          label: tr('ELIMINA', 'DELETE'),
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          height: 52,
          fontSize: 14,
          onPressed: ()
          {
            Navigator.pop(confirmContext);
            onConfirmed();
          },
        ),
      ),
      children: [
        AppDialogPill(
          child: Text(
            warning,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ],
    ),
  );
}

// [onSave] gets the trimmed text, null when emptied; true once written. [hinted]: the booker's
// sentence above the field, left out for the administrators.
Future<void> showBandNoteDialog({
  required BuildContext context,
  required String eyebrow,
  required String? note,
  required Future<bool> Function(String? notes) onSave,
  bool hinted = true,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'BandNote',
    builder: (context) => _BandNoteDialog(eyebrow: eyebrow, note: note, onSave: onSave, hinted: hinted),
  );
}

class _BandNoteDialog extends StatefulWidget
{
  final String eyebrow;
  final String? note;
  final Future<bool> Function(String? notes) onSave;
  final bool hinted;

  const _BandNoteDialog({required this.eyebrow, required this.note, required this.onSave, required this.hinted});

  @override
  State<_BandNoteDialog> createState() => _BandNoteDialogState();
}

class _BandNoteDialogState extends State<_BandNoteDialog>
{
  late final TextEditingController _text = TextEditingController(text: widget.note);

  bool _busy = false;

  @override
  void initState()
  {
    super.initState();

    // Families only: an administrator's window has no hint and no tour.
    if (widget.hinted)
    {
      _startTour();
    }
  }

  @override
  void dispose()
  {
    _text.dispose();
    super.dispose();
  }

  void _startTour()
  {
    WidgetsBinding.instance.addPostFrameCallback((_) async
    {
      if (!mounted || isDesktopTourShown)
      {
        return;
      }

      final DesktopTour? tour = await bookingsBandNoteTour();

      if (tour != null && mounted)
      {
        startBookingsTour(context, tour, still: () => mounted && !_busy);
      }
    });

    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _save() async
  {
    if (_busy)
    {
      return;
    }

    final String said = _text.text.trim();

    setState(() => _busy = true);

    final bool written = await widget.onSave(said.isEmpty ? null : said);

    if (!mounted)
    {
      return;
    }

    if (written)
    {
      Navigator.of(context).pop();

      return;
    }

    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: widget.eyebrow,
      title: kBandNotesLabel,
      maxWidth: 680,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('SALVA', 'SAVE'),
          icon: Icons.check_rounded,
          busy: _busy,
          height: 52,
          fontSize: 14,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.hinted) ...[
                Text(
                  kBandNotesHint,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppTheme.trialMutedText,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              AppTextField(
                controller: _text,
                label: kBandNotesLabel,
                showLabel: false,
                hintText: kBandNotesExample,
                maxLength: FieldLimits.notes,
                maxLines: 4,
                minLines: 3,
                tourId: widget.hinted ? kTourBookingsBandNote : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
