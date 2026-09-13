import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../shared/widgets/closed_today_notice.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../../dashboard/widgets/published_pill.dart';
import 'home_schedule_data.dart';

const double _bandGap = 12;
const double _rowGap = 6;

// Type and spacing grow as the band count shrinks: the card height is fixed,
// so fewer bands are written larger to fill it.
class _BandScale
{
  final double name;
  final double hours;
  final double unit;
  final double padding;

  const _BandScale({
    required this.name,
    required this.hours,
    required this.unit,
    required this.padding,
  });

  static const _BandScale _tight = _BandScale(name: 15, hours: 15, unit: 12.5, padding: 11);
  static const _BandScale _roomy = _BandScale(name: 17, hours: 19, unit: 13.5, padding: 20);
  static const _BandScale _alone = _BandScale(name: 19, hours: 24, unit: 14.5, padding: 30);

  static _BandScale of(int bands)
  {
    if (bands >= 3)
    {
      return _tight;
    }

    return bands == 2 ? _roomy : _alone;
  }
}

class HomeScheduleSection extends StatelessWidget
{
  // Null when the day could not be read, which is not the same as a day with
  // no openings.
  final List<HomeBandStatus>? bands;

  final bool isLoading;

  final String title;

  // What to write in a band the reader has nothing in.
  final String emptyBandLabel;

  // What to write in a published band the reader offered hours for and was
  // not called in. Null where the reader's own rows never give way.
  final String? unconvenedLabel;

  final double minHeight;
  final bool fill;

  const HomeScheduleSection({
    super.key,
    required this.bands,
    required this.title,
    required this.emptyBandLabel,
    this.unconvenedLabel,
    this.isLoading = false,
    this.minHeight = 0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      eyebrow: 'Oggi',
      title: title,
      minHeight: minHeight,
      fill: fill,
      child: _buildBody(),
    );
  }

  Widget _buildBody()
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<HomeBandStatus>? open = bands;

    if (open == null)
    {
      return Text(
        'Gli orari di oggi non sono disponibili.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    if (open.isEmpty)
    {
      return const ClosedTodayNotice();
    }

    final _BandScale scale = _BandScale.of(open.length);
    final bool shares = fill && open.length > 1;

    return Column(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: shares ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < open.length; i++)
          if (shares)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i == open.length - 1 ? 0 : _bandGap),
                child: _band(open[i], scale),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: i == open.length - 1 ? 0 : _bandGap),
              child: _band(open[i], scale),
            ),
      ],
    );
  }

  Widget _band(HomeBandStatus status, _BandScale scale)
  {
    return _BandRow(
      status: status,
      scale: scale,
      emptyLabel: emptyBandLabel,
      unconvenedLabel: unconvenedLabel,
    );
  }
}

class _BandRow extends StatelessWidget
{
  final HomeBandStatus status;
  final _BandScale scale;
  final String emptyLabel;
  final String? unconvenedLabel;

  const _BandRow({
    required this.status,
    required this.scale,
    required this.emptyLabel,
    required this.unconvenedLabel,
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: scale.padding),
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.trialLine, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  bandLabel(status.band),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: scale.name,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              if (status.isPublished) ...[
                const SizedBox(width: 8),
                const PublishedPill(),
              ],
            ],
          ),
          SizedBox(height: _rowGap),
          Wrap(
            spacing: 16,
            runSpacing: 2,
            children: [
              for (final opening in status.openings)
                _Reading(
                  value: opening.hours,
                  label: opening.mode,
                  size: scale.hours,
                  labelSize: scale.unit,
                ),
            ],
          ),
          SizedBox(height: _rowGap),
          ..._buildOwnRows(),
        ],
      ),
    );
  }

  List<Widget> _buildOwnRows()
  {
    if (status.slots.isEmpty && status.idle.isEmpty)
    {
      final String? unconvened = unconvenedLabel;

      return [
        _Muted(
          text: status.isPublished && status.offered && unconvened != null
              ? unconvened
              : emptyLabel,
          size: scale.unit,
        ),
      ];
    }

    return [
      for (final slot in status.slots)
        _Reading(
          prefix: slot.name,
          lead: slot.convened ? 'Convocato' : null,
          value: slot.hours,
          label: slot.modeLabel,
          size: scale.hours,
          labelSize: scale.unit,
        ),
      for (final name in status.idle)
        _Muted(text: '$name · ${emptyLabel.toLowerCase()}', size: scale.unit),
    ];
  }
}

class _Reading extends StatelessWidget
{
  final String? prefix;

  // A word before the hours, set like the name: "Convocato 14:00–17:00".
  final String? lead;

  final String value;
  final String label;
  final double size;
  final double labelSize;

  const _Reading({
    required this.value,
    required this.label,
    required this.size,
    required this.labelSize,
    this.prefix,
    this.lead,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? name = prefix;
    final String? word = lead;

    final TextStyle accent = GoogleFonts.plusJakartaSans(
      fontSize: labelSize,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: AppTheme.trialTealDeep,
    );

    return Text.rich(
      TextSpan(
        children: [
          if (name != null && name.isNotEmpty)
            TextSpan(text: '$name · ', style: accent),
          if (word != null)
            TextSpan(text: '$word ', style: accent),
          TextSpan(
            text: value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppTheme.trialInk,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: GoogleFonts.plusJakartaSans(
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Muted extends StatelessWidget
{
  final String text;
  final double size;

  const _Muted({required this.text, required this.size});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.35,
        color: AppTheme.trialMutedText,
      ),
    );
  }
}
