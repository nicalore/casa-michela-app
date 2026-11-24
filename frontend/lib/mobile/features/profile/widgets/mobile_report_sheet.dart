import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/language/app_language.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

// The eyebrow says whose facts they are: a parent reports a child's too.
// A single field has nothing to choose: its box is open from the start.
Future<void> showMobileReportSheet({
  required BuildContext context,
  required PersonItem person,
  required List<String> fields,
  String? eyebrow,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _ReportSheet(person: person, fields: fields, eyebrow: eyebrow ?? tr('I tuoi dati', 'Your details')),
  );
}

class _ReportSheet extends StatefulWidget
{
  final PersonItem person;
  final List<String> fields;
  final String eyebrow;

  const _ReportSheet({required this.person, required this.fields, required this.eyebrow});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet>
{
  final Set<String> _chosen = {};
  final Map<String, TextEditingController> _controllers = {};

  bool _busy = false;

  bool get _single => widget.fields.length == 1;

  @override
  void initState()
  {
    super.initState();

    if (_single)
    {
      _chosen.add(widget.fields.single);
      _controllers[widget.fields.single] = TextEditingController();
    }
  }

  MobileUnsaved _unsaved()
  {
    if (!_single)
    {
      return _chosen.isEmpty ? MobileUnsaved.none : MobileUnsaved.choices;
    }

    return _controllers[widget.fields.single]!.text.trim().isEmpty ? MobileUnsaved.none : MobileUnsaved.text;
  }

  // In the order of the chips, not of the taps.
  List<String> get _chosenInOrder
  {
    return [for (final field in widget.fields) if (_chosen.contains(field)) field];
  }

  @override
  void dispose()
  {
    for (final controller in _controllers.values)
    {
      controller.dispose();
    }

    super.dispose();
  }

  void _toggle(String field)
  {
    setState(()
    {
      if (!_chosen.remove(field))
      {
        _chosen.add(field);
        _controllers.putIfAbsent(field, TextEditingController.new);
      }
    });
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _send() async
  {
    if (_chosen.isEmpty)
    {
      MobileNotice.show(context, tr('Seleziona almeno un campo da modificare.', 'Choose at least one field to change.'), error: true);

      return;
    }

    if (_chosen.any((field) => _controllers[field]!.text.trim().isEmpty))
    {
      MobileNotice.show(
        context,
        tr('Compila i dettagli per tutti i campi selezionati.', 'Fill in the details for all the selected fields.'),
        error: true,
      );

      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().sendAnagraphicErrorReport(widget.person.fiscalCode, {
        for (final field in _chosenInOrder) field: _controllers[field]!.text.trim(),
      });

      if (mounted)
      {
        MobileNotice.show(context, tr('Segnalazione inviata con successo!', 'Report sent successfully!'));
        finishMobileSheet(context);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: widget.eyebrow,
        title: tr('Segnala errore', 'Report an error'),
        aboveKeyboard: true,
        unsaved: _unsaved,
        saving: _busy,
        body: [
          if (!_single) ...[
            const SizedBox(height: 18),
            Text(
              tr('Quali dati sono sbagliati?', 'Which details are wrong?'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: kMobileChipGap,
              runSpacing: kMobileChipGap,
              children: [
                for (final field in widget.fields)
                  MobileSelectChip(
                    label: field,
                    selected: _chosen.contains(field),
                    onTap: () => _toggle(field),
                  ),
              ],
            ),
          ],
          for (final field in _chosenInOrder) ...[
            const SizedBox(height: 18),
            MobileTextField(
              key: ValueKey(field),
              controller: _controllers[field]!,
              label: field,
              hintText: tr('Valore corretto', 'Correct value'),
              maxLength: FieldLimits.reportValue,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: tr('Invia segnalazione', 'Send report'),
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
