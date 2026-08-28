import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/export/pdf_tab.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/association_subject_item.dart';
import '../../association/models/school_item.dart';
import '../../association/models/service_item.dart';
import '../../association/models/study_program_item.dart';
import '../models/person_item.dart';
import '../widgets/competence_picker.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../widgets/person_detail_widgets.dart';
import 'person_edit_cards.dart';
import 'person_edit_enrollment_request.dart';
import 'person_edit_form.dart';
import 'person_edit_pages.dart';
import 'person_edit_people_card.dart';
import 'person_edit_report_dialog.dart';
import 'person_edit_validation.dart';
import 'widgets/person_edit_guide.dart';

// Save is always available; validation runs over everything and jumps to the
// first step that complains.

class PersonEditDialog extends StatefulWidget
{
  // Null when creating a new person.
  final PersonItem? person;

  final PersonEditPurpose purpose;

  final ResidenceOffer? offeredResidence;

  const PersonEditDialog({super.key, required PersonItem this.person})
      : purpose = PersonEditPurpose.edit,
        offeredResidence = null;

  const PersonEditDialog.create({super.key})
      : person = null,
        purpose = PersonEditPurpose.create,
        offeredResidence = null;

  // Hands back the payload instead of saving: the opener sends it along with
  // the person it will be tied to.
  const PersonEditDialog.createParent({super.key, this.offeredResidence})
      : person = null,
        purpose = PersonEditPurpose.createParent;

  const PersonEditDialog.createMinor({super.key, this.offeredResidence})
      : person = null,
        purpose = PersonEditPurpose.createMinor;

  bool get isCreation => person == null;

  bool get handsBackPayload =>
      purpose == PersonEditPurpose.createParent ||
      purpose == PersonEditPurpose.createMinor;

