import 'package:intl/intl.dart';

import '../../../core/utils/phone_number.dart';
import '../models/person_item.dart';
import 'person_edit_form.dart';

// Which enrolment forms a run of the wizard has to print, and the body of the
// POST behind each one. The rule is one form per person the wizard is about to
// create who is actually joining: someone picked from the register is already
// on file, and a parent who declined membership has nothing to enrol into.

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

const String _roleParent = 'GENITORE';

class EnrollmentForm
{
  const EnrollmentForm({required this.personName, required this.request});

  final String personName;

  final Map<String, dynamic> request;
}

// Cheap enough for build(): it reads roles, and never assembles a payload.
bool needsEnrollmentForms(PersonEditForm form)
{
  if (!form.isOnlyParentNotMember)
  {
    return true;
  }

  return form.pendingPeople.any((pending) => _joins(_payloadOf(pending)));
}

List<EnrollmentForm> buildEnrollmentForms(PersonEditForm form)
{
  final Map<String, dynamic> main = form.buildCreatePayload();
  final List<EnrollmentForm> forms = [];

  // Pending people first, the order in which they reach the server.
  for (final Map<String, dynamic> pending in form.pendingPeople)
  {
    final Map<String, dynamic> payload = _payloadOf(pending);

    if (_joins(payload))
    {
      forms.add(_formOf(payload, parents: _parentsOfPending(form, main, payload)));
    }
  }

  if (_joins(main))
  {
    forms.add(_formOf(main, parents: _parentsOfMain(form)));
  }

  return forms;
}

EnrollmentForm _formOf(
  Map<String, dynamic> payload, {
  required List<Map<String, dynamic>> parents,
})
{
  final Map<String, dynamic> general = _generalOf(payload);

  return EnrollmentForm(
    personName: '${general['first_name']} ${general['last_name']}'.trim(),
    request: {'person': payload, 'parents': parents},
  );
}

// Someone whose only role is being a parent has declined membership; anyone
// else the wizard creates is joining, and joining is what the form is for.
bool _joins(Map<String, dynamic> payload)
{
  final List<String> roles = (payload['roles'] as List).cast<String>();

  return roles.any((role) => role != _roleParent);
}

Map<String, dynamic> _payloadOf(Map<String, dynamic> pending) =>
    pending['payload'] as Map<String, dynamic>;

Map<String, dynamic> _generalOf(Map<String, dynamic> payload) =>
    payload['general_data'] as Map<String, dynamic>;

List<Map<String, dynamic>> _parentsOfMain(PersonEditForm form)
{
  final List<Map<String, dynamic>> parents = [];

  for (final String taxCode in form.selectedParents.keys)
  {
    final Map<String, dynamic>? general = _parentGeneralData(form, taxCode);

    if (general != null)
    {
      parents.add(general);
    }
  }

  return parents;
}

// The nested wizards ask nothing about relations, so a minor created on the
// fly has exactly one parent to name: the person being created around them.
List<Map<String, dynamic>> _parentsOfPending(
  PersonEditForm form,
  Map<String, dynamic> main,
  Map<String, dynamic> payload,
)
{
  final String? taxCode = _generalOf(payload)['tax_code'] as String?;
  final bool isTheirChild =
      taxCode != null && form.selectedMinors.containsKey(taxCode);

  if (!isTheirChild || !form.selectedRoles.contains(_roleParent))
  {
    return const [];
  }

  return [_generalOf(main)];
}

// Pending people first: one created inside this wizard is in both places, but
// the PersonItem fabricated for the picker carries five fields, while its
// payload carries the whole registry entry.
Map<String, dynamic>? _parentGeneralData(PersonEditForm form, String taxCode)
{
  for (final Map<String, dynamic> pending in form.pendingPeople)
  {
    final Map<String, dynamic> general = _generalOf(_payloadOf(pending));

    if (general['tax_code'] == taxCode)
    {
      return general;
    }
  }

  for (final PersonItem adult in form.allAdults)
  {
    if (adult.fiscalCode == taxCode)
    {
      return _generalDataOf(adult);
    }
  }

  return null;
}

// Same key names as the wizard's own general_data; every one of them may be
// null, because a registry entry made before a field existed still prints.
Map<String, dynamic> _generalDataOf(PersonItem person)
{
  return {
    'first_name': person.firstName,
    'last_name': person.lastName,
    'tax_code': person.fiscalCode,
    'gender': person.gender,
    'birth_date': person.birthDate != null ? _isoDate.format(person.birthDate!) : null,
    'birth_city': person.birthCity,
    'birth_nation': person.birthNation,
    'birth_province': person.birthProvince?.toUpperCase(),
    'residence_type': person.residenceType,
    'residence_address': person.address,
    'residence_street_number': person.addressNumber,
    'residence_city': person.city,
    'residence_province': person.province?.toUpperCase(),
    'postal_code': person.zipCode,
    'email': person.email,
    'phone': person.phoneNumber != null ? barePhoneNumber(person.phoneNumber) : null,
  };
}
