import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/money.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_segmented_switch.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/dialog_components.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../models/standard_tariffs_item.dart';
import 'tariffs_strings.dart';

const double _dialogWidth = 600;
const double _amountWidth = 170;
const double _hoursWidth = 90;
const double _fieldGap = 12;
const double _blockPadding = 18;
const int _hoursDigits = 3;

Widget _footer(bool busy, VoidCallback onPressed)
{
  return AppDialogFooter.single(
    AppGradientButton(
      label: kSaveLabel,
      icon: Icons.check_rounded,
      height: 52,
      fontSize: 14,
      busy: busy,
      onPressed: onPressed,
    ),
  );
}

TextStyle _suffixStyle(bool on)
{
  return GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: on ? AppTheme.trialMutedText : AppTheme.trialMutedText.withValues(alpha: 0.5),
  );
}

Widget _amountField(TextEditingController controller, String label, {required bool on, double width = _amountWidth})
{
  return SizedBox(
    width: width,
    child: AppTextField(
      controller: controller,
      label: label,
      showLabel: false,
      hintText: on ? 'Es. 10,00' : '',
      keyboardType: TextInputType.number,
      enabled: on,
    ),
  );
}

String _amountText(int? cents) => cents == null ? '' : formatAmount(cents);

// ---------------------------------------------------------------- a level

Future<StandardTariffsItem?> showLevelTariffsDialog({required BuildContext context, required StandardTariffItem tariff})
{
  return showBlurredDialog<StandardTariffsItem>(
    context: context,
    barrierLabel: 'LevelTariffs',
    builder: (_) => _LevelDialog(tariff: tariff),
  );
}

class _LevelDialog extends StatefulWidget
{
  final StandardTariffItem tariff;

  const _LevelDialog({required this.tariff});

  @override
  State<_LevelDialog> createState() => _LevelDialogState();
}

class _LevelDialogState extends State<_LevelDialog>
{
  late final StandardTariffItem _start = widget.tariff;

  late bool _hourlyOn = _start.hourlyEnabled;
  late bool _packageOn = _start.packageEnabled;
  late bool _monthlyOn = _start.monthlyEnabled;

  late final TextEditingController _hourly = TextEditingController(text: _amountText(_start.hourlyCents));
  late final TextEditingController _package = TextEditingController(text: _amountText(_start.packageCents));
  late final TextEditingController _hours = TextEditingController(text: _start.packageHours?.toString() ?? '');
  late final TextEditingController _monthly = TextEditingController(text: _amountText(_start.monthlyCents));
  late final TextEditingController _weekend = TextEditingController(text: _amountText(_start.weekendOnlineCents));

  bool _saving = false;

  @override
  void dispose()
  {
    _hourly.dispose();
    _package.dispose();
    _hours.dispose();
    _monthly.dispose();
    _weekend.dispose();
    super.dispose();
  }

  static int? _cents(TextEditingController controller)
  {
    final int? cents = parseAmountCents(controller.text);

    return cents != null && cents > 0 ? cents : null;
  }

  int? get _packageHours
  {
    final int? hours = int.tryParse(_hours.text.trim());

    return hours != null && hours > 0 ? hours : null;
  }

  // Null, after a snackbar, when something is missing.
  StandardTariffItem? _read()
  {
    final int? hourly = _cents(_hourly);
    final int? package = _cents(_package);
    final int? hours = _packageHours;
    final int? monthly = _cents(_monthly);
    final int? weekend = _cents(_weekend);
    final bool packageWhole = package != null && hours != null;

    final String? refusal = !_hourlyOn && !_packageOn && !_monthlyOn
        ? kOneTariffOn
        : hourly == null
            ? kHourlyPriceMissing
            : _packageOn && !packageWhole
                ? kPackagePriceMissing
                : _monthlyOn && monthly == null
                    ? kMonthlyPriceMissing
                    : weekend == null
                        ? kWeekendPriceMissing
                        : null;

    if (refusal != null)
    {
      CustomSnackBar.show(context: context, message: refusal, isError: true);

      return null;
    }

    // A kind turned off keeps what was typed when it is valid, else what it had.
    return StandardTariffItem(
      level: _start.level,
      hourlyEnabled: _hourlyOn,
      hourlyCents: hourly!,
      packageEnabled: _packageOn,
      packageCents: packageWhole ? package : _start.packageCents,
      packageHours: packageWhole ? hours : _start.packageHours,
      monthlyEnabled: _monthlyOn,
      monthlyCents: monthly ?? (_monthlyOn ? null : _start.monthlyCents),
      weekendOnlineCents: weekend!,
    );
  }

