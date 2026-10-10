import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/week_range.dart' show formatMinutes;
import '../../../../features/people/models/personal_statistics_items.dart';
import '../../../../features/people/models/student_presence_statistics_item.dart';
import '../../../../features/people/own_page.dart' show OwnPageSection;
import '../../../../features/people/tabs/person_personal_stats_tab.dart'
    show
        availabilityShortfalls,
        kPupilStatsTitle,
        kTaughtDisciplinesTitle,
        kTeacherStatsTitle,
        kTopStudentsTitle,
        kTopTeachersTitle,
        presenceDaysPerWeekLabel,
        presenceTrendTitle,
        subjectHoursTitle;
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/people/tabs/statistics/widgets/stats_data.dart';
import '../../../../services/api_service.dart';
import '../../../layout/mobile_breakpoints.dart';
import '../../../shared/mobile_line_breaks.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_choice_sheet.dart';
import '../../../shared/widgets/mobile_filter_chip.dart';
import '../../../shared/widgets/mobile_load_switcher.dart';
import 'mobile_card_grid.dart';
import 'mobile_detail_card.dart';
import 'mobile_trend_chart.dart';

// Room for "100.0%", and for the usual hours badges; a longer one widens its own slot.
const double _shareSlot = 44;
const double _badgeSlot = 72;

// Room for "10°".
const double _positionSlot = 30;

const double _rankingsGap = 12;

// Held by the page: its pages are not kept alive, and returning must not refetch.
abstract class MobileStatsController<T> extends ChangeNotifier
{
  final ApiService _api = ApiService();

  String taxCode;

  String period = defaultStatsPeriod;
  String mode = kPresenceMode;
  T? statistics;

  // Mode of the shown [statistics]: words the labels while the next loads.
  String shownMode = kPresenceMode;
  bool loading = false;

  int _request = 0;
  bool _disposed = false;

  MobileStatsController(this.taxCode);

  Future<T> fetch(StatsPeriod period);

