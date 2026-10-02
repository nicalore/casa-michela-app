import '../../../core/utils/birthday.dart';
import '../../../core/utils/json_parsing.dart';
import 'person_face.dart';

class ParentItem implements PersonFace
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
  final String? birthNation;
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

  final bool hasAccount;

  // Both describe the ParentalResponsibility relation between this parent and
  // the person the list was built for, not the parent in general.
  final bool authorizedPickup;
  final String? pickupRestrictionReason;

  const ParentItem({
    required this.fiscalCode,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.email,
    this.phoneNumber,
    this.birthCity,
    this.birthNation,
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
    this.hasAccount = false,
    this.authorizedPickup = true,
    this.pickupRestrictionReason,
  });

  int? get age => ageToday(birthDate);

  factory ParentItem.fromJson(Map<String, dynamic> json)
  {
    return ParentItem(
      fiscalCode: json['fiscal_code'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'],
      email: json['email'],
      phoneNumber: json['phone'],
      birthCity: json['birth_city'],
      birthNation: json['birth_nation'],
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
      hasAccount: json['has_account'] == true,
      authorizedPickup: json['authorized_pickup'] ?? true,
      pickupRestrictionReason: json['pickup_restriction_reason'],
    );
  }
}