class LoginResponse
{
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool passwordResetRequired;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.passwordResetRequired,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json)
  {
    return LoginResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      tokenType: json['token_type'],
      passwordResetRequired: json['password_reset_required'],
    );
  }
}