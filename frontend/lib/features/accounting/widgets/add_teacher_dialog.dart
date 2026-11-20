import 'dart:async';
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
import '../../people/edit/person_edit_form.dart';
import '../../people/models/person_item.dart';
import '../models/teacher_hours_items.dart';
import '../utils/accounting_strings.dart';

const double _dialogWidth = 600;
const double _fieldGap = 20;
const int _newStretchMinutes = 60;

// The band as it stands once the teacher is in, or null if the dialog was closed.
Future<TeacherHoursBand?> showAddTeacherDialog(
  BuildContext context, {
  required DateTime day,
  required TimeBucket band,
  required List<PersonItem> teachers,
  required Set<String> present,
})
{
  return showBlurredDialog<TeacherHoursBand>(
    context: context,
    barrierLabel: 'AddTeacherHours',
    builder: (context) => _AddTeacherDialog(
      day: day,
      band: band,
      teachers: teachers,
      present: present,
    ),
  );
}

class _AddTeacherDialog extends StatefulWidget
{
  final DateTime day;
  final TimeBucket band;
  final List<PersonItem> teachers;

  // Already in the summary, or on their way to it: listed greyed, never picked.
  final Set<String> present;

  const _AddTeacherDialog({
    required this.day,
    required this.band,
    required this.teachers,
    required this.present,
  });

  @override
  State<_AddTeacherDialog> createState() => _AddTeacherDialogState();
}

class _AddTeacherDialogState extends State<_AddTeacherDialog>
{
  final ApiService _api = ApiService();

  String? _taxCode;
  bool _online = false;
  List<HoursSpan> _work = [];
  HoursSpan? _volunteer;

  // Once moved by hand the weekly hour no longer proposes it.
  bool _volunteerTouched = false;

  bool _saving = false;
  int _proposalRequest = 0;

  PersonItem? get _teacher
  {
    for (final teacher in widget.teachers)
    {
      if (teacher.fiscalCode == _taxCode)
      {
        return teacher;
      }
    }

    return null;
  }

  // GET /people/ sends the type's label, the summary's rows its code.
  String? get _collaboration
  {
    final String? type = _teacher?.collaborationType;

    return kCollaborationTypes[type] ?? type;
  }

  bool get _isVolunteer => _collaboration == kVolunteerCollaboration;

  // Who can come in first; those already there last, greyed, saying so.
  List<SelectionOption<String>> get _options
  {
    final List<SelectionOption<String>> all = personPickerOptions(widget.teachers);

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

  bool get _mayVolunteer => !_online && _collaboration == kPaidCollaboration;

  String get _mode => _online ? kOnline : kPresence;

  // The whole band, not the association's hours: somebody may have come in outside them.
  ({int start, int end}) get _window => (start: bandStartMinutes(widget.band), end: bandEndMinutes(widget.band));

  void _selectTeacher(String? taxCode)
  {
    setState(()
    {
      _taxCode = taxCode;
      _volunteerTouched = false;
      _volunteer = null;
    });

    unawaited(_propose());
  }

  void _setMode(bool presence)
  {
    setState(()
    {
      _online = !presence;
      _work = [];
      _volunteer = null;
      _volunteerTouched = false;
    });
  }

  void _setStretch(int index, TimeOfDay? start, TimeOfDay? end)
  {
    setState(()
    {
      if (start == null || end == null)
      {
        _work = [];
        _volunteer = null;

        return;
      }

      final HoursSpan span = HoursSpan(minutesOfTimeOfDay(start), minutesOfTimeOfDay(end));

      _work = [
        for (final (at, old) in _work.indexed) at == index ? span : old,
        if (index >= _work.length) span,
      ];

      _volunteer = _inside(_volunteer);
    });

    unawaited(_propose());
  }

  // The volunteering keeps what of it still falls inside the work.
  HoursSpan? _inside(HoursSpan? volunteer)
  {
    if (volunteer == null || _work.isEmpty)
    {
      return null;
    }

    final HoursSpan work = _work.first;
    final HoursSpan clipped = HoursSpan(math.max(volunteer.start, work.start), math.min(volunteer.end, work.end));

    return clipped.end > clipped.start ? clipped : null;
  }

  Future<void> _propose() async
  {
    final String? taxCode = _taxCode;

    if (taxCode == null || !_mayVolunteer || _volunteerTouched || _work.isEmpty)
    {
      return;
    }

    final int request = ++_proposalRequest;

    try
    {
      final HoursSpan? proposal = await _api.getVolunteerProposal(widget.day, widget.band, taxCode, _work.first);

      if (mounted && request == _proposalRequest && !_volunteerTouched)
      {
        setState(() => _volunteer = proposal);
      }
    }
    catch (_)
    {
      // Only a proposal: the rule decides once the teacher is in.
    }
  }

  void _addStretch()
  {
    final int end = _window.end;
    final int from = _work.isEmpty ? _window.start : _work.last.end;

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
      CustomSnackBar.show(context: context, message: kChooseTeacher, isError: true);

      return;
    }

    if (_work.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kNoWork, isError: true);

      return;
    }