  Future<void> _save() async
  {
    final StandardTariffItem? tariff = _read();

    if (tariff == null)
    {
      return;
    }

    setState(() => _saving = true);

    try
    {
      final StandardTariffsItem saved = await ApiService().updateStandardTariff(tariff);

      if (mounted)
      {
        Navigator.of(context).pop(saved);
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _saving = false);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  Widget _block({
    required String title,
    required bool on,
    ValueChanged<bool>? onToggle,
    required List<Widget> fields,
    bool first = false,
    String? note,
  })
  {
    return Container(
      padding: EdgeInsets.only(top: first ? 4 : _blockPadding, bottom: _blockPadding),
      decoration: first
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: AppTheme.trialLine))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: on ? AppTheme.trialOceanText : AppTheme.trialMutedText.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (onToggle != null)
                AppSegmentedSwitch(
                  value: on,
                  trueLabel: kTariffOn,
                  falseLabel: kTariffOffChoice,
                  hugContent: true,
                  onChanged: onToggle,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: _fieldGap,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: fields,
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.info_outline_rounded, size: 17, color: AppTheme.trialTurquoise),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kTariffsEyebrow,
      title: kTariffLevelLabels[_start.level] ?? _start.level,
      maxWidth: _dialogWidth,
      footer: _footer(_saving, _save),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _block(
                title: kHourlyColumn,
                on: _hourlyOn,
                first: true,
                onToggle: (on) => setState(() => _hourlyOn = on),
                // Hours over a package or a fee are paid at it even while the tariff is off.
                fields: [
                  _amountField(_hourly, kHourlyColumn, on: true),
                  Text(kPerHourSuffix, style: _suffixStyle(true)),
                ],
                note: kHourlyRateNote,
              ),
              _block(
                title: kPackageColumn,
                on: _packageOn,
                onToggle: (on) => setState(() => _packageOn = on),
                fields: [
                  _amountField(_package, kPackageColumn, on: _packageOn),
                  Text(kPackagePerSuffix, style: _suffixStyle(_packageOn)),
                  SizedBox(
                    width: _hoursWidth,
                    child: AppTextField(
                      controller: _hours,
                      label: kPackageHoursSuffix,
                      showLabel: false,
                      hintText: _packageOn ? 'Es. 18' : '',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_hoursDigits),
                      ],
                      enabled: _packageOn,
                    ),
                  ),
                  Text(kPackageHoursSuffix, style: _suffixStyle(_packageOn)),
                ],
              ),
              _block(
                title: kMonthlyColumn,
                on: _monthlyOn,
                onToggle: (on) => setState(() => _monthlyOn = on),
                fields: [
                  _amountField(_monthly, kMonthlyColumn, on: _monthlyOn),
                  Text(kPerMonthSuffix, style: _suffixStyle(_monthlyOn)),
                ],
              ),
              _block(
                title: kWeekendColumn,
                on: true,
                fields: [
                  _amountField(_weekend, kWeekendColumn, on: true),
                  Text(kPerHourSuffix, style: _suffixStyle(true)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- a fee

enum AnnualFee { membership, insurance }

Future<StandardTariffsItem?> showAnnualFeeDialog({
  required BuildContext context,
  required AnnualFeesItem fees,
  required AnnualFee fee,
})
{
  return showBlurredDialog<StandardTariffsItem>(
    context: context,
    barrierLabel: 'AnnualFee',
    builder: (_) => _FeeDialog(fees: fees, fee: fee),
  );
}

class _FeeDialog extends StatefulWidget
{
  final AnnualFeesItem fees;
  final AnnualFee fee;

  const _FeeDialog({required this.fees, required this.fee});

  @override
  State<_FeeDialog> createState() => _FeeDialogState();
}

class _FeeDialogState extends State<_FeeDialog>
{
  bool get _membership => widget.fee == AnnualFee.membership;

  late final TextEditingController _amount = TextEditingController(
    text: formatAmount(_membership ? widget.fees.membershipCents : widget.fees.insuranceCents),
  );

  bool _saving = false;

  @override
  void dispose()
  {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async
  {
    final int? cents = parseAmountCents(_amount.text);

    if (cents == null || cents <= 0)
    {
      CustomSnackBar.show(context: context, message: kFeePriceMissing, isError: true);

      return;
    }

    setState(() => _saving = true);

    final AnnualFeesItem fees = AnnualFeesItem(
      membershipCents: _membership ? cents : widget.fees.membershipCents,
      insuranceCents: _membership ? widget.fees.insuranceCents : cents,
    );

    try
    {
      final StandardTariffsItem saved = await ApiService().updateAnnualFees(fees);

      if (mounted)
      {
        Navigator.of(context).pop(saved);
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _saving = false);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kAnnualFeesEyebrow,
      title: _membership ? kMembershipFee : kInsuranceFee,
      maxWidth: _dialogWidth,
      footer: _footer(_saving, _save),
      children: [
        AppDialogPill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 260,
              child: AppTextField(
                controller: _amount,
                label: kFeeFieldLabel,
                hintText: 'Es. 15,00',
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _save(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
