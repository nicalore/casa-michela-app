import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../core/utils/word_lists.dart';
import '../../../features/accounting/utils/opening_strings.dart' show openingRowLabel;
import '../../../features/association/tabs/opening_hours/calendar_bounds.dart' show kAssociationFoundedOn;
import '../../../features/auth/models/me_response.dart';
import '../../../features/notifications/compensation_seen.dart';
import '../../../features/people/models/compensation_items.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/person_jump.dart';
import '../../../features/people/utils/compensation_strings.dart';
import '../../../features/people/utils/payments_strings.dart' show kPaymentsSection;
import '../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../services/api_service.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../../shared/utils/day_marks.dart' show kTodayLabel;
import '../../../shared/widgets/app_month_button.dart' show kPickMonthLabel, kShortMonthNames;
import '../../layout/mobile_breakpoints.dart';
import '../../shared/device_files.dart';
import '../../shared/mobile_line_breaks.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_date_capsule.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_load_failed.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../home/widgets/mobile_link.dart';
import '../profile/widgets/mobile_detail_card.dart';
import '../profile/widgets/mobile_report_sheet.dart';
import 'mobile_compensation_tour.dart';
import 'mobile_fees_tab.dart';

String get _title => kWalletSection;

const double _phoneMargin = 20;
const double _tabletMargin = 44;
const double _handleClearance = 16;
const double _headerGap = 14;
const double _stripGap = 14;
const double _topRoom = 16;

const Duration _pageTurn = Duration(milliseconds: 320);

const int _payPage = 0;

// A month that takes longer than this to arrive shows the wait.
const Duration _slowMonth = Duration(milliseconds: 400);

const double _cardRadius = 22;

// Tour holes: the part's corner plus what they grow by.
const EdgeInsets _tourCardInflate = EdgeInsets.all(6);
const double _tourCardRadius = _cardRadius + 6;
const EdgeInsets _tourButtonInflate = EdgeInsets.all(4);
const double _tourButtonRadius = 18 + 4;
const EdgeInsets _tourMonthInflate = EdgeInsets.all(5);
const double _tourMonthRadius = 30;
const EdgeInsets _tourRowInflate = EdgeInsets.fromLTRB(8, 6, 8, 6);
const double _tourRowRadius = 16;
const EdgeInsets _tourTileInflate = EdgeInsets.all(3);
const double _tourTileRadius = 14 + 3;

Widget _tourCard(String id, Widget child, {bool clipped = false})
{
  return MobileTourTarget(id: id, inflate: _tourCardInflate, radius: _tourCardRadius, clipped: clipped, child: child);
}

Widget _tourButton(String id, Widget child)
{
  return MobileTourTarget(id: id, inflate: _tourButtonInflate, radius: _tourButtonRadius, child: child);
}
const double _tileGap = 4;
const double _weekGap = 12;

// Under this the gaps between the phone's columns are too thin: the volunteering goes to the day sheet.
const double _leastGap = 8;

// Below this width the tablet stacks its pay card as the phone does.
const double _payRowMinWidth = 1000;

Color get _disabledMonth => ThemeColours.fixed(0xFFA9B6BE);

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

String _span(CompensationSpan span) => '${span.start}–${span.end}';

String _spans(List<CompensationSpan> spans, int minutes)
{
  if (spans.isEmpty)
  {
    return '—';
  }

  return '${joinWithAnd([for (final span in spans) _span(span)])} (${formatMinutes(minutes)})';
}

String _money(int? cents) => cents == null ? '—' : formatAmount(cents);

String _dayTitle(DateTime day)
{
  final String weekday = weekdayFullName(day.weekday);

  return '$weekday ${formatDayMonthFull(day)}';
}

bool _newWeek(CompensationDay day, CompensationDay? before)
{
  return before != null && startOfWeek(before.date) != startOfWeek(day.date);
}

TextStyle _labelStyle({double size = 12.5}) => GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: MobilePalette.mutedText,
    );

TextStyle _cellStyle({bool strong = false, double size = 15, Color? color}) => GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      color: color ?? (strong ? AppTheme.trialInk : AppTheme.trialInk.withValues(alpha: 0.86)),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// A teacher's Portafoglio, read only: their pay month by month, and their fees on the next tab.
class MobileCompensationPage extends StatefulWidget
{
  final MeResponse user;

  const MobileCompensationPage({super.key, required this.user});

  @override
  State<MobileCompensationPage> createState() => _MobileCompensationPageState();
}

class _MobileCompensationPageState extends State<MobileCompensationPage>
{
  final ApiService _api = ApiService();

  final DateTime _last = _monthOf(romeNow());
  // Accounting has no time limit: back to the association's first month.
  final DateTime _first = _monthOf(kAssociationFoundedOn);

  late DateTime _month = _clamped(CompensationJumps.take()) ?? _last;

  CompensationMonth? _shown;
  // The month [_shown] is, which stays on screen while another is on its way.
  late DateTime _shownMonth = _month;
  bool _loading = true;
  Object? _failure;

  // Past the first load the page is kept: another month takes the place of the one shown.
  bool _opened = false;
  Timer? _slow;

  bool _saving = false;

  // The tour waits for the page to have come in; the day sheet tells it when it is up.
  bool _toured = false;
  final PaySheetTourLink _sheetLink = PaySheetTourLink();

  Set<DateTime> _worked = const {};
  // The teacher's record, for the IBAN and its report.
  PersonItem? _person;

  // Only the last month asked for may land: the arrows can outrun the answers.
  int _asked = 0;

  // Loaded with the pay, so the fees are there when their tab comes in.
  late final MobileFeesSource _fees = MobileFeesSource(_taxCode);

  final PageController _pages = PageController();
  int _page = _payPage;
  int _restingPage = _payPage;

  String get _taxCode => widget.user.taxCode;

