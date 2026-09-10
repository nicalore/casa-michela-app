import 'package:intl/intl.dart';

import '../../../core/utils/phone_number.dart';
import '../models/membership_item.dart';
import '../models/person_item.dart';
import 'person_edit_form.dart';

// One enrolment form per person the wizard creates who actually joins; register picks and non-member parents get none.

final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

const String _roleParent = 'GENITORE';

class EnrollmentForm
{
  const EnrollmentForm({required this.personName, required this.request});

  final String personName;

  final Map<String, dynamic> request;

  // The early exit form prints beside the enrolment one; the wizard grants leave only to a minor.
  bool get needsEarlyExitForm
  {
    final person = request['person'] as Map<String, dynamic>;
    final student = person['student_data'] as Map<String, dynamic>?;

    return student != null && student['authorized_early_exit'] == true;
  }
}

// Cheap enough for build(): reads roles and membership rows, never assembles a payload.
bool needsEnrollmentForms(PersonEditForm form)
{
  if (!form.isOnlyParentNotMember && form.isEnrolledByRows)
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

  // The rate rides inside student_data with the rest of the pupil's record.
  return EnrollmentForm(
    personName: '${general['first_name']} ${general['last_name']}'.trim(),
    request: {'person': payload, 'parents': parents},
  );
}

// A parent-only role means membership was declined; a membership already expired prints nothing.
bool _joins(Map<String, dynamic> payload)
{
  final List<String> roles = (payload['roles'] as List).cast<String>();

  if (!roles.any((role) => role != _roleParent))
  {
    return false;
  }

  return _standsToday(payload['member_data'] as Map<String, dynamic>?);
}

// Newest membership, not revoked and still inside its renewal window: the rule the register applies.
bool _standsToday(Map<String, dynamic>? memberData)
{
  Map<String, dynamic>? latest;
  int? latestYear;

  for (final dynamic entry in (memberData?['memberships'] as List?) ?? const [])
  {
    final Map<String, dynamic> membership = entry as Map<String, dynamic>;
    final int year = membership['year'] as int;

    if (latestYear == null || year > latestYear)
    {
      latestYear = year;
      latest = membership;
    }
  }

  if (latest == null || latest['revocation'] != MembershipItem.revocationNone)
  {
    return false;
  }

  return MembershipItem.isWithinRenewalWindow(
    DateTime.parse(latest['end_date'] as String),
    latest['renewal_period_days'] as int,
  );
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

// A minor created on the fly has exactly one parent: the person being created around them.
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

// Pending people first: the PersonItem fabricated for the picker carries five fields, its payload the whole entry.
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

// Same key names as the wizard's general_data; every value may be null.
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
