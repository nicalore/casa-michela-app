class MeResponse
{
  final String taxCode;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? profileImageUrl;
  final List<String> availableRoles;
  final String activeRole;
  final String status;
  final bool passwordResetRequired;

  final String? gender;
  final String? email;
  final String? phoneNumber;
  final DateTime? birthDate;
  final String? birthCity;
  final String? birthProvince;
  final String? address;
  final String? addressNumber;
  final String? city;
  final String? province;
  final String? zipCode;

  const MeResponse({
    required this.taxCode,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.profileImageUrl,
    required this.availableRoles,
    required this.activeRole,
    required this.status,
    required this.passwordResetRequired,
    this.gender,
    this.email,
    this.phoneNumber,
    this.birthDate,
    this.birthCity,
    this.birthProvince,
    this.address,
    this.addressNumber,
    this.city,
    this.province,
    this.zipCode,
  });

  //ConstructFromJson
  factory MeResponse.fromJson(Map<String, dynamic> json)
  {
    return MeResponse(
      taxCode: json['tax_code'],
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      fullName: json['full_name'],
      profileImageUrl: json['profile_image_url'],
      availableRoles: List<String>.from(json['available_roles']),
      activeRole: json['active_role'],
      status: json['status'],
      passwordResetRequired: json['password_reset_required'],
      gender: json['gender'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      birthDate: json['birth_date'] != null ? DateTime.tryParse(json['birth_date']) : null,
      birthCity: json['birth_city'],
      birthProvince: json['birth_province'],
      address: json['address'],
      addressNumber: json['address_number'],
      city: json['city'],
      province: json['province'],
      zipCode: json['zip_code'],
    );
  }
}