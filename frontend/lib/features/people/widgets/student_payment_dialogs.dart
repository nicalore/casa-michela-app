import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart';
import '../../association/models/standard_tariffs_item.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show kWeekendColumn, tariffOffFor;
import '../edit/homework_tariffs.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../models/person_item.dart';
import '../models/student_payments_item.dart';
import '../tabs/person_account_shared.dart' show askPersonConfirmation;
import '../utils/payments_strings.dart';
import 'payment_dialog_parts.dart';
import 'settle_items.dart';

export 'settle_items.dart' show hasSomethingToSettle;

const double _dialogWidth = kPaymentDialogWidth;

// The settle window: room for a day, its hours and its amount beside the ticks.
const double _settleWidth = kPaymentDialogWidth + 40;
const double _gap = kPaymentDialogGap;
const double _fieldGap = kPaymentFieldGap;
const int _packageHoursDigits = kPackageHoursDigits;

DateTime _today() => paymentToday();

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

DateTime _nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

// A change waiting to start cannot be taken back: the server takes no day further than this.
const int _longestWaitDays = 366;

bool _tooFar(DateTime day) => day.difference(_today()).inDays > _longestWaitDays;

class _PaymentInput extends PaymentInput
{
  _PaymentInput(StudentPaymentsItem payments)
      : super(method: payments.paymentMethod, otherMethod: payments.paymentMethodOther);
}

typedef _Note = PaymentNote;
typedef _PaymentFields = PaymentFields;
typedef _Conditions = TariffConditions;
typedef _ConditionFields = TariffConditionFields;

// «TARIFFA ATTUALE» over the kind and its cost.
class _CurrentTariffBox extends StatelessWidget
{
  final StudentPaymentsItem payments;

  const _CurrentTariffBox({required this.payments});

  @override
  Widget build(BuildContext context)
  {
    final StudentTariffItem tariff = payments.tariff!;

    return PaymentFactBox(
      eyebrow: kCurrentTariffLabel,
      text: currentTariff(tariff.kind, tariff.amountCents, tariff.packageHours),
    );
  }
}

// When it starts: blue while the running package or month goes on, teal when at once.
class _WhenBox extends StatelessWidget
{
  final String title;
  final String? note;
  final bool later;

  const _WhenBox({required this.title, this.note, required this.later});

