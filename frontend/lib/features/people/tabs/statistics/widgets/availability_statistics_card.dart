import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/teacher_availability_statistics_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';

const Color _sectionDivider = AppTheme.trialLine;

// Below this width the ranking and the warnings stack instead of pairing up.
const double _stackBelow = 900;

const Duration _fetchFade = Duration(milliseconds: 150);

// Max height before a warning list scrolls inside itself; the paired value
// applies when two lists share one column.
const double _warningListMaxHeight = 420;
const double _pairedWarningListMaxHeight = 232;

class TeacherAvailabilityCard extends StatelessWidget
{
  final TeacherAvailabilityStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;

  const TeacherAvailabilityCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  Widget _figure(String label, String value)
  {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topRanking()
  {
    return PersonRankingSection(
      title: '10 docenti più disponibili',
      rows: [
        for (var position = 1; position <= statistics.topTeachers.length; position++)
          PersonRankRow(
            position: position,
            person: statistics.topTeachers[position - 1].teacher,
            badgeText: '${statistics.topTeachers[position - 1].availabilityCount} disponibilità',
            accent: AppTheme.trialSeaGreen,
          ),
      ],
    );
  }

  Widget _warnings()
  {
    final bool paired = statistics.isSingleMonth;
    final double listHeight =
        paired ? _pairedWarningListMaxHeight : _warningListMaxHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TeacherWarningSection(
          title: 'Sotto 2 disponibilità a settimana',
          flagged: statistics.lowAvailabilityTeachers,
          describe: (item) => '${item.weeklyAverage.toStringAsFixed(1)} a settimana',
          listMaxHeight: listHeight,
        ),
        if (paired) ...[
          const SizedBox(height: 24),
          const Divider(color: _sectionDivider, thickness: 1),
          const SizedBox(height: 24),
          TeacherWarningSection(
            title: 'Sotto 9 disponibilità nel mese',
            flagged: statistics.lowMonthlyTeachers,
            describe: (item) => '${item.availabilityCount} disponibilità',
            listMaxHeight: listHeight,
          ),
        ],
      ],
    );
  }

  Widget _sections()
  {
    final ranking = _topRanking();
    final warnings = _warnings();

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _stackBelow)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ranking,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 1),
              const SizedBox(height: 24),
              warnings,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ranking),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 1),
              ),
              Expanded(child: warnings),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Disponibilità docenti',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_available_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: statsPeriodPill(value: period, onChanged: onPeriodChanged),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _figure(
                  'Disponibilità a settimana',
                  statistics.weeklyAverage.toStringAsFixed(1),
                ),
                const StatDivider(),
                _figure('Totale nel periodo', '${statistics.totalAvailabilities}'),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(color: _sectionDivider, thickness: 1),
            const SizedBox(height: 32),
            _sections(),
          ],
        ),
      ),
    );
  }
}


// SingleChildScrollView and not ListView: the sections sit inside an
// IntrinsicHeight, which cannot measure a lazy viewport.
class TeacherWarningSection extends StatefulWidget
{
  final String title;
  final List<LowAvailabilityTeacherItem> flagged;
  final String Function(LowAvailabilityTeacherItem item) describe;
  final double listMaxHeight;

  const TeacherWarningSection({
    super.key,
    required this.title,
    required this.flagged,
    required this.describe,
    required this.listMaxHeight,
  });

  @override
  State<TeacherWarningSection> createState() => _TeacherWarningSectionState();
}

class _TeacherWarningSectionState extends State<TeacherWarningSection>
{
  final ScrollController _controller = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Widget _lowRow(LowAvailabilityTeacherItem item, String trailing)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppTheme.modifiedAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.teacher.fullName} — $trailing',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.modifiedAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(widget.title),
        const SizedBox(height: 24),
        if (widget.flagged.isEmpty)
          Text(
            'Nessun docente da segnalare.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.listMaxHeight),
            child: RawScrollbar(
              controller: _controller,
              thumbVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              thumbColor: AppTheme.trialLine,
              child: SingleChildScrollView(
                controller: _controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in widget.flagged)
                      _lowRow(item, widget.describe(item)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
