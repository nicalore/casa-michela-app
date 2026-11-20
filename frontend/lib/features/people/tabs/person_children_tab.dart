import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/filter_menu.dart' show FilterOption;
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/child_item.dart';
import '../models/parent_item.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_face.dart';
import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/authorized_pickup_dialog.dart';
import '../widgets/relative_card.dart';

String get _peopleLoadFailed => tr('Impossibile caricare le anagrafiche dal server.', "Couldn't load the people from the server.");

const int _adultAge = 18;
const int _maxParentsPerMinor = 2;

// Roles whose card rows describe the child in place of their contacts.
const Set<String> _describingRoles = {'STUDENTE', 'CORSISTA'};

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

// Derived from the label so a rename in RoleLabelMapper cannot leave this stale.
final String _memberOnlyFilterValue = RoleLabelMapper.memberLabel.toUpperCase();

enum _MinorSort
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
      _MinorSort.nameAsc => compareByName(a, b),
      _MinorSort.nameDesc => compareByName(b, a),
      _MinorSort.surnameAsc => compareBySurname(a, b),
      _MinorSort.surnameDesc => compareBySurname(b, a),
      _MinorSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      _MinorSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

class PersonChildrenTab extends StatefulWidget
{
  final PersonItem person;

  final VoidCallback onUpdate;

  final ValueChanged<String> onOpenPerson;

  const PersonChildrenTab({
    super.key,
    required this.person,
    required this.onUpdate,
    required this.onOpenPerson,
  });

  @override
  State<PersonChildrenTab> createState() => _PersonChildrenTabState();
}

class _PersonChildrenTabState extends State<PersonChildrenTab>
{
  Future<void> _openChildrenEditDialog() async
  {
    final changed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ChildrenEdit',
      builder: (context) => ChildrenEditDialog(person: widget.person),
    );

