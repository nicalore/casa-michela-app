import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/language/app_language.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/week_range.dart';
import '../../../notifications/week_jump.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_load_failed.dart';
import '../../../../shared/widgets/desktop_tour.dart';
import '../../../../shared/widgets/dialog_components.dart';
import '../../../../shared/widgets/page_density.dart';
import '../../../../shared/widgets/page_transition.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../models/opening_day_item.dart';
import '../../association_tour.dart';
import '../../models/weekly_template_item.dart';
import 'begun_hours.dart';
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

const double _denseCardGap = 14;

class CombinedHoursView extends StatefulWidget
{
  final List<WeeklyTemplateItem> weeklyTemplates;

  final Future<void> Function()? onWeeklyTemplatesChanged;

  // After every read, once the week and the variations show: a reader's tour may start.
  final VoidCallback? onShown;

  // Whose "Associazione" it is in, so a notification for another role's is left to that one.
  final String? role;

  const CombinedHoursView({
    super.key,
    this.weeklyTemplates = const [],
    this.onWeeklyTemplatesChanged,
    this.onShown,
    this.role,
  });

  @override
  State<CombinedHoursView> createState() => _CombinedHoursViewState();
}

class _CombinedHoursViewState extends State<CombinedHoursView>
{
  final ApiService _apiService = ApiService();

  late DateTime _weekStart;
  bool _isLoadingWeek = true;
  List<OpeningDayItem> _weekOpeningDays = [];

  // The week _weekOpeningDays belongs to; null before the first read.
  DateTime? _weekHeld;
  Object? _weekFailure;

  // Bumped on every fetch so a stale answer cannot overwrite fresher data.
  int _weekRequestId = 0;
  int _variationsRequestId = 0;

  bool _isLoadingVariations = true;
  bool _variationsHeld = false;
  Object? _variationsFailure;
  List<OpeningDayItem> _upcomingVariations = [];
  List<OpeningDayItem> _todayRows = [];

  // Kept beside the data so the card filters on the window the rows were fetched for.
  late DateTime _variationsWindowEnd;

  StandardSchedule _scheduleByMode = {};

  @override
  void initState()
  {
    super.initState();

    // Opened from a notification: the week of the first day changed.
    _weekStart = startOfWeek(WeekJumps.hours.take(role: widget.role) ?? romeNow());
    _variationsWindowEnd = addDays(romeNow(), kVariationsWindowDays);
    _loadWeek();
    _loadUpcomingVariations();
    WeekJumps.hours.asked.addListener(_jump);
  }

  @override
  void dispose()
  {
    WeekJumps.hours.asked.removeListener(_jump);
    super.dispose();
  }