  Future<void> load() async
  {
    final int request = ++_request;
    final StatsPeriod parts = statsPeriodParts(period);
    final String asked = mode;

    loading = true;
    notifyListeners();

    try
    {
      final T fetched = await fetch(parts);

      if (!_disposed && request == _request)
      {
        statistics = fetched;
        shownMode = asked;
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle statistiche personali');
    }
    finally
    {
      if (!_disposed && request == _request)
      {
        loading = false;
        notifyListeners();
      }
    }
  }

  void choose(String? chosen)
  {
    if (chosen == null || chosen == period)
    {
      return;
    }

    period = chosen;
    load();
  }

  void chooseMode(String? chosen)
  {
    if (chosen == null || chosen == mode)
    {
      return;
    }

    mode = chosen;
    load();
  }

  // Same period, another person: old figures must not show under the new name.
  void follow(String other)
  {
    if (other == taxCode)
    {
      return;
    }

    taxCode = other;
    statistics = null;
    load();
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

class MobileTeacherStatsController extends MobileStatsController<TeacherPersonalStatisticsItem>
{
  MobileTeacherStatsController(super.taxCode);

  @override
  Future<TeacherPersonalStatisticsItem> fetch(StatsPeriod period)
  {
    return _api.getTeacherPersonalStatistics(
      taxCode,
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }
}

class MobilePupilStatsController extends MobileStatsController<StudentPersonalStatisticsItem>
{
  RequestedSubjectKind kind = RequestedSubjectKind.ministrySubject;

  MobilePupilStatsController(super.taxCode);

  @override
  Future<StudentPersonalStatisticsItem> fetch(StatsPeriod period)
  {
    return _api.getStudentPersonalStatistics(
      taxCode,
      months: period.months,
      year: period.year,
      month: period.month,
      mode: mode,
    );
  }

  void chooseKind(RequestedSubjectKind picked)
  {
    if (picked != kind)
    {
      kind = picked;
      notifyListeners();
    }
  }
}

class MobileTeacherStats extends StatelessWidget
{
  final MobileTeacherStatsController controller;

  final double margin;

  const MobileTeacherStats({super.key, required this.controller, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return _StatsBlock(
      controller: controller,
      margin: margin,
      icon: Icons.event_available_rounded,
      title: kTeacherStatsTitle,
      figures: (statistics) => _TeacherFigures(statistics: statistics),
      rankings: (statistics) => [
        MobileDetailCard(
          icon: Icons.menu_book_rounded,
          title: kTaughtDisciplinesTitle,
          body: _subjectRows(statistics.taughtDisciplines),
        ),
        MobileDetailCard(
          icon: Icons.groups_rounded,
          title: kTopStudentsTitle,
          body: _peopleRows(statistics.topStudents),
        ),
      ],
    );
  }
}

class MobilePupilStats extends StatelessWidget
{
  final MobilePupilStatsController controller;

  final double margin;

  const MobilePupilStats({super.key, required this.controller, required this.margin});

  @override
  Widget build(BuildContext context)
  {
    return _StatsBlock(
      controller: controller,
      margin: margin,
      icon: Icons.event_seat_rounded,
      title: kPupilStatsTitle,
      figures: (statistics) => _PupilFigures(statistics: statistics, online: controller.shownMode == kOnlineMode),
      rankings: (statistics) => [
        MobileDetailCard(
          icon: Icons.menu_book_rounded,
          title: subjectHoursTitle(controller.kind),
          body: _SubjectHours(statistics: statistics, controller: controller),
        ),
        MobileDetailCard(
          icon: Icons.school_rounded,
          title: kTopTeachersTitle,
          body: _peopleRows(statistics.topTeachers),
        ),
      ],
    );
  }
}

class _StatsBlock<T> extends StatefulWidget
{
  final MobileStatsController<T> controller;
  final double margin;

  final IconData icon;
  final String title;
  final Widget Function(T statistics) figures;
  final List<Widget> Function(T statistics) rankings;

  const _StatsBlock({
    required this.controller,
    required this.margin,
    required this.icon,
    required this.title,
    required this.figures,
    required this.rankings,
  });

  @override
  State<_StatsBlock<T>> createState() => _StatsBlockState<T>();
}

class _StatsBlockState<T> extends State<_StatsBlock<T>>
{
  // Rankings arriving while the block shows rise in; on a return to the tab they are simply there.
  late bool _waited = widget.controller.statistics == null;

  @override
  void initState()
  {
    super.initState();
    widget.controller.addListener(_note);
  }

  @override
  void didUpdateWidget(_StatsBlock<T> oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller)
    {
      oldWidget.controller.removeListener(_note);
      widget.controller.addListener(_note);
      _note();
    }
  }

  @override
  void dispose()
  {
    widget.controller.removeListener(_note);
    super.dispose();
  }

  void _note()
  {
    if (widget.controller.statistics == null)
    {
      _waited = true;
    }
  }

  Future<void> _pickMode(BuildContext context) async
  {
    final MobileChoice<String>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: OwnPageSection.stats.label,
      title: 'Modalità',
      choices: [
        for (final mode in const [kPresenceMode, kOnlineMode]) MobileChoice(value: mode, label: modeLabel(mode)),
      ],
      value: widget.controller.mode,
    );

    if (picked != null && context.mounted)
    {
      widget.controller.chooseMode(picked.value);
    }
  }

  Future<void> _pickPeriod(BuildContext context) async
  {
    final MobileChoice<String>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: OwnPageSection.stats.label,
      title: 'Periodo',
      choices: [
        for (final option in statsPeriodOptions()) MobileChoice(value: option.value, label: option.label),
      ],
      value: widget.controller.period,
    );

    if (picked != null && context.mounted)
    {
      widget.controller.choose(picked.value);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildBlock(context),
    );
  }

  Widget _buildBlock(BuildContext context)
  {
    final MobileStatsController<T> controller = widget.controller;
    final double margin = widget.margin;
    final T? statistics = controller.statistics;

    final Widget? rankings = statistics == null
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(margin, _rankingsGap, margin, 0),
            child: MobileCardGrid(
              tablet: MobileBreakpoints.of(context).isTablet,
              cards: widget.rankings(statistics),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileFilterChips(
          margin: margin,
          chips: [
            // Always set to something, so like an order they never light up.
            MobileFilterChip(
              icon: Icons.devices_outlined,
              label: modeLabel(controller.mode),
              active: false,
              onTap: () => _pickMode(context),
            ),
            MobileFilterChip(
              icon: Icons.event_note_rounded,
              label: statsPeriodLabel(controller.period),
              active: false,
              onTap: () => _pickPeriod(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: _buildCard(statistics),
        ),
        if (rankings != null) _waited ? MobileRiseIn(child: rankings) : rankings,
      ],
    );
  }

  Widget _buildCard(T? statistics)
  {
    final bool loading = widget.controller.loading;

    // Old figures stay while the next period loads: glass cannot be faded.
    final Widget? spinner = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
          )
        : null;

    return MobileDetailCard(
      icon: widget.icon,
      title: widget.title,
      trailing: spinner,
      body: statistics == null
          ? (loading ? const SizedBox(height: 60) : const _NoData())
          : widget.figures(statistics),
    );
  }
}

class _TeacherFigures extends StatelessWidget
{
  final TeacherPersonalStatisticsItem statistics;

  const _TeacherFigures({required this.statistics});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final shortfall in availabilityShortfalls(statistics, forOwner: true))
          _Shortfall(text: shortfall),
        _FigurePair(
          first: _Figure(
            value: statistics.weeklyAverage.toStringAsFixed(1),
            label: 'Disponibilità a settimana',
          ),
          second: _Figure(
            value: '${statistics.totalAvailabilities}',
            label: 'Totale nel periodo',
          ),
        ),
        const _Hairline(),
        const _SectionTitle('Disponibilità per mese, ultimi 12 mesi'),
        const SizedBox(height: 8),
        if (statistics.monthlyTrend.isEmpty)
          const _NoData()
        else
          MobileTrendChart(data: statistics.monthlyTrend),
      ],
    );
  }
}

