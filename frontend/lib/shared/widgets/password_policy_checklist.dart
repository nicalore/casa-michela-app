import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const double _meterHeight = 6;
const Duration _meterFill = Duration(milliseconds: 260);

// The line is drawn a touch slower than the bar fills, so the eye catches it
// crossing the words rather than finding it already there.
const Duration _strikeThrough = Duration(milliseconds: 320);
const double _strikeWidth = 1.5;
const double _ruleIconSize = 15;

// One requirement and whether the password meets it.
class PasswordPolicyRule
{
  final String label;
  final bool satisfied;

  const PasswordPolicyRule(this.label, this.satisfied);
}

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

  // Every rule, met or not, always in the same order and always all five. They
  // stay on the list once satisfied and get struck through instead of dropping
  // off it: a list that loses a line every few keystrokes takes the ones under
  // it up with it, and the dialog around it changes height while you are still
  // typing into it.
  List<PasswordPolicyRule> get rules
  {
    return <PasswordPolicyRule>[
      PasswordPolicyRule('Almeno $minLength caratteri', hasMinLength),
      PasswordPolicyRule('Almeno una lettera minuscola', hasLowercase),
      PasswordPolicyRule('Almeno una lettera maiuscola', hasUppercase),
      PasswordPolicyRule('Almeno un numero', hasDigit),
      PasswordPolicyRule('Almeno un carattere speciale', hasSpecialCharacter),
    ];
  }

  int get missingCount => rules.where((rule) => !rule.satisfied).length;

  double get progress => (rules.length - missingCount) / rules.length;
}

// How far the password has got, and what it still owes. The bar fills with the
// brand ramp as the rules fall, and the rules stay where they are underneath it,
// each one struck through as it is met. Nothing here changes size while you
// type: a block that loses a line every few keystrokes moves everything below it
// and resizes the dialog around your hands.
class PasswordPolicyChecklist extends StatelessWidget
{
  final PasswordPolicyStatus status;

  const PasswordPolicyChecklist({super.key, required this.status});

  Widget _buildMeter()
  {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_meterHeight),
      child: Stack(
        children: [
          Container(height: _meterHeight, color: AppTheme.trialLine),
          // The fill is a fraction of the track, so it needs no width of its
          // own and follows the block whatever room it is given.
          AnimatedFractionallySizedBox(
            duration: _meterFill,
            curve: Curves.easeOut,
            widthFactor: status.progress,
            alignment: Alignment.centerLeft,
            child: Container(
              height: _meterHeight,
              decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption()
  {
    final int missingCount = status.missingCount;

    final String text = missingCount == 0
        ? 'Tutti i requisiti soddisfatti'
        : missingCount == 1
            ? 'Manca un requisito'
            : 'Mancano $missingCount requisiti';

    return Row(
      children: [
        Icon(
          missingCount == 0 ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          size: 16,
          color: missingCount == 0 ? AppTheme.trialTurquoise : AppTheme.trialMutedText,
        ),
        const SizedBox(width: 8),
        // Flexible, so a wider font than the one measured here ellipsises the
        // line instead of running it off the end of the block.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: missingCount == 0 ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
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
        _buildMeter(),
        const SizedBox(height: 12),
        _buildCaption(),
        for (final rule in status.rules) _PolicyRuleRow(rule: rule),
      ],
    );
  }
}

// One rule of the policy. The line does not go away when it is met: it is drawn
// through, left to right, the same way the mark under a destination in the top
// bar opens and the fill of a button travels. One gesture, three places.
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
          // A satisfied rule steps back rather than disappearing: it is still
          // there to be counted, only no longer asking for anything.
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
                      child: const Icon(
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
                    // One line, always: the line is drawn across the width the
                    // text turned out to be, and a label allowed to wrap would
                    // take the full width of the block and be struck through
                    // well past where it ends.
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
                    // Grown by a fraction of the width rather than by a size, so
                    // it takes no part in layout: the row cannot shift as the
                    // line is drawn across it.
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
