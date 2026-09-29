import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/settings/utils/settings_strings.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../mobile_palette.dart';
import 'mobile_text_field.dart';

const double _ruleHeight = 25;
const double _hintHeight = 22;

class MobilePasswordFields extends StatelessWidget
{
  // Null where not asked: a reset, or the change forced right after sign-in.
  final TextEditingController? current;

  final TextEditingController next;
  final TextEditingController confirmation;

  final VoidCallback onSubmitted;

  const MobilePasswordFields({
    super.key,
    this.current,
    required this.next,
    required this.confirmation,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context)
  {
    final TextEditingController? current = this.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          MobileTextField(
            controller: current,
            label: kCurrentPasswordLabel,
            hintText: kCurrentPasswordHint,
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 16),
        ],
        MobileTextField(
          controller: next,
          label: kNewPasswordLabel,
          hintText: kNewPasswordHint,
          icon: Icons.lock_outline_rounded,
          obscure: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: next,
          builder: (context, _) => MobilePasswordPolicy(status: PasswordPolicyStatus.of(next.text)),
        ),
        const SizedBox(height: 16),
        MobileTextField(
          controller: confirmation,
          label: kConfirmPasswordLabel,
          hintText: kConfirmPasswordHint,
          icon: Icons.lock_outline_rounded,
          obscure: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => onSubmitted(),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Listenable.merge([next, confirmation]),
          builder: (context, _) => MobilePasswordMatch(next: next.text, confirmation: confirmation.text),
        ),
      ],
    );
  }
}

class MobilePasswordPolicy extends StatelessWidget
{
  final PasswordPolicyStatus status;

  const MobilePasswordPolicy({super.key, required this.status});

  @override
  Widget build(BuildContext context)
  {
    final List<PasswordPolicyRule> rules = status.rules;
    final bool done = status.missingCount == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordPolicyMeter(
            progress: status.progress,
            track: AppTheme.trialInk.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                size: 16,
                color: done ? AppTheme.trialTurquoise : MobilePalette.mutedText,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  status.caption,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: done ? AppTheme.trialTealDeep : MobilePalette.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final rule in rules)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _ruleHeight),
              child: Row(
                children: [
                  Icon(
                    rule.satisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: rule.satisfied
                        ? AppTheme.trialTurquoise
                        : MobilePalette.mutedText.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      rule.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: rule.satisfied ? AppTheme.trialTealDeep : MobilePalette.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Keeps its height when empty, so nothing under it moves.
class MobilePasswordMatch extends StatelessWidget
{
  final String next;
  final String confirmation;

  const MobilePasswordMatch({super.key, required this.next, required this.confirmation});

  @override
  Widget build(BuildContext context)
  {
    if (next.isEmpty || confirmation.isEmpty)
    {
      return const SizedBox(height: _hintHeight);
    }

    final bool matches = next == confirmation;
    final Color tone = matches ? AppTheme.trialTealDeep : AppTheme.trialDanger;

    return SizedBox(
      height: _hintHeight,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Icon(
              matches ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              size: 16,
              color: matches ? AppTheme.trialTurquoise : AppTheme.trialDanger,
            ),
            const SizedBox(width: 8),
            Text(
              matches ? kPasswordsMatch : kPasswordsDiffer,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: tone),
            ),
          ],
        ),
      ),
    );
  }
}
