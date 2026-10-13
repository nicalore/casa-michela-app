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
import '../../../shared/widgets/mobile_tour.dart';

class MobileAddModeButton extends StatelessWidget
{
  final String mode;
  final bool tablet;
  final VoidCallback onTap;

  const MobileAddModeButton({super.key, required this.mode, required this.tablet, required this.onTap});

  // As drawn in a tour's text, a little taller than the capitals of [size].
  static Widget glyph(String mode, double size)
  {
    return _AddModeFace(
      mode: mode,
      height: size * 1.25,
      iconSize: size * 0.75,
      fontSize: size * 0.58,
      letterSpacing: size * 0.04,
      gap: size * 0.15,
      padding: EdgeInsets.only(left: size * 0.3, right: size * 0.45),
      // [size] already follows the reader's text scale.
      scaler: TextScaler.noScaling,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _AddModeFace(
          mode: mode,
          height: tablet ? 36 : 32,
          iconSize: tablet ? 18 : 16,
          fontSize: tablet ? 12 : 11,
          letterSpacing: 0.7,
          gap: 4,
          padding: EdgeInsets.only(left: tablet ? 11 : 9, right: tablet ? 15 : 12),
          shadow: const [BoxShadow(color: Color(0x330B6478), offset: Offset(0, 4), blurRadius: 10)],
        ),
      ),
    );
  }
}

class _AddModeFace extends StatelessWidget
{
  final String mode;
  final double height;
  final double iconSize;
  final double fontSize;
  final double letterSpacing;
  final double gap;
  final EdgeInsets padding;
  final List<BoxShadow>? shadow;
  final TextScaler? scaler;

  const _AddModeFace({
    required this.mode,
    required this.height,
    required this.iconSize,
    required this.fontSize,
    required this.letterSpacing,
    required this.gap,
    required this.padding,
    this.shadow,
    this.scaler,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: iconSize, color: Colors.white),
          SizedBox(width: gap),
          Text(
            modeLabel(mode).toUpperCase(),
            textScaler: scaler,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: letterSpacing,
              color: Colors.white,
            ),
          ),
        ],
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

// Coloured by its mode, as the hours on the day cards; several ranges stand in a column after the band's name.
class MobileBandTag extends StatelessWidget
{
  final BandOffer offer;
  final String mode;

  // For a tour to light the band with its ranges, and the hours left.
  final String? tourBand;
  final String? tourLeft;

  const MobileBandTag({super.key, required this.offer, required this.mode, this.tourBand, this.tourLeft});

  @override
  Widget build(BuildContext context)
  {
    final bool online = mode == kOnlineMode;
    final Color accent = online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    final TextStyle hours = GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      height: 1.45,
      color: AppTheme.trialInk,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    const EdgeInsets inflate = EdgeInsets.symmetric(horizontal: 7, vertical: 5);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: MobileTourTarget(
                id: tourBand,
                inflate: inflate,
                radius: 12,
                // The name on the first range's line.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      bandLabel(offer.band).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final range in offer.ranges) Text(range, style: hours)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          MobileTourTarget(
            id: tourLeft,
            inflate: inflate,
            radius: 12,
            child: Text(
              minutesLeftLabel(offer.left),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.45,
                color: offer.left <= 0 ? AppTheme.trialDanger : accent,
              ),
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

  // For a tour to light the count.
  final String? countTourTarget;

  const MobileFieldHead(this.label, {super.key, this.count, this.over = false, this.countTourTarget});

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
            MobileTourTarget(
              id: countTourTarget,
              inflate: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              radius: 14,
              child: Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: over ? AppTheme.trialDanger : AppTheme.trialTealDeep,
                ),
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