    setState(() => _saving = true);

    try
    {
      final TeacherHoursBand band = await _api.addTeacherHours(
        widget.day,
        widget.band,
        taxCode: taxCode,
        mode: _mode,
        work: _work,
        setVolunteer: _mayVolunteer && _volunteerTouched,
        volunteer: _volunteer,
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

  Widget _slider({
    required String name,
    required HoursSpan? span,
    required int start,
    required int end,
    required void Function(TimeOfDay? start, TimeOfDay? end) onChanged,
    Widget? trailing,
  })
  {
    return BandTimeRangeSlider(
      bucket: widget.band,
      nameOverride: name,
      startTime: span == null ? null : timeOfDayFromMinutes(span.start),
      endTime: span == null ? null : timeOfDayFromMinutes(span.end),
      windowStartMinutes: start,
      windowEndMinutes: end,
      trueLabel: tr('Sì', 'Yes'),
      falseLabel: 'No',
      offLabel: kNoneLabel,
      trailing: trailing,
      onChanged: onChanged,
    );
  }

  List<Widget> _workSliders()
  {
    final String name = _isVolunteer ? kVolunteerGroup : kWorkGroup;
    final ({int start, int end}) window = _window;

    if (_work.length <= 1)
    {
      return [
        _slider(
          name: name,
          span: _work.isEmpty ? null : _work.first,
          start: window.start,
          end: window.end,
          onChanged: (start, end) => _setStretch(0, start, end),
        ),
      ];
    }

    return [
      for (final (index, span) in _work.indexed) ...[
        if (index > 0) const SizedBox(height: 14),
        _slider(
          name: index == 0 ? name : '',
          span: span,
          start: window.start,
          end: window.end,
          onChanged: (start, end) => _setStretch(index, start, end),
          trailing: FadeHoverIconButton(
            icon: Icons.delete_outline_rounded,
            color: AppTheme.trialDangerText,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: () => _removeStretch(index),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final HoursSpan? work = _work.isEmpty ? null : _work.first;

    return AppDialogStack(
      eyebrow: '${formatWeekdayColumnLabel(widget.day)} · ${bandLabel(widget.band)}',
      title: kAddTeacherTitle,
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
                label: kTeacherLabel,
                hint: kTeacherHint,
                icon: null,
                options: _options,
                showAllOptionsWhenEmpty: true,
                value: _taxCode,
                onSelected: _selectTeacher,
                onCleared: () => _selectTeacher(null),
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
                  onChanged: _setMode,
                ),
              ),
              const SizedBox(height: _fieldGap),
              ..._workSliders(),
              if (_work.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppAddRowButton(label: kAddStretchButton, dense: true, onTap: _addStretch),
                ),
              ],
              if (_mayVolunteer && work != null) ...[
                Divider(height: 30, thickness: 1, color: AppTheme.trialLine),
                _slider(
                  name: kVolunteerGroup,
                  span: _volunteer,
                  start: work.start,
                  end: work.end,
                  onChanged: (start, end)
                  {
                    setState(()
                    {
                      _volunteerTouched = true;
                      _volunteer = start == null || end == null
                          ? null
                          : HoursSpan(minutesOfTimeOfDay(start), minutesOfTimeOfDay(end));
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
