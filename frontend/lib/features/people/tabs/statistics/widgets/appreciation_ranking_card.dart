import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/teacher_appreciation_item.dart';
import 'appreciation_students_dialog.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';

const Color _accent = AppTheme.trialDeepWater;


const Duration _fetchFade = Duration(milliseconds: 150);

class TeacherAppreciationCard extends StatelessWidget
{
  final TeacherAppreciationRankingItem ranking;

  // One month, or the last N: see statsPeriodOptions.
  final String period;

  final ValueChanged<String> onPeriodChanged;

  final bool isLoading;

  const TeacherAppreciationCard({
    super.key,
    required this.ranking,
    required this.period,
    required this.onPeriodChanged,
    this.isLoading = false,
  });

  PersonRankRow _row(BuildContext context, int position)
  {
    final item = ranking.ranking[position - 1];

    void showStudents(bool up) => showAppreciationStudentsDialog(
          context,
          taxCode: item.teacher.taxCode,
          period: period,
          up: up,
        );

    return PersonRankRow(
      position: position,
      person: item.teacher,
      badgeText: formatAppreciationScore(item.score),
      accent: _accent,
      subtitle: ThumbCounts(
        up: item.preferringStudentCount,
        down: item.avoidingStudentCount,
        onUpTap: () => showStudents(true),
        onDownTap: () => showStudents(false),
      ),
    );
  }

  Widget _column(BuildContext context, int first, int last)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var position = first; position <= last; position++) _row(context, position),
      ],
    );
  }

  // A single column folds in the minimal window.
  Widget _single(BuildContext context, int count)
  {
    return RankingRows(rows: [for (var position = 1; position <= count; position++) _row(context, position)]);
  }

  // Places fill the left column first, then continue down the right one.
  Widget _rows(BuildContext context)
  {
    final count = ranking.ranking.length;

    if (count == 0)
    {
      return const EmptyChartMessage(fontSize: 14);
    }

    // Two columns while they fit: one long column leaves the right half empty.
    final double twoColumnsFrom = StatMetrics.of(context).listsFrom;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < twoColumnsFrom || count < 2)
        {
          return _single(context, count);
        }

        final half = (count + 1) ~/ 2;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _column(context, 1, half)),
              const StatColumnDivider(),
              Expanded(child: _column(context, half + 1, count)),
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
      title: 'Gradimento docenti',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.emoji_events_rounded),
      trailingFit: AppCardTrailing.wrapping,
      trailing: statsPeriodPill(value: period, onChanged: onPeriodChanged),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: _rows(context),
      ),
    );
  }
}
