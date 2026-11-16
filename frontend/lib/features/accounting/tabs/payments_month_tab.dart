import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_month_button.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../people/utils/payments_strings.dart' show kPaymentsSection;
import '../accounting_page.dart';
import '../export/accounting_pdf_export.dart';
import '../export/payments_month_pdf.dart';
import '../models/payments_month_items.dart';
import '../utils/accounting_strings.dart';
import '../utils/payments_month_words.dart';
import '../widgets/hours_table_parts.dart';
import '../widgets/people_filters.dart';

const double _monthLabelWidth = 200;
const double _denseMonthLabelWidth = 160;
const double _tariffMenuWidth = 230;
const double _exportWidth = 300;

const double _radius = 24;
const double _sideInset = 20;
const double _headHeight = 46;

// Below this the fixed columns narrow and the flexible ones keep the room.
const double _narrowTable = 900;

// Accounting reaches back to the association's first month.
final DateTime _firstMonth = DateTime(2023, 1);

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

class PaymentsMonthTab extends StatefulWidget
{
  // On screen among the page's summaries: shown again, it reads the month anew.
  final bool shown;

  const PaymentsMonthTab({super.key, this.shown = true});

  // Tests start from the month and filters of an app just opened.
  @visibleForTesting
  static void debugForget() => _PaymentsMonthTabState._forget();

  @override
  State<PaymentsMonthTab> createState() => _PaymentsMonthTabState();
}

class _PaymentsMonthTabState extends State<PaymentsMonthTab> with DestinationRefresh
{
  // Kept while the app runs: back from someone's payments, the same month and filters show.
  static DateTime? _shownMonth;
  static String? _shownRole;
  static String? _shownTariff;
  static int? _shownLeast;
  static int? _shownMost;

  static void _forget()
  {
    _shownMonth = null;
    _shownRole = null;
    _shownTariff = null;
    _shownLeast = null;
    _shownMost = null;
  }

  final ApiService _api = ApiService();

  late DateTime _thisMonth = _monthOf(romeNow());
  late DateTime _month = _shownMonth ?? _thisMonth;
  String? _role = _shownRole;
  String? _tariff = _shownTariff;

  // Bounds of the amount, in cents, both included.
  int? _least = _shownLeast;
  int? _most = _shownMost;

  PaymentsMonth? _data;
  Object? _error;
  bool _exporting = false;

