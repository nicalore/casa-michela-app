import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/people/models/child_item.dart';
import '../../../features/people/models/person_face.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/models/student_payments_item.dart';
import '../../../features/people/person_jump.dart';
import '../../../features/people/utils/payments_strings.dart';
import '../../../features/people/widgets/family_pay_choice.dart' show familyCanPay;
import '../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../features/people/widgets/student_payment_history.dart' show PaymentDueFlag, hoursUse;
import '../../../services/api_service.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/mobile_line_breaks.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_height_reporter.dart';
import '../../shared/widgets/mobile_load_failed.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../children/widgets/mobile_child_tiles.dart';
import '../compensation/mobile_fees_tab.dart' show MobileFeesSource;
import '../home/widgets/mobile_link.dart';
import '../profile/widgets/mobile_detail_card.dart' show MobileDetailRows, mobileFactLabelStyle, mobileFactValueStyle;
import 'mobile_family_pay_sheet.dart';
import 'mobile_family_payments_tour.dart';

const double _phoneMargin = 20;
const double _tabletMargin = 44;
const double _handleClearance = 16;
const double _chipsGap = 12;
const double _tilesGap = 18;
const double _topRoom = 16;
const double _stripGap = 14;

const double _cardRadius = 22;
const double _tileRadius = 14;
const double _stripe = 4;
const double _gap = 14;

// Tour holes: the part's corner plus what they grow by.
const EdgeInsets _tourCardInflate = EdgeInsets.all(6);
const double _tourCardRadius = _cardRadius + 6;
const EdgeInsets _tourButtonInflate = EdgeInsets.all(4);
const double _tourButtonRadius = 18 + 4;
const EdgeInsets _tourTileInflate = EdgeInsets.all(3);
const double _tourTileRadius = _tileRadius + 3;
const EdgeInsets _tourChipInflate = EdgeInsets.all(5);
const double _tourChipRadius = 21;
const EdgeInsets _tourSheetInflate = EdgeInsets.all(4);

Widget _tourSheetCard(String id, Widget card)
{
  return MobileTourTarget(
    id: id,
    inflate: _tourSheetInflate,
    radius: MobileSheetCard.radius + 4,
    clipped: true,
    child: card,
  );
}

Widget _tourCard(String? id, Widget child)
{
  return MobileTourTarget(id: id, inflate: _tourCardInflate, radius: _tourCardRadius, clipped: true, child: child);
}

String _method(String? method, String? other)
{
  if (method == null)
  {
    return '—';
  }

  return kPaymentMethodLabels[method] ?? other ?? '—';
}

TextStyle _labelStyle({double size = 12.5}) => GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: MobilePalette.mutedText,
    );

TextStyle _titleStyle({double size = 16.5}) => GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: AppTheme.trialInk,
    );

TextStyle _amountStyle(PaymentHistoryRow row, {double size = 17}) => GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: row.isPaid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

Widget _due({bool tablet = false}) => PaymentDueFlag(height: tablet ? 28 : 26, fontSize: tablet ? 13 : 12.5);

// The days of its lessons, then their hours: «Dal 16 settembre al 2 ottobre (18h)».
String? _period(PaymentHistoryRow row)
{
  final String? line = historyLine(row);
  final String? hours = row.isFee || row.minutes == 0 ? null : hoursText(row.minutes);

  if (line == null)
  {
    return hours;
  }

  return hours == null ? line : '$line ($hours)';
}

Color _lineTone(PaymentHistoryRow row)
{
  return switch (row.state)
  {
    PaymentHistoryState.running => AppTheme.trialTealDeepText,
    PaymentHistoryState.waiting => AppTheme.laterBlueText,
    _ => MobilePalette.mutedText,
  };
}

// A parent's children's payments (and their own fees, when a member), or a pupil's own when nobody answers
// for them: read only.
class MobileFamilyPaymentsPage extends StatefulWidget
{
  final MeResponse user;

  const MobileFamilyPaymentsPage({super.key, required this.user});

  @override
  State<MobileFamilyPaymentsPage> createState() => _MobileFamilyPaymentsPageState();
}

class _MobileFamilyPaymentsPageState extends State<MobileFamilyPaymentsPage>
{
  final ApiService _api = ApiService();

  List<PersonItem> _people = [];
  bool _loading = true;
  Object? _failure;

  String? _shown;

  // One per child, read when first shown.
  final Map<String, MobileFeesSource> _sources = {};

  // The parent, when a member: their own fees on a page of their own.
  PersonItem? _self;

  final PageController _pages = PageController();

  // The tour waits for the page to have come in; a payment's sheet tells it when it is up.
  bool _toured = false;
  final PaymentSheetTourLink _sheetLink = PaymentSheetTourLink();

  // Opened on a child by the home: that visit's tour is skipped.
  bool _jumped = false;

  bool get _parent => widget.user.activeRole == 'PARENT';

  String get _taxCode => widget.user.taxCode;

