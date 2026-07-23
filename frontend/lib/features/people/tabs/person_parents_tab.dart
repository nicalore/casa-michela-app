import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/parent_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_item.dart';
import '../person_wizard_components.dart';
import '../widgets/person_detail_widgets.dart';

const Color _dialogBackground = Color(0xFFF4F7F9);
const Color _dialogShadow = Color(0x26000000);

const double _dialogRadius = 40;
const int _adultAge = 18;
const int _maxParentsPerPerson = 2;

// Role label the backend uses for a parent, matched case insensitively because
// the endpoints are not consistent on capitalisation.
const String _parentRoleLabel = 'GENITORE';

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

enum _ParentSort
{
  surnameAsc('Cognome (A-Z)'),
  surnameDesc('Cognome (Z-A)'),
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const _ParentSort(this.label);

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      _ParentSort.nameAsc => a.firstName.compareTo(b.firstName),
      _ParentSort.nameDesc => b.firstName.compareTo(a.firstName),
      _ParentSort.surnameAsc => a.lastName.compareTo(b.lastName),
      _ParentSort.surnameDesc => b.lastName.compareTo(a.lastName),
      _ParentSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _ParentSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

class PersonParentsTab extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // Called only after the parental responsibilities have been removed. This tab
  // disappears from the list at that point, and the IndexedStack would otherwise
  // stay on a position that no longer exists: the caller redirects to the
  // personal information tab instead.
  final VoidCallback onResponsibilityRemoved;

  const PersonParentsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onResponsibilityRemoved,
  });

  @override
  State<PersonParentsTab> createState() => _PersonParentsTabState();
}

class _PersonParentsTabState extends State<PersonParentsTab>
{
  int _selectedParentIndex = 0;

  Map<String, ParentalRelationshipDraft> get _currentDrafts
  {
    return {
      for (final parent in widget.person.parents ?? <ParentItem>[])
        parent.fiscalCode: ParentalRelationshipDraft(
          taxCode: parent.fiscalCode,
          authorizedPickup: parent.authorizedPickup,
          restrictionReason: parent.pickupRestrictionReason,
        ),
    };
  }

  bool _draftsDiffer(ParentalRelationshipDraft a, ParentalRelationshipDraft b)
  {
    return a.authorizedPickup != b.authorizedPickup ||
        a.restrictionReason != b.restrictionReason;
  }

  // Removals go first: freeing a slot before adding avoids hitting the two
  // parents limit when one parent is being swapped for another.
  Future<void> _applyChanges(
    Map<String, ParentalRelationshipDraft> before,
    Map<String, ParentalRelationshipDraft> after,
  ) async
  {
    final removed = before.keys.toSet().difference(after.keys.toSet());
    final added = after.keys.toSet().difference(before.keys.toSet());
    final changed = after.keys.where((code)
    {
      final previous = before[code];

      return previous != null && _draftsDiffer(previous, after[code]!);
    }).toSet();

    if (removed.isEmpty && added.isEmpty && changed.isEmpty)
    {
      return;
    }

    final api = ApiService();
    final childCode = widget.person.fiscalCode;

    for (final code in removed)
    {
      await api.removeParent(childCode, code);
    }

    for (final code in added)
    {
      final draft = after[code]!;
      await api.addParent(
        childCode,
        code,
        authorizedPickup: draft.authorizedPickup,
        pickupRestrictionReason: draft.restrictionReason,
      );
    }

    for (final code in changed)
    {
      final draft = after[code]!;
      // The parent code is passed twice on purpose: the endpoint can also
      // replace a parent, and here only the pickup fields change.
      await api.updateParent(
        childCode,
        code,
        code,
        authorizedPickup: draft.authorizedPickup,
        pickupRestrictionReason: draft.restrictionReason,
      );
    }
  }

