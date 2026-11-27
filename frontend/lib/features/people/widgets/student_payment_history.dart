import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../accounting/export/accounting_pdf_export.dart';
import '../../accounting/utils/opening_strings.dart' show pendingReason;
import '../../accounting/widgets/opening_pending_pill.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart'
    show formatDateString, isValidDateString, parseDateString;
import '../export/student_payments_pdf.dart';
import '../family_payments_tour.dart';
import '../models/person_item.dart';
import '../models/student_payments_item.dart';
import '../utils/payments_strings.dart';
import 'student_payment_dialogs.dart';

const double _detailsWidth = 680;
// Room for "REVOCA PAGAMENTO" on one line.
const double _cancelFooterWidth = 620;
const double _factGap = 28;
const double _exportWidth = 560;
const double _fieldGap = 16;
const double _stripe = 4;
const double _chevron = 54;

Color get _headSurface => ThemeColours.of(0xFFF5F8F8);
Color get _rowRule => ThemeColours.of(0xFFEDF2F1);

// Closes the lessons before their total, as on the phone.
Color get _closingRule => AppTheme.trialInk.withValues(alpha: 0.28);

// A package's or the hours ahead's use, in minutes: (used, bought); null for the others.
(int, int)? hoursUse(PaymentHistoryRow row)
{
  final int? hours = row.packageHours;
  final int? ahead = row.aheadMinutes;

  if (row.isPackage && hours != null)
  {
    return (row.minutes, hours * 60);
  }

  if (row.isAhead && ahead != null)
  {
    return (row.minutes, ahead);
  }

  return null;
}

// As the status card's: used on the left, left on the right, the bar under them; gold once used up.
class PaymentHoursBar extends StatelessWidget
{
  final int used;
  final int total;
  final double fontSize;
  final double height;

  const PaymentHoursBar({super.key, required this.used, required this.total, required this.fontSize, required this.height});

  @override
  Widget build(BuildContext context)
  {
    final bool usedUp = used >= total;
    final double share = total == 0 ? 1 : (used / total).clamp(0, 1).toDouble();
    final TextStyle label = GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
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
            Text(
              leftLabel(usedUp ? 0 : total - used),
              style: usedUp ? label.copyWith(color: AppTheme.modifiedAccent) : label,
            ),
          ],
        ),
        SizedBox(height: height - 1),
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
Color get _greyBadge => ThemeColours.of(0xFFEEF3F3);
Color get _greyBadgeText => ThemeColours.fixed(0xFF33495A);

// Shares of the row: the payment, its hours, the amount, the day it was paid and how.
const int _titleShare = 34;
const int _hoursShare = 9;
const int _amountShare = 11;
const int _paidShare = 20;
const int _methodShare = 16;

String _method(PaymentHistoryRow row)
{
  final String? method = row.paymentMethod;

  if (method == null)
  {
    return '—';
  }

  return kPaymentMethodLabels[method] ?? row.paymentMethodOther ?? '—';
}

String _hours(PaymentHistoryRow row) => row.isFee ? '' : (row.minutes == 0 ? '—' : hoursText(row.minutes));

// Every size that steps down with the window, in one place.
class PaymentHistoryMetrics
{
  final double radius;
  final double sidePadding;
  final double title;
  final double line;
  final double cell;
  final double head;
  final double headHeight;
  final double rowPadding;
  final double flagHeight;

  const PaymentHistoryMetrics._({
    required this.radius,
    required this.sidePadding,
    required this.title,
    required this.line,
    required this.cell,
    required this.head,
    required this.headHeight,
    required this.rowPadding,
    required this.flagHeight,
  });

  factory PaymentHistoryMetrics.of({required bool dense})
  {
    if (!dense)
    {
      return const PaymentHistoryMetrics._(
        radius: 32,
        sidePadding: 30,
        title: 16,
        line: 13,
        cell: 15.5,
        head: 13,
        headHeight: 50,
        rowPadding: 15,
        flagHeight: 30,
      );
    }

    return const PaymentHistoryMetrics._(
      radius: 24,
      sidePadding: 20,
      title: 14,
      line: 11.5,
      cell: 13.5,
      head: 11.5,
      headHeight: 40,
      rowPadding: 10,
      flagHeight: 26,
    );
  }
}

