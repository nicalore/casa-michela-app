import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../models/parent_item.dart';
import '../models/person_item.dart';
import '../utils/cessation_form.dart';
import '../utils/payments_strings.dart';
import 'person_detail_widgets.dart';

const int _adultAge = 18;

const double _dialogWidth = 640;

// Half of it is the button: wide enough for its label on one line.
const double _footerWidth = 720;

const double _blockGap = 22;
const double _fieldGap = 18;

enum _Cause { resignation, expulsion }

// The server's codes, in the cessation form's order.
enum _Ground { breach, conduct, harm, other }

Color get _warningSurface => ThemeColours.fixed(0xFFFBEDEA);

final DateFormat _wireDate = DateFormat('yyyy-MM-dd');

Map<_Cause, String> get _causeLabels => {
  _Cause.resignation: tr('Recesso (dimissioni)', 'Resignation'),
  _Cause.expulsion: tr('Esclusione per gravi motivi', 'Expulsion for serious reasons'),
};

Map<_Ground, String> get _groundLabels => {
  _Ground.breach: tr(
    'Grave inosservanza di Statuto, Regolamento o delibere',
    'Serious breach of the Statute, Rules or resolutions',
  ),
  _Ground.conduct: tr(
    "Condotte contrarie alle finalità dell'Associazione",
    "Conduct contrary to the Association's aims",
  ),
  _Ground.harm: tr(
    "Danno morale o materiale all'Associazione o ai soci",
    'Moral or material harm to the Association or its members',
  ),
  _Ground.other: tr('Altro', 'Other'),
};

String get _notAfterResolution => tr('Non dopo la delibera', 'Not after the resolution');

// The cessation form's data: saved with the revocation, then the form opens.
class RevokeMembershipDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const RevokeMembershipDialog({super.key, required this.person, required this.onUpdate});

  @override
  State<RevokeMembershipDialog> createState() => _RevokeMembershipDialogState();
}

class _RevokeMembershipDialogState extends State<RevokeMembershipDialog>
{
  final ApiService _apiService = ApiService();

  final TextEditingController _reason = TextEditingController();
  final TextEditingController _resolutionDate = TextEditingController();
  final TextEditingController _minutes = TextEditingController();
  final TextEditingController _otherGround = TextEditingController();
  final TextEditingController _chargedOn = TextEditingController();
  final TextEditingController _protocol = TextEditingController();
  final TextEditingController _card = TextEditingController();

  final Set<_Ground> _grounds = {};

  _Cause? _cause;
  String? _guardian;

  String? _causeError;
  String? _resolutionError;
  String? _groundsError;
  String? _otherGroundError;
  String? _chargedOnError;
  String? _guardianError;

  bool _isSaving = false;

  List<ParentItem> get _parents => widget.person.parents ?? const [];

  // With one parent the server prints that one; with two the admin chooses.
  bool get _asksGuardian => (widget.person.age ?? _adultAge) < _adultAge && _parents.length > 1;

  @override
  void dispose()
  {
    for (final controller in [_reason, _resolutionDate, _minutes, _otherGround, _chargedOn, _protocol, _card])
    {
      controller.dispose();
    }

    super.dispose();
  }

  DateTime? _dateOf(TextEditingController controller)
  {
    final String text = controller.text.trim();

    return isValidDateString(text) ? parseDateString(text) : null;
  }

  // Sets every error at once; true when nothing is left to fix.
  bool _validate()
  {
    _causeError = _cause == null ? kRequiredField : null;
    _resolutionError = null;
    _groundsError = null;
    _otherGroundError = null;
    _chargedOnError = null;
    _guardianError = _asksGuardian && _guardian == null ? kRequiredField : null;

    if (_cause == _Cause.expulsion)
    {
      final String resolutionText = _resolutionDate.text.trim();
      final String chargedText = _chargedOn.text.trim();
      final DateTime? resolution = _dateOf(_resolutionDate);
      final DateTime? charged = _dateOf(_chargedOn);
      final DateTime now = romeNow();
      final DateTime today = DateTime(now.year, now.month, now.day);

      if (resolutionText.isEmpty)
      {
        _resolutionError = kRequiredField;
      }
      else if (resolution == null)
      {
        _resolutionError = kInvalidDate;
      }
      else if (resolution.isAfter(today))
      {
        _resolutionError = kDayInFuture;
      }

      if (chargedText.isNotEmpty && charged == null)
      {
        _chargedOnError = kInvalidDate;
      }
      else if (charged != null && resolution != null && charged.isAfter(resolution))
      {
        _chargedOnError = _notAfterResolution;
      }

      if (_grounds.isEmpty)
      {
        _groundsError = kRequiredField;
      }

      if (_grounds.contains(_Ground.other) && _otherGround.text.trim().isEmpty)
      {
        _otherGroundError = kRequiredField;
      }
    }

    return [_causeError, _resolutionError, _groundsError, _otherGroundError, _chargedOnError, _guardianError]
        .every((error) => error == null);
  }