  @override
  void initState()
  {
    super.initState();

    if (ChildPaymentsJumps.take() case final String pupil)
    {
      _shown = pupil;
      _jumped = true;
    }

    _load().whenComplete(MobileHoldScope.hold(context));
    mobileTourChanges.addListener(_tourLater);
    MobileNavSheet.hidden.addListener(_onSheets);
    _sheetLink.addListener(_onPaymentSheet);
    ChildPaymentsJumps.asked.addListener(_onAsked);
  }

  // A touch on the home's figure while this page is kept: the child, on the children's page.
  void _onAsked()
  {
    final String? pupil = ChildPaymentsJumps.take();

    if (pupil == null || !mounted)
    {
      return;
    }

    _jumped = true;

    if (_people.where((person) => person.fiscalCode == pupil).firstOrNull case final PersonItem child)
    {
      _show(child);

      if (_pages.hasClients)
      {
        _pages.jumpToPage(0);
      }
    }
    else if (_loading)
    {
      _shown = pupil;
    }
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
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.hidden.removeListener(_onSheets);
    _sheetLink.removeListener(_onPaymentSheet);
    ChildPaymentsJumps.asked.removeListener(_onAsked);

    for (final source in _sources.values)
    {
      source.dispose();
    }

    _sheetLink.dispose();
    _pages.dispose();
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

  // The whole page on the first visit, on the first child shown; the payments read first.
  Future<void> _tourCheck() async
  {
    final PersonItem? child = _child;
    final PersonItem? self = _self;
    final StudentPaymentsItem? payments = child == null ? null : _sourceOf(child.fiscalCode).payments;

    if (!mounted ||
        _jumped ||
        !_toured ||
        _loading ||
        payments == null ||
        (self != null && _sourceOf(self.fiscalCode).loading) ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value)
    {
      return;
    }

    final bool pupil = !_parent;

    if (await isMobileTourSeen(taxCode: _taxCode, tour: familyPaymentsMainTour(self: pupil)))
    {
      // Told already: only the parts shown since, on the child's page.
      final bool onOwn = self != null && _pages.hasClients && (_pages.page ?? 0) > 0.5;

      if (mounted && !onOwn && !isMobileTourShown)
      {
        await startFamilyPageLateTour(taxCode: _taxCode, self: pupil, gender: child?.gender, tariff: payments.tariff);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    final PaymentHistoryRow? toured = familyTouredRow(payments);

    await startMobileTourOnce(
      taxCode: _taxCode,
      tour: familyPaymentsTour(
        self: pupil,
        genders: [for (final PersonItem person in _people) person.gender],
        gender: child?.gender,
        tariff: payments.tariff,
        member: self != null,
        pages: _pages,
        sheet: _sheetLink,
        row: toured,
        openRow: ()
        {
          if (toured != null && mounted)
          {
            _openSheet(context, toured, _sheetLink);
          }
        },
      ),
    );
  }

  // A payment's sheet up outside a tour: its parts never seen, the first time they show.
  void _onPaymentSheet()
  {
    if (!_sheetLink.open)
    {
      return;
    }

    SchedulerBinding.instance
      ..addPostFrameCallback((_)
      {
        if (mounted && !isMobileTourShown && _sheetLink.open)
        {
          startFamilySheetTour(taxCode: _taxCode, sheet: _sheetLink);
        }
      })
      ..scheduleFrame();
  }

  // The children, then the first one's payments and a member's own fees, all inside the shell's hold.
  Future<void> _load() async
  {
    try
    {
      final PersonItem self = await _api.getPerson(widget.user.taxCode);
      final List<PersonItem> people = _parent
          ? await Future.wait([
              for (final child in self.children ?? const <ChildItem>[]) _api.getPerson(child.fiscalCode),
            ])
          : [self];

      people.sort(compareByName);

      // A refresh that reorders the children keeps the one shown.
      final String? shown = people.any((person) => person.fiscalCode == _shown)
          ? _shown
          : people.firstOrNull?.fiscalCode;

      final bool member = _parent && self.roles.contains(RoleLabelMapper.memberLabel);

      await Future.wait([
        if (shown != null) _sourceOf(shown).load(),
        if (member) _sourceOf(self.fiscalCode).load(),
      ]);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _people = people;
        _self = member ? self : null;
        _shown = shown;
        _loading = false;
        _failure = null;
      });
    }
    catch (error, stackTrace)
    {
      reportCaughtError(error, stackTrace, during: 'il caricamento dei pagamenti');

      if (mounted)
      {
        setState(()
        {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  // A pull: the shown child's payments again, what is shown stays if it fails.
  Future<void> _refresh() async
  {
    final String? shown = _shown;

    if (shown == null)
    {
      return _load();
    }

    await _sourceOf(shown).load(quiet: true);
  }

  // The tour counts what the payments hold: it waits for them too.
  MobileFeesSource _sourceOf(String taxCode)
  {
    return _sources[taxCode] ??= (MobileFeesSource(taxCode)..addListener(_tourLater));
  }

  void _show(PersonItem child)
  {
    final MobileFeesSource source = _sourceOf(child.fiscalCode);

    if (source.loading)
    {
      source.load();
    }

    setState(() => _shown = child.fiscalCode);
  }

  PersonItem? get _child
  {
    for (final person in _people)
    {
      if (person.fiscalCode == _shown)
      {
        return person;
      }
    }

    return null;
  }

  Widget _buildTitle(bool tablet)
  {
    return Text(
      kPaymentsSection,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );
  }

  // What the page holds, and whether it is a card alone, centred in the room.
  (Widget, bool) _buildBody(bool tablet)
  {
    final PersonItem? child = _child;

    if (_loading)
    {
      return (const MobileWaiting(), false);
    }

    if (child == null)
    {
      final Object? failure = _failure;

      return (
        failure == null
            ? MobileEmptyCard(
                icon: Icons.family_restroom_rounded,
                message: tr('Nessun figlio collegato al tuo profilo.', 'No children linked to your profile.'),
                tablet: tablet,
              )
            : MobileLoadFailed(error: failure, message: kPaymentsLoadFailed, onRetry: _load, tablet: tablet),
        true,
      );
    }

    return _sourceBody(_sourceOf(child.fiscalCode), tablet);
  }

  (Widget, bool) _sourceBody(MobileFeesSource source, bool tablet)
  {
    final StudentPaymentsItem? payments = source.payments;

    if (source.loading)
    {
      return (const MobileWaiting(), false);
    }

    if (payments == null)
    {
      final Object? failure = source.failure;

      return (
        MobileLoadFailed(
          error: failure,
          message: failure == null ? kPaymentsLoadFailed : readableApiError(failure),
          onRetry: source.load,
          tablet: tablet,
        ),
        true,
      );
    }

    final PersonItem? person = [?_self, ..._people].where((each) => each.fiscalCode == source.taxCode).firstOrNull;
    final String name = person == null ? '' : '${person.firstName} ${person.lastName}';

    return (
      _PaymentsView(
        key: ValueKey(source.taxCode),
        payments: payments,
        tablet: tablet,
        name: name,
        own: person != null && identical(person, _self),
        sheet: _sheetLink,
      ),
      false,
    );
  }

  Widget _refreshable(Widget scroll)
  {
    return RefreshIndicator(
      color: AppTheme.trialGold,
      backgroundColor: AppTheme.trialDeepWater,
      onRefresh: _refresh,
      child: scroll,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final PersonItem? shownChild = _child;

    // The shown child's payments arrive on their own.
    return ListenableBuilder(
      listenable: Listenable.merge([if (shownChild != null) _sourceOf(shownChild.fiscalCode)]),
      builder: (context, _) => _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;
    final PersonItem? self = _self;

    final Widget title = Padding(
      padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
      child: _buildTitle(tablet),
    );

    if (self == null)
    {
      return SafeArea(bottom: false, child: _buildChildren(tablet: tablet, margin: margin, bottom: bottom, title: title));
    }

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: _stripGap),
        MobilePageStrip(
          labels: [kChildrenPaymentsTab, kOwnPaymentsTab],
          controller: _pages,
          scrollMargin: margin,
          tourTargets: [familyTourTab(0), familyTourTab(1)],
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pages,
          children: [
            MobileSwipePage(child: _buildChildren(tablet: tablet, margin: margin, bottom: bottom)),
            MobileSwipePage(child: _buildOwn(self, tablet: tablet, margin: margin, bottom: bottom)),
          ],
        ),
      ),
    );
  }

  // The parent's own fees.
  Widget _buildOwn(PersonItem self, {required bool tablet, required double margin, required double bottom})
  {
    final MobileFeesSource source = _sourceOf(self.fiscalCode);

    return ListenableBuilder(
      listenable: source,
      builder: (context, _)
      {
        final (Widget content, bool alone) = _sourceBody(source, tablet);

        return RefreshIndicator(
          color: AppTheme.trialGold,
          backgroundColor: AppTheme.trialDeepWater,
          onRefresh: () => source.load(quiet: true),
          child: MobileEmptyScroll(
            padding: EdgeInsets.fromLTRB(margin, _topRoom, margin, bottom),
            body: MobileLoadSwitcher(child: alone ? Center(child: content) : content),
            fill: alone,
            tail: const [MobileTourRunway()],
          ),
        );
      },
    );
  }

  // The children's payments: chips or tiles over the shown child's, or the rail beside them; [title] above
  // when the page has no tabs.
  Widget _buildChildren({required bool tablet, required double margin, required double bottom, Widget? title})
  {
    final Size size = MediaQuery.sizeOf(context);
    final bool lying = tablet && size.width > size.height;

    final PersonItem? child = _child;
    final bool several = _parent && child != null && _people.length > 1;
    final bool rail = lying && several;

    final (Widget content, bool alone) = _buildBody(tablet);
    final Widget body = MobileLoadSwitcher(child: alone ? Center(child: content) : content);

    if (rail)
    {
      const double railRoom = MobileChildRail.width + MobileChildRail.gap;

      final Widget beside = Stack(
        children: [
          Positioned.fill(
            child: _refreshable(
              MobileEmptyScroll(
                padding: EdgeInsets.fromLTRB(railRoom + margin, title == null ? _topRoom : 0, margin, bottom),
                body: body,
                fill: alone,
                tail: const [MobileTourRunway()],
              ),
            ),
          ),
          Positioned(
            left: margin,
            top: title == null ? _topRoom : 0,
            bottom: 0,
            width: MobileChildRail.width,
            child: MobileChildRail(
              children: _people,
              shown: child,
              onShow: _show,
              bottom: bottom,
              tourTarget: kFamilyTourChildren,
            ),
          ),
        ],
      );

      if (title == null)
      {
        return beside;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: _tilesGap),
          Expanded(child: beside),
        ],
      );
    }

    return _refreshable(
      MobileEmptyScroll(
        padding: EdgeInsets.only(bottom: bottom),
        head: [
          ?title,
          if (several)
            Padding(
              padding: EdgeInsets.only(top: title == null ? _topRoom : (tablet ? _tilesGap : _chipsGap)),
              child: tablet
                  ? MobileChildTiles(
                      children: _people,
                      shown: child,
                      onShow: _show,
                      margin: margin,
                      tourTarget: kFamilyTourChildren,
                    )
                  : MobileFilterChips(
                      margin: margin,
                      chips: [
                        MobileTourTarget(
                          id: kFamilyTourChildren,
                          inflate: _tourChipInflate,
                          radius: _tourChipRadius,
                          child: MobileChildChip(children: _people, shown: child, onShow: _show, eyebrow: kPaymentsSection),
                        ),
                      ],
                    ),
            ),
        ],
        body: Padding(
          padding: EdgeInsets.fromLTRB(margin, _topRoom + (several || title == null ? 0 : 4), margin, 0),
          child: body,
        ),
        fill: alone,
        tail: const [MobileTourRunway()],
      ),
    );
  }
}

// ---------------------------------------------------------------- the child's payments

class _PaymentsView extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final bool tablet;

  // Whose payments: the pay sheet's title.
  final String name;

  // A member parent's own fees, on «Personali».
  final bool own;

  final PaymentSheetTourLink sheet;

  const _PaymentsView({
    super.key,
    required this.payments,
    required this.tablet,
    required this.name,
    required this.own,
    required this.sheet,
  });

  @override
  Widget build(BuildContext context)
  {
    final Map<int, List<PaymentHistoryRow>> years = paymentsByYear(payments.history, romeNow().year);
    final PaymentHistoryRow? toured = familyTouredRow(payments);
    final String history = own ? kFamilyTourOwnHistory : kFamilyTourHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (payments.student) _tourCard(own ? null : kFamilyTourTariff, _SummaryCard(payments: payments, tablet: tablet)),
        if (payments.state != null) ...[
          if (payments.student) const SizedBox(height: _gap),
          _tourCard(own ? null : kFamilyTourStatus, _StatusCard(payments: payments, tablet: tablet)),
        ],
        // Anything to pay: «PAGA» under the state, on the sea like the page's other buttons.
        if (familyCanPay(payments)) ...[
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: tablet ? MobileNavSheet.tabletWidth : double.infinity,
              child: MobileTourTarget(
                id: own ? null : kFamilyTourPay,
                inflate: _tourButtonInflate,
                radius: _tourButtonRadius,
                child: MobileGoldButton(
                  label: kPayLabel,
                  icon: Icons.payments_outlined,
                  onPressed: () => showMobileFamilyPaySheet(context: context, payments: payments, name: name),
                ),
              ),
            ),
          ),
        ],
        if (years.isEmpty) ...[
          const SizedBox(height: 40),
          _tourCard(
            own ? kFamilyTourOwnHistory : kFamilyTourEmpty,
            MobileEmptyCard(icon: Icons.receipt_long_rounded, message: kNoPayments, tablet: tablet),
          ),
        ],
        // The first year's heading and payments, one part for the tour.
        for (final (index, MapEntry(key: year, value: rows)) in years.entries.indexed) ...[
          SizedBox(height: tablet ? 28 : 26),
          MobileTourTarget(
            id: index == 0 ? history : null,
            inflate: _tourCardInflate,
            radius: _tourCardRadius,
            clipped: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _YearHeading(year: year, rows: rows, tablet: tablet),
                tablet
                    ? _TabletTable(payments: payments, rows: rows, toured: toured, own: own, sheet: sheet)
                    : _PhoneTiles(payments: payments, rows: rows, toured: toured, own: own, sheet: sheet),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget
{
  final String label;
  final String value;
  final bool tablet;

  const _Figure({required this.label, required this.value, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _labelStyle(size: tablet ? 13 : 12.5)),
        const SizedBox(height: 3),
        WholeWords(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 18 : 16.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialOceanText,
            ),
          ),
        ),
      ],
    );
  }
}

