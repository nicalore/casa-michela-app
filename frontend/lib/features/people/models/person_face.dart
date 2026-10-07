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
  String key(PersonFace face) => '${face.firstName} ${face.lastName}'.toLowerCase();

  return key(a).compareTo(key(b));
}
