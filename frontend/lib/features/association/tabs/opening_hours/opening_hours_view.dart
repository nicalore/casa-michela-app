import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
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
import 'edit_hours_dialog.dart';
import 'extraordinary_hours_dialog.dart';
import 'lost_calendars.dart';
import 'opening_hours_table_card.dart';
import 'opening_hours_layout.dart';
import 'standard_hours_card.dart';
import 'upcoming_variations_card.dart';
import 'variation_group.dart';

// Shared by the "In presenza" and "Online" tabs; only the mode filter differs.
class OpeningHoursView extends StatefulWidget
{
  final String mode;
  final List<WeeklyTemplateItem> weeklyTemplates;
  final Future<void> Function() onWeeklyTemplatesChanged;

  const OpeningHoursView({
    super.key,
    required this.mode,
    required this.weeklyTemplates,
    required this.onWeeklyTemplatesChanged,
  });

  @override
  State<OpeningHoursView> createState() => _OpeningHoursViewState();
}

class _OpeningHoursViewState extends State<OpeningHoursView>
{
  static const int _scheduleLookbackDays = 27;

  static const int _variationsWindowDays = 60;

  // Fetches past the window so a run starting inside it keeps its real end date.
  static const int _variationsFetchDays = _variationsWindowDays + 90;

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

  Map<int, List<OpeningDayItem>> _scheduleByWeekday = {};

  @override
  void initState()
  {
    super.initState();
    _weekStart = startOfWeek(DateTime.now());
    _variationsWindowEnd = addDays(DateTime.now(), _variationsWindowDays);
    _loadWeek();
    _loadUpcomingVariations();
  }

  Future<void> _loadWeek() async
  {
    final requestId = ++_weekRequestId;
    final weekStart = _weekStart;

    try
    {
      final days = await _apiService.getOpeningDays(
        dateFrom: weekStart,
        dateTo: addDays(weekStart, 6),
        mode: widget.mode,
      );

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
      CustomSnackBar.show(context: context, message: 'Impossibile caricare gli orari della settimana.', isError: true);
    }
  }

  Future<void> _loadUpcomingVariations() async
  {
    final today = DateTime.now();
    final requestId = ++_variationsRequestId;

    try
    {
      // Reaches back so today's schedule can come from a past weekday when the
      // upcoming occurrence is a holiday.
      final days = await _apiService.getOpeningDays(
        dateFrom: addDays(today, -_scheduleLookbackDays),
        dateTo: addDays(today, _variationsFetchDays),
        mode: widget.mode,
      );

      if (!mounted || requestId != _variationsRequestId)
      {
        return;
      }

      final variations = days
          .where((d) => d.isOverride && !d.date.isBefore(DateTime(today.year, today.month, today.day)))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      setState(()
      {
        _upcomingVariations = variations;
        _variationsWindowEnd = addDays(today, _variationsWindowDays);
        _scheduleByWeekday = _deriveCurrentSchedule(days, today);
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
      CustomSnackBar.show(context: context, message: 'Impossibile caricare le variazioni programmate.', isError: true);
    }
  }

  // Hours in force per weekday: latest non-override occurrence of each weekday
  // within the next week, so a future change is not shown as today's schedule.
  Map<int, List<OpeningDayItem>> _deriveCurrentSchedule(List<OpeningDayItem> days, DateTime today)
  {
    final horizon = addDays(today, 6);
    final chosenDate = <int, DateTime>{};
    final schedule = <int, List<OpeningDayItem>>{};

    final inWindow = days.where((d) => !d.isOverride && !d.date.isAfter(horizon)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final day in inWindow)
    {
      final weekday = day.date.weekday;
      final chosen = chosenDate[weekday];

      if (chosen == null || day.date.isAfter(chosen))
      {
        chosenDate[weekday] = day.date;
        schedule[weekday] = [day];
      }
      else if (isSameDate(chosen, day.date))
      {
        schedule[weekday]!.add(day);
      }
    }

    return schedule;
  }

  // Ignores clicks while loading so overlapping fetches cannot land out of order.
  void _goToPreviousWeek()
  {
    if (_isLoadingWeek || !_weekStart.isAfter(startOfWeek(kAssociationFoundedOn)))
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
    if (_isLoadingWeek || addDays(_weekStart, 7).isAfter(calendarHorizon()))
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

  void _goToToday()
  {
    if (_isLoadingWeek)
    {
      return;
    }

    setState(()
    {
      _weekStart = startOfWeek(DateTime.now());
      _isLoadingWeek = true;
    });
    _loadWeek();
  }

  void _openEditHoursDialog()
  {
    final modeTemplates = widget.weeklyTemplates.where((t) => t.mode == widget.mode).toList();

    showBlurredDialog(
      context: context,
      barrierLabel: 'EditHoursDialog',
      // Not barrier-dismissible: a stray tap would discard everything typed.
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 420),
      builder: (_) => EditHoursDialog(
        mode: widget.mode,
        currentTemplates: modeTemplates,
        onSaved: _onWeeklyTemplatesSaved,
      ),
    );
  }

  Future<void> _onWeeklyTemplatesSaved() async
  {
    await widget.onWeeklyTemplatesChanged();

    if (!mounted)
    {
      return;
    }

    await _reloadAll();
  }

  void _openExtraordinaryDialog({VariationGroup? initial})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'ExtraordinaryHoursDialog',
      builder: (_) => ExtraordinaryHoursDialog(
        mode: widget.mode,
        onSaved: _onOpeningDaysSaved,
        standardTemplates:
            widget.weeklyTemplates.where((row) => row.mode == widget.mode).toList(),
        initial: initial,
      ),
    );
  }