// «Da pagare» where the day it was paid goes.
class PaymentDueFlag extends StatelessWidget
{
  final double height;
  final double fontSize;

  const PaymentDueFlag({super.key, required this.height, required this.fontSize});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 9, right: 12),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: fontSize + 2, color: AppTheme.modifiedAccent),
          const SizedBox(width: 6),
          Text(
            kToPayFlag,
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppTheme.modifiedAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- the table

// One row per payment, those to pay first; a row opens its window. What is owed is settled
// from the status card above, all of it in one window.
class PaymentHistoryTable extends StatelessWidget
{
  final List<PaymentHistoryRow> rows;
  final PaymentHistoryMetrics metrics;
  final ValueChanged<PaymentHistoryRow> onOpen;

  // Without hours for a member who is not a pupil: fees have none.
  final bool showHours;

  // The pupil's initial set-up is still to do: hours to settle have no amount yet.
  final bool openingPending;

  // Minimal windows: rows on floors, no columns.
  final bool stacked;

  // The member's own page: rows open nothing.
  final bool readOnly;

  // The row a family tour opens, and its id.
  final (PaymentHistoryRow, String)? tourRow;

  const PaymentHistoryTable({
    super.key,
    required this.rows,
    required this.metrics,
    required this.onOpen,
    this.showHours = true,
    this.openingPending = false,
    this.stacked = false,
    this.readOnly = false,
    this.tourRow,
  });

  // The chevron's room, or only the side padding when rows open nothing.
  double get _end => readOnly ? metrics.sidePadding : _chevron;

  bool _waiting(PaymentHistoryRow row) => openingPending && !row.isPaid && !row.isFee;

  TextStyle _cell({Color? color, FontWeight weight = FontWeight.w500}) => GoogleFonts.plusJakartaSans(
        fontSize: metrics.cell,
        fontWeight: weight,
        height: 1.35,
        color: color ?? AppTheme.trialOceanText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  Widget _centred(int flex, Widget child)
  {
    return Expanded(
      flex: flex,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }

  Widget _left(int flex, Widget child)
  {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 4),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }

  Widget _head()
  {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: metrics.head,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    return Container(
      height: metrics.headHeight,
      decoration: BoxDecoration(
        color: _headSurface,
        border: Border(bottom: BorderSide(color: AppTheme.trialLine)),
      ),
      child: Row(
        children: [
          SizedBox(width: metrics.sidePadding),
          Expanded(flex: _titleShare, child: Text(kPaymentColumn, style: style)),
          if (showHours) _centred(_hoursShare, Text(kHoursColumn, style: style)),
          _centred(_amountShare, Text(kAmountColumn, style: style)),
          _left(_paidShare, Text(kPaidOnColumn, style: style)),
          _left(_methodShare, Text(kMethodColumn, style: style)),
          SizedBox(width: _end),
        ],
      ),
    );
  }

  Widget _title(PaymentHistoryRow row)
  {
    final String? line = historyLine(row);
    final Color tone = switch (row.state)
    {
      PaymentHistoryState.running => AppTheme.trialTealDeepText,
      PaymentHistoryState.waiting => AppTheme.laterBlueText,
      _ => AppTheme.trialMutedText,
    };
    final bool marked = tone != AppTheme.trialMutedText;

    return Expanded(
      flex: _titleShare,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            historyTitle(row),
            style: GoogleFonts.plusJakartaSans(
              fontSize: metrics.title,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialOceanText,
            ),
          ),
          if (line != null) ...[
            const SizedBox(height: 3),
            Text(
              line,
              style: GoogleFonts.plusJakartaSans(
                fontSize: metrics.line,
                fontWeight: marked ? FontWeight.w700 : FontWeight.w500,
                color: tone,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amount(PaymentHistoryRow row)
  {
    final bool waiting = _waiting(row);

    return Text(
      waiting ? '—' : formatAmount(row.amountCents),
      style: _cell(
        color: waiting ? AppTheme.trialMutedText : (row.isPaid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent),
        weight: FontWeight.w800,
      ),
    );
  }

  // Payment and amount, then its period and hours, then when and how it was paid (or what is still to do).
  Widget _stackedRow(PaymentHistoryRow row, {required bool first})
  {
    final DateTime? paidOn = row.paidOn;
    final bool waiting = _waiting(row);
    final String? line = historyLine(row);
    final String hours = showHours ? _hours(row) : '';
    final String? counted = hours.isNotEmpty && hours != '—' ? hours : null;
    final String period = line == null ? counted ?? '' : (counted == null ? line : '$line ($counted)');
    final TextStyle small = GoogleFonts.plusJakartaSans(
      fontSize: metrics.line,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );

    final Widget state = waiting
        ? OpeningPendingPill(fontSize: metrics.cell - 2)
        : paidOn == null
        ? PaymentDueFlag(height: metrics.flagHeight, fontSize: metrics.cell - 2)
        : Text(paidOnLine(formatWeekdayColumnLabel(paidOn), paymentMethodPhrase(row.paymentMethod, row.paymentMethodOther)), style: small);

    final Widget cells = Container(
      padding: EdgeInsets.fromLTRB(metrics.sidePadding, 12, 8, 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: _rowRule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  historyTitle(row),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: metrics.title,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trialOceanText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _amount(row),
              SizedBox(
                width: readOnly ? 12 : 30,
                child: readOnly ? null : Icon(Icons.chevron_right_rounded, size: 24, color: AppTheme.trialTealDeepText),
              ),
            ],
          ),
          if (period.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(period, style: small.copyWith(fontWeight: FontWeight.w500, color: ThemeColours.fixed(0xFF33495A))),
          ],
          const SizedBox(height: 5),
          Align(alignment: Alignment.centerLeft, child: state),
        ],
      ),
    );

    if (row.isPaid || waiting)
    {
      return cells;
    }

    return Stack(
      children: [
        cells,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _stripe,
          child: ColoredBox(color: AppTheme.trialGold),
        ),
      ],
    );
  }

  Widget _row(PaymentHistoryRow row, {required bool first})
  {
    final bool paid = row.isPaid;
    final DateTime? paidOn = row.paidOn;
    final bool waiting = _waiting(row);

    final Widget cells = Container(
      padding: EdgeInsets.symmetric(vertical: metrics.rowPadding),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: _rowRule)),
      ),
      child: Row(
        children: [
          SizedBox(width: metrics.sidePadding),
          _title(row),
          if (showHours) _centred(_hoursShare, Text(_hours(row), style: _cell())),
          _centred(
            _amountShare,
            Text(
              waiting ? '—' : formatAmount(row.amountCents),
              style: _cell(
                color: waiting
                    ? AppTheme.trialMutedText
                    : (paid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent),
                weight: FontWeight.w800,
              ),
            ),
          ),
          _left(
            _paidShare,
            waiting
                ? FittedBox(fit: BoxFit.scaleDown, child: OpeningPendingPill(fontSize: metrics.cell - 2))
                : paidOn == null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PaymentDueFlag(height: metrics.flagHeight, fontSize: metrics.cell - 2),
                  )
                : Text(formatWeekdayColumnLabel(paidOn), style: _cell()),
          ),
          _left(
            _methodShare,
            // Still to pay: no way yet.
            paid
                ? Text(_method(row), style: _cell(color: ThemeColours.fixed(0xFF33495A)))
                : Text('—', style: _cell(color: AppTheme.trialMutedText)),
          ),
          SizedBox(
            width: _end,
            child: readOnly ? null : Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialTealDeepText),
          ),
        ],
      ),
    );

    if (paid || waiting)
    {
      return cells;
    }

    return Stack(
      children: [
        cells,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _stripe,
          child: ColoredBox(color: AppTheme.trialGold),
        ),
      ],
    );
  }

  // A row that opens its payment; on the member's own page it stands alone.
  Widget _framed(PaymentHistoryRow row, int index)
  {
    final Widget shown = stacked ? _stackedRow(row, first: index == 0) : _row(row, first: index == 0);

    if (readOnly)
    {
      return shown;
    }

    final (PaymentHistoryRow, String)? tour = tourRow;

    return DesktopTourTarget(
      id: tour != null && identical(tour.$1, row) ? tour.$2 : null,
      child: HoverGoldFrame(
        cardRadius: metrics.radius,
        atTop: stacked && index == 0,
        atBottom: index == rows.length - 1,
        onTap: () => onOpen(row),
        leadingInset: row.isPaid || _waiting(row) ? 0 : _stripe,
        child: shown,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(metrics.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      foregroundDecoration: AppTheme.cardEdge(metrics.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!stacked) _head(),
          for (final (index, row) in rows.indexed) _framed(row, index),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- a payment's window

class _Badge extends StatelessWidget
{
  final String label;
  final bool blue;

  const _Badge(this.label, {this.blue = false});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: blue ? AppTheme.laterBlueSurface : _greyBadge,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: blue ? AppTheme.laterBlueText : _greyBadgeText,
        ),
      ),
    );
  }
}

