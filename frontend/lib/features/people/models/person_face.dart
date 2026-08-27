// The minimum needed to draw a person's avatar; implemented by PersonItem and
// PersonOptionItem.
abstract interface class PersonFace
{
  String get firstName;
  String get lastName;
  String? get profileImageUrl;
}
