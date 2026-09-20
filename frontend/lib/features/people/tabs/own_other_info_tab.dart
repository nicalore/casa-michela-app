import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_cards.dart';
import '../widgets/person_detail_widgets.dart';

const double _cardsWidth = 1200;

const double _dialogWidth = 560;

Set<String> _rolesOf(PersonItem person)
{
  return person.roles.map((role) => role.toUpperCase()).toSet();
}

List<PersonDetailCard> ownOtherCards(PersonItem person)
{
  final Set<String> roles = _rolesOf(person);
  final bool isStaff = roles.contains('DOCENTE') || roles.contains('AMMINISTRATORE');
  final PersonDetailCard? payments = paymentsCard(person);

  return [
    if (roles.contains('STUDENTE')) ...[
      ...pupilDetailCards(person),
      if (!person.isAdult) minorSafetyCard(person),
    ],
    if (isStaff && payments != null) payments,
    if (roles.contains('AMMINISTRATORE')) adminDetailsCard(person),
    if (roles.contains('DOCENTE')) teacherDetailsCard(person, forOwner: true),
  ];
}

class OwnOtherInfoTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Rendered beside the edit button, inside the scroll.
  final Widget? footer;

  const OwnOtherInfoTab({
    super.key,
    required this.person,
    required this.onUpdate,
    this.footer,
  });

  void _editEducation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'OwnEducationEdit',
      builder: (context) => _EditEducationDialog(person: person, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<PersonDetailCard> cards = ownOtherCards(person);
    final bool isTeacher = _rolesOf(person).contains('DOCENTE');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: kPersonCardGap),
                cards[i],
              ],
              if (isTeacher || footer != null) ...[
                const SizedBox(height: 48),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      if (isTeacher)
                        AppGradientButton(
                          label: 'MODIFICA STUDI',
                          icon: Icons.edit_rounded,
                          onPressed: () => _editEducation(context),
                        ),
                      ?footer,
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _EditEducationDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _EditEducationDialog({required this.person, required this.onUpdate});

  @override
  State<_EditEducationDialog> createState() => _EditEducationDialogState();
}

class _EditEducationDialogState extends State<_EditEducationDialog>
{
  late final TextEditingController _school;
  late final TextEditingController _university;

  bool _isSaving = false;

  // Not editable here; the server rejects university education for a high-school student.
  bool get _atSchool => widget.person.isHighSchoolStudent ?? false;

  @override
  void initState()
  {
    super.initState();

    _school = TextEditingController(text: widget.person.schoolEducation ?? '');
    _university = TextEditingController(text: widget.person.universityEducation ?? '');
  }

  @override
  void dispose()
  {
    _school.dispose();
    _university.dispose();

    super.dispose();
  }

  String? _cleaned(TextEditingController controller)
  {
    final String text = controller.text.trim();

    return text.isEmpty ? null : text;
  }

  Future<void> _save() async
  {
    setState(() => _isSaving = true);

    try
    {
      await ApiService().updateTeacherEducation(
        taxCode: widget.person.fiscalCode,
        isHighSchoolStudent: _atSchool,
        schoolEducation: _cleaned(_school),
        universityEducation: _atSchool ? null : _cleaned(_university),
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Studi aggiornati con successo!',
          isError: false,
        );

        Navigator.of(context).pop();
        widget.onUpdate();
      }
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
    return AppDialogStack(
      eyebrow: 'Studi',
      title: 'Modifica studi',
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _school,
                label: 'Studi scolastici',
                hintText: 'Es. Liceo scientifico',
                nothingAbove: true,
                maxLength: FieldLimits.education,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (!_atSchool)
                AppTextField(
                  controller: _university,
                  label: 'Studi universitari',
                  hintText: 'Es. Ingegneria informatica',
                  maxLength: FieldLimits.education,
                  textCapitalization: TextCapitalization.sentences,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
