import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../edit/widgets/person_edit_guide.dart';
import '../models/parent_item.dart';
import '../models/person_item.dart';
import 'person_detail_widgets.dart';

const double _confirmWidth = 520;
const double _wizardContentWidth = 600;
const double _choiceGap = 18;
const double _chipGap = 10;

const String _creationNotice =
    "Verrà creato l'account e verrà inviata una email all'indirizzo inserito in anagrafica "
    'con le istruzioni per accedere.';

const String _creationsNotice =
    'Verranno creati gli account e verranno inviate le email agli indirizzi inseriti '
    'in anagrafica con le istruzioni per accedere.';

const String _parentsQuestion = "A quali genitori vuoi creare l'account?";

const String _accountCreated = 'Account creato!';
const String _accountsCreated = 'Account creati!';

class CreateAccountRequest
{
  // Null unless parents answer for the pupil.
  final bool? autonomousBookings;

  final List<String> parentTaxCodes;

  const CreateAccountRequest({required this.autonomousBookings, required this.parentTaxCodes});
}

// Mirrors RoleService.is_answered_for on the server.
bool isAnsweredFor(PersonItem person)
{
  return person.roles.any((role) => role.toUpperCase() == 'STUDENTE') &&
      (person.parents?.isNotEmpty ?? false);
}

// A teacher's parents never show up: shownRoles drops their GENITORE.
bool mayOpenAccount(PersonItem person)
{
  return !person.hasAccount &&
      !person.isMembershipRevoked &&
      !person.accessLapsed &&
      person.shownRoles.any((role) => role.toUpperCase() != 'ASSOCIATO');
}

// True once the account exists.
Future<bool> runAccountCreation(
  BuildContext context,
  PersonItem person, {
  ValueChanged<bool>? onBusy,
}) async
{
  final CreateAccountRequest? request = await showCreateAccountDialog(context, person);

  if (request == null || !context.mounted)
  {
    return false;
  }

  onBusy?.call(true);

  try
  {
    await ApiService().createAccount(
      person.fiscalCode,
      autonomousBookings: request.autonomousBookings ?? false,
      parentTaxCodes: request.parentTaxCodes,
    );

    if (context.mounted)
    {
      CustomSnackBar.show(
        context: context,
        message: request.parentTaxCodes.isEmpty ? _accountCreated : _accountsCreated,
        isError: false,
      );
    }

    return true;
  }
  catch (e)
  {
    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
    }

    return false;
  }
  finally
  {
    onBusy?.call(false);
  }
}

Future<CreateAccountRequest?> showCreateAccountDialog(BuildContext context, PersonItem person)
{
  return showBlurredDialog<CreateAccountRequest>(
    context: context,
    barrierLabel: 'CreateAccount',
    builder: (dialogContext) => isAnsweredFor(person)
        ? _PupilAccountWizard(person: person)
        : const _CreateAccountConfirmation(),
  );
}

TextStyle get _textStyle => GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppTheme.trialInk,
    );

String _fullName(ParentItem parent) => '${parent.firstName} ${parent.lastName}';

class _CreateAccountConfirmation extends StatelessWidget
{
  const _CreateAccountConfirmation();

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Account',
      title: 'Confermi?',
      showClose: false,
      maxWidth: _confirmWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ANNULLA',
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: () => Navigator.of(context).pop(),
        ),
        primary: AppGradientButton(
          label: 'CREA ACCOUNT',
          icon: Icons.person_add_alt_1_rounded,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: () => Navigator.of(context).pop(
            const CreateAccountRequest(autonomousBookings: null, parentTaxCodes: []),
          ),
        ),
      ),
      children: [
        AppDialogPill(expand: true, child: Text(_creationNotice, style: _textStyle)),
      ],
    );
  }
}

class _PupilAccountWizard extends StatefulWidget
{
  final PersonItem person;

  const _PupilAccountWizard({required this.person});

  @override
  State<_PupilAccountWizard> createState() => _PupilAccountWizardState();
}

