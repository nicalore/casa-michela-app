import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kInsuranceFee, kMembershipFee;
import '../../people/utils/payments_strings.dart' show hoursText, kHoursTitles, kPaymentsSection;
import '../accounting_page.dart';
import '../models/to_settle_items.dart';
import '../utils/accounting_strings.dart';
import '../widgets/hours_table_parts.dart';
import '../widgets/people_filters.dart';

const double _radius = 24;
const double _sideInset = 20;
const double _headHeight = 46;
const double _sinceWidth = 150;
const double _amountWidth = 120;
const double _chevronWidth = 44;

// Below this the fixed columns narrow and the person gives room to what is owed.
const double _narrowTable = 900;
const double _narrowSinceWidth = 136;
const double _narrowAmountWidth = 92;
const double _narrowChevronWidth = 36;
const double _itemGap = 4;
const double _itemAmountGap = 12;

// What is owed, one line each: «Ore oltre il pacchetto · 1h 30m», «Assicurazione 2026».
String _itemLabel(OwedItem item)
{
  if (item.isFee)
  {
    return '${item.kind == 'MEMBERSHIP_FEE' ? kMembershipFee : kInsuranceFee} ${item.year ?? ''}'.trim();
  }

  // Hours never split: «1h 30m» stays on one line with its dot.
  final String hours = hoursText(item.minutes ?? 0).replaceAll(' ', '\u00A0');

  return '${kHoursTitles[item.kind] ?? ''}\u00A0· $hours';
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
  String? _error;

  // A later answer drops an earlier one.
  int _request = 0;

  @override
  void initState()
  {
    super.initState();
    unawaited(_load());
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

      setState(() => _error = readableApiError(error));
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

  Widget _filters()
  {
    return Wrap(
      spacing: kFilterGap,
      runSpacing: kFilterGap,
      children: [
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
                const TextSpan(text: '$kOwedInAll  '),
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
                child: _ToSettleTable(rows: rows, dense: dense, onOpen: _open),
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
    final String? error = _error;

    final Widget body = switch ((data, error))
    {
      (_, final String message) when data == null => AppEmptyRoom(
          card: AppEmptyCard(icon: Icons.error_outline_rounded, message: message),
        ),
      (final ToSettle list, _) => _body(list, dense),
      _ => const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
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

// One row per person, what they owe line by line; a row opens their payments.
class _ToSettleTable extends StatelessWidget
{
  final List<Debtor> rows;
  final bool dense;
  final ValueChanged<Debtor> onOpen;

  const _ToSettleTable({required this.rows, required this.dense, required this.onOpen});

  double get _font => dense ? 13.5 : 14.5;

  // The fixed columns and the shares of the two flexible ones.
  static ({double since, double amount, double chevron, int name, int owed}) _columns(bool narrow)
  {
    return narrow
        ? (since: _narrowSinceWidth, amount: _narrowAmountWidth, chevron: _narrowChevronWidth, name: 2, owed: 4)
        : (since: _sinceWidth, amount: _amountWidth, chevron: _chevronWidth, name: 3, owed: 5);
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
          Expanded(flex: c.name, child: Text(kDebtorColumn, style: hoursHeadStyle)),
          Expanded(flex: c.owed, child: Text(kOwedColumn, style: hoursHeadStyle)),
          SizedBox(width: c.since, child: Text(kSinceColumn, style: hoursHeadStyle)),
          SizedBox(
            width: c.amount,
            child: Text(kOwedAmountColumn, textAlign: TextAlign.right, style: hoursHeadStyle),
          ),
          SizedBox(width: c.chevron),
        ],
      ),
    );
  }

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
            color: AppTheme.trialOcean,
          ),
        ),
        if (!row.enrolled) ...[
          const SizedBox(height: 3),
          Text(
            kNotEnrolledNow,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _font - 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ],
    );
  }

  Widget _items(Debtor row, bool narrow)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in row.items.indexed) ...[
          if (index > 0) const SizedBox(height: _itemGap),
          Row(
            children: [
              Expanded(child: Text(_itemLabel(item), style: hoursCellStyle().copyWith(fontSize: _font))),
              const SizedBox(width: _itemAmountGap),
              Text(
                formatAmount(item.cents),
                style: hoursCellStyle(color: AppTheme.trialMutedText).copyWith(
                  fontSize: _font - 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: narrow ? _itemAmountGap : _itemAmountGap * 2),
            ],
          ),
        ],
      ],
    );
  }

  Widget _row(Debtor row, int thisYear, {required bool first, required bool narrow})
  {
    final c = _columns(narrow);

    return Container(
      padding: EdgeInsets.fromLTRB(_sideInset, dense ? 12 : 15, 0, dense ? 12 : 15),
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: kHoursRowLine)),
      ),
      child: Row(
        children: [
          Expanded(flex: c.name, child: _name(row)),
          Expanded(flex: c.owed, child: _items(row, narrow)),
          SizedBox(
            width: c.since,
            child: Text(owedSince(row.since, thisYear), style: hoursCellStyle().copyWith(fontSize: _font)),
          ),
          SizedBox(
            width: c.amount,
            child: Text(
              formatAmount(row.totalCents),
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _font + 0.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.modifiedAccent,
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
    final int thisYear = romeNow().year;

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
                  child: _row(row, thisYear, first: index == 0, narrow: narrow),
                ),
            ],
          ),
        );
      },
    );
  }
}
