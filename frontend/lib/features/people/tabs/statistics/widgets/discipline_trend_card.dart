import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../services/api_service.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../association/models/association_subject_item.dart';
import '../../../../lessons/widgets/lessons_form_fields.dart';
import '../../../models/member_trend_item.dart';
import 'stat_widgets.dart';
import 'trend_line_chart.dart';

const double _chartHeight = 280;

const double _searchFieldWidth = 420;

class DisciplineTrendCard extends StatefulWidget
{
  final List<AssociationSubjectItem> disciplines;

  const DisciplineTrendCard({super.key, required this.disciplines});

  @override
  State<DisciplineTrendCard> createState() => _DisciplineTrendCardState();
}

class _DisciplineTrendCardState extends State<DisciplineTrendCard>
{
  final ApiService _apiService = ApiService();

  int? _selectedId;
  List<MemberTrendItem> _trend = [];
  bool _isLoading = false;

  // Id of the request in flight; a stale answer must not land on the chart.
  int? _pendingId;

  Future<void> _load(int associationSubjectId) async
  {
    setState(()
    {
      _selectedId = associationSubjectId;
      _pendingId = associationSubjectId;
      _isLoading = true;
    });

    try
    {
      final data = await _apiService.getDisciplineRequestTrend(associationSubjectId);

      if (mounted && _pendingId == associationSubjectId)
      {
        setState(() => _trend = data);
      }
    }
    catch (_) {}
    finally
    {
      if (mounted && _pendingId == associationSubjectId)
      {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clear()
  {
    setState(()
    {
      _selectedId = null;
      _pendingId = null;
      _trend = [];
      _isLoading = false;
    });
  }

  Widget _body()
  {
    if (_isLoading)
    {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
      );
    }

    if (_selectedId == null)
    {
      return Center(
        child: Text(
          'Cerca una disciplina per vederne le richieste mese per mese.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.trialMutedText,
          ),
        ),
      );
    }

    if (_trend.isEmpty)
    {
      return const EmptyChartMessage();
    }

    return TrendLineChart(data: _trend, isMonthly: true);
  }

  @override
  Widget build(BuildContext context)
  {
    final options = [
      for (final discipline in widget.disciplines)
        SelectionOption(value: discipline.id, label: discipline.name),
    ];

    return AppCard(
      title: 'Andamento richieste per disciplina',
      selectable: false,
      leading: const AppCardBadge(icon: Icons.query_stats_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _searchFieldWidth),
            child: AutocompleteField<int>(
              label: 'Disciplina',
              hint: 'Cerca una disciplina per nome...',
              options: options,
              value: _selectedId,
              onSelected: _load,
              onCleared: _clear,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(height: _chartHeight, child: _body()),
        ],
      ),
    );
  }
}
