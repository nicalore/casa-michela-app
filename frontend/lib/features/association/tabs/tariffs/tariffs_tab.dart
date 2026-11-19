import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_load_failed.dart';
import '../../../../shared/widgets/page_density.dart';
import '../../../../shared/widgets/page_transition.dart';
import '../../../../shared/widgets/shared_components.dart';
import '../../models/standard_tariffs_item.dart';
import '../opening_hours/mode_hours_parts.dart' show measureText;
import 'tariff_dialogs.dart';
import 'tariffs_strings.dart';

const double _cardGap = 24;
const double _denseCardGap = 16;

// Kept around each price: below it the levels list their tariffs under their names.
const double _cellGap = 24;

const double _rowHeight = 60;
const double _denseRowHeight = 50;
const double _rowPadding = 12;
const double _labelGap = 16;
const double _editWidth = 40;

TextStyle _labelStyle(bool dense) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 14.5 : 16,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOceanText,
    );

TextStyle _headStyle(bool dense) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 13.5 : 15,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOceanText,
    );

TextStyle _priceStyle(bool dense) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 14 : 15.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialTealDeepText,
    );

TextStyle _quietStyle(bool dense) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 13.5 : 15,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

// The kinds in the order of the columns.
const List<(String, String)> _columns = [
  ('HOURLY', kHourlyColumn),
  ('PACKAGE', kPackageColumn),
  ('MONTHLY', kMonthlyColumn),
  ('WEEKEND', kWeekendColumn),
];

// Null: the kind is turned off.
String? _price(StandardTariffItem tariff, String kind)
{
  return switch (kind)
  {
    'HOURLY' when tariff.hourlyEnabled => hourlyPrice(tariff.hourlyCents),
    'PACKAGE' when tariff.packageEnabled => packagePrice(tariff.packageCents!, tariff.packageHours!),
    'MONTHLY' when tariff.monthlyEnabled => monthlyPrice(tariff.monthlyCents!),
    'WEEKEND' => hourlyPrice(tariff.weekendOnlineCents),
    _ => null,
  };
}

class TariffsTab extends StatefulWidget
{
  const TariffsTab({super.key});

  @override
  State<TariffsTab> createState() => _TariffsTabState();
}

class _TariffsTabState extends State<TariffsTab>
{
  StandardTariffsItem? _tariffs;
  bool _loading = true;
  Object? _loadFailure;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  Future<void> _load() async
  {
    try
    {
      final StandardTariffsItem tariffs = await ApiService().getStandardTariffs();

      if (mounted)
      {
        setState(()
        {
          _tariffs = tariffs;
          _loading = false;
        });
      }
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _loading = false;
        _loadFailure = e;
      });
    }
  }

  Future<void> _openLevel(StandardTariffItem tariff) async
  {
    final StandardTariffsItem? saved = await showLevelTariffsDialog(context: context, tariff: tariff);

    if (saved != null && mounted)
    {
      setState(() => _tariffs = saved);
    }
  }

  Future<void> _openFee(AnnualFeesItem fees, AnnualFee fee) async
  {
    final StandardTariffsItem? saved = await showAnnualFeeDialog(context: context, fees: fees, fee: fee);

    if (saved != null && mounted)
    {
      setState(() => _tariffs = saved);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;
    final StandardTariffsItem? tariffs = _tariffs;

    if (_loading)
    {
      return Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    if (tariffs == null)
    {
      return AppLoadFailedRoom(error: _loadFailure, message: kTariffsLoadFailed, onRetry: _load);
    }

    return AppPageDensity(
      dense: dense,
      child: PageTransitionScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageTransitionItem(
              slot: PageTransitionItem.list,
              child: _HomeworkCard(tariffs: tariffs, onOpen: _openLevel),
            ),
            SizedBox(height: dense ? _denseCardGap : _cardGap),
            PageTransitionItem(
              slot: PageTransitionItem.list + 1,
              child: _FeesCard(tariffs: tariffs, onOpen: (fee) => _openFee(tariffs.fees, fee)),
            ),
          ],
        ),
      ),
    );
  }
}

// The width of the names on the left, the same in both cards.
double _labelWidth(BuildContext context, bool dense)
{
  final TextStyle style = _labelStyle(dense);

  return [
    for (final String label in [...kTariffLevelLabels.values, kMembershipFee, kInsuranceFee])
      measureText(context, label, style),
  ].reduce(math.max);
}

Widget _edit(VoidCallback onTap)
{
  return SizedBox(
    width: _editWidth,
    child: Center(
      child: FadeHoverIconButton(
        icon: Icons.edit_outlined,
        color: AppTheme.trialTealDeepText,
        hoverColor: AppTheme.trialGoldSurface,
        iconSize: 22,
        onTap: onTap,
      ),
    ),
  );
}

class _OffPill extends StatelessWidget
{
  final bool dense;

  const _OffPill({required this.dense});

  static double paddingOf(bool dense) => dense ? 10 : 14;

