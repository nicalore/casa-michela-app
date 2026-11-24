import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
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

// Keeps 'INVIA SEGNALAZIONE' on one line.
const double _footerWidth = 576;

// Everything else on the edit wizard is a field the administrator simply changes.
List<String> get kAnagraphicReportableFields => [
  tr('Nome', 'First name'),
  tr('Cognome', 'Surname'),
  tr('Sesso', 'Sex'),
  tr('Codice fiscale', 'Tax code'),
  tr('Data di nascita', 'Date of birth'),
  tr('Città di nascita', 'City of birth'),
  tr('Provincia', 'Province'),
  tr('Nazione di nascita', 'Country of birth'),
];

List<String> get kSchoolReportableFields => [
  tr('Scuola', 'School'),
  tr('Classe', 'Class'),
  tr('Percorso di studi', 'Study programme'),
];

// A single field has nothing to choose: its box is open from the start.
Future<void> showAnagraphicErrorReportDialog(
  BuildContext context,
  PersonItem person, {
  List<String>? fields,
  String? eyebrow,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'AnagraphicErrorReport',
    builder: (dialogContext) => AnagraphicErrorReportDialog(
      person: person,
      fields: fields ?? kAnagraphicReportableFields,
      eyebrow: eyebrow ?? tr('Anagrafica', 'Personal details'),
    ),
  );
}

class AnagraphicErrorReportDialog extends StatefulWidget
{
  final PersonItem person;

  final List<String> fields;
  final String eyebrow;

  const AnagraphicErrorReportDialog({
    super.key,
    required this.person,
    required this.fields,
    required this.eyebrow,
  });

  @override
  State<AnagraphicErrorReportDialog> createState() => _AnagraphicErrorReportDialogState();
}

class _AnagraphicErrorReportDialogState extends State<AnagraphicErrorReportDialog>
{
  final Set<String> _selectedFields = {};
  final Map<String, TextEditingController> _controllers = {};

  bool _isSaving = false;

  bool get _single => widget.fields.length == 1;

  @override
  void initState()
  {
    super.initState();

    if (_single)
    {
      _selectedFields.add(widget.fields.single);
      _controllers[widget.fields.single] = TextEditingController();
    }
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
        message: tr('Seleziona almeno un campo da modificare.', 'Select at least one field to change.'),
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
        message: tr('Compila i dettagli per tutti i campi selezionati.', 'Fill in the details for every selected field.'),
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
        message: tr('Segnalazione inviata con successo!', 'Report sent successfully!'),
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
        widget.fields.where(_selectedFields.contains).toList();

    return AppDialogStack(
      eyebrow: widget.eyebrow,
      title: tr('Segnala errore', 'Report an error'),
      maxWidth: 620,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('INVIA SEGNALAZIONE', 'SEND REPORT'),
          icon: Icons.send_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _send,
        ),
        maxWidth: _footerWidth,
      ),
      children: [
        if (!_single)
          AppDialogPill(
            expand: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Quali dati sono sbagliati?', 'Which details are wrong?'),
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
                    for (final field in widget.fields)
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
                    hintText: tr('Valore corretto', 'Correct value'),
                    maxLength: FieldLimits.reportValue,
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
