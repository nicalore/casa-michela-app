import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../lessons/utils/opening_window.dart' show kOnlineMode;
import '../../../models/student_presence_statistics_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';
import 'stats_layout.dart';

const Color _sectionDivider = AppTheme.trialLine;

// Places in each requests ranking; must match the backend limit.
const int _requestsLimit = 10;

const Duration _fetchFade = Duration(milliseconds: 150);

class StudentPresenceCard extends StatefulWidget
{
  final StudentPresenceStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final String mode;
  final ValueChanged<String> onModeChanged;

  // The mode of [statistics], which words the labels.
  final String shownMode;

  final bool isLoading;

  const StudentPresenceCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    required this.mode,
    required this.onModeChanged,
    required this.shownMode,
    this.isLoading = false,
  });

  bool get _online => shownMode == kOnlineMode;

  @override
  State<StudentPresenceCard> createState() => _StudentPresenceCardState();
}

class _StudentPresenceCardState extends State<StudentPresenceCard>
{
  RequestedSubjectKind _kind = RequestedSubjectKind.ministrySubject;

  Widget _figure(String label, String value) => Expanded(child: StatFigure(label: label, value: value));

  Widget _topStudents()
  {
    return PersonRankingSection(
      title: widget._online ? '10 studenti più presenti online' : '10 studenti più presenti',
      rows: [
        for (var position = 1; position <= widget.statistics.topStudents.length; position++)
          PersonRankRow(
            position: position,
            person: widget.statistics.topStudents[position - 1].student,
            badgeText:
                '${widget.statistics.topStudents[position - 1].presenceDays} '
                '${widget.statistics.topStudents[position - 1].presenceDays == 1 ? 'giorno' : 'giorni'}',
            accent: AppTheme.trialTealDeep,
          ),
      ],
    );
  }

  Widget _topSubjects()
  {
    return RequestedSubjectsSection(
      rankings: widget.statistics.requested,
      kind: _kind,
      limit: _requestsLimit,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppCard(
      title: 'Presenze studenti',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.event_seat_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: StatFilterRow(
        children: [
          requestedKindPill(
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
          ),
          statsModePill(value: widget.mode, onChanged: widget.onModeChanged),
          statsPeriodPill(value: widget.period, onChanged: widget.onPeriodChanged),
        ],
      ),
      child: AnimatedOpacity(
        opacity: widget.isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _figure(
                  'Studenti al giorno',
                  widget.statistics.dailyAverage.toStringAsFixed(1),
                ),
                const StatDivider(),
                _figure(
                  widget._online ? 'Studenti unici online nel periodo' : 'Studenti unici nel periodo',
                  '${widget.statistics.studentCount}',
                ),
              ],
            ),
            const StatPartDivider(color: _sectionDivider),
            RankingPair(first: _topStudents(), second: _topSubjects()),
          ],
        ),
      ),
    );
  }
}
