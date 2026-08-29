import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/student_presence_statistics_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';

const Color _sectionDivider = AppTheme.trialLine;

// Below this width the student and subject rankings stack.
const double _stackBelow = 900;

// Places in each requests ranking; must match the backend limit.
const int _requestsLimit = 10;

const Duration _fetchFade = Duration(milliseconds: 150);

class StudentPresenceCard extends StatefulWidget
{
  final StudentPresenceStatisticsItem statistics;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;

  const StudentPresenceCard({
    super.key,
    required this.statistics,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  @override
  State<StudentPresenceCard> createState() => _StudentPresenceCardState();
}

class _StudentPresenceCardState extends State<StudentPresenceCard>
{
  RequestedSubjectKind _kind = RequestedSubjectKind.ministrySubject;

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

  Widget _topStudents()
  {
    return PersonRankingSection(
      title: '10 studenti più presenti',
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

  Widget _sections()
  {
    final students = _topStudents();
    final subjects = _topSubjects();

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _stackBelow)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              students,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 1),
              const SizedBox(height: 24),
              subjects,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: students),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 1),
              ),
              Expanded(child: subjects),
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
                  'Giorni di presenza nel periodo',
                  '${widget.statistics.totalPresenceDays}',
                ),
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
