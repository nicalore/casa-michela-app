import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/phone_number.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/parent_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_face.dart';
import '../models/person_item.dart';
import '../widgets/authorized_pickup_dialog.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/relative_card.dart';

String get _peopleLoadFailed => tr('Impossibile caricare le anagrafiche dal server.', "Couldn't load the people from the server.");

const int _adultAge = 18;
const int _maxParentsPerPerson = 2;

// Matched case-insensitively: the endpoints are inconsistent on capitalisation.
const String _parentRoleLabel = 'GENITORE';

enum _ParentSort
{
  surnameAsc,
  surnameDesc,
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc;

  String get label => switch (this)
  {
    surnameAsc => tr('Cognome (A-Z)', 'Surname (A-Z)'),
    surnameDesc => tr('Cognome (Z-A)', 'Surname (Z-A)'),
    nameAsc => tr('Nome (A-Z)', 'Name (A-Z)'),
    nameDesc => tr('Nome (Z-A)', 'Name (Z-A)'),
    dateDesc => tr('Più recente', 'Most recent'),
    dateAsc => tr('Meno recente', 'Least recent'),
  };

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      _ParentSort.nameAsc => compareByName(a, b),
      _ParentSort.nameDesc => compareByName(b, a),
      _ParentSort.surnameAsc => compareBySurname(a, b),
      _ParentSort.surnameDesc => compareBySurname(b, a),
      _ParentSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _ParentSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

class PersonParentsTab extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onUpdate;

  // This tab disappears afterwards: the caller redirects elsewhere.
  final VoidCallback onResponsibilityRemoved;

  final ValueChanged<String> onOpenPerson;

  const PersonParentsTab({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onResponsibilityRemoved,
    required this.onOpenPerson,
  });

  @override
  State<PersonParentsTab> createState() => _PersonParentsTabState();
}

class _PersonParentsTabState extends State<PersonParentsTab>
{

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

