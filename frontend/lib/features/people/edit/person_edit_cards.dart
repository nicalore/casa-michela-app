import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/person_item.dart';
import '../../../shared/widgets/app_photo_uploader.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../widgets/early_exit_edit_row.dart';
import '../widgets/membership_edit_row.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/person_row_models.dart';
import '../widgets/school_enrollment_edit_row.dart' hide currentSchoolYearStart;
import '../utils/compensation_strings.dart' show kRateHint;
import '../widgets/school_year_wizard.dart';
import '../../association/models/standard_tariffs_item.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kTariffLevelLabels, tariffOffFor;
import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart'
    show changeQueuedReason, currentTariff, feePaymentBlock, kPackagePaymentBlock, tariffCost;
import 'homework_tariffs.dart';
import 'person_edit_form.dart';
import 'widgets/person_chip_group_field.dart';
import '../../../shared/widgets/app_choice_card.dart';
import '../../../shared/widgets/app_tooltip.dart';

// UI-only chip for "no certification"; the form stores it as an empty set.
const String _noCertification = 'No';

class PersonEditCardContext
{
  final PersonEditForm form;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  final ResidenceOffer? offeredResidence;

  const PersonEditCardContext({
    required this.form,
    required this.errors,
    required this.onChanged,
    this.offeredResidence,
  });

  void clearError(String key)
  {
    errors.remove(key);
    onChanged();
  }
}

const double _choiceGap = 12;

const double _tariffFieldGap = 16;

// Side by side from this width: the tariff beside the fees, or the two fees.
const double _paymentColumnsWidth = 820;
const double _paymentColumnGap = 36;
const double _paymentBlockGap = 24;
const double _feeGap = 22;
const double _feeAmountWidth = 170;

const int _packageHoursDigits = 3;

Widget cardSection(String label, Widget child)
{
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppFieldLabel(label),
      const SizedBox(height: 10),
      child,
    ],
  );
}

// Drafts: why a choice is off when a history keeps roles or the membership.
String get kKeptRoleNote => tr(
  'Non si può togliere: ci sono lezioni, ore o pagamenti registrati.',
  'Cannot be removed: there are lessons, hours or payments recorded.',
);
String get kKeptRolesNote => tr(
  'Non si può scegliere: alcuni ruoli hanno lezioni, ore o pagamenti registrati.',
  'Cannot be chosen: some roles have lessons, hours or payments recorded.',
);
String get kKeptMembershipNote => tr(
  'Non si può scegliere: ci sono pagamenti registrati nel periodo di iscrizione.',
  'Cannot be chosen: there are payments recorded in the enrolment period.',
);

// An option off keeps its own words; the reason shows on hover.
Widget _offWithReason(String? reason, Widget card)
{
  if (reason == null)
  {
    return card;
  }

  return AppTooltip(
    waitDuration: const Duration(milliseconds: 400),
    message: reason,
    child: card,
  );
}

class InvolvementCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const InvolvementCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final bool feminine = ctx.form.genderValue == 'F';

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _choiceGap,
      children: [
        AppChoiceCard(
          icon: Icons.workspaces_outline,
          title: feminine
              ? tr('Coinvolta nelle attività', 'Involved in the activities')
              : tr('Coinvolto nelle attività', 'Involved in the activities'),
          subtitle: tr(
            'Partecipa alla vita dell\'Associazione, svolge uno o più ruoli '
            'oppure è un genitore.',
            'Takes part in the life of the Association, holds one or more roles '
            'or is a parent.',
          ),
          selected: ctx.form.involvementType == 0,
          onSelected: (_)
          {
            ctx.form.chooseInvolvement(0);
            ctx.onChanged();
          },
        ),
        _offWithReason(
          ctx.form.keepsSomeRole ? kKeptRolesNote : null,
          AppChoiceCard(
            icon: Icons.card_membership_rounded,
            title: feminine ? tr('Solo socia', 'Member only') : tr('Solo socio', 'Member only'),
            subtitle: tr(
              'Paga regolarmente la quota di iscrizione per sostenere '
              'l\'Associazione, ma non ricopre alcun ruolo.',
              'Pays the membership fee regularly to support '
              'the Association, but holds no role.',
            ),
            disabled: ctx.form.keepsSomeRole,
            selected: ctx.form.involvementType == 1,
            onSelected: (_)
            {
              ctx.form.chooseInvolvement(1);
              ctx.onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class RolesCard extends StatelessWidget
{
  static const double _twoColumnsFrom = 760;

  static const Map<String, IconData> _icons = {
    'DOCENTE': Icons.school_outlined,
    'STUDENTE': Icons.menu_book_outlined,
    'AMMINISTRATORE': Icons.computer_outlined,
    'PSICOLOGO': Icons.psychology_outlined,
    'CORSISTA': Icons.self_improvement_rounded,
    'GENITORE': Icons.family_restroom_outlined,
  };

  final PersonEditCardContext ctx;

  final Set<String> only;

  const RolesCard({super.key, required this.ctx, this.only = const {}});

  List<PersonRoleOption> get _options => only.isEmpty
      ? kPersonRoleOptions
      : kPersonRoleOptions.where((role) => only.contains(role.id)).toList();

  @override
  Widget build(BuildContext context)
  {
    return CardScrollArea(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final bool twoColumns = constraints.maxWidth >= _twoColumnsFrom;

          if (!twoColumns)
          {
            return Column(
              mainAxisSize: MainAxisSize.min,
              spacing: _choiceGap,
              children: [
                for (final role in _options) _buildCard(role),
              ],
            );
          }

          final List<PersonRoleOption> options = _options;
          final List<Widget> rows = [];

          for (var i = 0; i < options.length; i += 2)
          {
            final PersonRoleOption left = options[i];
            final PersonRoleOption? right = i + 1 < options.length ? options[i + 1] : null;

            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildCard(left)),
                  const SizedBox(width: _choiceGap),
                  Expanded(
                    child: right == null ? const SizedBox.shrink() : _buildCard(right),
                  ),
                ],
              ),
            ));
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _choiceGap,
            children: rows,
          );
        },
      ),
    );
  }

  Widget _buildCard(PersonRoleOption role)
  {
    final bool kept = ctx.form.isRoleKept(role.id);
    final bool feminine = ctx.form.genderValue == 'F';

    return _offWithReason(
      kept ? kKeptRoleNote : null,
      AppChoiceCard(
        icon: _icons[role.id] ?? Icons.person_outline,
        title: role.labelFor(feminine: feminine),
        subtitle: role.descriptionFor(feminine: feminine),
        disabled: kept,
        selected: ctx.form.selectedRoles.contains(role.id),
        onSelected: (selected)
        {
          ctx.form.toggleRole(role.id, selected);
          ctx.onChanged();
        },
      ),
    );
  }
}

class AssociationCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const AssociationCard({super.key, required this.ctx});

  // No minor chosen yet reads as one boy.
  String _guardianOnly()
  {
    final PersonEditForm form = ctx.form;
    final List<PersonItem> known = [
      ...form.allPeople,
      for (final pending in form.pendingPeople) pending['person'] as PersonItem,
    ];
    final List<String?> genders = [
      for (final taxCode in form.selectedMinors.keys)
        known.where((person) => person.fiscalCode == taxCode).firstOrNull?.gender,
    ];
    final bool allGirls = genders.isNotEmpty && genders.every((gender) => gender == 'F');

    if (isEnglish)
    {
      return genders.length > 1
          ? 'The parent is recorded only as guardian of the minors.'
          : 'The parent is recorded only as guardian of the minor.';
    }

    final String guardian = form.genderValue == 'F' ? 'tutrice' : 'tutore';
    final String minors = genders.length > 1
        ? (allGirls ? 'delle minori' : 'dei minori')
        : (allGirls ? 'della minore' : 'del minore');

    return 'Il genitore viene registrato solo come $guardian $minors.';
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _choiceGap,
      children: [
        AppChoiceCard(
          icon: Icons.person_outlined,
          title: tr('Sì', 'Yes'),
          subtitle: tr(
            'Il genitore aderisce all\'Associazione e versa la quota annuale.',
            'The parent joins the Association and pays the annual fee.',
          ),
          selected: ctx.form.parentIsMember == true,
          onSelected: (_)
          {
            ctx.form.parentIsMember = true;
            ctx.onChanged();
          },
        ),
        _offWithReason(
          ctx.form.keepsMembership ? kKeptMembershipNote : null,
          AppChoiceCard(
            icon: Icons.person_off_outlined,
            title: 'No',
            subtitle: _guardianOnly(),
            disabled: ctx.form.keepsMembership,
            selected: ctx.form.parentIsMember == false,
            onSelected: (_)
            {
              ctx.form.parentIsMember = false;
              ctx.onChanged();
            },
          ),
        ),
      ],
    );
  }
}

const double _factLabelWidth = 230;

class _ReportBlock extends StatelessWidget
{
  final VoidCallback onReportError;

  const _ReportBlock({required this.onReportError});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppGradientButton(
          label: tr('SEGNALA ERRORE', 'REPORT ERROR'),
          icon: Icons.flag_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.dismissAccent,
          height: 50,
          fontSize: 14,
          radius: 25,
          onPressed: onReportError,
        ),
      ),
    );
  }
}

class IdentityCard extends StatelessWidget
{
  final PersonEditCardContext ctx;
  final VoidCallback onReportError;

  const IdentityCard({super.key, required this.ctx, required this.onReportError});

  @override
  Widget build(BuildContext context)
  {
    final PersonItem person = ctx.form.person!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPhotoUploader(
          imageBytes: ctx.form.fotoProfilo,
          initialImageUrl: person.profileImageUrl,
          onImagePicked: (bytes)
          {
            ctx.form.fotoProfilo = bytes;
            ctx.onChanged();
          },
        ),
        const SizedBox(height: 24),
        AppInfoRow(label: tr('Nome', 'First name'), value: orDash(person.firstName), labelWidth: _factLabelWidth),
        AppInfoRow(label: tr('Cognome', 'Surname'), value: orDash(person.lastName), labelWidth: _factLabelWidth),
        AppInfoRow(label: tr('Sesso', 'Sex'), value: orDash(person.gender), labelWidth: _factLabelWidth),
        AppInfoRow(
          label: tr('Codice fiscale', 'Tax code'),
          value: orDash(person.fiscalCode),
          labelWidth: _factLabelWidth,
        ),
        _ReportBlock(onReportError: onReportError),
      ],
    );
  }
}

class BirthDataCard extends StatelessWidget
{
  final PersonEditCardContext ctx;
  final VoidCallback onReportError;

  const BirthDataCard({super.key, required this.ctx, required this.onReportError});

  @override
  Widget build(BuildContext context)
  {
    final PersonItem person = ctx.form.person!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInfoRow(
          label: tr('Data di nascita', 'Date of birth'),
          value: orDash(ctx.form.birthDateCtrl.text),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: tr('Città di nascita', 'City of birth'),
          value: orDash(person.birthCity),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: tr('Provincia di nascita', 'Province of birth'),
          value: orDash(person.birthProvince),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: tr('Nazione di nascita', 'Country of birth'),
          value: orDash(person.birthNation),
          labelWidth: _factLabelWidth,
        ),
        _ReportBlock(onReportError: onReportError),
      ],
    );
  }
}

class IdentityEditCard extends StatelessWidget
{
  static const double _breakpoint = 560;

  static const double _fieldLabelTopGap = 16;

  final PersonEditCardContext ctx;

  const IdentityEditCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final Widget firstNameValue = AppTextField(
      controller: ctx.form.firstNameCtrl,
      label: tr('Nome', 'First name'),
      hintText: tr('Es. Mario', 'E.g. Mario'),
      maxLength: FieldLimits.personName,
      errorText: ctx.errors['nome'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => ctx.clearError('nome'),
    );

    final Widget lastNameValue = AppTextField(
      controller: ctx.form.lastNameCtrl,
      label: tr('Cognome', 'Surname'),
      hintText: tr('Es. Rossi', 'E.g. Rossi'),
      maxLength: FieldLimits.personName,
      errorText: ctx.errors['cognome'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => ctx.clearError('cognome'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPhotoUploader(
          imageBytes: ctx.form.fotoProfilo,
          onImagePicked: (bytes)
          {
            ctx.form.fotoProfilo = bytes;
            ctx.onChanged();
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints)
          {
            if (constraints.maxWidth < _breakpoint)
            {
              return Column(children: [firstNameValue, lastNameValue]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firstNameValue),
                const SizedBox(width: 16),
                Expanded(child: lastNameValue),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints)
          {
            final Widget genderValue = PersonChipGroupField(
              label: tr('Sesso', 'Sex'),
              options: const ['M', 'F'],
              value: ctx.form.genderValue,
              errorText: ctx.errors['sesso'],
              onChanged: (value)
              {
                ctx.form.genderValue = value;
                ctx.clearError('sesso');
              },
            );

            final Widget cf = AppTextField(
              controller: ctx.form.cfCtrl,
              label: tr('Codice fiscale', 'Tax code'),
              hintText: tr('Es. RSSMRA80A01L157H', 'E.g. RSSMRA80A01L157H'),
              maxLength: FieldLimits.taxCode,
              errorText: ctx.errors['cf'],
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => ctx.clearError('cf'),
            );

            if (constraints.maxWidth < _breakpoint)
            {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [genderValue, cf]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: _fieldLabelTopGap),
                    child: genderValue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: cf),
              ],
            );
          },
        ),
      ],
    );
  }
}