  @override
  void initState()
  {
    super.initState();
    Future.wait([_load(), _fees.load()]).whenComplete(MobileHoldScope.hold(context));
    _pages.addListener(_onPages);
    // The tour counts the fees' parts: it waits for them too.
    _fees.addListener(_tourLater);
    _loadPerson();
    _loadWorked();
    CompensationJumps.asked.addListener(_jump);
    mobileTourChanges.addListener(_tourLater);
    MobileNavSheet.hidden.addListener(_onSheets);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_toured && mobileTourSettled(context))
    {
      _toured = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    _slow?.cancel();
    CompensationJumps.asked.removeListener(_jump);
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.hidden.removeListener(_onSheets);
    _sheetLink.dispose();
    _pages.dispose();
    _fees.dispose();
    super.dispose();
  }

  // Also when a tour ends, so parts appearing together come one after the other.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  // A sheet closing gives the page back to its tours.
  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // The day the tour opens: the first of the month.
  void _openFirstDay()
  {
    final CompensationDay? day = _shown?.days.firstOrNull;

    if (day != null)
    {
      _openDay(day);
    }
  }

  // The whole page on the first visit, then the parts shown for the first time.
  Future<void> _tourCheck() async
  {
    if (!mounted ||
        !_toured ||
        _fees.loading ||
        _loading ||
        _shown == null ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value)
    {
      return;
    }

    final bool tablet = MobileBreakpoints.of(context).isTablet;

    if (!await isMobileTourSeen(taxCode: _taxCode, tour: compensationMainTour))
    {
      if (mounted)
      {
        await startMobileTourOnce(
          taxCode: _taxCode,
          tour: compensationTour(
            tablet: tablet,
            sheet: _sheetLink,
            openDay: _openFirstDay,
            pages: _pages,
            fees: _fees,
          ),
        );
      }

      return;
    }

    if (mounted)
    {
      await startCompensationLateTour(
        taxCode: _taxCode,
        tablet: tablet,
        sheet: _sheetLink,
        openDay: _openFirstDay,
        pages: _pages,
        fees: _fees,
      );
    }
  }

  DateTime? _clamped(DateTime? month)
  {
    if (month == null)
    {
      return null;
    }

    final DateTime first = _monthOf(month);

    return first.isAfter(_last) ? _last : (first.isBefore(_first) ? _first : first);
  }

  // Sent to the pay by a link or a notification, maybe on a month.
  void _jump()
  {
    final DateTime? month = _clamped(CompensationJumps.take());

    if (!mounted)
    {
      return;
    }

    if (_page != _payPage && _pages.hasClients)
    {
      _pages.animateToPage(_payPage, duration: _pageTurn, curve: Curves.easeInOutCubic);
    }

    if (month != null)
    {
      _go(month);
    }
  }

  void _onPageChanged(int page)
  {
    _page = page;
  }

  // A tab come to rest: the parts on it never told are told now.
  void _onPages()
  {
    if (!_pages.hasClients)
    {
      return;
    }

    final double page = _pages.page ?? 0;
    final int near = page.round();

    if ((page - near).abs() < 0.001 && near != _restingPage)
    {
      _restingPage = near;
      _tourLater();
    }
  }


  // [quiet]: a refresh of the month on show, which keeps it if the refresh fails.
  Future<void> _load({bool quiet = false}) async
  {
    final int asked = ++_asked;
    final DateTime month = _month;

    try
    {
      final CompensationMonth shown = await _api.getCompensation(_taxCode, month);

      if (!mounted || asked != _asked)
      {
        return;
      }

      _slow?.cancel();
      setState(()
      {
        _shown = shown;
        _shownMonth = month;
        _loading = false;
        _failure = null;
        _opened = true;
      });

      // The pay on screen: what told of a changed unpaid hour is done.
      unawaited(markCompensationSeen(month));
      _tourLater();
    }
    catch (error)
    {
      if (!mounted || asked != _asked || (quiet && _shown != null))
      {
        return;
      }

      // Better nothing than last month's money under this month's name.
      _slow?.cancel();
      setState(()
      {
        _shown = null;
        _loading = false;
        _failure = error;
        _opened = true;
      });
    }
  }

  // The IBAN shows only when on record; a failure leaves the page without it.
  Future<void> _loadPerson() async
  {
    try
    {
      final PersonItem person = await _api.getPerson(_taxCode);

      if (mounted)
      {
        setState(() => _person = person);
      }
    }
    catch (_)
    {
      // The pay still shows.
    }
  }

  // Only the month sheet's dots: a failure leaves it without them.
  Future<void> _loadWorked() async
  {
    try
    {
      final Set<DateTime> worked = await _api.getCompensationMonths(_taxCode);

      if (mounted)
      {
        setState(() => _worked = worked);
      }
    }
    catch (_)
    {
      // No dots.
    }
  }

  Future<void> _refresh() async
  {
    await Future.wait([_load(quiet: true), _loadPerson(), _loadWorked()]);
  }

  // The month on show stays until the new one lands, then gives way with no movement.
  void _go(DateTime month)
  {
    if (month == _month && _shown != null)
    {
      return;
    }

    setState(() => _month = month);
    _slow?.cancel();
    _slow = Timer(_slowMonth, ()
    {
      if (mounted)
      {
        setState(() => _loading = true);
      }
    });
    _load();
  }

  Future<void> _pickMonth() async
  {
    final DateTime? picked = await showMobileSheet<DateTime>(
      context: context,
      builder: (context) => _MonthSheet(selected: _month, first: _first, last: _last, marked: _worked, taxCode: _taxCode),
    );

    if (picked != null && mounted)
    {
      _go(picked);
    }
  }

