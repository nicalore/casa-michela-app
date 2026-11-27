import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../features/people/models/student_payments_item.dart';
import '../../../features/people/utils/payments_strings.dart';
import '../../../features/people/widgets/family_pay_choice.dart';
import '../../../features/people/widgets/settle_items.dart';
import '../../../features/settings/utils/settings_strings.dart' show kComingSoon;
import '../../../services/api_service.dart';
import '../../../shared/widgets/unfolding_rows.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_gold_button.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_select_parts.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_text_field.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_family_payments_tour.dart';

// As the percorsi sheet of a discipline: its panel, its lines.
const double _panelRadius = 18;
const double _panelGap = 8;
const double _lineInset = 6;
const double _dayIndent = 36;
const double _coveredOpacity = 0.45;

// Tour holes: the part's corner plus what they grow by.
const EdgeInsets _tourGroupInflate = EdgeInsets.all(6);
const double _tourGroupRadius = _panelRadius + 6;
const EdgeInsets _tourArrowInflate = EdgeInsets.all(6);
const double _tourArrowRadius = 18;

Color get _panelFill => ThemeColours.fixed(0xB8FFFFFF);

// A parent or a pupil nobody answers for: what is owed, the renewal, hours ahead; then Stripe.
Future<void> showMobileFamilyPaySheet({
  required BuildContext context,
  required StudentPaymentsItem payments,
  required String name,
})
{
  return showMobileSheet<void>(context: context, builder: (context) => _PaySheet(payments: payments, name: name));
}

class _Head extends StatelessWidget
{
  final String title;

  const _Head(this.title);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25, color: AppTheme.trialInk),
      ),
    );
  }
}

// One panel per item, as a level of the percorsi.
class _Panel extends StatelessWidget
{
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context)
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelFill,
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: AppTheme.trialInk.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_panelRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

// A line of several days, as a sector: the arrow opens its days, the circle takes them all.
class _DaysLine extends StatelessWidget
{
  final String title;
  final String amount;
  final int chosen;
  final int total;
  final bool open;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  // The first line's arrow, which the tour has touched.
  final String? arrowTour;

