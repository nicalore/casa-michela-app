import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../settings/utils/settings_strings.dart' show kComingSoon;
import '../family_payments_tour.dart';
import '../models/person_item.dart';
import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';
import 'family_pay_choice.dart';
import 'payment_dialog_parts.dart';
import 'settle_items.dart';

// Room for a day, its hours and its amount beside the ticks, as the admin's settle window.
const double _width = kPaymentDialogWidth + 40;

// Wide enough for «PROCEDI AL PAGAMENTO» on one line.
const double _footerWidth = 720;

const double _tickInset = 4;
const double _tickGap = 14;
const double _wordsInset = _tickInset + AppCheckMark.size + _tickGap;

Color get _rule => ThemeColours.of(0xFFEDF2F1);

// A parent or a pupil nobody answers for: what is owed, the renewal, hours ahead; then Stripe.
Future<void> showFamilyPayDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'Payment',
    builder: (_) => _FamilyPayDialog(person: person, payments: payments),
  );
}

class _FamilyPayDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  const _FamilyPayDialog({required this.person, required this.payments});

  @override
  State<_FamilyPayDialog> createState() => _FamilyPayDialogState();
}

class _FamilyPayDialogState extends State<_FamilyPayDialog>
{
  late final FamilyPayChoice _choice = FamilyPayChoice(widget.payments);

  final TextEditingController _hours = TextEditingController();
  int _minutes = 0;

  final TextEditingController _weekendHours = TextEditingController();
  int _weekendMinutes = 0;

