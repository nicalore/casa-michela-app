import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
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
import 'person_edit_form.dart';
import 'person_edit_pages.dart';
import 'person_edit_people_card.dart';
import 'person_edit_report_dialog.dart';
import 'person_edit_validation.dart';
import 'widgets/person_edit_guide.dart';

// The dialog that edits a person's details: a stack of pills like every other
// one — the header, the step's question, and the choices below it.
//
// Two things about using it are deliberate:
// - navigation is by arrows and the save button is always there. This dialog is
//   opened to change one thing, and walking eight steps to reach the button was
//   the price of a creation flow, not of an edit.
// - validation does not block the step: it runs over everything and jumps to the
//   first step that complains.

class PersonEditDialog extends StatefulWidget
{
  // The person to edit, or null when one is being created.
  final PersonItem? person;

  final PersonEditPurpose purpose;

  // See [PersonEditDialog.createParent]. Null in dialogs no other one opened,
  // which is all the rest.
  final ResidenceOffer? offeredResidence;

  const PersonEditDialog({super.key, required PersonItem this.person})
      : purpose = PersonEditPurpose.edit,
        offeredResidence = null;

  // The same dialog in front of an empty form: the same steps, the same cards,
  // plus the ones asked only of someone joining — the identity to write, the
  // consents, the psychological support.
  const PersonEditDialog.create({super.key})
      : person = null,
        purpose = PersonEditPurpose.create,
        offeredResidence = null;

  // A parent created while registering their child, or a minor created while
  // registering their parent. They do not reach the server on their own: they
  // return what the server will have to create, and whoever opened them sends it
  // along with the rest, because it is to that person they will be tied.
  //
  // [offeredResidence] is the residence of whoever opened the dialog: parent and
  // child almost always live together, and the residence card offers it behind a
  // checkbox instead of having the same address typed twice.
  const PersonEditDialog.createParent({super.key, this.offeredResidence})
      : person = null,
        purpose = PersonEditPurpose.createParent;

  const PersonEditDialog.createMinor({super.key, this.offeredResidence})
      : person = null,
        purpose = PersonEditPurpose.createMinor;

  bool get isCreation => person == null;

  // True when the dialog does not save by itself but hands over its work.
  bool get handsBackPayload =>
      purpose == PersonEditPurpose.createParent ||
      purpose == PersonEditPurpose.createMinor;

  @override
  State<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<PersonEditDialog>
{
  // How wide the card is, and how wide the stack holding it: the card plus the
  // two arrows with the room around them.
  //
  // 1100 is the width of the dialog that edits the school years, and a year's
  // row — year, school, programme, class — needs all of it: narrower, a school's
  // name and a programme's ended up in a couple of fingers of space.
  static const double _contentMaxWidth = 1100;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  late final PersonEditForm _form;

  final Map<String, String> _errors = {};

  PersonEditStepId _stepId = PersonEditStepId.type;
  PersonEditCardId? _cardId;
  bool _movingForward = true;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState()
  {
    super.initState();
    _form = widget.isCreation
        ? PersonEditForm.blank(
            roles: widget.purpose == PersonEditPurpose.createParent
                ? const {'GENITORE'}
                : const {},
            // A parent or a minor created on the fly is not put through the
            // first step — the dialog they come from is already saying it — so
            // the answer is given: they are involved in the activities. A new
            // person starts without one and has to give it.
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

  // --------------------------------------------------------- navigation

  List<PersonEditStep> get _steps => buildEditSteps(_form, purpose: widget.purpose);

  // The current step, found by name: ticking a role slips a step into the
  // middle, and a hand-kept index would slide out from under the finger.
  PersonEditStep get _step
  {
    final List<PersonEditStep> steps = _steps;

    return steps.firstWhere((step) => step.id == _stepId, orElse: () => steps.first);
  }

  int get _stepIndex => indexOfStep(_steps, _step.id);

  // The card inside the step, also kept by name.
  PersonEditCard get _card
  {
    final List<PersonEditCard> cards = _step.cards;

    return cards.firstWhere((card) => card.id == _cardId, orElse: () => cards.first);
  }

  int get _cardIndex => _step.cards.indexWhere((card) => card.id == _card.id);

  // What is wrong on the current step, checked when the arrow is pressed.
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

      // Onto the card that complains, which inside a step may not be the one
      // being looked at.
      _cardId = mine.first.card;
    });

    CustomSnackBar.show(
      context: context,
      // The validation message speaks of the first problem it found: it holds
      // if that problem is this one's, otherwise what is known is said.
      message: validation.firstCard == mine.first.card && validation.message != null
          ? validation.message!
          : 'Ci sono errori nei dati inseriti. Correggi i campi.',
      isError: true,
    );

    return false;
  }

  // The step forward: taken if what is written here holds up.
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

  // Goes where the error is: the step holding that card, and the card inside
  // it.
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

  // What the person being edited is called, or the one being created as it is
  // typed: needed by the pickup question, which names parent and child.
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

  // --------------------------------------------------------------- saving

  Future<void> _submit() async
  {
    final PersonEditValidation validation = validatePersonEdit(_form);

    setState(()
    {
      _errors
        ..clear()
        ..addAll(validation.errors);
    });

    if (!validation.isValid)
    {
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

      return;
    }

    // A dialog that hands over its work calls no server: it returns what the
    // server will have to create, and whoever opened it sends that at the right
    // moment.
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
        // The people created inside here first — a parent, a minor — because
        // it is to them that this one will be tied.
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

  // The person just described, as their creator sees them: enough to show them
  // selected in the list until the server knows about them.
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
            // Three words and an icon in half of a 520-wide foot: with the
            // usual air on the sides they miss one line by a couple of pixels
            // and the button answers in two.
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

  // ---------------------------------------------- persone create per strada

  // A parent or a minor not yet on the system is created from here. It does not
  // go out at once: it waits in the queue and reaches the server before the
  // person being created, which is the one it will be tied to.
  Future<Map<String, dynamic>?> _createParent() async
  {
    final Map<String, dynamic>? created = await showBlurredDialog<Map<String, dynamic>>(
      context: context,
      barrierLabel: 'ParentCreation',
      // The parents step is only put to a minor, so whoever opens this dialog
      // is the minor: their residence is the one the parent almost always
      // shares.
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
      // And here the other way round: the minors step is only put to a parent.
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

  // ------------------------------------------------------------ le schede

  PersonEditCardContext get _ctx => PersonEditCardContext(
        form: _form,
        errors: _errors,
        onChanged: () => setState(() {}),
        offeredResidence: widget.offeredResidence,
      );

  Widget _buildCard(PersonEditCardId id)
  {
    return switch (id)
    {
      PersonEditCardId.involvement => InvolvementCard(ctx: _ctx),
      PersonEditCardId.roleChoice => RolesCard(
          ctx: _ctx,
          // Parent, psychologist and administrator require being of age: a
          // minor is not even offered them.
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

  // The step's question. It goes to the frame on its own rather than with the
  // card: it travels with it, but the arrows turn the card and centre on it.
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
            // The step's cards are picked by name. They used to be a second
            // carousel: two more arrows looking like the step ones, where
            // reaching the contacts meant pressing forward twice instead of
            // going there.
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
      footer: AppDialogFooter.single(
        AppGradientButton(
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
        ),
      ),
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