  // Restoring standard hours must go through the server; deleting the rows
  // locally would leave those days with no hours at all.
  Future<void> _deleteVariation(VariationGroup group) async
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
              group.isSingleDay
                  ? 'La variazione di ${group.dateLabel.toLowerCase()} verrà eliminata e il giorno tornerà all\'orario standard.'
                  : 'La variazione "${group.dateLabel.toLowerCase()}" verrà eliminata e i giorni torneranno all\'orario standard.',
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

    // Reverting can shut a day and drop its published calendar; the server
    // refuses the write until the loss is confirmed.
    final confirmation = LossConfirmation(confirmLabel: 'ELIMINA COMUNQUE');

    try
    {
      final done = await confirmation.run(
        context,
        (confirm) => _apiService.restoreStandardHours(
          dateFrom: group.start,
          dateTo: group.end,
          mode: widget.mode,
          confirm: confirm,
        ),
      );

      if (!done)
      {
        return;
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

    if (!mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: 'Variazione eliminata.', isError: false);
    await _onOpeningDaysSaved();
  }

  Future<void> _onOpeningDaysSaved() async
  {
    if (!mounted)
    {
      return;
    }

    await _reloadAll();
  }

  // Awaited so dialogs close only after fresh data is on screen.
  Future<void> _reloadAll() async
  {
    setState(()
    {
      _isLoadingWeek = true;
      _isLoadingVariations = true;
    });

    await Future.wait([_loadWeek(), _loadUpcomingVariations()]);
  }

  Widget _editHoursButton()
  {
    return AppGradientButton(
      label: 'MODIFICA ORARIO',
      icon: Icons.edit_rounded,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openEditHoursDialog,
    );
  }

  Widget _extraordinaryButton()
  {
    return AppGradientButton(
      label: 'CHIUSURA/APERTURA STRAORDINARIA',
      icon: Icons.flag_rounded,
      height: kHoursActionButtonHeight,
      fontSize: 14,
      onPressed: _openExtraordinaryDialog,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final tableCard = OpeningHoursTableCard(
      weekStart: _weekStart,
      openingDays: _weekOpeningDays,
      isLoading: _isLoadingWeek,
      onPreviousWeek: _goToPreviousWeek,
      onNextWeek: _goToNextWeek,
      onToday: _goToToday,
    );

    final standardHoursCard = StandardHoursCard(
      scheduleByWeekday: _scheduleByWeekday,
      isLoading: _isLoadingVariations,
    );

    final upcomingVariationsCard = UpcomingVariationsCard(
      upcomingVariations: _upcomingVariations,
      windowEnd: _variationsWindowEnd,
      isLoading: _isLoadingVariations,
      onEdit: (group) => _openExtraordinaryDialog(initial: group),
      onDelete: _deleteVariation,
    );

    return PageTransitionScrollView(
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final isCompact = constraints.maxWidth < kHoursCompactBreakpoint;

          final lowerCards = isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tableCard,
                    const SizedBox(height: kHoursCardGap),
                    upcomingVariationsCard,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tableCard),
                    const SizedBox(width: kHoursCardGap),
                    Expanded(child: upcomingVariationsCard),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTransitionItem(
                slot: PageTransitionItem.list,
                child: standardHoursCard,
              ),
              const SizedBox(height: kHoursCardGap),
              PageTransitionItem(
                slot: PageTransitionItem.list + 1,
                child: lowerCards,
              ),
              const SizedBox(height: kHoursCardGap),
              // Not ResponsiveDialogButtonsRow: it swaps its children's order
              // when stacking, which is wrong for two peer actions.
              Center(
                child: PageTransitionItem(
                  slot: PageTransitionItem.list + 2,
                  child: isCompact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _editHoursButton(),
                            const SizedBox(height: 16),
                            _extraordinaryButton(),
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _editHoursButton(),
                            _extraordinaryButton(),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
