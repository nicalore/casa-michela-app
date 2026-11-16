import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/error_message.dart';
import '../../../core/utils/money.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/opening_hours/hours_date_field.dart' show formatDateString;
import '../../association/tabs/tariffs/tariffs_strings.dart' show tariffOffFor;
import '../../people/edit/homework_tariffs.dart';
import '../../people/edit/person_edit_form.dart' show kCollaborationChoices, kCollaborationTypes;
import '../../people/edit/widgets/person_chip_group_field.dart';
import '../../people/utils/payments_strings.dart'
    show currentTariff, feePaymentBlock, kAheadHoursHint, kAheadHoursLabel, kInvalidAmountMessage, kInvalidNumber,
        kPackagePaymentBlock, kPaymentBlock, kRequiredField;
import '../../people/widgets/payment_dialog_parts.dart';
import '../models/opening_items.dart';
import '../utils/opening_strings.dart';

const double _gap = kPaymentDialogGap;
const double _fieldGap = kPaymentFieldGap;

String? _labelOf(Map<String, String> choices, String? server)
{
  return choices.entries.where((entry) => entry.value == server).map((entry) => entry.key).firstOrNull;
}

int _halfUpCents(int minutes, int centsPerHour) => (minutes * centsPerHour * 2 + 60) ~/ 120;

Future<T?> _send<T>(BuildContext context, Future<T> Function() write) async
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

// Hours and quarter hours, as lessons are booked.
class _HoursInput
{
  final TextEditingController hours;
  int minutes;
  String? error;

  _HoursInput([int total = 0])
      : hours = TextEditingController(text: total == 0 ? '' : '${total ~/ 60}'),
        minutes = total % 60;

  // Null with the error set; [empty] is what an untouched pair means.
  int? read({bool zero = false})
  {
    final String text = hours.text.trim();
    final int? whole = text.isEmpty ? 0 : int.tryParse(text);

    if (whole == null)
    {
      error = kInvalidNumber;

      return null;
    }

    final int total = whole * 60 + minutes;

    if (total == 0 && !zero)
    {
      error = kRequiredField;

      return null;
    }

    error = null;

    return total;
  }

  int get shown
  {
    final int? whole = int.tryParse(hours.text.trim());

    return (whole ?? 0) * 60 + minutes;
  }

  void dispose() => hours.dispose();
}

class _HoursFields extends StatelessWidget
{
  final _HoursInput input;
  final String? label;
  final VoidCallback onChanged;

  const _HoursFields({required this.input, this.label, required this.onChanged});

