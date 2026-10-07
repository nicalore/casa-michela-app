import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

const int _minLines = 5;
const int _maxLines = 8;

Future<void> showMobileProblemReportSheet(BuildContext context)
{
  return showMobileSheet<void>(context: context, builder: (_) => const _ReportSheet());
}

class _ReportSheet extends StatefulWidget
{
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet>
{
  final TextEditingController _description = TextEditingController();

  bool _busy = false;

  @override
  void dispose()
  {
    _description.dispose();
    super.dispose();
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _send() async
  {
    if (_busy)
    {
      return;
    }

    final String description = _description.text.trim();

    if (description.isEmpty)
    {
      MobileNotice.show(context, kReportEmpty, error: true);
      return;
    }

    setState(() => _busy = true);

    try
    {
      await ApiService().reportProblem(description);

      if (mounted)
      {
        MobileNotice.show(context, kReportSent);
        finishMobileSheet(context);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: MobileSheet(
        eyebrow: kReportEyebrow,
        title: kReportTitle,
        aboveKeyboard: true,
        body: [
          const SizedBox(height: 18),
          MobileTextField(
            controller: _description,
            label: kReportDescriptionLabel,
            hintText: kReportDescriptionHint,
            maxLength: FieldLimits.description,
            minLines: _minLines,
            maxLines: _maxLines,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: MobileGoldButton(
            label: kReportSendLabel,
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
