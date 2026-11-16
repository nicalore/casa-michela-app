import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart';
import '../../association/models/standard_tariffs_item.dart';
import '../../association/tabs/tariffs/tariffs_strings.dart' show tariffOffFor;
import '../edit/homework_tariffs.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../models/person_item.dart';
import '../models/student_payments_item.dart';
import '../tabs/person_account_shared.dart' show askPersonConfirmation;
import '../utils/payments_strings.dart';
import 'payment_dialog_parts.dart';

const double _dialogWidth = kPaymentDialogWidth;
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
    final Color accent = later ? AppTheme.laterBlue : AppTheme.trialTealDeep;
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
                    color: later ? AppTheme.laterBlue : AppTheme.trialOcean,
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
                      color: const Color(0xFF33495A),
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

// A whole line of hours paid by the hour; online at the weekend keeps its rate.
Future<StudentPaymentsItem?> showSettleDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  required HoursLineItem line,
})
{
  return _show(context, 'Settlement', _SettleDialog(person: person, payments: payments, line: line));
}

// An annual fee owed: its amount stands, only the day and the way are asked.
Future<StudentPaymentsItem?> showFeeSettleDialog({
  required BuildContext context,
  required PersonItem person,
  required StudentPaymentsItem payments,
  required PaymentHistoryRow row,
})
{
  return _show(context, 'Fee settlement', _FeeSettleDialog(person: person, payments: payments, row: row));
}

class _FeeSettleDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final PaymentHistoryRow row;

  const _FeeSettleDialog({required this.person, required this.payments, required this.row});

  @override
  State<_FeeSettleDialog> createState() => _FeeSettleDialogState();
}

class _FeeSettleDialogState extends State<_FeeSettleDialog>
{
  late final TextEditingController _amount = TextEditingController(text: formatAmount(widget.row.amountCents));
  late final _PaymentInput _payment = _PaymentInput(widget.payments);

  bool _saving = false;

  @override
  void dispose()
  {
    _amount.dispose();
    _payment.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    final Map<String, dynamic>? payment = _payment.read();
    final int? feeId = widget.row.feeId;

    setState(() {});

    if (payment == null || feeId == null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().settleMembershipFee(
        taxCode: widget.person.fiscalCode,
        feeId: feeId,
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
      eyebrow: kPaymentEyebrow,
      title: historyTitle(widget.row),
      maxWidth: _dialogWidth,
      footer: _footer(kSettleLabel, Icons.payments_outlined, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _amount,
                label: kAmountLabel,
                hintText: '',
                nothingAbove: true,
                enabled: false,
              ),
              const SizedBox(height: _fieldGap),
              _PaymentFields(input: _payment, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettleDialog extends StatefulWidget
{
  final PersonItem person;
  final StudentPaymentsItem payments;
  final HoursLineItem line;

  const _SettleDialog({required this.person, required this.payments, required this.line});

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog>
{
  late final _Conditions _rate = _Conditions(amount: formatAmount(widget.line.centsPerHour));
  late final TextEditingController _total = TextEditingController(text: formatAmount(widget.line.cents));
  late final _PaymentInput _payment = _PaymentInput(widget.payments);

  bool _saving = false;

  @override
  void dispose()
  {
    _rate.dispose();
    _total.dispose();
    _payment.dispose();
    super.dispose();
  }

  // The line's own sum while its rate stands, mixed rates included.
  void _onRate()
  {
    final int? cents = parseAmountCents(_rate.amount.text);
    final HoursLineItem line = widget.line;

    setState(()
    {
      _total.text = cents == null
          ? ''
          : formatAmount(cents == line.centsPerHour ? line.cents : (line.minutes * cents / 60).round());
    });
  }

  Future<void> _save() async
  {
    final (int, int?)? rate = _rate.read(package: false);
    final Map<String, dynamic>? payment = _payment.read();

    setState(() {});

    if (rate == null || payment == null)
    {
      return;
    }

    setState(() => _saving = true);

    final StudentPaymentsItem? saved = await _send(
      context,
      () => ApiService().settleStudentHours(
        taxCode: widget.person.fiscalCode,
        hoursKind: widget.line.kind,
        centsPerHour: rate.$1,
        payment: payment,
        expectedMinutes: widget.line.minutes,
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
    final HoursLineItem line = widget.line;

    return AppDialogStack(
      eyebrow: kPaymentEyebrow,
      title: kSettleTitle,
      maxWidth: _dialogWidth,
      footer: _footer(kSettleLabel, Icons.payments_outlined, _saving, _save),
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
                    child: AppTextField(
                      controller: _rate.amount,
                      label: kHourlyCostLabel,
                      hintText: 'Es. 10,00',
                      keyboardType: TextInputType.number,
                      nothingAbove: true,
                      enabled: !line.isWeekendOnline,
                      errorText: _rate.amountError,
                      onChanged: (_)
                      {
                        _rate.amountError = null;
                        _onRate();
                      },
                    ),
                  ),
                  const SizedBox(width: _fieldGap),
                  Expanded(
                    child: AppTextField(
                      controller: _total,
                      label: kAmountLabel,
                      hintText: '',
                      nothingAbove: true,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _fieldGap),
              _PaymentFields(input: _payment, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- hours paid ahead

// Hourly tariff only; added to any still left, lessons draw on them before anything is due.
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
  final TextEditingController _total = TextEditingController();
  late final _PaymentInput _payment = _PaymentInput(widget.payments);

  int _minutes = 0;
  String? _hoursError;
  bool _saving = false;

  @override
  void dispose()
  {
    _hours.dispose();
    _rate.dispose();
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
    final int? cents = parseAmountCents(_rate.amount.text);

    _total.text = minutes == null || cents == null || cents <= 0 ? '' : formatAmount((minutes * cents / 60).round());
  }

  Future<void> _save() async
  {
    final (int, int?)? rate = _rate.read(package: false);
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
    final AheadStatusItem? ahead = widget.payments.ahead;
    final int unsettled = widget.payments.line('HOURLY')?.minutes ?? 0;

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
              _CurrentTariffBox(payments: widget.payments),
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
                  Expanded(
                    child: AppTextField(
                      controller: _rate.amount,
                      label: kHourlyCostLabel,
                      hintText: 'Es. 10,00',
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
              if (unsettled > 0) const _Note(kUnsettledTakenNow),
              _PaymentFields(input: _payment, title: kPaymentBlock, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }
}
