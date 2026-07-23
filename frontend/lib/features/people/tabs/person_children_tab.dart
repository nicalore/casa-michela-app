import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/child_item.dart';
import '../models/parent_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_item.dart';
import '../widgets/person_detail_widgets.dart';
import '../person_wizard_components.dart';

const Color _dialogBackground = Color(0xFFF4F7F9);
const double _dialogRadius = 40;
const Color _dialogShadow = Color(0x26000000);

const int _adultAge = 18;
const int _maxParentsPerMinor = 2;

// Value of the "solo associato" option. Derived from the label so that renaming
// the role in RoleLabelMapper cannot leave the filter pointing at a stale string.
final String _memberOnlyFilterValue = RoleLabelMapper.memberLabel.toUpperCase();

enum _MinorSort
{
  surnameAsc('Cognome (A-Z)'),
  surnameDesc('Cognome (Z-A)'),
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const _MinorSort(this.label);

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      _MinorSort.nameAsc => a.firstName.compareTo(b.firstName),
      _MinorSort.nameDesc => b.firstName.compareTo(a.firstName),
      _MinorSort.surnameAsc => a.lastName.compareTo(b.lastName),
      _MinorSort.surnameDesc => b.lastName.compareTo(a.lastName),
      _MinorSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _MinorSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

class PersonChildrenTab extends StatefulWidget
{
  final PersonItem person;

  const PersonChildrenTab({super.key, required this.person});

  @override
  State<PersonChildrenTab> createState() => _PersonChildrenTabState();
}

class _PersonChildrenTabState extends State<PersonChildrenTab>
{
  late PersonItem _currentPerson;

  int _selectedChildIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState()
  {
    super.initState();
    _currentPerson = widget.person;
  }

  @override
  void didUpdateWidget(covariant PersonChildrenTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.person != widget.person)
    {
      _currentPerson = widget.person;
      _selectedChildIndex = 0;
    }
  }

  // Reloads the whole people list and picks this person out of it: the children
  // just edited arrive only with a fresh fetch.
  Future<void> _refreshCurrentPerson() async
  {
    setState(() => _isRefreshing = true);

    try
    {
      final allPeople = await ApiService().getPeople();
      final updatedPerson = allPeople.firstWhere(
        (person) => person.fiscalCode == _currentPerson.fiscalCode,
        orElse: () => _currentPerson,
      );

      if (mounted)
      {
        setState(()
        {
          _currentPerson = updatedPerson;
          _selectedChildIndex = 0;
        });
      }
    }
    catch (e)
    {
      // Deliberately silent: the edit already succeeded, and reporting a failed
      // refresh as a failed save would be misleading.
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openChildrenEditDialog() async
  {
    final changed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ChildrenEdit',
      builder: (context) => ChildrenEditDialog(person: _currentPerson),
    );

    if (changed == true)
    {
      await _refreshCurrentPerson();
    }
  }

  Widget _buildManageButton(String label)
  {
    return SizedBox(
      width: 255,
      child: WizardAnimatedActionButton(
        text: label,
        icon: Icons.family_restroom_outlined,
        baseColor: AppTheme.primary,
        hoverColor: AppTheme.primaryHover,
        onPressed: _openChildrenEditDialog,
      ),
    );
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
              'Nessun figlio associato a questa anagrafica genitore.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.slate500,
              ),
            ),
            const SizedBox(height: 24),
            _buildManageButton('AGGIUNGI FIGLI'),
          ],
        ),
      ),
    );
  }

  // The residence type and street name are stored separately but read as one
  // line, so they are joined here rather than shown as two rows.
  String _residenceAddress(ChildItem child)
  {
    final joined = '${child.residenceType?.trim() ?? ''} ${child.address?.trim() ?? ''}'.trim();

    return joined.isEmpty ? missingValue : joined;
  }

  // Full width card telling whether the current parent may collect this child.
  Widget _buildAuthorizationCard(ChildItem child)
  {
    return SizedBox(
      width: double.infinity,
      child: PersonDetailCard(
        title: 'Autorizzazione al ritiro',
        icon: Icons.how_to_reg_outlined,
        rows: [
          DetailRowData('Autorizzato', child.authorizedPickup ? 'Sì' : 'No'),
          if (!child.authorizedPickup)
            DetailRowData('Motivo', orDash(child.pickupRestrictionReason)),
        ],
      ),
    );
  }

  List<Widget> _buildDetailCards(ChildItem child)
  {
    final birthDate = child.birthDate != null
        ? DateFormat('dd/MM/yyyy').format(child.birthDate!)
        : missingValue;

    return [
      // Stacks vertically below the breakpoint, the same policy as PersonInfoTab.
      PersonDetailCardPair(
        first: PersonDetailCard(
          title: 'Identità',
          icon: Icons.badge_rounded,
          rows: [
            DetailRowData('Nome', child.firstName),
            DetailRowData('Cognome', child.lastName),
            DetailRowData('Sesso', orDash(child.gender)),
            DetailRowData('Codice fiscale', child.fiscalCode),
            null,
          ],
        ),
        second: PersonDetailCard(
          title: 'Residenza',
          icon: Icons.home_rounded,
          rows: [
            DetailRowData('Indirizzo', _residenceAddress(child)),
            DetailRowData('N°', orDash(child.addressNumber)),
            DetailRowData('Città', orDash(child.city)),
            DetailRowData('Provincia', orDash(child.province)),
            DetailRowData('CAP', orDash(child.zipCode)),
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
            DetailRowData('Città di nascita', orDash(child.birthCity)),
            DetailRowData('Provincia', orDash(child.birthProvince)),
          ],
        ),
        second: PersonDetailCard(
          title: 'Contatti',
          icon: Icons.alternate_email_rounded,
          rows: [
            DetailRowData('Email', orDash(child.email)),
            DetailRowData('Telefono', orDash(child.phoneNumber)),
            null,
          ],
        ),
      ),
      const SizedBox(height: 24),
      _buildAuthorizationCard(child),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isRefreshing)
    {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final children = _currentPerson.children ?? [];

    if (children.isEmpty)
    {
      return _buildEmptyState();
    }

    // Guards against a selection left over from a longer list, for instance
    // after removing the child that was being shown.
    if (_selectedChildIndex >= children.length)
    {
      _selectedChildIndex = 0;
    }

    final child = children[_selectedChildIndex];

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
                  for (final item in children) '${item.firstName} ${item.lastName}',
                ],
                selectedIndex: _selectedChildIndex,
                onSelected: (index) => setState(() => _selectedChildIndex = index),
              ),
              ..._buildDetailCards(child),
              const SizedBox(height: 48),
              Center(child: _buildManageButton('GESTISCI FIGLI')),
            ],
          ),
        ),
      ),
    );
  }
}
class ChildrenEditDialog extends StatefulWidget
{
  final PersonItem person;