  // Removals first: swapping a parent must free a slot under the two-parent limit.
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
      // Same code twice: the endpoint can also replace a parent; here only pickup changes.
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
        message: tr('Associazioni aggiornate con successo!', 'Links updated successfully!'),
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
        message: tr('Responsabilità rimosse con successo.', 'Responsibility removed successfully.'),
        isError: false,
      );

      // Not onUpdate(): this tab is about to disappear.
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

  Future<void> _confirmRemoveResponsibilities() async
  {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmParentalRemoval',
      builder: (dialogContext) => AppDialogStack(
        eyebrow: tr('Responsabilità genitoriali', 'Parental responsibility'),
        title: tr('Confermi?', 'Are you sure?'),
        showClose: false,
        maxWidth: 520,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: tr('ANNULLA', 'CANCEL'),
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialVioletText,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          primary: AppGradientButton(
            label: tr('RIMUOVI', 'REMOVE'),
            icon: Icons.gavel_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              tr(
                'Dopo la rimozione delle responsabilità genitoriali, questa persona '
                    "gestirà autonomamente il proprio rapporto con l'Associazione. "
                    "L'operazione è irreversibile.",
                'Once parental responsibility is removed, this person will manage their own relationship with the '
                    'Association. This cannot be undone.',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true)
    {
      await _removeAllResponsibilities();
    }
  }

  String _residence(ParentItem parent)
  {
    final city = parent.city?.trim() ?? '';
    final province = parent.province?.trim() ?? '';

    if (city.isEmpty)
    {
      return missingValue;
    }

    return province.isEmpty ? city : '$city ($province)';
  }

  Widget _buildCard(ParentItem parent)
  {
    final age = parent.age;

    return RelativeCard(
      person: parent,
      roles: parent.roles,
      feminine: parent.gender == 'F',
      facts: [
        RelativeFact(Icons.cake_rounded, age == null ? missingValue : ageLabel(age)),
        RelativeFact(Icons.call_rounded, orDash(formatPhoneNumber(parent.phoneNumber))),
        RelativeFact(Icons.alternate_email_rounded, orDash(parent.email)),
        RelativeFact(Icons.home_rounded, _residence(parent)),
      ],
      authorizedPickup: widget.person.isAdult ? null : parent.authorizedPickup,
      pickupRestrictionReason: parent.pickupRestrictionReason,
      onTap: () => widget.onOpenPerson(parent.fiscalCode),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final parents = widget.person.parents ?? [];

    // Only an adult can be released from parental responsibility.
    final isAdult = widget.person.age != null && widget.person.age! >= _adultAge;

    final Widget actions = _ResponsiveParentActionButtonsRow(
      onManage: _openParentSelectionDialog,
      onRemoveResponsibility: isAdult ? _confirmRemoveResponsibilities : null,
    );

    if (parents.isEmpty)
    {
      return AppEmptyRoom(
        card: AppEmptyCard(
          icon: Icons.family_restroom_rounded,
          message: tr('Nessun genitore associato a questa anagrafica', 'No parent linked to this record'),
        ),
        below: [actions],
      );
    }

    return ScrollEdgeFade(
      child: TransitionScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: pageTransitionBlocks([
                RelativeCardGrid(cards: [for (final parent in parents) _buildCard(parent)]),
                const SizedBox(height: 48),
                actions,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveParentActionButtonsRow extends StatelessWidget
{
  final VoidCallback onManage;
  final VoidCallback? onRemoveResponsibility;

  const _ResponsiveParentActionButtonsRow({
    required this.onManage,
    required this.onRemoveResponsibility,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget manage = AppGradientButton(
      label: tr('GESTISCI GENITORI', 'MANAGE PARENTS'),
      icon: Icons.family_restroom_rounded,
      onPressed: onManage,
    );

    if (onRemoveResponsibility == null)
    {
      return manage;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        manage,
        AppGradientButton(
          label: tr('RIMUOVI RESPONSABILITÀ', 'REMOVE RESPONSIBILITY'),
          icon: Icons.gavel_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDangerText,
          onPressed: onRemoveResponsibility!,
        ),
      ],
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
  final TextEditingController _searchController = TextEditingController();

  late Map<String, ParentalRelationshipDraft> _selected;

  bool _isLoading = true;
  Object? _loadFailure;
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

  // A missing birth date counts as adult, so an incomplete record is not hidden.
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
          _loadFailure = null;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _isLoading = false;
          _loadFailure = e;
        });
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
        message: tr('Massimo $_maxParentsPerPerson genitori selezionabili.', 'You can select at most $_maxParentsPerPerson parents.'),
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
        message: tr('Seleziona almeno un genitore per procedere.', 'Select at least one parent to go on.'),
        isError: true,
      );

      return;
    }

    Navigator.of(context).pop(_selected);
  }

  Widget _buildFilters()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: tr('Cerca genitore...', 'Search parent...'),
          onChanged: (value) => setState(() => _searchText = value),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AppFilterPill<_ParentSort>.setting(
              prefix: tr('Ordina', 'Sort'),
              hint: tr('Ordina', 'Sort'),
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 200,
              onChanged: (value) => setState(() => _sort = value),
              options: _ParentSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCandidatesGrid(List<PersonItem> candidates)
  {
    if (_isLoading)
    {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    if (_loadFailure != null)
    {
      return Center(child: AppLoadFailedPanel(error: _loadFailure, message: _peopleLoadFailed, onRetry: _loadCandidates));
    }

    if (candidates.isEmpty)
    {
      return PersonEmptyState(message: tr('Nessun genitore disponibile trovato.', 'No available parent found.'));
    }

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: kPersonGridShadowRoom),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: candidates.map((adult)
          {
            final isSelected = _selected.containsKey(adult.fiscalCode);

            return PersonPickerCard(
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
    return AppDialogStack(
      eyebrow: tr('Genitori', 'Parents'),
      title: tr('Gestisci genitori', 'Manage parents'),
      maxWidth: 1160,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('SALVA', 'SAVE'),
          icon: Icons.check_rounded,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(expand: true, child: _buildFilters()),
        AppDialogPill(expand: true, child: _buildCandidatesGrid(_filteredCandidates)),
      ],
    );
  }
}
