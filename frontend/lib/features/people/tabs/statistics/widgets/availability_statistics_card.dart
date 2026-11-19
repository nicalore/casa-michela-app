import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/week_range.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/scroll_edge_fade.dart';
import '../../../../lessons/utils/opening_window.dart' show kOnlineMode;
import '../../../models/teacher_availability_statistics_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';
import 'stats_layout.dart';

Color get _sectionDivider => AppTheme.trialLine;

const Duration _fetchFade = Duration(milliseconds: 150);

// Height past which a warning list scrolls; the paired one is for two lists in one column.
const double _warningListMaxHeight = 420;
const double _pairedWarningListMaxHeight = 232;

class TeacherAvailabilityCard extends StatelessWidget
{
  final TeacherAvailabilityStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  // Shortfalls matter only in presence: online names no one falling short.
  final String mode;
  final ValueChanged<String> onModeChanged;

  final bool isLoading;

  const TeacherAvailabilityCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    required this.mode,
    required this.onModeChanged,
    this.isLoading = false,
  });

  Widget _figure(String label, String value) => Expanded(child: StatFigure(label: label, value: value));

  static const String _topTitle = '10 docenti più disponibili';

  List<PersonRankRow> _topRows()
  {
    return [
      for (final (index, item) in statistics.topTeachers.indexed)
        PersonRankRow(
          position: index + 1,
          person: item.teacher,
          badgeText: '${item.availabilityCount} disponibilità',
          accent: AppTheme.trialSeaGreen,
        ),
    ];
  }

  Widget _topRanking() => PersonRankingSection(title: _topTitle, rows: _topRows());

  Widget _hoursRanking()
  {
    return PersonRankingSection(
      title: '10 docenti con più ore di disponibilità',
      rows: [
        for (final (index, item) in statistics.topTeachersByHours.indexed)
          PersonRankRow(
            position: index + 1,
            person: item.person,
            badgeText: formatMinutes(item.minutes),
            accent: AppTheme.trialSeaGreen,
          ),
      ],
    );
  }

  Widget _weeklyWarnings(double listHeight)
  {
    return TeacherWarningSection(
      title: 'Sotto 2 disponibilità a settimana',
      flagged: statistics.lowAvailabilityTeachers,
      describe: (item) => '${item.shortWeekCount} ${item.shortWeekCount == 1 ? 'settimana' : 'settimane'}',
      listMaxHeight: listHeight,
    );
  }

  Widget _monthlyWarnings(double listHeight)
  {
    return TeacherWarningSection(
      title: 'Sotto 9 disponibilità nel mese',
      flagged: statistics.lowMonthlyTeachers,
      describe: (item) => '${item.availabilityCount} disponibilità',
      listMaxHeight: listHeight,
    );
  }

  // In a column beside the rankings: the monthly list, when there is one, under the weekly.
  Widget _warnings()
  {
    if (!statistics.isSingleMonth)
    {
      return _weeklyWarnings(_warningListMaxHeight);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _weeklyWarnings(_pairedWarningListMaxHeight),
        StatPartDivider(color: _sectionDivider, lists: true),
        _monthlyWarnings(_pairedWarningListMaxHeight),
      ],
    );
  }

  // Across the card under the rankings: the two lists side by side.
  Widget _warningsAcross()
  {
    if (!statistics.isSingleMonth)
    {
      return _weeklyWarnings(_warningListMaxHeight);
    }

    return RankingPair(
      first: _weeklyWarnings(_warningListMaxHeight),
      second: _monthlyWarnings(_warningListMaxHeight),
    );
  }

  Widget _sections()
  {
    if (mode == kOnlineMode)
    {
      return RankingPair(first: _topRanking(), second: _hoursRanking());
    }

    return RankingTriple(
      first: _topRanking(),
      second: _hoursRanking(),
      third: _warnings(),
      thirdAcross: _warningsAcross(),
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
      trailing: StatFilterRow(
        children: [
          statsModePill(value: mode, onChanged: onModeChanged),
          statsPeriodPill(value: period, onChanged: onPeriodChanged),
        ],
      ),
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
            StatPartDivider(color: _sectionDivider),
            _sections(),
          ],
        ),
      ),
    );
  }
}


// SingleChildScrollView, not ListView: IntrinsicHeight cannot measure a lazy viewport.
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
      padding: const EdgeInsets.only(right: 12),
      child: PersonRankRow(
        person: item.teacher,
        badgeText: trailing,
        accent: AppTheme.modifiedAccent,
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
        SizedBox(height: StatMetrics.of(context).titleGap),
        if (widget.flagged.isEmpty)
          Center(
            child: Text(
              'Nessun docente da segnalare.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.trialMutedText,
              ),
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
              child: ScrollEdgeFade(
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
          ),
      ],
    );
  }
}
