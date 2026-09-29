import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';

const double _cardGap = 12;
const double _emptyHeight = 110;

// The two feeds of the web home, still to come.
class MobileNoticesList extends StatelessWidget
{
  const MobileNoticesList({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComingCard(
          eyebrow: 'Cose da fare',
          title: 'Attività e notifiche',
          icon: Icons.checklist_rounded,
        ),
        SizedBox(height: _cardGap),
        _ComingCard(
          eyebrow: 'Messaggi',
          title: 'Comunicazioni e avvisi',
          icon: Icons.campaign_rounded,
        ),
      ],
    );
  }
}

class _ComingCard extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final IconData icon;

  const _ComingCard({required this.eyebrow, required this.title, required this.icon});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppTheme.trialInk.withValues(alpha: 0.62),
                  ),
                ),
              ),
              const MobilePill('In arrivo', tone: MobilePillTone.teal),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialInk,
            ),
          ),
          SizedBox(
            height: _emptyHeight,
            child: Center(
              child: Icon(icon, size: 44, color: AppTheme.trialInk.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
