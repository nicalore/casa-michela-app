import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

const Duration _chipFade = Duration(milliseconds: 160);

// The eyebrow says whose facts they are: a parent reports a child's too.
Future<void> showMobileReportSheet({
  required BuildContext context,
  required PersonItem person,
  required List<String> fields,
  String eyebrow = 'I tuoi dati',
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _ReportSheet(person: person, fields: fields, eyebrow: eyebrow),
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
      MobileNotice.show(context, 'Seleziona almeno un campo da modificare.', error: true);

      return;
    }

    if (_chosen.any((field) => _controllers[field]!.text.trim().isEmpty))
    {
      MobileNotice.show(context, 'Compila i dettagli per tutti i campi selezionati.', error: true);

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
        MobileNotice.show(context, 'Segnalazione inviata con successo!');
        Navigator.of(context).pop();
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
        title: 'Segnala errore',
        aboveKeyboard: true,
        body: [
          const SizedBox(height: 18),
          Text(
            'Quali dati sono sbagliati?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final field in widget.fields)
                _FieldChip(
                  label: field,
                  chosen: _chosen.contains(field),
                  onTap: () => _toggle(field),
                ),
            ],
          ),
          for (final field in _chosenInOrder) ...[
            const SizedBox(height: 18),
            MobileTextField(
              key: ValueKey(field),
              controller: _controllers[field]!,
              label: field,
              hintText: 'Valore corretto',
              maxLength: FieldLimits.reportValue,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: 'Invia segnalazione',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}

class _FieldChip extends StatelessWidget
{
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  const _FieldChip({required this.label, required this.chosen, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final Color text = chosen ? AppTheme.modifiedAccent : AppTheme.trialInk;

    return Semantics(
      button: true,
      selected: chosen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _chipFade,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: chosen ? AppTheme.trialGoldSurface : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: chosen ? AppTheme.trialGold : AppTheme.trialOcean.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (chosen) ...[
                Icon(Icons.check_rounded, size: 17, color: text),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
