import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/hover_gold_frame.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../accounting/export/accounting_pdf_export.dart';
import '../../accounting/utils/opening_strings.dart' show kPendingReason;
import '../../accounting/widgets/opening_pending_pill.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart'
    show formatDateString, isValidDateString, parseDateString;
import '../export/student_payments_pdf.dart';
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

const Color _headSurface = Color(0xFFF5F8F8);
const Color _rowRule = Color(0xFFEDF2F1);
const Color _greyBadge = Color(0xFFEEF3F3);
const Color _greyBadgeText = Color(0xFF33495A);

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
  final double settleHeight;

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
    required this.settleHeight,
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
        settleHeight: 36,
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
      settleHeight: 30,
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

// One row per payment, those to pay first; a row opens its window, «SALDA» pays it.
class PaymentHistoryTable extends StatelessWidget
{
  final List<PaymentHistoryRow> rows;
  final PaymentHistoryMetrics metrics;
  final ValueChanged<PaymentHistoryRow> onOpen;
  final ValueChanged<PaymentHistoryRow> onSettle;

  // Without hours for a member who is not a pupil: fees have none.
  final bool showHours;

  // The pupil's initial set-up is still to do: hours to settle have no amount yet.
  final bool openingPending;

  const PaymentHistoryTable({
    super.key,
    required this.rows,
    required this.metrics,
    required this.onOpen,
    required this.onSettle,
    this.showHours = true,
    this.openingPending = false,
  });

  bool _waiting(PaymentHistoryRow row) => openingPending && !row.isPaid && !row.isFee;

