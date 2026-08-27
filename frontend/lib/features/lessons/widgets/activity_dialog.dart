import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/band_time_range_slider.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/activity_item.dart';
import '../models/availability_item.dart';
import '../models/calendar_day.dart';
import '../utils/lesson_placement.dart';
import '../utils/timeline_geometry.dart';
import 'calendar_activity_block.dart';
import 'calendar_lesson_block.dart';

// Sized to fit the three footer buttons side by side.
const double _dialogWidth = 900;

const double _widestAnswerWidth = 288;

const double _threeAnswerFooterWidth = 3 * _widestAnswerWidth + 2 * 16;

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;
const double _dialogButtonPadding = 18;

const String _kTeacherHint = 'Scegli il docente';

const String _kNoTeacherNote =
    'Nessun docente ha dato la sua disponibilità in questa parte della giornata: '
    "l'attività resta qui finché non ce n'è uno.";

const String _kNameRequired = "Un'attività deve avere un nome.";

// Both availability modes are offered: an activity needs the teacher's time,
// not a room.
class _Slot
{
  final TeacherLane lane;
  final AvailabilityItem availability;
  final int windowStart;
  final int windowEnd;

  const _Slot({
    required this.lane,
    required this.availability,
    required this.windowStart,
    required this.windowEnd,
  });

  String get label =>
      '${lane.teacher.fullName} · ${formatMinutesRange(windowStart, windowEnd)}';
}

class ActivityDialog extends StatefulWidget
{
  final CalendarDayIndex index;

  // Null when creating a new activity.
  final ActivityItem? activity;

  final Future<bool> Function({
    required String name,
    required String? description,
    required Function(String) onError,
  })? onCreate;

  final Future<bool> Function({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Function(String) onError,
  })? onSave;

  final Future<bool> Function(ActivityItem activity, Function(String) onError)? onDelete;

  const ActivityDialog({
    super.key,
    required this.index,
    this.activity,
    this.onCreate,
    this.onSave,
    this.onDelete,
  });