// The pupil's tariff; each payment says its own method.
List<(String, String)> _figuresOf(StudentPaymentsItem payments)
{
  final StudentTariffItem? tariff = payments.tariff;

  return [
    (kTariffFigure, tariff == null ? '—' : kTariffKindLabels[tariff.kind] ?? '—'),
    (kCostFigure, tariff == null ? '—' : tariffCost(tariff.kind, tariff.amountCents, tariff.packageHours)),
  ];
}

// Tariff and cost, as the computer's first card.
class _SummaryCard extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final bool tablet;

  const _SummaryCard({required this.payments, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 18, 24, 18) : const EdgeInsets.fromLTRB(18, 14, 18, 16),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: tablet ? 40 : 28,
          runSpacing: 12,
          children: [
            for (final (label, value) in _figuresOf(payments)) _Figure(label: label, value: value, tablet: tablet),
          ],
        ),
      ),
    );
  }
}

// The badge and the state's title, the line under it.
class _StateLine extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final bool tablet;

  const _StateLine({required this.payments, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final bool ok = payments.state == PaymentState.ok;
    final double badge = tablet ? 50 : 44;
    final String? line = paymentStateLine(payments, romeNow());

    return Row(
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ok ? AppTheme.brandGradient : AppTheme.goldGradient,
          ),
          child: Icon(ok ? Icons.check_rounded : Icons.warning_amber_rounded, size: badge * 0.54, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              WholeWords(
                child: Text(
                  withoutOrphans(paymentStateTitle(payments)),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tablet ? 24 : 21,
                    fontWeight: FontWeight.w800,
                    color: ok ? AppTheme.trialOceanText : AppTheme.modifiedAccent,
                  ),
                ),
              ),
              if (line != null) ...[
                const SizedBox(height: 3),
                WholeWords(
                  child: Text(
                    withoutOrphans(line),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: tablet ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ),
              ],
            ],
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
      margin: const EdgeInsets.symmetric(vertical: 14),
      height: 1,
      color: AppTheme.trialInk.withValues(alpha: 0.09),
    );
  }
}