  @override
  Widget build(BuildContext context)
  {
    final Color accent = later ? AppTheme.laterBlueText : AppTheme.trialTealDeepText;
    final String? note = this.note;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: later ? AppTheme.laterBlueSurface : AppTheme.paidSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(later ? Icons.schedule_rounded : Icons.event_rounded, size: 22, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: later ? AppTheme.laterBlueText : AppTheme.trialOceanText,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: ThemeColours.fixed(0xFF33495A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _footer(String label, IconData icon, bool busy, VoidCallback onPressed) =>
    paymentDialogFooter(label, icon, busy, onPressed);

Future<StudentPaymentsItem?> _show(BuildContext context, String label, Widget dialog)
{
  return showBlurredDialog<StudentPaymentsItem>(context: context, barrierLabel: label, builder: (_) => dialog);
}

// Runs a write, shows its refusal; the tab as it now stands, or null.
Future<StudentPaymentsItem?> _send(BuildContext context, Future<StudentPaymentsItem> Function() write) async
{
  try
  {
    return await write();
  }
  catch (error)
  {
    if (context.mounted)
    {
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }

    return null;
  }
}

// ---------------------------------------------------------------- cancel

// Asked first; the tab as it now stands, or null when not confirmed or refused.
Future<StudentPaymentsItem?> cancelPayment({
  required BuildContext context,
  required PersonItem person,
  required PaymentHistoryRow row,
  VoidCallback? onConfirmed,
}) async
{
  final int? feeId = row.feeId;
  final int? paymentId = row.paymentId;

  final bool confirmed = await askPersonConfirmation(
    context,
    eyebrow: kPaymentEyebrow,
    message: [TextSpan(text: cancelPaymentMessage(row))],
    confirmLabel: kConfirmCancelLabel,
    confirmIcon: Icons.undo_rounded,
    danger: true,
  );

  if (!confirmed || !context.mounted)
  {
    return null;
  }

  onConfirmed?.call();

  if (row.isFee && feeId != null)
  {
    return _send(
      context,
      () => ApiService().cancelMembershipFeePayment(taxCode: person.fiscalCode, feeId: feeId),
    );
  }

  if (paymentId != null)
  {
    return _send(
      context,
      () => ApiService().cancelStudentPayment(taxCode: person.fiscalCode, paymentId: paymentId),
    );
  }

  return null;
}

// ---------------------------------------------------------------- renew

// The package or month running bought again; its figures start as the last ones and can change.
Future<StudentPaymentsItem?> showRenewDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return _show(context, 'Renewal', _RenewDialog(person: person, payments: payments));
}

class _RenewDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  const _RenewDialog({required this.person, required this.payments});

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog>
{
  late final StudentTariffItem _tariff = widget.payments.tariff!;
  late final _Conditions _conditions = _Conditions(
    hours: _tariff.packageHours?.toString() ?? '',
    amount: formatAmount(_tariff.amountCents),
  );
  late final _PaymentInput _payment = _PaymentInput(widget.payments);
  final DateTime _today0 = _today();

  bool _saving = false;

  bool get _package => _tariff.isPackage;

  // The month bought: this one, or the next when this one is paid.
  DateTime get _month
  {
    final DateTime month = _monthOf(_today0);

    return widget.payments.monthPaid(_today0) ? _nextMonth(month) : month;
  }

  @override
  void dispose()
  {
    _conditions.dispose();
    _payment.dispose();
    super.dispose();
  }

  Widget _when()
  {
    final StudentPaymentsItem payments = widget.payments;

    if (_package)
    {
      final PackageStatusItem? package = payments.package;

      if (package != null && package.running)
      {
        return _WhenBox(title: kAtPackageEnd, note: stillLeft(package.leftMinutes), later: true);
      }

      final List<LessonPartItem> over = [
        for (final LessonPartItem part in payments.line('OVER_PACKAGE')?.parts ?? const <LessonPartItem>[])
          if (part.current) part,
      ];

      return _WhenBox(
        title: startsFromDay(over.isEmpty ? _today0 : over.first.day),
        note: over.isEmpty ? null : kUnsettledTakenNow,
        later: false,
      );
    }

    if (payments.monthPaid(_today0))
    {
      return _WhenBox(title: startsFromMonth(_month), later: true);
    }

    final int covered = payments
            .line('OVER_FEE')
            ?.minutesWhere((part) => part.current && _sameMonth(part.day, _today0)) ??
        0;

    return _WhenBox(
      title: startsFromMonth(_month),
      note: covered > 0 ? coveredByFee(covered) : null,
      later: false,
    );
  }

  Future<void> _save() async
  {
    final (int, int?)? conditions = _conditions.read(package: _package);
    final Map<String, dynamic>? payment = _payment.read();

    setState(() {});

    if (conditions == null || payment == null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().renewStudentTariff(
        taxCode: widget.person.fiscalCode,
        amountCents: conditions.$1,
        packageHours: conditions.$2,
        payment: payment,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: _package ? kPackageEyebrow : kMonthlyEyebrow,
      title: _package ? kRenewPackageTitle : kRenewMonthTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kRenewLabel, Icons.autorenew_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentTariffBox(payments: widget.payments),
              _when(),
              const SizedBox(height: 4),
              _ConditionFields(conditions: _conditions, kind: _tariff.kind, onChanged: () => setState(() {})),
              _PaymentFields(input: _payment, title: kPaymentBlock, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- change tariff

// [standard]: the level's tariffs, which propose the figures and strike the kinds turned off.
Future<StudentPaymentsItem?> showChangeTariffDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  StandardTariffItem? standard,
})
{
  return _show(
    context,
    'Tariff change',
    _ChangeTariffDialog(person: person, payments: payments, standard: standard),
  );
}

class _ChangeTariffDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final StandardTariffItem? standard;

  const _ChangeTariffDialog({required this.person, required this.payments, this.standard});

  @override
  State<_ChangeTariffDialog> createState() => _ChangeTariffDialogState();
}

class _ChangeTariffDialogState extends State<_ChangeTariffDialog>
{
  late final StudentTariffItem _tariff = widget.payments.tariff!;
  final _Conditions _conditions = _Conditions();
  late final _PaymentInput _payment = _PaymentInput(widget.payments);
  late final TextEditingController _day = TextEditingController(text: formatDateString(_today0));
  final DateTime _today0 = _today();

  String? _choice;
  String? _choiceError;
  String? _dayError;

  // From this month rather than the next, where months decide.
  bool _thisMonth = true;

  bool _saving = false;

  List<String> get _options => [
        for (final String label in kTariffChoices)
          if (kTariffKinds[label] != _tariff.kind) label,
      ];

  String? get _kind => kTariffKinds[_choice];

  bool get _packageRunning => _tariff.isPackage && (widget.payments.package?.running ?? false);

  // Hours paid ahead still left: the new tariff starts when they end.
  AheadStatusItem? get _ahead => _tariff.isHourly ? widget.payments.ahead : null;

  bool get _monthPaid => _tariff.isMonthly && widget.payments.monthPaid(_today0);

  // Months decide from a fee, towards a fee, and from a package that ended.
  bool get _byMonth => !_packageRunning && _ahead == null && !_monthPaid && (_tariff.isMonthly || _kind == 'MONTHLY');

  DateTime get _month
  {
    final DateTime month = _monthOf(_today0);

    return _thisMonth && !_monthPaid ? month : _nextMonth(month);
  }

  @override
  void dispose()
  {
    _conditions.dispose();
    _payment.dispose();
    _day.dispose();
    super.dispose();
  }

  // The kinds turned off for the pupil's level, with the reason.
  Map<String, String> get _struck
  {
    final StandardTariffItem? standard = widget.standard;

    if (standard == null)
    {
      return const {};
    }

    return {
      for (final String option in _options)
        if (!standard.enabled(kTariffKinds[option]!)) option: tariffOffFor(widget.payments.schoolLevel),
    };
  }

  void _choose(String? choice)
  {
    final StandardTariffItem? defaults = widget.standard;
    final String? kind = kTariffKinds[choice];

    setState(()
    {
      _choice = choice;
      _choiceError = null;
      _conditions.amountError = null;
      _conditions.hoursError = null;

      final int? cents = kind == null ? null : defaults?.centsOf(kind);

      _conditions.amount.text = cents == null ? '' : formatAmount(cents);
      _conditions.hours.text = kind == 'PACKAGE' ? '${defaults?.packageHours ?? ''}' : '';
    });
  }

  DateTime? get _pickedDay
  {
    final String text = _day.text.trim();

    return isValidDateString(text) ? parseDateString(text) : null;
  }

  int _minutes(String kind, bool Function(LessonPartItem part) test)
  {
    return widget.payments.line(kind)?.minutesWhere(test) ?? 0;
  }

  // What happens to the hours not settled yet, as the choice now stands.
  String? _note()
  {
    final String? kind = _kind;
    final DateTime month = _monthOf(_today0);

    if (kind == null || _ahead != null)
    {
      return null;
    }

    if (_tariff.isHourly && kind == 'PACKAGE')
    {
      final DateTime? day = _pickedDay;
      final int before = day == null ? 0 : _minutes('HOURLY', (part) => part.day.isBefore(day));

      return before > 0 ? doneBeforeToSettle(before) : null;
    }

    if (_tariff.isMonthly)
    {
      if (!_thisMonth || _monthPaid)
      {
        return null;
      }

      final int done = _minutes('OVER_FEE', (part) => part.current && _sameMonth(part.day, month));

      if (done == 0)
      {
        return null;
      }

      return kind == 'PACKAGE' ? kDoneTakenByPackage : kDoneStillToSettle;
    }

    // From hours or from a package that ended: those hours stay apart.
    final String line = _tariff.isHourly ? 'HOURLY' : 'OVER_PACKAGE';

    if (_packageRunning)
    {
      return null;
    }

    if (kind == 'HOURLY')
    {
      final int over = _minutes(line, (_) => true);

      return over > 0 ? doneBeforeToSettle(over) : null;
    }

    if (_thisMonth)
    {
      final int covered = _minutes(line, (part) => _sameMonth(part.day, month));

      return covered > 0 ? coveredByFee(covered) : null;
    }

    final int left = _minutes(line, (_) => true);
    final bool allThisMonth = _minutes(line, (part) => _sameMonth(part.day, month)) == left;

    if (left == 0)
    {
      return null;
    }

    return allThisMonth ? doneInMonthToSettle(left, month) : doneBeforeToSettle(left);
  }

  Widget? _start()
  {
    final String? kind = _kind;

    if (kind == null)
    {
      return null;
    }

    if (_packageRunning)
    {
      return _WhenBox(title: kAtPackageEnd, note: stillLeft(widget.payments.package!.leftMinutes), later: true);
    }

    final AheadStatusItem? ahead = _ahead;

    if (ahead != null)
    {
      return _WhenBox(title: kAtAheadEnd, note: stillLeft(ahead.leftMinutes), later: true);
    }

    if (_monthPaid)
    {
      return _WhenBox(title: startsFromMonth(_month), later: true);
    }

    if (_byMonth)
    {
      final DateTime month = _monthOf(_today0);

      return Padding(
        padding: const EdgeInsets.only(top: _fieldGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFieldLabel(kFromWhenLabel),
            const SizedBox(height: 10),
            AppSegmentedSwitch(
              value: _thisMonth,
              trueLabel: fromMonth(month),
              falseLabel: fromMonth(_nextMonth(month)),
              onChanged: (value) => setState(() => _thisMonth = value),
            ),
          ],
        ),
      );
    }

    if (_tariff.isHourly)
    {
      return Padding(
        padding: const EdgeInsets.only(top: _fieldGap),
        child: AppTextField(
          controller: _day,
          label: kFromDayLabel,
          hintText: kDateHint,
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          errorText: _dayError,
          nothingAbove: true,
          onChanged: (_) => setState(() => _dayError = null),
        ),
      );
    }

    // A package that ended, towards hours: from today.
    return _WhenBox(title: startsFromDay(_today0), later: false);
  }

  String? get _paymentTitle
  {
    return switch (_kind)
    {
      'PACKAGE' => kPackagePaymentBlock,
      'MONTHLY' => _packageRunning || _ahead != null ? kFirstFeePaymentBlock : feePaymentBlock(_month),
      _ => null,
    };
  }

  Future<void> _save() async
  {
    final String? kind = _kind;

    if (kind == null)
    {
      setState(() => _choiceError = kRequiredField);

      return;
    }

    final (int, int?)? conditions = _conditions.read(package: kind == 'PACKAGE');
    final bool paid = kind != 'HOURLY';
    final Map<String, dynamic>? payment = paid ? _payment.read() : null;
    final bool askDay = _tariff.isHourly && kind == 'PACKAGE' && _ahead == null;
    final DateTime? day = askDay ? _pickedDay : null;

    _dayError = null;

    if (askDay)
    {
      if (_day.text.trim().isEmpty)
      {
        _dayError = kRequiredField;
      }
      else if (day == null)
      {
        _dayError = kInvalidDate;
      }
      else if (day.isBefore(_tariff.startsOn))
      {
        _dayError = kDayTooEarly;
      }
      else if (_tooFar(day))
      {
        _dayError = kDayTooFar;
      }
    }

    setState(() {});

    if (conditions == null || (paid && payment == null) || _dayError != null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().changeStudentTariff(
        taxCode: widget.person.fiscalCode,
        kind: kind,
        amountCents: conditions.$1,
        packageHours: conditions.$2,
        startsOn: day,
        nextMonth: _byMonth && !_thisMonth,
        payment: payment,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context)
  {
    final String? kind = _kind;
    final Widget? start = _start();
    final String? note = _note();
    final String? paymentTitle = _paymentTitle;

    return AppDialogStack(
      eyebrow: kTariffEyebrow,
      title: kChangeTariffTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kChangeLabel, Icons.swap_horiz_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentTariffBox(payments: widget.payments),
              const SizedBox(height: _gap),
              PersonChipGroupField(
                label: kNewTariffLabel,
                options: _options,
                struck: _struck,
                value: _choice,
                errorText: _choiceError,
                onChanged: _choose,
              ),
              if (kind != null) ...[
                const SizedBox(height: 4),
                _ConditionFields(conditions: _conditions, kind: kind, onChanged: () => setState(() {})),
              ],
              ?start,
              if (note != null) _Note(note),
              if (paymentTitle != null)
                _PaymentFields(input: _payment, title: paymentTitle, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- first tariff

// A pupil on file without a tariff takes one from a day on; its package or fee is bought with the renewal.
Future<StudentPaymentsItem?> showFirstTariffDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  StandardTariffItem? standard,
})
{
  return _show(
    context,
    'First tariff',
    _FirstTariffDialog(person: person, payments: payments, standard: standard),
  );
}

class _FirstTariffDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final StandardTariffItem? standard;

  const _FirstTariffDialog({required this.person, required this.payments, this.standard});

  @override
  State<_FirstTariffDialog> createState() => _FirstTariffDialogState();
}

class _FirstTariffDialogState extends State<_FirstTariffDialog>
{
  final _Conditions _conditions = _Conditions();
  final TextEditingController _day = TextEditingController(text: formatDateString(_today()));

  String? _choice;
  String? _choiceError;
  String? _dayError;
  bool _saving = false;

  String? get _kind => kTariffKinds[_choice];

  @override
  void dispose()
  {
    _conditions.dispose();
    _day.dispose();
    super.dispose();
  }

  // The kinds turned off for the pupil's level, with the reason.
  Map<String, String> get _struck
  {
    final StandardTariffItem? standard = widget.standard;

    if (standard == null)
    {
      return const {};
    }

    return {
      for (final String option in kTariffChoices)
        if (!standard.enabled(kTariffKinds[option]!)) option: tariffOffFor(widget.payments.schoolLevel),
    };
  }

  void _choose(String? choice)
  {
    final StandardTariffItem? defaults = widget.standard;
    final String? kind = kTariffKinds[choice];

    setState(()
    {
      _choice = choice;
      _choiceError = null;
      _conditions.amountError = null;
      _conditions.hoursError = null;

      final int? cents = kind == null ? null : defaults?.centsOf(kind);

      _conditions.amount.text = cents == null ? '' : formatAmount(cents);
      _conditions.hours.text = kind == 'PACKAGE' ? '${defaults?.packageHours ?? ''}' : '';
    });
  }

  Future<void> _save() async
  {
    final String? kind = _kind;

    if (kind == null)
    {
      setState(() => _choiceError = kRequiredField);

      return;
    }

    final (int, int?)? conditions = _conditions.read(package: kind == 'PACKAGE');
    final String text = _day.text.trim();
    final DateTime? day = isValidDateString(text) ? parseDateString(text) : null;

    _dayError = text.isEmpty
        ? kRequiredField
        : (day == null ? kInvalidDate : (day.isAfter(_today()) ? kDayInFuture : null));

    setState(() {});

    if (conditions == null || _dayError != null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().changeStudentTariff(
        taxCode: widget.person.fiscalCode,
        kind: kind,
        amountCents: conditions.$1,
        packageHours: conditions.$2,
        startsOn: day,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context)
  {
    final String? kind = _kind;

    return AppDialogStack(
      eyebrow: kTariffEyebrow,
      title: kGiveTariffTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kGiveLabel, Icons.check_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PersonChipGroupField(
                label: kTariffFigure,
                options: kTariffChoices,
                struck: _struck,
                value: _choice,
                errorText: _choiceError,
                onChanged: _choose,
              ),
              if (kind != null) ...[
                const SizedBox(height: 4),
                _ConditionFields(conditions: _conditions, kind: kind, onChanged: () => setState(() {})),
              ],
              const SizedBox(height: _fieldGap),
              AppTextField(
                controller: _day,
                label: kFromDayLabel,
                hintText: kDateHint,
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                errorText: _dayError,
                nothingAbove: true,
                onChanged: (_) => setState(() => _dayError = null),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- hourly rate

Future<StudentPaymentsItem?> showChangeRateDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return _show(context, 'Hourly rate', _ChangeRateDialog(person: person, payments: payments));
}

class _ChangeRateDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  const _ChangeRateDialog({required this.person, required this.payments});

  @override
  State<_ChangeRateDialog> createState() => _ChangeRateDialogState();
}

class _ChangeRateDialogState extends State<_ChangeRateDialog>
{
  late final StudentTariffItem _tariff = widget.payments.tariff!;
  late final _Conditions _conditions = _Conditions(amount: formatAmount(_tariff.amountCents));
  final TextEditingController _day = TextEditingController(text: formatDateString(_today()));

  String? _dayError;
  bool _saving = false;

  @override
  void dispose()
  {
    _conditions.dispose();
    _day.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    final (int, int?)? conditions = _conditions.read(package: false);
    final String text = _day.text.trim();
    final DateTime? day = isValidDateString(text) ? parseDateString(text) : null;

    _dayError = text.isEmpty
        ? kRequiredField
        : (day == null
            ? kInvalidDate
            : (day.isBefore(_tariff.startsOn) ? kDayTooEarly : (_tooFar(day) ? kDayTooFar : null)));

    setState(() {});

    if (conditions == null || _dayError != null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().changeStudentTariff(
        taxCode: widget.person.fiscalCode,
        kind: 'HOURLY',
        amountCents: conditions.$1,
        startsOn: day,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context)
  {
    final int? cents = parseAmountCents(_conditions.amount.text);
    final bool changed = cents != null && cents > 0 && cents != _tariff.amountCents;
    final AheadStatusItem? ahead = widget.payments.ahead;

    return AppDialogStack(
      eyebrow: kTariffEyebrow,
      title: kChangeRateTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kChangeLabel, Icons.edit_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentTariffBox(payments: widget.payments),
              const SizedBox(height: 4),
              _ConditionFields(conditions: _conditions, kind: 'HOURLY', onChanged: () => setState(() {})),
              const SizedBox(height: _fieldGap),
              AppTextField(
                controller: _day,
                label: kFromDayLabel,
                hintText: kDateHint,
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                errorText: _dayError,
                nothingAbove: true,
                onChanged: (_) => setState(() => _dayError = null),
              ),
              if (changed) _Note(rateFromDayNote(cents, _tariff.amountCents)),
              if (changed && ahead != null) _Note(aheadKeepsItsPrice(ahead.leftMinutes)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- settle

// The ticked lines: the tick, then the words; the total keeps their edges.
const double _tickInset = 4;
const double _tickGap = 14;
const double _wordsInset = _tickInset + AppCheckMark.size + _tickGap;

// A ticked line: the whole of it answers the pointer, without a ripple.
class _TickRow extends StatelessWidget
{
  final VoidCallback onTap;
  final Widget child;

  const _TickRow({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
    );
  }
}

// Everything owed, ticked: lines of hours day by day, fees; one day and one way for all.
Future<StudentPaymentsItem?> showSettleDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return _show(context, 'Settlement', _SettleDialog(person: person, payments: payments));
}

class _SettleDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  const _SettleDialog({required this.person, required this.payments});

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog>
{
  late final List<SettleItem> _items = settleItemsOf(widget.payments);

  // For each item the indices of its ticked days; a fee has one.
  late final List<Set<int>> _ticked = [
    for (final item in _items) {for (var i = 0; i < item.count; i++) i},
  ];

  late final _PaymentInput _payment = _PaymentInput(widget.payments);

  late final SettleItem? _editable = _items.where((item) => item.rateEditable).firstOrNull;

  // The rate shown; left as it is, every line keeps its own.
  late final int? _shownRate = _editable?.line!.centsPerHour;
  late final TextEditingController _rate = TextEditingController(
    text: _shownRate == null ? '' : formatAmount(_shownRate),
  );
  String? _rateError;

  bool _saving = false;

  @override
  void dispose()
  {
    _payment.dispose();
    _rate.dispose();
    super.dispose();
  }

  // The rate a line is settled at: its own, unless another was written.
  int _rateOf(SettleItem item)
  {
    final HoursLineItem line = item.line!;
    final int? written = parseAmountCents(_rate.text);

    if (!item.rateEditable || written == null || written <= 0 || written == _shownRate)
    {
      return line.centsPerHour;
    }

    return written;
  }

  int _dayCents(SettleItem item, SettleDay day)
  {
    final int rate = _rateOf(item);

    return rate == item.line!.centsPerHour ? day.cents : settleHourCents(day.minutes, rate);
  }

  // As the server prices it: the days' own sums at the line's rate, else the minutes at the one asked.
  int _cents(SettleItem item, Iterable<int> ticked)
  {
    if (item.fee != null)
    {
      return ticked.isEmpty ? 0 : item.fee!.amountCents;
    }

    final int rate = _rateOf(item);
    final List<SettleDay> days = [for (final i in ticked) item.days[i]];

    return rate == item.line!.centsPerHour
        ? days.fold(0, (sum, day) => sum + day.cents)
        : settleHourCents(days.fold(0, (sum, day) => sum + day.minutes), rate);
  }

  int get _total => [for (var i = 0; i < _items.length; i++) _cents(_items[i], _ticked[i])].fold(0, (a, b) => a + b);

  void _toggleItem(int index)
  {
    setState(()
    {
      final bool all = _ticked[index].length == _items[index].count;

      _ticked[index]
        ..clear()
        ..addAll(all ? const <int>[] : [for (var i = 0; i < _items[index].count; i++) i]);
    });
  }

  void _toggleDay(int index, int day)
  {
    setState(() => _ticked[index].contains(day) ? _ticked[index].remove(day) : _ticked[index].add(day));
  }

  // Null, with the error set, when the rate is needed and not valid.
  bool _rateValid()
  {
    final bool needed = [
      for (var i = 0; i < _items.length; i++)
        if (_items[i].rateEditable && _ticked[i].isNotEmpty) i,
    ].isNotEmpty;
    final int? cents = parseAmountCents(_rate.text);

    _rateError = !needed
        ? null
        : (_rate.text.trim().isEmpty ? kRequiredField : (cents == null || cents <= 0 ? kInvalidAmountMessage : null));

    return _rateError == null;
  }

  Future<void> _save() async
  {
    final bool chosen = _ticked.any((days) => days.isNotEmpty);

    if (!chosen)
    {
      CustomSnackBar.show(context: context, message: kNothingChosen, isError: true);

      return;
    }

    final bool rate = _rateValid();
    final Map<String, dynamic>? payment = _payment.read();

    setState(() {});

    if (!rate || payment == null)
    {
      return;
    }

    final hours = [
      for (final (index, item) in _items.indexed)
        if (item.line != null && _ticked[index].isNotEmpty)
          (
            kind: item.line!.kind,
            centsPerHour: _rateOf(item),
            // Every day ticked: the whole line, whatever was confirmed since is refused by the minutes.
            days: _ticked[index].length == item.count
                ? null
                : [for (final i in _ticked[index].toList()..sort()) item.days[i].day],
            expectedMinutes: item.line!.minutes,
          ),
    ];
    final List<int> fees = [
      for (final (index, item) in _items.indexed)
        if (item.fee != null && _ticked[index].isNotEmpty) item.fee!.feeId!,
    ];

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().settleStudentItems(
        taxCode: widget.person.fiscalCode,
        hours: hours,
        feeIds: fees,
        payment: payment,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
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

  Widget _item(int index)
  {
    final SettleItem item = _items[index];
    final int ticked = _ticked[index].length;
    // Nothing ticked: its whole amount, grey.
    final int cents = ticked == 0
        ? _cents(item, [for (var i = 0; i < item.count; i++) i])
        : _cents(item, _ticked[index]);
    final String? period = item.period;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TickRow(
          onTap: () => _toggleItem(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: _tickInset),
            child: Row(
              children: [
                AppCheckMark(selected: ticked == item.count, partial: ticked > 0 && ticked < item.count),
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
                  style: _text(15.5, FontWeight.w800, ticked == 0 ? AppTheme.trialMutedText : AppTheme.modifiedAccent),
                ),
              ],
            ),
          ),
        ),
        // One day alone is the item itself.
        if (item.days.length > 1)
          for (final (i, day) in item.days.indexed)
            _TickRow(
              onTap: () => _toggleDay(index, i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_wordsInset, 6, _tickInset, 6),
                child: Row(
                  children: [
                    AppCheckMark(selected: _ticked[index].contains(i)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        day.opening ? atOpeningDay(day.day) : formatWeekdayColumnLabel(day.day),
                        style: _text(14.5, FontWeight.w500, AppTheme.trialOceanText),
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
                        formatAmount(_dayCents(item, day)),
                        textAlign: TextAlign.right,
                        style: _text(
                          14.5,
                          FontWeight.w600,
                          _ticked[index].contains(i) ? AppTheme.trialOceanText : AppTheme.trialMutedText,
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

  @override
  Widget build(BuildContext context)
  {
    final TextStyle eyebrow = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: AppTheme.trialMutedText,
    );
    final Color rule = ThemeColours.of(0xFFEDF2F1);

    return AppDialogStack(
      eyebrow: kPaymentEyebrow,
      title: '${widget.person.firstName} ${widget.person.lastName}',
      maxWidth: _settleWidth,
      footer: _footer(kSettleLabel, Icons.payments_outlined, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(kToSettleBlock.toUpperCase(), style: eyebrow),
              const SizedBox(height: 6),
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, thickness: 1, color: rule),
                  ),
                _item(i),
              ],
              const SizedBox(height: 6),
              Divider(height: 1, thickness: 1.5, color: rule),
              // The word under the items' titles, the sum under their amounts, on one baseline.
              Padding(
                padding: const EdgeInsets.fromLTRB(_wordsInset, 20, _tickInset, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text(kSettleTotal, style: _text(16.5, FontWeight.w800, AppTheme.trialOceanText))),
                    Text(formatAmount(_total), style: _text(18, FontWeight.w800, AppTheme.modifiedAccent)),
                  ],
                ),
              ),
              _PaymentFields(
                input: _payment,
                title: kPaymentBlock,
                onChanged: () => setState(() {}),
                beforeDate: _editable == null
                    ? null
                    : AppTextField(
                        controller: _rate,
                        label: kHourlyCostLabel,
                        hintText: tr('Es. 10,00', 'E.g. 10.00'),
                        keyboardType: TextInputType.number,
                        errorText: _rateError,
                        onChanged: (_) => setState(() => _rateError = null),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- hours paid ahead

// Lessons by the hour under an hourly tariff, online at the weekend under any; added to any still left,
// lessons draw on them before anything is due.
Future<StudentPaymentsItem?> showPayAheadDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
})
{
  return _show(context, 'Hours paid ahead', _PayAheadDialog(person: person, payments: payments));
}

typedef _MinutesField = QuarterMinutesField;

class _PayAheadDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;

  const _PayAheadDialog({required this.person, required this.payments});

  @override
  State<_PayAheadDialog> createState() => _PayAheadDialogState();
}

class _PayAheadDialogState extends State<_PayAheadDialog>
{
  late final StudentTariffItem _tariff = widget.payments.tariff!;
  final TextEditingController _hours = TextEditingController();
  late final _Conditions _rate = _Conditions(amount: formatAmount(_tariff.amountCents));
  late final TextEditingController _weekendRate = TextEditingController(
    text: _weekendCents == null ? '' : formatAmount(_weekendCents!),
  );
  final TextEditingController _total = TextEditingController();
  late final _PaymentInput _payment = _PaymentInput(widget.payments);

  // Online at the weekend: the only hours ahead outside an hourly tariff, and those left while a change waits.
  late bool _weekend = !_tariff.isHourly || _hourlyOff != null;

  int _minutes = 0;
  String? _hoursError;
  bool _saving = false;

  int? get _weekendCents => widget.payments.weekendOnlineCents;

  // A change waiting for the hours ahead to end: no more of them.
  String? get _hourlyOff => widget.payments.queued == QueuedPayment.change
      ? changeQueuedReason(widget.payments.queuedStartsOn, ahead: true)
      : null;

  String get _hourlyChoice => kWeekdaysChoice;

  @override
  void dispose()
  {
    _hours.dispose();
    _rate.dispose();
    _weekendRate.dispose();
    _total.dispose();
    _payment.dispose();
    super.dispose();
  }

  // Null while nothing is bought.
  int? get _bought
  {
    final String text = _hours.text.trim();
    final int? hours = text.isEmpty ? 0 : int.tryParse(text);

    if (hours == null)
    {
      return null;
    }

    final int total = hours * 60 + _minutes;

    return total > 0 ? total : null;
  }

  void _refresh()
  {
    final int? minutes = _bought;
    final int? cents = _weekend ? _weekendCents : parseAmountCents(_rate.amount.text);

    _total.text = minutes == null || cents == null || cents <= 0 ? '' : formatAmount((minutes * cents / 60).round());
  }

  void _choose(String? choice)
  {
    if (choice == null)
    {
      return;
    }

    setState(()
    {
      _weekend = choice != _hourlyChoice;
      _refresh();
    });
  }

  Future<void> _save() async
  {
    final int? weekendCents = _weekendCents;
    final (int, int?)? rate = _weekend ? (weekendCents == null ? null : (weekendCents, null)) : _rate.read(package: false);
    final Map<String, dynamic>? payment = _payment.read();
    final int? minutes = _bought;

    _hoursError = minutes != null ? null : (_hours.text.trim().isEmpty ? kRequiredField : kInvalidNumber);

    setState(() {});

    if (rate == null || payment == null || minutes == null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().payStudentHoursAhead(
        taxCode: widget.person.fiscalCode,
        minutes: minutes,
        centsPerHour: rate.$1,
        payment: payment,
        weekendOnline: _weekend,
      ),
    );

    if (!mounted)
    {
      return;
    }

    if (saved == null)
    {
      setState(() => _saving = false);

      return;
    }

    Navigator.of(context).pop(saved);
  }

  // An hourly tariff chooses which hours; the others pay online at the weekend alone.
  List<Widget> _kind()
  {
    final String? hourlyOff = _hourlyOff;

    if (!_tariff.isHourly)
    {
      return [PaymentFactBox(eyebrow: kAheadKindLabel, text: kWeekendColumn)];
    }

    return [
      _CurrentTariffBox(payments: widget.payments),
      const SizedBox(height: _gap),
      PersonChipGroupField(
        label: kAheadKindLabel,
        options: [_hourlyChoice, kWeekendColumn],
        struck: {_hourlyChoice: ?hourlyOff},
        value: _weekend ? kWeekendColumn : _hourlyChoice,
        onChanged: _choose,
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final AheadStatusItem? ahead = _weekend ? widget.payments.weekendAhead : widget.payments.ahead;
    final int unsettled = widget.payments.line(_weekend ? 'WEEKEND_ONLINE' : 'HOURLY')?.minutes ?? 0;

    return AppDialogStack(
      eyebrow: kPaymentEyebrow,
      title: kPayAheadTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kPayLabel, Icons.payments_outlined, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._kind(),
              if (ahead != null) _WhenBox(title: kAtAheadEnd, note: stillLeft(ahead.leftMinutes), later: true),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _hours,
                      label: kAheadHoursLabel,
                      hintText: kAheadHoursHint,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: _packageHoursDigits,
                      errorText: _hoursError,
                      onChanged: (_)
                      {
                        _hoursError = null;
                        setState(_refresh);
                      },
                    ),
                  ),
                  const SizedBox(width: _fieldGap),
                  Expanded(
                    child: _MinutesField(
                      value: _minutes,
                      onChanged: (minutes) => setState(()
                      {
                        _minutes = minutes;
                        _hoursError = null;
                        _refresh();
                      }),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Online at the weekend keeps its own rate.
                  Expanded(
                    child: _weekend
                        ? AppTextField(
                            controller: _weekendRate,
                            label: kHourlyCostLabel,
                            hintText: '',
                            enabled: false,
                          )
                        : AppTextField(
                            controller: _rate.amount,
                            label: kHourlyCostLabel,
                            hintText: tr('Es. 10,00', 'E.g. 10.00'),
                            keyboardType: TextInputType.number,
                            errorText: _rate.amountError,
                            onChanged: (_)
                            {
                              _rate.amountError = null;
                              setState(_refresh);
                            },
                          ),
                  ),
                  const SizedBox(width: _fieldGap),
                  Expanded(
                    child: AppTextField(
                      controller: _total,
                      label: kAmountLabel,
                      hintText: '',
                      enabled: false,
                    ),
                  ),
                ],
              ),
              if (unsettled > 0) _Note(kUnsettledTakenNow),
              _PaymentFields(input: _payment, title: kPaymentBlock, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}