  // A later answer for another month drops an earlier one.
  int _request = 0;

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(PaymentsMonthTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.shown && !oldWidget.shown)
    {
      unawaited(_load());
    }
  }

  @override
  void onDestinationShown()
  {
    unawaited(_load());
  }

  Future<void> _load() async
  {
    final int request = ++_request;
    _thisMonth = _monthOf(romeNow());

    if (_month.isAfter(_thisMonth))
    {
      _month = _thisMonth;
    }

    try
    {
      final PaymentsMonth data = await _api.getPaymentsMonth(_month);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _data = data;
        _error = null;
      });
    }
    catch (error)
    {
      if (!mounted || request != _request)
      {
        return;
      }

      setState(() => _error = error);
    }
  }

  void _showMonth(DateTime month)
  {
    setState(()
    {
      _month = _monthOf(month);
      _shownMonth = _month;
      _data = null;
    });

    unawaited(_load());
  }

  void _pickRole(String? role)
  {
    setState(()
    {
      _role = role;
      _shownRole = role;
    });
  }

  void _pickTariff(String? tariff)
  {
    setState(()
    {
      _tariff = tariff;
      _shownTariff = tariff;
    });
  }

  void _pickAmount(int? least, int? most)
  {
    setState(()
    {
      _least = least;
      _most = most;
      _shownLeast = least;
      _shownMost = most;
    });
  }

  bool _passes(MonthPayment row)
  {
    final String? role = _role;
    final String? tariff = _tariff;
    final int? least = _least;
    final int? most = _most;

    return (role == null || row.roles.contains(role)) &&
        (tariff == null || row.tariff == tariff) &&
        (least == null || row.amountCents >= least) &&
        (most == null || row.amountCents <= most);
  }

  // What the page shows goes to paper: the same rows, the filters said under the title.
  Future<void> _exportPdf(DateTime month, List<MonthPayment> rows) async
  {
    if (_exporting)
    {
      return;
    }

    setState(() => _exporting = true);

    final String? filters = paymentFiltersSaid(role: _role, tariff: _tariff, least: _least, most: _most);

    await exportAccountingPdf(
      context,
      title: monthlyPaymentsPdfTab(month),
      fileName: monthlyPaymentsPdfFile(month),
      bytes: () => buildPaymentsMonthPdf(month, rows, filters: filters),
    );

    if (mounted)
    {
      setState(() => _exporting = false);
    }
  }

  // Their record, on the payments; its way back leads here.
  void _open(MonthPayment row)
  {
    context.go(
      Uri(
        path: '/people/${row.taxCode}',
        queryParameters: {'from': kAccountingRoute, 'section': kPaymentsSection},
      ).toString(),
    );
  }

  Widget _tariffFilter()
  {
    return AppFilterPill<String>.filter(
      prefix: kTariffFilterPrefix,
      hint: kAllTariffsHint,
      icon: Icons.sell_outlined,
      value: _tariff,
      menuWidth: _tariffMenuWidth,
      onChanged: _pickTariff,
      onClear: () => _pickTariff(null),
      options: [
        for (final MapEntry(key: tariff, value: label) in kPaymentTariffFilters.entries)
          FilterOption(value: tariff, label: label),
      ],
    );
  }

  Widget _buildNav(bool dense)
  {
    final double button = dense ? 36 : CarouselArrowButton.defaultSize;

    final Widget label = Text(
      formatMonthYear(_month),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 14 : 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      ),
    );

    // The filters wrap on a second line before they crowd the month.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: kFilterGap,
            runSpacing: kFilterGap,
            children: [
              RoleFilterPill(value: _role, onPicked: _pickRole),
              _tariffFilter(),
              AmountFilterPill(least: _least, most: _most, onApply: _pickAmount),
            ],
          ),
        ),
        SizedBox(width: dense ? 12 : 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMonthButton(
              selected: _month,
              first: _firstMonth,
              last: _thisMonth,
              size: button,
              onPicked: _showMonth,
            ),
            SizedBox(width: dense ? 8 : 12),
            CarouselArrowButton(
              icon: Icons.chevron_left_rounded,
              isDisabled: !_month.isAfter(_firstMonth),
              size: button,
              onTap: () => _showMonth(DateTime(_month.year, _month.month - 1)),
            ),
            SizedBox(width: dense ? 6 : 8),
            SizedBox(width: dense ? _denseMonthLabelWidth : _monthLabelWidth, child: Center(child: label)),
            SizedBox(width: dense ? 6 : 8),
            CarouselArrowButton(
              icon: Icons.chevron_right_rounded,
              isDisabled: !_month.isBefore(_thisMonth),
              size: button,
              onTap: () => _showMonth(DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heading(List<MonthPayment> rows, bool dense)
  {
    final TextStyle muted = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 15 : 16,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );
    final int total = rows.fold(0, (sum, row) => sum + row.amountCents);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(paymentsCount(rows.length), maxLines: 1, style: muted)),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '$kOwedInAll  '),
                TextSpan(
                  text: formatAmount(total),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.trialTealDeep),
                ),
              ],
            ),
            style: muted,
          ),
        ],
      ),
    );
  }

  Widget _body(PaymentsMonth data, bool dense)
  {
    final List<MonthPayment> rows = [for (final row in data.rows) if (_passes(row)) row];

    if (rows.isEmpty)
    {
      return AppEmptyRoom(
        card: AppEmptyCard(
          icon: Icons.receipt_long_rounded,
          message: data.rows.isEmpty ? kNoPaymentsInMonth : kNoPaymentsFiltered,
        ),
      );
    }

    // Each block runs in after the one above it, as on the other pages.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.header, child: _heading(rows, dense)),
        const SizedBox(height: kPageHeadingGap),
        Expanded(
          child: PageTransitionScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageTransitionItem(
                    slot: PageTransitionItem.list,
                    child: _PaymentsTable(rows: rows, dense: dense, onOpen: _open),
                  ),
                  const SizedBox(height: 18),
                  PageTransitionItem(
                    slot: PageTransitionItem.list + 1,
                    child: Center(
                      child: AppGradientButton(
                        label: kExportPdf,
                        icon: Icons.picture_as_pdf_outlined,
                        width: _exportWidth,
                        height: 50,
                        fontSize: 14,
                        busy: _exporting,
                        onPressed: () => unawaited(_exportPdf(data.month, rows)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final PaymentsMonth? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final PaymentsMonth month, _) => _body(month, dense),
      _ => const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _buildNav(dense)),
        SizedBox(height: dense ? 14 : 18),
        Expanded(child: body),
      ],
    );
  }
}