  Future<void> _openParentSelectionDialog() async
  {
    final before = _currentDrafts;

    final after = await showBlurredDialog<Map<String, ParentalRelationshipDraft>>(
      context: context,
      barrierLabel: 'SelectParent',
      builder: (context) => _ParentSelectionDialog(
        childTaxCode: widget.person.fiscalCode,
        childName: '${widget.person.firstName} ${widget.person.lastName}',
        initialSelected: before,
      ),
    );

    if (after == null || !mounted)
    {
      return;
    }

    try
    {
      await _applyChanges(before, after);

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(
        context: context,
        message: 'Associazioni aggiornate con successo!',
        isError: false,
      );

      widget.onUpdate();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  Future<void> _removeAllResponsibilities() async
  {
    try
    {
      for (final parent in widget.person.parents ?? <ParentItem>[])
      {
        await ApiService().removeParent(widget.person.fiscalCode, parent.fiscalCode);
      }

      if (!mounted)
      {
        return;
      }

      CustomSnackBar.show(
        context: context,
        message: 'Responsabilità rimosse con successo.',
        isError: false,
      );

      // Not onUpdate() here: this tab is about to disappear, so the caller has to
      // move the selection elsewhere.
      widget.onResponsibilityRemoved();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

  void _confirmRemoveResponsibilities()
  {
    showDialog(
      context: context,
      builder: (dialogContext)
      {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Rimuovi Responsabilità Genitoriali',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Dopo la rimozione delle responsabilità genitoriali, questa persona '
            "gestirà autonomamente il proprio rapporto con l'Associazione. "
            "L'operazione è irreversibile.",
            style: GoogleFonts.plusJakartaSans(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'ANNULLA',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: ()
              {
                Navigator.pop(dialogContext);
                _removeAllResponsibilities();
              },
              child: Text(
                'RIMUOVI',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _residenceAddress(ParentItem parent)
  {
    final joined =
        '${parent.residenceType?.trim() ?? ''} ${parent.address?.trim() ?? ''}'.trim();

    return joined.isEmpty ? missingValue : joined;
  }

  Widget _buildEmptyState()
  {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nessun genitore associato a sistema.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.slate500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: WizardAnimatedActionButton(
                text: 'AGGIUNGI GENITORI',
                icon: Icons.add_rounded,
                baseColor: AppTheme.primary,
                hoverColor: AppTheme.primaryHover,
                onPressed: _openParentSelectionDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailCards(ParentItem parent)
  {
    final birthDate =
        parent.birthDate != null ? _dateFormat.format(parent.birthDate!) : missingValue;

    return [
      PersonDetailCardPair(
        first: PersonDetailCard(
          title: 'Identità',
          icon: Icons.badge_rounded,
          rows: [
            DetailRowData('Nome', parent.firstName),
            DetailRowData('Cognome', parent.lastName),
            DetailRowData('Sesso', orDash(parent.gender)),
            DetailRowData('Codice fiscale', parent.fiscalCode),
            null,
          ],
        ),
        second: PersonDetailCard(
          title: 'Residenza',
          icon: Icons.home_rounded,
          rows: [
            DetailRowData('Indirizzo', _residenceAddress(parent)),
            DetailRowData('N°', orDash(parent.addressNumber)),
            DetailRowData('Città', orDash(parent.city)),
            DetailRowData('Provincia', orDash(parent.province)),
            DetailRowData('CAP', orDash(parent.zipCode)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      PersonDetailCardPair(
        first: PersonDetailCard(
          title: 'Dati anagrafici',
          icon: Icons.cake_rounded,
          rows: [
            DetailRowData('Data di nascita', birthDate),
            DetailRowData('Città di nascita', orDash(parent.birthCity)),
            DetailRowData('Provincia', orDash(parent.birthProvince)),
          ],
        ),
        second: PersonDetailCard(
          title: 'Contatti',
          icon: Icons.alternate_email_rounded,
          rows: [
            DetailRowData('Email', orDash(parent.email)),
            DetailRowData('Telefono', orDash(parent.phoneNumber)),
            null,
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: PersonDetailCard(
          title: 'Autorizzazione al ritiro',
          icon: Icons.how_to_reg_outlined,
          rows: [
            DetailRowData('Autorizzato', parent.authorizedPickup ? 'Sì' : 'No'),
            if (!parent.authorizedPickup)
              DetailRowData('Motivo', orDash(parent.pickupRestrictionReason)),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final parents = widget.person.parents ?? [];

    if (parents.isEmpty)
    {
      return _buildEmptyState();
    }

    // Guards against a selection left over from a longer list, for instance after
    // removing the parent that was being shown.
    if (_selectedParentIndex >= parents.length)
    {
      _selectedParentIndex = 0;
    }

    final parent = parents[_selectedParentIndex];

    // Only an adult can be released from parental responsibility, so the button
    // is absent for minors.
    final isAdult = widget.person.age != null && widget.person.age! >= _adultAge;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PillTabBar(
                labels: [
                  for (final item in parents) '${item.firstName} ${item.lastName}',
                ],
                selectedIndex: _selectedParentIndex,
                onSelected: (index) => setState(() => _selectedParentIndex = index),
              ),
              ..._buildDetailCards(parent),
              const SizedBox(height: 48),
              Center(
                child: _ResponsiveParentActionButtonsRow(
                  onModify: _openParentSelectionDialog,
                  onRemoveResponsibility: isAdult ? _confirmRemoveResponsibilities : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Two actions whose widths stay fixed in both layouts, never stretched. The
// secondary label is shortened when stacked, because the long one does not fit
// the narrower button.
class _ResponsiveParentActionButtonsRow extends StatelessWidget
{
  static const double _primaryWidth = 230;
  static const double _secondaryWidthSideBySide = 395;
  static const double _secondaryWidthStacked = 300;
  static const double _spacing = 16;
  static const double _breakpoint =
      _primaryWidth + _spacing + _secondaryWidthSideBySide + 40;

  final VoidCallback onModify;
  final VoidCallback? onRemoveResponsibility;

  const _ResponsiveParentActionButtonsRow({
    required this.onModify,
    required this.onRemoveResponsibility,
  });

  Widget _buildRemoveButton({required double width, required String label})
  {
    return SizedBox(
      width: width,
      child: WizardAnimatedActionButton(
        text: label,
        icon: Icons.gavel_rounded,
        baseColor: AppTheme.danger,
        hoverColor: AppTheme.dangerHover,
        onPressed: onRemoveResponsibility!,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final primaryButton = SizedBox(
      width: _primaryWidth,
      child: WizardAnimatedActionButton(
        text: 'MODIFICA GENITORI',
        icon: Icons.edit_rounded,
        baseColor: AppTheme.primary,
        hoverColor: AppTheme.primaryHover,
        onPressed: onModify,
      ),
    );

    if (onRemoveResponsibility == null)
    {
      return primaryButton;
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth >= _breakpoint)
        {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              primaryButton,
              const SizedBox(width: _spacing),
              _buildRemoveButton(
                width: _secondaryWidthSideBySide,
                label: 'RIMUOVI RESPONSABILITÀ GENITORIALI',
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            primaryButton,
            const SizedBox(height: _spacing),
            _buildRemoveButton(
              width: _secondaryWidthStacked,
              label: 'RIMUOVI RESPONSABILITÀ',
            ),
          ],
        );
      },
    );
  }
}

class _ParentSelectionDialog extends StatefulWidget
{
  final String childTaxCode;
  final String childName;
  final Map<String, ParentalRelationshipDraft> initialSelected;

  const _ParentSelectionDialog({
    required this.childTaxCode,
    required this.childName,
    required this.initialSelected,
  });

  @override
  State<_ParentSelectionDialog> createState() => _ParentSelectionDialogState();
}

class _ParentSelectionDialogState extends State<_ParentSelectionDialog>
{
  static const double _contentMaxWidth = 1320;

  final TextEditingController _searchController = TextEditingController();

  late Map<String, ParentalRelationshipDraft> _selected;

  bool _isLoading = true;
  List<PersonItem> _candidates = [];
  String _searchText = '';
  _ParentSort _sort = _ParentSort.surnameAsc;

  @override
  void initState()
  {
    super.initState();
    _selected = Map.from(widget.initialSelected);
    _loadCandidates();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  // Candidates are adults holding the parent role, excluding the person whose
  // parents are being chosen. A missing birth date counts as adult, so an
  // incomplete record is not silently hidden.
  bool _isCandidate(PersonItem person)
  {
    if (person.fiscalCode == widget.childTaxCode)
    {
      return false;
    }

    final isAdult = person.age == null || person.age! >= _adultAge;
    final isParent = person.roles.any((role) => role.toUpperCase() == _parentRoleLabel);

    return isAdult && isParent;
  }

  Future<void> _loadCandidates() async
  {
    try
    {
      final allPeople = await ApiService().getPeople();

      if (mounted)
      {
        setState(()
        {
          _candidates = allPeople.where(_isCandidate).toList();
          _isLoading = false;
        });
      }
    }
    catch (_)
    {
      if (mounted)
      {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onCardTap(PersonItem adult) async
  {
    final isSelected = _selected.containsKey(adult.fiscalCode);

    if (!isSelected && _selected.length >= _maxParentsPerPerson)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Massimo $_maxParentsPerPerson genitori selezionabili.',
        isError: true,
      );

      return;
    }

    final draft = await showAuthorizedPickupDialog(
      context,
      personTaxCode: adult.fiscalCode,
      parentName: '${adult.firstName} ${adult.lastName}',
      childName: widget.childName,
      existing: _selected[adult.fiscalCode],
    );

    if (draft != null && mounted)
    {
      setState(() => _selected[adult.fiscalCode] = draft);
    }
  }

  List<PersonItem> get _filteredCandidates
  {
    final query = _searchText.toLowerCase();

    final result = _candidates.where((adult)
    {
      return '${adult.firstName} ${adult.lastName}'.toLowerCase().contains(query);
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  void _confirm()
  {
    if (_selected.isEmpty)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Seleziona almeno un genitore per procedere.',
        isError: true,
      );

      return;
    }

    Navigator.of(context).pop(_selected);
  }

  Widget _buildDialogGlow({required bool topRight})
  {
    return Positioned(
      right: topRight ? -400 : null,
      top: topRight ? -400 : null,
      left: topRight ? null : -400,
      bottom: topRight ? null : -400,
      child: const IgnorePointer(
        child: SizedBox(
          width: 800,
          height: 800,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x22003C82), Color(0x00003C82)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters()
  {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: _ResponsiveSearchFilterRow(
          breakpoint: 500,
          searchBar: AnimatedSearchBar(
            controller: _searchController,
            hintText: 'Cerca genitore...',
            onChanged: (value) => setState(() => _searchText = value),
          ),
          filterWidgets: [
            CustomFilterMenu<_ParentSort>(
              hint: 'Ordina per',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 180,
              showClearIcon: false,
              onClear: () {},
              onChanged: (value) => setState(() => _sort = value),
              options: _ParentSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesGrid(List<PersonItem> candidates)
  {
    if (candidates.isEmpty)
    {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            'Nessun genitore disponibile trovato.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: candidates.map((adult)
          {
            final isSelected = _selected.containsKey(adult.fiscalCode);

            return WizardSelectablePersonCard(
              person: adult,
              isSelected: isSelected,
              onTap: () => _onCardTap(adult),
              onEdit: isSelected ? () => _onCardTap(adult) : null,
              onRemove: isSelected
                  ? () => setState(() => _selected.remove(adult.fiscalCode))
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final candidates = _filteredCandidates;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        constraints: const BoxConstraints(maxWidth: 1200, minHeight: 600),
        decoration: BoxDecoration(
          color: _dialogBackground,
          borderRadius: BorderRadius.circular(_dialogRadius),
          boxShadow: const [
            BoxShadow(color: _dialogShadow, offset: Offset(0, 12), blurRadius: 36),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_dialogRadius),
          child: Stack(
            children: [
              _buildDialogGlow(topRight: true),
              _buildDialogGlow(topRight: false),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gestisci Genitori',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: AppTheme.slate200),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildFilters(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(color: AppTheme.primary),
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.only(bottom: 40),
                                      child: _buildCandidatesGrid(candidates),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32, left: 32, right: 32),
                    child: Center(
                      child: _ResponsiveDialogButtonsRow(
                        cancelOnPressed: () => Navigator.of(context).pop(),
                        confirmOnPressed: _confirm,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bottom bar of the manage dialog. Kept local rather than using the shared
// ResponsiveDialogButtonsRow: that one stretches its buttons to fill the footer,
// while these stay at a fixed width in both layouts and are built from the wizard
// component set.
class _ResponsiveDialogButtonsRow extends StatelessWidget
{
  static const double _buttonWidth = 230;
  static const double _spacing = 24;
  static const double _breakpoint = _buttonWidth * 2 + _spacing + 40;

  final VoidCallback cancelOnPressed;
  final VoidCallback confirmOnPressed;

  const _ResponsiveDialogButtonsRow({
    required this.cancelOnPressed,
    required this.confirmOnPressed,
  });

  @override
  Widget build(BuildContext context)
  {
    final cancelButton = SizedBox(
      width: _buttonWidth,
      child: WizardAnimatedActionButton(
        text: 'ANNULLA',
        icon: Icons.close_rounded,
        baseColor: AppTheme.danger,
        hoverColor: AppTheme.dangerHover,
        onPressed: cancelOnPressed,
      ),
    );

    final confirmButton = SizedBox(
      width: _buttonWidth,
      child: WizardAnimatedActionButton(
        text: 'CONFERMA',
        icon: Icons.check_circle_outline,
        baseColor: AppTheme.primary,
        hoverColor: AppTheme.primaryHover,
        onPressed: confirmOnPressed,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        // Confirm on top when stacked, so the primary action stays closest to the
        // content above it.
        if (constraints.maxWidth < _breakpoint)
        {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              confirmButton,
              const SizedBox(height: 16),
              cancelButton,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButton,
            const SizedBox(width: _spacing),
            confirmButton,
          ],
        );
      },
    );
  }
}

// Search bar and filters on one row while there is room, stacked below the
// threshold rather than always split.
class _ResponsiveSearchFilterRow extends StatelessWidget
{
  static const double _spacing = 12;

  final Widget searchBar;
  final List<Widget> filterWidgets;
  final double breakpoint;

  const _ResponsiveSearchFilterRow({
    required this.searchBar,
    required this.filterWidgets,
    this.breakpoint = 700,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < breakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchBar,
              const SizedBox(height: _spacing),
              Wrap(spacing: _spacing, runSpacing: _spacing, children: filterWidgets),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBar),
            for (final filter in filterWidgets) ...[
              const SizedBox(width: _spacing),
              filter,
            ],
          ],
        );
      },
    );
  }
}