  // The bank transfer that paid the month, saved where the person chooses.
  Future<void> _saveReceipt() async
  {
    final CompensationReceipt? receipt = _shown?.receipt;

    if (receipt == null || _saving)
    {
      return;
    }

    setState(() => _saving = true);

    try
    {
      final Uint8List bytes = await _api.getCompensationReceipt(_taxCode, _shownMonth);
      final bool saved = await saveToDevice(bytes, fileName: receipt.fileName, mimeType: receipt.contentType);

      if (saved && mounted)
      {
        MobileNotice.show(context, kReceiptSaved);
      }
    }
    on PlatformException catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il salvataggio della ricevuta');

      if (mounted)
      {
        MobileNotice.show(context, kReceiptSaveFailed, error: true);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _saving = false);
      }
    }
  }

  // A wrong IBAN goes to the administrators as a report, the right one written in it.
  void _reportIban()
  {
    final PersonItem? person = _person;

    if (person != null)
    {
      showMobileReportSheet(
        context: context,
        person: person,
        fields: [kIbanLabel],
        eyebrow: kCompensationSection,
      );
    }
  }

  void _openDay(CompensationDay day)
  {
    showMobileSheet<void>(
      context: context,
      builder: (context) => _DaySheet(day: day, link: _sheetLink),
    );
  }

  Widget _buildTitle(bool tablet)
  {
    return Text(
      _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBody(bool tablet)
  {
    final CompensationMonth? shown = _shown;

    if (_loading)
    {
      return const MobileWaiting();
    }

    if (shown == null)
    {
      final Object? failure = _failure;

      return MobileLoadFailed(
        error: failure,
        message: failure == null ? kCompensationLoadFailed : readableApiError(failure),
        onRetry: _load,
        tablet: tablet,
      );
    }

    if (shown.days.isEmpty && shown.openingGross == null)
    {
      return MobileEmptyCard(icon: Icons.event_busy_rounded, message: noHoursMessage(_shownMonth), tablet: tablet);
    }

    final Widget days;

    if (!shown.isPaid)
    {
      days = _tourCard(kPayTourHours, _PlainTable(shown: shown, tablet: tablet), clipped: true);
    }
    else if (tablet)
    {
      days = _tourCard(kPayTourDays, _FullTable(shown: shown), clipped: true);
    }
    else
    {
      days = _tourCard(kPayTourDays, _DaysCard(shown: shown, onOpen: _openDay), clipped: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown.isPaid)
          _tourCard(kPayTourPay, _PayCard(shown: shown, month: _shownMonth, tablet: tablet))
        else
          _tourCard(kPayTourWork, _WorkCard(shown: shown, tablet: tablet)),
        const SizedBox(height: 14),
        days,
        if (shown.receipt != null) ...[
          const SizedBox(height: 20),
          _ButtonWidth(
            tablet: tablet,
            child: _tourButton(
              kPayTourReceipt,
              MobileGoldButton(
                label: kDownloadReceiptLabel,
                icon: Icons.download_rounded,
                busy: _saving,
                onPressed: () => unawaited(_saveReceipt()),
              ),
            ),
          ),
        ],
        if (_person?.iban != null) ...[
          SizedBox(height: shown.receipt != null ? 12 : 20),
          _ButtonWidth(
            tablet: tablet,
            child: _tourButton(
              kPayTourReport,
              MobileDismissButton(label: kReportIbanLabel, icon: Icons.flag_rounded, onPressed: _reportIban),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPay({required bool tablet, required EdgeInsets padding})
  {
    final String? iban = _person?.iban;

    final Widget body = _buildBody(tablet);
    final bool alone = body is MobileEmptyCard || body is MobileLoadFailed;

    return RefreshIndicator(
      color: AppTheme.trialGold,
      backgroundColor: AppTheme.trialDeepWater,
      onRefresh: _refresh,
      child: MobileEmptyScroll(
        padding: padding,
        head: [
          if (iban != null) ...[
            _tourCard(kPayTourIban, _IbanCard(iban: iban, tablet: tablet)),
            const SizedBox(height: _headerGap),
          ],
          MobileTourTarget(
            id: kPayTourMonth,
            inflate: _tourMonthInflate,
            radius: _tourMonthRadius,
            child: MobileDateCapsule(
              label: formatMonthYear(_month),
              widestLabel: formatMonthYear(DateTime(_last.year, 9)),
              current: _month == _last,
              tablet: tablet,
              onBack: _month.isAfter(_first) ? () => _go(DateTime(_month.year, _month.month - 1)) : null,
              onForward: _month.isBefore(_last) ? () => _go(DateTime(_month.year, _month.month + 1)) : null,
              onPick: _pickMonth,
            ),
          ),
          const SizedBox(height: _topRoom),
        ],
        body: MobileLoadSwitcher(waiting: _opened ? false : null, child: alone ? Center(child: body) : body),
        fill: alone,
        tail: const [MobileTourRunway()],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;
    final EdgeInsets padding = EdgeInsets.fromLTRB(margin, _topRoom, margin, bottom);

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: _buildTitle(tablet),
        ),
        const SizedBox(height: _stripGap),
        MobilePageStrip(
          labels: [kCompensationSection, kPaymentsSection],
          controller: _pages,
          scrollMargin: margin,
          tourTargets: [compensationTourTab(0), compensationTourTab(1)],
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pages,
          onPageChanged: _onPageChanged,
          // Not kept alive: a mounted, scrolled page stalls the shared header.
          children: [
            MobileSwipePage(child: _buildPay(tablet: tablet, padding: padding)),
            MobileSwipePage(child: MobileFeesTab(source: _fees, padding: padding, tablet: tablet)),
          ],
        ),
      ),
    );
  }
}

// As wide as the tablet's bar, like the settings' buttons; the phone's whole width.
class _ButtonWidth extends StatelessWidget
{
  final bool tablet;
  final Widget child;

  const _ButtonWidth({required this.tablet, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return tablet ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: child)) : child;
  }
}

class _Hairline extends StatelessWidget
{
  final double top;
  final double bottom;

  const _Hairline({this.top = 14, this.bottom = 12});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: 1,
      margin: EdgeInsets.only(top: top, bottom: bottom),
      color: AppTheme.trialInk.withValues(alpha: 0.1),
    );
  }
}

class _Figure extends StatelessWidget
{
  final String label;
  final String value;
  final double size;
  final Color color;

  const _Figure({required this.label, required this.value, required this.size, required this.color});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.15,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        WholeWords(child: Text(withoutOrphans(label), style: _labelStyle())),
      ],
    );
  }
}