  const ChildrenEditDialog({super.key, required this.person});

  @override
  State<ChildrenEditDialog> createState() => _ChildrenEditDialogState();
}

class _ChildrenEditDialogState extends State<ChildrenEditDialog>
{
  static const double _contentMaxWidth = 1320;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, ParentalRelationshipDraft> _selectedMinors = {};

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  List<PersonItem> _allMinors = [];

  String _searchText = '';
  _MinorSort _sort = _MinorSort.surnameAsc;
  String? _filterRole;

  @override
  void initState()
  {
    super.initState();
    _initSelectedMinors();
    _loadAllData();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  void _initSelectedMinors()
  {
    for (final child in widget.person.children ?? <ChildItem>[])
    {
      _selectedMinors[child.fiscalCode] = ParentalRelationshipDraft(
        taxCode: child.fiscalCode,
        authorizedPickup: child.authorizedPickup,
        restrictionReason: child.pickupRestrictionReason,
      );
    }
  }

  // Candidates are the minors plus whoever is already a child of this person:
  // an existing relationship stays editable even after the child turns adult.
  bool _isCandidate(PersonItem person)
  {
    if (person.fiscalCode == widget.person.fiscalCode)
    {
      return false;
    }

    final isMinor = person.age != null && person.age! < _adultAge;
    final isAlreadyChild =
        widget.person.children?.any((child) => child.fiscalCode == person.fiscalCode) ?? false;

    return isMinor || isAlreadyChild;
  }

  Future<void> _loadAllData() async
  {
    try
    {
      final allPeople = await ApiService().getPeople();

      if (mounted)
      {
        setState(()
        {
          _allMinors = allPeople.where(_isCandidate).toList();
          _isLoadingData = false;
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _onCardTap(PersonItem minor) async
  {
    final draft = await showAuthorizedPickupDialog(
      context,
      personTaxCode: minor.fiscalCode,
      parentName: '${widget.person.firstName} ${widget.person.lastName}',
      childName: '${minor.firstName} ${minor.lastName}',
      existing: _selectedMinors[minor.fiscalCode],
    );

    if (draft != null && mounted)
    {
      setState(() => _selectedMinors[minor.fiscalCode] = draft);
    }
  }

  // "Solo Associato" means exactly that: a student or a teacher is a member too,
  // but must not appear under this filter. Every other option is a plain match on
  // the role label, compared case insensitively.
  bool _matchesRole(PersonItem minor)
  {
    final role = _filterRole;

    if (role == null)
    {
      return true;
    }

    if (role == _memberOnlyFilterValue)
    {
      return RoleLabelMapper.hasOnlyMemberRole(minor.roles);
    }

    final normalized = role.trim().toUpperCase();

    return minor.roles.any((label) => label.trim().toUpperCase() == normalized);
  }

  List<PersonItem> get _filteredMinors
  {
    final query = _searchText.toLowerCase();

    final result = _allMinors.where((minor)
    {
      final fullName = '${minor.firstName} ${minor.lastName}'.toLowerCase();

      return fullName.contains(query) && _matchesRole(minor);
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  PersonItem? _findMinor(String fiscalCode)
  {
    for (final minor in _allMinors)
    {
      if (minor.fiscalCode == fiscalCode)
      {
        return minor;
      }
    }

    return null;
  }

  List<ParentItem> _otherParentsOf(PersonItem minor)
  {
    return (minor.parents ?? [])
        .where((parent) => parent.fiscalCode != widget.person.fiscalCode)
        .toList();
  }

  // Removing a relationship is refused when it would leave a minor with no
  // parent at all, and only warned about when the child is already an adult.
  String? _validateRemovals()
  {
    var hasAdultRemoval = false;

    for (final child in widget.person.children ?? <ChildItem>[])
    {
      if (_selectedMinors.containsKey(child.fiscalCode))
      {
        continue;
      }

      final minor = _findMinor(child.fiscalCode);

      if (minor == null)
      {
        continue;
      }

      if (minor.age == null || minor.age! >= _adultAge)
      {
        hasAdultRemoval = true;
        continue;
      }

      if (minor.parents != null && _otherParentsOf(minor).isEmpty)
      {
        return 'Impossibile rimuovere il figlio: ${minor.firstName} ${minor.lastName} '
            'rimarrebbe senza genitori.';
      }
    }

    if (hasAdultRemoval)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Attenzione: rimuovendo il figlio si perdono le responsabilità '
            'genitoriali su un figlio maggiorenne.',
        isError: false,
      );
    }

    return null;
  }

  // A minor cannot have more than two parents, so adding this one has to leave
  // room for it.
  String? _validateAdditions()
  {
    for (final fiscalCode in _selectedMinors.keys)
    {
      final minor = _findMinor(fiscalCode);

      if (minor == null)
      {
        continue;
      }

      if (_otherParentsOf(minor).length >= _maxParentsPerMinor)
      {
        return 'Impossibile aggiungere ${minor.firstName} ${minor.lastName}: '
            'ha già due genitori associati.';
      }
    }

    return null;
  }

  // The endpoint takes the whole person, so the unchanged fields are sent back
  // as they are: omitting one would clear it server side.
  Map<String, dynamic> _buildPayload()
  {
    final person = widget.person;

    return {
      'general_data': {
        'first_name': person.firstName,
        'last_name': person.lastName,
        'tax_code': person.fiscalCode,
        'gender': person.gender,
        'birth_date': person.birthDate != null
            ? DateFormat('yyyy-MM-dd').format(person.birthDate!)
            : null,
        'birth_city': person.birthCity,
        'birth_province': person.birthProvince,
        'residence_type': person.residenceType,
        'residence_address': person.address,
        'residence_street_number': person.addressNumber,
        'residence_city': person.city,
        'residence_province': person.province,
        'postal_code': person.zipCode,
        'email': person.email,
        'phone': person.phoneNumber,
      },
      'roles': person.roles,
      'relationships': {
        'minors_tax_codes': _selectedMinors.values.map((draft) => draft.toJson()).toList(),
        'parents_tax_codes': (person.parents ?? [])
            .map((parent) => ParentalRelationshipDraft(
                  taxCode: parent.fiscalCode,
                  authorizedPickup: parent.authorizedPickup,
                  restrictionReason: parent.pickupRestrictionReason,
                ).toJson())
            .toList(),
      },
    };
  }

  Future<void> _onSave() async
  {
    final removalError = _validateRemovals();

    if (removalError != null)
    {
      CustomSnackBar.show(context: context, message: removalError, isError: true);
      return;
    }

    final additionError = _validateAdditions();

    if (additionError != null)
    {
      CustomSnackBar.show(context: context, message: additionError, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try
    {
      await ApiService().updatePerson(widget.person.fiscalCode, _buildPayload());

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Associazione figli aggiornata con successo!',
          isError: false,
        );

        Navigator.of(context).pop(true);
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

  Widget _buildHeader()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 24, right: 24, left: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Gestisci Figli',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildFilters()
  {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
        // Side by side when there is room, stacked only below the threshold.
        child: _ResponsiveSearchFilterRow(
          breakpoint: 750,
          searchBar: WizardAnimatedSearchBar(
            controller: _searchController,
            hintText: 'Cerca minore...',
            onChanged: (value) => setState(() => _searchText = value),
          ),
          filterWidgets: [
            WizardFilterMenu<_MinorSort>(
              hint: 'Ordina per',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 180,
              showClearIcon: false,
              onClear: () {},
              onChanged: (value) => setState(() => _sort = value),
              options: _MinorSort.values
                  .map((sort) => WizardFilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            WizardFilterMenu<String>(
              hint: 'Tutti i ruoli',
              icon: Icons.badge_outlined,
              value: _filterRole,
              menuWidth: 200,
              showClearIcon: true,
              onChanged: (value) => setState(() => _filterRole = value),
              onClear: () => setState(() => _filterRole = null),
              options: [
                WizardFilterOption(value: 'STUDENTE', label: 'Studente'),
                WizardFilterOption(value: 'CORSISTA', label: 'Corsista'),
                WizardFilterOption(value: 'DOCENTE', label: 'Docente'),
                WizardFilterOption(value: _memberOnlyFilterValue, label: 'Solo Associato'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinorsGrid(List<PersonItem> minors)
  {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: minors.map((minor)
              {
                final isSelected = _selectedMinors.containsKey(minor.fiscalCode);

                return WizardSelectablePersonCard(
                  person: minor,
                  isSelected: isSelected,
                  onTap: () => _onCardTap(minor),
                  onEdit: isSelected ? () => _onCardTap(minor) : null,
                  onRemove: isSelected
                      ? () => setState(() => _selectedMinors.remove(minor.fiscalCode))
                      : null,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final minors = _filteredMinors;
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
                  _buildHeader(),
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
                            child: _isLoadingData
                                ? const Center(
                                    child: CircularProgressIndicator(color: AppTheme.primary),
                                  )
                                : _buildMinorsGrid(minors),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 32, left: 32, right: 32),
                    child: Center(
                      child: _ResponsiveDialogButtonsRow(
                        cancelText: 'ANNULLA',
                        cancelIcon: Icons.close_rounded,
                        cancelColor: AppTheme.danger,
                        cancelHoverColor: AppTheme.dangerHover,
                        cancelOnPressed: () => Navigator.of(context).pop(),
                        confirmText: _isSubmitting ? 'SALVATAGGIO...' : 'SALVA MODIFICHE',
                        confirmIcon: Icons.check_circle_outline,
                        confirmColor: AppTheme.primary,
                        confirmHoverColor: AppTheme.primaryHover,
                        confirmOnPressed: _isSubmitting ? () {} : _onSave,
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

// Bottom bar of the manage dialog. Unlike the shared ResponsiveDialogButtonsRow
// it centres two fixed width buttons instead of stretching them, and builds the
// buttons itself from the wizard component set.
class _ResponsiveDialogButtonsRow extends StatelessWidget
{
  static const double _buttonWidth = 230;
  static const double _spacing = 24;

  // Below the width of both buttons plus their gap and some slack there is no
  // room for a row, so the two stack with the confirm action on top.
  static const double _breakpoint = _buttonWidth * 2 + _spacing + 40;

  final String cancelText;
  final IconData cancelIcon;
  final Color cancelColor;
  final Color cancelHoverColor;
  final VoidCallback cancelOnPressed;

  final String confirmText;
  final IconData confirmIcon;
  final Color confirmColor;
  final Color confirmHoverColor;
  final VoidCallback confirmOnPressed;

  const _ResponsiveDialogButtonsRow({
    required this.cancelText,
    required this.cancelIcon,
    required this.cancelColor,
    required this.cancelHoverColor,
    required this.cancelOnPressed,
    required this.confirmText,
    required this.confirmIcon,
    required this.confirmColor,
    required this.confirmHoverColor,
    required this.confirmOnPressed,
  });

  @override
  Widget build(BuildContext context)
  {
    final cancelButton = SizedBox(
      width: _buttonWidth,
      child: WizardAnimatedActionButton(
        text: cancelText,
        icon: cancelIcon,
        baseColor: cancelColor,
        hoverColor: cancelHoverColor,
        onPressed: cancelOnPressed,
      ),
    );

    final confirmButton = SizedBox(
      width: _buttonWidth,
      child: WizardAnimatedActionButton(
        text: confirmText,
        icon: confirmIcon,
        baseColor: confirmColor,
        hoverColor: confirmHoverColor,
        onPressed: confirmOnPressed,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
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
          mainAxisAlignment: MainAxisAlignment.center,
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
              SizedBox(height: _spacing),
              Wrap(spacing: _spacing, runSpacing: _spacing, children: filterWidgets),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchBar),
            for (final filter in filterWidgets) ...[
              SizedBox(width: _spacing),
              filter,
            ],
          ],
        );
      },
    );
  }
}