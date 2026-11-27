import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../accounting/models/opening_items.dart';
import '../../accounting/utils/accounting_strings.dart' show kExportPdf;
import '../../accounting/utils/opening_strings.dart';
import '../../accounting/widgets/opening_dialogs.dart';
import '../../association/models/standard_tariffs_item.dart';
import '../compensation_tour.dart';
import '../models/person_item.dart';
import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';
import '../widgets/person_detail_widgets.dart';
import '../widgets/student_payment_dialogs.dart';
import '../widgets/family_pay_choice.dart';
import '../widgets/family_pay_dialog.dart';
import '../family_payments_tour.dart';
import '../widgets/student_payment_history.dart';

const double _contentWidth = 1600;

const double _figureGap = 40;
const double _figureRunGap = 14;

const Duration _barFill = Duration(milliseconds: 450);

// Under this a month shows its mark without the word.
const double _monthWordMinWidth = 64;

const double _monthGap = 8;

const double _actionGap = 12;

// Inside a button beside its label: the gap after the icon, the border and a little slack.
const double _buttonInner = 8 + 4 + 4;

// ESPORTA PDF floats at the foot as NUOVA COMUNICAZIONE does; the last table scrolls clear of it.
const double _exportWidth = 330;
const double _exportHeight = 52;
const double _exportRoom = _exportHeight + 40;


// What a pupil pays for Aiuto Compiti and whether it is settled; administrators only.
class PersonPaymentsTab extends StatefulWidget
{
  final PersonItem person;

  // The member's own page: only the fees, nothing to change, settle or export.
  final bool ownPage;

  // False while another section of the page is on show: no tour then.
  final bool shown;

  // A parent reading a child, or a pupil nobody answers for: everything, nothing to change.
  final bool family;

  // The family page's tour: the person it follows, or the parent's own fees; none for the others.
  final FamilyTabTour tour;

  // The payments read, for the family page's tour.
  final ValueChanged<StudentPaymentsItem>? onLoaded;

  const PersonPaymentsTab({
    super.key,
    required this.person,
    this.ownPage = false,
    this.shown = true,
    this.family = false,
    this.tour = FamilyTabTour.none,
    this.onLoaded,
  });

  @override
  State<PersonPaymentsTab> createState() => _PersonPaymentsTabState();
}

enum FamilyTabTour { none, child, own }

class _PersonPaymentsTabState extends State<PersonPaymentsTab>
{
  StudentPaymentsItem? _payments;

  // Why the tab could not be read, shown in its place.
  Object? _error;

  // The association's tariffs: what a change proposes and which kinds are turned off.
  StandardTariffsItem? _standard;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  // The own page reads its person again each time it is shown: the fees follow.
  @override
  void didUpdateWidget(PersonPaymentsTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.ownPage && !identical(widget.person, oldWidget.person))
    {
      unawaited(_refresh());
    }

