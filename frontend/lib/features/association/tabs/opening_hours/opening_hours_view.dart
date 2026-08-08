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
import 'opening_hours_table_card.dart';
import 'opening_hours_layout.dart';
import 'standard_hours_card.dart';
import 'upcoming_variations_card.dart';
import 'variation_group.dart';

// Shared, mode-parameterized: "In presenza" and "Online" need identical
// structure (weekly table + fixed-hours/variations cards), differing only by
// the mode filter, so both tab wrappers delegate to a single instance of this
// widget instead of duplicating the whole UI twice.
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

  /// How far ahead a variation counts as upcoming.
  static const int _variationsWindowDays = 60;

  /// Fetched past the window's end on purpose: a variation can start inside the
  /// sixty days and run beyond them, and cutting the rows at the boundary would
  /// show it ending there. The card drops the groups that start too late, after
  /// it has read each run whole.
  static const int _variationsFetchDays = _variationsWindowDays + 90;

  final ApiService _apiService = ApiService();

  late DateTime _weekStart;
  bool _isLoadingWeek = true;
  List<OpeningDayItem> _weekOpeningDays = [];

  /// Bumped on every fetch, so an answer that is no longer the current one is
  /// dropped instead of overwriting fresher data.
  int _weekRequestId = 0;
  int _variationsRequestId = 0;

  // Independent of the displayed week, fetched once on mount. The whole sorted
  // list is kept in state; both the sixty-day window and the truncation to
  // "however many rows fit" happen at render time, inside
  // UpcomingVariationsCard, not here.
  bool _isLoadingVariations = true;
  List<OpeningDayItem> _upcomingVariations = [];

  /// Kept beside the data rather than recomputed in build, so the window the
  /// card filters on is the same one the rows were fetched for.
  late DateTime _variationsWindowEnd;

  // Derived from the same fetch: the hours in force per weekday right now.
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
    // Only the newest request may write to the state. Saving the standard hours
    // fires a reload while the user is free to keep stepping through the weeks,
    // and without this the slower answer could land last and put the pre-save
    // week back on screen — the card looking like it had not updated at all.
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
    // Same reason as _loadWeek: this fetch feeds the standard-hours card, and a
    // stale answer landing last is exactly "the card does not always update".
    final requestId = ++_variationsRequestId;

    try
    {
      // Reaches back four weeks as well: the schedule in force today is read
      // off the most recent occurrence of each weekday, which may be behind us
      // when the upcoming one is a holiday.
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

  /// The hours in force per weekday as of today, read off the generated
  /// calendar rather than the templates.
  ///
  /// Bounded to the week ahead: a change dated months from now is already in
  /// the calendar, but it is not today's schedule and must not be shown as
  /// such. Within that bound it takes the LATEST non-override occurrence of
  /// each weekday, so the most recent state wins and a holiday on the upcoming
  /// Monday falls back to the Monday before rather than reading as closed.
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
        // Same day, another band.
        schedule[weekday]!.add(day);
      }
    }

    return schedule;
  }

  // Guards against a rapid double-click firing two overlapping fetches (whose
  // responses could then land out of order) without visually disabling the
  // arrows/button — nav controls stay in their normal state throughout, the
  // table's own opacity dip is the only loading feedback.
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
      // The paper between the floating pieces of this dialog is page as much as
      // the paper around it, and a tap that fell in one of those gaps would
      // throw away every hour typed so far. It closes by its own X or by
      // ANNULLA, and by nothing else.
      barrierDismissible: false,
      // Long enough for the pieces to arrive one after the other.
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
        // The same ones the standard-hours editor receives: they are what
        // recognises a variation repeating what the day already does.
        standardTemplates:
            widget.weeklyTemplates.where((row) => row.mode == widget.mode).toList(),
        initial: initial,
      ),
    );
  }

  // Undoing a variation is not a plain delete: the days have to go back to the
  // weekly template's hours, which only the server can write (every row the API
  // accepts is flagged as an override). Deleting the rows here would leave
  // those days with no hours at all.
  Future<void> _deleteVariation(VariationGroup group) async
  {
    final confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmVariationDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        // ANNULLA is already the way out of this one.
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
                  : 'La variazione "${group.dateLabel.toLowerCase()}" verrà eliminata e quei giorni torneranno all\'orario standard.',
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

    try
    {
      await _apiService.restoreStandardHours(
        dateFrom: group.start,
        dateTo: group.end,
        mode: widget.mode,
      );
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

  /// Both fetches, with the cards showing they are reloading meanwhile.
  ///
  /// Awaited rather than fired and forgotten: the dialogs close on the back of
  /// this, and popping while the answers were still in flight left the old
  /// hours on screen for a beat — which reads as the save not having taken.
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
          // Below this width neither the table's 4 columns nor the standard
          // board's 7 survive being halved, so the cards stack instead of
          // sitting side by side.
          final isCompact = constraints.maxWidth < kHoursCompactBreakpoint;

          // The variations card is pinned to the table's own height, so the two
          // line up with no IntrinsicHeight negotiation and nothing resizes as
          // the data changes.
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
              // The three cards are one above the other two, and on a page
              // change they leave in that order: the top band first, then the
              // two below, then the buttons.
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
              // The app's standard blue action button. Laid out explicitly
              // rather than via ResponsiveDialogButtonsRow, which swaps its
              // two children's order when it stacks — right for a
              // cancel/confirm pair, wrong for two peer actions.
              // Each button is as wide as what it says, the pair centred under
              // the cards. Split down a fixed 760 they came out at 372 apiece
              // for a label that wants 180, which reads as two banners rather
              // than as two things to press.
              //
              // Below the breakpoint they stack and take the full width
              // instead: on a phone a button narrower than the screen has
              // nothing to line up with, and the longer label needs the room.
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
