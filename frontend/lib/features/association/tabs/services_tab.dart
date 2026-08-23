import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
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

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

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
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: 'Cerca servizio...',
        actionLabel: 'NUOVO SERVIZIO',
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: services.length == 1
            ? '1 servizio trovato'
            : '${services.length} servizi trovati',
      ),
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
    with WizardDialogState
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  bool get isEditing => widget.existingService != null;

  @override
  VoidCallback? get onCancelEdit => widget.onCancelEdit;

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

  @override
  void resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _descController.clear();
    });
  }

  Future<void> _save() async
  {
    if (isSaving)
    {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty)
    {
      showError('Il nome non può essere vuoto.');

      return;
    }

    await runSave(
      (onError) => widget.onSave(name, _descController.text.trim(), onError),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return buildSingleStepDialog(
      eyebrow: 'Servizio',
      title: isEditing ? 'Modifica servizio' : 'Nuovo servizio',
      onSubmit: _save,
      fields: [
        AppTextField(
          controller: _nameController,
          label: 'Nome',
          hintText: 'Es. Metodo di studio',
          maxLength: FieldLimits.name,
          textCapitalization: TextCapitalization.sentences,
          nothingAbove: true,
        ),
        DescriptionField(_descController),
      ],
    );
  }
}
