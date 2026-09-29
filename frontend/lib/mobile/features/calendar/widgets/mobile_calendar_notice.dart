import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';

const double _badgeSize = 56;

class MobileCalendarNotice extends StatelessWidget
{
  final IconData icon;
  final String title;
  final String? message;

  const MobileCalendarNotice({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? message = this.message;

    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: _badgeSize,
            height: _badgeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.todaySurface,
              border: Border.all(color: AppTheme.trialTealDeep.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(icon, size: 27, color: AppTheme.trialTealDeep),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: AppTheme.trialInk,
            ),
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: MobilePalette.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
