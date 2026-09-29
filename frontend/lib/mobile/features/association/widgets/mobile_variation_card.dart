import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/tabs/opening_hours/combined_hours.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import 'mobile_hours_parts.dart';

const double _radius = 22;
const double _labelGap = 8;
const double _chipGap = 5;

class MobileVariationCard extends StatelessWidget
{
  final CombinedVariation run;

  // Shared by every card, so the hours start level down the list.
  final double labelWidth;

  final bool tablet;

  const MobileVariationCard({super.key, required this.run, required this.labelWidth, required this.tablet});

  static double labelWidthOf(BuildContext context, {required bool tablet})
  {
    return MobileModeLabel.widthOf(context, fontSize: _labelSize(tablet), iconSize: _iconSize(tablet));
  }

  static double _labelSize(bool tablet) => tablet ? 14 : 13;

  static double _iconSize(bool tablet) => tablet ? 17 : 16;

  Widget _buildMode(String mode)
  {
    final double chipHeight = tablet ? 30 : 26;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          height: chipHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: MobileModeLabel(mode: mode, fontSize: _labelSize(tablet), iconSize: _iconSize(tablet)),
          ),
        ),
        const SizedBox(width: _labelGap),
        Expanded(
          child: Wrap(
            spacing: _chipGap,
            runSpacing: _chipGap,
            children: run.isClosed(mode)
                ? [MobileClosedTag(decided: true, fontSize: tablet ? 13 : 12.5, height: chipHeight)]
                : [for (final band in run.bandsByMode[mode]!) MobileHoursChip(band: band, tablet: tablet)],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> modes = [for (final mode in kHoursModes) if (run.bandsByMode.containsKey(mode)) mode];
    final String? note = run.note;

    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(18, 16, 18, 16) : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: BorderRadius.circular(_radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            run.dateLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 16.5 : 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialInk,
            ),
          ),
          const SizedBox(height: 10),
          for (final (i, mode) in modes.indexed) ...[
            if (i > 0) const MobileHoursRule(gap: 7),
            _buildMode(mode),
          ],
          if (note != null) ...[
            const SizedBox(height: 9),
            MobileHoursNote(note: note, fontSize: tablet ? 13 : 12.5),
          ],
        ],
      ),
    );
  }
}