    // Brought in: the parts never told are told now.
    if (widget.shown && !oldWidget.shown)
    {
      unawaited(_startOwnTours());
    }
  }

  // The teacher's own fees, once on show and the whole page's tour seen: the parts shown for the first time.
  Future<void> _startOwnTours() async
  {
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || !widget.ownPage || !widget.shown || isDesktopTourShown || _payments == null)
    {
      return;
    }

    if (!await compensationTourSeen(compensationPageTour))
    {
      return;
    }

    final DesktopTour? late = await compensationFeesLateTour();

    if (late != null && mounted)
    {
      startCompensationTour(context, late);
    }
  }

  Future<void> _load() async
  {
    try
    {
      // Both under way at once; the payments' own failure is what the tab reports. The own page changes nothing.
      final Future<StandardTariffsItem?> tariffs = widget.ownPage || widget.family
          ? Future<StandardTariffsItem?>.value()
          : ApiService().getStandardTariffs().then<StandardTariffsItem?>((tariffs) => tariffs, onError: (_) => null);
      final StudentPaymentsItem payments = await ApiService().getStudentPayments(widget.person.fiscalCode);
      final StandardTariffsItem? standard = await tariffs;

      if (mounted)
      {
        setState(()
        {
          _payments = payments;
          _standard = standard;
          _error = null;
        });
        unawaited(_startOwnTours());

        // After the frame: the tour looks for the parts this build lays out.
        final ValueChanged<StudentPaymentsItem>? loaded = widget.onLoaded;

        if (loaded != null)
        {
          WidgetsBinding.instance.addPostFrameCallback((_)
          {
            if (mounted)
            {
              loaded(payments);
            }
          });
        }
      }
    }
    catch (error)
    {
      if (mounted)
      {
        setState(() => _error = error);
      }
    }
  }

  // A window that saved hands back the tab as it now stands.
  Future<void> _open(Future<StudentPaymentsItem?> window, String saved) async
  {
    final StudentPaymentsItem? payments = await window;

    if (!mounted)
    {
      return;
    }

    // Closed without saving, maybe refused for figures gone stale: they are read again, quietly.
    if (payments == null)
    {
      unawaited(_refresh());

      return;
    }

    setState(() => _payments = payments);
    CustomSnackBar.show(context: context, message: saved);
  }

  Future<void> _refresh() async
  {
    try
    {
      final StudentPaymentsItem payments = await ApiService().getStudentPayments(widget.person.fiscalCode);

      if (mounted)
      {
        setState(() => _payments = payments);
      }
    }
    catch (_)
    {
      // What is shown stays: the next write says if something is wrong.
    }
  }

  void _renew(StudentPaymentsItem payments)
  {
    _open(
      showRenewDialog(context: context, person: widget.person, payments: payments),
      payments.tariff?.isPackage == true ? kPackageRenewed : kFeeRenewed,
    );
  }

  void _changeTariff(StudentPaymentsItem payments)
  {
    _open(
      showChangeTariffDialog(
        context: context,
        person: widget.person,
        payments: payments,
        standard: _standard?.of(payments.schoolLevel),
      ),
      kTariffChanged,
    );
  }

  void _giveTariff(StudentPaymentsItem payments)
  {
    _open(
      showFirstTariffDialog(
        context: context,
        person: widget.person,
        payments: payments,
        standard: _standard?.of(payments.schoolLevel),
      ),
      kTariffGiven,
    );
  }

  void _changeRate(StudentPaymentsItem payments)
  {
    _open(showChangeRateDialog(context: context, person: widget.person, payments: payments), kRateChanged);
  }

  void _payAhead(StudentPaymentsItem payments)
  {
    _open(showPayAheadDialog(context: context, person: widget.person, payments: payments), kHoursPaidAhead);
  }

  // Everything owed in one window, all ticked.
  void _settle(StudentPaymentsItem payments)
  {
    // A family pays on Stripe: nothing is written here.
    if (widget.family)
    {
      unawaited(showFamilyPayDialog(context: context, person: widget.person, payments: payments));

      return;
    }

    _open(showSettleDialog(context: context, person: widget.person, payments: payments), kSettled);
  }

  // Paid rows can be revoked there; those still to pay are only read.
  void _openRow(StudentPaymentsItem payments, PaymentHistoryRow row)
  {
    if (widget.family)
    {
      showPaymentDetails(context: context, person: widget.person, payments: payments, row: row, readOnly: true);

      return;
    }

    _open(
      showPaymentDetails(context: context, person: widget.person, payments: payments, row: row),
      kPaymentCancelled,
    );
  }

  void _export(StudentPaymentsItem payments)
  {
    showPaymentsExport(context: context, person: widget.person, payments: payments);
  }

  // The same window as Contabilità › Configurazione iniziale.
  Future<void> _configure(StudentPaymentsItem payments) async
  {
    final DateTime? lastDay = payments.openingDay;

    if (lastDay == null)
    {
      return;
    }

    try
    {
      final OpeningPupil pupil = await ApiService().getOpeningPupil(widget.person.fiscalCode);

      if (!mounted)
      {
        return;
      }

      final OpeningPupil? saved = await showPupilOpeningDialog(context: context, pupil: pupil, lastDay: lastDay);

      if (saved == null || !mounted)
      {
        return;
      }

      CustomSnackBar.show(context: context, message: pupilConfirmed(feminine: saved.gender == 'F'));
      await _refresh();
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  // «Pagato quest'anno € 865,00» beside the year's heading.
  Widget _paid(String label, int cents, bool dense)
  {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label  '),
          TextSpan(
            text: formatAmount(cents),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.trialOceanText),
          ),
        ],
      ),
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13 : 14.5,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      ),
    );
  }

  // A table per calendar year, the newest first; nothing is dropped as the years go by.
  List<Widget> _history(StudentPaymentsItem payments, double gap)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final int thisYear = romeNow().year;
    final Map<int, List<PaymentHistoryRow>> years = paymentsByYear(payments.history, thisYear);

    // The payment the family tour opens: the child's.
    final PaymentHistoryRow? toured = widget.tour == FamilyTabTour.child ? familyTouredRow(payments.history) : null;

    if (years.isEmpty)
    {
      return [
        SizedBox(height: gap + 8),
        PageHeading(kHistoryHeading),
        const SizedBox(height: 12),
        Center(
          child: DesktopTourTarget(
            id: switch (widget.tour)
            {
              FamilyTabTour.child => kTourFamilyEmpty,
              FamilyTabTour.own => kTourFamilyOwnEmpty,
              FamilyTabTour.none => widget.ownPage ? kTourFeesEmpty : null,
            },
            child: AppEmptyCard(icon: Icons.receipt_long_rounded, message: kNoPayments),
          ),
        ),
      ];
    }

    final List<Widget> blocks = [
      for (final MapEntry(key: year, value: rows) in years.entries) ...[
        SizedBox(height: gap + 8),
        PageHeading(
          historyYearHeading(year),
          trailing: _paid(
            year == thisYear ? kPaidThisYearLabel : paidInYear(year),
            rows.where((row) => row.isPaid).fold(0, (sum, row) => sum + row.amountCents),
            dense,
          ),
        ),
        const SizedBox(height: 12),
        PaymentHistoryTable(
          rows: rows,
          metrics: PaymentHistoryMetrics.of(dense: dense),
          showHours: payments.student,
          openingPending: payments.openingPending,
          stacked: AppBreakpoints.of(context).isMinimal,
          onOpen: (row) => _openRow(payments, row),
          readOnly: widget.ownPage,
          tourRow: toured == null ? null : (toured, kTourFamilyRow),
        ),
      ],
    ];

    final String? history = switch (widget.tour)
    {
      FamilyTabTour.child => kTourFamilyHistory,
      FamilyTabTour.own => kTourFamilyOwnHistory,
      FamilyTabTour.none => widget.ownPage ? kTourFeesHistory : null,
    };

    if (history == null)
    {
      return blocks;
    }

    // Every year lit as one by the tour, the gap above it left out.
    return [
      blocks.first,
      DesktopTourTarget(
        id: history,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks.sublist(1)),
      ),
    ];
  }

  // Below the wide window the PDF does not float: it leads the row of buttons, or stands alone.
  Widget _exportButton(StudentPaymentsItem payments, {double? width})
  {
    return tabActionButton(
      label: kExportPdf,
      icon: Icons.picture_as_pdf_outlined,
      width: width,
      onPressed: () => _export(payments),
    );
  }

  // An enrolled pupil on file without a tariff: nothing else can be done before one is given.
  Widget _firstTariffAction(StudentPaymentsItem payments)
  {
    return Align(
      alignment: Alignment.centerRight,
      child: tabActionButton(
        label: kGiveTariffLabel,
        icon: Icons.add_rounded,
        disabledReason: payments.openingPending ? pendingReason(feminine: widget.person.gender == 'F') : null,
        onPressed: () => _giveTariff(payments),
      ),
    );
  }

  // A button's natural width: its label, the icon before it and its sides (the page's denser sizes).
  double _buttonNeed(String label)
  {
    final bool page = AppPageDensity.of(context);
    final double font = page ? 12.5 : 13;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(
          GoogleFonts.plusJakartaSans(fontSize: font, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width + MediaQuery.textScalerOf(context).scale(font + 1) + _buttonInner + 2 * (page ? 14 : 20);
  }

  // Two to a line: as wide as each other while both labels fit half, else shared by what they need,
  // else each on its own line.
  List<double> _pairedWidths(List<String> labels, double room)
  {
    final double half = (room - _actionGap) / 2;
    final List<double> widths = [];

    for (var index = 0; index < labels.length; index += 2)
    {
      if (index + 1 == labels.length)
      {
        widths.add(_buttonNeed(labels[index]) <= half ? half : room);
        continue;
      }

      final double first = _buttonNeed(labels[index]);
      final double second = _buttonNeed(labels[index + 1]);

      if (first <= half && second <= half)
      {
        widths.addAll([half, half]);
      }
      else if (first + second + _actionGap <= room)
      {
        // A hair short of the line, so rounding never sends the second below.
        final double shared = room - _actionGap - 1;

        widths.addAll([shared * first / (first + second), shared * second / (first + second)]);
      }
      else
      {
        widths.addAll([room, room]);
      }
    }

    return widths;
  }

  // [room] set: minimal windows, the buttons two to a line rather than steps down the right.
  Widget _actions(StudentPaymentsItem payments, {double? room})
  {
    final StudentTariffItem tariff = payments.tariff!;
    final StandardTariffItem? standard = _standard?.of(payments.schoolLevel);

    // Nothing to change to when every other kind is turned off for the level.
    final bool changeable = standard == null ||
        ['HOURLY', 'PACKAGE', 'MONTHLY'].any((kind) => kind != tariff.kind && standard.enabled(kind));

    final String? pending = payments.openingPending ? pendingReason(feminine: widget.person.gender == 'F') : null;

    // One paid ahead at a time: the buttons wait for it to start. Nothing before the set-up.
    final String? off = pending ??
        switch (payments.queued)
        {
          QueuedPayment.package => kPackageQueuedReason,
          QueuedPayment.month => kMonthQueuedReason,
          QueuedPayment.change => changeQueuedReason(payments.queuedStartsOn, ahead: tariff.isHourly),
          null => null,
        };

    // Online at the weekend is paid ahead under any tariff, whatever waits; its window says what is left.
    final List<(String, IconData, VoidCallback)> tariffSpecs = tariff.isHourly
        ? [
            if (changeable) (kChangeTariffLabel, Icons.swap_horiz_rounded, () => _changeTariff(payments)),
            (kChangeRateLabel, Icons.edit_rounded, () => _changeRate(payments)),
            (kPayAheadLabel, Icons.more_time_rounded, () => _payAhead(payments)),
          ]
        : [
            if (changeable) (kChangeTariffLabel, Icons.swap_horiz_rounded, () => _changeTariff(payments)),
            (kRenewLabel, Icons.autorenew_rounded, () => _renew(payments)),
            (kPayAheadLabel, Icons.more_time_rounded, () => _payAhead(payments)),
          ];

    Widget button((String, IconData, VoidCallback) spec, {double? width})
    {
      final (label, icon, onPressed) = spec;

      return tabActionButton(
        label: label,
        icon: icon,
        width: width,
        disabledReason: label == kPayAheadLabel ? pending : off,
        onPressed: onPressed,
      );
    }

    // Nothing to export without a payment.
    final bool exports = payments.history.isNotEmpty && AppBreakpoints.of(context).isDense;

    if (room != null)
    {
      final List<String> labels = [if (exports) kExportPdf, for (final (label, _, _) in tariffSpecs) label];
      final List<double> widths = _pairedWidths(labels, room);

      return Wrap(
        spacing: _actionGap,
        runSpacing: _actionGap,
        children: [
          if (exports) _exportButton(payments, width: widths.first),
          for (final (index, spec) in tariffSpecs.indexed) button(spec, width: widths[index + (exports ? 1 : 0)]),
        ],
      );
    }

    final Widget export = _exportButton(payments);

    final Widget tariffButtons = Wrap(
      alignment: WrapAlignment.end,
      spacing: _actionGap,
      runSpacing: _actionGap,
      children: [for (final spec in tariffSpecs) button(spec)],
    );

    if (!exports)
    {
      return tariffButtons;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        export,
        const SizedBox(width: _actionGap),
        Expanded(child: tariffButtons),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final StudentPaymentsItem? payments = _payments;
    final _Metrics metrics = _Metrics.of(AppBreakpoints.of(context).isDense);
    final double gap = personCardGap(context);

    final Object? error = _error;

    if (payments == null && error != null)
    {
      return AppLoadFailedRoom(error: error, message: readableApiError(error), onRetry: _load);
    }

    if (payments == null)
    {
      return Padding(
        padding: EdgeInsets.only(top: 60),
        child: Align(
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final bool dense = AppBreakpoints.of(context).isDense;
    final bool own = widget.ownPage || widget.family;
    final bool floating = !own && !dense && payments.history.isNotEmpty;

    // A member's tariff buttons; none for fees alone, none for whoever is not enrolled (what is owed is still
    // settled in the history).
    final bool tariffActions = !own && payments.tariff != null && !payments.readOnly;
    final bool exportAlone = !own && dense && !tariffActions && payments.history.isNotEmpty;

    final List<Widget> blocks = [
      // The pupil's tariff; each payment says its own method.
      if (payments.student)
        DesktopTourTarget(
          id: widget.tour == FamilyTabTour.child ? kTourFamilyTariff : null,
          child: _SummaryCard(payments: payments, metrics: metrics),
        ),
      if (tariffActions) ...[
        SizedBox(height: gap),
        // Minimal windows: two to a line, all as wide, rather than steps down the right.
        if (AppBreakpoints.of(context).isMinimal)
          LayoutBuilder(
            builder: (context, constraints) => _actions(payments, room: constraints.maxWidth),
          )
        else
          _actions(payments),
      ],
      if (!own && payments.student && payments.tariff == null && !payments.readOnly) ...[
        SizedBox(height: gap),
        _firstTariffAction(payments),
      ],
      if (exportAlone) ...[
        SizedBox(height: gap),
        Align(alignment: Alignment.centerLeft, child: _exportButton(payments)),
      ],
      if (payments.openingPending) ...[
        SizedBox(height: gap),
        _PendingCard(
          lastDay: payments.openingDay,
          metrics: metrics,
          onConfigure: own ? null : () => unawaited(_configure(payments)),
          onSettle: (widget.family ? familyCanPay(payments) : !widget.ownPage && hasSomethingToSettle(payments))
              ? () => _settle(payments)
              : null,
          settleLabel: widget.family ? kPayLabel : kSettleLabel,
        ),
        ..._history(payments, gap),
      ]
      else if (payments.state != null) ...[
        SizedBox(height: gap),
        DesktopTourTarget(
          id: widget.tour == FamilyTabTour.child ? kTourFamilyStatus : (widget.ownPage ? kTourFeesStatus : null),
          child: _StatusCard(
            payments: payments,
            metrics: metrics,
            onSettle: (widget.family ? familyCanPay(payments) : !own && hasSomethingToSettle(payments))
                ? () => _settle(payments)
                : null,
            settleLabel: widget.family ? kPayLabel : kSettleLabel,
            settleTour: widget.tour == FamilyTabTour.child ? kTourFamilyPay : null,
          ),
        ),
        ..._history(payments, gap),
      ]
      else if (!payments.student) ...[
        ..._history(payments, gap),
      ],
    ];

    // Without the tariff on top, what comes first needs no gap above it.
    while (blocks.isNotEmpty && blocks.first is SizedBox && (blocks.first as SizedBox).child == null)
    {
      blocks.removeAt(0);
    }

    final Widget content = ScrollEdgeFade(
      child: TransitionScrollView(
        padding: EdgeInsets.only(bottom: floating ? _exportRoom : 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks(blocks),
            ),
          ),
        ),
      ),
    );

    if (!floating)
    {
      return content;
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: PageTransitionItem(
              slot: PageTransitionItem.header,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x2E0B3350), offset: Offset(0, 10), blurRadius: 28)],
                ),
                child: AppGradientButton(
                  label: kExportPdf,
                  icon: Icons.picture_as_pdf_outlined,
                  width: _exportWidth,
                  height: _exportHeight,
                  fontSize: 14,
                  onPressed: () => _export(payments),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Every size that steps down with the window, in one place.
class _Metrics
{
  final double radius;
  final EdgeInsets padding;
  final double labelText;
  final double valueText;
  final double badge;
  final double badgeIcon;
  final double titleText;
  final double subtitleText;
  final double ruleGap;
  final double barText;
  final double bar;
  final double monthHeight;
  final double monthText;
  final double monthWord;

  const _Metrics({
    required this.radius,
    required this.padding,
    required this.labelText,
    required this.valueText,
    required this.badge,
    required this.badgeIcon,
    required this.titleText,
    required this.subtitleText,
    required this.ruleGap,
    required this.barText,
    required this.bar,
    required this.monthHeight,
    required this.monthText,
    required this.monthWord,
  });

  factory _Metrics.of(bool dense)
  {
    if (!dense)
    {
      return const _Metrics(
        radius: 32,
        padding: EdgeInsets.fromLTRB(30, 22, 30, 24),
        labelText: 12,
        valueText: 22,
        badge: 52,
        badgeIcon: 28,
        titleText: 23,
        subtitleText: 15,
        ruleGap: 20,
        barText: 15,
        bar: 14,
        monthHeight: 74,
        monthText: 14,
        monthWord: 11,
      );
    }

    return const _Metrics(
      radius: 24,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 16),
      labelText: 10,
      valueText: 17,
      badge: 40,
      badgeIcon: 22,
      titleText: 18,
      subtitleText: 13,
      ruleGap: 14,
      barText: 13,
      bar: 10,
      monthHeight: 60,
      monthText: 12.5,
      monthWord: 10,
    );
  }
}

class _Card extends StatelessWidget
{
  final _Metrics metrics;
  final Widget child;

  const _Card({required this.metrics, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: metrics.padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(metrics.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      foregroundDecoration: AppTheme.cardEdge(metrics.radius),
      child: child,
    );
  }
}

class _Rule extends StatelessWidget
{
  final _Metrics metrics;

  const _Rule({required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: metrics.ruleGap),
      child: Divider(height: 1, thickness: 1, color: ThemeColours.of(0xFFEDF2F1)),
    );
  }
}

class _SummaryCard extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final _Metrics metrics;

  const _SummaryCard({required this.payments, required this.metrics});

  Widget _figure(String label, String value)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: PageHeading.style().copyWith(fontSize: metrics.labelText, letterSpacing: 1.4),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: metrics.valueText,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialOceanText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final StudentTariffItem? tariff = payments.tariff;

    return _Card(
      metrics: metrics,
      child: Wrap(
        spacing: _figureGap,
        runSpacing: _figureRunGap,
        children: [
          _figure(kTariffFigure, tariff == null ? '—' : kTariffKindLabels[tariff.kind] ?? '—'),
          _figure(
            kCostFigure,
            tariff == null ? '—' : tariffCost(tariff.kind, tariff.amountCents, tariff.packageHours),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final _Metrics metrics;

  // Set while something is owed: everything settled from here.
  final VoidCallback? onSettle;
  final String settleLabel;

  // The family tour lights the button.
  final String? settleTour;

  const _StatusCard({
    required this.payments,
    required this.metrics,
    this.onSettle,
    required this.settleLabel,
    this.settleTour,
  });

  bool get _ok => payments.state == PaymentState.ok;

  String get _title => paymentStateTitle(payments);

  String? get _subtitle => paymentStateLine(payments, romeNow());

  Widget _header()
  {
    final String? subtitle = _subtitle;

    return Row(
      children: [
        Container(
          width: metrics.badge,
          height: metrics.badge,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _ok ? AppTheme.brandGradient : AppTheme.goldGradient,
          ),
          child: Icon(
            _ok ? Icons.check_rounded : Icons.warning_amber_rounded,
            size: metrics.badgeIcon,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: metrics.titleText,
                  fontWeight: FontWeight.w800,
                  color: _ok ? AppTheme.trialOceanText : AppTheme.modifiedAccent,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: metrics.subtitleText,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _details()
  {
    final PackageStatusItem? package = payments.package;
    final AheadStatusItem? ahead = payments.ahead;
    final AheadStatusItem? weekend = payments.weekendAhead;
    final List<MonthStateItem>? months = payments.months;

    return [
      if (package != null && payments.tariff?.isPackage == true) ...[
        _Rule(metrics: metrics),
        _HoursBar(used: package.usedMinutes, total: package.totalMinutes, metrics: metrics),
      ],
      if (ahead != null && payments.tariff?.isHourly == true) ...[
        _Rule(metrics: metrics),
        _HoursBar(used: ahead.usedMinutes, total: ahead.totalMinutes, metrics: metrics),
      ],
      if (months != null) ...[
        _Rule(metrics: metrics),
        _MonthStrip(months: months, metrics: metrics),
      ],
      // Under any tariff: its own line names it.
      if (weekend != null) ...[
        _Rule(metrics: metrics),
        Text(
          weekendAheadPaidLine(weekend.totalMinutes),
          style: GoogleFonts.plusJakartaSans(
            fontSize: metrics.subtitleText,
            fontWeight: FontWeight.w500,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 10),
        _HoursBar(used: weekend.usedMinutes, total: weekend.totalMinutes, metrics: metrics),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onSettle = this.onSettle;

    return _Card(
      metrics: metrics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          onSettle == null
              ? _header()
              : _WithActions(
                  actions: [
                    DesktopTourTarget(
                      id: settleTour,
                      child: tabActionButton(label: settleLabel, icon: Icons.payments_outlined, onPressed: onSettle),
                    ),
                  ],
                  child: _header(),
                ),
          ..._details(),
        ],
      ),
    );
  }
}

// In place of the state while the initial set-up waits: what is missing, and the way to it.
class _PendingCard extends StatelessWidget
{
  final DateTime? lastDay;
  final _Metrics metrics;

  // Admins only: families read the card.
  final VoidCallback? onConfigure;

  // Fees owed are paid whatever the set-up says.
  final VoidCallback? onSettle;
  final String settleLabel;

  const _PendingCard({
    required this.lastDay,
    required this.metrics,
    this.onConfigure,
    this.onSettle,
    required this.settleLabel,
  });

  @override
  Widget build(BuildContext context)
  {
    final DateTime? lastDay = this.lastDay;

    final VoidCallback? onSettle = this.onSettle;
    final VoidCallback? onConfigure = this.onConfigure;

    return _Card(
      metrics: metrics,
      child: _WithActions(
        actions: [
          if (onSettle != null)
            tabActionButton(label: settleLabel, icon: Icons.payments_outlined, onPressed: onSettle),
          if (onConfigure != null)
            tabActionButton(label: kConfigureLabel, icon: Icons.tune_rounded, onPressed: onConfigure),
        ],
        child: Row(
          children: [
            Container(
              width: metrics.badge,
              height: metrics.badge,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.trialOcean, AppTheme.trialDeepWater],
                ),
              ),
              child: Icon(Icons.pending_actions_rounded, size: metrics.badgeIcon, color: Colors.white),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kOpeningPending,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: metrics.titleText,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.trialOceanText,
                    ),
                  ),
                  if (lastDay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      pendingPaymentsNote(lastDay),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: metrics.subtitleText,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A card's buttons beside its header, or under it, right-aligned, when the card is narrow.
class _WithActions extends StatelessWidget
{
  static const double _besideWidth = 560;
  static const double _gap = 12;

  final Widget child;
  final List<Widget> actions;

  const _WithActions({required this.child, required this.actions});

  @override
  Widget build(BuildContext context)
  {
    // A family's card with nothing to pay: the words alone.
    if (actions.isEmpty)
    {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final Widget buttons = Wrap(
          spacing: _gap,
          runSpacing: _gap,
          alignment: WrapAlignment.end,
          children: actions,
        );

        if (constraints.maxWidth < _besideWidth)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerRight, child: buttons),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: child),
            const SizedBox(width: 18),
            buttons,
          ],
        );
      },
    );
  }
}

// A package's hours, or those paid ahead: used on the left, left on the right.
class _HoursBar extends StatelessWidget
{
  final int used;
  final int total;
  final _Metrics metrics;

  const _HoursBar({required this.used, required this.total, required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    final bool usedUp = used >= total;
    final double share = total == 0 ? 1 : (used / total).clamp(0, 1).toDouble();

    final String right = leftLabel(usedUp ? 0 : total - used);

    final TextStyle label = GoogleFonts.plusJakartaSans(
      fontSize: metrics.barText,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOceanText,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(usedLabel(used), style: label)),
            const SizedBox(width: 16),
            Text(right, style: usedUp ? label.copyWith(color: AppTheme.modifiedAccent) : label),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(metrics.bar / 2),
          child: SizedBox(
            height: metrics.bar,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: ThemeColours.of(0xFFE6EEEE))),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: share),
                  duration: _barFill,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(metrics.bar / 2),
                        gradient: LinearGradient(
                          colors: usedUp
                              ? AppTheme.goldGradient.colors
                              : [AppTheme.trialTurquoise, AppTheme.trialTealDeep],
                        ),
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

// The school year's months: paid in teal, this one unpaid in gold, the others plain.
class _MonthStrip extends StatelessWidget
{
  final List<MonthStateItem> months;
  final _Metrics metrics;

  const _MonthStrip({required this.months, required this.metrics});

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
        final bool words = cell >= _monthWordMinWidth;

        return Row(
          children: [
            for (final (index, month) in months.indexed) ...[
              if (index > 0) const SizedBox(width: _monthGap),
              Expanded(child: _MonthCell(month: month, label: _short(month.month), words: words, metrics: metrics)),
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
  final _Metrics metrics;

  const _MonthCell({required this.month, required this.label, required this.words, required this.metrics});

  @override
  Widget build(BuildContext context)
  {
    final MonthState state = month.state;
    final bool marked = state != MonthState.none;
    final Color accent = state == MonthState.paid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent;

    return Container(
      height: metrics.monthHeight,
      decoration: BoxDecoration(
        color: switch (state)
        {
          MonthState.paid => AppTheme.paidSurface,
          MonthState.due => AppTheme.modifiedAccentSurface,
          MonthState.none => AppTheme.quietSurface,
        },
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: metrics.monthText,
              fontWeight: FontWeight.w700,
              color: marked ? AppTheme.trialOceanText : ThemeColours.fixed(0xFFA9B7BF),
            ),
          ),
          if (marked) ...[
            const SizedBox(height: 4),
            Icon(
              state == MonthState.paid ? Icons.check_rounded : Icons.autorenew_rounded,
              size: metrics.monthText + 3,
              color: accent,
            ),
            if (words) ...[
              const SizedBox(height: 2),
              Text(
                state == MonthState.paid ? kMonthPaid : kFeeNotPaid,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: metrics.monthWord,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
