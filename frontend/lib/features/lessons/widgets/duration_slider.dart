import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_range_slider.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../utils/booking_wizard_strings.dart';

String durationText(int minutes) => minutes == 0 ? '0' : formatMinutes(minutes);

// Starts at 0, which the wizard refuses: a length is always picked by hand.
class DurationSlider extends StatelessWidget
{
  // May lie past [longest], on a lesson already booked: the thumb waits at the end.
  final int minutes;
  final int longest;

  final String? count;
  final bool over;

  final ValueChanged<int> onChanged;

  // What a tour lights: the track with its ends, and the count.
  final String? trackTour;
  final String? countTour;

  const DurationSlider({
    super.key,
    required this.minutes,
    required this.longest,
    required this.count,
    required this.over,
    required this.onChanged,
    this.trackTour,
    this.countTour,
  });

  Widget _buildHeader()
  {
    final String? count = this.count;

    return Row(
      children: [
        Text(
          kDurationLabel,
          style: GoogleFonts.plusJakartaSans(color: AppTheme.trialOcean, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            durationText(minutes),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(color: AppTheme.trialTealDeep, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        if (count != null)
          DesktopTourTarget(
            id: countTour,
            child: Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                color: over ? AppTheme.trialDanger : AppTheme.trialTealDeep,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrack()
  {
    final int shown = minutes.clamp(0, longest);

    return AppSlider(
      value: shown.toDouble(),
      min: 0,
      max: longest.toDouble(),
      divisions: longest ~/ kQuarterHour,
      label: durationText(shown),
      onChanged: (value) => onChanged(value.round()),
    );
  }

  Widget _buildBounds()
  {
    final style = GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kRangeSliderThumbRadius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(durationText(0), style: style),
          Text(formatMinutes(longest), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 6),
        DesktopTourTarget(
          id: trackTour,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTrack(),
              _buildBounds(),
            ],
          ),
        ),
      ],
    );
  }
}