class BirthDataEditCard extends StatelessWidget
{
  static const double _breakpoint = 560;

  final PersonEditCardContext ctx;

  const BirthDataEditCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final bool abroad = ctx.form.bornAbroad;

    final Widget cityValue = AppTextField(
      controller: ctx.form.birthCityCtrl,
      label: abroad
          ? tr('Città di nascita (opzionale)', 'City of birth (optional)')
          : tr('Città di nascita', 'City of birth'),
      hintText: abroad ? tr('Es. Bucarest', 'E.g. Bucharest') : tr('Es. Thiene', 'E.g. Thiene'),
      maxLength: FieldLimits.city,
      errorText: ctx.errors['cittaNascita'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => ctx.clearError('cittaNascita'),
    );

    final Widget provinceCode = AppTextField(
      controller: ctx.form.birthProvinceCtrl,
      label: tr('Provincia di nascita', 'Province of birth'),
      hintText: tr('Es. VI', 'E.g. VI'),
      maxLength: FieldLimits.province,
      errorText: ctx.errors['provNascita'],
      enabled: !abroad,
      onChanged: (_) => ctx.clearError('provNascita'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: ctx.form.birthDateCtrl,
          label: tr('Data di nascita', 'Date of birth'),
          hintText: tr('gg/mm/aaaa', 'dd/mm/yyyy'),
          errorText: ctx.errors['dataNascita'],
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          onChanged: (_) => ctx.clearError('dataNascita'),
        ),
        const SizedBox(height: 20),
        cardSection(
          tr('Luogo di nascita', 'Place of birth'),
          AppSegmentedSwitch(
            value: !abroad,
            trueLabel: tr('Italia', 'Italy'),
            falseLabel: tr('Estero', 'Abroad'),
            onChanged: (inItaly)
            {
              ctx.form.setBornAbroad(!inItaly);

              for (final key in const ['cittaNascita', 'provNascita', 'nazioneNascita'])
              {
                ctx.errors.remove(key);
              }

              ctx.onChanged();
            },
          ),
        ),
        if (abroad)
          AppTextField(
            controller: ctx.form.birthNationCtrl,
            label: tr('Nazione di nascita', 'Country of birth'),
            hintText: tr('Es. Romania', 'E.g. Romania'),
            maxLength: FieldLimits.nation,
            errorText: ctx.errors['nazioneNascita'],
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => ctx.clearError('nazioneNascita'),
          ),
        LayoutBuilder(
          builder: (context, constraints)
          {
            if (constraints.maxWidth < _breakpoint)
            {
              return Column(children: [cityValue, provinceCode]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cityValue),
                const SizedBox(width: 16),
                Expanded(child: provinceCode),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ConsentsCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const ConsentsCard({super.key, required this.ctx});

  Widget _consent({
    required String label,
    required String description,
    required bool value,
    required String? errorText,
    required ValueChanged<bool> onChanged,
  })
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFieldLabel(label),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 12),
          AppSegmentedSwitch(value: value, onChanged: onChanged),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialDangerText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return CardScrollArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ctx.form.isCreation) ...[
          _consent(
            label: tr('Statuto', 'Statute'),
            description: tr(
              'Dichiara di aver letto e accettato lo statuto dell\'Associazione.',
              'Declares they have read and accepted the Association’s statute.',
            ),
            value: ctx.form.statuteAcknowledged,
            errorText: ctx.errors['statutoAccettato'],
            onChanged: (value)
            {
              ctx.form.statuteAcknowledged = value;
              ctx.clearError('statutoAccettato');
            },
          ),
          _consent(
            label: tr('Regolamento', 'Rules'),
            description: tr(
              'Dichiara di aver letto e accettato il regolamento interno.',
              'Declares they have read and accepted the internal rules.',
            ),
            value: ctx.form.regulationAcknowledged,
            errorText: ctx.errors['regolamentoAccettato'],
            onChanged: (value)
            {
              ctx.form.regulationAcknowledged = value;
              ctx.clearError('regolamentoAccettato');
            },
          ),
          _consent(
            label: tr('Videosorveglianza', 'Video surveillance'),
            description: tr(
              'Dichiara di aver preso visione dell\'informativa sulla '
              'videosorveglianza dei locali.',
              'Declares they have read the notice on the '
              'video surveillance of the premises.',
            ),
            value: ctx.form.videoSurveillanceAcknowledged,
            errorText: ctx.errors['videosorveglianzaPresaVisione'],
            onChanged: (value)
            {
              ctx.form.videoSurveillanceAcknowledged = value;
              ctx.clearError('videosorveglianzaPresaVisione');
            },
          ),
          ],
          _consent(
            label: tr('Dati particolari (opzionale)', 'Special category data (optional)'),
            description: tr(
              'Acconsente al trattamento dei dati particolari (salute, '
              'certificazioni) per le finalità dell\'Associazione.',
              'Agrees to the processing of special category data (health, '
              'certifications) for the Association’s purposes.',
            ),
            value: ctx.form.specialCategoryDataConsentValue,
            errorText: null,
            onChanged: (value)
            {
              ctx.form.specialCategoryDataConsentValue = value;
              ctx.onChanged();
            },
          ),
          _consent(
            label: tr('Notiziari periodici (opzionale)', 'Newsletters (optional)'),
            description: tr(
              'Acconsente a ricevere i notiziari periodici dell\'Associazione.',
              'Agrees to receive the Association’s newsletters.',
            ),
            value: ctx.form.newsletterConsentValue,
            errorText: null,
            onChanged: (value)
            {
              ctx.form.newsletterConsentValue = value;
              ctx.onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class PsychologicalSupportCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const PsychologicalSupportCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cardSection(
          tr('Aderisce al servizio', 'Joins the service'),
          AppSegmentedSwitch(
            value: ctx.form.hasPsychologicalSupport,
            onChanged: (value)
            {
              ctx.form.hasPsychologicalSupport = value;
              ctx.onChanged();
            },
          ),
        ),
        if (ctx.form.hasPsychologicalSupport) ...[
          const SizedBox(height: 20),
          AppTextField(
            controller: ctx.form.psychologicalSupportStartDateCtrl,
            label: tr('Data di inizio', 'Start date'),
            hintText: tr('gg/mm/aaaa', 'dd/mm/yyyy'),
            errorText: ctx.errors['dataInizioSostegnoPsicologico'],
            keyboardType: TextInputType.number,
            inputFormatters: [DateInputFormatter()],
            onChanged: (_) => ctx.clearError('dataInizioSostegnoPsicologico'),
          ),
        ],
      ],
    );
  }
}

class ResidenceCard extends StatelessWidget
{
  static const double _breakpoint = 600;

  static const double _streetTypeWidth = 160;

  final PersonEditCardContext ctx;

  const ResidenceCard({super.key, required this.ctx});

  void _handWritten(String key)
  {
    ctx.clearError(key);
    ctx.form.residenceEditedByHand();
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget streetTypeValue = AppTextField(
      controller: ctx.form.streetTypeCtrl,
      label: tr('Indirizzo', 'Address'),
      hintText: tr('Via/Strada/...', 'Street/Road/...'),
      maxLength: FieldLimits.residenceType,
      errorText: ctx.errors['tipoVia'],
      onChanged: (_) => _handWritten('tipoVia'),
    );

    final Widget addressValue = AppTextField(
      controller: ctx.form.streetNameCtrl,
      label: '',
      hintText: tr('Nome', 'Name'),
      maxLength: FieldLimits.address,
      errorText: ctx.errors['indirizzo'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => _handWritten('indirizzo'),
    );

    final Widget streetNumberValue = AppTextField(
      controller: ctx.form.streetNumberCtrl,
      label: '',
      hintText: tr('N°', 'No.'),
      maxLength: FieldLimits.streetNumber,
      errorText: ctx.errors['civico'],
      onChanged: (_) => _handWritten('civico'),
    );

    final ResidenceOffer? offered = ctx.offeredResidence;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (offered != null) ...[
          AppChoiceCard(
            icon: Icons.home_outlined,
            title: offered.label,
            subtitle: offered.isEmpty
                ? tr(
                  'Non c\'è ancora niente da copiare: quella residenza non è stata scritta.',
                  'There is nothing to copy yet: that residence has not been written.',
                )
                : tr(
                  'Compila indirizzo, città, provincia e CAP con gli stessi dati.',
                  'Fills in address, city, province and postcode with the same details.',
                ),
            disabled: offered.isEmpty,
            selected: ctx.form.copiesResidence,
            onSelected: (taken)
            {
              if (taken)
              {
                ctx.form.takeResidence(offered);
              }
              else
              {
                ctx.form.giveBackResidence();
              }

              for (final key in const ['tipoVia', 'indirizzo', 'civico', 'cittaResidenza', 'provResidenza', 'cap'])
              {
                ctx.errors.remove(key);
              }

              ctx.onChanged();
            },
          ),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (context, constraints)
          {
            if (constraints.maxWidth < _breakpoint)
            {
              return Column(children: [streetTypeValue, addressValue, streetNumberValue]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _streetTypeWidth, child: streetTypeValue),
                const SizedBox(width: 16),
                Expanded(child: addressValue),
                const SizedBox(width: 16),
                SizedBox(width: 110, child: streetNumberValue),
              ],
            );
          },
        ),
        AppTextField(
          controller: ctx.form.residenceCityCtrl,
          label: tr('Città', 'City'),
          hintText: tr('Es. Thiene', 'E.g. Thiene'),
          maxLength: FieldLimits.city,
          errorText: ctx.errors['cittaResidenza'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _handWritten('cittaResidenza'),
        ),
        LayoutBuilder(
          builder: (context, constraints)
          {
            final Widget provinceCode = AppTextField(
              controller: ctx.form.residenceProvinceCtrl,
              label: tr('Provincia', 'Province'),
              hintText: tr('Es. VI', 'E.g. VI'),
              maxLength: FieldLimits.province,
              errorText: ctx.errors['provResidenza'],
              onChanged: (_) => _handWritten('provResidenza'),
            );

            final Widget postalCodeValue = AppTextField(
              controller: ctx.form.postalCodeCtrl,
              label: tr('CAP', 'Postcode'),
              hintText: tr('Es. 36016', 'E.g. 36016'),
              maxLength: FieldLimits.postalCode,
              errorText: ctx.errors['cap'],
              keyboardType: TextInputType.number,
              onChanged: (_) => _handWritten('cap'),
            );

            if (constraints.maxWidth < _breakpoint)
            {
              return Column(children: [provinceCode, postalCodeValue]);
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: provinceCode),
                const SizedBox(width: 16),
                Expanded(child: postalCodeValue),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ContactsCard extends StatelessWidget
{
  static const double _breakpoint = 560;

  final PersonEditCardContext ctx;

  const ContactsCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final Widget email = AppTextField(
      controller: ctx.form.emailCtrl,
      label: 'Email',
      hintText: tr('Es. mario.rossi@email.com', 'E.g. mario.rossi@email.com'),
      maxLength: FieldLimits.email,
      errorText: ctx.errors['email'],
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => ctx.clearError('email'),
    );

    final Widget phoneValue = AppTextField(
      controller: ctx.form.phoneCtrl,
      label: tr('Telefono', 'Phone'),
      hintText: tr('Es. 333 123 4567', 'E.g. 333 123 4567'),
      maxLength: FieldLimits.phone,
      errorText: ctx.errors['telefono'],
      keyboardType: TextInputType.phone,
      inputFormatters: const [PhoneInputFormatter()],
      onChanged: (_) => ctx.clearError('telefono'),
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(children: [email, phoneValue]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: email),
            const SizedBox(width: 16),
            Expanded(child: phoneValue),
          ],
        );
      },
    );
  }
}

// The new year's start; the year is the one in course.
class ReEnrollmentCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const ReEnrollmentCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    // Sized to the row, as the memberships card holds its own.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MembershipEditRow(
          yearController: ctx.form.reEnrollYearCtrl,
          dayMonthController: ctx.form.reEnrollStartCtrl,
          yearError: null,
          startError: ctx.errors['reEnrollStart'],
          onYearChanged: (_) {},
          onDayMonthChanged: (_) => ctx.clearError('reEnrollStart'),
          onRemove: null,
          yearFixed: true,
        ),
      ],
    );
  }
}

class MembershipsCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const MembershipsCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final List<MembershipRowData> rows = ctx.form.membershipRows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The cessation form prints it as the member's qualification.
        cardSection(
          ctx.form.genderValue == 'F'
              ? tr('Socia fondatrice', 'Founding member')
              : tr('Socio fondatore', 'Founding member'),
          AppSegmentedSwitch(
            value: ctx.form.founderValue,
            onChanged: (value)
            {
              ctx.form.founderValue = value;
              ctx.onChanged();
            },
          ),
        ),
        const SizedBox(height: 22),
        CardScrollArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++)
                MembershipEditRow(
                  key: ValueKey(rows[i]),
                  yearController: rows[i].yearCtrl,
                  dayMonthController: rows[i].dateCtrl,
                  yearError: ctx.errors['enrollmentYear_$i'],
                  startError: ctx.errors['enrollmentDate_$i'],
                  onYearChanged: (_) => ctx.clearError('enrollmentYear_$i'),
                  onDayMonthChanged: (_) => ctx.clearError('enrollmentDate_$i'),
                  onRemove: i == 0
                      ? null
                      : ()
                        {
                          rows.removeAt(i).dispose();
                          ctx.onChanged();
                        },
                  locked: rows[i].locked,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppAddRowButton(
          label: tr('AGGIUNGI ISCRIZIONE', 'ADD ENROLMENT'),
          onTap: ()
          {
            final Iterable<int> years = rows
                .map((row) => int.tryParse(row.yearCtrl.text.trim()))
                .whereType<int>();

            final int? earliest = years.isEmpty
                ? null
                : years.reduce((a, b) => a < b ? a : b);

            rows.add(MembershipRowData.empty(
              year: (earliest == null ? romeNow().year : earliest - 1).toString(),
            ));
            ctx.onChanged();
          },
        ),
      ],
    );
  }
}