// Equal columns with a hairline between them.
class _Columns extends StatelessWidget
{
  final List<Widget> cells;
  final List<int>? flexes;
  final Set<int> ruledBefore;

  const _Columns({required this.cells, this.flexes, this.ruledBefore = const {}});

  @override
  Widget build(BuildContext context)
  {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0)
              ruledBefore.isEmpty || ruledBefore.contains(i)
                  ? Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: AppTheme.trialInk.withValues(alpha: 0.12),
                    )
                  : const SizedBox(width: 12),
            Expanded(flex: flexes?[i] ?? 1, child: cell),
          ],
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget
{
  final String value;
  final String text;
  final double size;

  const _Total(this.value, this.text, {required this.size});

  @override
  Widget build(BuildContext context)
  {
    return WholeWords(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: FontWeight.w800, color: AppTheme.trialOceanText),
            ),
            TextSpan(text: ' $text'),
          ],
        ),
        style: GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
      ),
    );
  }
}

// The unpaid hour the month owes.
class _RuleLine extends StatelessWidget
{
  final CompensationMonth shown;
  final DateTime month;
  final bool tablet;

  const _RuleLine({required this.shown, required this.month, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.trialInk.withValues(alpha: 0.06)),
          child: Icon(Icons.volunteer_activism_rounded, size: 18, color: AppTheme.trialTealDeepText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WholeWords(child: Text(kVolunteeringLabel, style: _labelStyle(size: 12))),
              WholeWords(
                child: Text.rich(
                  TextSpan(
                    text: kVolunteeringRuleNames[shown.volunteering],
                    children: [
                      if (shown.volunteeringMonthOnly)
                        TextSpan(
                          text: ' (${volunteeringMonthOnlyNote(month)})',
                          style: TextStyle(fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
                        ),
                    ],
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tablet ? 16 : 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// The month's money, both rates, the totals and the unpaid hour.
class _PayCard extends StatelessWidget
{
  final CompensationMonth shown;
  final DateTime month;
  final bool tablet;

  const _PayCard({required this.shown, required this.month, required this.tablet});

  List<Widget> _moneyFigures(double size)
  {
    return [
      _Figure(label: kGrossPayLabel, value: _money(shown.gross), size: size, color: AppTheme.trialOceanText),
      _Figure(
        label: kWithholdingLabel,
        value: _money(withholdingOf(shown.gross, shown.net)),
        size: size,
        color: AppTheme.trialOceanText,
      ),
      _Figure(label: kNetPayLabel, value: _money(shown.net), size: size, color: AppTheme.trialTealDeepText),
    ];
  }

  List<Widget> _rates(double size)
  {
    return [
      _Figure(label: kGrossRateLabel, value: _money(shown.grossRate), size: size, color: AppTheme.trialOceanText),
      _Figure(label: kNetRateLabel, value: _money(shown.netRate), size: size, color: AppTheme.trialTealDeepText),
    ];
  }

  List<Widget> _totals(double size)
  {
    return [
      _Total('${shown.days.length}', workedDaysText(shown.days.length), size: size),
      _Total(formatMinutes(shown.workedMinutes), workedHoursText(shown.workedMinutes), size: size),
      _Total(formatMinutes(shown.volunteerMinutes), kVolunteerHoursText, size: size),
      _Total(formatMinutes(shown.paidMinutes), paidHoursText(shown.paidMinutes), size: size),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    if (tablet && MediaQuery.sizeOf(context).width >= _payRowMinWidth)
    {
      return MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Columns(
              cells: [..._moneyFigures(28), ..._rates(23)],
              flexes: const [4, 4, 4, 5, 5],
              ruledBefore: const {3},
            ),
            const _Hairline(top: 16, bottom: 14),
            Row(
              children: [
                for (final total in _totals(16)) Expanded(child: total),
              ],
            ),
            const _Hairline(top: 14, bottom: 12),
            MobileTourTarget(
              id: kPayTourVolunteering,
              inflate: _tourRowInflate,
              radius: _tourRowRadius,
              child: _RuleLine(shown: shown, month: month, tablet: true),
            ),
          ],
        ),
      );
    }

    final List<Widget> totals = _totals(tablet ? 16 : 14.5);

    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 22, 24, 20) : const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: LayoutBuilder(
        builder: (context, constraints) => _buildStacked(context, constraints.maxWidth, totals),
      ),
    );
  }

  // One size for the figures of a row, the widest fitting its column.
  double _fit(BuildContext context, List<int?> values, double size, double room)
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final double widest = values.map((value) => _Grid._width(context, _money(value), style)).reduce(math.max);

    return widest <= room ? size : size * room / widest;
  }

  Widget _buildStacked(BuildContext context, double width, List<Widget> totals)
  {
    // A column's share: the rule between two takes 12 + 1 + 12.
    final double third = (width - 2 * 25) / 3;
    final double money = _fit(context, [shown.gross, withholdingOf(shown.gross, shown.net), shown.net], tablet ? 28 : 22, third);
    final double rates = _fit(context, [shown.grossRate, shown.netRate], tablet ? 23 : 20, tablet ? third : (width - 25) / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Columns(cells: _moneyFigures(money)),
        const _Hairline(),
        _Columns(cells: [..._rates(rates), if (tablet) const SizedBox()], ruledBefore: tablet ? const {1} : const {}),
        const _Hairline(),
        if (tablet)
          Row(children: [for (final total in totals) Expanded(child: total)])
        else ...[
          Row(children: [Expanded(child: totals[0]), Expanded(child: totals[1])]),
          const SizedBox(height: 6),
          Row(children: [Expanded(child: totals[2]), Expanded(child: totals[3])]),
        ],
        const _Hairline(),
        MobileTourTarget(
          id: kPayTourVolunteering,
          inflate: _tourRowInflate,
          radius: _tourRowRadius,
          child: _RuleLine(shown: shown, month: month, tablet: tablet),
        ),
      ],
    );
  }
}

// The IBAN stays the same whatever the month, so it stands above it.
class _IbanCard extends StatelessWidget
{
  final String iban;
  final bool tablet;

