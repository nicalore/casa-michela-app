import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Color _satisfiedColor = Color(0xFF4CAF50);
const Color _checklistBackground = Color(0xFFF8FAFC);
const Color _checklistBorder = AppTheme.slate200;

// Client side mirror of the backend password policy (app/core/password_policy.py).
// It exists only to give immediate feedback while typing: the authoritative
// check stays on the server, and the two must be kept in sync by hand.
class PasswordPolicyStatus
{
  static const int minLength = 12;

  final bool hasMinLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSpecialCharacter;

  const PasswordPolicyStatus({
    required this.hasMinLength,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasDigit,
    required this.hasSpecialCharacter,
  });

  const PasswordPolicyStatus.empty()
      : hasMinLength = false,
        hasLowercase = false,
        hasUppercase = false,
        hasDigit = false,
        hasSpecialCharacter = false;

  factory PasswordPolicyStatus.of(String password)
  {
    return PasswordPolicyStatus(
      hasMinLength: password.length >= minLength,
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasDigit: RegExp(r'\d').hasMatch(password),
      hasSpecialCharacter: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    );
  }

  bool get isSatisfied =>
      hasMinLength && hasLowercase && hasUppercase && hasDigit && hasSpecialCharacter;
}

class PasswordPolicyChecklist extends StatelessWidget
{
  final PasswordPolicyStatus status;

  const PasswordPolicyChecklist({super.key, required this.status});

  Widget _buildRow(String text, bool isSatisfied)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isSatisfied ? _satisfiedColor : AppTheme.hint,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isSatisfied ? _satisfiedColor : AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _checklistBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _checklistBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('Almeno ${PasswordPolicyStatus.minLength} caratteri', status.hasMinLength),
          _buildRow('Almeno una lettera minuscola', status.hasLowercase),
          _buildRow('Almeno una lettera maiuscola', status.hasUppercase),
          _buildRow('Almeno un numero', status.hasDigit),
          _buildRow('Almeno un carattere speciale', status.hasSpecialCharacter),
        ],
      ),
    );
  }
}