  TextStyle _cell({Color color = AppTheme.trialOcean, FontWeight weight = FontWeight.w500}) => GoogleFonts.plusJakartaSans(
        fontSize: metrics.cell,
        fontWeight: weight,
        height: 1.35,
        color: color,
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
      decoration: const BoxDecoration(
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
          const SizedBox(width: _chevron),
        ],
      ),
    );
  }

  Widget _title(PaymentHistoryRow row)
  {
    final String? line = historyLine(row);
    final Color tone = switch (row.state)
    {
      PaymentHistoryState.running => AppTheme.trialTealDeep,
      PaymentHistoryState.waiting => AppTheme.laterBlue,
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
              color: AppTheme.trialOcean,
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

  Widget _settle(PaymentHistoryRow row)
  {
    final double height = metrics.settleHeight;

    return AppGradientButton(
      label: kSettleLabel,
      icon: Icons.payments_outlined,
      height: height,
      radius: height / 2,
      fontSize: metrics.cell < 15 ? 11 : 12,
      horizontalPadding: 14,
      onPressed: () => onSettle(row),
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
        border: first ? null : const Border(top: BorderSide(color: _rowRule)),
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
                    : (paid ? AppTheme.trialTealDeep : AppTheme.modifiedAccent),
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
            paid
                ? Text(_method(row), style: _cell(color: const Color(0xFF33495A)))
                : (waiting ? const SizedBox.shrink() : FittedBox(fit: BoxFit.scaleDown, child: _settle(row))),
          ),
          const SizedBox(
            width: _chevron,
            child: Icon(Icons.chevron_right_rounded, size: 26, color: AppTheme.trialTealDeep),
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
        const Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _stripe,
          child: ColoredBox(color: AppTheme.trialGold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(metrics.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(),
          for (final (index, row) in rows.indexed)
            HoverGoldFrame(
              cardRadius: metrics.radius,
              atBottom: index == rows.length - 1,
              onTap: () => onOpen(row),
              leadingInset: row.isPaid || _waiting(row) ? 0 : _stripe,
              child: _row(row, first: index == 0),
            ),
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
          color: blue ? AppTheme.laterBlue : _greyBadgeText,
        ),
      ),
    );
  }
}

// Shown on a row's tap: what was paid, when and how, then its lessons; "SALDA" or "REVOCA PAGAMENTO".
Future<StudentPaymentsItem?> showPaymentDetails({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  required PaymentHistoryRow row,
})
{
  return showBlurredDialog<StudentPaymentsItem>(
    context: context,
    barrierLabel: 'Payment',
    builder: (_) => _PaymentDetails(person: person, payments: payments, row: row),
  );
}

class _PaymentDetails extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final PaymentHistoryRow row;

  const _PaymentDetails({required this.person, required this.payments, required this.row});

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
    // Fees are paid whatever the set-up; the rest waits for it.
    final String? blocked = widget.payments.openingPending && !row.isFee ? kPendingReason : null;

    if (!row.isPaid)
    {
      return AppDialogFooter.single(
        AppGradientButton(
          label: kSettleLabel,
          icon: Icons.payments_outlined,
          height: 52,
          fontSize: 14,
          disabledReason: blocked,
          onPressed: () => unawaited(_settle(context)),
        ),
      );
    }

    if (!row.canCancel)
    {
      return null;
    }

    return AppDialogFooter.single(
      maxWidth: _cancelFooterWidth,
      AppGradientButton(
        label: kCancelPaymentLabel,
        icon: Icons.undo_rounded,
        gradient: AppTheme.dangerGradient,
        accent: AppTheme.trialDanger,
        height: 52,
        fontSize: 14,
        busy: _cancelling,
        disabledReason: widget.payments.openingPending && !row.isFee ? kPendingReason : null,
        onPressed: () => unawaited(_cancel()),
      ),
    );
  }

  Future<void> _settle(BuildContext context) async
  {
    final HoursLineItem? line = payments.line(row.kind);
    final StudentPaymentsItem? saved;

    if (row.isFee)
    {
      saved = await showFeeSettleDialog(context: context, person: person, payments: payments, row: row);
    }
    else if (line != null)
    {
      saved = await showSettleDialog(context: context, person: person, payments: payments, line: line);
    }
    else
    {
      return;
    }

    if (saved != null && context.mounted)
    {
      Navigator.of(context).pop(saved);
    }
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

  Widget _figure(String text, {Color color = AppTheme.trialOcean})
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: color),
    );
  }

  Widget _facts()
  {
    final DateTime? paidOn = row.paidOn;
    final int? hours = row.packageHours;
    final int? ahead = row.aheadMinutes;

    // The pill reaches left past its column, so its mark starts where the label does.
    final Widget paid = paidOn == null
        ? Transform.translate(
            offset: const Offset(-9, 0),
            child: const PaymentDueFlag(height: _figureLine, fontSize: 14.5),
          )
        : _figure(formatWeekdayColumnLabel(paidOn));

    // Each as wide as its value, the room left shared between them; a line of its own when it runs out.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: _factGap,
      runSpacing: _factGap / 2,
      children: [
        _fact(
          kAmountColumn,
          _figure(
            formatAmount(row.amountCents),
            color: row.isPaid ? AppTheme.trialTealDeep : AppTheme.modifiedAccent,
          ),
        ),
        _fact(kPaidOnColumn, paid),
        _fact(kMethodColumn, _figure(_method(row))),
        if (!row.isFee)
          _fact(
            kHoursColumn,
            _figure(
              row.isPackage && hours != null
                  ? hoursOfPackage(row.minutes, hours)
                  : (row.isAhead && ahead != null ? hoursOfAhead(row.minutes, ahead) : _hours(row)),
            ),
          ),
      ],
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
      color: AppTheme.trialOcean,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget centred(Widget child) => Expanded(flex: 2, child: Center(child: child));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
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
            padding: const EdgeInsets.fromLTRB(4, 9, 0, 9),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _rowRule))),
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
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _facts(),
              if (row.lessons.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, thickness: 1, color: _rowRule),
                ),
                _lessons(),
              ],
            ],
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
                color: AppTheme.trialOcean,
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