// Shown on a row's tap: what was paid, when and how, then its lessons; "REVOCA PAGAMENTO" when paid.
Future<StudentPaymentsItem?> showPaymentDetails({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  required PaymentHistoryRow row,
  bool readOnly = false,
})
{
  return showBlurredDialog<StudentPaymentsItem>(
    context: context,
    barrierLabel: 'Payment',
    builder: (_) => _PaymentDetails(person: person, payments: payments, row: row, readOnly: readOnly),
  );
}

class _PaymentDetails extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final PaymentHistoryRow row;

  // A family reading: nothing to revoke.
  final bool readOnly;

  const _PaymentDetails({required this.person, required this.payments, required this.row, this.readOnly = false});

  @override
  State<_PaymentDetails> createState() => _PaymentDetailsState();
}

class _PaymentDetailsState extends State<_PaymentDetails>
{
  // Line height of the figures, which the «Da pagare» pill matches.
  static const double _figureLine = 26;

  bool _cancelling = false;

  PersonItem get person => widget.person;
  StudentPaymentsItem get payments => widget.payments;
  PaymentHistoryRow get row => widget.row;

  // A family's window: told by the page's tour, or by its own the first time.
  @override
  void initState()
  {
    super.initState();

    if (!widget.readOnly)
    {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async
    {
      if (!mounted)
      {
        return;
      }

      familyPaymentWindowCloser = _close;

      final bool touring = isDesktopTourShown;

      familyPaymentWindow.value = row;

      final DesktopTour? tour = touring ? null : await familyPaymentWindowTour(row);

      if (tour != null && mounted)
      {
        startFamilyPaymentsTour(context, tour);
      }
    });
  }