  const _IbanCard({required this.iban, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 14, 14, 0) : const EdgeInsets.fromLTRB(18, 12, 8, 0),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: MobileDetailRows(rows: [DetailRowData(kIbanLabel, iban, isSensitive: true, hidesLength: true)]),
    );
  }
}

// A month with nothing to pay: days and hours only.
class _WorkCard extends StatelessWidget
{
  final CompensationMonth shown;
  final bool tablet;

  const _WorkCard({required this.shown, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final double size = tablet ? 28 : 22;

    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 22, 24, 20) : const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: _Columns(
        cells: [
          _Figure(label: kWorkedDaysLabel, value: '${shown.days.length}', size: size, color: AppTheme.trialOceanText),
          _Figure(
            label: kWorkedHoursLabel,
            value: formatMinutes(shown.workedMinutes),
            size: size,
            color: AppTheme.trialOceanText,
          ),
        ],
      ),
    );
  }
}

typedef _Cell = ({List<String> lines, TextStyle style});

// A column of the days: its heading and each day's text.
class _Col
{
  final String head;
  final _Cell Function(CompensationDay day, double size) cell;

  // On the set-up's row, the pay before the app's accounts: a dash unless given.
  final _Cell Function(double size)? opening;

  const _Col(this.head, this.cell, {this.opening});

  _Cell openingCell(double size) => opening?.call(size) ?? _dash(size);
}

// Each column as wide as its widest text; the room left is shared out evenly between them.
class _Grid
{
  final double size;
  final double headSize;
  final List<double> widths;
  final double gap;

  const _Grid(this.size, this.headSize, this.widths, this.gap);

  static double _width(BuildContext context, String text, TextStyle style)
  {
    final TextPainter painter = TextPainter(
      // As the Text will draw it, with what it inherits.
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = painter.width.ceilToDouble() + 1;

    painter.dispose();

    return width;
  }

  // Smaller text only when the gaps would come out too thin; with [shrink], under
  // [leastGap] at the smallest size, the text shrinks until that gap fits.
  static _Grid of(
    BuildContext context,
    List<_Col> columns,
    List<CompensationDay> days,
    double room, {
    required List<double> sizes,
    required double headSize,
    double minGap = 14,
    double leastGap = _leastGap,
    bool shrink = true,
    bool opening = false,
  })
  {
    double widest(_Cell cell, double start) =>
        cell.lines.fold(start, (w, line) => math.max(w, _width(context, line, cell.style)));

    _Grid measure(double size, double head)
    {
      final List<double> widths = [
        for (final column in columns)
          days.fold<double>(
            opening
                ? widest(column.openingCell(size), _width(context, column.head, _labelStyle(size: head)))
                : _width(context, column.head, _labelStyle(size: head)),
            (wide, day) => widest(column.cell(day, size), wide),
          ),
      ];
      final double used = widths.fold(0, (sum, width) => sum + width);

      return _Grid(size, head, widths, (room - used) / (columns.length - 1));
    }

    late _Grid grid;

    for (final size in sizes)
    {
      grid = measure(size, headSize);

      if (grid.gap >= minGap)
      {
        return grid;
      }
    }

    if (!shrink || grid.gap >= leastGap)
    {
      return grid;
    }

    // Widths follow the type size: a little under the share that leaves the gaps.
    final double used = room - grid.gap * (columns.length - 1);
    final double factor = (room - leastGap * (columns.length - 1)) / used * 0.97;

    return measure(grid.size * factor, headSize * factor);
  }

  Widget row(List<Widget> cells)
  {
    return Row(
      children: [
        for (final (i, cell) in cells.indexed) ...[
          if (i > 0) SizedBox(width: math.max(0, gap)),
          SizedBox(
            width: widths[i],
            child: Align(alignment: i == 0 ? Alignment.centerLeft : Alignment.center, child: cell),
          ),
        ],
      ],
    );
  }

  static Widget cellOf(_Cell cell)
  {
    if (cell.lines.length == 1)
    {
      return Text(cell.lines.single, style: cell.style, maxLines: 1, softWrap: false);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final line in cell.lines) Text(line, style: cell.style, maxLines: 1, softWrap: false)],
    );
  }
}

// [openingDay]: the last day the initial set-up paid for, naming its row.
_Col _dayColumn({required bool full, DateTime? openingDay})
{
  return _Col(
    kDayColumn,
    (day, size)
    {
      final String weekday = full ? weekdayFullName(day.date.weekday) : weekdayShortName(day.date.weekday);

      return (lines: ['$weekday ${day.date.day}'], style: _cellStyle(size: size, strong: true));
    },
    opening: openingDay == null
        ? null
        : (size) => (lines: [openingRowLabel(openingDay)], style: _cellStyle(size: size, strong: true)),
  );
}

