import 'package:flutter/material.dart';

import '../../../shared/widgets/card_scroll_area.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/filter_menu.dart' show FilterOption;
import '../../../shared/widgets/snackbar.dart';
import '../models/parental_relationship_draft.dart';
import '../models/person_item.dart';
import '../widgets/authorized_pickup_dialog.dart';
import '../widgets/person_detail_widgets.dart';

// Picking the people tied to this one: a minor's parents, or the minors they
// are a parent of. The cards are the ones from the dedicated dialogs — same
// face, same search, same ordering — because it is the same question asked from
// another point of the app.

enum PersonPickerSort
{
  surnameAsc('Cognome (A-Z)'),
  surnameDesc('Cognome (Z-A)'),
  nameAsc('Nome (A-Z)'),
  nameDesc('Nome (Z-A)'),
  dateDesc('Più recente'),
  dateAsc('Meno recente');

  final String label;

  const PersonPickerSort(this.label);

  int compare(PersonItem a, PersonItem b)
  {
    return switch (this)
    {
      PersonPickerSort.surnameAsc => a.lastName.compareTo(b.lastName),
      PersonPickerSort.surnameDesc => b.lastName.compareTo(a.lastName),
      PersonPickerSort.nameAsc => a.firstName.compareTo(b.firstName),
      PersonPickerSort.nameDesc => b.firstName.compareTo(a.firstName),
      PersonPickerSort.dateDesc => b.createdAt.compareTo(a.createdAt),
      PersonPickerSort.dateAsc => a.createdAt.compareTo(b.createdAt),
    };
  }
}

class PersonEditPeopleCard extends StatefulWidget
{
  final List<PersonItem> people;

  /// Chi è scelto, con la sua autorizzazione al ritiro.
  final Map<String, ParentalRelationshipDraft> selected;

  // The name of the person being edited: needed by the pickup question, which
  // names both the parent and the child.
  final String personName;

  // True when the person's parents are being picked: it swaps who is parent and
  // who is child in the question, and applies the cap of two.
  final bool pickingParents;

  final String searchHint;
  final String emptyMessage;
  final VoidCallback onChanged;

  // Opens the dialog that creates the missing person on the spot and returns
  // what the server will have to create. Null where that is not allowed: editing
  // an existing person's details, people are picked and not invented.
  final Future<Map<String, dynamic>?> Function()? onCreateMissing;

  // What the button opening it is called.
  final String createLabel;

  const PersonEditPeopleCard({
    super.key,
    required this.people,
    required this.selected,
    required this.personName,
    required this.pickingParents,
    required this.searchHint,
    required this.emptyMessage,
    required this.onChanged,
    this.onCreateMissing,
    this.createLabel = '',
  });

  @override
  State<PersonEditPeopleCard> createState() => _PersonEditPeopleCardState();
}

class _PersonEditPeopleCardState extends State<PersonEditPeopleCard>
{
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  PersonPickerSort _sort = PersonPickerSort.surnameAsc;

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  List<PersonItem> get _filtered
  {
    final String query = _query.toLowerCase();

    final List<PersonItem> result = widget.people.where((person)
    {
      return '${person.firstName} ${person.lastName}'.toLowerCase().contains(query);
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  String _nameOf(PersonItem person) => '${person.firstName} ${person.lastName}';

  Future<void> _open(PersonItem person) async
  {
    final bool wasSelected = widget.selected.containsKey(person.fiscalCode);

    // Two parents is the maximum: a third is not added silently.
    if (!wasSelected && widget.pickingParents && widget.selected.length >= 2)
    {
      CustomSnackBar.show(
        context: context,
        message: 'Un minore può avere al massimo due genitori o tutori.',
        isError: true,
      );

      return;
    }

    final ParentalRelationshipDraft? draft = await showAuthorizedPickupDialog(
      context,
      personTaxCode: person.fiscalCode,
      parentName: widget.pickingParents ? _nameOf(person) : widget.personName,
      childName: widget.pickingParents ? widget.personName : _nameOf(person),
      existing: widget.selected[person.fiscalCode],
    );

    if (draft == null)
    {
      return;
    }

    widget.selected[person.fiscalCode] = draft;
    widget.onChanged();
    setState(() {});
  }

  // Someone not yet on the books is created here and picked at once: on save
  // they reach the server before the person they are tied to.
  Future<void> _createMissing() async
  {
    final Map<String, dynamic>? created = await widget.onCreateMissing!();

    if (created == null || !mounted)
    {
      return;
    }

    final PersonItem person = created['person'] as PersonItem;

    widget.people.add(person);

    final ParentalRelationshipDraft? draft = await showAuthorizedPickupDialog(
      context,
      personTaxCode: person.fiscalCode,
      parentName: widget.pickingParents ? _nameOf(person) : widget.personName,
      childName: widget.pickingParents ? widget.personName : _nameOf(person),
    );

    widget.selected[person.fiscalCode] = draft ??
        ParentalRelationshipDraft(taxCode: person.fiscalCode);

    widget.onChanged();
    setState(() {});
  }

  void _remove(PersonItem person)
  {
    widget.selected.remove(person.fiscalCode);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context)
  {
    final List<PersonItem> people = _filtered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _searchController,
          hintText: widget.searchHint,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppFilterPill<PersonPickerSort>.setting(
              prefix: 'Ordina',
              hint: 'Ordina',
              icon: Icons.sort_rounded,
              value: _sort,
              menuWidth: 200,
              onChanged: (value) => setState(() => _sort = value),
              options: PersonPickerSort.values
                  .map((sort) => FilterOption(value: sort, label: sort.label))
                  .toList(),
            ),
            if (widget.onCreateMissing != null)
              AppGradientButton(
                label: widget.createLabel,
                icon: Icons.person_add_alt_1_rounded,
                height: 44,
                radius: 22,
                fontSize: 13,
                onPressed: _createMissing,
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (people.isEmpty)
          PersonEmptyState(message: widget.emptyMessage)
        else
          CardScrollArea(
            padding: const EdgeInsets.symmetric(vertical: kPersonGridShadowRoom),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final person in people)
                  PersonPickerCard(
                    key: ValueKey(person.fiscalCode),
                    person: person,
                    isSelected: widget.selected.containsKey(person.fiscalCode),
                    onTap: () => _open(person),
                    onEdit: widget.selected.containsKey(person.fiscalCode)
                        ? () => _open(person)
                        : null,
                    onRemove: widget.selected.containsKey(person.fiscalCode)
                        ? () => _remove(person)
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
