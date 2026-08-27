import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../../lessons/widgets/person_avatar.dart';
import '../../../models/teacher_appreciation_item.dart';
import 'stat_filters.dart';
import 'stat_widgets.dart';

const Color _sectionDivider = AppTheme.trialLine;

// The same colours the calendar marks preferences with: violet for preferred,
// deep water for avoided.
const Color _preferredAccent = AppTheme.trialViolet;
const Color _avoidedAccent = AppTheme.trialDeepWater;

const double _stackBelow = 900;

const Duration _fetchFade = Duration(milliseconds: 150);

class TeacherAppreciationCard extends StatelessWidget
{
  final TeacherAppreciationRankingItem ranking;

  // One month or the whole window: see appreciationPeriodOptions.
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

  Widget _place(int position, TeacherAppreciationItem item, Color accent)
  {
    final unit = item.requestCount == 1 ? 'richiesta' : 'richieste';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position°',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PersonAvatar(person: item.teacher),
          const SizedBox(width: 12),
          Expanded(
            child: OverflowTooltipText(
              text: item.teacher.fullName,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialInk,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${item.requestCount} $unit',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ranking(String title, List<TeacherAppreciationItem> teachers, Color accent)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatSectionTitle(title),
        const SizedBox(height: 24),
        if (teachers.isEmpty)
          const EmptyChartMessage(fontSize: 14)
        else
          ...[
            for (var position = 1; position <= teachers.length; position++)
              _place(position, teachers[position - 1], accent),
          ],
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
      trailing: appreciationPeriodPill(value: period, onChanged: onPeriodChanged),
      // Dimmed, not swapped for a spinner: resizing would move everything below.
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1,
        duration: _fetchFade,
        child: _rankings(),
      ),
    );
  }
}
