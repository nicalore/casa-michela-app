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
    );
  }
}