  Map<String, dynamic> _details()
  {
    String? text(TextEditingController controller)
    {
      final String value = controller.text.trim();

      return value.isEmpty ? null : value;
    }

    final bool expulsion = _cause == _Cause.expulsion;
    final DateTime? resolution = _dateOf(_resolutionDate);
    final DateTime? charged = _dateOf(_chargedOn);

    return {
      'revocation_type': expulsion ? 'EXPULSION' : 'RESIGNATION',
      if (!expulsion) 'reason': text(_reason),
      if (expulsion && resolution != null) 'resolution_date': _wireDate.format(resolution),
      if (expulsion) 'minutes_number': text(_minutes),
      if (expulsion) 'grounds': [for (final ground in _Ground.values) if (_grounds.contains(ground)) ground.name.toUpperCase()],
      if (expulsion && _grounds.contains(_Ground.other)) 'other_ground': text(_otherGround),
      if (expulsion && charged != null) 'charged_on': _wireDate.format(charged),
      'protocol_number': text(_protocol),
      'card_number': text(_card),
      if (_asksGuardian) 'guardian_tax_code': _guardian,
    };
  }

  Future<void> _submit() async
  {
    if (_isSaving)
    {
      return;
    }

    if (!_validate())
    {
      setState(() {});
      return;
    }

    final PdfTab? tab = openCessationFormTab(widget.person);

    setState(() => _isSaving = true);

    try
    {
      // memberUpdatedAt is the optimistic concurrency token.
      await _apiService.revokePersonMembership(
        widget.person.fiscalCode,
        _details(),
        widget.person.memberUpdatedAt,
      );
    }
    catch (e)
    {
      tab?.close();

      if (mounted)
      {
        setState(() => _isSaving = false);
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }

      return;
    }

    String message = tr('Iscrizione revocata con successo.', 'Enrolment revoked successfully.');

    try
    {
      if (await presentCessationForm(widget.person, tab, day: romeNow()))
      {
        message = '$message $kCessationFormBlocked';
      }
    }
    catch (e)
    {
      tab?.fail(kCessationFormFailed);
      message = tr(
        '$message Il modulo non è stato generato: usa MODULO DI CESSAZIONE.',
        '$message The form was not generated: use LEAVING FORM.',
      );
    }

    if (!mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: message, isError: false);
    Navigator.of(context).pop();
    widget.onUpdate();
  }

  Widget _buildWarning()
  {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warningSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppTheme.trialDangerText, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              tr(
                "L'operazione è irreversibile: l'iscrizione terminerà in data odierna "
                    'e lo stato di collaborazione verrà disattivato.'
                    "${widget.person.hasAccount ? " L'account verrà sospeso definitivamente." : ''}",
                'This cannot be undone: the enrolment will end today '
                    'and the collaboration will be turned off.'
                    "${widget.person.hasAccount ? ' The account will be suspended for good.' : ''}",
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialDangerText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCause()
  {
    final Map<_Cause, String> labels = _causeLabels;

    return PersonChipGroupField(
      label: tr('Causa della cessazione', 'Reason the membership ends'),
      options: [for (final cause in _Cause.values) labels[cause]!],
      value: _cause == null ? null : labels[_cause],
      errorText: _causeError,
      onChanged: (value) => setState(()
      {
        _cause = labels.entries.where((entry) => entry.value == value).firstOrNull?.key;
        _causeError = null;
      }),
    );
  }

  Widget _buildResignation()
  {
    return AppTextField(
      controller: _reason,
      label: tr('Motivazione (facoltativa)', 'Reason (optional)'),
      hintText: tr('Inserisci...', 'Type here...'),
      maxLength: FieldLimits.revocationReason,
    );
  }

  Widget _dateField(
    TextEditingController controller,
    String label,
    String? error,
    ValueChanged<String> onChanged,
  )
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: kDateHint,
      keyboardType: TextInputType.number,
      inputFormatters: [DateInputFormatter()],
      errorText: error,
      onChanged: onChanged,
    );
  }

