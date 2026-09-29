import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/mobile_flow_page.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

// Mobile-only copy: the desktop has no page before the steps.
const String kFirstAccessEyebrow = 'Primo accesso';
const String kFirstAccessIntro = 'Prima di iniziare, ti chiediamo di completare questi passaggi.';
const String kFirstAccessStart = 'Inizia';

const double _numberSize = 30;

class MobileFirstAccessWelcome extends StatelessWidget
{
  final String greeting;
  final List<String> steps;
  final Widget capsule;
  final bool tablet;

  const MobileFirstAccessWelcome({
    super.key,
    required this.greeting,
    required this.steps,
    required this.capsule,
    required this.tablet,
  });

  @override
  Widget build(BuildContext context)
  {
    return MobileFlowForm(
      tablet: tablet,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Expanded(child: MobileFlowEyebrow(kFirstAccessEyebrow, tablet: tablet)),
              capsule,
            ],
          ),
        ),
        const SizedBox(height: 18),
        MobileFlowTitle(greeting, tablet: tablet, size: tablet ? 40 : 34),
        const SizedBox(height: 14),
        Text(
          kFirstAccessIntro,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.84),
          ),
        ),
        const SizedBox(height: 22),
        MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children: [
                        _Number(i + 1),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.trialInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Number extends StatelessWidget
{
  final int value;

  const _Number(this.value);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _numberSize,
      height: _numberSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.trialTealDeep.withValues(alpha: 0.13),
      ),
      child: Text(
        '$value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}

// Read-only: the steps are walked with the buttons.
class MobileFirstAccessRail extends StatelessWidget
{
  static const double width = 340;

  final String greeting;
  final List<String> steps;
  final int current;
  final Widget capsule;

  const MobileFirstAccessRail({
    super.key,
    required this.greeting,
    required this.steps,
    required this.current,
    required this.capsule,
  });

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MobileFlowEyebrow(kFirstAccessEyebrow, tablet: true),
              const SizedBox(height: 12),
              MobileFlowTitle(greeting, tablet: true, size: 32),
              const SizedBox(height: 26),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _RailStep(label: steps[i], number: i + 1, done: i < current, current: i == current),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              capsule,
            ],
          ),
        ),
      ),
    );
  }
}

class _RailStep extends StatelessWidget
{
  final String label;
  final int number;
  final bool done;
  final bool current;

  const _RailStep({
    required this.label,
    required this.number,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color text = current
        ? Colors.white
        : Colors.white.withValues(alpha: done ? 0.85 : 0.62);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: _numberSize,
            height: _numberSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppTheme.trialTurquoise : null,
              border: done
                  ? null
                  : Border.all(
                      color: current ? AppTheme.trialGold : Colors.white.withValues(alpha: 0.35),
                      width: current ? 2 : 1.5,
                    ),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 17, color: AppTheme.trialDeepWater)
                : Text(
                    '$number',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: current ? AppTheme.trialGold : text,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: current ? FontWeight.w800 : FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