  // Its parts told the first time they show.
  @override
  void initState()
  {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async
    {
      if (!mounted || isDesktopTourShown)
      {
        return;
      }

      final DesktopTour? tour = await familyPayWindowTour(widget.payments.tariff, weekend: _choice.weekendAhead);

      if (tour != null && mounted)
      {
        startFamilyPaymentsTour(context, tour);
      }
    });
  }

  @override
  void dispose()
  {
    _hours.dispose();
    _weekendHours.dispose();
    super.dispose();
  }

  void _readAhead()
  {
    final int hours = int.tryParse(_hours.text.trim()) ?? 0;

    _choice.aheadMinutes = hours * 60 + _minutes;
  }

  void _readWeekendAhead()
  {
    final int hours = int.tryParse(_weekendHours.text.trim()) ?? 0;

    _choice.weekendAheadMinutes = hours * 60 + _weekendMinutes;
  }

  TextStyle _text(double size, FontWeight weight, Color color)
  {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  Widget _tickRow({required VoidCallback? onTap, required Widget child})
  {
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }

  // A line of hours with its days, or a fee: the admin's settle rows.
  Widget _item(int index)
  {
    final SettleItem item = _choice.items[index];
    final Set<int> chosen = _choice.chosen(index);
    final int free = [for (var i = 0; i < item.count; i++) if (!_choice.covered(index, i)) i].length;
    final bool whole = _choice.wholeCovered(index);
    final int cents = chosen.isEmpty ? item.cents : _choice.cents(index);
    final String? period = item.period;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tickRow(
          onTap: whole ? null : () => setState(() => _choice.toggleItem(index)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: _tickInset),
            child: Row(
              children: [
                AppCheckMark(
                  selected: whole || (free > 0 && chosen.length == free),
                  partial: chosen.isNotEmpty && chosen.length < free,
                  muted: whole,
                ),
                const SizedBox(width: _tickGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: _text(15.5, FontWeight.w700, AppTheme.trialOceanText)),
                      if (period != null) ...[
                        const SizedBox(height: 2),
                        Text(period, style: _text(13.5, FontWeight.w500, AppTheme.trialMutedText)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatAmount(cents),
                  style: _text(
                    15.5,
                    FontWeight.w800,
                    chosen.isEmpty ? AppTheme.trialMutedText : AppTheme.modifiedAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        // One day alone is the item itself.
        if (item.days.length > 1)
          DesktopTourTarget(
            id: index == _firstWithDays ? kTourPayDays : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final (i, day) in item.days.indexed) _day(index, i, day)],
            ),
          ),
      ],
    );
  }

  int get _firstWithDays => _choice.items.indexWhere((item) => item.days.length > 1);

  Widget _day(int index, int i, SettleDay day)
  {
    final bool covered = _choice.covered(index, i);
    final bool ticked = _choice.chosen(index).contains(i);

    return _tickRow(
      onTap: covered ? null : () => setState(() => _choice.toggleDay(index, i)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_wordsInset, 6, _tickInset, 6),
        child: Row(
          children: [
            AppCheckMark(selected: ticked || covered, muted: covered),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                day.opening ? atOpeningDay(day.day) : formatWeekdayColumnLabel(day.day),
                style: _text(14.5, FontWeight.w500, covered ? AppTheme.trialMutedText : AppTheme.trialOceanText),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                formatMinutes(day.minutes),
                textAlign: TextAlign.right,
                style: _text(14, FontWeight.w500, AppTheme.trialMutedText),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                formatAmount(day.cents),
                textAlign: TextAlign.right,
                style: _text(14.5, FontWeight.w600, ticked ? AppTheme.trialOceanText : AppTheme.trialMutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A small line under a choice: when it starts, what it takes over.
  Widget _under(String text, {Color? color})
  {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: _text(13.5, FontWeight.w600, color ?? AppTheme.trialMutedText)),
    );
  }

  Widget _renewalRow(FamilyRenewal renewal)
  {
    final bool ticked = _choice.renewalTicked;
    final String? note = renewal.note;
    final String? cover = renewal.coverNote;

    return _tickRow(
      onTap: () => setState(() => _choice.renewalTicked = !ticked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: _tickInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: AppCheckMark(selected: ticked)),
            const SizedBox(width: _tickGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(renewal.title, style: _text(15.5, FontWeight.w700, AppTheme.trialOceanText)),
                  _under(renewal.detail),
                  _under(
                    note == null ? renewal.when : '${renewal.when} (${note[0].toLowerCase()}${note.substring(1)})',
                    color: renewal.later ? AppTheme.laterBlueText : AppTheme.trialTealDeepText,
                  ),
                  if (ticked && cover != null) _under(cover),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatAmount(renewal.cents),
              style: _text(15.5, FontWeight.w800, ticked ? AppTheme.modifiedAccent : AppTheme.trialMutedText),
            ),
          ],
        ),
      ),
    );
  }

  // Lessons by the hour at the tariff's rate, or [weekend] online at its own.
  Widget _aheadRow({bool weekend = false})
  {
    final StudentTariffItem tariff = widget.payments.tariff!;
    final bool ticked = weekend ? _choice.weekendAheadTicked : _choice.aheadTicked;
    final String? note = weekend ? _choice.weekendAheadNote : _choice.aheadNote;
    final String cost = weekend
        ? tariffCost('HOURLY', widget.payments.weekendOnlineCents ?? 0, null)
        : tariffCost(tariff.kind, tariff.amountCents, tariff.packageHours);
    final TextEditingController hours = weekend ? _weekendHours : _hours;
    final VoidCallback read = weekend ? _readWeekendAhead : _readAhead;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tickRow(
          onTap: () => setState(()
          {
            if (weekend)
            {
              _choice.weekendAheadTicked = !ticked;
            }
            else
            {
              _choice.aheadTicked = !ticked;
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: _tickInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: AppCheckMark(selected: ticked)),
                const SizedBox(width: _tickGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekend ? kPayWeekendAheadTitle : kPayAheadTitle,
                        style: _text(15.5, FontWeight.w700, AppTheme.trialOceanText),
                      ),
                      _under(cost),
                      if (note != null) _under(note),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatAmount(weekend ? _choice.weekendAheadCents : _choice.aheadCents),
                  style: _text(15.5, FontWeight.w800, ticked ? AppTheme.modifiedAccent : AppTheme.trialMutedText),
                ),
              ],
            ),
          ),
        ),
        if (ticked)
          Padding(
            padding: const EdgeInsets.fromLTRB(_wordsInset, 4, _tickInset, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: hours,
                    label: kAheadHoursLabel,
                    hintText: kAheadHoursHint,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: kPackageHoursDigits,
                    onChanged: (_) => setState(read),
                  ),
                ),
                const SizedBox(width: kPaymentFieldGap),
                Expanded(
                  child: QuarterMinutesField(
                    value: weekend ? _weekendMinutes : _minutes,
                    onChanged: (minutes) => setState(()
                    {
                      if (weekend)
                      {
                        _weekendMinutes = minutes;
                      }
                      else
                      {
                        _minutes = minutes;
                      }

                      read();
                    }),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final TextStyle eyebrow = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: AppTheme.trialMutedText,
    );
    final FamilyRenewal? renewal = _choice.renewal;
    final List<SettleItem> items = _choice.items;
    final bool others = renewal != null || _choice.ahead || _choice.weekendAhead;

    return AppDialogStack(
      eyebrow: kPaymentEyebrow,
      title: '${widget.person.firstName} ${widget.person.lastName}',
      maxWidth: _width,
      // Stripe is not linked yet.
      footer: AppDialogFooter.single(
        DesktopTourTarget(
          id: kTourPayButton,
          child: AppGradientButton(
            label: kProceedToPayment,
            icon: Icons.lock_rounded,
            height: 52,
            fontSize: 14,
            disabledReason: kComingSoon,
            onPressed: () {},
          ),
        ),
        maxWidth: _footerWidth,
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isNotEmpty)
                DesktopTourTarget(
                  id: kTourPayOwed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(kToSettleBlock.toUpperCase(), style: eyebrow),
                      const SizedBox(height: 6),
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1, thickness: 1, color: _rule),
                          ),
                        _item(i),
                      ],
                    ],
                  ),
                ),
              if (others) ...[
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Divider(height: 1, thickness: 1.5, color: _rule),
                  const SizedBox(height: 18),
                ],
                DesktopTourTarget(
                  id: kTourPayOthers,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(kOtherPayments.toUpperCase(), style: eyebrow),
                      const SizedBox(height: 6),
                      if (renewal != null) _renewalRow(renewal),
                      if (_choice.ahead) _aheadRow(),
                      if (_choice.weekendAhead) _aheadRow(weekend: true),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Divider(height: 1, thickness: 1.5, color: _rule),
              // The word under the items' titles, the sum under their amounts, on one baseline.
              Padding(
                padding: const EdgeInsets.fromLTRB(_wordsInset, 20, _tickInset, 0),
                child: DesktopTourTarget(
                  id: kTourPayTotal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(kSettleTotal, style: _text(16.5, FontWeight.w800, AppTheme.trialOceanText))),
                      Text(formatAmount(_choice.total), style: _text(18, FontWeight.w800, AppTheme.modifiedAccent)),
                    ],
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
