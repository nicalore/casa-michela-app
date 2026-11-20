import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/language/app_language.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../shared/widgets/wizard_dialog.dart';
import '../models/room_item.dart';
import '../widgets/room_card.dart';

typedef RoomWriter = Future<bool> Function(
  String name,
  int? capacity,
  String description,
  Function(String) onError,
);

typedef RoomEditor = Future<bool> Function(
  int id,
  String name,
  int? capacity,
  String description,
  Function(String) onError,
);

class RoomsTab extends StatefulWidget
{
  final List<RoomItem> rooms;
  final RoomWriter onCreate;
  final RoomEditor onEdit;
  final void Function(RoomItem item) onDelete;

  const RoomsTab({
    super.key,
    required this.rooms,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  SortCriterion _sortBy = SortCriterion.nameAsc;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<RoomItem> get _filteredRooms
  {
    final query = _searchText.toLowerCase();

    final result = widget.rooms
        .where((room) => room.name.toLowerCase().contains(query))
        .toList();

    sortByCriterion(
      result,
      _sortBy,
      name: (item) => item.name,
      createdAt: (item) => item.createdAt,
    );

    return result;
  }

  void _showWizard({RoomItem? room, VoidCallback? onEditSaved})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RoomWizard',
      builder: (context) => _RoomWizardDialog(
        existingRoom: room,
        onEditSaved: onEditSaved,
        onSave: (name, capacity, description, onError) async
        {
          if (room == null)
          {
            return await widget.onCreate(name, capacity, description, onError);
          }

          return await widget.onEdit(room.id, name, capacity, description, onError);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final rooms = _filteredRooms;

    return TabContent(
      header: entityTabHeader(
        searchController: _searchController,
        onSearchChanged: (value) => setState(() => _searchText = value),
        searchHint: tr('Cerca stanza...', 'Search rooms...'),
        actionLabel: tr('NUOVA STANZA', 'NEW ROOM'),
        onAction: () => _showWizard(),
        sort: _sortBy,
        onSortChanged: (value) => setState(() => _sortBy = value),
        countLabel: rooms.length == 1
            ? tr('1 stanza trovata', '1 room found')
            : tr('${rooms.length} stanze trovate', '${rooms.length} rooms found'),
      ),
      empty: emptyListCard(
        shown: rooms.length,
        total: widget.rooms.length,
        icon: Icons.meeting_room_rounded,
        none: tr('Nessuna stanza registrata', 'No rooms recorded'),
      ),
      body: EntityCardGrid(
        children: rooms.map((room)
        {
          return RoomCard(
            room: room,
            onEditRequested: (onSaved) => _showWizard(room: room, onEditSaved: onSaved),
            onDelete: () => widget.onDelete(room),
          );
        }).toList(),
      ),
    );
  }
}

class _RoomWizardDialog extends StatefulWidget
{
  final RoomItem? existingRoom;
  final VoidCallback? onEditSaved;
  final RoomWriter onSave;

  const _RoomWizardDialog({
    this.existingRoom,
    this.onEditSaved,
    required this.onSave,
  });

  @override
  State<_RoomWizardDialog> createState() => _RoomWizardDialogState();
}

class _RoomWizardDialogState extends State<_RoomWizardDialog>
    with WizardDialogState
{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  bool get isEditing => widget.existingRoom != null;

  @override
  VoidCallback? get onEditSaved => widget.onEditSaved;

  @override
  void initState()
  {
    super.initState();

    final room = widget.existingRoom;

    if (room != null)
    {
      _nameController.text = room.name;
      _capacityController.text = room.capacity?.toString() ?? '';
      _descController.text = room.description ?? '';
    }
  }

  @override
  void dispose()
  {
    _nameController.dispose();
    _capacityController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _capacityController.clear();
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
      showError(tr('Il nome non può essere vuoto.', 'The name cannot be empty.'));

      return;
    }

    final capacityText = _capacityController.text.trim();
    final int? capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);

    if (capacityText.isNotEmpty && (capacity == null || capacity <= 0))
    {
      showError(tr('La capienza deve essere un numero maggiore di zero.', 'The capacity must be a number greater than zero.'));

      return;
    }

    await runSave(
      (onError) => widget.onSave(
        name,
        capacity,
        _descController.text.trim(),
        onError,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return buildSingleStepDialog(
      eyebrow: tr('Stanza', 'Room'),
      title: isEditing ? tr('Modifica stanza', 'Edit room') : tr('Nuova stanza', 'New room'),
      onSubmit: _save,
      fields: [
        AppTextField(
          controller: _nameController,
          label: tr('Nome', 'Name'),
          hintText: tr('Es. Stanza di Aldo', "E.g. Aldo's room"),
          maxLength: FieldLimits.name,
          textCapitalization: TextCapitalization.sentences,
          nothingAbove: true,
        ),
        AppTextField(
          controller: _capacityController,
          label: tr('Capienza (opzionale)', 'Capacity (optional)'),
          hintText: tr('Es. 12', 'E.g. 12'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        DescriptionField(_descController),
      ],
    );
  }
}