// The package's hours, or those paid ahead, the school year's months.
List<Widget> _details(StudentPaymentsItem payments, bool tablet)
{
  final PackageStatusItem? package = payments.package;
  final AheadStatusItem? ahead = payments.ahead;
  final AheadStatusItem? weekend = payments.weekendAhead;
  final List<MonthStateItem>? months = payments.months;

  return [
    if (package != null && payments.tariff?.isPackage == true) ...[
      const _Hairline(),
      _HoursBar(used: package.usedMinutes, total: package.totalMinutes, tablet: tablet),
    ],
    if (ahead != null && payments.tariff?.isHourly == true) ...[
      const _Hairline(),
      _HoursBar(used: ahead.usedMinutes, total: ahead.totalMinutes, tablet: tablet),
    ],
    if (months != null) ...[
      const _Hairline(),
      _MonthStrip(months: months, tablet: tablet),
    ],
    // Under any tariff: its own line names it.
    if (weekend != null) ...[
      const _Hairline(),
      WholeWords(
        child: Text(
          withoutOrphans(weekendAheadPaidLine(weekend.totalMinutes)),
          style: GoogleFonts.plusJakartaSans(
            fontSize: tablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: MobilePalette.mutedText,
          ),
        ),
      ),
      const SizedBox(height: 8),
      _HoursBar(used: weekend.usedMinutes, total: weekend.totalMinutes, tablet: tablet),
    ],
  ];
}

