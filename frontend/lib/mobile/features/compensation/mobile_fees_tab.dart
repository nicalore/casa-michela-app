
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/people/models/student_payments_item.dart';
import '../../../features/people/utils/payments_strings.dart';
import '../../../features/people/widgets/person_detail_widgets.dart' show DetailRowData;
import '../../../features/people/widgets/student_payment_history.dart' show PaymentDueFlag;
import '../../../services/api_service.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../shared/mobile_line_breaks.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_load_failed.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../home/widgets/mobile_link.dart';
import '../profile/widgets/mobile_detail_card.dart' show MobileDetailRows;
import 'mobile_compensation_tour.dart';

const double _cardRadius = 22;
const double _tileRadius = 14;
const double _stripe = 4;

// Tour holes: the part's corner plus what they grow by.
const EdgeInsets _tourCardInflate = EdgeInsets.all(6);
const double _tourCardRadius = _cardRadius + 6;
const double _tourEmptyRadius = 28 + 6;
const EdgeInsets _tourTileInflate = EdgeInsets.all(3);
const double _tourTileRadius = _tileRadius + 3;

Widget _tourCard(String id, Widget child, {bool clipped = false})
{
  return MobileTourTarget(id: id, inflate: _tourCardInflate, radius: _tourCardRadius, clipped: clipped, child: child);
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

// A teacher's own fees, loaded with their Portafoglio so the tab shows them at once.
class MobileFeesSource extends ChangeNotifier
{
  final String taxCode;

  StudentPaymentsItem? payments;
  Object? failure;
  bool loading = true;

  bool _disposed = false;

  MobileFeesSource(this.taxCode);

  // [quiet]: a pull to refresh, which keeps what is shown if it fails.
  Future<void> load({bool quiet = false}) async
  {
    try
    {
      final StudentPaymentsItem fetched = await ApiService().getStudentPayments(taxCode);

      payments = fetched;
      failure = null;
      loading = false;
    }
    catch (error, stackTrace)
    {
      reportCaughtError(error, stackTrace, during: 'il caricamento dei pagamenti');

      if (quiet && payments != null)
      {
        return;
      }

      failure = error;
      loading = false;
    }

    if (!_disposed)
    {
      notifyListeners();
    }
  }

  @override
  void dispose()
  {
    _disposed = true;
    super.dispose();
  }
}

// The fees, read only: a tile per fee on the phone, the computer's table on the tablet.
class MobileFeesTab extends StatelessWidget
{
  final MobileFeesSource source;
  final EdgeInsets padding;
  final bool tablet;

  const MobileFeesTab({super.key, required this.source, required this.padding, required this.tablet});

  Widget _buildBody()
  {
    final StudentPaymentsItem? payments = source.payments;

    if (source.loading)
    {
      return const MobileWaiting();
    }

    if (payments == null)
    {
      final Object? failure = source.failure;

      return MobileLoadFailed(
        error: failure,
        message: failure == null ? kPaymentsLoadFailed : readableApiError(failure),
        onRetry: source.load,
        tablet: tablet,
      );
    }

    if (payments.history.isEmpty)
    {
      return MobileTourTarget(
        id: kPayTourFeesEmpty,
        inflate: _tourCardInflate,
        radius: _tourEmptyRadius,
        child: MobileEmptyCard(icon: Icons.receipt_long_rounded, message: kNoPayments, tablet: tablet),
      );
    }

    return tablet ? _TabletFees(payments: payments) : _PhoneFees(payments: payments);
  }

  @override
  Widget build(BuildContext context)
  {
    return ListenableBuilder(
      listenable: source,
      builder: (context, _)
      {
        final Widget body = _buildBody();
        // A failure or nothing on record: the card alone, in the middle of the room.
        final bool alone = body is MobileLoadFailed || (source.payments?.history.isEmpty ?? false);

        return RefreshIndicator(
          color: AppTheme.trialGold,
          backgroundColor: AppTheme.trialDeepWater,
          onRefresh: () => source.load(quiet: true),
          child: MobileEmptyScroll(
            padding: padding,
            body: MobileLoadSwitcher(child: alone ? Center(child: body) : body),
            fill: alone,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- shared parts

// The badge and «In regola» / «Da pagare € 20,00».
class _StateLine extends StatelessWidget
{
  final StudentPaymentsItem payments;
  final bool tablet;

  const _StateLine({required this.payments, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final bool ok = payments.state != PaymentState.due;
    final double badge = tablet ? 50 : 44;

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
          child: WholeWords(
            child: Text(
              withoutOrphans(paymentStateTitle(payments)),
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 24 : 21,
                fontWeight: FontWeight.w800,
                color: ok ? AppTheme.trialOceanText : AppTheme.modifiedAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// «STORICO 2026» on the sea, «Pagato quest'anno € 15,00» beside it.
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

// ---------------------------------------------------------------- phone: a tile per fee, opening its sheet

class _PhoneFees extends StatelessWidget
{
  final StudentPaymentsItem payments;

  const _PhoneFees({required this.payments});

  static const double _tilePadding = 14;
  static const double _tileGap = 4;

  // The first fee is the one the tour touches.
  Widget _tile(BuildContext context, PaymentHistoryRow row, {required bool first})
  {
    final Widget tile = MobileLink(
      onTap: () => showMobileSheet<void>(context: context, builder: (context) => _FeeSheet(row: row)),
      child: MobileLinkTile(
        padding: const EdgeInsets.symmetric(horizontal: _tilePadding, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: WholeWords(child: Text(historyTitle(row), style: _titleStyle()))),
                const SizedBox(width: 12),
                Text(formatAmount(row.amountCents), style: _amountStyle(row)),
              ],
            ),
            if (!row.isPaid) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: _due()),
            ],
          ],
        ),
      ),
    );

    // The gold edge inside the tile's corners.
    final Widget shown = row.isPaid
        ? tile
        : ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(_tileRadius)),
            child: _Owed(owed: true, child: tile),
          );

    return MobileTourTarget(
      id: first ? kPayTourFee : null,
      inflate: _tourTileInflate,
      radius: _tourTileRadius,
      child: shown,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Map<int, List<PaymentHistoryRow>> years = paymentsByYear(payments.history, romeNow().year);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (payments.state != null) ...[
          _tourCard(
            kPayTourFeesStatus,
            MobileGlassPanel(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
              child: _StateLine(payments: payments, tablet: false),
            ),
          ),
          const SizedBox(height: 26),
        ],
        // Every year lit as one by the tour.
        _tourCard(
          kPayTourFeesList,
          clipped: true,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (y, MapEntry(key: year, value: rows)) in years.entries.indexed) ...[
                if (y > 0) const SizedBox(height: 26),
                _YearHeading(year: year, rows: rows, tablet: false),
                MobileGlassPanel(
                  padding: const EdgeInsets.all(8),
                  borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, row) in rows.indexed) ...[
                        if (i > 0) const SizedBox(height: _tileGap),
                        _tile(context, row, first: y == 0 && i == 0),
                      ],
                    ],
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

// What a fee came to and how it was paid; still to pay, as the computer's table, «Da pagare» and no method.
class _FeeSheet extends StatelessWidget
{
  final PaymentHistoryRow row;

  const _FeeSheet({required this.row});

  @override
  Widget build(BuildContext context)
  {
    final DateTime? day = row.paidOn;

    return MobileSheet(
      eyebrow: kPaymentsSection,
      title: historyTitle(row),
      body: [
        const SizedBox(height: 14),
        MobileDetailRows(
          rows: [
            DetailRowData(kAmountLabel, formatAmount(row.amountCents)),
            if (day == null)
              DetailRowData.drawn(kPaidOnLabel, Align(alignment: Alignment.centerLeft, child: _due()))
            else ...[
              DetailRowData(kPaidOnLabel, '${formatWeekdayColumnLabel(day)} ${day.year}'),
              DetailRowData(kPaymentMethodLabel, _method(row.paymentMethod, row.paymentMethodOther)),
            ],
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------- tablet: the computer's table

class _TabletFees extends StatelessWidget
{
  final StudentPaymentsItem payments;

  const _TabletFees({required this.payments});

  static const double _side = 24;

  // Payment, amount, paid on, method.
  static const List<int> _flexes = [25, 14, 25, 24];

  Widget _cells(List<Widget> cells)
  {
    return Row(
      children: [
        for (final (i, cell) in cells.indexed)
          Expanded(
            flex: _flexes[i],
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 20),
              child: Align(alignment: Alignment.centerLeft, child: WholeWords(child: cell)),
            ),
          ),
      ],
    );
  }

  Widget _table(List<PaymentHistoryRow> rows)
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
              padding: const EdgeInsets.fromLTRB(_side, 14, _side, 11),
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
              _Owed(
                owed: !row.isPaid,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.fromLTRB(_side, 10, _side, 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.08))),
                  ),
                  child: _cells([
                    Text(historyTitle(row), style: _titleStyle(size: 16)),
                    Text(formatAmount(row.amountCents), style: _amountStyle(row, size: 16)),
                    row.isPaid ? Text(formatWeekdayColumnLabel(row.paidOn!), style: cell) : _due(tablet: true),
                    Text(row.isPaid ? _method(row.paymentMethod, row.paymentMethodOther) : '', style: cell),
                  ]),
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
    final Map<int, List<PaymentHistoryRow>> years = paymentsByYear(payments.history, romeNow().year);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The whole width, as the computer's status card.
        if (payments.state != null) ...[
          _tourCard(
            kPayTourFeesStatus,
            MobileGlassPanel(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
              child: Align(alignment: Alignment.centerLeft, child: _StateLine(payments: payments, tablet: true)),
            ),
          ),
          const SizedBox(height: 28),
        ],
        // Every year lit as one by the tour.
        _tourCard(
          kPayTourFeesList,
          clipped: true,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (y, MapEntry(key: year, value: rows)) in years.entries.indexed) ...[
                if (y > 0) const SizedBox(height: 28),
                _YearHeading(year: year, rows: rows, tablet: true),
                _table(rows),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
