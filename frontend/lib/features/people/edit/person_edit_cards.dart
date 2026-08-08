import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
import '../widgets/membership_edit_row.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/person_row_models.dart';
import '../widgets/school_enrollment_edit_row.dart' hide currentSchoolYearStart;
import 'person_edit_form.dart';
import 'widgets/person_chip_group_field.dart';
import '../../../shared/widgets/app_choice_card.dart';

// The cards of the edit dialog: one per group of questions.
//
// Stateless widgets. They receive the form, edit it in place and notify whoever
// owns it — the dialog, which calls setState. They live in a file of their own
// because the whole dialog calls four endpoints as soon as it opens and cannot
// be mounted in a test, whereas a single card can.

// What every card receives.
class PersonEditCardContext
{
  final PersonEditForm form;
  final Map<String, String> errors;
  final VoidCallback onChanged;

  // The residence of whoever opened this dialog, where there is one: the
  // residence card offers it behind a checkbox. Null in dialogs not opened from
  // another one, which is the normal case.
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

// Between one choice and the next. Here rather than as a margin inside the
// card: a margin under the last one is space nobody asked for, and on a stack of
// six it was enough to bring up a scrollbar for twelve pixels.
const double _choiceGap = 12;

// The label above a group of controls, with the room around it.
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

// --------------------------------------------------------------- le scelte

class InvolvementCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const InvolvementCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _choiceGap,
      children: [
        AppChoiceCard(
          icon: Icons.workspaces_outline,
          title: 'Coinvolto nelle attività',
          subtitle: 'Partecipa alla vita dell\'Associazione, svolge uno o più ruoli '
              'oppure è un genitore.',
          selected: ctx.form.involvementType == 0,
          onSelected: (_)
          {
            ctx.form.chooseInvolvement(0);
            ctx.onChanged();
          },
        ),
        AppChoiceCard(
          icon: Icons.card_membership_rounded,
          title: 'Solo socio',
          subtitle: 'Paga regolarmente la quota di iscrizione per sostenere '
              'l\'Associazione, ma non ricopre alcun ruolo.',
          selected: ctx.form.involvementType == 1,
          onSelected: (_)
          {
            ctx.form.chooseInvolvement(1);
            ctx.onChanged();
          },
        ),
      ],
    );
  }
}

class RolesCard extends StatelessWidget
{
  // Below this width two columns of choices become two narrow columns, and the
  // text explaining the role wraps three times.
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

  // Which roles can be picked. Empty means all of them: a minor created on the
  // fly is not offered parent, psychologist or administrator, which require
  // being of age.
  final Set<String> only;

  const RolesCard({super.key, required this.ctx, this.only = const {}});

  List<PersonRoleOption> get _options => only.isEmpty
      ? kPersonRoleOptions
      : kPersonRoleOptions.where((role) => only.contains(role.id)).toList();

  @override
  Widget build(BuildContext context)
  {
    // Two columns where there is room: six roles in single file made a column
    // taller than the dialog, which then scrolled to show the last one.
    //
    // The two in a row come out the same height: the sentences explaining the
    // roles are not the same length, and two side by side at different heights
    // read as crooked at once.
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
    return AppChoiceCard(
      icon: _icons[role.id] ?? Icons.person_outline,
      title: role.label,
      subtitle: role.description,
      selected: ctx.form.selectedRoles.contains(role.id),
      onSelected: (selected)
      {
        ctx.form.toggleRole(role.id, selected);
        ctx.onChanged();
      },
    );
  }
}

class AssociationCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const AssociationCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: _choiceGap,
      children: [
        AppChoiceCard(
          icon: Icons.person_outlined,
          title: 'Sì',
          subtitle: 'Il genitore aderisce all\'Associazione e versa la quota annuale.',
          selected: ctx.form.parentIsMember == true,
          onSelected: (_)
          {
            ctx.form.parentIsMember = true;
            ctx.onChanged();
          },
        ),
        AppChoiceCard(
          icon: Icons.person_off_outlined,
          title: 'No',
          subtitle: 'Il genitore viene registrato solo come tutore del minore.',
          // Neither of the two until they say so: a self-ticked "No" was an
          // answer nobody had given.
          selected: ctx.form.parentIsMember == false,
          onSelected: (_)
          {
            ctx.form.parentIsMember = false;
            ctx.onChanged();
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------- i dati personali

// What cannot be changed from here: identity and birth. A value that cannot be
// changed is not a field but a fact, and it reads the way a fact reads on the
// person's page — where these same two groups live under the same names.
// Disabled fields, by contrast, looked like broken ones.

// A fact's label and its value sit in two columns, and this is the first. Wide
// enough to keep the longest label on one line and to leave a visible gap
// between the name and the value.
const double _factLabelWidth = 230;

// The line explaining why it cannot be edited, and how to have it corrected.
class _ReportBlock extends StatelessWidget
{
  final String explanation;
  final VoidCallback onReportError;

  const _ReportBlock({required this.explanation, required this.onReportError});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          explanation,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: AppGradientButton(
            label: 'SEGNALA ERRORE',
            icon: Icons.report_gmailerrorred_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: 46,
            fontSize: 13,
            radius: 23,
            onPressed: onReportError,
          ),
        ),
      ],
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
        // The uploader takes the pill's whole width: inside a row, as a child
        // without flex, it would be handed an infinite width and its
        // LayoutBuilder would have nothing to do with it.
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
        AppInfoRow(label: 'Nome', value: orDash(person.firstName), labelWidth: _factLabelWidth),
        AppInfoRow(label: 'Cognome', value: orDash(person.lastName), labelWidth: _factLabelWidth),
        AppInfoRow(label: 'Sesso', value: orDash(person.gender), labelWidth: _factLabelWidth),
        AppInfoRow(
          label: 'Codice fiscale',
          value: orDash(person.fiscalCode),
          labelWidth: _factLabelWidth,
        ),
        _ReportBlock(
          explanation: '',
          onReportError: onReportError,
        ),
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
          label: 'Data di nascita',
          value: orDash(ctx.form.birthDateCtrl.text),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: 'Città di nascita',
          value: orDash(person.birthCity),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: 'Provincia di nascita',
          value: orDash(person.birthProvince),
          labelWidth: _factLabelWidth,
        ),
        AppInfoRow(
          label: 'Nazione di nascita',
          value: orDash(person.birthNation),
          labelWidth: _factLabelWidth,
        ),
        _ReportBlock(
          explanation: '',
          onReportError: onReportError,
        ),
      ],
    );
  }
}

// The same two cards, but to be filled in: when the person does not exist yet,
// what will later be untouchable is the only thing that can be written.
class IdentityEditCard extends StatelessWidget
{
  static const double _breakpoint = 560;

  // The gap AppTextField leaves above its own label.
  static const double _fieldLabelTopGap = 16;

  final PersonEditCardContext ctx;

