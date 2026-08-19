import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../models/service_item.dart';
import '../widgets/service_card.dart';

class ServicesTab extends StatefulWidget
{
  final List<ServiceItem> services;
  final Future<bool> Function(String name, String description, Function(String) onError) onCreate;
  final Future<bool> Function(String originalName, String name, String description, Function(String) onError) onEdit;
  final void Function(ServiceItem item) onDelete;

  const ServicesTab({
    super.key,
    required this.services,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;

  List<ServiceItem> get _filteredServices
  {
    final query = _searchText.toLowerCase();

    final result = widget.services
        .where((service) => service.name.toLowerCase().contains(query))
        .toList();

    result.sort((a, b) => switch (_sortBy)
    {
      SortCriterion.nameAsc => a.name.compareTo(b.name),
      SortCriterion.nameDesc => b.name.compareTo(a.name),
      SortCriterion.dateAsc => a.createdAt.compareTo(b.createdAt),
      SortCriterion.dateDesc => b.createdAt.compareTo(a.createdAt),
    });

    return result;
  }

  void _showWizard({ServiceItem? service, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ServiceWizard',
      builder: (context) => _ServiceWizardDialog(
        existingService: service,
        onCancelEdit: onCancelEdit,
        onSave: (name, description, onError) async
        {
          if (service == null)
          {
            return await widget.onCreate(name, description, onError);
          }

          // The name of the row as it stands is what says which one to rewrite:
          // the one being typed may be a new name for it.
          return await widget.onEdit(service.name, name, description, onError);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final services = _filteredServices;

    return TabContent(
      header: [
        TabHeaderRow(
          search: AppSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            hintText: 'Cerca servizio...',
          ),
          action: AppGradientButton(
            label: 'NUOVO SERVIZIO',
            icon: Icons.add_rounded,
            height: 50,
            radius: 25,
            fontSize: 14,
            onPressed: () => _showWizard(),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppFilterPill<SortCriterion>.setting(
              prefix: 'Ordina',
              hint: 'Ordina per',
              icon: Icons.swap_vert_rounded,
              value: _sortBy,
              menuWidth: 190,
              onChanged: (value) => setState(() => _sortBy = value),
              options: SortCriterion.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          services.length == 1
              ? '1 servizio trovato'
              : '${services.length} servizi trovati',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 16),
      ],
      body: EntityCardGrid(
        children: services.map((service)
        {
          return ServiceCard(
            service: service,
            onEditRequested: (onCancel) => _showWizard(service: service, onCancelEdit: onCancel),
            onDelete: () => widget.onDelete(service),
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceWizardDialog extends StatefulWidget
{
  final ServiceItem? existingService;
  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String name, String description, Function(String) onError) onSave;

  const _ServiceWizardDialog({
    this.existingService,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_ServiceWizardDialog> createState() => _ServiceWizardDialogState();
}

class _ServiceWizardDialogState extends State<_ServiceWizardDialog>
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.existingService != null;

  @override
  void initState()
  {
    super.initState();

    final service = widget.existingService;

    if (service != null)
    {
      _nameController.text = service.name;
      _descController.text = service.description ?? '';
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
    });
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();

    if (_isEditing)
    {
      widget.onCancelEdit?.call();
    }
  }

  Future<void> _save() async
  {
    if (_isSaving)
    {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Il nome non può essere vuoto.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      name,
      _descController.text.trim(),
      (errorMessage)
      {
        if (mounted)
        {
          CustomSnackBar.show(context: context, message: errorMessage, isError: true);
        }
      },
    );

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (!success)
    {
      return;
    }

    if (_isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Servizio',
      title: _isEditing ? 'Modifica servizio' : 'Nuovo servizio',
      onClose: _closeDialog,
      maxWidth: 540,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _save,
        ),
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
                hintText: 'Es. Metodo di studio',
                textCapitalization: TextCapitalization.sentences,
                nothingAbove: true,
              ),
              AppTextField(
                controller: _descController,
                label: 'Descrizione (opzionale)',
                hintText: 'Aggiungi una descrizione...',
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