class _PupilFigures extends StatelessWidget
{
  final StudentPersonalStatisticsItem statistics;
  final bool online;

  const _PupilFigures({required this.statistics, required this.online});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FigurePair(
          first: _Figure(
            value: statistics.weeklyPresenceDays.toStringAsFixed(1),
            label: presenceDaysPerWeekLabel(online: online),
          ),
          second: _Figure(
            value: '${statistics.totalPresenceDays}',
            label: 'Giorni totali nel periodo',
          ),
        ),
        const _Hairline(),
        _SectionTitle(presenceTrendTitle(online: online)),
        const SizedBox(height: 8),
        if (statistics.monthlyTrend.isEmpty)
          const _NoData()
        else
          MobileTrendChart(data: statistics.monthlyTrend),
      ],
    );
  }
}

class _SubjectHours extends StatelessWidget
{
  final StudentPersonalStatisticsItem statistics;
  final MobilePupilStatsController controller;

  const _SubjectHours({required this.statistics, required this.controller});

  Future<void> _pickKind(BuildContext context) async
  {
    final MobileChoice<RequestedSubjectKind>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: OwnPageSection.stats.label,
      title: 'Classifica',
      choices: [for (final kind in RequestedSubjectKind.values) MobileChoice(value: kind, label: kind.label)],
      value: controller.kind,
    );

    if (picked != null && context.mounted)
    {
      controller.chooseKind(picked.value);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MobileFilterChips(
          margin: 0,
          chips: [
            MobileFilterChip(
              icon: Icons.leaderboard_rounded,
              label: controller.kind.label,
              active: false,
              onLight: true,
              onTap: () => _pickKind(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _subjectRows(statistics.lessonHours.of(controller.kind)),
      ],
    );
  }
}

Widget _subjectRows(List<SubjectHoursItem> subjects)
{
  return _RankRows(
    rows: [for (final subject in subjects) (name: subject.name, percentage: subject.percentage, minutes: subject.minutes)],
  );
}

Widget _peopleRows(List<PersonHoursItem> people)
{
  return _RankRows(
    rows: [
      for (final entry in people) (name: entry.person.fullName, percentage: entry.percentage, minutes: entry.minutes),
    ],
  );
}

typedef _RankEntry = ({String name, double percentage, int minutes});

class _RankRows extends StatelessWidget
{
  final List<_RankEntry> rows;

  const _RankRows({required this.rows});

  @override
  Widget build(BuildContext context)
  {
    if (rows.isEmpty)
    {
      return const _NoData();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) _RankRow(position: index + 1, entry: rows[index]),
      ],
    );
  }
}

class _RankRow extends StatelessWidget
{
  final int position;
  final _RankEntry entry;

  const _RankRow({required this.position, required this.entry});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: position == 1 ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _positionSlot),
              child: Text(
                '$position°',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialTealDeep,
                ),
              ),
            ),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppTheme.trialInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _shareSlot),
              child: Text(
                '${entry.percentage.toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: MobilePalette.mutedText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _badgeSlot),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.trialTealDeep.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatMinutes(entry.minutes),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.trialTealDeep,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigurePair extends StatelessWidget
{
  final Widget first;
  final Widget second;

  const _FigurePair({required this.first, required this.second});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppTheme.trialInk.withValues(alpha: 0.12),
          ),
          Expanded(child: second),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget
{
  final String value;
  final String label;

  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
            color: AppTheme.trialTealDeep,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          withoutOrphans(label),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: MobilePalette.mutedText,
          ),
        ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget
{
  const _Hairline();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(top: 16, bottom: 14),
      color: AppTheme.trialInk.withValues(alpha: 0.1),
    );
  }
}

class _SectionTitle extends StatelessWidget
{
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppTheme.trialInk,
      ),
    );
  }
}

// Worded and coloured as on the desktop.
class _Shortfall extends StatelessWidget
{
  final String text;

  const _Shortfall({required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 19, color: AppTheme.modifiedAccent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppTheme.modifiedAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget
{
  const _NoData();

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'Nessun dato',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: MobilePalette.mutedText,
          ),
        ),
      ),
    );
  }
}
