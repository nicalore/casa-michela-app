import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/lessons_form_fields.dart';
import '../../people/models/person_item.dart';
import '../models/student_hours_items.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';

const double _dialogWidth = 600;
const double _fieldGap = 20;
const int _newStretchMinutes = 60;

// The band as it stands once the pupil is in, or null if the dialog was closed.
Future<StudentHoursBand?> showAddStudentDialog(
  BuildContext context, {
  required DateTime day,
  required TimeBucket band,
  required List<PersonItem> students,
  required Set<String> present,
})
{
  return showBlurredDialog<StudentHoursBand>(
    context: context,
    barrierLabel: 'AddStudentHours',
    builder: (context) => _AddStudentDialog(
      day: day,
      band: band,
      students: students,
      present: present,
    ),
  );
}

class _AddStudentDialog extends StatefulWidget
{
  final DateTime day;
  final TimeBucket band;
  final List<PersonItem> students;

  // Already in the summary, or on their way to it: listed greyed, never picked.
  final Set<String> present;

  const _AddStudentDialog({
    required this.day,
    required this.band,
    required this.students,
    required this.present,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog>
{
  final ApiService _api = ApiService();

  String? _taxCode;
  bool _online = false;

  // A pupil added has always some time: the whole band to start with.
  late List<HoursSpan> _work = [HoursSpan(_window.start, _window.end)];

  bool _saving = false;

  // Who can come in first; those already there last, greyed, saying so.
  List<SelectionOption<String>> get _options
  {
    final List<SelectionOption<String>> all = personPickerOptions(widget.students);

    return [
      for (final option in all)
        if (!widget.present.contains(option.value)) option,
      for (final option in all)
        if (widget.present.contains(option.value))
          SelectionOption(
            value: option.value,
            label: option.label,
            subtitle: kAlreadyInSummary,
            leading: option.leading,
            enabled: false,
          ),
    ];
  }

  String get _mode => _online ? kOnline : kPresence;

  // The whole band, not the association's hours: somebody may have come in outside them.
  ({int start, int end}) get _window => (start: bandStartMinutes(widget.band), end: bandEndMinutes(widget.band));

  void _setStretch(int index, TimeOfDay? start, TimeOfDay? end)
  {
    if (start == null || end == null)
    {
      return;
    }

    final HoursSpan span = HoursSpan(minutesOfTimeOfDay(start), minutesOfTimeOfDay(end));

    setState(() => _work = [for (final (at, old) in _work.indexed) at == index ? span : old]);
  }

  void _addStretch()
  {
    final int end = _window.end;
    final int from = _work.last.end;

    if (from >= end)
    {
      CustomSnackBar.show(context: context, message: kNoRoomForStretch, isError: true);

      return;
    }

    setState(() => _work = [..._work, HoursSpan(from, math.min(from + _newStretchMinutes, end))]);
  }

  void _removeStretch(int index)
  {
    setState(() => _work = [for (final (at, span) in _work.indexed) if (at != index) span]);
  }

  Future<void> _save() async
  {
    final String? taxCode = _taxCode;

    if (taxCode == null)
    {
      CustomSnackBar.show(context: context, message: kChooseStudent, isError: true);

      return;
    }

    if (_work.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kNoTimes, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      final StudentHoursBand band = await _api.addStudentHours(
        widget.day,
        widget.band,
        taxCode: taxCode,
        mode: _mode,
        work: _work,
      );

      if (mounted)
      {
        Navigator.of(context, rootNavigator: true).pop(band);
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

  // No switch: the time is never «Nessuno»; a bin only once there are two.
  Widget _slider(int index, HoursSpan span)
  {
    final ({int start, int end}) window = _window;

    return BandTimeRangeSlider(
      bucket: widget.band,
      nameOverride: index == 0 ? kTimesLabel : '',
      startTime: timeOfDayFromMinutes(span.start),
      endTime: timeOfDayFromMinutes(span.end),
      windowStartMinutes: window.start,
      windowEndMinutes: window.end,
      trueLabel: tr('Sì', 'Yes'),
      falseLabel: 'No',
      offLabel: kNoneLabel,
      trailing: _work.length > 1
          ? FadeHoverIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppTheme.trialDangerText,
              hoverColor: AppTheme.trialGoldSurface,
              onTap: () => _removeStretch(index),
            )
          : const SizedBox.shrink(),
      onChanged: (start, end) => _setStretch(index, start, end),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: '${formatWeekdayColumnLabel(widget.day)} · ${bandLabel(widget.band)}',
      title: kAddStudentTitle,
      maxWidth: _dialogWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kAddButton,
          icon: Icons.check_rounded,
          height: 52,
          fontSize: 14,
          busy: _saving,
          onPressed: _save,
        ),
      ),
      children: [
        AppDialogPill(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AutocompleteField<String>(
                label: kStudentLabel,
                hint: kStudentHint,
                icon: null,
                options: _options,
                showAllOptionsWhenEmpty: true,
                value: _taxCode,
                onSelected: (taxCode) => setState(() => _taxCode = taxCode),
                onCleared: () => setState(() => _taxCode = null),
              ),
              const SizedBox(height: _fieldGap),
              AppFieldLabel(kModeLabel),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: AppSegmentedSwitch(
                  value: !_online,
                  trueLabel: modeLabel(kPresence),
                  falseLabel: modeLabel(kOnline),
                  hugContent: true,
                  onChanged: (presence) => setState(() => _online = !presence),
                ),
              ),
              const SizedBox(height: _fieldGap),
              for (final (index, span) in _work.indexed) ...[
                if (index > 0) const SizedBox(height: 14),
                _slider(index, span),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: AppAddRowButton(label: kAddStretchButton, dense: true, onTap: _addStretch),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
