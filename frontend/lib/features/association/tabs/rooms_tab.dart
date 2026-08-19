import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/room_item.dart';
import '../widgets/room_card.dart';

// Answers whether the write went through; onError carries the server's own
// sentence where it did not.
typedef RoomWriter = Future<bool> Function(
  String name,
  int? capacity,
  String description,
  Function(String) onError,
);

// The same, for a room that already exists.
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

    result.sort((a, b) => switch (_sortBy)
    {
      SortCriterion.nameAsc => a.name.compareTo(b.name),
      SortCriterion.nameDesc => b.name.compareTo(a.name),
      SortCriterion.dateAsc => a.createdAt.compareTo(b.createdAt),
      SortCriterion.dateDesc => b.createdAt.compareTo(a.createdAt),
    });

    return result;
  }

  void _showWizard({RoomItem? room, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'RoomWizard',
      builder: (context) => _RoomWizardDialog(
        existingRoom: room,
        onCancelEdit: onCancelEdit,
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
      header: [
        TabHeaderRow(
          search: AppSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchText = value),
            hintText: 'Cerca stanza...',
          ),
          action: AppGradientButton(
            label: 'NUOVA STANZA',
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
          rooms.length == 1
              ? '1 stanza trovata'
              : '${rooms.length} stanze trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 16),
      ],
      body: EntityCardGrid(
        children: rooms.map((room)
        {
          return RoomCard(
            room: room,
            onEditRequested: (onCancel) => _showWizard(room: room, onCancelEdit: onCancel),
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
  final VoidCallback? onCancelEdit;
  final RoomWriter onSave;

  const _RoomWizardDialog({
    this.existingRoom,
    this.onCancelEdit,
    required this.onSave,
  });

  @override
  State<_RoomWizardDialog> createState() => _RoomWizardDialogState();
}

class _RoomWizardDialogState extends State<_RoomWizardDialog>
{
  // The height and type size every dialog gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.existingRoom != null;

  @override
  void initState()
  {
    super.initState();

    final room = widget.existingRoom;

    if (room != null)
    {
      _nameController.text = room.name;
      // Blank is how the form says "not measured", so a null arrives blank.
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

  void _showError(String message)
  {
    if (!mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: message, isError: true);
  }

  void _resetForm()
  {
    setState(()
    {
      _nameController.clear();
      _capacityController.clear();
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
      _showError('Il nome non può essere vuoto.');

      return;
    }

    // Blank means null. Typed, the field only takes digits, so what is left to
    // refuse is a zero.
    final capacityText = _capacityController.text.trim();
    final int? capacity = capacityText.isEmpty ? null : int.tryParse(capacityText);

    if (capacityText.isNotEmpty && (capacity == null || capacity <= 0))
    {
      _showError('La capienza deve essere un numero maggiore di zero.');

      return;
    }

    setState(() => _isSaving = true);

    final success = await widget.onSave(
      name,
      capacity,
      _descController.text.trim(),
      _showError,
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
      eyebrow: 'Stanza',
      title: _isEditing ? 'Modifica stanza' : 'Nuova stanza',
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
                hintText: 'Es. Stanza di Aldo',
                textCapitalization: TextCapitalization.sentences,
                nothingAbove: true,
              ),
              AppTextField(
                controller: _capacityController,
                label: 'Capienza (opzionale)',
                hintText: 'Es. 12',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