class _StatusCard extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final bool tablet;

  const _StatusCard({required this.payments, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: tablet ? const EdgeInsets.fromLTRB(24, 18, 24, 20) : const EdgeInsets.fromLTRB(18, 16, 18, 16),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StateLine(payments: payments, tablet: tablet),
          ..._details(payments, tablet),
        ],
      ),
    );
  }
}

class _HoursBar extends StatelessWidget
{
  final int used;
  final int total;
  final bool tablet;

  const _HoursBar({required this.used, required this.total, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final bool usedUp = used >= total;
    final double share = total == 0 ? 1 : (used / total).clamp(0, 1).toDouble();
    final TextStyle label = GoogleFonts.plusJakartaSans(
      fontSize: tablet ? 15 : 14,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOceanText,
    );
    final double height = tablet ? 12 : 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(usedLabel(used), style: label)),
            const SizedBox(width: 16),
            Text(
              leftLabel(usedUp ? 0 : total - used),
              style: usedUp ? label.copyWith(color: AppTheme.modifiedAccent) : label,
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: ThemeColours.of(0xFFE6EEEE))),
                FractionallySizedBox(
                  widthFactor: share,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: LinearGradient(
                        colors: usedUp ? AppTheme.goldGradient.colors : [AppTheme.trialTurquoise, AppTheme.trialTealDeep],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// September to June: paid in teal, the one to renew in gold, the others plain.
class _MonthStrip extends StatelessWidget
{
  final List<MonthStateItem> months;
  final bool tablet;

  const _MonthStrip({required this.months, required this.tablet});

  static const double _monthGap = 5;

  static String _short(DateTime month)
  {
    final String name = formatMonthName(month);

    return '${name[0].toUpperCase()}${name.substring(1, 3)}';
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double cell = (constraints.maxWidth - _monthGap * (months.length - 1)) / months.length;
        final bool words = cell >= 58;

        return Row(
          children: [
            for (final (index, month) in months.indexed) ...[
              if (index > 0) const SizedBox(width: _monthGap),
              Expanded(child: _MonthCell(month: month, label: _short(month.month), words: words, tablet: tablet)),
            ],
          ],
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget
{
  final MonthStateItem month;
  final String label;
  final bool words;
  final bool tablet;

  const _MonthCell({required this.month, required this.label, required this.words, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final MonthState state = month.state;
    final bool marked = state != MonthState.none;
    final Color accent = state == MonthState.paid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent;

    return Container(
      height: words ? 62 : (tablet ? 56 : 50),
      decoration: BoxDecoration(
        color: switch (state)
        {
          MonthState.paid => AppTheme.paidSurface,
          MonthState.due => AppTheme.modifiedAccentSurface,
          MonthState.none => AppTheme.quietSurface,
        },
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 13 : 11.5,
              fontWeight: FontWeight.w700,
              color: marked ? AppTheme.trialOceanText : ThemeColours.fixed(0xFFA9B7BF),
            ),
          ),
          if (marked) ...[
            const SizedBox(height: 3),
            Icon(
              state == MonthState.paid ? Icons.check_rounded : Icons.autorenew_rounded,
              size: tablet ? 16 : 14,
              color: accent,
            ),
            if (words) ...[
              const SizedBox(height: 2),
              Text(
                state == MonthState.paid ? kMonthPaid : kFeeNotPaid,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// «STORICO 2026» on the sea, «Pagato quest'anno € 501,00» beside it.
class _YearHeading extends StatelessWidget
{
  final int year;
  final List<PaymentHistoryRow> rows;
  final bool tablet;

  const _YearHeading({required this.year, required this.rows, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final int paid = rows.where((row) => row.isPaid).fold(0, (sum, row) => sum + row.amountCents);
    final bool thisYear = year == romeNow().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            historyYearHeading(year).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 14 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${thisYear ? kPaidThisYearLabel : paidInYear(year)}  '),
                TextSpan(text: formatAmount(paid), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 14.5 : 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// The gold edge of what is still to pay, as the computer's table has it.
class _Owed extends StatelessWidget
{
  final bool owed;
  final Widget child;

  const _Owed({required this.owed, required this.child});

  @override
  Widget build(BuildContext context)
  {
    if (!owed)
    {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(left: 0, top: 0, bottom: 0, width: _stripe, child: ColoredBox(color: AppTheme.trialGold)),
      ],
    );
  }
}

void _openSheet(BuildContext context, PaymentHistoryRow row, PaymentSheetTourLink sheet)
{
  showMobileSheet<void>(context: context, builder: (context) => _PaymentSheet(row: row, link: sheet));
}

// ---------------------------------------------------------------- phone: a tile per payment, opening its sheet

class _PhoneTiles extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final List<PaymentHistoryRow> rows;

  // The payment the tour opens, on the own page or the child's.
  final PaymentHistoryRow? toured;
  final bool own;
  final PaymentSheetTourLink sheet;

  const _PhoneTiles({
    required this.payments,
    required this.rows,
    required this.toured,
    required this.own,
    required this.sheet,
  });

  Widget _tile(BuildContext context, PaymentHistoryRow row)
  {
    final String? period = _period(row);
    final bool marked = row.state == PaymentHistoryState.running || row.state == PaymentHistoryState.waiting;

    final Widget tile = MobileLink(
      onTap: () => _openSheet(context, row, sheet),
      child: MobileLinkTile(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: WholeWords(child: Text(withoutOrphans(historyTitle(row)), style: _titleStyle()))),
                const SizedBox(width: 12),
                Text(formatAmount(row.amountCents), style: _amountStyle(row)),
              ],
            ),
            if (period != null) ...[
              const SizedBox(height: 3),
              WholeWords(
                child: Text(
                  withoutOrphans(period),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: marked ? FontWeight.w700 : FontWeight.w600,
                    color: _lineTone(row),
                  ),
                ),
              ),
            ],
            if (!row.isPaid) ...[
              const SizedBox(height: 7),
              Align(alignment: Alignment.centerLeft, child: _due()),
            ],
          ],
        ),
      ),
    );

    if (row.isPaid)
    {
      return tile;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(_tileRadius)),
      child: _Owed(owed: true, child: tile),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: const EdgeInsets.all(8),
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 4),
            MobileTourTarget(
              id: !own && identical(row, toured) ? kFamilyTourRow : null,
              inflate: _tourTileInflate,
              radius: _tourTileRadius,
              child: _tile(context, row),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- tablet: the computer's table, rows open the sheet

class _TabletTable extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final List<PaymentHistoryRow> rows;

  // The payment the tour opens, on the own page or the child's.
  final PaymentHistoryRow? toured;
  final bool own;
  final PaymentSheetTourLink sheet;

  const _TabletTable({
    required this.payments,
    required this.rows,
    required this.toured,
    required this.own,
    required this.sheet,
  });

  static const double _side = 24;

  // Payment (its hours under it, as on the phone), amount, paid on, method.
  static const List<int> _flexes = [33, 13, 30, 24];

  Widget _cells(List<Widget> cells, {Widget? end})
  {
    return Row(
      children: [
        for (final (i, cell) in cells.indexed)
          Expanded(
            flex: _flexes[i],
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
              child: Align(
                alignment: i == 1 ? Alignment.center : Alignment.centerLeft,
                child: cell,
              ),
            ),
          ),
        SizedBox(width: 30, child: end),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle head = _labelStyle(size: 13);
    final TextStyle cell = GoogleFonts.plusJakartaSans(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialInk.withValues(alpha: 0.86),
    );

    return MobileGlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(_side, 14, 12, 11),
              decoration: BoxDecoration(
                color: AppTheme.trialInk.withValues(alpha: 0.035),
                border: Border(bottom: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.1))),
              ),
              child: _cells([
                Text(kPaymentColumn, style: head),
                Text(kAmountColumn, style: head),
                Text(kPaidOnColumn, style: head),
                Text(kMethodColumn, style: head),
              ]),
            ),
            for (final (i, row) in rows.indexed)
              MobileTourTarget(
                id: !own && identical(row, toured) ? kFamilyTourRow : null,
                clipped: true,
                radius: 4,
                child: _Owed(
                  owed: !row.isPaid,
                  child: MobileLink(
                    onTap: () => _openSheet(context, row, sheet),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 62),
                      padding: const EdgeInsets.fromLTRB(_side, 11, 12, 11),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.08))),
                      ),
                      child: _cells(
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              WholeWords(child: Text(historyTitle(row), style: _titleStyle(size: 16))),
                              if (_period(row) case final String line) ...[
                                const SizedBox(height: 2),
                                WholeWords(
                                  child: Text(
                                    line,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _lineTone(row),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(formatAmount(row.amountCents), style: _amountStyle(row, size: 16)),
                          row.isPaid ? WholeWords(child: Text(formatWeekdayColumnLabel(row.paidOn!), style: cell)) : _due(tablet: true),
                          // Still to pay: no way yet, as on the computer.
                          WholeWords(
                            child: Text(
                              row.isPaid ? _method(row.paymentMethod, row.paymentMethodOther) : '—',
                              style: row.isPaid ? cell : cell.copyWith(color: MobilePalette.mutedText),
                            ),
                          ),
                        ],
                        end: Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialTealDeepText),
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

// ---------------------------------------------------------------- a payment's sheet

// What was paid, when and how, then the lessons it covers; nothing to do.
class _PaymentSheet extends StatefulWidget
{
  final PaymentHistoryRow row;

  // Told when the sheet stands still, which page it shows, when it goes.
  final PaymentSheetTourLink link;

  const _PaymentSheet({required this.row, required this.link});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet>
{
  // Assumed page height until measured.
  static const double _unmeasured = 320;

  static const double _hoursWidth = 64;
  static const double _thirdWidth = 76;
  static const double _cellGap = 8;

  final PageController _pages = PageController();

  // Each page's card, measured: the sheet follows the swipe from one to the other.
  final ValueNotifier<List<double?>> _heights = ValueNotifier(const [null, null]);

  PaymentHistoryRow get row => widget.row;

  static const Duration _turnBack = Duration(milliseconds: 320);
  static const double _settledPage = 0.001;

  @override
  void initState()
  {
    super.initState();
    _pages.addListener(_onPages);
    _riseLater();
  }

  @override
  void dispose()
  {
    final PaymentSheetTourLink link = widget.link;

    // Not while the tree is locked: a tour ends, and redraws, on hearing it.
    SchedulerBinding.instance.addPostFrameCallback((_) => link.fall());

    _pages.dispose();
    _heights.dispose();
    super.dispose();
  }

  void _riseLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _risen())
      ..scheduleFrame();
  }

  // A tour measures the sheet only once it stands still.
  void _risen()
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

    widget.link.rise(
      row: row,
      toFirstPage: ()
      {
        if (_pages.hasClients)
        {
          _pages.animateToPage(0, duration: _turnBack, curve: Curves.easeInOutCubic);
        }
      },
      close: () => closeMobileSheet(context),
    );
  }

  void _onPages()
  {
    final double page = _page;

    if ((page - page.round()).abs() < _settledPage)
    {
      widget.link.turned(page.round());
    }
  }

  double get _page => _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? 0 : 0;

  Widget _badge(String label, {bool blue = false})
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: blue ? AppTheme.laterBlueSurface : ThemeColours.of(0xFFEEF3F3),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: blue ? AppTheme.laterBlueText : ThemeColours.fixed(0xFF33495A),
        ),
      ),
    );
  }

  Widget _facts()
  {
    final DateTime? day = row.paidOn;

    return MobileDetailRows(
      rows: [
        DetailRowData(kAmountLabel, formatAmount(row.amountCents)),
        if (day == null)
          DetailRowData.drawn(kPaidOnLabel, Align(alignment: Alignment.centerLeft, child: _due()))
        else ...[
          DetailRowData(kPaidOnLabel, '${formatWeekdayColumnLabel(day)} ${day.year}'),
          DetailRowData(kPaymentMethodLabel, _method(row.paymentMethod, row.paymentMethodOther)),
        ],
      ],
    );
  }

  // Day, hours and what was left or what they cost, as the profile's tables; a total when nothing counts down.
  Widget _cells(Widget day, Widget hours, Widget? third)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: day),
        const SizedBox(width: _cellGap),
        SizedBox(width: _hoursWidth, child: Align(alignment: Alignment.topRight, child: hours)),
        if (third != null) ...[
          const SizedBox(width: _cellGap),
          SizedBox(width: _thirdWidth, child: Align(alignment: Alignment.topRight, child: third)),
        ],
      ],
    );
  }

  Widget _fitted(String text, TextStyle style)
  {
    return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, style: style));
  }

  Widget _lessonsTable()
  {
    final bool third = !row.isMonth;
    final TextStyle head = mobileFactLabelStyle();
    // As on the computer: light rows, the day a little heavier, the total heaviest.
    final TextStyle cell = mobileFactValueStyle().copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final TextStyle day = cell.copyWith(fontWeight: FontWeight.w600);
    final TextStyle total = cell.copyWith(fontWeight: FontWeight.w800);
    final Color line = AppTheme.trialInk.withValues(alpha: 0.09);
    final Color closing = AppTheme.trialInk.withValues(alpha: 0.28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _cells(
            Text(kDayColumn, style: head),
            Text(kHoursColumn, style: head),
            third ? Text(row.countsDown ? kLeftColumn : kCostColumn, style: head) : null,
          ),
        ),
        for (final PaymentHistoryLesson lesson in row.lessons)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
            child: _cells(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fitted(lesson.opening ? atOpeningDay(lesson.day) : formatWeekdayColumnLabel(lesson.day), day),
                  if (lesson.exhausted) ...[const SizedBox(height: 4), _badge(exhaustedBadge(row))],
                  if (lesson.beforePayment) ...[const SizedBox(height: 4), _badge(takenBadge(row), blue: true)],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fitted(hoursText(lesson.minutes), cell),
                  if (lesson.isPart) Text(ofLesson(lesson.lessonMinutes), style: head.copyWith(fontSize: 11.5)),
                ],
              ),
              third
                  ? _fitted(row.countsDown ? hoursText(lesson.leftMinutes ?? 0) : formatAmount(lesson.cents ?? 0), cell)
                  : null,
            ),
          ),
        // A darker rule closes the lessons before the total.
        if (!row.countsDown)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: closing, width: 1.5))),
            child: _cells(
              Text(kSettleTotal, style: total),
              _fitted(hoursText(row.minutes), total),
              third ? _fitted(formatAmount(row.amountCents), total) : null,
            ),
          ),
      ],
    );
  }

  Widget _lessonsCard()
  {
    final (int, int)? use = hoursUse(row);

    final Widget card = MobileSheetCard(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (use != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _HoursBar(used: use.$1, total: use.$2, tablet: false),
              ),
              const SizedBox(height: 18),
            ],
            _lessonsTable(),
          ],
        ),
      ),
    );

    return _tourSheetCard(kFamilyTourLessons, card);
  }

  void _measured(int index, double height)
  {
    final double? known = _heights.value[index];

    if (known != null && (known - height).abs() < 0.5)
    {
      return;
    }

    _heights.value = [for (var i = 0; i < 2; i++) i == index ? height : _heights.value[i]];
  }

  Widget _buildPage(int index, Widget card)
  {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileHeightReporter(
            onHeight: (height) => _measured(index, height),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, 16, MobileSheet.sidePadding, 6),
              child: card,
            ),
          ),
        ],
      ),
    );
  }

  // As the calendar's lesson sheet: the height follows the swipe.
  Widget _buildPager()
  {
    return AnimatedBuilder(
      animation: Listenable.merge([_pages, _heights]),
      builder: (context, child)
      {
        final double page = _page.clamp(0, 1).toDouble();
        final int low = page.floor();
        final int high = page.ceil();
        final List<double?> heights = _heights.value;
        final double from = heights[low] ?? heights[high] ?? _unmeasured;
        final double to = heights[high] ?? from;

        return SizedBox(height: ui.lerpDouble(from, to, page - low), child: child);
      },
      child: PageView(
        controller: _pages,
        allowImplicitScrolling: true,
        children: [
          _buildPage(0, _tourSheetCard(kFamilyTourFacts, MobileSheetCard(child: _facts()))),
          _buildPage(1, _lessonsCard()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (row.lessons.isEmpty)
    {
      return MobileSheet(
        eyebrow: kPaymentEyebrow,
        title: historyTitle(row),
        body: [
          const SizedBox(height: 16),
          _tourSheetCard(kFamilyTourFacts, MobileSheetCard(child: _facts())),
          const SizedBox(height: 6),
        ],
      );
    }

    return MobileSheet(
      eyebrow: kPaymentEyebrow,
      title: historyTitle(row),
      subhead: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobilePageStrip(
          labels: [kPaymentEyebrow, kLessonsCard],
          controller: _pages,
          onLight: true,
          tourTargets: [familyTourSheetTab(0), familyTourSheetTab(1)],
        ),
      ),
      content: _buildPager(),
    );
  }
}
