import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/dialog_components.dart';
import '../../../../shared/widgets/page_transition.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../models/opening_day_item.dart';
import '../../models/weekly_template_item.dart';
import 'calendar_bounds.dart';
import 'combined_hours.dart';
import 'combined_standard_card.dart';
import 'combined_variations_card.dart';
import 'combined_week_card.dart';
import 'hours_strings.dart';
import 'lost_calendars.dart';
import 'mode_hours_parts.dart';
import 'opening_hours_layout.dart';
import 'standard_hours_wizard.dart';
import 'variation_wizard.dart';

class CombinedHoursView extends StatefulWidget
{
  final List<WeeklyTemplateItem> weeklyTemplates;

  final Future<void> Function()? onWeeklyTemplatesChanged;

  const CombinedHoursView({super.key, this.weeklyTemplates = const [], this.onWeeklyTemplatesChanged});

  @override
  State<CombinedHoursView> createState() => _CombinedHoursViewState();
}

class _CombinedHoursViewState extends State<CombinedHoursView>
{
  final ApiService _apiService = ApiService();

  late DateTime _weekStart;
  bool _isLoadingWeek = true;
  List<OpeningDayItem> _weekOpeningDays = [];

  // Bumped on every fetch so a stale answer cannot overwrite fresher data.
  int _weekRequestId = 0;
  int _variationsRequestId = 0;

  bool _isLoadingVariations = true;
  List<OpeningDayItem> _upcomingVariations = [];

  // Kept beside the data so the card filters on the window the rows were fetched for.
  late DateTime _variationsWindowEnd;

  StandardSchedule _scheduleByMode = {};

  @override
  void initState()
  {
    super.initState();
    _weekStart = startOfWeek(romeNow());
    _variationsWindowEnd = addDays(romeNow(), kVariationsWindowDays);
    _loadWeek();
    _loadUpcomingVariations();
  }

  Future<void> _loadWeek() async
  {
    final requestId = ++_weekRequestId;
    final weekStart = _weekStart;

    try
    {
      final days = await _apiService.getOpeningDays(dateFrom: weekStart, dateTo: addDays(weekStart, 6));

      if (!mounted || requestId != _weekRequestId)
      {
        return;
      }

      setState(()
      {
        _weekOpeningDays = days;
        _isLoadingWeek = false;
      });
    }
    catch (e)
    {
      if (!mounted || requestId != _weekRequestId)
      {
        return;
      }

      setState(() => _isLoadingWeek = false);
      CustomSnackBar.show(context: context, message: kWeekHoursLoadFailed, isError: true);
    }
  }

  Future<void> _loadUpcomingVariations() async
  {
    final today = romeNow();
    final requestId = ++_variationsRequestId;

    try
    {
      final days = await _apiService.getOpeningDays(
        dateFrom: addDays(today, -kScheduleLookbackDays),
        dateTo: addDays(today, kVariationsFetchDays),
      );

      if (!mounted || requestId != _variationsRequestId)
      {
        return;
      }

      setState(()
      {
        _upcomingVariations = upcomingVariationsOf(days, today);
        _variationsWindowEnd = addDays(today, kVariationsWindowDays);
        _scheduleByMode = standardScheduleOf(days, today);
        _isLoadingVariations = false;
      });
    }
    catch (e)
    {
      if (!mounted || requestId != _variationsRequestId)
      {
        return;
      }

      setState(() => _isLoadingVariations = false);
      CustomSnackBar.show(context: context, message: kVariationsLoadFailed, isError: true);
    }
  }

  // Ignores clicks while loading so overlapping fetches cannot land out of order.
  void _goToPreviousWeek()
  {
    if (_isLoadingWeek || isOldestKeptWeek(_weekStart))
    {
      return;
    }

    setState(()
    {
      _weekStart = addDays(_weekStart, -7);
      _isLoadingWeek = true;
    });
    _loadWeek();
  }

  void _goToNextWeek()
  {
    if (_isLoadingWeek || isLastCalendarWeek(_weekStart))
    {
      return;
    }

    setState(()
    {
      _weekStart = addDays(_weekStart, 7);
      _isLoadingWeek = true;
    });
    _loadWeek();
  }

  void _goToWeekOf(DateTime day)
  {
    final DateTime weekStart = startOfWeek(day);

    if (_isLoadingWeek || isSameDate(weekStart, _weekStart))
    {
      return;
    }

    setState(()
    {
      _weekStart = weekStart;
      _isLoadingWeek = true;
    });
    _loadWeek();
  }

