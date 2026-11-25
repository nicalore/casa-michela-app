import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/search_terms.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_load_failed.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/search_reveal.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kInsuranceFee, kMembershipFee;
import '../../people/models/person_item.dart';
import '../../people/models/student_payments_item.dart';
import '../../people/utils/payments_strings.dart'
    show atOpeningDay, feeDueSince, hoursText, kHoursTitles, kPaymentsSection, kSettleLabel, kSettled, lessonDaysText;
import '../../people/widgets/student_payment_dialogs.dart' show showSettleDialog;
import '../accounting_page.dart';
import '../models/to_settle_items.dart';
import '../utils/accounting_strings.dart';
import '../widgets/hours_table_parts.dart';
import '../widgets/opening_pending_pill.dart';
import '../widgets/people_filters.dart';
import '../widgets/summary_search.dart';

const double _radius = 24;
const double _sideInset = 20;
const double _headHeight = 46;
const double _periodWidth = 190;
const double _itemAmountWidth = 104;
const double _totalWidth = 120;
const double _settleWidth = 128;
const double _chevronWidth = 44;

// Below this the fixed columns narrow and the person gives room to what is owed.
const double _narrowTable = 900;
const double _narrowPeriodWidth = 150;
const double _narrowItemAmountWidth = 84;
const double _narrowTotalWidth = 92;
const double _narrowSettleWidth = 112;
const double _narrowChevronWidth = 36;
const double _itemAmountGap = 12;

// Minimal windows: blocks on floors (name and total, the items with their days, «SALDA»).
const double _stackedInset = 16;
const double _stackedChevron = 30;
const double _stackedGap = 4;

// What is owed, one line each: "Ore oltre il pacchetto: 1h 30m", "Assicurazione 2026".
String _itemLabel(OwedItem item)
{
  if (item.isFee)
  {
    return '${item.kind == 'MEMBERSHIP_FEE' ? kMembershipFee : kInsuranceFee} ${item.year ?? ''}'.trim();
  }

  // Hours never split: "1h 30m" stays on one line.
  final String hours = hoursText(item.minutes ?? 0).replaceAll(' ', '\u00A0');

  return '${kHoursTitles[item.kind] ?? ''}: $hours';
}

// When an item ran: its lessons' days, or since when a fee is owed.
String _itemPeriod(OwedItem item)
{
  if (item.isFee)
  {
    return feeDueSince(item.first);
  }

  if (item.opening)
  {
    return atOpeningDay(item.first);
  }

  return lessonDaysText(item.days.isEmpty ? [item.first, item.last] : item.days, interleaved: item.interleaved);
}

class ToSettleTab extends StatefulWidget
{
  // On screen among the page's summaries: shown again, it reads the list anew.
  final bool shown;

  const ToSettleTab({super.key, this.shown = true});

  // Tests start from the filters of an app just opened.
  @visibleForTesting
  static void debugForget() => _ToSettleTabState._forget();

  @override
  State<ToSettleTab> createState() => _ToSettleTabState();
}

class _ToSettleTabState extends State<ToSettleTab> with DestinationRefresh
{
  // Kept while the app runs: back from someone's payments, the same filters show.
  static String? _shownRole;
  static int? _shownLeast;
  static int? _shownMost;

  static void _forget()
  {
    _shownRole = null;
    _shownLeast = null;
    _shownMost = null;
  }

  final ApiService _api = ApiService();

  String? _role = _shownRole;

  // Bounds of what each person owes in all, in cents, both included.
  int? _least = _shownLeast;
  int? _most = _shownMost;

  ToSettle? _data;
  Object? _error;

  // A later answer drops an earlier one.
  int _request = 0;

  // Who is looked for by name: kept across filters.
  final TextEditingController _searchText = TextEditingController();
  final ValueNotifier<SearchTerms?> _search = ValueNotifier(null);

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose()
  {
    _searchText.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ToSettleTab oldWidget)
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

