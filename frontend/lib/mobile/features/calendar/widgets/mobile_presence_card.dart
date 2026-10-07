import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/calendar/utils/calendar_strings.dart';
import '../../../../features/calendar/utils/pupil_band_presence.dart';
import '../../../../features/calendar/utils/teacher_band_call.dart' show ModeSpan;
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_convocation_card.dart';

const Color _hairline = Color(0x1A122438);

// "Presente" and the hours in the building; online only, the online hours.
(String, String) presenceHeadline(PupilBandPresence presence)
{
  final ModeSpan? inBuilding = presence.byMode.where((span) => span.mode == kPresenceMode).firstOrNull;
  final ModeSpan? span = inBuilding ?? presence.byMode.firstOrNull;
  final (int, int)? hours = span == null ? presence.hull : (span.startMinutes, span.endMinutes);

  return (
    inBuilding != null ? kPresentWord : kOnlineLessonsTitle,
    hours == null ? '' : formatMinutesRange(hours.$1, hours.$2),
  );
}

String presenceShortSummary(PupilBandPresence presence)
{
  final lessons = presenceFigures(presence).first;

  return '${lessons.value} ${lessons.label} · ${formatMinutes(presence.lessonMinutes)}';
}

class MobilePresenceCard extends StatelessWidget
{
  final PupilBandPresence presence;

  final String? name;

  final bool tablet;
  final bool stretched;

  const MobilePresenceCard({
    super.key,
    required this.presence,
    this.name,
    required this.tablet,
    this.stretched = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final (String eyebrow, String hours) = presenceHeadline(presence);

    return MobileBandCard(
      eyebrow: eyebrow,
      hours: hours,
      figures: presenceFigures(presence),
      name: name,
      tablet: tablet,
      stretched: stretched,
      chips: const [],
    );
  }
}

class MobilePupilHead extends StatelessWidget
{
  final String name;
  final PupilBandPresence presence;

  final String nothingTitle;

  final bool tablet;

  const MobilePupilHead({
    super.key,
    required this.name,
    required this.presence,
    required this.nothingTitle,
    required this.tablet,
  });

  @override
  Widget build(BuildContext context)
  {
    final (String eyebrow, String hours) = presenceHeadline(presence);
    final bool empty = presence.isEmpty;

    return MobileGlassPanel(
      padding: EdgeInsets.fromLTRB(tablet ? 18 : 14, tablet ? 14 : 12, tablet ? 14 : 10, tablet ? 14 : 12),
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 19 : 17,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: tablet ? 10 : 8),
            child: const SizedBox(height: 1, child: ColoredBox(color: _hairline)),
          ),
          if (empty)
            Text(
              nothingTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 16 : 15.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: MobilePalette.mutedText,
              ),
            )
          else ...[
            Text(
              eyebrow.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 11.5 : 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppTheme.trialTealDeep,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              hours,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 26 : 20.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.2,
                color: AppTheme.trialInk,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              presenceShortSummary(presence),
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 13 : 12.5,
                fontWeight: FontWeight.w700,
                color: MobilePalette.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MobilePupilLine extends StatelessWidget
{
  final String name;
  final PupilBandPresence presence;
  final String nothingTitle;
  final bool tablet;

  const MobilePupilLine({
    super.key,
    required this.name,
    required this.presence,
    required this.nothingTitle,
    required this.tablet,
  });

  String get _about
  {
    if (presence.isEmpty)
    {
      return nothingTitle;
    }

    final (String eyebrow, String hours) = presenceHeadline(presence);
    final lessons = presenceFigures(presence).first;

    return '$eyebrow $hours · ${lessons.value} ${lessons.label}';
  }

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 22 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.15,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              _about,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 14 : 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.72),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MobilePupilLaneName extends StatelessWidget
{
  final String name;

  const MobilePupilLaneName({super.key, required this.name});

  @override
  Widget build(BuildContext context)
  {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          height: 1.15,
          color: Colors.white,
        ),
      ),
    );
  }
}
