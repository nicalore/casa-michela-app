import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';

// Reporting an error in the data that cannot be edited here.
//
// First name, last name, gender, tax code and birth data hold a person's record
// together, and changing them by hand from any dialog is how one ends up with
// two people where there was one. Here one says which are wrong and what they
// should say; correcting them is for whoever answers for them.

const List<String> _reportableFields = [
  'Nome',
  'Cognome',
  'Sesso',
  'Codice fiscale',
  'Data di nascita',
  'Città di nascita',
  'Provincia',
  'Nazione di nascita',
];

Future<void> showAnagraphicErrorReportDialog(BuildContext context, PersonItem person)
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'AnagraphicErrorReport',
    builder: (dialogContext) => AnagraphicErrorReportDialog(person: person),
  );
}

class AnagraphicErrorReportDialog extends StatefulWidget
{
  final PersonItem person;

  const AnagraphicErrorReportDialog({super.key, required this.person});

  @override
  State<AnagraphicErrorReportDialog> createState() => _AnagraphicErrorReportDialogState();
}

class _AnagraphicErrorReportDialogState extends State<AnagraphicErrorReportDialog>
{
  final Set<String> _selectedFields = {};
  final Map<String, TextEditingController> _controllers = {};

  bool _isSaving = false;

  @override
  void dispose()
  {
    for (final controller in _controllers.values)
    {
      controller.dispose();
    }

    super.dispose();
  }

  void _toggle(String field, bool selected)
  {
    setState(()
    {
      if (selected)
      {
        _selectedFields.add(field);
        _controllers.putIfAbsent(field, TextEditingController.new);
      }
      else
      {
        _selectedFields.remove(field);
      }
    });
  }

  Future<void> _send() async
  {
    if (_selectedFields.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Seleziona almeno un campo da modificare.',
        isError: true,
      );

      return;
    }

    final bool hasEmpty = _selectedFields
        .any((field) => _controllers[field]?.text.trim().isEmpty ?? true);

    if (hasEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Compila i dettagli per tutti i campi selezionati.',
        isError: true,
      );

      return;
    }

    setState(() => _isSaving = true);

    try
    {
      final Map<String, String> corrections = {
        for (final field in _selectedFields) field: _controllers[field]!.text.trim(),
      };

      await ApiService().sendAnagraphicErrorReport(widget.person.fiscalCode, corrections);

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(
        context: context,
        message: 'Segnalazione inviata con successo!',
        isError: false,
      );
      Navigator.of(context).pop();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> chosen =
        _reportableFields.where(_selectedFields.contains).toList();

    return AppDialogStack(
      eyebrow: 'Anagrafica',
      title: 'Segnala errore',
      maxWidth: 620,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'INVIA SEGNALAZIONE',
          icon: Icons.send_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _send,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quali dati sono sbagliati?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: AppTheme.trialInk,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final field in _reportableFields)
                    AppSelectableChip(
                      label: field,
                      selected: _selectedFields.contains(field),
                      onSelected: (selected) => _toggle(field, selected),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (chosen.isNotEmpty)
          AppDialogPill(
            expand: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in chosen)
                  AppTextField(
                    controller: _controllers[field]!,
                    label: field,
                    hintText: 'Valore corretto',
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
