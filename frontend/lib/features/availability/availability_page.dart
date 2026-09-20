import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/time_bucket.dart';
import '../../core/utils/week_range.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_dialog_footer.dart';
import '../../shared/widgets/app_dialog_stack.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/carousel_arrow_button.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../association/models/opening_day_item.dart';
import '../lessons/models/availability_group.dart';
import '../lessons/models/availability_item.dart';
import '../lessons/utils/booking_window.dart';
import '../lessons/utils/opening_window.dart';
import '../lessons/widgets/availability_wizard.dart';
import 'widgets/availability_day_row.dart';

const double _headerGap = 22;
const double _rowGap = 12;

const double _weekLabelWidth = 250;

const double _confirmWidth = 480;
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const Duration _tick = Duration(minutes: 1);

const String _teacherRole = 'TEACHER';

// This week from its Monday; the next week unlocks Friday 20:00.
class TeacherAvailabilityPage extends StatefulWidget
{
  const TeacherAvailabilityPage({super.key});

  @override
  State<TeacherAvailabilityPage> createState() => _TeacherAvailabilityPageState();
}

class _TeacherAvailabilityPageState extends State<TeacherAvailabilityPage>
    with DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();

  DateTime _now = DateTime.now();

  Timer? _clock;

  // 0 for the week of today, 1 for the next.
  int _weekIndex = 0;

  bool _isLoading = true;
  bool _failed = false;

  List<AvailabilityItem> _availabilities = [];
  List<OpeningDayItem> _openingDays = [];

  String? _meTaxCode;

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  DateTime get _thisMonday => startOfWeek(_today);

  bool get _isNextWeekUnlocked => isNextWeekUnlocked(_now);

  List<DateTime> get _shownDays => daysOfWeek(addDays(_thisMonday, 7 * _weekIndex));

  @override
  void initState()
  {
    super.initState();

    _clock = Timer.periodic(_tick, (_) => _advanceClock());

    _loadData();
  }

  @override
  void dispose()
  {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void onDestinationShown()
  {
    _advanceClock();
    _loadData(quiet: true);
  }

  // Reloads once Monday midnight shifts the weeks.
  void _advanceClock()
  {
    final DateTime before = _thisMonday;

    setState(()
    {
      _now = DateTime.now();

      if (!_isNextWeekUnlocked)
      {
        _weekIndex = 0;
      }
    });

    if (!isSameDate(before, _thisMonday))
    {
      _loadData(quiet: true);
    }
  }

  Future<void> _readWhoIAm() async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();

      if (mounted)
      {
        setState(() => _meTaxCode = me.taxCode);
      }
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'la lettura del profilo');
    }
  }

  // Both weeks are always fetched so the Friday unlock needs no reload.
  Future<void> _loadData({bool quiet = false}) async
  {
    unawaited(_readWhoIAm());

    final DateTime from = _thisMonday;
    final DateTime to = addDays(from, 13);

    try
    {
      final results = await Future.wait([
        _apiService.getAvailabilities(dateFrom: from, dateTo: to),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kPresenceMode),
        _apiService.getOpeningDays(dateFrom: from, dateTo: to, mode: kOnlineMode),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _availabilities = results[0] as List<AvailabilityItem>;
        _openingDays = [
          ...results[1] as List<OpeningDayItem>,
          ...results[2] as List<OpeningDayItem>,
        ];
        _isLoading = false;
        _failed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle disponibilità');

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _availabilities.isEmpty;
      });
    }
  }

  Future<bool> _executeCreate(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.createAvailability(
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
      ),
      apply: (created) => _availabilities = [..._availabilities, created],
      onError: onError,
    );
  }

  Future<bool> _executeEdit(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError)
  {
    return write(
      call: () => _apiService.updateAvailability(
        id: existing.id,
        teacherTaxCode: teacherTaxCode,
        date: date,
        mode: mode,
        startTime: startTime,
        endTime: endTime,
        expectedUpdatedAt: existing.updatedAt,
      ),
      apply: (updated) => _availabilities = _availabilities.map((a) => a.id == existing.id ? updated : a).toList(),
      onError: onError,
    );
  }

  Future<bool> _executeDeleteSlot(AvailabilityItem item, Function(String) onError)
  {
    return erase(
      call: () => _apiService.deleteAvailability(item.id),
      apply: () => _availabilities = _availabilities.where((a) => a.id != item.id).toList(),
      onError: onError,
    );
  }

  Future<void> _executeDeleteSlots(List<AvailabilityItem> slots) async
  {
    final removed = slots.map((slot) => slot.id).toSet();

    await erase(
      call: () async
      {
        for (final slot in slots)
        {
          await _apiService.deleteAvailability(slot.id);
        }
      },
      apply: () => _availabilities = _availabilities.where((a) => !removed.contains(a.id)).toList(),
      done: 'Disponibilità eliminata con successo!',
    );
  }

  void _showWizard(DateTime day, {AvailabilityGroup? group})
  {
    final String? taxCode = _meTaxCode;

    if (taxCode == null)
    {
      return;
    }

    showBlurredDialog(
      context: context,
      barrierLabel: 'AvailabilityWizard',
      builder: (context) => AvailabilityWizardDialog(
        existingGroup: group,
        ownTaxCode: taxCode,
        availableDays: computeAvailableDays(DateTime.now()),
        defaultDate: day,
        availabilities: _availabilities,
        openingDays: _openingDays,
        onCreate: _executeCreate,
        onEdit: _executeEdit,
        onDeleteSlot: _executeDeleteSlot,
      ),
    );
  }

  void _confirmDelete(DateTime day, List<AvailabilityItem> slots, {TimeBucket? band})
  {
    final String when = formatAvailableDayLabel(day).toLowerCase();

    final String warning = band == null
        ? "L'orario ${formatTimeRange(slots.single.startTime, slots.single.endTime)} "
            '${slots.single.mode == kOnlineMode ? kOnScreen : kInBuilding} di $when '
            'verrà eliminato definitivamente.'
        : 'La tua disponibilità ${_ofBand(band)} di $when verrà eliminata definitivamente.';

    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmAvailabilityDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: formatAvailableDayLabel(day),
        title: 'Confermi?',
        shrinkTitle: true,
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              _executeDeleteSlots(slots);
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              warning,
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
  }

  static String _ofBand(TimeBucket band)
  {
    return switch (band)
    {
      TimeBucket.morning => 'della mattina',
      TimeBucket.afternoon => 'del pomeriggio',
      TimeBucket.evening => 'della sera',
    };
  }

  List<AvailabilityItem> _slotsOn(DateTime day)
  {
    final onTheDay = _availabilities.where((availability) => isSameDate(availability.date, day)).toList();

    onTheDay.sort((a, b) => minutesOfTimeOfDay(a.startTime).compareTo(minutesOfTimeOfDay(b.startTime)));

    return onTheDay;
  }

  void _openDay(DateTime day, List<AvailabilityItem> slots)
  {
    if (slots.isEmpty)
    {
      _showWizard(day);

      return;
    }

    _showWizard(day, group: groupAvailabilities(slots).first);
  }

  String get _summary
  {
    final int given = _shownDays.where((day) => _slotsOn(day).isNotEmpty).length;
    final String week = _weekIndex == 0 ? 'questa settimana' : 'la settimana prossima';

    if (given == 0)
    {
      return 'Non hai ancora dato disponibilità $week';
    }

    return 'Hai dato disponibilità per $given ${given == 1 ? 'giorno' : 'giorni'} $week';
  }

  String get _summaryLine
  {
    return [
      if (!_isLoading && !_failed) _summary,
      if (!_isNextWeekUnlocked) 'La settimana prossima si sblocca venerdì alle 20:00',
    ].join(' · ');
  }

  Widget _buildHeader(AppWindowSize size)
  {
    final List<DateTime> days = _shownDays;

    final Widget facts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatDateSpan(days.first, days.last),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOcean,
          ),
        ),
        if (_summaryLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _summaryLine,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.trialMutedText),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Per le lezioni del mattino, è possibile aggiungere o modificare ' 
                'le disponibilità fino alle 20:00 del giorno precedente; '
                'per quelle del pomeriggio, fino alle 11:00 dello stesso '
                'giorno; per quelle della sera, fino alle 18:00 dello stesso giorno.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (!_isNextWeekUnlocked)
    {
      return facts;
    }

    if (size.isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          facts,
          const SizedBox(height: 16),
          _buildWeekNav(compact: true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: facts),
        const SizedBox(width: 24),
        _buildWeekNav(compact: false),
      ],
    );
  }

  // Fixed label width keeps the arrows still as the text changes.
  Widget _buildWeekNav({required bool compact})
  {
    final Widget label = Text(
      _weekIndex == 0 ? 'Questa settimana' : 'Settimana prossima',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    return Row(
      mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
      children: [
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          isDisabled: _weekIndex == 0,
          onTap: () => setState(() => _weekIndex = 0),
        ),
        const SizedBox(width: 8),
        if (compact) Expanded(child: label) else SizedBox(width: _weekLabelWidth, child: label),
        const SizedBox(width: 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          isDisabled: _weekIndex == 1,
          onTap: () => setState(() => _weekIndex = 1),
        ),
      ],
    );
  }

  Widget _buildRows()
  {
    if (_isLoading)
    {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
      );
    }

    if (_failed)
    {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text(
            'Non è stato possibile caricare le disponibilità.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AppTheme.trialMutedText,
            ),
          ),
        ),
      );
    }

    final DateTime today = _today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in _shownDays) ...[
          if (!isSameDate(day, _shownDays.first)) const SizedBox(height: _rowGap),
          Builder(
            builder: (context)
            {
              final List<AvailabilityItem> slots = _slotsOn(day);

              return AvailabilityDayRow(
                day: day,
                isToday: isSameDate(day, today),
                isPast: day.isBefore(today),
                slots: slots,
                openingDays: _openingDays,
                now: _now,
                onOpen: () => _openDay(day, slots),
                onDeleteSlot: (slot) => _confirmDelete(day, [slot]),
                onDeleteBand: (band, held) => _confirmDelete(day, held, band: band),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.fromWidth(width);
          final double margin = AppBreakpoints.pageMargin(size);

          final double contentWidth = width - 2 * margin;

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
                ),
                const PageWatermark(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, AppTopBar.contentTopInsetFor(size), margin, 28),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageTransitionItem(
                              slot: PageTransitionItem.header,
                              child: _buildHeader(size),
                            ),
                            const SizedBox(height: _headerGap),
                            Expanded(
                              child: PageTransitionScrollView(
                                child: PageTransitionItem(
                                  slot: PageTransitionItem.list,
                                  child: _buildRows(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                AppTopBar(currentRoute: '${homeForRole(_teacherRole)}/availability'),
              ],
            ),
          );
        },
      ),
    );
  }
}
