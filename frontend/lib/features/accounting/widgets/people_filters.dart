import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/accounting_strings.dart';

// Filters the accounting lists of people share: «Pagamenti» and «Da saldare».

const double kFilterGap = 10;

const double _roleMenuWidth = 220;
const double _amountDialogWidth = 520;

// One role at a time; a person with several shows under each.
class RoleFilterPill extends StatelessWidget
{
  final String? value;
  final ValueChanged<String?> onPicked;

  const RoleFilterPill({super.key, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context)
  {
    return AppFilterPill<String>.filter(
      prefix: kRoleFilterPrefix,
      hint: kAllRolesHint,
      icon: Icons.badge_outlined,
      value: value,
      menuWidth: _roleMenuWidth,
      onChanged: onPicked,
      onClear: () => onPicked(null),
      options: [
        for (final MapEntry(key: role, value: label) in kPaymentRoleFilters.entries)
          FilterOption(value: role, label: label),
      ],
    );
  }
}

// «Importo», set in its window as the subjects' filters are; both bounds included.
class AmountFilterPill extends StatelessWidget
{
  final int? least;
  final int? most;
  final void Function(int? least, int? most) onApply;

  const AmountFilterPill({super.key, required this.least, required this.most, required this.onApply});

  @override
  Widget build(BuildContext context)
  {
    return AppCountFilterPill.value(
      label: kAmountFilterPrefix,
      icon: Icons.euro_rounded,
      value: amountRange(least, most),
      onOpen: () => showBlurredDialog(
        context: context,
        barrierLabel: 'AmountFilterDialog',
        builder: (context) => _AmountFilterDialog(least: least, most: most, onApply: onApply),
      ),
      onClear: () => onApply(null, null),
    );
  }
}

// «Minimo» and «Massimo», set by «APPLICA»; an empty field is no bound, both bounds included.
class _AmountFilterDialog extends StatefulWidget
{
  final int? least;
  final int? most;
  final void Function(int? least, int? most) onApply;

  const _AmountFilterDialog({required this.least, required this.most, required this.onApply});

  @override
  State<_AmountFilterDialog> createState() => _AmountFilterDialogState();
}

class _AmountFilterDialogState extends State<_AmountFilterDialog>
{
  late final TextEditingController _least = TextEditingController(text: _typed(widget.least));
  late final TextEditingController _most = TextEditingController(text: _typed(widget.most));
  final FocusNode _first = FocusNode();

  // "20,00": the amount without the euro sign.
  static String _typed(int? cents) => cents == null ? '' : formatAmount(cents).replaceFirst('€ ', '');

  @override
  void initState()
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        _first.requestFocus();
      }
    });
  }

  @override
  void dispose()
  {
    _least.dispose();
    _most.dispose();
    _first.dispose();
    super.dispose();
  }

  void _reset()
  {
    _least.clear();
    _most.clear();
  }

  String? _refusal(int? least, int? most)
  {
    if (least == null && _least.text.trim().isNotEmpty)
    {
      return kLeastAmountInvalid;
    }

    if (most == null && _most.text.trim().isNotEmpty)
    {
      return kMostAmountInvalid;
    }

    return least != null && most != null && least > most ? kAmountRangeReversed : null;
  }

  void _apply()
  {
    final int? least = parseAmountCents(_least.text);
    final int? most = parseAmountCents(_most.text);
    final String? refusal = _refusal(least, most);

    if (refusal != null)
    {
      CustomSnackBar.show(context: context, message: refusal, isError: true);

      return;
    }

    widget.onApply(least, most);
    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController controller, String label, String hint, {FocusNode? focus})
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: hint,
      focusNode: focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onSubmitted: (_) => _apply(),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kFilterEyebrow,
      title: kAmountFilterTitle,
      maxWidth: _amountDialogWidth,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: kResetFilterLabel,
          icon: Icons.refresh_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.dismissAccent,
          height: 52,
          fontSize: 14,
          onPressed: _reset,
        ),
        primary: AppGradientButton(
          label: kApplyFilterLabel,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          onPressed: _apply,
        ),
      ),
      children: [
        AppDialogPill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field(_least, kLeastAmountLabel, kLeastAmountHint, focus: _first)),
              const SizedBox(width: 16),
              Expanded(child: _field(_most, kMostAmountLabel, kMostAmountHint)),
            ],
          ),
        ),
      ],
    );
  }
}