    try
    {
      final ToSettle data = await _api.getToSettle();

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

  void _pickRole(String? role)
  {
    setState(()
    {
      _role = role;
      _shownRole = role;
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

  bool _passes(Debtor row)
  {
    final String? role = _role;
    final int? least = _least;
    final int? most = _most;

    return (role == null || row.roles.contains(role)) &&
        (least == null || row.totalCents >= least) &&
        (most == null || row.totalCents <= most);
  }

  // Their record, on the payments; its way back leads here.
  void _open(Debtor row)
  {
    context.go(
      Uri(
        path: '/people/${row.taxCode}',
        queryParameters: {'from': kAccountingRoute, 'section': kPaymentsSection},
      ).toString(),
    );
  }

  // Everything the person owes, read afresh, in the one settle window; the list is read again after.
  Future<void> _settle(Debtor row) async
  {
    final PersonItem person;
    final StudentPaymentsItem payments;

    try
    {
      (person, payments) = await (_api.getPerson(row.taxCode), _api.getStudentPayments(row.taxCode)).wait;
    }
    on ParallelWaitError<(PersonItem?, StudentPaymentsItem?), (AsyncError?, AsyncError?)> catch (failure)
    {
      if (mounted)
      {
        final Object error = failure.errors.$1?.error ?? failure.errors.$2?.error ?? failure;

        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    final StudentPaymentsItem? saved = await showSettleDialog(context: context, person: person, payments: payments);

    if (!mounted)
    {
      return;
    }

    if (saved != null)
    {
      CustomSnackBar.show(context: context, message: kSettled);
    }

    unawaited(_load());
  }

  Widget _filters()
  {
    return SummarySearchFilters(
      gap: kFilterGap,
      search: AppSearchField(
        controller: _searchText,
        hintText: kPersonHint,
        onChanged: (text) => _search.value = SearchTerms.of(text),
      ),
      filters: [
        RoleFilterPill(value: _role, onPicked: _pickRole),
        AmountFilterPill(least: _least, most: _most, onApply: _pickAmount),
      ],
    );
  }

  Widget _heading(List<Debtor> rows, bool dense)
  {
    final TextStyle muted = GoogleFonts.plusJakartaSans(
      fontSize: dense ? 15 : 16,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(child: Text(debtorsCount(rows.length), maxLines: 1, style: muted)),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$kOwedInAll  '),
                TextSpan(
                  text: formatAmount(rows.fold(0, (sum, row) => sum + row.totalCents)),
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AppTheme.modifiedAccent),
                ),
              ],
            ),
            style: muted,
          ),
        ],
      ),
    );
  }

  Widget _body(ToSettle data, bool dense)
  {
    final List<Debtor> rows = [for (final row in data.rows) if (_passes(row)) row];

    if (rows.isEmpty)
    {
      return AppEmptyRoom(
        card: AppEmptyCard(
          icon: Icons.check_circle_outline_rounded,
          message: data.rows.isEmpty ? kNothingOwed : kNoDebtorsFiltered,
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
              child: PageTransitionItem(
                slot: PageTransitionItem.list,
                child: SearchReveal(
                  search: _search,
                  child: _ToSettleTable(
                    rows: rows,
                    dense: dense,
                    onOpen: _open,
                    onSettle: _settle,
                    stacked: AppBreakpoints.of(context).isMinimal,
                    search: _search,
                  ),
                ),
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
    final ToSettle? data = _data;
    final Object? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final Object failure) when data == null => AppLoadFailedRoom(
          error: failure,
          message: readableApiError(failure),
          onRetry: _load,
        ),
      (final ToSettle list, _) => _body(list, dense),
      _ => Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTransitionItem(slot: PageTransitionItem.frame, child: _filters()),
        SizedBox(height: dense ? 14 : 18),
        Expanded(child: body),
      ],
    );
  }
}

// One block per person: the name once, a line between their items, the total and «SALDA» once.
class _ToSettleTable extends StatelessWidget
{
  final List<Debtor> rows;
  final bool dense;
  final ValueChanged<Debtor> onOpen;
  final ValueChanged<Debtor> onSettle;

  // Minimal windows: blocks on floors, no columns.
  final bool stacked;

  // Who is looked for by name.
  final ValueListenable<SearchTerms?> search;

  const _ToSettleTable({
    required this.rows,
    required this.dense,
    required this.onOpen,
    required this.onSettle,
    required this.search,
    this.stacked = false,
  });

  double get _font => dense ? 13.5 : 14.5;

  double get _rowPad => dense ? 12 : 15;

  static ({double period, double amount, double total, double settle, double chevron, int name, int owed}) _columns(
    bool narrow,
  )
  {
    return narrow
        ? (
            period: _narrowPeriodWidth,
            amount: _narrowItemAmountWidth,
            total: _narrowTotalWidth,
            settle: _narrowSettleWidth,
            chevron: _narrowChevronWidth,
            name: 2,
            owed: 5,
          )
        : (
            period: _periodWidth,
            amount: _itemAmountWidth,
            total: _totalWidth,
            settle: _settleWidth,
            chevron: _chevronWidth,
            name: 3,
            owed: 7,
          );
  }

  Widget _headText(String text, {bool right = false}) =>
      Text(text, textAlign: right ? TextAlign.right : TextAlign.left, style: hoursHeadStyle);

  Widget _head(bool narrow)
  {
    final c = _columns(narrow);

    return Container(
      height: _headHeight,
      padding: const EdgeInsets.only(left: _sideInset),
      decoration: BoxDecoration(
        color: kHoursHeadSurface,
        border: Border(bottom: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          Expanded(flex: c.name, child: _headText(kDebtorColumn)),
          Expanded(
            flex: c.owed,
            child: Row(
              children: [
                Expanded(child: _headText(kOwedColumn)),
                SizedBox(width: c.period, child: _headText(kPeriodColumn)),
                SizedBox(width: c.amount, child: _headText(kOwedAmountColumn, right: true)),
              ],
            ),
          ),
          SizedBox(width: c.total, child: _headText(kTotalColumn, right: true)),
          SizedBox(width: c.settle),
          SizedBox(width: c.chevron),
        ],
      ),
    );
  }