    if (changed == true)
    {
      widget.onUpdate();
    }
  }

  Widget _buildManageButton(String label)
  {
    return AppGradientButton(
      label: label,
      icon: Icons.family_restroom_rounded,
      onPressed: _openChildrenEditDialog,
    );
  }

  Widget _buildEmptyState()
  {
    return AppEmptyRoom(
      card: AppEmptyCard(
        icon: Icons.family_restroom_rounded,
        message: tr('Nessun figlio associato a questa anagrafica genitore.', "No children linked to this parent's record."),
      ),
      below: [
        PersonLoneButton(
          label: tr('AGGIUNGI FIGLI', 'ADD CHILDREN'),
          icon: Icons.family_restroom_rounded,
          onPressed: _openChildrenEditDialog,
        ),
      ],
    );
  }

  RelativeFact _certificateFact(DateTime? expiration)
  {
    if (expiration == null)
    {
      return RelativeFact(
        Icons.medical_information_rounded,
        tr('Certificato non consegnato', 'Certificate not handed in'),
        isWarning: true,
      );
    }

    final now = romeNow();
    final date = _dateFormat.format(expiration);

    if (expiration.isBefore(DateTime(now.year, now.month, now.day)))
    {
      return RelativeFact(
        Icons.medical_information_rounded,
        tr('Certificato scaduto il $date', 'Certificate expired on $date'),
        isWarning: true,
      );
    }

    return RelativeFact(Icons.medical_information_rounded, tr('Certificato valido fino al $date', 'Certificate valid until $date'));
  }

  // Teachers never get here: their parents are paperwork.
  List<RelativeFact> _roleFacts(ChildItem child, Set<String> roles)
  {
    if (roles.contains('STUDENTE'))
    {
      final school = child.schoolName?.trim() ?? '';
      final program = child.studyProgram;
      final grade = [program == null ? null : studyProgramNameOnlyOf(program), child.schoolClass]
          .map((part) => part?.trim() ?? '')
          .where((part) => part.isNotEmpty)
          .join(' - ');

      return [
        if (school.isNotEmpty) RelativeFact(Icons.school_rounded, school),
        if (grade.isNotEmpty) RelativeFact(Icons.menu_book_rounded, grade),
      ];
    }

    if (roles.contains('CORSISTA'))
    {
      final course = child.courseType?.trim() ?? '';

      return [
        if (course.isNotEmpty) RelativeFact(Icons.self_improvement_rounded, course),
        _certificateFact(child.medicalCertificateExpiration),
      ];
    }

    return const [];
  }

  Widget _buildCard(ChildItem child)
  {
    final age = child.age;
    final isAdult = (age ?? 0) >= _adultAge;
    final roles = child.roles.map((role) => role.toUpperCase()).toSet();
    final roleFacts = _roleFacts(child, roles);

    // A minor's contacts are usually the parent's own.
    final showsContacts = isAdult || !roles.any(_describingRoles.contains);

    final phone = formatPhoneNumber(child.phoneNumber);
    final email = child.email?.trim() ?? '';

    return RelativeCard(
      person: child,
      roles: child.roles,
      feminine: child.gender == 'F',
      facts: [
        if (age != null) RelativeFact(Icons.cake_rounded, ageLabel(age)),
        ...roleFacts,
        if (showsContacts && phone.isNotEmpty) RelativeFact(Icons.call_rounded, phone),
        if (showsContacts && email.isNotEmpty) RelativeFact(Icons.alternate_email_rounded, email),
      ],
      authorizedPickup: isAdult ? null : child.authorizedPickup,
      pickupRestrictionReason: child.pickupRestrictionReason,
      onTap: () => widget.onOpenPerson(child.fiscalCode),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final children = widget.person.children ?? [];

    if (children.isEmpty)
    {
      return _buildEmptyState();
    }

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: pageTransitionBlocks([
                RelativeCardGrid(cards: [for (final child in children) _buildCard(child)]),
                const SizedBox(height: 48),
                _buildManageButton(tr('GESTISCI FIGLI', 'MANAGE CHILDREN')),
              ]),
            ),
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
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ParentalRelationshipDraft> _selectedMinors = {};

  bool _isLoadingData = true;
  Object? _loadFailure;
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

  // An existing relationship stays editable even after the child turns adult.
  // A teacher's parents are chosen from the teacher's record only.
  bool _isCandidate(PersonItem person)
  {
    if (person.fiscalCode == widget.person.fiscalCode || person.isTeacherOnly)
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
          _isLoadingData = false;
          _loadFailure = e;
        });
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

  // "Solo Associato" excludes people who are also student, teacher, etc.
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

  // A minor left with no parent is refused; an adult child only warns.
  String? _validateRemovals()
  {
    final List<PersonItem> adultRemovals = [];

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
        adultRemovals.add(minor);
        continue;
      }

      if (minor.parents != null && _otherParentsOf(minor).isEmpty)
      {
        return tr(
          'Impossibile rimuovere ${minor.gender == 'F' ? 'la figlia' : 'il figlio'}: '
              '${minor.firstName} ${minor.lastName} rimarrebbe senza genitori.',
          "Can't remove ${minor.gender == 'F' ? 'the daughter' : 'the son'}: "
              '${minor.firstName} ${minor.lastName} would be left without parents.',
        );
      }
    }

    if (adultRemovals.isNotEmpty)
    {
      CustomSnackBar.show(context: context, message: _adultRemovalWarning(adultRemovals), isError: false);
    }

    return null;
  }

  String _adultRemovalWarning(List<PersonItem> adults)
  {
    final List<String> names = [for (final adult in adults) '${adult.firstName} ${adult.lastName}'];
    final String listed = names.length == 1
        ? names.single
        : tr(
          '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}',
          '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}',
        );
    final bool allGirls = adults.every((adult) => adult.gender == 'F');

    final String whom = adults.length == 1
        ? (allGirls ? tr('una figlia maggiorenne', 'an adult daughter') : tr('un figlio maggiorenne', 'an adult son'))
        : (allGirls ? tr('figlie maggiorenni', 'adult daughters') : tr('figli maggiorenni', 'adult children'));

    return tr(
      'Attenzione: rimuovendo $listed si perdono le responsabilità genitoriali su $whom.',
      'Warning: removing $listed gives up parental responsibility for $whom.',
    );
  }

  // A minor cannot have more than two parents.
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
        return tr(
          'Impossibile aggiungere ${minor.firstName} ${minor.lastName}: '
              'ha già due genitori associati.',
          "Can't add ${minor.firstName} ${minor.lastName}: "
              'they already have two parents linked.',
        );
      }
    }

    return null;
  }

  // Full-record endpoint: an omitted field is cleared server side.
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
        // Required by GeneralDataUpdate; leaving it out fails the whole call.
        'birth_nation': person.birthNation ?? '',
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
          message: tr('Figli aggiornati con successo!', 'Children updated successfully!'),
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

  Widget _buildFilters()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: tr('Cerca minore...', 'Search minor...'),
          onChanged: (value) => setState(() => _searchText = value),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AppFilterPill<_MinorSort>.setting(
              prefix: tr('Ordina', 'Sort'),
              hint: tr('Ordina', 'Sort'),
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 200,
              onChanged: (value) => setState(() => _sort = value),
              options: _MinorSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            AppFilterPill<String>.filter(
              prefix: tr('Ruolo', 'Role'),
              hint: tr('Tutti i ruoli', 'All roles'),
              icon: Icons.badge_rounded,
              value: _filterRole,
              menuWidth: 220,
              onChanged: (value) => setState(() => _filterRole = value),
              onClear: () => setState(() => _filterRole = null),
              options: [
                FilterOption(value: 'STUDENTE', label: tr('Studente', 'Student')),
                FilterOption(value: 'CORSISTA', label: tr('Corsista', 'Course participant')),
                FilterOption(value: 'DOCENTE', label: tr('Docente', 'Teacher')),
                FilterOption(value: _memberOnlyFilterValue, label: tr('Solo associato', 'Member only')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMinorsGrid(List<PersonItem> minors)
  {
    if (_isLoadingData)
    {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    if (_loadFailure != null)
    {
      return Center(child: AppLoadFailedPanel(error: _loadFailure, message: _peopleLoadFailed, onRetry: _loadAllData));
    }

    if (minors.isEmpty)
    {
      return PersonEmptyState(message: tr('Nessun minore trovato per questa ricerca.', 'No minor found for this search.'));
    }

    return ScrollEdgeFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: kPersonGridShadowRoom),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: minors.map((minor)
          {
            final isSelected = _selectedMinors.containsKey(minor.fiscalCode);

            return PersonPickerCard(
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
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: tr('Figli', 'Children'),
      title: tr('Gestisci figli', 'Manage children'),
      maxWidth: 1160,
      fillLast: true,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: tr('SALVA', 'SAVE'),
          icon: Icons.check_rounded,
          busy: _isSubmitting,
          height: kPersonDialogButtonHeight,
          fontSize: kPersonDialogButtonFontSize,
          onPressed: _onSave,
        ),
      ),
      children: [
        AppDialogPill(expand: true, child: _buildFilters()),
        AppDialogPill(expand: true, child: _buildMinorsGrid(_filteredMinors)),
      ],
    );
  }
}
