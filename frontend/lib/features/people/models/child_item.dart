import '../../../core/utils/json_parsing.dart';

class ChildItem
{
  final String fiscalCode;
  final String firstName;
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
  final String? schoolName;
  final String? schoolClass;
  final String? studyProgram;

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
    this.schoolName,
    this.schoolClass,
    this.studyProgram,
    this.authorizedPickup = true,
    this.pickupRestrictionReason,
  });

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
      schoolName: json['school_name'],
      schoolClass: json['school_class'],
      studyProgram: json['study_program'],
      authorizedPickup: json['authorized_pickup'] ?? true,
      pickupRestrictionReason: json['pickup_restriction_reason'],
    );
  }
}