  Widget _buildExpulsion()
  {
    final Map<_Ground, String> labels = _groundLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _fieldGap,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Expanded(
              child: _dateField(
                _resolutionDate,
                tr('Data della delibera', 'Date of the resolution'),
                _resolutionError,
                (_) => setState(() => _resolutionError = null),
              ),
            ),
            Expanded(
              child: AppTextField(
                controller: _minutes,
                label: tr('Verbale n. (facoltativo)', 'Minutes no. (optional)'),
                hintText: tr('Es. 12', 'E.g. 12'),
                maxLength: FieldLimits.revocationMinutes,
              ),
            ),
          ],
        ),
        PersonChipGroupField.multiple(
          label: tr('Motivi', 'Grounds'),
          options: [for (final ground in _Ground.values) labels[ground]!],
          values: {for (final ground in _grounds) labels[ground]!},
          errorText: _groundsError,
          onToggled: (value) => setState(()
          {
            final _Ground ground = labels.entries.firstWhere((entry) => entry.value == value).key;

            if (!_grounds.remove(ground))
            {
              _grounds.add(ground);
            }

            _groundsError = null;
          }),
        ),
        if (_grounds.contains(_Ground.other))
          AppTextField(
            controller: _otherGround,
            label: tr('Altro motivo', 'Other ground'),
            hintText: tr('Inserisci...', 'Type here...'),
            maxLength: FieldLimits.revocationOtherGround,
            errorText: _otherGroundError,
            onChanged: (_) => setState(() => _otherGroundError = null),
          ),
        _dateField(
          _chargedOn,
          tr('Addebiti contestati il (facoltativo)', 'Charges notified on (optional)'),
          _chargedOnError,
          (_) => setState(() => _chargedOnError = null),
        ),
      ],
    );
  }

  Widget _buildGuardian()
  {
    return PersonChipGroupField(
      label: tr('Genitore o tutore sul modulo', 'Parent or guardian on the form'),
      options: [for (final parent in _parents) parent.fiscalCode],
      shownAs: {for (final parent in _parents) parent.fiscalCode: '${parent.firstName} ${parent.lastName}'},
      value: _guardian,
      errorText: _guardianError,
      onChanged: (value) => setState(()
      {
        _guardian = value;
        _guardianError = null;
      }),
    );
  }

  Widget _buildNumbers()
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Expanded(
          child: AppTextField(
            controller: _protocol,
            label: tr('Prot. n. (facoltativo)', 'Ref. no. (optional)'),
            hintText: tr('Es. 27', 'E.g. 27'),
            maxLength: FieldLimits.revocationProtocol,
          ),
        ),
        Expanded(
          child: AppTextField(
            controller: _card,
            label: tr('N. tessera (facoltativo)', 'Card no. (optional)'),
            hintText: tr('Es. 112', 'E.g. 112'),
            maxLength: FieldLimits.revocationCard,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final _Cause? cause = _cause;

    return AppDialogStack(
      eyebrow: tr('Iscrizione', 'Enrolment'),
      title: tr('Revoca iscrizione', 'Revoke enrolment'),
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        maxWidth: _footerWidth,
        AppGradientButton(
          label: tr('GENERA MODULO E REVOCA', 'GENERATE FORM AND REVOKE'),
          icon: Icons.gavel_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildWarning(),
              const SizedBox(height: _blockGap),
              _buildCause(),
              if (cause != null) ...[
                const SizedBox(height: _blockGap),
                if (cause == _Cause.resignation) _buildResignation() else _buildExpulsion(),
              ],
              if (_asksGuardian) ...[
                const SizedBox(height: _blockGap),
                _buildGuardian(),
              ],
              const SizedBox(height: _blockGap),
              _buildNumbers(),
            ],
          ),
        ),
      ],
    );
  }
}