  TextStyle get _muted => GoogleFonts.plusJakartaSans(
        fontSize: _font - 1.5,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      );

  Widget _name(Debtor row)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.fullName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: _font + 1,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialOceanText,
          ),
        ),
        if (!row.enrolled) ...[
          const SizedBox(height: 3),
          Text(kNotEnrolledNow, style: _muted),
        ],
        if (row.openingPending) ...[
          const SizedBox(height: 5),
          OpeningPendingPill(fontSize: _font - 2),
        ],
      ],
    );
  }

  bool _payable(Debtor row) => row.items.any((item) => item.cents != null);

  Widget _total(Debtor row)
  {
    final bool payable = _payable(row);

    return Text(
      payable ? formatAmount(row.totalCents) : '—',
      textAlign: TextAlign.right,
      style: GoogleFonts.plusJakartaSans(
        fontSize: _font + 0.5,
        fontWeight: FontWeight.w800,
        color: payable ? AppTheme.modifiedAccent : AppTheme.trialMutedText,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _itemAmount(OwedItem item)
  {
    return Text(
      item.cents == null ? '—' : formatAmount(item.cents!),
      textAlign: TextAlign.right,
      style: hoursCellStyle(color: item.cents == null ? AppTheme.trialMutedText : null).copyWith(
        fontSize: _font,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _settleButton(Debtor row)
  {
    final double height = dense ? 32 : 34;

    return AppGradientButton(
      label: kSettleLabel,
      icon: Icons.payments_outlined,
      height: height,
      radius: height / 2,
      fontSize: dense ? 11 : 12,
      horizontalPadding: 14,
      onPressed: () => onSettle(row),
    );
  }

  Widget _chevron(double width) =>
      SizedBox(width: width, child: Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialTealDeepText));

  // One item: what, when, how much; a line above it when it is not the first.
  Widget _item(OwedItem item, bool first, ({double period, double amount, double total, double settle, double chevron, int name, int owed}) c)
  {
    return Container(
      padding: EdgeInsets.symmetric(vertical: _rowPad),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_itemLabel(item), style: hoursCellStyle().copyWith(fontSize: _font))),
          SizedBox(
            width: c.period,
            child: Text(_itemPeriod(item), style: hoursCellStyle().copyWith(fontSize: _font)),
          ),
          SizedBox(width: c.amount, child: _itemAmount(item)),
        ],
      ),
    );
  }

  Widget _row(Debtor row, {required bool first, required bool narrow})
  {
    final c = _columns(narrow);

    return Container(
      padding: const EdgeInsets.only(left: _sideInset),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: c.name,
            child: Padding(padding: EdgeInsets.symmetric(vertical: _rowPad), child: _name(row)),
          ),
          Expanded(
            flex: c.owed,
            child: Column(
              children: [for (final (index, item) in row.items.indexed) _item(item, index == 0, c)],
            ),
          ),
          SizedBox(width: c.total, child: _total(row)),
          SizedBox(
            width: c.settle,
            child: _payable(row) ? Align(alignment: Alignment.centerRight, child: _settleButton(row)) : null,
          ),
          _chevron(c.chevron),
        ],
      ),
    );
  }

  // Minimal windows: name and total, then the items between lines, then «SALDA».
  Widget _stackedRow(Debtor row, {required bool first})
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(_stackedInset, 12, 8, 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: kHoursRowLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _name(row)),
              const SizedBox(width: _itemAmountGap),
              _total(row),
              SizedBox(
                width: _stackedChevron,
                child: Icon(Icons.chevron_right_rounded, size: 24, color: AppTheme.trialTealDeepText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (index, item) in row.items.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.only(right: _stackedChevron),
              decoration: BoxDecoration(
                border: index == 0 ? null : Border(top: BorderSide(color: kHoursRowLine)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_itemLabel(item), style: hoursCellStyle().copyWith(fontSize: _font)),
                        const SizedBox(height: _stackedGap),
                        Text(_itemPeriod(item), style: _muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: _itemAmountGap),
                  _itemAmount(item),
                ],
              ),
            ),
          if (_payable(row)) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: _stackedChevron),
              child: Align(alignment: Alignment.centerRight, child: _settleButton(row)),
            ),
          ],
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
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: AppTheme.cardShadow,
          ),
          foregroundDecoration: AppTheme.cardEdge(_radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!stacked) _head(narrow),
              for (final (index, row) in rows.indexed)
                SummarySearchRow(
                  search: search,
                  name: row.fullName,
                  cardRadius: _radius,
                  atTop: stacked && index == 0,
                  atBottom: index == rows.length - 1,
                  child: HoverGoldFrame(
                    cardRadius: _radius,
                    atTop: stacked && index == 0,
                    atBottom: index == rows.length - 1,
                    onTap: () => onOpen(row),
                    child: stacked
                        ? _stackedRow(row, first: index == 0)
                        : _row(row, first: index == 0, narrow: narrow),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
