import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/json_parsing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/date_input_formatters.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart' show kAssociationFoundedOn;
import '../../association/tabs/opening_hours/hours_date_field.dart';
import '../edit/homework_tariffs.dart';
import '../edit/widgets/person_chip_group_field.dart';
import '../utils/payments_strings.dart';

const double kPaymentDialogWidth = 600;
const double kPaymentDialogGap = 18;
const double kPaymentBlockGap = 24;
const double kPaymentFieldGap = 16;
const double kPaymentBoxRadius = 18;
const int kPackageHoursDigits = 3;

DateTime paymentToday()
{
  final DateTime now = romeNow();

  return DateTime(now.year, now.month, now.day);
}

Map<String, String> get kPaymentMethodNames => {
  'CASH': kCashChoice,
  'BANK_TRANSFER': kBankTransferChoice,
  'OTHER': kOtherChoice,
};

// No payment is older than the association: the server refuses it, and a mistyped year lands before it.
final DateTime _firstPaymentDay = DateTime(kAssociationFoundedOn.year);

// The date and the way of a payment, as every window that takes money asks them.
class PaymentInput
{
  final TextEditingController date;
  final TextEditingController other = TextEditingController();
  String? method;

  // The last day a payment may carry: today, unless the window says otherwise.
  final DateTime? latest;

  String? dateError;
  String? methodError;
  String? otherError;

  PaymentInput({String? method, String? otherMethod, String? date, this.latest})
      : date = TextEditingController(text: date ?? formatDateString(paymentToday()))
  {
    this.method = kPaymentMethodNames[method];
    other.text = method == 'OTHER' ? otherMethod ?? '' : '';
  }

  // Null, with the errors set, when something is missing.
  Map<String, dynamic>? read()
  {
    final String text = date.text.trim();
    final String? server = kPaymentMethodNames.entries
        .where((entry) => entry.value == method)
        .map((entry) => entry.key)
        .firstOrNull;
    final DateTime? day = isValidDateString(text) ? parseDateString(text) : null;
    final DateTime last = latest ?? paymentToday();
    final bool valid = day != null && !day.isAfter(last) && !day.isBefore(_firstPaymentDay);

    dateError = text.isEmpty ? kRequiredField : (valid ? null : kInvalidDate);
    methodError = server == null ? kRequiredField : null;
    otherError = server == 'OTHER' && other.text.trim().isEmpty ? kRequiredField : null;

    if (dateError != null || methodError != null || otherError != null)
    {
      return null;
    }

    return {
      'paid_on': formatDateOnly(parseDateString(text)),
      'payment_method': server,
      'payment_method_other': server == 'OTHER' ? other.text.trim() : null,
    };
  }

  void dispose()
  {
    date.dispose();
    other.dispose();
  }
}

TextStyle paymentNoteStyle()
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppTheme.trialMutedText,
  );
}

class PaymentNote extends StatelessWidget
{
  final String text;

  const PaymentNote(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text, style: paymentNoteStyle()),
    );
  }
}

class PaymentBlockTitle extends StatelessWidget
{
  final String text;

  const PaymentBlockTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: kPaymentBlockGap),
        Divider(height: 1, thickness: 1, color: ThemeColours.of(0xFFEDF2F1)),
        const SizedBox(height: kPaymentDialogGap),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }
}

// An eyebrow over one line, on the quiet surface: «TARIFFA ATTUALE» over the kind and its cost.
class PaymentFactBox extends StatelessWidget
{
  final String eyebrow;
  final String text;

