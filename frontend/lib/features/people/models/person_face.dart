import '../../../core/utils/alphabetical_order.dart';

// The minimum needed to draw a person's avatar; implemented by PersonItem and
// PersonOptionItem.
abstract interface class PersonFace
{
  String get firstName;
  String get lastName;
  String? get profileImageUrl;
}

int compareByName(PersonFace a, PersonFace b)
{
  return compareAlphabeticallyInParts([a.firstName, a.lastName], [b.firstName, b.lastName]);
}

int compareBySurname(PersonFace a, PersonFace b)
{
  return compareAlphabeticallyInParts([a.lastName, a.firstName], [b.lastName, b.firstName]);
}
