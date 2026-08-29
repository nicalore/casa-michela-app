import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../models/teacher_appreciation_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';

const Color _sectionDivider = AppTheme.trialLine;

const Color _preferredAccent = AppTheme.trialViolet;
const Color _avoidedAccent = AppTheme.trialDeepWater;

const double _stackBelow = 900;

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

  Widget _ranking(String title, List<TeacherAppreciationItem> teachers, Color accent)
  {
    return PersonRankingSection(
      title: title,
      rows: [
        for (var position = 1; position <= teachers.length; position++)
          PersonRankRow(
            position: position,
            person: teachers[position - 1].teacher,
            badgeText:
                '${teachers[position - 1].requestCount} '
                '${teachers[position - 1].requestCount == 1 ? 'richiesta' : 'richieste'}',
            accent: accent,
          ),
      ],
    );
  }

  Widget _rankings()
  {
    final asked = _ranking(
      '5 docenti più richiesti',
      ranking.mostAppreciated,
      _preferredAccent,
    );
    final avoided = _ranking(
      '5 docenti meno graditi',
      ranking.leastAppreciated,
      _avoidedAccent,
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < _stackBelow)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              asked,
              const SizedBox(height: 24),
              const Divider(color: _sectionDivider, thickness: 1),
              const SizedBox(height: 24),
              avoided,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: asked),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: VerticalDivider(color: _sectionDivider, thickness: 1),
              ),
              Expanded(child: avoided),
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
        child: _rankings(),
      ),
    );
  }
}