  const PaymentFactBox({super.key, required this.eyebrow, required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(color: AppTheme.quietSurface, borderRadius: BorderRadius.circular(kPaymentBoxRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialOceanText,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentFields extends StatelessWidget
{
  final PaymentInput input;
  final String? title;
  final VoidCallback onChanged;

  const PaymentFields({super.key, required this.input, this.title, required this.onChanged});

  @override
  Widget build(BuildContext context)
  {
    final String? title = this.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) PaymentBlockTitle(title),
        AppTextField(
          controller: input.date,
          label: kPaidOnLabel,
          hintText: kDateHint,
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          errorText: input.dateError,
          onChanged: (_)
          {
            input.dateError = null;
            onChanged();
          },
        ),
        const SizedBox(height: kPaymentFieldGap),
        PersonChipGroupField(
          label: kPaymentMethodLabel,
          options: kPaymentMethodChoices,
          value: input.method,
          errorText: input.methodError,
          onChanged: (value)
          {
            input.method = value;
            input.methodError = null;
            onChanged();
          },
        ),
        if (input.method == kOtherChoice)
          AppTextField(
            controller: input.other,
            label: kOtherMethodLabel,
            hintText: kOtherMethodHint,
            maxLength: 255,
            errorText: input.otherError,
            onChanged: (_)
            {
              input.otherError = null;
              onChanged();
            },
          ),
      ],
    );
  }
}

// The fields of a package or a fee; one of the two is null.
class TariffConditions
{
  final TextEditingController hours;
  final TextEditingController amount;

  String? hoursError;
  String? amountError;

  TariffConditions({String hours = '', String amount = ''})
      : hours = TextEditingController(text: hours),
        amount = TextEditingController(text: amount);

  // Null with the errors set when not valid.
  (int, int?)? read({required bool package})
  {
    final int? cents = parseAmountCents(amount.text);
    final int? count = int.tryParse(hours.text.trim());

    amountError = amount.text.trim().isEmpty
        ? kRequiredField
        : (cents == null || cents <= 0 ? kInvalidAmountMessage : null);
    hoursError = !package
        ? null
        : (hours.text.trim().isEmpty ? kRequiredField : (count == null || count <= 0 ? kInvalidNumber : null));

    if (amountError != null || hoursError != null)
    {
      return null;
    }

    return (cents!, package ? count : null);
  }

  void dispose()
  {
    hours.dispose();
    amount.dispose();
  }
}

class TariffConditionFields extends StatelessWidget
{
  final TariffConditions conditions;
  final String kind;
  final VoidCallback onChanged;

  const TariffConditionFields({super.key, required this.conditions, required this.kind, required this.onChanged});

  Widget _amount(String label)
  {
    return AppTextField(
      controller: conditions.amount,
      label: label,
      hintText: tr('Es. 10,00', 'E.g. 10.00'),
      keyboardType: TextInputType.number,
      errorText: conditions.amountError,
      onChanged: (_)
      {
        conditions.amountError = null;
        onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (kind == 'HOURLY')
    {
      return _amount(kHourlyCostLabel);
    }

    if (kind == 'MONTHLY')
    {
      return _amount(kMonthlyCostLabel);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: conditions.hours,
            label: kPackageHoursLabel,
            hintText: tr('Es. 18', 'E.g. 18'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: kPackageHoursDigits,
            errorText: conditions.hoursError,
            onChanged: (_)
            {
              conditions.hoursError = null;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: kPaymentFieldGap),
        Expanded(child: _amount(kPackageCostLabel)),
      ],
    );
  }
}

Widget paymentDialogFooter(String label, IconData icon, bool busy, VoidCallback onPressed)
{
  return AppDialogFooter.single(
    AppGradientButton(
      label: label,
      icon: icon,
      height: 52,
      fontSize: 14,
      busy: busy,
      onPressed: onPressed,
    ),
  );
}

// «Minuti» beside «Ore», as tall as a text field: an invisible twin field sets the height, since
// the web lays a field out shorter than AppTextField.boxHeight says.
class QuarterMinutesField extends StatefulWidget
{
  final int value;
  final ValueChanged<int> onChanged;

  const QuarterMinutesField({super.key, required this.value, required this.onChanged});

  @override
  State<QuarterMinutesField> createState() => _QuarterMinutesFieldState();
}

class _QuarterMinutesFieldState extends State<QuarterMinutesField>
{
  final TextEditingController _twin = TextEditingController();

  @override
  void dispose()
  {
    _twin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: AppTextField.labelTopGapOf(context),
            bottom: AppTextField.labelBottomGapOf(context),
          ),
          child: AppFieldLabel(kAheadMinutesLabel),
        ),
        Stack(
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0,
                  child: AppTextField(controller: _twin, label: '', hintText: '', showLabel: false, enabled: false),
                ),
              ),
            ),
            Positioned.fill(
              child: AppDropdownField<int>(
                hint: '${widget.value}',
                value: widget.value,
                options: [
                  for (final int minutes in kAheadMinuteChoices) AppDropdownOption(value: minutes, label: '$minutes'),
                ],
                onChanged: (minutes) => widget.onChanged(minutes ?? 0),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
