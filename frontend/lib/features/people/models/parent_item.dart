class ParentItem 
{
  final String  fiscalCode;
  final String  firstName;
  final String  lastName;
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

  const ParentItem({
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
  });

  factory ParentItem.fromJson(Map<String, dynamic> json) 
  {
    return ParentItem(
      fiscalCode:    json['fiscal_code'] ?? '',
      firstName:     json['first_name'] ?? '',
      lastName:      json['last_name'] ?? '',
      gender:        json['gender'],
      email:         json['email'],
      phoneNumber:   json['phone'],
      birthCity:     json['birth_city'],
      birthProvince: json['birth_province'],
      residenceType: json['residence_type'],
      address:       json['residence_address'],
      addressNumber: json['residence_street_number'],
      province:      json['residence_province'],
      zipCode:       json['postal_code'],
      city:          json['city'],
      birthDate:     json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
    );
  }
}