  @override
  State<ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<ActivityDialog>
{
  late final TextEditingController _name =
      TextEditingController(text: widget.activity?.name ?? '');

  late final TextEditingController _description =
      TextEditingController(text: widget.activity?.description ?? '');

  late final List<_Slot> _slots = _slotsInTheBand();

  late int? _availabilityId = widget.activity?.placement?.availabilityId;

  late int _startMinutes =
      widget.activity?.placement?.startMinutes ?? _index.bandStart;

  late int _endMinutes = widget.activity?.placement?.endMinutes ??
      _index.bandStart + kDefaultActivityMinutes;

  bool _isSaving = false;

  bool _saysNameIsMissing = false;

  CalendarDayIndex get _index => widget.index;

  ActivityItem? get _activity => widget.activity;

  bool get _isNew => _activity == null;

  bool get _isLocked => _activity?.isLocked ?? false;

  @override
  void dispose()
  {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  List<_Slot> _slotsInTheBand()
  {
    final slots = <_Slot>[];

    for (final lane in widget.index.lanes)
    {
      for (final availability in lane.availabilities)
      {
        final window = intersectSpan(
          minutesOfTimeOfDay(availability.startTime),
          minutesOfTimeOfDay(availability.endTime),
          widget.index.bandStart,
          widget.index.bandEnd,
        );

        if (window == null || window.$2 - window.$1 < kMinimumActivityMinutes)
        {
          continue;
        }

        slots.add(_Slot(
          lane: lane,
          availability: availability,
          windowStart: window.$1,
          windowEnd: window.$2,
        ));
      }
    }

    slots.sort((a, b)
    {
      final byName = a.lane.teacher.fullName.toLowerCase().compareTo(
            b.lane.teacher.fullName.toLowerCase(),
          );

      return byName != 0 ? byName : a.windowStart.compareTo(b.windowStart);
    });

    return slots;
  }

  _Slot? get _slot
  {
    return _slots.where((slot) => slot.availability.id == _availabilityId).firstOrNull;
  }

  void _place(_Slot slot)
  {
    _availabilityId = slot.availability.id;

    final length = (_endMinutes - _startMinutes).clamp(
      kMinimumActivityMinutes,
      slot.windowEnd - slot.windowStart,
    );

    if (_startMinutes < slot.windowStart || _startMinutes + length > slot.windowEnd)
    {
      _startMinutes = slot.windowStart;
    }

    _endMinutes = _startMinutes + length;
  }

  String? get _refusal
  {
    final activity = _activity;
    final slot = _slot;

    if (activity == null || slot == null)
    {
      return null;
    }

    return validateActivityPlacement(
      index: _index,
      activity: activity,
      teacherTaxCode: slot.lane.teacherTaxCode,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
    ).refusal;
  }

  Widget _label(String text, {bool first = true})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  TextStyle get _noteStyle => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppTheme.trialMutedText,
      );

  Widget _buildNameAndDescription()
  {
    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _name,
            label: 'Nome',
            hintText: 'Es. Ufficio',
            nothingAbove: true,
            maxLength: FieldLimits.name,
            textCapitalization: TextCapitalization.sentences,
            errorText: _saysNameIsMissing ? _kNameRequired : null,
            onChanged: (_)
            {
              if (_saysNameIsMissing)
              {
                setState(() => _saysNameIsMissing = false);
              }
            },
          ),
          AppTextField(
            controller: _description,
            label: 'Descrizione (opzionale)',
            hintText: 'Aggiungi una descrizione...',
            maxLength: FieldLimits.description,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignment()
  {
    final slot = _slot;
    final refusal = _refusal;

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Docente'),
          if (_slots.isEmpty)
            Text(_kNoTeacherNote, style: _noteStyle)
          else
            AppDropdownField<int>(
              hint: _kTeacherHint,
              value: _availabilityId,
              options: [
                for (final offered in _slots)
                  AppDropdownOption(
                    value: offered.availability.id,
                    label: offered.label,
                  ),
              ],
              onChanged: (id)
              {
                final chosen = _slots.where((offered) => offered.availability.id == id).firstOrNull;

                if (chosen != null)
                {
                  setState(() => _place(chosen));
                }
              },
            ),
          if (slot != null) ...[
            _label('Quando', first: false),
            BandTimeRangeSlider(
              bucket: _index.band,
              startTime: timeOfDayFromMinutes(_startMinutes),
              endTime: timeOfDayFromMinutes(_endMinutes),
              minimumMinutes: kMinimumActivityMinutes,
              windowStartMinutes: slot.windowStart,
              windowEndMinutes: slot.windowEnd,
              nameOverride: '',
              trailing: Text(
                formatMinutes(_endMinutes - _startMinutes),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppTheme.trialInk,
                ),
              ),
              onChanged: (start, end)
              {
                if (start == null || end == null)
                {
                  return;
                }

                setState(()
                {
                  _startMinutes = minutesOfTimeOfDay(start);
                  _endMinutes = minutesOfTimeOfDay(end);
                });
              },
            ),
          ],
          if (refusal != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, size: 20, color: AppTheme.trialDanger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    refusal,
                    style: _noteStyle.copyWith(color: AppTheme.trialDanger),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _report(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  // keepingTheHours=false is TOGLI DAL CALENDARIO: same save, with no teacher.
  // A placement refusal does not block removal.
  Future<void> _confirm({bool keepingTheHours = true}) async
  {
    final name = _name.text.trim();

    if (name.isEmpty)
    {
      setState(() => _saysNameIsMissing = true);

      return;
    }

    if (_isSaving || (keepingTheHours && _refusal != null))
    {
      return;
    }

    final description = _description.text.trim();
    final activity = _activity;

    final availabilityId = keepingTheHours ? _availabilityId : null;

    setState(() => _isSaving = true);

    final written = activity == null
        ? await widget.onCreate?.call(
            name: name,
            description: description.isEmpty ? null : description,
            onError: _report,
          )
        : await widget.onSave?.call(
            existing: activity,
            name: name,
            description: description.isEmpty ? null : description,
            availabilityId: availabilityId,
            startTime: availabilityId == null ? null : timeOfDayFromMinutes(_startMinutes),
            endTime: availabilityId == null ? null : timeOfDayFromMinutes(_endMinutes),
            onError: _report,
          );

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (written == true)
    {
      Navigator.pop(context);
    }
  }

  Future<void> _remove() async
  {
    final activity = _activity;
    final delete = widget.onDelete;

    if (activity == null || delete == null || _isSaving)
    {
      return;
    }

    setState(() => _isSaving = true);

    final removed = await delete(activity, _report);

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (removed)
    {
      Navigator.pop(context);
    }
  }

  bool get _canWrite => (_isNew ? widget.onCreate : widget.onSave) != null && !_isLocked;

  bool get _canDelete => widget.onDelete != null && !_isLocked;

  // As the calendar has it, not as this window has it: an unconfirmed pick is
  // not on the calendar yet.
  bool get _isOnTheCalendar => _activity?.isAssigned ?? false;

  Widget _buildFooter()
  {
    if (!_canWrite && !_canDelete)
    {
      return AppDialogFooter.single(
        AppGradientButton(
          label: 'CHIUDI',
          icon: Icons.close_rounded,
          gradient: AppTheme.dismissGradient,
          accent: AppTheme.trialViolet,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          horizontalPadding: _dialogButtonPadding,
          onPressed: () => Navigator.pop(context),
        ),
      );
    }

    final confirm = AppGradientButton(
      label: 'CONFERMA',
      icon: Icons.check_rounded,
      busy: _isSaving,
      height: _dialogButtonHeight,
      fontSize: _dialogButtonFontSize,
      horizontalPadding: _dialogButtonPadding,
      disabledReason: _canWrite ? null : kActivitySettledRefusal,
      onPressed: _confirm,
    );

    if (_isNew)
    {
      return AppDialogFooter.single(confirm);
    }

    return AppDialogFooter(
      maxWidth: _isOnTheCalendar ? _threeAnswerFooterWidth : AppDialogFooter.defaultWidth,
      tertiary: _isOnTheCalendar
          ? AppGradientButton(
              label: kRemoveFromCalendarLabel,
              icon: Icons.delete_outline_rounded,
              gradient: AppTheme.dangerGradient,
              accent: AppTheme.trialDanger,
              height: _dialogButtonHeight,
              fontSize: _dialogButtonFontSize,
              horizontalPadding: _dialogButtonPadding,
              disabledReason: _canWrite ? null : kActivitySettledRefusal,
              onPressed: () => _confirm(keepingTheHours: false),
            )
          : null,
      secondary: AppGradientButton(
        label: 'ELIMINA',
        icon: Icons.delete_outline_rounded,
        gradient: AppTheme.dangerGradient,
        accent: AppTheme.trialDanger,
        height: _dialogButtonHeight,
        fontSize: _dialogButtonFontSize,
        horizontalPadding: _dialogButtonPadding,
        disabledReason: _canDelete ? null : kActivitySettledRefusal,
        onPressed: _remove,
      ),
      primary: confirm,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kActivityWord,
      title: _isNew ? 'Nuova attività' : 'Modifica attività',
      maxWidth: _dialogWidth,
      footer: _buildFooter(),
      children: [
        _buildNameAndDescription(),
        if (!_isNew) _buildAssignment(),
      ],
    );
  }
}

Future<void> showActivityDialog({
  required BuildContext context,
  required CalendarDayIndex index,
  ActivityItem? activity,
  Future<bool> Function({
    required String name,
    required String? description,
    required Function(String) onError,
  })? onCreate,
  Future<bool> Function({
    required ActivityItem existing,
    required String name,
    required String? description,
    required int? availabilityId,
    required TimeOfDay? startTime,
    required TimeOfDay? endTime,
    required Function(String) onError,
  })? onSave,
  Future<bool> Function(ActivityItem activity, Function(String) onError)? onDelete,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: kActivityWord,
    builder: (dialogContext) => ActivityDialog(
      index: index,
      activity: activity,
      onCreate: onCreate,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}