  @override
  Widget build(BuildContext context)
  {
    final String? label = this.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          const SizedBox(height: _gap),
          AppFieldLabel(label),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: input.hours,
                label: kAheadHoursLabel,
                hintText: kAheadHoursHint,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: kPackageHoursDigits,
                errorText: input.error,
                onChanged: (_)
                {
                  input.error = null;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: _fieldGap),
            Expanded(
              child: QuarterMinutesField(
                value: input.minutes,
                onChanged: (minutes)
                {
                  input.minutes = minutes;
                  input.error = null;
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// A label over a switch of its own, as the windows ask a choice.
class _Choice extends StatelessWidget
{
  final String label;
  final Widget child;

  const _Choice({required this.label, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: _fieldGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFieldLabel(label),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- teachers

Future<OpeningTeacher?> showTeacherOpeningDialog({
  required BuildContext context,
  required OpeningTeacher teacher,
  required DateTime lastDay,
})
{
  return showBlurredDialog<OpeningTeacher>(
    context: context,
    barrierLabel: 'Teacher opening',
    builder: (_) => _TeacherDialog(teacher: teacher, lastDay: lastDay),
  );
}

class _TeacherDialog extends StatefulWidget
{
  final OpeningTeacher teacher;
  final DateTime lastDay;

  const _TeacherDialog({required this.teacher, required this.lastDay});

  @override
  State<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<_TeacherDialog>
{
  late String? _collaboration = _labelOf(kCollaborationTypes, widget.teacher.collaborationType);
  late final TextEditingController _rate = TextEditingController(text: _text(widget.teacher.grossRateCents));
  late final TextEditingController _gross = TextEditingController(text: _text(widget.teacher.grossCents));
  final TextEditingController _netRate = TextEditingController();
  final TextEditingController _net = TextEditingController();

  String? _rateError;
  String? _grossError;
  String? _collaborationError;
  bool _saving = false;

  static String _text(int? cents) => cents == null ? '' : formatAmount(cents);

  bool get _paid => kCollaborationTypes[_collaboration] == 'PAID';

  @override
  void initState()
  {
    super.initState();
    _refresh();
  }

  @override
  void dispose()
  {
    _rate.dispose();
    _gross.dispose();
    _netRate.dispose();
    _net.dispose();
    super.dispose();
  }

  void _refresh()
  {
    final int? rate = parseAmountCents(_rate.text);
    final int? gross = parseAmountCents(_gross.text);

    _netRate.text = rate == null ? '' : formatAmount(netOfCents(rate));
    _net.text = gross == null ? '' : formatAmount(netOfCents(gross));
  }

  String? _amountError(TextEditingController controller)
  {
    final String text = controller.text.trim();

    if (text.isEmpty)
    {
      return kRequiredField;
    }

    final int? cents = parseAmountCents(text);

    return cents == null || cents < 0 ? kInvalidAmountMessage : null;
  }

  String? get _onFile
  {
    final OpeningTeacher teacher = widget.teacher;

    if (teacher.missing)
    {
      return null;
    }

    final int? rate = teacher.grossRateCents;

    return teacher.isPaid && rate != null ? paidOnFile(rate) : _labelOf(kCollaborationTypes, teacher.collaborationType);
  }

  Future<void> _save() async
  {
    final bool editable = widget.teacher.canEdit;

    _collaborationError = editable && _collaboration == null ? kRequiredField : null;
    _rateError = editable && _paid ? _amountError(_rate) : null;
    _grossError = editable && _paid ? _amountError(_gross) : null;

    setState(() {});

    if (_collaborationError != null || _rateError != null || _grossError != null)
    {
      return;
    }

    setState(() => _saving = true);

    final OpeningTeacher? saved = await _send(
      context,
      () => ApiService().confirmOpeningTeacher(widget.teacher.taxCode, {
        'collaboration_type': editable ? kCollaborationTypes[_collaboration] : widget.teacher.collaborationType,
        'gross_compensation': editable && _paid ? amountPayloadOf(_rate.text) : null,
        'gross': editable && _paid ? amountPayloadOf(_gross.text) : null,
      }),
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

  List<Widget> _paidFields()
  {
    return [
      const SizedBox(height: _fieldGap),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: _rate,
              label: kGrossRateLabel,
              hintText: 'Es. 15,00',
              keyboardType: TextInputType.number,
              errorText: _rateError,
              onChanged: (_)
              {
                _rateError = null;
                setState(_refresh);
              },
            ),
          ),
          const SizedBox(width: _fieldGap),
          Expanded(child: AppTextField(controller: _netRate, label: kNetRateLabel, hintText: '', enabled: false)),
        ],
      ),
      PaymentBlockTitle(beforeAccounts(widget.lastDay)),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: _gross,
              label: kGrossLabel,
              hintText: 'Es. 120,00',
              keyboardType: TextInputType.number,
              errorText: _grossError,
              onChanged: (_)
              {
                _grossError = null;
                setState(_refresh);
              },
            ),
          ),
          const SizedBox(width: _fieldGap),
          Expanded(child: AppTextField(controller: _net, label: kNetLabel, hintText: '', enabled: false)),
        ],
      ),
      PaymentNote(teacherAfterNote(widget.lastDay)),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final String? onFile = _onFile;
    final bool editable = widget.teacher.canEdit;

    return AppDialogStack(
      eyebrow: kOpeningEyebrow,
      title: widget.teacher.fullName,
      maxWidth: kPaymentDialogWidth,
      footer: paymentDialogFooter(kConfirmLabel, Icons.check_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onFile != null) ...[
                PaymentFactBox(eyebrow: kPayOnFile, text: onFile),
                const SizedBox(height: _gap),
              ],
              if (editable)
                PersonChipGroupField(
                  label: kCollaborationLabel,
                  options: kCollaborationChoices,
                  value: _collaboration,
                  errorText: _collaborationError,
                  onChanged: (value) => setState(()
                  {
                    _collaboration = value;
                    _collaborationError = null;
                  }),
                ),
              if (editable && _paid) ..._paidFields() else const PaymentNote(kNothingToPay),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- pupils

Future<OpeningPupil?> showPupilOpeningDialog({
  required BuildContext context,
  required OpeningPupil pupil,
  required DateTime lastDay,
})
{
  return showBlurredDialog<OpeningPupil>(
    context: context,
    barrierLabel: 'Pupil opening',
    builder: (_) => _PupilDialog(pupil: pupil, lastDay: lastDay),
  );
}

class _PupilDialog extends StatefulWidget
{
  final OpeningPupil pupil;
  final DateTime lastDay;

  const _PupilDialog({required this.pupil, required this.lastDay});

  @override
  State<_PupilDialog> createState() => _PupilDialogState();
}

enum _HoursState { none, due, ahead }

class _PupilDialogState extends State<_PupilDialog>
{
  late String? _kind = widget.pupil.tariff?.kind;
  late final TariffConditions _conditions = TariffConditions(
    hours: widget.pupil.tariff?.packageHours?.toString() ?? '',
    amount: widget.pupil.tariff == null ? '' : formatAmount(widget.pupil.tariff!.amountCents),
  );

  late bool _paid = !widget.pupil.confirmed || widget.pupil.payment != null;
  late final PaymentInput _payment = PaymentInput(
    method: widget.pupil.payment?.method,
    otherMethod: widget.pupil.payment?.methodOther,
    date: widget.pupil.payment == null ? '' : formatDateString(widget.pupil.payment!.paidOn),
    latest: widget.lastDay,
  );

  late bool _ended = widget.pupil.packageEnded;
  late final _HoursInput _left = _HoursInput(widget.pupil.packageEnded ? 0 : widget.pupil.leftMinutes);
  late final _HoursInput _over = _HoursInput(widget.pupil.packageEnded ? widget.pupil.dueMinutes : 0);

  late _HoursState _hours = widget.pupil.ahead != null
      ? _HoursState.ahead
      : (widget.pupil.dueMinutes > 0 && widget.pupil.tariff?.kind == 'HOURLY' ? _HoursState.due : _HoursState.none);
  late final _HoursInput _due = _HoursInput(widget.pupil.tariff?.kind == 'HOURLY' ? widget.pupil.dueMinutes : 0);
  late final _HoursInput _ahead = _HoursInput(widget.pupil.ahead?.minutes ?? 0);
  late final TextEditingController _aheadRate = TextEditingController(
    text: widget.pupil.ahead == null ? '' : formatAmount(widget.pupil.ahead!.centsPerHour),
  );
  late final PaymentInput _aheadPayment = PaymentInput(
    method: widget.pupil.ahead?.payment.method,
    otherMethod: widget.pupil.ahead?.payment.methodOther,
    date: widget.pupil.ahead == null ? '' : formatDateString(widget.pupil.ahead!.payment.paidOn),
    latest: widget.lastDay,
  );
  String? _aheadRateError;

  late bool _weekend = widget.pupil.weekendMinutes > 0;
  late final _HoursInput _weekendHours = _HoursInput(widget.pupil.weekendMinutes);

  String? _kindError;
  bool _saving = false;

  @override
  void dispose()
  {
    _conditions.dispose();
    _payment.dispose();
    _left.dispose();
    _over.dispose();
    _due.dispose();
    _ahead.dispose();
    _aheadRate.dispose();
    _aheadPayment.dispose();
    _weekendHours.dispose();
    super.dispose();
  }

  bool get _package => _kind == 'PACKAGE';
  bool get _hourly => _kind == 'HOURLY';
  bool get _monthly => _kind == 'MONTHLY';

  // Kinds turned off for the level, but the one the pupil already has.
  Map<String, String> get _struck
  {
    return {
      for (final String option in kTariffChoices)
        if (!widget.pupil.enabledKinds.contains(kTariffKinds[option]) && widget.pupil.tariff?.kind != kTariffKinds[option])
          option: tariffOffFor(widget.pupil.schoolLevel),
    };
  }

  void _choose(String? choice)
  {
    final String? kind = kTariffKinds[choice];
    final OpeningTariff? onFile = widget.pupil.tariff;
    final LevelStandard? standard = widget.pupil.standard;

    setState(()
    {
      _kind = kind;
      _kindError = null;
      _conditions.amountError = null;
      _conditions.hoursError = null;

      if (onFile != null && onFile.kind == kind)
      {
        _conditions.amount.text = formatAmount(onFile.amountCents);
        _conditions.hours.text = onFile.packageHours?.toString() ?? '';

        return;
      }

      final int? cents = switch (kind)
      {
        'HOURLY' => standard?.hourlyCents,
        'PACKAGE' => standard?.packageCents,
        'MONTHLY' => standard?.monthlyCents,
        _ => null,
      };

      _conditions.amount.text = cents == null ? '' : formatAmount(cents);
      _conditions.hours.text = kind == 'PACKAGE' ? standard?.packageHours?.toString() ?? '' : '';
    });
  }

  int? get _packageHours => int.tryParse(_conditions.hours.text.trim());

  int? get _hourlyCents => parseAmountCents(_conditions.amount.text);

  Map<String, dynamic>? _payload()
  {
    if (_kind == null)
    {
      _kindError = kRequiredField;

      return null;
    }

    final (int, int?)? conditions = _conditions.read(package: _package);
    final Map<String, dynamic>? payment = (_package || _monthly) && _paid ? _payment.read() : null;
    bool valid = conditions != null && (!(_package || _monthly) || !_paid || payment != null);

    int left = 0;
    int due = 0;
    Map<String, dynamic>? ahead;

    if (_package)
    {
      if (_ended)
      {
        due = _over.read(zero: true) ?? -1;
      }
      else
      {
        left = _left.read(zero: true) ?? -1;
        final int? hours = conditions?.$2;

        if (hours != null && left > hours * 60)
        {
          _left.error = kInvalidNumber;
          left = -1;
        }
      }
    }

    if (_hourly && _hours == _HoursState.due)
    {
      due = _due.read() ?? -1;
    }

    if (_hourly && _hours == _HoursState.ahead)
    {
      final int? minutes = _ahead.read();
      final int? rate = parseAmountCents(_aheadRate.text);
      final Map<String, dynamic>? paid = _aheadPayment.read();

      _aheadRateError = _aheadRate.text.trim().isEmpty
          ? kRequiredField
          : (rate == null || rate <= 0 ? kInvalidAmountMessage : null);

      if (minutes == null || _aheadRateError != null || paid == null)
      {
        valid = false;
      }
      else
      {
        ahead = {'minutes': minutes, 'cents_per_hour': rate, 'payment': paid};
      }
    }

    final int weekend = _weekend ? (_weekendHours.read() ?? -1) : 0;

    if (!valid || left < 0 || due < 0 || weekend < 0 || conditions == null)
    {
      return null;
    }

    return {
      'kind': _kind,
      'amount_cents': conditions.$1,
      'package_hours': conditions.$2,
      'payment': payment,
      'package_ended': _package && _ended,
      'left_minutes': left,
      'due_minutes': due,
      'ahead': ahead,
      'weekend_minutes': weekend,
    };
  }

  Future<void> _save() async
  {
    final Map<String, dynamic>? payload = _payload();

    setState(() {});

    if (payload == null)
    {
      return;
    }

    setState(() => _saving = true);

    final OpeningPupil? saved = await _send(
      context,
      () => ApiService().confirmOpeningPupil(widget.pupil.taxCode, payload),
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

  void _changed() => setState(() {});

  List<Widget> _paymentBlock()
  {
    final String title = _package ? kPackagePaymentBlock : feePaymentBlock(widget.lastDay);

    return [
      PaymentBlockTitle(kPaymentBlock),
      _Choice(
        label: title,
        child: AppSegmentedSwitch(
          value: _paid,
          trueLabel: _package ? kPaidChoice : kPaidFeminineChoice,
          falseLabel: _package ? kUnpaidChoice : kUnpaidFeminineChoice,
          hugContent: true,
          onChanged: (value) => setState(() => _paid = value),
        ),
      ),
      if (_paid) ...[
        const SizedBox(height: _fieldGap),
        PaymentFields(input: _payment, onChanged: _changed),
      ],
    ];
  }

  List<Widget> _packageState()
  {
    final int? hours = _packageHours;
    final int leftShown = _left.shown;
    final int overCents = _halfUpCents(_over.shown, widget.pupil.settleCents);

    return [
      _Choice(
        label: kPackageState,
        child: AppSegmentedSwitch(
          value: !_ended,
          trueLabel: kHoursLeftChoice,
          falseLabel: kPackageEndedChoice,
          hugContent: true,
          onChanged: (value) => setState(() => _ended = !value),
        ),
      ),
      if (!_ended) ...[
        _HoursFields(input: _left, onChanged: _changed),
        if (hours != null && hours > 0 && leftShown <= hours * 60)
          PaymentNote(usedOf(hours * 60 - leftShown, hours)),
      ]
      else ...[
        _HoursFields(input: _over, label: kOverPackageLabel, onChanged: _changed),
        if (_over.shown > 0) PaymentNote(toSettleAt(overCents, widget.pupil.settleCents)),
      ],
    ];
  }

  List<Widget> _hourlyState()
  {
    final int? rate = _hourlyCents;
    final int? aheadRate = parseAmountCents(_aheadRate.text);

    return [
      _Choice(
        label: kHoursState,
        child: AppSegmentedTabs(
          labels: const [kNoHoursChoice, kDueChoice, kAheadChoice],
          selectedIndex: _hours.index,
          onSelected: (index) => setState(() => _hours = _HoursState.values[index]),
          padding: EdgeInsets.zero,
          hugContent: true,
        ),
      ),
      if (_hours == _HoursState.due) ...[
        _HoursFields(input: _due, onChanged: _changed),
        if (rate != null && _due.shown > 0) PaymentNote(toSettle(_halfUpCents(_due.shown, rate))),
      ],
      if (_hours == _HoursState.ahead) ...[
        _HoursFields(input: _ahead, label: kAheadLeftLabel, onChanged: _changed),
        const SizedBox(height: _fieldGap),
        AppTextField(
          controller: _aheadRate,
          label: kAheadRateLabel,
          hintText: 'Es. 13,00',
          keyboardType: TextInputType.number,
          errorText: _aheadRateError,
          onChanged: (_)
          {
            _aheadRateError = null;
            _changed();
          },
        ),
        if (aheadRate != null && _ahead.shown > 0) PaymentNote(alreadyPaid(_halfUpCents(_ahead.shown, aheadRate))),
        const SizedBox(height: _fieldGap),
        PaymentFields(input: _aheadPayment, onChanged: _changed),
      ],
    ];
  }

  List<Widget> _weekendState()
  {
    final int rate = widget.pupil.weekendOnlineCents;

    return [
      _Choice(
        label: kWeekendDueLabel,
        child: AppSegmentedSwitch(
          value: _weekend,
          trueLabel: kYesChoice,
          falseLabel: kNoChoice,
          hugContent: true,
          onChanged: (value) => setState(() => _weekend = value),
        ),
      ),
      if (_weekend) ...[
        _HoursFields(input: _weekendHours, onChanged: _changed),
        if (_weekendHours.shown > 0) PaymentNote(toSettleAt(_halfUpCents(_weekendHours.shown, rate), rate)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final OpeningTariff? onFile = widget.pupil.tariff;
    final String? kind = _kind;

    return AppDialogStack(
      eyebrow: kOpeningEyebrow,
      title: widget.pupil.fullName,
      maxWidth: kPaymentDialogWidth,
      footer: paymentDialogFooter(kConfirmLabel, Icons.check_rounded, _saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onFile != null) ...[
                PaymentFactBox(
                  eyebrow: kTariffOnFile,
                  text: currentTariff(onFile.kind, onFile.amountCents, onFile.packageHours),
                ),
                const SizedBox(height: _gap),
              ],
              PersonChipGroupField(
                label: tariffInUse(widget.lastDay),
                options: kTariffChoices,
                struck: _struck,
                value: _labelOf(kTariffKinds, kind),
                errorText: _kindError,
                onChanged: _choose,
              ),
              if (kind != null) ...[
                const SizedBox(height: 4),
                TariffConditionFields(conditions: _conditions, kind: kind, onChanged: _changed),
                if (_package || _monthly) ..._paymentBlock(),
                PaymentBlockTitle(atLastDay(widget.lastDay)),
                if (_package) ..._packageState(),
                if (_hourly) ..._hourlyState(),
                ..._weekendState(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