  @override
  void dispose()
  {
    if (familyPaymentWindowCloser == _close)
    {
      familyPaymentWindowCloser = null;
    }

    if (widget.readOnly)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) => familyPaymentWindow.value = null);
    }

    super.dispose();
  }

  void _close()
  {
    if (mounted)
    {
      Navigator.of(context).pop();
    }
  }

  Future<void> _cancel() async
  {
    final StudentPaymentsItem? saved = await cancelPayment(
      context: context,
      person: person,
      row: row,
      onConfirmed: () => setState(() => _cancelling = true),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _cancelling = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  Widget? _footer(BuildContext context)
  {
    // Still to pay: read here, settled from the status card.
    if (widget.readOnly || !row.canCancel)
    {
      return null;
    }

    return AppDialogFooter.single(
      maxWidth: _cancelFooterWidth,
      AppGradientButton(
        label: kCancelPaymentLabel,
        icon: Icons.undo_rounded,
        gradient: AppTheme.dangerGradient,
        accent: AppTheme.trialDangerText,
        height: 52,
        fontSize: 14,
        busy: _cancelling,
        disabledReason: widget.payments.openingPending && !row.isFee
            ? pendingReason(feminine: person.gender == 'F')
            : null,
        onPressed: () => unawaited(_cancel()),
      ),
    );
  }

  Widget _fact(String label, Widget value)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: PageHeading.style().copyWith(fontSize: 11, letterSpacing: 1.6)),
        const SizedBox(height: 4),
        SizedBox(height: _figureLine, child: Align(alignment: Alignment.centerLeft, widthFactor: 1, child: value)),
      ],
    );
  }

  Widget _figure(String text, {Color? color})
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? AppTheme.trialOceanText),
    );
  }

  Widget _facts()
  {
    final DateTime? paidOn = row.paidOn;

    // The pill reaches left past its column, so its mark starts where the label does.
    final Widget paid = paidOn == null
        ? Transform.translate(
            offset: const Offset(-9, 0),
            child: const PaymentDueFlag(height: _figureLine, fontSize: 14.5),
          )
        : _figure(formatWeekdayColumnLabel(paidOn));

    // Each as wide as its value, the room left shared between them across the card; a line of its own when it
    // runs out.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: _factGap,
        runSpacing: _factGap / 2,
        children: [
          _fact(
            kAmountColumn,
            _figure(
              formatAmount(row.amountCents),
              color: row.isPaid ? AppTheme.trialTealDeepText : AppTheme.modifiedAccent,
            ),
          ),
          _fact(kPaidOnColumn, paid),
          _fact(kMethodColumn, _figure(_method(row))),
        ],
      ),
    );
  }

  // «LEZIONI», as the facts' labels.
  Widget _lessonsTitle()
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(kLessonsCard.toUpperCase(), style: PageHeading.style().copyWith(fontSize: 11, letterSpacing: 1.6)),
    );
  }

  // Ore, weekend and months: what the lessons add up to.
  Widget _totalRow(bool third)
  {
    final TextStyle total = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: AppTheme.trialOceanText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget centred(Widget child) => Expanded(flex: 2, child: Center(child: child));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _closingRule, width: 1.5))),
      child: Row(
        children: [
          Expanded(flex: 6, child: Text(kSettleTotal, style: total)),
          centred(Text(hoursText(row.minutes), style: total)),
          if (third) centred(Text(formatAmount(row.amountCents), style: total)),
        ],
      ),
    );
  }

  Widget _lessons()
  {
    final bool third = !row.isMonth;
    final String thirdLabel = row.countsDown ? kLeftColumn : kCostColumn;

    final TextStyle head = GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.trialMutedText,
    );
    final TextStyle cell = GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppTheme.trialOceanText,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget centred(Widget child) => Expanded(flex: 2, child: Center(child: child));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(flex: 6, child: Text(kDayColumn, style: head)),
              centred(Text(kHoursColumn, style: head)),
              if (third) centred(Text(thirdLabel, style: head)),
            ],
          ),
        ),
        for (final PaymentHistoryLesson lesson in row.lessons)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _rowRule))),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        lesson.opening ? atOpeningDay(lesson.day) : formatWeekdayColumnLabel(lesson.day),
                        style: cell.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (lesson.exhausted) _Badge(exhaustedBadge(row)),
                      if (lesson.beforePayment) _Badge(takenBadge(row), blue: true),
                    ],
                  ),
                ),
                centred(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hoursText(lesson.minutes), style: cell),
                      if (lesson.isPart)
                        Text(
                          ofLesson(lesson.lessonMinutes),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.trialMutedText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (third)
                  centred(
                    Text(
                      row.countsDown
                          ? hoursText(lesson.leftMinutes ?? 0)
                          : formatAmount(lesson.cents ?? 0),
                      style: cell,
                    ),
                  ),
              ],
            ),
          ),
        if (!row.countsDown) _totalRow(third),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kPaymentEyebrow,
      title: historyTitle(row),
      maxWidth: _detailsWidth,
      footer: _footer(context),
      closeTourId: widget.readOnly ? kTourPaymentClose : null,
      // What was paid, then the lessons it covers: a package's hours as the status card's bar over them.
      children: [
        DesktopTourTarget(id: widget.readOnly ? kTourPaymentFacts : null, child: AppDialogPill(child: _facts())),
        if (row.lessons.isNotEmpty)
          DesktopTourTarget(
            id: widget.readOnly ? kTourPaymentLessons : null,
            child: AppDialogPill(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _lessonsTitle(),
                  if (hoursUse(row) case (final int used, final int total)) ...[
                    PaymentHoursBar(used: used, total: total, fontSize: 15, height: 10),
                    const SizedBox(height: 20),
                  ],
                  _lessons(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- the export

// The two days, typed; the PDF has the payments made between them and those to pay with lessons there.
Future<void> showPaymentsExport({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'Export',
    builder: (_) => _PaymentsExport(person: person, payments: payments, exportContext: context),
  );
}

class _PaymentsExport extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  // The tab's, which outlives this window and tells how the PDF went.
  final BuildContext exportContext;

  const _PaymentsExport({required this.person, required this.payments, required this.exportContext});

  @override
  State<_PaymentsExport> createState() => _PaymentsExportState();
}

class _PaymentsExportState extends State<_PaymentsExport>
{
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();

  String? _fromError;
  String? _toError;

  // From the first payment or lesson to today, both days filled in and locked.
  bool _fromStart = false;

  // What was typed, back when the tick goes off.
  String _typedFrom = '';
  String _typedTo = '';

  @override
  void dispose()
  {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  static DateTime _today()
  {
    final DateTime now = romeNow();

    return DateTime(now.year, now.month, now.day);
  }

  // Nothing is paid or done after today, so a later day is refused.
  static String? _error(String text)
  {
    if (text.isEmpty)
    {
      return kRequiredField;
    }

    return isValidDateString(text) && !parseDateString(text).isAfter(_today()) ? null : kInvalidDate;
  }

  // The earliest payment or lesson; today when there is none.
  DateTime _firstDay()
  {
    DateTime first = _today();

    for (final PaymentHistoryRow row in widget.payments.history)
    {
      for (final DateTime day in [?row.paidOn, for (final lesson in row.lessons) lesson.day])
      {
        if (day.isBefore(first))
        {
          first = day;
        }
      }
    }

    return first;
  }

  // Straight from the tap: the PDF's tab opens before anything is awaited.
  void _export()
  {
    final String from = _from.text.trim();
    final String to = _to.text.trim();

    setState(()
    {
      _fromError = _error(from);
      _toError = _error(to);

      if (_fromError == null && _toError == null && parseDateString(to).isBefore(parseDateString(from)))
      {
        _toError = kEndBeforeStart;
      }
    });

    if (_fromError != null || _toError != null)
    {
      return;
    }

    final String name = '${widget.person.firstName} ${widget.person.lastName}';
    final DateTime first = parseDateString(from);
    final DateTime last = parseDateString(to);

    unawaited(
      exportAccountingPdf(
        widget.exportContext,
        title: paymentsPdfFooter(name, first, last),
        fileName: paymentsPdfFile(name, first, last),
        bytes: () => buildStudentPaymentsPdf(name: name, payments: widget.payments, from: first, to: last),
      ),
    );

    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController controller, String label, String? error, VoidCallback onChanged, {bool enabled = true})
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: kDateHint,
      keyboardType: TextInputType.datetime,
      nothingAbove: true,
      enabled: enabled,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), DateInputFormatter()],
      errorText: error,
      onChanged: (_) => onChanged(),
    );
  }

  Widget _fromStartTick()
  {
    void toggle() => setState(()
    {
      _fromStart = !_fromStart;
      _fromError = null;
      _toError = null;

      if (_fromStart)
      {
        _typedFrom = _from.text;
        _typedTo = _to.text;
        _from.text = formatDateString(_firstDay());
        _to.text = formatDateString(_today());
      }
      else
      {
        _from.text = _typedFrom;
        _to.text = _typedTo;
      }
    });

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCheckMark(selected: _fromStart),
            const SizedBox(width: 10),
            Text(
              kFromStartLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialOceanText,
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
    return AppDialogStack(
      eyebrow: kPaymentsEyebrow,
      title: kExportTitle,
      maxWidth: _exportWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kExportLabel,
          icon: Icons.picture_as_pdf_outlined,
          height: 52,
          fontSize: 14,
          onPressed: _export,
        ),
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      _from,
                      kFromDayLabel,
                      _fromError,
                      () => setState(() => _fromError = null),
                      enabled: !_fromStart,
                    ),
                  ),
                  const SizedBox(width: _fieldGap),
                  Expanded(
                    child: _field(
                      _to,
                      kToDayLabel,
                      _toError,
                      () => setState(() => _toError = null),
                      enabled: !_fromStart,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _fieldGap),
              Align(alignment: Alignment.centerLeft, child: _fromStartTick()),
            ],
          ),
        ),
      ],
    );
  }
}