  bool get _isAdmin => widget.onWeeklyTemplatesChanged != null;

  // Awaited so the wizards close only after fresh data is on screen.
  Future<void> _reloadAll() async
  {
    setState(()
    {
      _isLoadingWeek = true;
      _isLoadingVariations = true;
    });

    await Future.wait([_loadWeek(), _loadUpcomingVariations()]);
  }

  void _openStandardWizard()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'StandardHoursWizard',
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 420),
      builder: (_) => StandardHoursWizard(
        currentTemplates: widget.weeklyTemplates,
        onSaved: () async
        {
          await widget.onWeeklyTemplatesChanged?.call();

          if (mounted)
          {
            await _reloadAll();
          }
        },
      ),
    );
  }

  void _openVariationWizard({CombinedVariation? initial, DateTime? day})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'VariationWizard',
      builder: (_) => VariationWizard(
        standardTemplates: widget.weeklyTemplates,
        initial: initial,
        day: day,
        onSaved: _reloadAll,
      ),
    );
  }

  void _openDay(DateTime day)
  {
    final run = CombinedVariation.from(_upcomingVariations)
        .where((run) => !run.isHoliday && !day.isBefore(run.start) && !day.isAfter(run.end))
        .firstOrNull;

    _openVariationWizard(initial: run, day: run == null ? day : null);
  }

  // Must go through the server: deleting rows locally would leave days with no hours.
  Future<void> _deleteVariation(CombinedVariation run) async
  {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmVariationDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        showClose: false,
        maxWidth: 480,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(confirmContext).pop(false),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(confirmContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              run.isSingleDay
                  ? 'La variazione di ${run.dateLabel.toLowerCase()} verrà eliminata e il giorno tornerà all\'orario standard.'
                  : 'La variazione "${run.dateLabel.toLowerCase()}" verrà eliminata e i giorni torneranno all\'orario standard.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted)
    {
      return;
    }

    // Reverting can drop a published calendar; the server refuses until confirmed.
    final confirmation = LossConfirmation(confirmLabel: 'ELIMINA COMUNQUE');

    try
    {
      for (final mode in run.bandsByMode.keys)
      {
        final done = await confirmation.run(
          context,
          (confirm) => _apiService.restoreStandardHours(
            dateFrom: run.start,
            dateTo: run.end,
            mode: mode,
            confirm: confirm,
          ),
        );

        if (!done || !mounted)
        {
          return;
        }
      }
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }

      return;
    }

    CustomSnackBar.show(context: context, message: 'Variazione eliminata.', isError: false);
    await _reloadAll();
  }

  Widget _buildActions()
  {
    final edit = AppGradientButton(
      label: 'MODIFICA ORARIO',
      icon: Icons.edit_rounded,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openStandardWizard,
    );

    final extraordinary = AppGradientButton(
      label: 'CHIUSURA/APERTURA STRAORDINARIA',
      icon: kVariationIcon,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openVariationWizard,
    );

    // Not ResponsiveDialogButtonsRow: it reverses its children when stacking, wrong for peer actions.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth < kHoursActionsStackBreakpoint)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [edit, const SizedBox(height: 16), extraordinary],
          );
        }

        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [edit, extraordinary],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return PageTransitionScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.list,
            child: CombinedWeekCard(
              weekStart: _weekStart,
              openingDays: _weekOpeningDays,
              isLoading: _isLoadingWeek,
              onPreviousWeek: _goToPreviousWeek,
              onNextWeek: _goToNextWeek,
              onPickDay: _goToWeekOf,
              onDayTap: _isAdmin ? _openDay : null,
            ),
          ),
          const SizedBox(height: kHoursCardGap),
          PageTransitionItem(
            slot: PageTransitionItem.list + 1,
            child: CombinedStandardCard(scheduleByMode: _scheduleByMode, isLoading: _isLoadingVariations),
          ),
          const SizedBox(height: kHoursCardGap),
          PageTransitionItem(
            slot: PageTransitionItem.list + 2,
            child: CombinedVariationsCard(
              upcomingVariations: _upcomingVariations,
              windowEnd: _variationsWindowEnd,
              isLoading: _isLoadingVariations,
              onEdit: _isAdmin ? (run) => _openVariationWizard(initial: run) : null,
              onDelete: _isAdmin ? _deleteVariation : null,
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: kHoursCardGap),
            PageTransitionItem(slot: PageTransitionItem.list + 3, child: _buildActions()),
          ],
        ],
      ),
    );
  }
}
