import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/models/person_option_item.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../lessons/widgets/subject_request_tile.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';

const double _cardsWidth = 1600;

const double _cardWidth = 360;
const double _cardGap = 16;

// The compact card badge's size, so the photo sits where a badge would.
const double _avatarSize = 64;

const String _teacherRoleLabel = 'Docente';

void showEditNotPreferredTeachersDialog(
  BuildContext context, {
  required PersonItem person,
  required VoidCallback onUpdate,
})
{
  showBlurredDialog(
    context: context,
    barrierLabel: 'EditNotPreferredTeachers',
    builder: (context) => _EditNotPreferredTeachersDialog(person: person, onUpdate: onUpdate),
  );
}

// The teachers a pupil would rather not have: a standing opinion, held on the
// pupil and applied to every booking, unlike the teachers asked for per lesson.
class PersonNotPreferredTeachersTab extends StatelessWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const PersonNotPreferredTeachersTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  // Photo and name only: there is nothing more to say about the teacher here.
  Widget _buildCard(PersonOptionItem teacher)
  {
    return SizedBox(
      width: _cardWidth,
      child: AppCard(
        title: teacher.fullName,
        compact: true,
        selectable: false,
        leading: PersonAvatar(person: teacher, size: _avatarSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final teachers = person.notPreferredTeachers ?? const <PersonOptionItem>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              const PersonSectionTitle('Mi sono trovato meno con...'),
              const SizedBox(height: kPersonTitleGap),
              if (teachers.isEmpty)
                const PersonEmptyState(message: 'Nessun docente indicato.')
              else
                Wrap(
                  spacing: _cardGap,
                  runSpacing: _cardGap,
                  children: [for (final teacher in teachers) _buildCard(teacher)],
                ),
              const SizedBox(height: kPersonSectionGap),
              Center(
                child: AppGradientButton(
                  label: 'MODIFICA DOCENTI',
                  icon: Icons.edit_rounded,
                  onPressed: () => showEditNotPreferredTeachersDialog(
                    context,
                    person: person,
                    onUpdate: onUpdate,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EditNotPreferredTeachersDialog extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  const _EditNotPreferredTeachersDialog({required this.person, required this.onUpdate});

  @override
  State<_EditNotPreferredTeachersDialog> createState() => _EditNotPreferredTeachersDialogState();
}

class _EditNotPreferredTeachersDialogState extends State<_EditNotPreferredTeachersDialog>
{
  late final List<String> _chosen = [...widget.person.notPreferredTeacherTaxCodes];

  List<PersonItem> _teachers = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState()
  {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async
  {
    try
    {
      final people = await ApiService().getPeople();

      if (mounted)
      {
        setState(()
        {
          _teachers = activeCollaborators(
            people.where((person) => person.roles.contains(_teacherRoleLabel)).toList(),
          );
          _isLoading = false;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  Future<void> _submit() async
  {
    setState(() => _isSubmitting = true);

    try
    {
      await ApiService().updateNotPreferredTeachers(
        widget.person.fiscalCode,
        _chosen,
        widget.person.studentUpdatedAt,
      );

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Docenti aggiornati con successo!',
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildPicker()
  {
    if (_isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    return TeacherPicker(
      icon: Icons.thumb_down_outlined,
      chosen: _chosen,
      offered: _teachers,
      onChanged: () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'DOCENTI',
      title: 'Mi sono trovato meno con...',
      maxWidth: 720,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSubmitting || _isLoading,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [
        AppDialogPill(expand: true, child: _buildPicker()),
      ],
    );
  }
}