// The pay the initial set-up gave for the days before the app's accounts, if any.
bool _hasOpening(CompensationMonth shown) => shown.openingGross != null && shown.openingDay != null;

_Cell _dash(double size) => (lines: const ['—'], style: _cellStyle(size: size, color: AppTheme.trialInk.withValues(alpha: 0.35)));

List<Widget> _spaced(List<CompensationDay> days, List<Widget> tiles)
{
  return [
    for (var i = 0; i < days.length; i++) ...[
      if (i > 0) SizedBox(height: _newWeek(days[i], days[i - 1]) ? _weekGap : _tileGap),
      tiles[i],
    ],
  ];
}

// The phone's days: a tile each, opening the day.
class _DaysCard extends StatelessWidget
{
  final CompensationMonth shown;
  final ValueChanged<CompensationDay> onOpen;

  const _DaysCard({required this.shown, required this.onOpen});

  static const double _tilePadding = 12;
  static const double _headSize = 12.5;

  List<_Col> _columns({required bool volunteering})
  {
    TextStyle gross(double size) => _cellStyle(size: size, strong: true, color: AppTheme.trialOceanText);
    TextStyle net(double size) => _cellStyle(size: size, strong: true, color: AppTheme.trialTealDeepText);

    return [
      _dayColumn(full: false, openingDay: shown.openingDay),
      _Col(kHoursColumn, (day, size) => (lines: [formatMinutes(day.workedMinutes)], style: _cellStyle(size: size))),
      if (volunteering)
        _Col(
          kVolunteerShortColumn,
          (day, size) => day.volunteerMinutes == 0
              ? _dash(size)
              : (lines: [formatMinutes(day.volunteerMinutes)], style: _cellStyle(size: size)),
        ),
      _Col(
        kGrossColumn,
        (day, size) => (lines: [_money(day.gross)], style: gross(size)),
        opening: (size) => (lines: [_money(shown.openingGross)], style: gross(size)),
      ),
      _Col(
        kNetColumn,
        (day, size) => (lines: [_money(day.net)], style: net(size)),
        opening: (size) => (lines: [_money(shown.openingNet)], style: net(size)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final List<CompensationDay> days = shown.days;
    final bool opening = _hasOpening(shown);

    return MobileGlassPanel(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          _Grid gridOf(List<_Col> columns, {required bool shrink}) => _Grid.of(
                context,
                columns,
                days,
                constraints.maxWidth - 2 * _tilePadding,
                sizes: const [15, 14, 13],
                headSize: _headSize,
                shrink: shrink,
                opening: opening,
              );

          // Very large text leaves no room for five: the volunteering stays in the day sheet.
          List<_Col> columns = _columns(volunteering: true);
          _Grid grid = gridOf(columns, shrink: false);

          if (grid.gap < _leastGap)
          {
            columns = _columns(volunteering: false);
            grid = gridOf(columns, shrink: true);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(_tilePadding, 0, _tilePadding, 8),
                child: grid.row([for (final column in columns) Text(column.head, style: _labelStyle(size: grid.headSize))]),
              ),
              // Not a day: nothing more to open.
              if (opening) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _tilePadding, vertical: 11),
                  child: grid.row([for (final column in columns) _Grid.cellOf(column.openingCell(grid.size))]),
                ),
                if (days.isNotEmpty) const SizedBox(height: _weekGap - _tileGap),
              ],
              ..._spaced(days, [
                for (final (i, day) in days.indexed)
                  MobileTourTarget(
                    id: i == 0 ? kPayTourDay : null,
                    inflate: _tourTileInflate,
                    radius: _tourTileRadius,
                    child: MobileLink(
                      onTap: () => onOpen(day),
                      child: MobileLinkTile(
                        padding: const EdgeInsets.symmetric(horizontal: _tilePadding, vertical: 11),
                        child: grid.row([for (final column in columns) _Grid.cellOf(column.cell(day, grid.size))]),
                      ),
                    ),
                  ),
              ]),
            ],
          );
        },
      ),
    );
  }
}

// A month with nothing to pay: when each day began and ended, nothing more to open.
class _PlainTable extends StatelessWidget
{
  final CompensationMonth shown;
  final bool tablet;

  const _PlainTable({required this.shown, required this.tablet});

  List<_Col> get _columns => [
        _dayColumn(full: tablet),
        _Col(kStartColumn, (day, size) => (lines: [for (final span in day.worked) span.start], style: _cellStyle(size: size))),
        _Col(kEndColumn, (day, size) => (lines: [for (final span in day.worked) span.end], style: _cellStyle(size: size))),
        _Col(
          kHoursColumn,
          (day, size) => (lines: [formatMinutes(day.workedMinutes)], style: _cellStyle(size: size, strong: true)),
        ),
      ];

  @override
  Widget build(BuildContext context)
  {
    final List<_Col> columns = _columns;
    final List<CompensationDay> days = shown.days;
    final double side = tablet ? 26 : 20;
    final double headSize = tablet ? 13.5 : 12.5;

    return MobileGlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final _Grid grid = _Grid.of(
            context,
            columns,
            days,
            constraints.maxWidth - 2 * side,
            sizes: tablet ? const [16] : const [15, 14, 13],
            headSize: headSize,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(side, 14, side, 11),
                decoration: BoxDecoration(
                  color: AppTheme.trialInk.withValues(alpha: 0.035),
                  border: Border(bottom: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.1))),
                ),
                child: grid.row([for (final column in columns) Text(column.head, style: _labelStyle(size: grid.headSize))]),
              ),
              for (var i = 0; i < days.length; i++)
                Container(
                  constraints: BoxConstraints(minHeight: tablet ? 50 : 46),
                  padding: EdgeInsets.symmetric(horizontal: side, vertical: 9),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            top: BorderSide(
                              color: AppTheme.trialInk.withValues(alpha: _newWeek(days[i], days[i - 1]) ? 0.18 : 0.08),
                              width: _newWeek(days[i], days[i - 1]) ? 1.5 : 1,
                            ),
                          ),
                  ),
                  child: grid.row([for (final column in columns) _Grid.cellOf(column.cell(days[i], grid.size))]),
                ),
            ],
          );
        },
      ),
    );
  }
}

