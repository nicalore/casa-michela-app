import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/lessons/models/band_offer.dart';
import '../../../../features/lessons/models/presence_item.dart';
import '../../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';

class MobileAddModeButton extends StatelessWidget
{
  final String mode;
  final bool tablet;
  final VoidCallback onTap;

  const MobileAddModeButton({super.key, required this.mode, required this.tablet, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final double height = tablet ? 36 : 32;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.only(left: tablet ? 11 : 9, right: tablet ? 15 : 12),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: const [BoxShadow(color: Color(0x330B6478), offset: Offset(0, 4), blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: tablet ? 18 : 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                modeLabel(mode).toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: tablet ? 12 : 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileHoursChip extends StatelessWidget
{
  final PresenceItem slot;
  final bool closed;
  final bool tablet;

  const MobileHoursChip({super.key, required this.slot, required this.closed, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final bool online = slot.mode == kOnlineMode;

    final Color surface = closed ? Colors.white : (online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface);
    final Color ink = closed ? MobilePalette.mutedText : (online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep);

    return Container(
      height: tablet ? 28 : 26,
      padding: EdgeInsets.symmetric(horizontal: tablet ? 11 : 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: closed ? Border.all(color: AppTheme.closedLine, width: 1.5) : null,
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          formatTimeRange(slot.startTime, slot.endTime),
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 13.5 : 12.5,
            fontWeight: FontWeight.w800,
            color: ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class MobileTeacherFace extends StatelessWidget
{
  final PersonItem teacher;
  final double size;

  const MobileTeacherFace({super.key, required this.teacher, required this.size});

  @override
  Widget build(BuildContext context)
  {
    return MobileAvatar(
      firstName: teacher.firstName,
      lastName: teacher.lastName,
      imageUrl: teacher.profileImageUrl,
      size: size,
      gold: false,
    );
  }
}

class MobileBandTag extends StatelessWidget
{
  final BandOffer offer;

  const MobileBandTag({super.key, required this.offer});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${bandLabel(offer.band).toUpperCase()}  ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: AppTheme.trialTealDeep,
                    ),
                  ),
                  TextSpan(text: offer.hours),
                ],
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            minutesLeftLabel(offer.left),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.45,
              color: offer.left <= 0 ? AppTheme.trialDanger : AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class MobileFieldHead extends StatelessWidget
{
  final String label;
  final String? count;
  final bool over;

  const MobileFieldHead(this.label, {super.key, this.count, this.over = false});

  @override
  Widget build(BuildContext context)
  {
    final String? count = this.count;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: MobilePalette.mutedText,
              ),
            ),
          ),
          if (count != null)
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: over ? AppTheme.trialDanger : AppTheme.trialTealDeep,
              ),
            ),
        ],
      ),
    );
  }
}

class MobileQuietLine extends StatelessWidget
{
  final String text;

  const MobileQuietLine(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: MobilePalette.mutedText,
        ),
      ),
    );
  }
}