  static TextStyle styleOf(bool dense) => GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13 : 14.5,
        fontWeight: FontWeight.w500,
        color: AppTheme.trialMutedText,
      );

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingOf(dense), vertical: dense ? 3 : 4),
      decoration: BoxDecoration(color: AppTheme.closedSurface, borderRadius: BorderRadius.circular(8)),
      child: Text(kTariffOff, style: styleOf(dense)),
    );
  }
}

class _HomeworkCard extends StatelessWidget
{
  final StandardTariffsItem tariffs;
  final ValueChanged<StandardTariffItem> onOpen;

  const _HomeworkCard({required this.tariffs, required this.onOpen});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return AppCard(
      title: kHomeworkCardTitle,
      compact: !dense,
      selectable: false,
      leading: AppCardBadge(icon: Icons.school_rounded, compact: !dense),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < _tableWidth(context, dense)
            ? _stacked(context, dense)
            : _table(context, dense),
      ),
    );
  }

  // The four columns as wide as their widest price, with room around it.
  double _tableWidth(BuildContext context, bool dense)
  {
    final double pill = measureText(context, kTariffOff, _OffPill.styleOf(dense)) + 2 * _OffPill.paddingOf(dense);
    double columns = 0;

    for (final (kind, _) in _columns)
    {
      double widest = 0;

      for (final StandardTariffItem tariff in tariffs.levels)
      {
        final String? price = _price(tariff, kind);
        widest = math.max(widest, price == null ? pill : measureText(context, price, _priceStyle(dense)));
      }

      columns += widest + _cellGap;
    }

    return 2 * _rowPadding + _labelWidth(context, dense) + _labelGap + columns + _editWidth;
  }

  Widget _cell(StandardTariffItem tariff, String kind, bool dense)
  {
    final String? price = _price(tariff, kind);

    return Center(
      child: price == null
          ? _OffPill(dense: dense)
          : Text(price, textAlign: TextAlign.center, style: _priceStyle(dense)),
    );
  }

  Widget _table(BuildContext context, bool dense)
  {
    final double label = _labelWidth(context, dense) + _labelGap;
    final List<StandardTariffItem> levels = tariffs.levels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(_rowPadding, 0, _rowPadding, dense ? 10 : 14),
          child: Row(
            children: [
              SizedBox(width: label),
              for (final (_, title) in _columns)
                Expanded(child: Text(title, textAlign: TextAlign.center, style: _headStyle(dense))),
              const SizedBox(width: _editWidth),
            ],
          ),
        ),
        for (final tariff in levels) ...[
          Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
          Container(
            height: dense ? _denseRowHeight : _rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
            child: Row(
              children: [
                SizedBox(
                  width: label,
                  child: Text(kTariffLevelLabels[tariff.level] ?? tariff.level, style: _labelStyle(dense)),
                ),
                for (final (kind, _) in _columns) Expanded(child: _cell(tariff, kind, dense)),
                _edit(() => onOpen(tariff)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _stacked(BuildContext context, bool dense)
  {
    final List<StandardTariffItem> levels = tariffs.levels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, tariff) in levels.indexed) ...[
          if (index > 0) Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
          Padding(
            padding: const EdgeInsets.fromLTRB(_rowPadding, 10, _rowPadding / 2, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(kTariffLevelLabels[tariff.level] ?? tariff.level, style: _labelStyle(dense)),
                    ),
                    _edit(() => onOpen(tariff)),
                  ],
                ),
                for (final (kind, title) in _columns)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: _rowPadding / 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, style: _quietStyle(dense))),
                        const SizedBox(width: 12),
                        if (_price(tariff, kind) case final price?)
                          Text(price, textAlign: TextAlign.end, style: _priceStyle(dense))
                        else
                          _OffPill(dense: dense),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FeesCard extends StatelessWidget
{
  final StandardTariffsItem tariffs;
  final ValueChanged<AnnualFee> onOpen;

  const _FeesCard({required this.tariffs, required this.onOpen});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double label = _labelWidth(context, dense) + _labelGap;
    final AnnualFeesItem fees = tariffs.fees;

    final List<(AnnualFee, String, int)> rows = [
      (AnnualFee.membership, kMembershipFee, fees.membershipCents),
      (AnnualFee.insurance, kInsuranceFee, fees.insuranceCents),
    ];

    return AppCard(
      title: kAnnualFeesCardTitle,
      compact: !dense,
      selectable: false,
      leading: AppCardBadge(icon: Icons.card_membership_rounded, compact: !dense),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (fee, title, cents)) in rows.indexed) ...[
            if (index > 0) Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
            Container(
              height: dense ? _denseRowHeight : _rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
              child: Row(
                children: [
                  SizedBox(width: label, child: Text(title, style: _labelStyle(dense))),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: formatAmount(cents), style: _priceStyle(dense)),
                          TextSpan(text: '  $kPerYear', style: _quietStyle(dense)),
                        ],
                      ),
                    ),
                  ),
                  _edit(() => onOpen(fee)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