// One row per payment, the newest first; a row opens the payer's payments.
class _PaymentsTable extends StatelessWidget
{
  final List<MonthPayment> rows;
  final bool dense;
  final ValueChanged<MonthPayment> onOpen;

  const _PaymentsTable({required this.rows, required this.dense, required this.onOpen});

  double get _font => dense ? 13.5 : 14.5;

  // The fixed columns and the shares of the two flexible ones.
  static ({double day, double method, double amount, double chevron}) _columns(bool narrow)
  {
    return narrow
        ? (day: 110, method: 120, amount: 92, chevron: 36)
        : (day: 190, method: 170, amount: 120, chevron: 44);
  }

  Widget _head(bool narrow)
  {
    final c = _columns(narrow);

    return Container(
      height: _headHeight,
      padding: const EdgeInsets.only(left: _sideInset),
      decoration: const BoxDecoration(
        color: kHoursHeadSurface,
        border: Border(bottom: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          SizedBox(width: c.day, child: Text(kPaymentDayColumn, style: hoursHeadStyle)),
          Expanded(flex: 3, child: Text(kDebtorColumn, style: hoursHeadStyle)),
          Expanded(flex: 4, child: Text(kPaymentWhatColumn, style: hoursHeadStyle)),
          SizedBox(width: c.method, child: Text(kPaymentMethodColumn, style: hoursHeadStyle)),
          SizedBox(
            width: c.amount,
            child: Text(kOwedAmountColumn, textAlign: TextAlign.right, style: hoursHeadStyle),
          ),
          SizedBox(width: c.chevron),
        ],
      ),
    );
  }

  Widget _row(MonthPayment row, {required bool first, required bool narrow})
  {
    final c = _columns(narrow);
    final TextStyle cell = hoursCellStyle().copyWith(fontSize: _font);

    return Container(
      padding: EdgeInsets.fromLTRB(_sideInset, dense ? 12 : 15, 0, dense ? 12 : 15),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          // Narrow, the weekday goes: «4 novembre» keeps one line.
          SizedBox(
            width: c.day,
            child: Text(narrow ? formatDayMonthFull(row.paidOn) : formatWeekdayColumnLabel(row.paidOn), style: cell),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                row.fullName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: _font + 1,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trialOcean,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(paymentWhat(row), style: cell)),
          ),
          SizedBox(
            width: c.method,
            child: Text(paymentMethodWords(row), style: hoursCellStyle(color: AppTheme.trialMutedText).copyWith(fontSize: _font)),
          ),
          SizedBox(
            width: c.amount,
            child: Text(
              formatAmount(row.amountCents),
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _font + 0.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialTealDeep,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: c.chevron,
            child: const Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialTealDeep),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool narrow = constraints.maxWidth < _narrowTable;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _head(narrow),
              for (final (index, row) in rows.indexed)
                HoverGoldFrame(
                  cardRadius: _radius,
                  atBottom: index == rows.length - 1,
                  onTap: () => onOpen(row),
                  child: _row(row, first: index == 0, narrow: narrow),
                ),
            ],
          ),
        );
      },
    );
  }
}
