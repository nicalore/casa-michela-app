import 'package:flutter/material.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/edit/widgets/person_chip_group_field.dart';
import '../../people/models/person_item.dart';
import '../psychologist_strings.dart';

const double _dialogWidth = 760;

const String _noneOption = 'No';
const String _otherCode = 'OTHER';
const String _dsaCode = 'DSA';

// In the order the administrator's form offers them.
const Map<String, String> kCertificationLabels = {
  'DSA': 'DSA',
  'BES': 'BES',
  'ADHD': 'ADHD',
  _otherCode: 'Altro',
};

// True once saved.
Future<bool> showCertificationsDialog(BuildContext context, PersonItem student) async
{
  final bool? saved = await showBlurredDialog<bool>(
    context: context,
    barrierLabel: 'Certifications',
    builder: (context) => _CertificationsDialog(student: student),
  );

  return saved ?? false;
}

class _CertificationsDialog extends StatefulWidget
{
  final PersonItem student;

  const _CertificationsDialog({required this.student});

  @override
  State<_CertificationsDialog> createState() => _CertificationsDialogState();
}

class _CertificationsDialogState extends State<_CertificationsDialog>
{
  final ApiService _apiService = ApiService();

  late final Set<String> _codes = {...widget.student.certificationTypes};

  late final TextEditingController _otherController =
      TextEditingController(text: widget.student.certificationOtherDetail ?? '');
  late final TextEditingController _dsaController =
      TextEditingController(text: widget.student.certificationDsaDetail ?? '');

  String? _otherError;
  String? _dsaError;

  bool _saving = false;

  @override
  void dispose()
  {
    _otherController.dispose();
    _dsaController.dispose();
    super.dispose();
  }

  Set<String> get _chosenLabels =>
      _codes.isEmpty ? const {_noneOption} : {for (final code in _codes) kCertificationLabels[code]!};

  void _toggle(String label)
  {
    setState(()
    {
      if (label == _noneOption)
      {
        _codes.clear();
      }
      else
      {
        final String code = kCertificationLabels.entries.firstWhere((entry) => entry.value == label).key;

        if (!_codes.remove(code))
        {
          _codes.add(code);
        }
      }

      _otherError = null;
      _dsaError = null;
    });
  }

  Future<void> _save() async
  {
    final String other = _otherController.text.trim();
    final String dsa = _dsaController.text.trim();

    setState(()
    {
      _otherError = _codes.contains(_otherCode) && other.isEmpty ? kOtherRequired : null;
      _dsaError = _codes.contains(_dsaCode) && dsa.isEmpty ? kDsaRequired : null;
    });

    if (_otherError != null || _dsaError != null)
    {
      CustomSnackBar.show(context: context, message: kFormErrors, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      await _apiService.updateCertifications(
        widget.student.fiscalCode,
        types: [
          for (final code in kCertificationLabels.keys)
            if (_codes.contains(code)) code,
        ],
        dsaDetail: _codes.contains(_dsaCode) ? dsa : null,
        otherDetail: _codes.contains(_otherCode) ? other : null,
      );

      if (mounted)
      {
        Navigator.of(context).pop(true);
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
    final PersonItem student = widget.student;

    return AppDialogStack(
      eyebrow: kCertificationsTitle,
      title: '${student.firstName} ${student.lastName}',
      leading: PersonAvatar(person: student, size: PersonAvatar.titleSize),
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kSaveChangesLabel,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonChipGroupField.multiple(
                label: kCertificationField,
                options: [_noneOption, ...kCertificationLabels.values],
                values: _chosenLabels,
                onToggled: _toggle,
              ),
              if (_codes.contains(_otherCode))
                AppTextField(
                  controller: _otherController,
                  label: kOtherDetailLabel,
                  hintText: 'Es. Autismo livello 1',
                  maxLength: FieldLimits.otherDetail,
                  errorText: _otherError,
                  onChanged: (_) => setState(() => _otherError = null),
                ),
              if (_codes.contains(_dsaCode))
                AppTextField(
                  controller: _dsaController,
                  label: kDsaDetailLabel,
                  hintText: 'Es. Dislessia e discalculia',
                  maxLength: FieldLimits.dsaDetail,
                  errorText: _dsaError,
                  onChanged: (_) => setState(() => _dsaError = null),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