class PaymentCard extends StatefulWidget
{
  final PersonEditCardContext ctx;

  const PaymentCard({super.key, required this.ctx});

  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<PaymentCard>
{
  PersonEditCardContext get ctx => widget.ctx;

  // The level comes from the step before: its figures are written in as the card shows.
  @override
  void initState()
  {
    super.initState();
    ctx.form.syncTariffDefaults();
    ctx.form.syncFeeDefaults();
  }

  @override
  void didUpdateWidget(PaymentCard oldWidget)
  {
    super.didUpdateWidget(oldWidget);
    ctx.form.syncTariffDefaults();
    ctx.form.syncFeeDefaults();
  }

  // Typing redraws the card: the standard tariff line follows the figures.
  void _typed(String key)
  {
    ctx.clearError(key);
    setState(() {});
  }

  Widget _amountField(String label, TextEditingController controller)
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: kRateHint,
      keyboardType: TextInputType.number,
      errorText: ctx.errors['tariffaCosto'],
      onChanged: (_) => _typed('tariffaCosto'),
    );
  }

  Widget _figures(String choice)
  {
    final PersonEditForm form = ctx.form;

    if (choice == kHourlyTariff)
    {
      return _amountField(kHourlyCostLabel, form.tariffHourlyCtrl);
    }

    if (choice == kMonthlyTariff)
    {
      return _amountField(kMonthlyCostLabel, form.tariffMonthlyCtrl);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: form.tariffPackageHoursCtrl,
            label: kPackageHoursLabel,
            hintText: tr('Es. 18', 'E.g. 18'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: _packageHoursDigits,
            errorText: ctx.errors['tariffaOre'],
            onChanged: (_) => _typed('tariffaOre'),
          ),
        ),
        const SizedBox(width: _tariffFieldGap),
        Expanded(child: _amountField(kPackageCostLabel, form.tariffPackageCostCtrl)),
      ],
    );
  }

  Widget _note(String text)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded, size: 17, color: AppTheme.trialTurquoise),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      ],
    );
  }

  // Shown only while the figures differ from the level's standard tariff.
  Widget? _standardNote()
  {
    final PersonEditForm form = ctx.form;
    final ({int cents, int? hours})? standard = form.tariffStandardFigures;
    final String? kind = kTariffKinds[form.tariffKindValue];

    if (standard == null || kind == null)
    {
      return null;
    }

    final String level = kTariffLevelLabels[form.currentSchoolLevel] ?? '';

    return _note(standardTariffNote(level, tariffCost(kind, standard.cents, standard.hours)));
  }

  Widget _paidSwitch({
    required bool value,
    required bool feminine,
    required ValueChanged<bool> onChanged,
  })
  {
    return AppSegmentedSwitch(
      value: value,
      trueLabel: feminine ? kPaidFeminineChoice : kPaidChoice,
      falseLabel: feminine ? kUnpaidFeminineChoice : kUnpaidChoice,
      hugContent: true,
      onChanged: (paid) => setState(() => onChanged(paid)),
    );
  }

  // The package or this month's fee, paid with the enrolment.
  Widget? _firstPayment()
  {
    final PersonEditForm form = ctx.form;

    if (!form.asksFirstPayment)
    {
      return null;
    }

    final bool package = form.tariffKindValue == kPackageTariff;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(package ? kPackagePaymentBlock : feePaymentBlock(romeNow())),
        const SizedBox(height: 10),
        _paidSwitch(
          value: form.firstPaymentPaid,
          feminine: !package,
          onChanged: (paid) => form.firstPaymentPaid = paid,
        ),
      ],
    );
  }

  // The tariff already chosen and waiting to start, shown instead of the choice.
  Widget _keptTariff(StudentTariffItem tariff)
  {
    final StudentPaymentsItem? payments = ctx.form.paymentsOnFile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(kTariffLabel),
        const SizedBox(height: 10),
        Text(
          currentTariff(tariff.kind, tariff.amountCents, tariff.packageHours),
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.trialOceanText),
        ),
        const SizedBox(height: 12),
        _note(changeQueuedReason(payments?.queuedStartsOn, ahead: payments?.tariff?.isHourly ?? false)),
      ],
    );
  }

  Widget? _tariff()
  {
    final PersonEditForm form = ctx.form;

    if (form.keptTariff case final StudentTariffItem kept)
    {
      return _keptTariff(kept);
    }

    if (!form.asksTariff)
    {
      return null;
    }

    final StandardTariffItem defaults = form.levelTariffs!;
    final String off = tariffOffFor(form.currentSchoolLevel);
    final String? choice = form.tariffKindValue;
    final Widget? note = choice == null ? null : _standardNote();
    final Widget? payment = _firstPayment();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: kTariffLabel,
          options: kTariffChoices,
          value: choice,
          struck: {
            for (final String option in kTariffChoices)
              if (!defaults.enabled(kTariffKinds[option]!)) option: off,
          },
          errorText: ctx.errors['tariffaAiutoCompiti'],
          onChanged: (value)
          {
            form.tariffKindValue = value;
            ctx.errors.remove('tariffaCosto');
            ctx.errors.remove('tariffaOre');
            ctx.clearError('tariffaAiutoCompiti');
          },
        ),
        if (choice != null) ...[
          const SizedBox(height: 20),
          _figures(choice),
        ],
        if (note != null) ...[
          const SizedBox(height: 12),
          note,
        ],
        if (payment != null) ...[
          const SizedBox(height: 20),
          payment,
        ],
      ],
    );
  }

  Widget _fee({
    required String label,
    required bool paid,
    required ValueChanged<bool> onPaid,
    required TextEditingController controller,
    required String errorKey,
  })
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 10),
        Row(
          children: [
            _paidSwitch(value: paid, feminine: true, onChanged: onPaid),
            const SizedBox(width: _tariffFieldGap),
            SizedBox(
              width: _feeAmountWidth,
              child: AppTextField(
                controller: controller,
                label: label,
                showLabel: false,
                hintText: kRateHint,
                keyboardType: TextInputType.number,
                errorText: ctx.errors[errorKey],
                onChanged: (_) => ctx.clearError(errorKey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Membership first, insurance second.
  (Widget, Widget)? _fees()
  {
    final PersonEditForm form = ctx.form;
    final int? year = form.feesYear;

    if (!form.asksFees || year == null)
    {
      return null;
    }

    return (
      _fee(
        label: membershipFeeLabel(year),
        paid: form.membershipFeePaid,
        onPaid: (paid) => form.membershipFeePaid = paid,
        controller: form.membershipFeeCtrl,
        errorKey: 'quotaIscrizione',
      ),
      _fee(
        label: insuranceFeeLabel(year),
        paid: form.insuranceFeePaid,
        onPaid: (paid) => form.insuranceFeePaid = paid,
        controller: form.insuranceFeeCtrl,
        errorKey: 'quotaAssicurazione',
      ),
    );
  }

  // The divider in the middle runs as tall as the taller column, whichever it is.
  Widget _columns(Widget first, Widget second)
  {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: _paymentColumnGap),
            Expanded(child: second),
          ],
        ),
        Positioned.fill(
          child: Center(
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: AppTheme.trialLine),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stacked(List<Widget> blocks, double gap)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          blocks[i],
        ],
      ],
    );
  }

  Widget? _top(bool wide)
  {
    final Widget? tariff = _tariff();
    final (Widget, Widget)? fees = _fees();

    if (fees == null)
    {
      return tariff;
    }

    final Widget feeColumn = _stacked([fees.$1, fees.$2], _feeGap);

    if (tariff == null)
    {
      return wide ? _columns(fees.$1, fees.$2) : feeColumn;
    }

    return wide ? _columns(tariff, feeColumn) : _stacked([tariff, feeColumn], _paymentBlockGap);
  }

  Widget _method()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: tr('Modalità di pagamento', 'Payment method'),
          options: kPaymentMethods.keys.toList(),
          value: ctx.form.paymentMethodValue,
          errorText: ctx.errors['modalitaPagamento'],
          onChanged: (value)
          {
            ctx.form.paymentMethodValue = value;
            ctx.clearError('modalitaPagamento');
          },
        ),
        if (kPaymentMethods[ctx.form.paymentMethodValue] == 'OTHER')
          AppTextField(
            controller: ctx.form.otherPaymentMethodCtrl,
            label: tr('Altra modalità', 'Other method'),
            hintText: tr('Es. Carta di credito', 'E.g. Credit card'),
            maxLength: FieldLimits.otherDetail,
            errorText: ctx.errors['altraModalitaPagamento'],
            onChanged: (_) => ctx.clearError('altraModalitaPagamento'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final Widget? top = _top(constraints.maxWidth >= _paymentColumnsWidth);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?top,
            // The tariff alone, for a member on file: their method lives in «Pagamenti».
            if (ctx.form.asksPaymentStep) ...[
              if (top != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: _paymentBlockGap),
                  child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                ),
              _method(),
            ],
          ],
        );
      },
    );
  }
}

class AdminCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const AdminCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: tr('Ruolo', 'Role'),
          options: kAdminRoles.keys.toList(),
          shownAs: ctx.form.genderValue == 'F' && !isEnglish ? const {'Tesoriere': 'Tesoriera'} : const {},
          value: ctx.form.adminRoleValue,
          errorText: ctx.errors['ruoloAmministratore'],
          onChanged: (value)
          {
            ctx.form.adminRoleValue = value;
            ctx.form.syncCollaborationWithAdminRole();
            ctx.clearError('ruoloAmministratore');
          },
        ),
        if (kAdminRoles[ctx.form.adminRoleValue] == 'OTHER')
          AppTextField(
            controller: ctx.form.otherAdminRoleCtrl,
            label: tr('Altro ruolo', 'Other role'),
            hintText: tr('Es. Segreteria', 'E.g. Secretariat'),
            maxLength: FieldLimits.otherRole,
            errorText: ctx.errors['altroRuoloAmministratore'],
            onChanged: (_) => ctx.clearError('altroRuoloAmministratore'),
          ),
      ],
    );
  }
}

class TeacherCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const TeacherCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cardSection(
          ctx.form.genderValue == 'F'
              ? tr('Studentessa delle superiori', 'Upper secondary student')
              : tr('Studente delle superiori', 'Upper secondary student'),
          AppSegmentedSwitch(
            value: ctx.form.isHighSchoolStudent,
            onChanged: (value)
            {
              ctx.form.isHighSchoolStudent = value;
              ctx.onChanged();
            },
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          controller: ctx.form.studiScolasticiCtrl,
          label: tr('Studi scolastici (opzionale)', 'School studies (optional)'),
          hintText: tr('Es. Liceo Classico', 'E.g. Classical high school'),
          maxLength: FieldLimits.education,
          errorText: ctx.errors['studiScolastici'],
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.clearError('studiScolastici'),
        ),
        if (!ctx.form.isHighSchoolStudent)
          AppTextField(
            controller: ctx.form.studiUniversitariCtrl,
            label: tr('Studi universitari (opzionale)', 'University studies (optional)'),
            hintText: tr('Es. Laurea in Informatica', 'E.g. Degree in Computer Science'),
            maxLength: FieldLimits.education,
            errorText: ctx.errors['studiUniversitari'],
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => ctx.clearError('studiUniversitari'),
          ),
      ],
    );
  }
}

class CourseParticipantCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const CourseParticipantCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: tr('Tipo corso', 'Course type'),
          options: [for (final course in ctx.form.allCourses) course.name],
          value: ctx.form.courseTypeValue,
          errorText: ctx.errors['tipoCorso'],
          onChanged: (value)
          {
            ctx.form.courseTypeValue = value;
            ctx.clearError('tipoCorso');
          },
        ),
        AppTextField(
          controller: ctx.form.certificateExpirationCtrl,
          label: tr('Scadenza certificato medico (opzionale)', 'Medical certificate expiry (optional)'),
          hintText: tr('gg/mm/aaaa', 'dd/mm/yyyy'),
          errorText: ctx.errors['scadenzaCertificato'],
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          onChanged: (_) => ctx.clearError('scadenzaCertificato'),
        ),
      ],
    );
  }
}

class EarlyExitCard extends StatelessWidget
{
  static String get _wholeMembership => tr('Tutta l\'iscrizione', 'Whole enrolment');
  static String get _limitedPeriod => tr('Periodo limitato', 'Limited period');

  final PersonEditCardContext ctx;

  const EarlyExitCard({super.key, required this.ctx});

  // Row errors are keyed by position, so any list change must clear them.
  void _clearErrors()
  {
    ctx.errors.removeWhere((key, _) =>
        key == 'uscitaAnticipataDal' ||
        key == 'uscitaAnticipataAl' ||
        key.startsWith('earlyExitDays_') ||
        key.startsWith('earlyExitTime_') ||
        key.startsWith('earlyExitReason_'));
  }

  void _clearDeclaration()
  {
    ctx.form.uscitaAnticipataPeriodoLimitato = false;
    ctx.form.uscitaAnticipataDalCtrl.clear();
    ctx.form.uscitaAnticipataAlCtrl.clear();

    for (final row in ctx.form.earlyExitRows)
    {
      row.dispose();
    }

    ctx.form.earlyExitRows.clear();
  }

  List<Widget> _buildDeclaration()
  {
    final List<EarlyExitRowData> rows = ctx.form.earlyExitRows;

    return [
      const SizedBox(height: 24),
      PersonChipGroupField(
        label: tr('Validità', 'Validity'),
        options: [_wholeMembership, _limitedPeriod],
        value: ctx.form.uscitaAnticipataPeriodoLimitato
            ? _limitedPeriod
            : _wholeMembership,
        onChanged: (choice)
        {
          ctx.form.uscitaAnticipataPeriodoLimitato = choice == _limitedPeriod;

          if (!ctx.form.uscitaAnticipataPeriodoLimitato)
          {
            ctx.form.uscitaAnticipataDalCtrl.clear();
            ctx.form.uscitaAnticipataAlCtrl.clear();
          }

          _clearErrors();
          ctx.onChanged();
        },
      ),
      if (ctx.form.uscitaAnticipataPeriodoLimitato)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: ctx.form.uscitaAnticipataDalCtrl,
                label: tr('Dal', 'From'),
                hintText: tr('gg/mm/aaaa', 'dd/mm/yyyy'),
                errorText: ctx.errors['uscitaAnticipataDal'],
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                onChanged: (_) => ctx.clearError('uscitaAnticipataDal'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: ctx.form.uscitaAnticipataAlCtrl,
                label: tr('Al', 'To'),
                hintText: tr('gg/mm/aaaa', 'dd/mm/yyyy'),
                errorText: ctx.errors['uscitaAnticipataAl'],
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                onChanged: (_) => ctx.clearError('uscitaAnticipataAl'),
              ),
            ),
          ],
        ),
      const SizedBox(height: 24),
      AppFieldLabel(tr('Uscite', 'Departures')),
      const SizedBox(height: 10),
      if (rows.isEmpty)
        PersonEmptyState(message: tr('Nessuna uscita indicata.', 'No departures set.')),
      for (var i = 0; i < rows.length; i++)
        EarlyExitEditRow(
          key: ValueKey(rows[i]),
          row: rows[i],
          errors: {
            'weekdays': ctx.errors['earlyExitDays_$i'],
            'time': ctx.errors['earlyExitTime_$i'],
            'reason': ctx.errors['earlyExitReason_$i'],
          },
          onChanged: ()
          {
            _clearErrors();
            ctx.onChanged();
          },
          onRemove: ()
          {
            rows.removeAt(i).dispose();
            _clearErrors();
            ctx.onChanged();
          },
        ),
      if (rows.length < PersonEditForm.maxEarlyExitRows) ...[
        const SizedBox(height: 6),
        AppAddRowButton(
          label: tr('AGGIUNGI USCITA', 'ADD DEPARTURE'),
          onTap: ()
          {
            rows.add(EarlyExitRowData.empty());
            _clearErrors();
            ctx.onChanged();
          },
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cardSection(
          tr('Autorizzata', 'Authorised'),
          AppSegmentedSwitch(
            value: ctx.form.uscitaAnticipata,
            onChanged: (value)
            {
              ctx.form.uscitaAnticipata = value;

              if (!value)
              {
                _clearDeclaration();
              }

              _clearErrors();
              ctx.onChanged();
            },
          ),
        ),
        if (ctx.form.uscitaAnticipata) ..._buildDeclaration(),
      ],
    );
  }
}

class CertificationsCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const CertificationsCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField.multiple(
          label: tr('Certificazione', 'Certification'),
          options: [_noCertification, ...kCertificationTypes.keys],
          values: ctx.form.certificationValues.isEmpty
              ? const {_noCertification}
              : ctx.form.certificationValues,
          errorText: ctx.errors['tipoCertificazione'],
          onToggled: (option)
          {
            final Set<String> chosen = ctx.form.certificationValues;

            if (option == _noCertification)
            {
              chosen.clear();
            }
            else if (!chosen.remove(option))
            {
              chosen.add(option);
            }

            ctx.clearError('tipoCertificazione');
            ctx.onChanged();
          },
        ),
        if (ctx.form.certificationValues.any((value) => kCertificationTypes[value] == 'DSA'))
          AppTextField(
            controller: ctx.form.dsaCertificationCtrl,
            label: tr('Tipo di DSA', 'Type of SLD'),
            hintText: tr('Es. Dislessia e discalculia', 'E.g. Dyslexia and dyscalculia'),
            maxLength: FieldLimits.dsaDetail,
            errorText: ctx.errors['tipoDsa'],
            onChanged: (_) => ctx.clearError('tipoDsa'),
          ),
        if (ctx.form.certificationValues.any((value) => kCertificationTypes[value] == 'OTHER'))
          AppTextField(
            controller: ctx.form.otherCertificationCtrl,
            label: tr('Altra certificazione', 'Other certification'),
            hintText: tr('Es. Autismo livello 1', 'E.g. Autism level 1'),
            maxLength: FieldLimits.otherDetail,
            errorText: ctx.errors['altraCertificazione'],
            onChanged: (_) => ctx.clearError('altraCertificazione'),
          ),
        if (ctx.form.certificationValues.isNotEmpty) ...[
          const SizedBox(height: 24),
          AppFieldLabel(tr('Presa visione incontri', 'Meetings acknowledged')),
          const SizedBox(height: 8),
          Text(
            tr(
              'In presenza di una certificazione, sono obbligatori due colloqui con uno psicologo dell\'Associazione.',
              'With a certification, two meetings with one of the Association’s psychologists are required.',
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: ctx.errors['presaVisioneIncontri'] != null
                  ? AppTheme.trialDangerText
                  : AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 12),
          AppSegmentedSwitch(
            value: ctx.form.psychMeetingsAcknowledgedValue,
            onChanged: (value)
            {
              ctx.form.psychMeetingsAcknowledgedValue = value;
              ctx.clearError('presaVisioneIncontri');
            },
          ),
        ],
      ],
    );
  }
}

class SchoolEnrollmentsCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const SchoolEnrollmentsCard({super.key, required this.ctx});

  // School errors are keyed by row position, so any list change must clear them.
  void _clearSchoolErrors()
  {
    ctx.errors.removeWhere((key, _) =>
        key == 'schoolGeneral' ||
        key.startsWith('schoolYear_') ||
        key.startsWith('school_') ||
        key.startsWith('program_') ||
        key.startsWith('grade_'));
  }

  void _openWizard(BuildContext context, {int? index})
  {
    final List<SchoolEnrollmentRowData> rows = ctx.form.schoolRows;

    showSchoolYearWizard(
      context: context,
      allSchools: ctx.form.allSchools,
      allPrograms: ctx.form.allPrograms,
      takenYears: takenSchoolYears(rows, except: index),
      isEditing: index != null,
      gender: ctx.form.genderValue,
      initial: index == null
          ? previousSchoolYearOf(rows)
          : SchoolYearChoice.ofRow(rows[index]),
      onConfirmed: (choice)
      {
        if (index == null)
        {
          rows.add(schoolEnrollmentRowOf(choice));
        }
        else
        {
          applySchoolYearChoice(rows[index], choice);
        }

        sortSchoolYearRows(rows);
        _clearSchoolErrors();
        ctx.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<SchoolEnrollmentRowData> rows = ctx.form.schoolRows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardScrollArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty)
                PersonEmptyState(message: tr('Nessun anno scolastico inserito.', 'No school years entered.')),
              for (var i = 0; i < rows.length; i++)
                SchoolEnrollmentSummaryRow(
                  key: ValueKey(rows[i]),
                  row: rows[i],
                  errors: {
                    'year': ctx.errors['schoolYear_$i'],
                    'school': ctx.errors['school_$i'],
                    'program': ctx.errors['program_$i'],
                    'grade': ctx.errors['grade_$i'],
                  },
                  onEdit: () => _openWizard(context, index: i),
                  onRemove: ()
                  {
                    rows.removeAt(i).dispose();
                    _clearSchoolErrors();
                    ctx.onChanged();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppAddRowButton(
          label: tr('AGGIUNGI ANNO', 'ADD YEAR'),
          onTap: () => _openWizard(context),
        ),
      ],
    );
  }
}

class StaffCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const StaffCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final bool forced = ctx.form.collaborationForcedUnpaid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: tr('Collaborazione', 'Collaboration'),
          options: forced ? [labelOfCode(kCollaborationTypes, 'UNPAID')] : kCollaborationChoices,
          value: ctx.form.collaborationTypeValue,
          enabled: !forced,
          note: forced
              ? tr(
                  'Presidente, vicepresidente e tesoriere non possono essere retribuiti.',
                  'The president, vice president and treasurer cannot be paid.',
                )
              : null,
          errorText: ctx.errors['tipoCollaborazione'],
          onChanged: (value)
          {
            ctx.form.collaborationTypeValue = value;
            ctx.clearError('tipoCollaborazione');
          },
        ),
        if (ctx.form.isPaidCollaboration) ...[
          const SizedBox(height: 20),
          AppTextField(
            controller: ctx.form.grossCompensationCtrl,
            label: tr('Compenso orario lordo (opzionale)', 'Gross hourly pay (optional)'),
            hintText: tr('Es. 10,00', 'E.g. 10.00'),
            keyboardType: TextInputType.number,
            errorText: ctx.errors['compensoLordo'],
            onChanged: (_) => ctx.clearError('compensoLordo'),
          ),
        ],
        if (!ctx.form.ibanInCompensi) ...[
          const SizedBox(height: 20),
          AppTextField(
            controller: ctx.form.ibanCtrl,
            label: 'IBAN',
            hintText: tr('Es. IT00A...', 'E.g. IT00A...'),
            maxLength: FieldLimits.iban,
            errorText: ctx.errors['iban'],
            onChanged: (_) => ctx.clearError('iban'),
          ),
        ],
      ],
    );
  }
}

class MinorSafetyCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const MinorSafetyCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: ctx.form.emergencyContactNameCtrl,
          label: tr('Contatto emergenza', 'Emergency contact'),
          hintText: tr('Nome e cognome', 'First name and surname'),
          maxLength: FieldLimits.contactName,
          errorText: ctx.errors['contattoEmergenzaNome'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => ctx.clearError('contattoEmergenzaNome'),
        ),
        AppTextField(
          controller: ctx.form.emergencyContactPhoneCtrl,
          label: tr('Telefono emergenza', 'Emergency phone'),
          hintText: tr('Es. 333 123 4567', 'E.g. 333 123 4567'),
          maxLength: FieldLimits.phone,
          errorText: ctx.errors['contattoEmergenzaTelefono'],
          keyboardType: TextInputType.phone,
          inputFormatters: const [PhoneInputFormatter()],
          onChanged: (_) => ctx.clearError('contattoEmergenzaTelefono'),
        ),
        AppTextField(
          controller: ctx.form.allergiesCtrl,
          label: tr('Allergie / Intolleranze / Condizioni di salute', 'Allergies / Intolerances / Health conditions'),
          hintText: tr('Es. Polline', 'E.g. Pollen'),
          maxLength: FieldLimits.notes,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.onChanged(),
        ),
        AppTextField(
          controller: ctx.form.medicationsCtrl,
          label: tr('Farmaci / Altre indicazioni', 'Medicines / Other instructions'),
          hintText: tr('Es. Ventolin', 'E.g. Ventolin'),
          maxLength: FieldLimits.notes,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.onChanged(),
        ),
      ],
    );
  }
}
