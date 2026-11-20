import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/language/app_language.dart';
import '../../core/theme/app_theme.dart';

const double _meterHeight = 6;
const Duration _meterFill = Duration(milliseconds: 260);

const Duration _strikeThrough = Duration(milliseconds: 320);
const double _strikeWidth = 1.5;
const double _ruleIconSize = 15;

class PasswordPolicyRule
{
  final String label;
  final bool satisfied;

  const PasswordPolicyRule(this.label, this.satisfied);
}

// Mirrors app/core/password_policy.py, synced by hand; the server check stays authoritative.
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

  List<PasswordPolicyRule> get rules
  {
    return <PasswordPolicyRule>[
      PasswordPolicyRule(tr('Almeno $minLength caratteri', 'At least $minLength characters'), hasMinLength),
      PasswordPolicyRule(tr('Almeno una lettera minuscola', 'At least one lowercase letter'), hasLowercase),
      PasswordPolicyRule(tr('Almeno una lettera maiuscola', 'At least one uppercase letter'), hasUppercase),
      PasswordPolicyRule(tr('Almeno un numero', 'At least one number'), hasDigit),
      PasswordPolicyRule(tr('Almeno un carattere speciale', 'At least one special character'), hasSpecialCharacter),
    ];
  }

  int get missingCount => rules.where((rule) => !rule.satisfied).length;

  String get caption
  {
    final int missing = missingCount;

    return missing == 0
        ? tr('Tutti i requisiti soddisfatti', 'All requirements met')
        : missing == 1
            ? tr('Manca un requisito', 'One requirement missing')
            : tr('Mancano $missing requisiti', '$missing requirements missing');
  }

  double get progress => (rules.length - missingCount) / rules.length;
}

class PasswordPolicyChecklist extends StatelessWidget
{
  final PasswordPolicyStatus status;

  const PasswordPolicyChecklist({super.key, required this.status});

  Widget _buildCaption()
  {
    final int missingCount = status.missingCount;
    final String text = status.caption;

    return Row(
      children: [
        Icon(
          missingCount == 0 ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          size: 16,
          color: missingCount == 0 ? AppTheme.trialTurquoise : AppTheme.trialMutedText,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: missingCount == 0 ? AppTheme.trialTealDeepText : AppTheme.trialMutedText,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PasswordPolicyMeter(progress: status.progress),
        const SizedBox(height: 12),
        _buildCaption(),
        for (final rule in status.rules) _PolicyRuleRow(rule: rule),
      ],
    );
  }
}

class _PolicyRuleRow extends StatelessWidget
{
  final PasswordPolicyRule rule;

  const _PolicyRuleRow({required this.rule});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 7, left: 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: rule.satisfied ? 1 : 0),
        duration: _strikeThrough,
        curve: Curves.easeOut,
        builder: (context, t, child)
        {
          final Color textColor =
              Color.lerp(AppTheme.trialMutedText, Colors.white, 0.45 * t)!;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _ruleIconSize,
                height: _ruleIconSize + 2,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - t,
                      child: Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: _ruleIconSize,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                    Opacity(
                      opacity: t,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: _ruleIconSize,
                        color: AppTheme.trialTurquoise,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Stack(
                  children: [
                    Text(
                      rule.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: t,
                          alignment: Alignment.centerLeft,
                          child: Container(height: _strikeWidth, color: textColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PasswordPolicyMeter extends StatelessWidget
{
  final double progress;

  // Unfilled part: darker on the phone's glass.
  final Color track;

  PasswordPolicyMeter({super.key, required this.progress, Color? track}) : track = track ?? AppTheme.trialLine;

  @override
  Widget build(BuildContext context)
  {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_meterHeight),
      child: Stack(
        children: [
          Container(height: _meterHeight, color: track),
          AnimatedFractionallySizedBox(
            duration: _meterFill,
            curve: Curves.easeOut,
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              height: _meterHeight,
              decoration: BoxDecoration(gradient: AppTheme.brandGradient),
            ),
          ),
        ],
      ),
    );
  }
}
