import '../../people/models/person_face.dart';

// Minimal person reference, mirroring the backend's PersonOption schema:
// just enough to display and identify a teacher, student or booker.
class PersonOptionItem implements PersonFace
{
  final String taxCode;

  @override
  final String firstName;

  @override
  final String lastName;

  // Where the anagrafica keeps their face. Null for whoever never uploaded one,
  // which is most people: the circle then falls back to their initials.
  @override
  final String? profileImageUrl;

  const PersonOptionItem({
    required this.taxCode,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
  });

  String get fullName => '$firstName $lastName';

  factory PersonOptionItem.fromJson(Map<String, dynamic> json)
  {
    return PersonOptionItem(
      taxCode: json['tax_code'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}