  const IdentityEditCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    final Widget firstNameValue = AppTextField(
      controller: ctx.form.firstNameCtrl,
      label: 'Nome',
      hintText: 'Es. Mario',
      errorText: ctx.errors['nome'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => ctx.clearError('nome'),
    );

    final Widget lastNameValue = AppTextField(
      controller: ctx.form.lastNameCtrl,
      label: 'Cognome',
      hintText: 'Es. Rossi',
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
        // Gender and tax code in one row: the first is two chips, and on a row
        // of its own it left half the form empty. The two labels start at the
        // same height, so the row reads as a row.
        LayoutBuilder(
          builder: (context, constraints)
          {
            final Widget genderValue = PersonChipGroupField(
              label: 'Sesso',
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
              label: 'Codice fiscale',
              hintText: 'Es. RSSMRA80A01L157H',
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
                // The same two columns as the row above: gender under the
                // first name, tax code under the last. The chip group has none
                // of the gap a field leaves above its label, so it is given one
                // here, and both labels and both controls line up.
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
    final Widget cityValue = AppTextField(
      controller: ctx.form.birthCityCtrl,
      label: 'Città di nascita',
      hintText: 'Es. Thiene',
      errorText: ctx.errors['cittaNascita'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => ctx.clearError('cittaNascita'),
    );

    final Widget provinceCode = AppTextField(
      controller: ctx.form.birthProvinceCtrl,
      label: 'Provincia di nascita',
      hintText: 'Es. VI',
      errorText: ctx.errors['provNascita'],
      onChanged: (_) => ctx.clearError('provNascita'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: ctx.form.birthDateCtrl,
          label: 'Data di nascita',
          hintText: 'gg/mm/aaaa',
          errorText: ctx.errors['dataNascita'],
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          onChanged: (_) => ctx.clearError('dataNascita'),
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
        AppTextField(
          controller: ctx.form.birthNationCtrl,
          label: 'Nazione di nascita',
          hintText: 'Es. Italia',
          errorText: ctx.errors['nazioneNascita'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => ctx.clearError('nazioneNascita'),
        ),
      ],
    );
  }
}

// The consents, signed once and once only: on joining.
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
                color: AppTheme.trialDanger,
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
    // On creation there are five, each with its explanation under it: a card
    // taller than the dialog, which set everything else in motion.
    return CardScrollArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The three declarations are signed once, on joining: they are never
          // withdrawn afterwards, and showing them when editing would suggest
          // otherwise. The two consents below can be changed at any time.
          if (ctx.form.isCreation) ...[
          _consent(
            label: 'Statuto',
            description: 'Dichiara di aver letto e accettato lo statuto dell\'Associazione.',
            value: ctx.form.statuteAcknowledged,
            errorText: ctx.errors['statutoAccettato'],
            onChanged: (value)
            {
              ctx.form.statuteAcknowledged = value;
              ctx.clearError('statutoAccettato');
            },
          ),
          _consent(
            label: 'Regolamento',
            description: 'Dichiara di aver letto e accettato il regolamento interno.',
            value: ctx.form.regulationAcknowledged,
            errorText: ctx.errors['regolamentoAccettato'],
            onChanged: (value)
            {
              ctx.form.regulationAcknowledged = value;
              ctx.clearError('regolamentoAccettato');
            },
          ),
          _consent(
            label: 'Videosorveglianza',
            description: 'Dichiara di aver preso visione dell\'informativa sulla '
                'videosorveglianza dei locali.',
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
            label: 'Dati particolari',
            description: 'Acconsente al trattamento dei dati particolari (salute, '
                'certificazioni) per le finalità dell\'Associazione.',
            value: ctx.form.specialCategoryDataConsentValue,
            errorText: null,
            onChanged: (value)
            {
              ctx.form.specialCategoryDataConsentValue = value;
              ctx.onChanged();
            },
          ),
          _consent(
            label: 'Notiziari periodici',
            description: 'Acconsente a ricevere i notiziari periodici dell\'Associazione.',
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

// The psychological support service, which can be asked for on joining.
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
          'Aderisce al servizio',
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
            label: 'Data di inizio',
            hintText: 'gg/mm/aaaa',
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
  // Below this width street type, name and number no longer fit in a row.
  static const double _breakpoint = 600;

  // Wide enough for the whole 'Via/Strada/...' hint: cut short, it stops
  // saying what goes in the field.
  static const double _streetTypeWidth = 160;

  final PersonEditCardContext ctx;

  const ResidenceCard({super.key, required this.ctx});

  // A field typed by hand: the error goes, and the tick with it, because what
  // is being typed is no longer the residence that was offered.
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
      label: 'Indirizzo',
      hintText: 'Via/Strada/...',
      errorText: ctx.errors['tipoVia'],
      onChanged: (_) => _handWritten('tipoVia'),
    );

    final Widget addressValue = AppTextField(
      controller: ctx.form.streetNameCtrl,
      label: '',
      hintText: 'Nome',
      errorText: ctx.errors['indirizzo'],
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => _handWritten('indirizzo'),
    );

    final Widget streetNumberValue = AppTextField(
      controller: ctx.form.streetNumberCtrl,
      label: '',
      hintText: 'N°',
      errorText: ctx.errors['civico'],
      onChanged: (_) => _handWritten('civico'),
    );

    final ResidenceOffer? offered = ctx.offeredResidence;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Above the fields, because it is the shortcut to filling them in:
        // below, it would read as something to do after writing them.
        //
        // It is there even when there is nothing to copy yet, disabled and
        // saying what is missing. Hidden until the other residence is written,
        // it would be invisible exactly when it is looked for — this dialog gets
        // opened before the other one is filled in — and nobody would know it
        // existed.
        if (offered != null) ...[
          AppChoiceCard(
            icon: Icons.home_outlined,
            title: offered.label,
            subtitle: offered.isEmpty
                ? 'Non c\'è ancora niente da copiare: quella residenza non è stata scritta.'
                : 'Compila indirizzo, città, provincia e CAP con gli stessi dati.',
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

              // The six fields changed underneath their errors.
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
          label: 'Città',
          hintText: 'Es. Thiene',
          errorText: ctx.errors['cittaResidenza'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _handWritten('cittaResidenza'),
        ),
        LayoutBuilder(
          builder: (context, constraints)
          {
            final Widget provinceCode = AppTextField(
              controller: ctx.form.residenceProvinceCtrl,
              label: 'Provincia',
              hintText: 'Es. VI',
              errorText: ctx.errors['provResidenza'],
              onChanged: (_) => _handWritten('provResidenza'),
            );

            final Widget postalCodeValue = AppTextField(
              controller: ctx.form.postalCodeCtrl,
              label: 'CAP',
              hintText: 'Es. 36016',
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
      hintText: 'Es. mario.rossi@email.com',
      errorText: ctx.errors['email'],
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => ctx.clearError('email'),
    );

    final Widget phoneValue = AppTextField(
      controller: ctx.form.phoneCtrl,
      label: 'Telefono',
      hintText: 'Es. 3331234567',
      errorText: ctx.errors['telefono'],
      keyboardType: TextInputType.phone,
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

// --------------------------------------------------- i dati associativi

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
        // The rows scroll, the button that adds one does not: it is pressed
        // after writing the last row, and inside the list it would run off the
        // bottom exactly when it is needed.
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
                  // The first cannot be removed: it is the membership the
                  // person is a member by.
                  onRemove: i == 0
                      ? null
                      : ()
                        {
                          rows.removeAt(i).dispose();
                          ctx.onChanged();
                        },
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppAddRowButton(
          label: 'AGGIUNGI ISCRIZIONE',
          onTap: ()
          {
            // Rows are added going back in time: the one being written is the
            // membership before the oldest already there, so the year proposed
            // is the one before it — never the year after the most recent,
            // which would invent a membership that has not happened yet.
            final Iterable<int> years = rows
                .map((row) => int.tryParse(row.yearCtrl.text.trim()))
                .whereType<int>();

            final int? earliest = years.isEmpty
                ? null
                : years.reduce((a, b) => a < b ? a : b);

            rows.add(MembershipRowData.empty(
              year: (earliest == null ? DateTime.now().year : earliest - 1).toString(),
            ));
            ctx.onChanged();
          },
        ),
      ],
    );
  }
}

class PaymentCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const PaymentCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonChipGroupField(
          label: 'Modalità di pagamento',
          options: const ['Contanti', 'Bonifico bancario', 'Altro'],
          value: ctx.form.paymentMethodValue,
          errorText: ctx.errors['modalitaPagamento'],
          onChanged: (value)
          {
            ctx.form.paymentMethodValue = value;
            ctx.clearError('modalitaPagamento');
          },
        ),
        if (ctx.form.paymentMethodValue == 'Altro')
          AppTextField(
            controller: ctx.form.otherPaymentMethodCtrl,
            label: 'Altra modalità',
            hintText: 'Es. Carta di credito',
            errorText: ctx.errors['altraModalitaPagamento'],
            onChanged: (_) => ctx.clearError('altraModalitaPagamento'),
          ),
      ],
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
          label: 'Ruolo',
          options: const ['Presidente', 'Vicepresidente', 'Tesoriere', 'Altro'],
          value: ctx.form.adminRoleValue,
          errorText: ctx.errors['ruoloAmministratore'],
          onChanged: (value)
          {
            ctx.form.adminRoleValue = value;
            // President, vice president and treasurer cannot be paid: the
            // collaboration follows the role without asking.
            ctx.form.syncCollaborationWithAdminRole();
            ctx.clearError('ruoloAmministratore');
          },
        ),
        if (ctx.form.adminRoleValue == 'Altro')
          AppTextField(
            controller: ctx.form.otherAdminRoleCtrl,
            label: 'Altro ruolo',
            hintText: 'Es. Responsabile IT',
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
        AppTextField(
          controller: ctx.form.studiScolasticiCtrl,
          label: 'Studi scolastici',
          hintText: 'Es. Liceo Classico',
          errorText: ctx.errors['studiScolastici'],
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.clearError('studiScolastici'),
        ),
        AppTextField(
          controller: ctx.form.studiUniversitariCtrl,
          label: 'Studi universitari',
          hintText: 'Es. Laurea in Informatica',
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
        // The courses the association runs, and not a field to type one into:
        // in the database they are a two-value enum, so a third name would not
        // fit anyway. When editing it used to be a text field, seeded with the
        // label the server sends and posted back verbatim to a server expecting
        // the code — pressing SAVE on a participant, without touching anything,
        // was enough to make the save fail.
        PersonChipGroupField(
          label: 'Tipo corso',
          options: kCourseTypes.keys.toList(),
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
          label: 'Scadenza certificato medico',
          hintText: 'gg/mm/aaaa',
          errorText: ctx.errors['scadenzaCertificato'],
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          onChanged: (_) => ctx.clearError('scadenzaCertificato'),
        ),
      ],
    );
  }
}

class StudentCard extends StatelessWidget
{
  final PersonEditCardContext ctx;

  const StudentCard({super.key, required this.ctx});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ctx.form.isMinor) ...[
          cardSection(
            'Uscita anticipata',
            AppSegmentedSwitch(
              value: ctx.form.uscitaAnticipata,
              onChanged: (value)
              {
                ctx.form.uscitaAnticipata = value;
                ctx.onChanged();
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
        PersonChipGroupField(
          label: 'Certificazione',
          options: const ['No', 'DSA', 'BES', 'ADHD', 'Altro'],
          value: ctx.form.certificationTypeValue,
          errorText: ctx.errors['tipoCertificazione'],
          onChanged: (value)
          {
            ctx.form.certificationTypeValue = value;
            ctx.clearError('tipoCertificazione');
          },
        ),
        if (ctx.form.certificationTypeValue == 'Altro')
          AppTextField(
            controller: ctx.form.otherCertificationCtrl,
            label: 'Altra certificazione',
            hintText: 'Es. Autismo livello 1',
            errorText: ctx.errors['altraCertificazione'],
            onChanged: (_) => ctx.clearError('altraCertificazione'),
          ),
        // Whoever holds a certification has to know that two meetings with the
        // psychologist are mandatory: a condition of joining and not a detail,
        // so it is ticked by hand.
        if (ctx.form.certificationTypeValue != null && ctx.form.certificationTypeValue != 'No') ...[
          const SizedBox(height: 24),
          // Laid out like the consents: title, what is being agreed to, then
          // the switch. Under the switch the sentence arrived after the answer
          // had already been given.
          const AppFieldLabel('Presa visione incontri'),
          const SizedBox(height: 8),
          Text(
            'In presenza di una certificazione, sono obbligatori due colloqui con uno psicologo dell\'Associazione.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: ctx.errors['presaVisioneIncontri'] != null
                  ? AppTheme.trialDanger
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

  @override
  Widget build(BuildContext context)
  {
    final List<SchoolEnrollmentRowData> rows = ctx.form.schoolRows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The rows scroll, the button that adds one does not: it is pressed
        // after writing the last row.
        CardScrollArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty)
                const PersonEmptyState(message: 'Nessun anno scolastico inserito.'),
              for (var i = 0; i < rows.length; i++)
                SchoolEnrollmentEditRow(
                  key: ValueKey(rows[i]),
                  row: rows[i],
                  allSchools: ctx.form.allSchools,
                  allPrograms: ctx.form.allPrograms,
                  errors: {
                    'year': ctx.errors['schoolYear_$i'],
                    'school': ctx.errors['school_$i'],
                    'program': ctx.errors['program_$i'],
                    'grade': ctx.errors['grade_$i'],
                  },
                  onChanged: ()
                  {
                    ctx.errors.remove('schoolYear_$i');
                    ctx.errors.remove('school_$i');
                    ctx.errors.remove('program_$i');
                    ctx.errors.remove('grade_$i');
                    ctx.onChanged();
                  },
                  onRemove: ()
                  {
                    rows.removeAt(i).dispose();
                    ctx.onChanged();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppAddRowButton(
          label: 'AGGIUNGI ANNO',
          onTap: ()
          {
            // Rows are added going back in time, so the year before the oldest
            // one present is the one offered.
            final int oldest = rows.isEmpty
                ? currentSchoolYearStart() + 1
                : rows
                    .map((row) => int.tryParse(row.yearCtrl.text.trim()) ?? currentSchoolYearStart())
                    .reduce((a, b) => a < b ? a : b);

            rows.add(SchoolEnrollmentRowData.empty(year: (oldest - 1).toString()));
            ctx.onChanged();
          },
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
        AppTextField(
          controller: ctx.form.ibanCtrl,
          label: 'IBAN',
          hintText: 'Es. IT00A...',
          errorText: ctx.errors['iban'],
          onChanged: (_) => ctx.clearError('iban'),
        ),
        const SizedBox(height: 20),
        PersonChipGroupField(
          label: 'Collaborazione',
          options: forced
              ? const ['Non pagato']
              : const ['Volontario', 'Retribuito', 'FSL (Ex PCT0)'],
          value: ctx.form.collaborationTypeValue,
          enabled: !forced,
          note: forced
              ? 'Presidente, vicepresidente e tesoriere non possono essere retribuiti.'
              : null,
          errorText: ctx.errors['tipoCollaborazione'],
          onChanged: (value)
          {
            ctx.form.collaborationTypeValue = value;
            ctx.clearError('tipoCollaborazione');
          },
        ),
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
          label: 'Contatto emergenza',
          hintText: 'Nome e cognome',
          errorText: ctx.errors['contattoEmergenzaNome'],
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => ctx.clearError('contattoEmergenzaNome'),
        ),
        AppTextField(
          controller: ctx.form.emergencyContactPhoneCtrl,
          label: 'Telefono emergenza',
          hintText: 'Es. 3331234567',
          errorText: ctx.errors['contattoEmergenzaTelefono'],
          keyboardType: TextInputType.phone,
          onChanged: (_) => ctx.clearError('contattoEmergenzaTelefono'),
        ),
        AppTextField(
          controller: ctx.form.allergiesCtrl,
          label: 'Allergie / intolleranze',
          hintText: 'Es. Polline, lattosio',
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.onChanged(),
        ),
        AppTextField(
          controller: ctx.form.medicationsCtrl,
          label: 'Farmaci',
          hintText: 'Es. Ventolin',
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => ctx.onChanged(),
        ),
      ],
    );
  }
}
