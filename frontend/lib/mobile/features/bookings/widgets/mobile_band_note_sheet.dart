import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/language/app_language.dart';
import '../../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../mobile_bookings_tour.dart';

const EdgeInsets _tourFieldInflate = EdgeInsets.all(5);
const double _tourFieldRadius = 20;

// A band's note on its own, turned from the band's sheet; saved, every sheet closes.
// [onSave] gets the trimmed text, null when emptied, and answers true once written.
// [tourFor]: the reader the field's tour is told to, none without it.
Future<void> showMobileBandNoteSheet({
  required BuildContext context,
  required String eyebrow,
  required String subtitle,
  IconData? subtitleIcon,
  required String? note,
  required Future<bool> Function(String? notes) onSave,
  String? tourFor,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _BandNoteSheet(
      eyebrow: eyebrow,
      subtitle: subtitle,
      subtitleIcon: subtitleIcon,
      note: note,
      onSave: onSave,
      tourFor: tourFor,
    ),
  );
}

class _BandNoteSheet extends StatefulWidget
{
  final String eyebrow;
  final String subtitle;
  final IconData? subtitleIcon;
  final String? note;
  final Future<bool> Function(String? notes) onSave;
  final String? tourFor;

  const _BandNoteSheet({
    required this.eyebrow,
    required this.subtitle,
    this.subtitleIcon,
    required this.note,
    required this.onSave,
    this.tourFor,
  });

  @override
  State<_BandNoteSheet> createState() => _BandNoteSheetState();
}

class _BandNoteSheetState extends State<_BandNoteSheet>
{
  late final TextEditingController _text = TextEditingController(text: widget.note);

  bool _busy = false;

  @override
  void dispose()
  {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    if (_busy)
    {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final String said = _text.text.trim();

    setState(() => _busy = true);

    final bool written = await widget.onSave(said.isEmpty ? null : said);

    if (!mounted)
    {
      return;
    }

    if (written)
    {
      closeMobileSheet(context);

      return;
    }

    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context)
  {
    final String? taxCode = widget.tourFor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: widget.eyebrow,
        title: kBandNotesLabel,
        subtitle: widget.subtitle,
        subtitleIcon: widget.subtitleIcon,
        aboveKeyboard: true,
        unsaved: () => _text.text.trim() == (widget.note ?? '') ? MobileUnsaved.none : MobileUnsaved.text,
        saving: _busy,
        body: [
          MobileTourOnRise(
            onRisen: taxCode == null ? null : () => startBandNoteSheetTour(taxCode: taxCode),
            child: const SizedBox(height: 18),
          ),
          MobileSheetText(kBandNotesHint),
          const SizedBox(height: 18),
          MobileTourTarget(
            id: kBookingsTourBandNote,
            inflate: _tourFieldInflate,
            radius: _tourFieldRadius,
            child: MobileTextField(
              controller: _text,
              label: kBandNotesLabel,
              hintText: kBandNotesExample,
              maxLength: FieldLimits.notes,
              minLines: 3,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileBackRow(
            child: MobileGoldButton(
              label: tr('Salva', 'Save'),
              icon: Icons.check_rounded,
              busy: _busy,
              onPressed: _save,
            ),
          ),
        ),
      ),
    );
  }
}
