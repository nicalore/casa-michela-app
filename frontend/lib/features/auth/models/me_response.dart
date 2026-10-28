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

  // First-access flow; the password change is its first step.
  final bool onboardingRequired;

  // The legal documents to accept: the flow's first step, or the only one if it is done.
  final bool termsRequired;

  // When an IT manager asked again someone who had accepted; null otherwise.
  final DateTime? termsUpdatedAt;

  // True for a pupil a parent answers for, not for the parent; their area is narrower.
  final bool hasParentalResponsibility;

  // Such a pupil may book too when the administration allows it; payments stay with the parents.
  final bool autonomousBookings;

  // PRESIDENT, VICE_PRESIDENT, TREASURER or null; mirrors _BOARD_ROLES on the server.
  final String? boardRole;

  // The kinds of report they receive (IT managers, the president); empty for the rest.
  final List<String> reportKinds;

  // IT managers write the app's updates, from their own page.
  final bool managesUpdates;

  // Already converted to the local clock.
  final DateTime? lastLogin;

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

  bool get readsReports => reportKinds.isNotEmpty;

  bool get firstAccessPending => onboardingRequired || termsRequired;

  // Past the first access the changed documents get their own page; within it, the usual step.
  DateTime? get termsUpdate => onboardingRequired ? null : termsUpdatedAt;

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
    this.onboardingRequired = false,
    this.termsRequired = false,
    this.termsUpdatedAt,
    this.hasParentalResponsibility = false,
    this.autonomousBookings = false,
    this.boardRole,
    this.reportKinds = const [],
    this.managesUpdates = false,
    this.lastLogin,
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
      onboardingRequired: json['onboarding_required'] ?? false,
      termsRequired: json['terms_required'] ?? false,
      termsUpdatedAt: json['terms_updated_at'] != null ? DateTime.tryParse(json['terms_updated_at']) : null,
      hasParentalResponsibility: json['has_parental_responsibility'] ?? false,
      autonomousBookings: json['autonomous_bookings'] ?? false,
      boardRole: json['board_role'] as String?,
      reportKinds: List<String>.from(json['report_kinds'] ?? const []),
      managesUpdates: json['manages_updates'] ?? false,
      // The server sends UTC; convert to local or it reads hours behind.
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'])?.toLocal()
          : null,
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