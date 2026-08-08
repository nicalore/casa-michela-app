// The little it takes to show a person's face: what they are called and where
// their photo is.
//
// A person's record knows everything (PersonItem); an availability or a request
// carries the bare minimum (PersonOptionItem). The circle on screen is the same
// in both cases, and this is all it needs to know to draw it.
abstract interface class PersonFace
{
  String get firstName;
  String get lastName;
  String? get profileImageUrl;
}