  @override
  State<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<PersonEditDialog>
{
  // 1100 matches the school-years dialog; a year's row needs all of it.
  static const double _contentMaxWidth = 1100;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  // Wide enough that 'GENERA DOCUMENTI DI ISCRIZIONE' keeps to one line, both
  // on its own and beside the button that creates the person.
  static const double _enrollmentFooterWidth = 820;

  late final PersonEditForm _form;

  final Map<String, String> _errors = {};

  PersonEditStepId _stepId = PersonEditStepId.type;
  PersonEditCardId? _cardId;
  bool _movingForward = true;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGenerating = false;

  // Creating the person is only offered once the form has been printed at
  // least once; regenerating afterwards keeps it on screen.
  bool _formGenerated = false;

  @override
  void initState()
  {
    super.initState();
    _form = widget.isCreation
        ? PersonEditForm.blank(
            roles: widget.purpose == PersonEditPurpose.createParent
                ? const {'GENITORE'}
                : const {},
            // Parents and minors created on the fly skip the first step, so
            // their answer is already given.
            involvement: widget.handsBackPayload ? 0 : -1,
          )
        : PersonEditForm.fromPerson(widget.person!);
    _loadCatalogues();
  }

  @override
  void dispose()
  {
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogues() async
  {
    try
    {
      final results = await Future.wait([
        ApiService().getStudyPrograms(),
        ApiService().getSchools(),
        ApiService().getAssociationSubjects(),
        ApiService().getPeople(),
        ApiService().getServices(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _form.applyCatalogues(
          programs: results[0] as List<StudyProgramItem>,
          schools: results[1] as List<SchoolItem>,
          subjects: results[2] as List<AssociationSubjectItem>,
          people: results[3] as List<PersonItem>,
          services: results[4] as List<ServiceItem>,
        );
        _isLoading = false;
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _isLoading = false);
      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
    }
  }

  List<PersonEditStep> get _steps => buildEditSteps(_form, purpose: widget.purpose);

  // Found by name: ticking a role can slip a step into the middle, invalidating
  // any kept index.
  PersonEditStep get _step
  {
    final List<PersonEditStep> steps = _steps;

    return steps.firstWhere((step) => step.id == _stepId, orElse: () => steps.first);
  }

  int get _stepIndex => indexOfStep(_steps, _step.id);

  PersonEditCard get _card
  {
    final List<PersonEditCard> cards = _step.cards;

    return cards.firstWhere((card) => card.id == _cardId, orElse: () => cards.first);
  }

  int get _cardIndex => _step.cards.indexWhere((card) => card.id == _card.id);

  bool _stepIsSound()
  {
    final PersonEditValidation validation = validatePersonEdit(_form);
    final List<PersonEditIssue> mine = validation.issuesOn(_step);

    if (mine.isEmpty)
    {
      return true;
    }

    setState(()
    {
      _errors
        ..clear()
        ..addEntries(mine.map((issue) => MapEntry(issue.field, issue.message)));

      // Onto the card that complains, which may not be the visible one.
      _cardId = mine.first.card;
    });

    CustomSnackBar.show(
      context: context,
      // The validation message describes the first problem overall; use it only
      // when that problem is this step's.
      message: validation.firstCard == mine.first.card && validation.message != null
          ? validation.message!
          : 'Ci sono errori nei dati inseriti. Correggi i campi.',
      isError: true,
    );

    return false;
  }

  void _goForward(int index)
  {
    if (!_stepIsSound())
    {
      return;
    }

    _goToStep(index + 1);
  }

  void _goToStep(int index)
  {
    final List<PersonEditStep> steps = _steps;
    final int clamped = index.clamp(0, steps.length - 1);

    setState(()
    {
      _movingForward = clamped >= _stepIndex;
      _stepId = steps[clamped].id;
      _cardId = steps[clamped].cards.first.id;
    });
  }

  void _goToCard(int index)
  {
    final List<PersonEditCard> cards = _step.cards;

    setState(() => _cardId = cards[index.clamp(0, cards.length - 1)].id);
  }

  void _jumpTo(PersonEditCardId cardId)
  {
    final List<PersonEditStep> steps = _steps;

    for (var i = 0; i < steps.length; i++)
    {
      if (steps[i].cards.any((card) => card.id == cardId))
      {
        setState(()
        {
          _movingForward = i >= _stepIndex;
          _stepId = steps[i].id;
          _cardId = cardId;
        });

        return;
      }
    }
  }

  String get _personName
  {
    final PersonItem? person = widget.person;

    if (person != null)
    {
      return '${person.firstName} ${person.lastName}';
    }

    final String name =
        '${_form.firstNameCtrl.text.trim()} ${_form.lastNameCtrl.text.trim()}'.trim();

    return name.isEmpty ? 'questa persona' : name;
  }

  // Both footer actions start here, so "the same checks" is literal and not a
  // promise: same validation, same jump, same message.
  bool _formIsSound()
  {
    final PersonEditValidation validation = validatePersonEdit(_form);

    setState(()
    {
      _errors
        ..clear()
        ..addAll(validation.errors);
    });

    if (validation.isValid)
    {
      return true;
    }

    final PersonEditCardId? card = validation.firstCard;

    if (card != null)
    {
      _jumpTo(card);
    }

    CustomSnackBar.show(
      context: context,
      message: validation.message ?? 'Ci sono errori nei dati inseriti. Correggi i campi.',
      isError: true,
    );

    return false;
  }

  Future<void> _generateEnrollmentForm() async
  {
    if (_isGenerating || !_formIsSound())
    {
      return;
    }

    final List<EnrollmentForm> forms = buildEnrollmentForms(_form);
    final String day = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Every tab is asked for inside the click and before the first await: one
    // opened after that is a popup, and the browser kills it.
    final List<PdfTab?> tabs = [
      for (final EnrollmentForm form in forms)
        openPdfTab(title: 'Modulo di iscrizione · ${form.personName}'),
    ];

    setState(() => _isGenerating = true);

    var downloaded = false;

    try
    {
      for (final (int index, EnrollmentForm form) in forms.indexed)
      {
        final Uint8List bytes =
            await ApiService().generateEnrollmentForm(form.request);
        final String fileName =
            'Modulo di iscrizione ${form.personName} $day.pdf';
        final PdfTab? tab = tabs[index];

        if (tab != null)
        {
          tab.present(bytes, fileName: fileName);
        }
        else
        {
          downloaded = downloadPdf(bytes, fileName: fileName) || downloaded;
        }
      }

      if (!mounted)
      {
        return;
      }

      if (downloaded)
      {
        CustomSnackBar.show(
          context: context,
          message: forms.length == 1
              ? 'Il browser ha bloccato la scheda: il modulo è stato scaricato.'
              : 'Il browser ha bloccato una scheda: il modulo è stato scaricato.',
          isError: false,
        );
      }

      setState(() => _formGenerated = true);
    }
    catch (e)
    {
      for (final PdfTab? tab in tabs)
      {
        tab?.fail('Non è stato possibile generare il modulo.');
      }

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _submit() async
  {
    if (!_formIsSound())
    {
      return;
    }

    if (widget.handsBackPayload)
    {
      Navigator.of(context).pop({
        'person': _newPersonItem(),
        'payload': _form.buildCreatePayload(),
        'imageBytes': _form.fotoProfilo,
      });

      return;
    }

    setState(() => _isSaving = true);

    try
    {
      if (widget.isCreation)
      {
        // Pending people first: this person will be tied to them.
        for (final pending in _form.pendingPeople)
        {
          await ApiService().createPersonFromWizard(
            pending['payload'] as Map<String, dynamic>,
            imageBytes: pending['imageBytes'] as Uint8List?,
          );
        }

        await ApiService().createPersonFromWizard(
          _form.buildCreatePayload(),
          imageBytes: _form.fotoProfilo,
        );

        if (!mounted)
        {
          return;
        }

        CustomSnackBar.show(
          context: context,
          message: 'Persona creata con successo!',
          isError: false,
        );
        Navigator.of(context).pop('');

        return;
      }

      final String newFiscalCode = await ApiService().updatePerson(
        widget.person!.fiscalCode,
        _form.buildPayload(),
        imageBytes: _form.fotoProfilo,
      );

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(
        context: context,
        message: 'Anagrafica aggiornata con successo!',
        isError: false,
      );
      Navigator.of(context).pop(newFiscalCode);
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

  // Enough to show the new person selected until the server knows about them.
  PersonItem _newPersonItem()
  {
    final List<String> roles = (_form.buildCreatePayload()['roles'] as List)
        .cast<String>()
        .map((role) => role.substring(0, 1) + role.substring(1).toLowerCase())
        .toList();

    return PersonItem(
      fiscalCode: _form.cfCtrl.text.trim().toUpperCase(),
      firstName: _form.firstNameCtrl.text.trim(),
      lastName: _form.lastNameCtrl.text.trim(),
      roles: roles,
      createdAt: DateTime.now(),
      city: _form.residenceCityCtrl.text.trim(),
      birthDate: PersonEditForm.isValidDate(_form.birthDateCtrl.text.trim())
          ? DateFormat('dd/MM/yyyy').parse(_form.birthDateCtrl.text.trim())
          : null,
    );
  }

  Future<void> _confirmDiscard() async
  {
    final bool? leave = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'DiscardEdit',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Interrompi inserimento',
        title: 'Confermi?',
        showClose: false,
        maxWidth: 520,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'RIPRENDI',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: () => Navigator.of(confirmContext).pop(false),
          ),
          primary: AppGradientButton(
            label: 'ESCI SENZA SALVARE',
            icon: Icons.logout_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            horizontalPadding: 16,
            onPressed: () => Navigator.of(confirmContext).pop(true),
          ),
        ),
        children: const [
          AppDialogPill(
            child: Text('Le modifiche non salvate andranno perse.'),
          ),
        ],
      ),
    );

    if (leave == true && mounted)
    {
      Navigator.of(context).pop();
    }
  }

  Future<Map<String, dynamic>?> _createParent() async
  {
    final Map<String, dynamic>? created = await showBlurredDialog<Map<String, dynamic>>(
      context: context,
      barrierLabel: 'ParentCreation',
      // The parents step is only put to a minor, whose residence the parent
      // almost always shares.
      builder: (context) => PersonEditDialog.createParent(
        offeredResidence: _form.residenceOffer(label: 'Stessa residenza del minore'),
      ),
    );

    if (created != null)
    {
      _form.pendingPeople.add(created);
    }

    return created;
  }

  Future<Map<String, dynamic>?> _createMinor() async
  {
    final Map<String, dynamic>? created = await showBlurredDialog<Map<String, dynamic>>(
      context: context,
      barrierLabel: 'MinorCreation',
      builder: (context) => PersonEditDialog.createMinor(
        offeredResidence: _form.residenceOffer(label: 'Stessa residenza del genitore'),
      ),
    );

    if (created != null)
    {
      _form.pendingPeople.add(created);
    }

    return created;
  }

  PersonEditCardContext get _ctx => PersonEditCardContext(
        form: _form,
        errors: _errors,
        onChanged: () => setState(() {}),
        offeredResidence: widget.offeredResidence,
      );

  Widget _buildFooter()
  {
    // Nobody being created is joining — a parent who declined membership, tied
    // to a minor already on file — so there is no form to print and the wizard
    // keeps the single button it always had.
    if (widget.purpose != PersonEditPurpose.create || !needsEnrollmentForms(_form))
    {
      return AppDialogFooter.single(_submitButton());
    }

    if (!_formGenerated)
    {
      // Same width it will keep once the create button joins it, so nothing
      // resizes under the pointer.
      return AppDialogFooter.single(_generateButton(), maxWidth: _enrollmentFooterWidth);
    }

    return AppDialogFooter(
      secondary: _generateButton(),
      primary: _submitButton(),
      maxWidth: _enrollmentFooterWidth,
    );
  }

  AppGradientButton _submitButton()
  {
    return AppGradientButton(
      label: switch (widget.purpose)
      {
        PersonEditPurpose.edit => 'SALVA MODIFICHE',
        PersonEditPurpose.create => 'CREA PERSONA',
        PersonEditPurpose.createParent => 'AGGIUNGI GENITORE',
        PersonEditPurpose.createMinor => 'AGGIUNGI MINORE',
      },
      icon: Icons.check_rounded,
      busy: _isSaving,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _submit,
    );
  }

  AppGradientButton _generateButton()
  {
    return AppGradientButton(
      label: 'GENERA DOCUMENTI DI ISCRIZIONE',
      icon: Icons.picture_as_pdf_outlined,
      busy: _isGenerating,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _generateEnrollmentForm,
    );
  }

  Widget _buildCard(PersonEditCardId id)
  {
    return switch (id)
    {
      PersonEditCardId.involvement => InvolvementCard(ctx: _ctx),
      PersonEditCardId.roleChoice => RolesCard(
          ctx: _ctx,
          // Parent, psychologist and administrator require being of age.
          only: widget.purpose == PersonEditPurpose.createMinor
              ? const {'DOCENTE', 'STUDENTE', 'CORSISTA'}
              : const {},
        ),
      PersonEditCardId.associationChoice => AssociationCard(ctx: _ctx),
      PersonEditCardId.identity => widget.isCreation
          ? IdentityEditCard(ctx: _ctx)
          : IdentityCard(
              ctx: _ctx,
              onReportError: () => showAnagraphicErrorReportDialog(context, widget.person!),
            ),
      PersonEditCardId.birthData => widget.isCreation
          ? BirthDataEditCard(ctx: _ctx)
          : BirthDataCard(
              ctx: _ctx,
              onReportError: () => showAnagraphicErrorReportDialog(context, widget.person!),
            ),
      PersonEditCardId.consents => ConsentsCard(ctx: _ctx),
      PersonEditCardId.psychologicalSupport => PsychologicalSupportCard(ctx: _ctx),
      PersonEditCardId.residence => ResidenceCard(ctx: _ctx),
      PersonEditCardId.contacts => ContactsCard(ctx: _ctx),
      PersonEditCardId.memberships => MembershipsCard(ctx: _ctx),
      PersonEditCardId.payment => PaymentCard(ctx: _ctx),
      PersonEditCardId.admin => AdminCard(ctx: _ctx),
      PersonEditCardId.teacher => TeacherCard(ctx: _ctx),
      PersonEditCardId.courseParticipant => CourseParticipantCard(ctx: _ctx),
      PersonEditCardId.student => StudentCard(ctx: _ctx),
      PersonEditCardId.schoolEnrollments => SchoolEnrollmentsCard(ctx: _ctx),
      PersonEditCardId.staff => StaffCard(ctx: _ctx),
      PersonEditCardId.minorSafety => MinorSafetyCard(ctx: _ctx),
      PersonEditCardId.parents => PersonEditPeopleCard(
          people: _form.allAdults,
          selected: _form.selectedParents,
          personName: _personName,
          pickingParents: true,
          searchHint: 'Cerca genitore...',
          emptyMessage: 'Nessun genitore trovato.',
          onChanged: () => setState(() {}),
          createLabel: 'NUOVO GENITORE',
          onCreateMissing: widget.isCreation ? _createParent : null,
        ),
      PersonEditCardId.minors => PersonEditPeopleCard(
          people: _form.allMinors,
          selected: _form.selectedMinors,
          personName: _personName,
          pickingParents: false,
          searchHint: 'Cerca minore...',
          emptyMessage: 'Nessun minore trovato.',
          onChanged: () => setState(() {}),
          createLabel: 'NUOVO MINORE',
          onCreateMissing: widget.isCreation ? _createMinor : null,
        ),
      PersonEditCardId.subjects => CompetenceCatalogue(
          subjects: _form.allSubjects,
          programsBySubjectId: _form.programsBySubjectId,
          isSelected: _form.subjectToggles,
          programsBySubject: _form.selectedProgramsForSubject,
          services: _form.allServices,
          selectedServices: _form.selectedServices,
          isLoading: _isLoading,
          onChanged: () => setState(() {}),
          builder: (context, filters, list) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filters,
              const SizedBox(height: 24),
              CardScrollArea(child: list),
            ],
          ),
        ),
    };
  }

  Widget _buildStepQuestion()
  {
    final PersonEditStep step = _step;

    return AppDialogPiece(
      index: 1,
      named: false,
      child: AppDialogPill(
        expand: true,
        child: PersonEditGuide(question: step.question, hint: step.hint),
      ),
    );
  }

  Widget _buildStepCard()
  {
    final PersonEditStep step = _step;
    final PersonEditCard card = _card;

    return AppDialogPiece(
      index: 2,
      named: false,
      child: AppDialogPill(
        expand: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step.cards.length > 1)
              AppSegmentedTabs(
                labels: [
                  for (final card in step.cards) card.label ?? '',
                ],
                selectedIndex: _cardIndex,
                onSelected: _goToCard,
              ),
            _buildCard(card.id),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<PersonEditStep> steps = _steps;
    final int index = _stepIndex;

    return AppDialogStack(
      eyebrow: 'Passo ${index + 1} di ${steps.length}',
      title: switch (widget.purpose)
      {
        PersonEditPurpose.edit => 'Modifica anagrafica',
        PersonEditPurpose.create => 'Nuova persona',
        PersonEditPurpose.createParent => 'Nuovo genitore',
        PersonEditPurpose.createMinor => 'Nuovo minore',
      },
      onClose: _confirmDiscard,
      maxWidth: _stackMaxWidth,
      footer: _buildFooter(),
      children: [
        AppCarouselFrame(
          index: index,
          movingForward: _movingForward,
          maxContentWidth: _contentMaxWidth,
          canGoBack: index > 0,
          canGoForward: index < steps.length - 1 && stepIsAnswered(_step.id, _form),
          onBack: () => _goToStep(index - 1),
          onForward: () => _goForward(index),
          header: _buildStepQuestion(),
          child: _buildStepCard(),
        ),
      ],
    );
  }
}