  const _DaysLine({
    required this.title,
    required this.amount,
    required this.chosen,
    required this.total,
    required this.open,
    required this.onOpen,
    required this.onToggle,
    this.arrowTour,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool all = chosen == total;

    return Semantics(
      button: true,
      expanded: open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.only(left: 10, right: _lineInset),
          child: Row(
            children: [
              MobileTourTarget(
                id: arrowTour,
                inflate: _tourArrowInflate,
                radius: _tourArrowRadius,
                child: AnimatedRotation(
                  turns: open ? 0 : -0.25,
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 24,
                    color: AppTheme.trialInk.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: open ? AppTheme.trialTealDeepText : AppTheme.trialInk,
                        ),
                      ),
                      Text(amount, style: mobileSelectAmountStyle(AppTheme.modifiedAccent)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$chosen/$total',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: MobilePalette.mutedText),
              ),
              const SizedBox(width: 4),
              MobileSelectAllToggle(selected: all, partial: chosen > 0 && !all, onTap: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaySheet extends StatefulWidget
{
  final StudentPaymentsItem payments;
  final String name;

  const _PaySheet({required this.payments, required this.name});

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet>
{
  late final FamilyPayChoice _choice = FamilyPayChoice(widget.payments);

  // Lines whose days are unfolded.
  final Set<int> _open = {};

  final TextEditingController _hours = TextEditingController();
  final TextEditingController _weekendHours = TextEditingController();

  // The first line of several days, whose arrow the tour touches; whether it is unfolded.
  late final int _firstDays = _choice.items.indexWhere((item) => item.days.length > 1);
  final ValueNotifier<bool> _daysOpen = ValueNotifier(false);

  @override
  void initState()
  {
    super.initState();
    _hours.addListener(() => setState(() => _choice.aheadMinutes = (int.tryParse(_hours.text.trim()) ?? 0) * 60));
    _weekendHours.addListener(
      () => setState(() => _choice.weekendAheadMinutes = (int.tryParse(_weekendHours.text.trim()) ?? 0) * 60),
    );
  }

  @override
  void dispose()
  {
    _hours.dispose();
    _weekendHours.dispose();
    _daysOpen.dispose();
    super.dispose();
  }

  void _unfold(int index, bool open)
  {
    setState(() => open ? _open.add(index) : _open.remove(index));

    if (index == _firstDays)
    {
      _daysOpen.value = open;
    }
  }

  // Once risen: the parts never told.
  void _tour()
  {
    final String? taxCode = ApiService().lastKnownIdentity?.taxCode;

    if (taxCode == null)
    {
      return;
    }

    startFamilyPayTour(
      taxCode: taxCode,
      tariff: widget.payments.tariff,
      days: _daysOpen,
      fold: () => _unfold(_firstDays, false),
      weekend: _choice.weekendAhead,
    );
  }

  // The subtitle and, while it applies, what the choice takes over.
  String _subtitle(String text, String? note) => note == null ? text : '$text\n$note';

  Widget _line({
    required String title,
    String? subtitle,
    required String amount,
    required bool selected,
    required VoidCallback onTap,
  })
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _lineInset, vertical: 2),
      child: MobileSelectLine(title: title, subtitle: subtitle, amount: amount, selected: selected, onTap: onTap),
    );
  }

  Widget _day(int index, int i, SettleDay day, String? cover)
  {
    final bool covered = _choice.covered(index, i);
    final Widget line = MobileSelectLine(
      title: day.opening ? atOpeningDay(day.day) : formatWeekdayColumnLabel(day.day),
      subtitle: '${hoursText(day.minutes)} – ${formatAmount(day.cents)}',
      selected: !covered && _choice.chosen(index).contains(i),
      // Paid by the ticked renewal or hours ahead: the reason, nothing taken.
      onTap: covered
          ? () => MobileNotice.show(context, cover ?? kUnsettledTakenNow)
          : () => setState(() => _choice.toggleDay(index, i)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(_dayIndent, 2, _lineInset, 2),
      child: covered ? Opacity(opacity: _coveredOpacity, child: line) : line,
    );
  }

  Widget _owed(int index)
  {
    final SettleItem item = _choice.items[index];
    final Set<int> chosen = _choice.chosen(index);
    final String cover = _choice.coverNote(index);

    if (item.days.length <= 1)
    {
      final bool covered = item.days.isNotEmpty && _choice.covered(index, 0);
      final Widget line = _line(
        title: item.name,
        subtitle: item.period,
        amount: formatAmount(item.cents),
        selected: chosen.isNotEmpty,
        onTap: covered
            ? () => MobileNotice.show(context, cover)
            : () => setState(() => _choice.toggleItem(index)),
      );

      return _Panel(children: [covered ? Opacity(opacity: _coveredOpacity, child: line) : line]);
    }

    final int free = [for (var i = 0; i < item.count; i++) if (!_choice.covered(index, i)) i].length;
    // Every day paid by the ticked renewal or hours ahead: all shown taken, dimmed, the reason on a touch.
    final bool whole = _choice.wholeCovered(index);
    final Widget line = _DaysLine(
      title: item.name,
      amount: formatAmount(chosen.isEmpty ? item.cents : _choice.cents(index)),
      chosen: whole ? item.count : chosen.length,
      total: whole ? item.count : free,
      open: _open.contains(index),
      onOpen: () => _unfold(index, !_open.contains(index)),
      onToggle: whole ? () => MobileNotice.show(context, cover) : () => setState(() => _choice.toggleItem(index)),
      arrowTour: index == _firstDays ? kFamilyPayTourDays : null,
    );

    return _Panel(
      children: [
        whole ? Opacity(opacity: _coveredOpacity, child: line) : line,
        UnfoldingRows(
          open: _open.contains(index),
          animate: !MediaQuery.disableAnimationsOf(context),
          padding: const EdgeInsets.only(bottom: 4),
          children: [for (final (i, day) in item.days.indexed) _day(index, i, day, cover)],
        ),
      ],
    );
  }

  // The hours to buy, unfolded under a ticked line ahead.
  Widget _hoursField(TextEditingController controller, bool open)
  {
    return UnfoldingRows(
      open: open,
      animate: !MediaQuery.disableAnimationsOf(context),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_dayIndent, 6, 12, 8),
          child: MobileTextField(
            controller: controller,
            label: kAheadHoursLabel,
            hintText: kAheadHoursHint,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
          ),
        ),
      ],
    );
  }

  List<Widget> _others()
  {
    final FamilyRenewal? renewal = _choice.renewal;
    final StudentTariffItem? tariff = widget.payments.tariff;
    final String weekendCost = tariffCost('HOURLY', widget.payments.weekendOnlineCents ?? 0, null);

    return [
      if (renewal != null)
        _Panel(
          children: [
            _line(
              title: renewal.title,
              subtitle: _subtitle(renewal.detail, _choice.renewalTicked ? renewal.coverNote : null),
              amount: formatAmount(renewal.cents),
              selected: _choice.renewalTicked,
              onTap: () => setState(() => _choice.renewalTicked = !_choice.renewalTicked),
            ),
          ],
        ),
      if (_choice.ahead && tariff != null)
        _Panel(
          children: [
            _line(
              title: kPayAheadTitle,
              subtitle: _subtitle(tariffCost(tariff.kind, tariff.amountCents, tariff.packageHours), _choice.aheadNote),
              amount: formatAmount(_choice.aheadCents),
              selected: _choice.aheadTicked,
              onTap: () => setState(() => _choice.aheadTicked = !_choice.aheadTicked),
            ),
            _hoursField(_hours, _choice.aheadTicked),
          ],
        ),
      if (_choice.weekendAhead)
        _Panel(
          children: [
            _line(
              title: kPayWeekendAheadTitle,
              subtitle: _subtitle(weekendCost, _choice.weekendAheadNote),
              amount: formatAmount(_choice.weekendAheadCents),
              selected: _choice.weekendAheadTicked,
              onTap: () => setState(() => _choice.weekendAheadTicked = !_choice.weekendAheadTicked),
            ),
            _hoursField(_weekendHours, _choice.weekendAheadTicked),
          ],
        ),
    ];
  }

  List<Widget> _spaced(List<Widget> panels)
  {
    return [
      for (final (index, panel) in panels.indexed) ...[
        if (index > 0) const SizedBox(height: _panelGap),
        panel,
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle total = GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.trialInk);
    final List<Widget> others = _others();

    // The hours ahead are typed in: the field stays above the keyboard.
    return MobileSheet(
      eyebrow: kPaymentEyebrow,
      title: widget.name,
      aboveKeyboard: true,
      body: [
        MobileTourOnRise(onRisen: _tour, child: const SizedBox(height: 18)),
        if (_choice.items.isNotEmpty)
          MobileTourTarget(
            id: kFamilyPayTourOwed,
            inflate: _tourGroupInflate,
            radius: _tourGroupRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(kToSettleBlock),
                ..._spaced([for (var i = 0; i < _choice.items.length; i++) _owed(i)]),
              ],
            ),
          ),
        if (others.isNotEmpty) ...[
          if (_choice.items.isNotEmpty) const SizedBox(height: 24),
          MobileTourTarget(
            id: kFamilyPayTourOthers,
            inflate: _tourGroupInflate,
            radius: _tourGroupRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(kOtherPayments),
                ..._spaced(others),
              ],
            ),
          ),
        ],
      ],
      footer: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: MobileTourTarget(
          id: kFamilyPayTourProceed,
          inflate: _tourGroupInflate,
          radius: _tourGroupRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.12))),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(kSettleTotal, style: total)),
                    Text(formatAmount(_choice.total), style: total.copyWith(color: AppTheme.modifiedAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Stripe is not linked yet.
              MobileGoldButton(
                label: kProceedToPayment,
                icon: Icons.lock_rounded,
                onPressed: () => MobileNotice.show(context, kComingSoon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