// The tablet's whole table, as the computer has it: nothing more to open.
// Each column as wide as its widest text plus an equal share of the room left.
class _FullTable extends StatelessWidget
{
  final CompensationMonth shown;

  const _FullTable({required this.shown});

  static const double _side = 18;
  static const double _ruleWidth = 1.5;
  static const double _headSize = 12.5;

  Widget _rule() => Container(width: _ruleWidth, color: AppTheme.trialInk.withValues(alpha: 0.12));

  List<_Col> get _columns
  {
    _Cell lines(Iterable<String> texts, TextStyle style, double size)
    {
      final List<String> all = texts.toList();

      return all.isEmpty ? _dash(size) : (lines: all, style: style);
    }

    return [
      _dayColumn(full: true, openingDay: shown.openingDay),
      _Col(kStartColumn, (day, size) => lines(day.worked.map((span) => span.start), _cellStyle(size: size), size)),
      _Col(kEndColumn, (day, size) => lines(day.worked.map((span) => span.end), _cellStyle(size: size), size)),
      _Col(kHoursColumn, (day, size) => (lines: [formatMinutes(day.workedMinutes)], style: _cellStyle(size: size, strong: true))),
      _Col(kStartColumn, (day, size) => lines(day.volunteer.map((span) => span.start), _cellStyle(size: size, strong: true), size)),
      _Col(kEndColumn, (day, size) => lines(day.volunteer.map((span) => span.end), _cellStyle(size: size, strong: true), size)),
      _Col(
        kHoursColumn,
        (day, size) => day.volunteerMinutes == 0
            ? _dash(size)
            : (lines: [formatMinutes(day.volunteerMinutes)], style: _cellStyle(size: size, strong: true)),
      ),
      _Col(
        kGrossColumn,
        (day, size) => (lines: [_money(day.gross)], style: _cellStyle(size: size, strong: true)),
        opening: (size) => (lines: [_money(shown.openingGross)], style: _cellStyle(size: size, strong: true)),
      ),
      _Col(
        kWithholdingColumn,
        (day, size) => (lines: [_money(withholdingOf(day.gross, day.net))], style: _cellStyle(size: size)),
        opening: (size) => (
          lines: [_money(withholdingOf(shown.openingGross, shown.openingNet))],
          style: _cellStyle(size: size),
        ),
      ),
      _Col(
        kNetColumn,
        (day, size) => (lines: [_money(day.net)], style: _cellStyle(size: size)),
        opening: (size) => (lines: [_money(shown.openingNet)], style: _cellStyle(size: size)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final List<_Col> columns = _columns;
    final List<CompensationDay> days = shown.days;
    final bool opening = _hasOpening(shown);
    final TextStyle group = _labelStyle(size: 11.5).copyWith(letterSpacing: 1.2);
    final Color line = AppTheme.trialInk.withValues(alpha: 0.08);

    return MobileGlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final _Grid grid = _Grid.of(
            context,
            columns,
            days,
            constraints.maxWidth - _side - 3 * _ruleWidth,
            sizes: const [15, 14],
            headSize: _headSize,
            minGap: 20,
            opening: opening,
          );
          final TextStyle head = _labelStyle(size: grid.headSize);
          final double share = (grid.gap * (columns.length - 1)) / columns.length;
          final List<int> flexes = [
            for (final (i, width) in grid.widths.indexed) ((width + share + (i == 0 ? _side : 0)) * 10).round(),
          ];

          Widget cell(int i, Widget child)
          {
            if (i == 0)
            {
              return Expanded(
                flex: flexes[0],
                child: Padding(
                  padding: const EdgeInsets.only(left: _side),
                  child: Align(alignment: Alignment.centerLeft, child: child),
                ),
              );
            }

            return Expanded(flex: flexes[i], child: Center(child: child));
          }

          Widget headGroup(String title, int from)
          {
            return Expanded(
              flex: flexes[from] + flexes[from + 1] + flexes[from + 2],
              child: Column(
                children: [
                  SizedBox(height: 26, child: Center(child: Text(title.toUpperCase(), style: group))),
                  SizedBox(
                    height: 26,
                    child: Row(
                      children: [
                        for (var i = from; i < from + 3; i++)
                          Expanded(flex: flexes[i], child: Center(child: Text(columns[i].head, style: head))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // [day]: none on the set-up's row.
          List<Widget> row(CompensationDay? day)
          {
            Widget at(int i) => cell(
                  i,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _Grid.cellOf(
                      day == null ? columns[i].openingCell(grid.size) : columns[i].cell(day, grid.size),
                    ),
                  ),
                );

            return [
              at(0),
              _rule(),
              for (var i = 1; i <= 3; i++) at(i),
              _rule(),
              for (var i = 4; i <= 6; i++) at(i),
              _rule(),
              for (var i = 7; i <= 9; i++) at(i),
            ];
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                decoration: BoxDecoration(
                  color: AppTheme.trialInk.withValues(alpha: 0.035),
                  border: Border(bottom: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.1))),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: flexes[0],
                        child: Padding(
                          padding: const EdgeInsets.only(left: _side, top: 26),
                          child: Align(alignment: Alignment.centerLeft, child: Text(kDayColumn, style: head)),
                        ),
                      ),
                      _rule(),
                      headGroup(kWorkGroup, 1),
                      _rule(),
                      headGroup(kVolunteerGroup, 4),
                      _rule(),
                      headGroup(kPayGroup, 7),
                    ],
                  ),
                ),
              ),
              if (opening)
                Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: row(null)),
                  ),
                ),
              for (var i = 0; i < days.length; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: BoxDecoration(
                    border: i == 0 && opening
                        ? Border(top: BorderSide(color: line))
                        : i == 0
                        ? null
                        : Border(
                            top: BorderSide(
                              color: _newWeek(days[i], days[i - 1]) ? AppTheme.trialInk.withValues(alpha: 0.18) : line,
                              width: _newWeek(days[i], days[i - 1]) ? 1.5 : 1,
                            ),
                          ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: row(days[i])),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DaySheet extends StatelessWidget
{
  final CompensationDay day;
  final PaySheetTourLink link;

  const _DaySheet({required this.day, required this.link});

  @override
  Widget build(BuildContext context)
  {
    final int paid = day.workedMinutes - day.volunteerMinutes;

    return MobileSheet(
      eyebrow: _title,
      title: _dayTitle(day.date),
      body: [
        _SheetLinked(link: link, child: const SizedBox(height: 14)),
        MobileTourTarget(
          id: kPayTourDaySheet,
          inflate: _tourRowInflate,
          radius: _tourRowRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileDetailRows(
                rows: [
                  DetailRowData(kWorkGroup, _spans(day.worked, day.workedMinutes)),
                  DetailRowData(kVolunteerGroup, _spans(day.volunteer, day.volunteerMinutes)),
                  DetailRowData(kPaidHoursLabel, formatMinutes(math.max(0, paid))),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                height: 1,
                color: AppTheme.trialInk.withValues(alpha: 0.09),
              ),
              _Columns(
                cells: [
                  _Figure(label: kGrossPayLabel, value: _money(day.gross), size: 22, color: AppTheme.trialOceanText),
                  _Figure(
                    label: kWithholdingLabel,
                    value: _money(withholdingOf(day.gross, day.net)),
                    size: 22,
                    color: AppTheme.trialOceanText,
                  ),
                  _Figure(label: kNetPayLabel, value: _money(day.net), size: 22, color: AppTheme.trialTealDeepText),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Tells the tour once the sheet has risen, and again as it goes.
class _SheetLinked extends StatefulWidget
{
  final PaySheetTourLink link;
  final Widget child;

  const _SheetLinked({required this.link, required this.child});

  @override
  State<_SheetLinked> createState() => _SheetLinkedState();
}

class _SheetLinkedState extends State<_SheetLinked>
{
  bool _risen = false;

  @override
  void initState()
  {
    super.initState();
    _riseLater();
  }

  @override
  void dispose()
  {
    final PaySheetTourLink link = widget.link;

    // Not while the tree is locked: a tour moves on, and redraws, on hearing it.
    if (_risen)
    {
      SchedulerBinding.instance.addPostFrameCallback((_) => link.fall());
    }

    super.dispose();
  }

  void _riseLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _rise())
      ..scheduleFrame();
  }

  void _rise()
  {
    if (!mounted)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _riseLater();

      return;
    }

    _risen = true;
    widget.link.rise(close: () => closeMobileSheet(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// Twelve months of a year, as the computer's month button.
class _MonthSheet extends StatefulWidget
{
  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final Set<DateTime> marked;

  // Whose tour of the dots it is.
  final String taxCode;

  const _MonthSheet({
    required this.selected,
    required this.first,
    required this.last,
    required this.marked,
    required this.taxCode,
  });

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet>
{
  late int _year = widget.selected.year;

  Widget _arrow(IconData icon, bool enabled, int by)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => setState(() => _year += by) : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.trialInk.withValues(alpha: 0.06)),
        child: Icon(
          icon,
          size: 24,
          color: enabled ? AppTheme.trialTealDeepText : AppTheme.trialInk.withValues(alpha: 0.22),
        ),
      ),
    );
  }

  Widget _cell(int month)
  {
    final DateTime date = DateTime(_year, month);
    final bool enabled = !date.isAfter(widget.last) && !date.isBefore(widget.first);
    final bool selected = date == widget.selected;
    final bool current = date == widget.last;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => finishMobileSheet(context, date) : null,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected ? AppTheme.brandGradient : null,
          color: selected ? null : AppTheme.trialInk.withValues(alpha: enabled ? 0.05 : 0.02),
          border: current
              ? Border.all(
                  color: MobilePalette.currentRim,
                  width: MobilePalette.currentRimWidth,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              kShortMonthNames[month - 1],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : (enabled ? AppTheme.trialInk : _disabledMonth),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.marked.contains(date)
                    ? (selected ? Colors.white : AppTheme.trialTurquoise)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileSheet(
      eyebrow: kPickMonthLabel,
      title: '$_year',
      subhead: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => finishMobileSheet(context, widget.last),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppTheme.trialInk.withValues(alpha: 0.06),
                ),
                child: Text(
                  kTodayLabel.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: AppTheme.trialTealDeepText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _arrow(Icons.chevron_left_rounded, _year > widget.first.year, -1),
            const SizedBox(width: 8),
            _arrow(Icons.chevron_right_rounded, _year < widget.last.year, 1),
          ],
        ),
      ),
      body: [
        MobileTourOnRise(
          onRisen: () => startMobileTourOnce(taxCode: widget.taxCode, tour: compensationPickerTour()),
          child: const SizedBox(height: 16),
        ),
        MobileTourTarget(
          id: kPayTourPickerMonths,
          inflate: _tourRowInflate,
          radius: _tourRowRadius + 4,
          child: Column(
            children: [
              for (var row = 0; row < 3; row++) ...[
                if (row > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var col = 0; col < 4; col++) ...[
                      if (col > 0) const SizedBox(width: 10),
                      Expanded(child: _cell(row * 4 + col + 1)),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
