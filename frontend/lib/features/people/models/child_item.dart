import '../../../core/utils/birthday.dart';
import '../../../core/utils/json_parsing.dart';
import 'person_face.dart';

class ChildItem implements PersonFace
{
  final String fiscalCode;

  @override
  final String firstName;

  @override
  final String lastName;

  final String? gender;
  final String? email;
  final String? phoneNumber;
  final String? birthCity;
  final String? birthProvince;
  final String? residenceType;
  final String? address;
  final String? addressNumber;
  final String? province;
  final String? zipCode;
  final String? city;
  final DateTime? birthDate;

  @override
  final String? profileImageUrl;

  final List<String> roles;
  final String? schoolName;
  final String? schoolClass;
  final String? studyProgram;
  final String? courseType;
  final DateTime? medicalCertificateExpiration;

  // Describe the relation with the current parent, not the child in general:
  // the same child can be collectable by one parent and not by another.
  final bool authorizedPickup;
  final String? pickupRestrictionReason;

  const ChildItem({
    required this.fiscalCode,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.email,
    this.phoneNumber,
    this.birthCity,
    this.birthProvince,
    this.residenceType,
    this.address,
    this.addressNumber,
    this.province,
    this.zipCode,
    this.city,
    this.birthDate,
    this.profileImageUrl,
    this.roles = const [],
    this.schoolName,
    this.schoolClass,
    this.studyProgram,
    this.courseType,
    this.medicalCertificateExpiration,
    this.authorizedPickup = true,
    this.pickupRestrictionReason,
  });

  int? get age => ageToday(birthDate);

  factory ChildItem.fromJson(Map<String, dynamic> json)
  {
    return ChildItem(
      fiscalCode: json['fiscal_code'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'],
      email: json['email'],
      phoneNumber: json['phone'],
      birthCity: json['birth_city'],
      birthProvince: json['birth_province'],
      residenceType: json['residence_type'],
      address: json['residence_address'],
      addressNumber: json['residence_street_number'],
      province: json['residence_province'],
      zipCode: json['postal_code'],
      city: json['city'],
      birthDate: parseDate(json['birth_date']),
      profileImageUrl: json['profile_image_url'],
      roles: parseStringList(json['roles']),
      schoolName: json['school_name'],
      schoolClass: json['school_class'],
      studyProgram: json['study_program'],
      courseType: json['course_type'],
      medicalCertificateExpiration: parseDate(json['medical_certificate_expiration']),
      authorizedPickup: json['authorized_pickup'] ?? true,
      pickupRestrictionReason: json['pickup_restriction_reason'],
    );
  }
}