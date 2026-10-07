import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/association/tabs/pupil_subjects_tab.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/wizard_dialog.dart' show kDescriptionFieldHint, kDescriptionFieldLabel;
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_text_field.dart';

const int _descriptionMinLines = 3;
const int _descriptionMaxLines = 5;

Future<void> showMobileMissingSubjectSheet(BuildContext context)
{
  return showMobileSheet<void>(context: context, builder: (_) => const _MissingSubjectSheet());
}

class _MissingSubjectSheet extends StatefulWidget
{
  const _MissingSubjectSheet();

  @override
  State<_MissingSubjectSheet> createState() => _MissingSubjectSheetState();
}

class _MissingSubjectSheetState extends State<_MissingSubjectSheet>
{
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();

  bool _busy = false;

  @override
  void dispose()
  {
    _name.dispose();
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

    final String name = _name.text.trim();

    if (name.isEmpty)
    {
      MobileNotice.show(context, kMissingSubjectNameEmpty, error: true);
      return;
    }

    final String description = _description.text.trim();

    setState(() => _busy = true);

    try
    {
      await ApiService().reportMissingSubject(name, description.isEmpty ? null : description);

      if (mounted)
      {
        MobileNotice.show(context, kMissingSubjectSent);
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
        eyebrow: kMissingSubjectEyebrow,
        title: kMissingSubjectTitle,
        aboveKeyboard: true,
        body: [
          const SizedBox(height: 18),
          MobileTextField(
            controller: _name,
            label: kMissingSubjectNameLabel,
            hintText: kMissingSubjectNameHint,
            maxLength: FieldLimits.name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          MobileTextField(
            controller: _description,
            label: kDescriptionFieldLabel,
            hintText: kDescriptionFieldHint,
            maxLength: FieldLimits.description,
            minLines: _descriptionMinLines,
            maxLines: _descriptionMaxLines,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        footer: Padding(
          padding: const EdgeInsets.only(top: 22),
          child: MobileGoldButton(
            label: kMissingSubjectSend,
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _send,
          ),
        ),
      ),
    );
  }
}
