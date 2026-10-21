import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/onboarding/legal_documents.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_select_parts.dart';

const double _iconSize = 40;

const double _tickSize = 28;
const double _tickEdge = 2;
const Duration _tickFill = Duration(milliseconds: 160);

class MobileTermsStep extends StatelessWidget
{
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const MobileTermsStep({super.key, required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(18, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < kLegalDocuments.length; i++)
                _DocumentRow(kLegalDocuments[i], first: i == 0),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Declaration(accepted: accepted, onTap: () => onChanged(!accepted)),
      ],
    );
  }
}

// On the sea a teal row would vanish: the glass stays and only the tick fills.
class _Declaration extends StatelessWidget
{
  final bool accepted;
  final VoidCallback onTap;

  const _Declaration({required this.accepted, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      checked: accepted,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  kTermsDeclaration,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: AppTheme.trialInk,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: accepted ? 1 : 0),
                duration: _tickFill,
                curve: Curves.easeOut,
                builder: (context, t, _) => Container(
                  width: _tickSize,
                  height: _tickSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: mobileSelectFill(Colors.white.withValues(alpha: 0), t),
                    border: Border.all(
                      color: AppTheme.trialInk.withValues(alpha: 0.25 * (1 - t)),
                      width: _tickEdge,
                    ),
                  ),
                  child: Icon(Icons.check_rounded, size: 18, color: Colors.white.withValues(alpha: t)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget
{
  final LegalDocument document;
  final bool first;

  const _DocumentRow(this.document, {required this.first});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openLegalDocument(document),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: first
                ? null
                : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Container(
                  width: _iconSize,
                  height: _iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.trialTealDeep.withValues(alpha: 0.13),
                  ),
                  child: Icon(document.icon, size: 21, color: AppTheme.trialTealDeep),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.trialInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        document.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: MobilePalette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.open_in_new_rounded, size: 21, color: AppTheme.trialTealDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