  // Already open: that week, read again in full with the variations.
  void _jump()
  {
    final DateTime? day = WeekJumps.hours.take(role: widget.role);

    if (day == null || !mounted)
    {
      return;
    }

    _weekStart = startOfWeek(day);
    unawaited(_reloadAll());
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
        _weekHeld = weekStart;
        _weekFailure = null;
        _isLoadingWeek = false;
      });
      _tellShown();
    }
    catch (e)
    {
      if (!mounted || requestId != _weekRequestId)
      {
        return;
      }

      setState(()
      {
        _isLoadingWeek = false;
        _weekFailure = e;
      });

      // A week on show keeps its hours and is told; one never read shows the failure in its place.
      if (_holdsShownWeek)
      {
        CustomSnackBar.show(context: context, message: kWeekHoursLoadFailed, isError: true);
      }
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
        _todayRows = days.where((day) => isSameDate(day.date, today)).toList();
        _variationsWindowEnd = addDays(today, kVariationsWindowDays);
        _scheduleByMode = standardScheduleOf(days, today);
        _variationsHeld = true;
        _variationsFailure = null;
        _isLoadingVariations = false;
      });
      _tellShown();
    }
    catch (e)
    {
      if (!mounted || requestId != _variationsRequestId)
      {
        return;
      }

      setState(()
      {
        _isLoadingVariations = false;
        _variationsFailure = e;
      });

      if (_variationsHeld)
      {
        CustomSnackBar.show(context: context, message: kVariationsLoadFailed, isError: true);
      }
    }
  }

  bool get _holdsShownWeek
  {
    final DateTime? held = _weekHeld;

    return held != null && isSameDate(held, _weekStart);
  }

  bool get _isWeekMissing => !_isLoadingWeek && _weekFailure != null && !_holdsShownWeek;

  bool get _areVariationsMissing => !_isLoadingVariations && _variationsFailure != null && !_variationsHeld;

  // Reads only the parts the view is short of.
  Future<void> _retryLoad() async
  {
    await Future.wait([
      if (_isWeekMissing) _loadWeek(),
      if (_areVariationsMissing) _loadUpcomingVariations(),
    ]);
  }

  void _tellShown()
  {
    if (!_isLoadingWeek && !_isLoadingVariations)
    {
      widget.onShown?.call();
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
        todayRows: _todayRows,
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

  void _openVariationWizard({CombinedVariation? initial})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'VariationWizard',
      builder: (_) => VariationWizard(
        standardTemplates: widget.weeklyTemplates,
        todayRows: _todayRows,
        initial: initial,
        onSaved: _reloadAll,
      ),
    );
  }

  // Must go through the server: deleting rows locally would leave days with no hours.
  Future<void> _deleteVariation(CombinedVariation run) async
  {
    final now = romeNow();

    if (isSameDate(run.start, now))
    {
      for (final mode in run.bandsByMode.keys)
      {
        final standard = standardHoursOn(widget.weeklyTemplates, now.weekday, mode);
        final band = begunBandChanged(now, hoursOfRows(_todayRows, mode), standard, now);

        if (band != null)
        {
          CustomSnackBar.show(context: context, message: begunHoursError(mode, band), isError: true);
          return;
        }
      }
    }

    final confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmVariationDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: tr('Eliminazione', 'Deletion'),
        title: tr('Confermi?', 'Confirm?'),
        showClose: false,
        maxWidth: 480,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: tr('ANNULLA', 'CANCEL'),
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialVioletText,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(confirmContext).pop(false),
          ),
          primary: AppGradientButton(
            label: tr('ELIMINA', 'DELETE'),
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDangerText,
            height: 52,
            fontSize: 14,
            onPressed: () => Navigator.of(confirmContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              run.isSingleDay
                  ? tr(
                      'La variazione di ${run.dateLabel.toLowerCase()} verrà eliminata e il giorno tornerà all\'orario standard.',
                      'The schedule change on ${run.dateLabel} will be deleted and the day will go back to the standard hours.',
                    )
                  : tr(
                      'La variazione "${run.dateLabel.toLowerCase()}" verrà eliminata e i giorni torneranno all\'orario standard.',
                      'The schedule change “${run.dateLabel}” will be deleted and the days will go back to the standard hours.',
                    ),
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
    final confirmation = LossConfirmation(confirmLabel: tr('ELIMINA COMUNQUE', 'DELETE ANYWAY'));

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

    CustomSnackBar.show(context: context, message: tr('Variazione eliminata.', 'Schedule change deleted.'), isError: false);
    unawaited(
      _apiService.announceOpeningHours(dateFrom: run.start, dateTo: run.end).catchError((Object _) {}),
    );
    await _reloadAll();
  }

  Widget _buildActions()
  {
    final edit = AppGradientButton(
      label: tr('MODIFICA ORARIO', 'EDIT HOURS'),
      icon: Icons.edit_rounded,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openStandardWizard,
    );

    final extraordinary = AppGradientButton(
      label: tr('CHIUSURA/APERTURA STRAORDINARIA', 'SPECIAL CLOSING/OPENING'),
      icon: kVariationIcon,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openVariationWizard,
    );

    // Not ResponsiveDialogButtonsRow: it reverses children when stacking, wrong for peers.
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
    // Below the wide window the cards and buttons take a dense page's sizes.
    final bool dense = AppBreakpoints.of(context).isDense;
    final double gap = dense ? _denseCardGap : kHoursCardGap;

    if (_isWeekMissing || _areVariationsMissing)
    {
      return AppLoadFailedRoom(
        error: _isWeekMissing ? _weekFailure : _variationsFailure,
        message: _isWeekMissing ? kWeekHoursLoadFailed : kVariationsLoadFailed,
        onRetry: _retryLoad,
      );
    }

    return AppPageDensity(dense: dense, child: _buildCards(gap));
  }

  Widget _buildCards(double gap)
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
            ),
          ),
          SizedBox(height: gap),
          PageTransitionItem(
            slot: PageTransitionItem.list + 1,
            child: DesktopTourTarget(
              id: kTourAssociationStandard,
              child: CombinedStandardCard(scheduleByMode: _scheduleByMode, isLoading: _isLoadingVariations),
            ),
          ),
          SizedBox(height: gap),
          PageTransitionItem(
            slot: PageTransitionItem.list + 2,
            child: CombinedVariationsCard(
              upcomingVariations: _upcomingVariations,
              windowEnd: _variationsWindowEnd,
              isLoading: _isLoadingVariations,
              onEdit: _isAdmin ? (run) => _openVariationWizard(initial: run) : null,
              onDelete: _isAdmin ? _deleteVariation : null,
              tour: kTourAssociationVariations,
            ),
          ),
          if (_isAdmin) ...[
            SizedBox(height: gap),
            PageTransitionItem(slot: PageTransitionItem.list + 3, child: _buildActions()),
          ],
        ],
      ),
    );
  }
}
