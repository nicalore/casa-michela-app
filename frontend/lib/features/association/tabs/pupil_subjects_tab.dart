import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/association_subject_item.dart';
import '../models/subject_taxonomy.dart';
import '../widgets/association_subject_card.dart';

const String _intro =
    'Di seguito trovi tutte le discipline che vengono insegnate in Associazione. '
    'Se manca una disciplina che ti interessa, faccelo sapere!';

const String _introWithButton =
    'Di seguito trovi tutte le discipline che vengono insegnate in Associazione. '
    'Se manca una disciplina che ti interessa, faccelo sapere tramite il bottone qui sotto!';

// Keeps 'INVIA SEGNALAZIONE' on one line.
const double _footerWidth = 576;

class PupilSubjectsTab extends StatefulWidget
{
  // False for a pupil a parent answers for: no report button.
  final bool canReport;

  const PupilSubjectsTab({super.key, required this.canReport});

  @override
  State<PupilSubjectsTab> createState() => _PupilSubjectsTabState();
}

class _PupilSubjectsTabState extends State<PupilSubjectsTab>
{
  final ApiService _apiService = ApiService();

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<AssociationSubjectItem> _subjects = [];

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;
  String? _filterArea;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async
  {
    try
    {
      final subjects = await _apiService.getAssociationSubjects();

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _subjects = subjects;
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
      CustomSnackBar.show(context: context, message: 'Impossibile caricare i dati dal server.', isError: true);
    }
  }

  List<AssociationSubjectItem> get _filteredSubjects
  {
    final query = _searchText.toLowerCase();

    final result = _subjects.where((subject)
    {
      final matchesSearch = subject.name.toLowerCase().contains(query);
      final matchesArea = _filterArea == null || subject.area == _filterArea;

      return matchesSearch && matchesArea;
    }).toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _openReportDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MissingSubjectDialog',
      builder: (_) => const _MissingSubjectDialog(),
    );
  }

  Widget _buildIntro()
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Text(
        widget.canReport ? _introWithButton : _intro,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppTheme.trialInk,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final subjects = _filteredSubjects;

    return TabContent(
      header: [
        _buildIntro(),
        ...entityTabHeader(
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _searchText = value),
          searchHint: 'Cerca disciplina...',
          actionLabel: widget.canReport ? 'SEGNALA DISCIPLINA' : null,
          actionIcon: Icons.flag_rounded,
          actionGradient: AppTheme.dismissGradient,
          actionAccent: AppTheme.trialViolet,
          onAction: widget.canReport ? _openReportDialog : null,
          sort: _sortBy,
          onSortChanged: (value) => setState(() => _sortBy = value),
          sortCriteria: const [SortCriterion.nameAsc, SortCriterion.nameDesc],
          countLabel: subjects.length == 1
              ? '1 disciplina trovata'
              : '${subjects.length} discipline trovate',
          filters: [
            const FilterGroupDivider(),
            AppFilterPill<String>.filter(
              prefix: 'Area',
              hint: 'Tutte le aree',
              icon: Icons.category_outlined,
              value: _filterArea,
              menuWidth: 210,
              onChanged: (value) => setState(() => _filterArea = value),
              onClear: () => setState(() => _filterArea = null),
              options: subjectAreas
                  .map((area) => FilterOption(value: area.value, label: area.label))
                  .toList(),
            ),
          ],
        ),
      ],
      body: EntityCardGrid(
        children: [
          for (final subject in subjects) AssociationSubjectCard(subject: subject),
        ],
      ),
    );
  }
}

class _MissingSubjectDialog extends StatefulWidget
{
  const _MissingSubjectDialog();

  @override
  State<_MissingSubjectDialog> createState() => _MissingSubjectDialogState();
}

class _MissingSubjectDialogState extends State<_MissingSubjectDialog>
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _send() async
  {
    if (_isSending)
    {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true);

      return;
    }

    final description = _descController.text.trim();

    setState(() => _isSending = true);

    try
    {
      await ApiService().reportMissingSubject(name, description.isEmpty ? null : description);

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: 'Segnalazione inviata con successo!', isError: false);
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
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Disciplina mancante',
      title: 'Segnala disciplina',
      maxWidth: kWizardDialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'INVIA SEGNALAZIONE',
          icon: Icons.send_rounded,
          busy: _isSending,
          height: kWizardButtonHeight,
          fontSize: kWizardButtonFontSize,
          onPressed: _send,
        ),
        maxWidth: _footerWidth,
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Nome',
                hintText: 'Es. Grammatica latina',
                maxLength: FieldLimits.name,
                textCapitalization: TextCapitalization.sentences,
                nothingAbove: true,
              ),
              DescriptionField(_descController),
            ],
          ),
        ),
      ],
    );
  }
}