class _PupilAccountWizardState extends State<_PupilAccountWizard>
{
  int _step = 0;
  bool _movingForward = true;

  bool _autonomousBookings = false;

  late final List<ParentItem> _parents = [
    for (final parent in widget.person.parents ?? const <ParentItem>[])
      if (!parent.hasAccount) parent,
  ];

  late final List<ParentItem> _parentsWithAccount = [
    for (final parent in widget.person.parents ?? const <ParentItem>[])
      if (parent.hasAccount) parent,
  ];

  // Parents' accounts are optional; the step shows only while one may still be opened.
  int get _stepCount => _parents.isEmpty ? 2 : 3;

  final Set<String> _chosenParents = {};

  List<String> get _parentTaxCodes => [
        for (final parent in _parents)
          if (_chosenParents.contains(parent.fiscalCode)) parent.fiscalCode,
      ];

  void _choose(ParentItem parent, bool chosen)
  {
    if (chosen)
    {
      _chosenParents.add(parent.fiscalCode);
    }
    else
    {
      _chosenParents.remove(parent.fiscalCode);
    }
  }

  void _goToStep(int step)
  {
    setState(()
    {
      _movingForward = step > _step;
      _step = step;
    });
  }

  void _submit()
  {
    Navigator.of(context).pop(
      CreateAccountRequest(
        autonomousBookings: _autonomousBookings,
        parentTaxCodes: _parentTaxCodes,
      ),
    );
  }

  Widget _buildQuestion(String question, Widget control, {String? hint})
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PersonEditGuide(question: question, hint: hint),
        const SizedBox(height: _choiceGap),
        Center(child: control),
      ],
    );
  }

  Widget _buildAutonomousBookings()
  {
    return _buildQuestion(
      'Vuoi permettere a ${widget.person.firstName} di prenotare autonomamente le lezioni?',
      AppSegmentedSwitch(
        value: _autonomousBookings,
        hugContent: true,
        onChanged: (value) => setState(() => _autonomousBookings = value),
      ),
    );
  }

  // At most two parents, each one defaulting to no.
  Widget _buildParents()
  {
    if (_parents.length == 1)
    {
      final ParentItem parent = _parents.single;

      return _buildQuestion(
        "Vuoi creare l'account anche per il genitore ${_fullName(parent)}?",
        AppSegmentedSwitch(
          value: _chosenParents.contains(parent.fiscalCode),
          hugContent: true,
          onChanged: (value) => setState(() => _choose(parent, value)),
        ),
        hint: _parentsWithAccount.isEmpty
            ? null
            : 'Il genitore ${_fullName(_parentsWithAccount.first)} ha già un account.',
      );
    }

    return _buildQuestion(
      _parentsQuestion,
      Wrap(
        alignment: WrapAlignment.center,
        spacing: _chipGap,
        runSpacing: _chipGap,
        children: [
          for (final parent in _parents)
            AppSelectableChip(
              label: _fullName(parent),
              selected: _chosenParents.contains(parent.fiscalCode),
              onSelected: (selected) => setState(() => _choose(parent, selected)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotice()
  {
    return Text(
      _parentTaxCodes.isEmpty ? _creationNotice : _creationsNotice,
      style: _textStyle,
    );
  }

  Widget _buildStep()
  {
    if (_step == 0)
    {
      return _buildAutonomousBookings();
    }

    return _step < _stepCount - 1 ? _buildParents() : _buildNotice();
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Passo ${_step + 1} di $_stepCount',
      title: 'Nuovo account',
      maxWidth: _wizardContentWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap),
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'CREA ACCOUNT',
          icon: Icons.person_add_alt_1_rounded,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [
        AppCarouselFrame(
          index: _step,
          movingForward: _movingForward,
          maxContentWidth: _wizardContentWidth,
          canGoBack: _step > 0,
          canGoForward: _step < _stepCount - 1,
          onBack: () => _goToStep(_step - 1),
          onForward: () => _goToStep(_step + 1),
          child: AppDialogPill(expand: true, child: _buildStep()),
        ),
      ],
    );
  }
}
