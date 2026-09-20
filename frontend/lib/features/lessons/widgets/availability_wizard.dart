import 'package:flutter/material.dart';

import '../../../core/utils/time_bucket.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/availability_group.dart';
import '../models/availability_item.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import 'band_schedule.dart';
import 'lesson_day_field.dart';
import 'lessons_form_fields.dart';
import 'person_avatar.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _wizardMaxWidth = 560;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

const List<String> _modes = [kPresenceMode, kOnlineMode];

// Keyed by opening signature, so hours survive adding or removing days.
class _DayGroup
{
  final String key;
  final List<DateTime> days;

  const _DayGroup({required this.key, required this.days});
}

typedef _Card = ({_DayGroup group, String mode});

typedef AvailabilityCreate = Future<bool> Function(
  String teacherTaxCode,
  DateTime date,
  String mode,
  TimeOfDay startTime,
  TimeOfDay endTime,
  Function(String) onError,
);

typedef AvailabilityEdit = Future<bool> Function(
  AvailabilityItem existing,
  String teacherTaxCode,
  DateTime date,
  String mode,
  TimeOfDay startTime,
  TimeOfDay endTime,
  Function(String) onError,
);

typedef AvailabilitySlotDelete = Future<bool> Function(
  AvailabilityItem item,
  Function(String) onError,
);

class AvailabilityWizardDialog extends StatefulWidget
{
  final AvailabilityGroup? existingGroup;

  final List<PersonItem> teachers;
  final String? ownTaxCode;

  final List<DateTime> availableDays;
  final DateTime defaultDate;

  final List<AvailabilityItem> availabilities;

  final List<OpeningDayItem> openingDays;

  final VoidCallback? onCancelEdit;
  final AvailabilityCreate onCreate;
  final AvailabilityEdit onEdit;
  final AvailabilitySlotDelete onDeleteSlot;

  const AvailabilityWizardDialog({
    super.key,
    this.existingGroup,
    this.teachers = const [],
    this.ownTaxCode,
    required this.availableDays,
    required this.defaultDate,
    required this.availabilities,
    required this.openingDays,
    this.onCancelEdit,
    required this.onCreate,
    required this.onEdit,
    required this.onDeleteSlot,
  });

  @override
  State<AvailabilityWizardDialog> createState() => _AvailabilityWizardDialogState();
}

class _AvailabilityWizardDialogState extends State<AvailabilityWizardDialog>
{
  String? _selectedTeacherTaxCode;

  Set<DateTime> _days = {};

  final Map<String, Map<String, BandSchedule<AvailabilityItem>>> _bandsByGroup = {};

  // Stored hours in bands that have closed: shown, never edited or dropped.
  final Map<String, Map<TimeBucket, List<BandStretch<AvailabilityItem>>>> _frozen = {
    for (final mode in _modes)
      mode: {for (final bucket in TimeBucket.values) bucket: <BandStretch<AvailabilityItem>>[]},
  };

  // Read once: the dialog is short-lived, and the server enforces the rule.
  final DateTime _now = DateTime.now();

  bool _isSaving = false;

  int _cardIndex = 0;
  bool _movingForward = true;

  final Set<Object> _saved = {};

  bool get _isEditing => widget.existingGroup != null;

  bool get _isOwn => widget.ownTaxCode != null;

  // Editing skips the first card: teacher and day are settled.
  int get _modeOffset => _isEditing ? 0 : 1;

  int get _lastCard => _cards.length - 1 + _modeOffset;

  bool get _onAskedCard => !_isEditing && _cardIndex == 0;

  _Card get _shownCard => _cards[_cardIndex - _modeOffset];

  // Grouping key: open window per mode and band, '-' where shut or closed to own.
  String _signatureOf(DateTime day)
  {
    final parts = <String>[];

    for (final mode in _modes)
    {
      for (final bucket in TimeBucket.values)
      {
        final window = _isClosed(day, bucket) ? null : openingWindowFor(widget.openingDays, day, mode, bucket);

        parts.add(window == null ? '-' : '${window.startMinutes}-${window.endMinutes}');
      }
    }

    return parts.join('|');
  }

  List<_DayGroup> get _groups
  {
    final byKey = <String, List<DateTime>>{};

    for (final day in _sortedDays)
    {
      byKey.putIfAbsent(_signatureOf(day), () => []).add(day);
    }

    return [
      for (final entry in byKey.entries) _DayGroup(key: entry.key, days: entry.value),
    ];
  }

  Map<String, BandSchedule<AvailabilityItem>> _bandsOf(_DayGroup group)
  {
    return _bandsByGroup.putIfAbsent(
      group.key,
      () => {for (final mode in _modes) mode: BandSchedule<AvailabilityItem>()},
    );
  }

  List<String> _shownModesOf(_DayGroup group)
  {
    final open = _modes
        .where((mode) => TimeBucket.values.any((bucket) => _windowFor(group, mode, bucket) != null))
        .toList();

    return open.isEmpty ? _modes : open;
  }

  List<_Card> get _cards
  {
    return [
      for (final group in _groups)
        for (final mode in _shownModesOf(group)) (group: group, mode: mode),
    ];
  }

  PersonItem? get _selectedTeacher
  {
    final taxCode = _selectedTeacherTaxCode;

    if (taxCode == null)
    {
      return null;
    }

    for (final teacher in widget.teachers)
    {
      if (teacher.fiscalCode == taxCode)
      {
        return teacher;
      }
    }

    return null;
  }

  List<DateTime> get _sortedDays
  {
    final days = _days.toList()..sort();

    return days;
  }

  bool _isClosed(DateTime day, TimeBucket bucket)
  {
    return _isOwn && haveBookingsClosed(day, bucket, _now);
  }

  // Alike by construction; the intersection is just the safe way to read it.
  OpeningWindow? _sharedWindow(_DayGroup group, String mode, TimeBucket bucket)
  {
    return sharedOpeningWindow(widget.openingDays, group.days, mode, bucket);
  }

  OpeningWindow? _windowFor(_DayGroup group, String mode, TimeBucket bucket)
  {
    if (group.days.any((day) => _isClosed(day, bucket)))
    {
      return null;
    }

    return _sharedWindow(group, mode, bucket);
  }

  String _shutLabelFor(_DayGroup group, String mode, TimeBucket bucket)
  {
    return _sharedWindow(group, mode, bucket) == null ? 'Associazione chiusa' : 'Disponibilità chiuse';
  }

  bool _hasFrozen(String mode) => _frozen[mode]!.values.any((held) => held.isNotEmpty);

  List<String> _openModesOn(DateTime day)
  {
    return _modes
        .where((mode) => TimeBucket.values.any((bucket) =>
            !_isClosed(day, bucket) &&
            openingWindowFor(widget.openingDays, day, mode, bucket) != null))
        .toList();
  }

  bool _isTakenBy(String teacherTaxCode, DateTime day, String mode)
  {
    if (_isEditing && isSameDate(day, widget.existingGroup!.date))
    {
      return false;
    }

    return hasAvailabilityOn(widget.availabilities, teacherTaxCode, day, mode);
  }

  List<String> _freeModesOn(DateTime day)
  {
    final taxCode = _selectedTeacherTaxCode;
    final open = _openModesOn(day);

    if (taxCode == null)
    {
      return open;
    }

    return open.where((mode) => !_isTakenBy(taxCode, day, mode)).toList();
  }

  bool _isDayOffered(DateTime day) => _freeModesOn(day).isNotEmpty;

  String _dayTooltip(DateTime day)
  {
    final when = formatAvailableDayLabel(day).toLowerCase();

    if (!_modes.any((mode) => isOpenOn(widget.openingDays, day, mode)))
    {
      return "L'Associazione è chiusa $when.";
    }

    if (_openModesOn(day).isEmpty)
    {
      return 'Le prenotazioni di $when sono chiuse.';
    }

    if (_isOwn)
    {
      return 'Hai già una disponibilità $when: aprila per cambiarne gli orari.';
    }

    final teacher = _selectedTeacher;
    final name = teacher == null ? 'Il docente' : '${teacher.firstName} ${teacher.lastName}';

    return '$name ha già una disponibilità $when: aprila per cambiarne gli orari.';
  }

  @override
  void initState()
  {
    super.initState();

    _selectedTeacherTaxCode = widget.ownTaxCode;

    final group = widget.existingGroup;

    if (group != null)
    {
      _selectedTeacherTaxCode = group.teacherTaxCode;
      _days = {group.date};

      for (final slot in group.slots)
      {
        final bucket = bucketFor(slot.startTime);

        if (bucket == null)
        {
          continue;
        }

        final stretch = BandStretch<AvailabilityItem>(
          startTime: slot.startTime,
          endTime: slot.endTime,
          existing: slot,
        );

        if (_isClosed(group.date, bucket))
        {
          _frozen[slot.mode]![bucket]!.add(stretch);
        }
        else
        {
          _bandsOf(_groups.single)[slot.mode]!.addStored(bucket, stretch);
        }
      }

      _reconcileBands();
    }
    else
    {
      _days = {_firstOfferedDay()};
    }
  }

  DateTime _firstOfferedDay()
  {
    final offered = widget.availableDays.where(_isDayOffered).toList();

    if (offered.isEmpty)
    {
      return widget.defaultDate;
    }

    return offered.firstWhere(
      (day) => !day.isBefore(widget.defaultDate),
      orElse: () => offered.first,
    );
  }

  void _reconcileBands()
  {
    final groups = _groups;
    final keys = {for (final group in groups) group.key};

    _bandsByGroup.removeWhere((key, _) => !keys.contains(key));

    for (final group in groups)
    {
      for (final mode in _modes)
      {
        _bandsOf(group)[mode]!.reconcile((bucket) => _windowFor(group, mode, bucket));
      }
    }
  }

  void _selectDays(Set<DateTime> days)
  {
    setState(()
    {
      _days = days;
      _reconcileBands();
    });
  }

  void _selectTeacher(String? taxCode)
  {
    setState(()
    {
      _selectedTeacherTaxCode = taxCode;

      _days = _days.where(_isDayOffered).toSet();

      _reconcileBands();
    });
  }

  void _resetForm()
  {
    setState(()
    {
      _selectedTeacherTaxCode = widget.ownTaxCode;
      _days = {_firstOfferedDay()};

      _bandsByGroup.clear();

      _saved.clear();
      _cardIndex = 0;
      _movingForward = false;
    });
  }

  String? get _blockedReason
  {
    if (!_onAskedCard)
    {
      return null;
    }

    if (_selectedTeacherTaxCode == null)
    {
      return 'Scegli il docente per andare avanti.';
    }

    if (_days.isEmpty)
    {
      return 'Scegli almeno una giornata per andare avanti.';
    }

    return null;
  }

  void _goToCard(int index)
  {
    if (index > _cardIndex && _blockedReason != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = index > _cardIndex;
      _cardIndex = index;
    });
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();

    if (_isEditing)
    {
      widget.onCancelEdit?.call();
    }
  }

  Iterable<BandSchedule<AvailabilityItem>> get _schedules =>
      _bandsByGroup.values.expand((byMode) => byMode.values);

  bool get _hasAnyBand => _schedules.any((schedule) => schedule.isNotEmpty) || _modes.any(_hasFrozen);

  // Every open band answered "No": the teacher's way of deleting the day.
  bool get _isClearing => _isEditing && _isOwn && !_hasAnyBand;

  Future<void> _save() async
  {
    if (_isSaving)
    {
      return;
    }

    final teacherTaxCode = _selectedTeacherTaxCode;

    if (teacherTaxCode == null)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona un docente.', isError: true);
      return;
    }

    if (_days.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una giornata.', isError: true);
      return;
    }

    if (!_hasAnyBand && !_isClearing)
    {
      CustomSnackBar.show(
        context: context,
        message: _isEditing
            ? 'Indica almeno un orario di disponibilità, oppure elimina la disponibilità dalla sua scheda.'
            : 'Indica almeno un orario di disponibilità.',
        isError: true,
      );

      return;
    }

    final bool clearing = _isClearing;

    final groups = _groups;

    for (final group in groups)
    {
      for (final day in group.days)
      {
        for (final mode in _modes)
        {
          if (_bandsOf(group)[mode]!.isEmpty || !_isTakenBy(teacherTaxCode, day, mode))
          {
            continue;
          }

          final when = '${modeLabel(mode).toLowerCase()} ${formatAvailableDayLabel(day).toLowerCase()}';

          CustomSnackBar.show(
            context: context,
            message: _isOwn
                ? 'Hai già una disponibilità $when: aprila per cambiarne gli orari.'
                : 'Il docente ha già una disponibilità $when: aprila per cambiarne gli orari.',
            isError: true,
          );

          return;
        }
      }
    }

    setState(()
    {
      _isSaving = true;

      for (final schedule in _schedules)
      {
        schedule.fuse();
      }
    });

    void showError(String message)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: message, isError: true);
      }
    }

    for (final item in _schedules.expand((schedule) => schedule.dropped))
    {
      if (_saved.contains(item))
      {
        continue;
      }

      if (!await widget.onDeleteSlot(item, showError))
      {
        if (!mounted)
        {
          return;
        }

        setState(() => _isSaving = false);
        return;
      }

      if (!mounted)
      {
        return;
      }

      _saved.add(item);
    }

    for (final group in groups)
    {
      for (final day in group.days)
      {
        for (final mode in _modes)
        {
          for (final draft in _bandsOf(group)[mode]!.all)
          {
            final key = (day, mode, draft);

            if (_saved.contains(key))
            {
              continue;
            }

            final existing = draft.existing;
            final isMove = existing != null && isSameDate(day, existing.date);

            final success = isMove
                ? await widget.onEdit(existing, teacherTaxCode, day, mode, draft.startTime, draft.endTime, showError)
                : await widget.onCreate(teacherTaxCode, day, mode, draft.startTime, draft.endTime, showError);

            if (!mounted)
            {
              return;
            }

            if (!success)
            {
              setState(() => _isSaving = false);
              return;
            }

            _saved.add(key);
          }
        }
      }
    }

    setState(() => _isSaving = false);

    CustomSnackBar.show(
      context: context,
      message: clearing
          ? 'Disponibilità eliminata con successo!'
          : _isEditing
              ? 'Disponibilità modificata con successo!'
              : (_days.length == 1
                  ? 'Disponibilità creata con successo!'
                  : '${_days.length} disponibilità create con successo!'),
      isError: false,
    );

    if (_isEditing || _isOwn)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  String get _eyebrow
  {
    final group = widget.existingGroup;

    if (group == null)
    {
      return 'Disponibilità';
    }

    final String when = formatAvailableDayLabel(group.date);

    return _isOwn ? when : '$when · ${group.teacher.fullName}';
  }

  Widget _buildDayField()
  {
    return LessonDayField(
      days: widget.availableDays,
      values: _days,
      onChanged: _selectDays,
      summary: (count) => _groups.length > 1
          ? 'Le giornate scelte hanno orari di apertura diversi: gli orari verranno chiesti separatamente.'
          : 'Gli orari scelti varranno su tutte e $count le giornate.',
      isEnabled: _isDayOffered,
      disabledTooltip: _dayTooltip,
    );
  }

  Widget _buildAsked()
  {
    if (_isOwn)
    {
      return _buildDayField();
    }

    final teacherOptions = activeCollaborators(widget.teachers)
        .map((teacher) => SelectionOption<String>(
              value: teacher.fiscalCode,
              label: '${teacher.firstName} ${teacher.lastName}',
              leading: PersonAvatar(person: teacher, size: PersonAvatar.pickerSize),
              subtitle: teacher.taughtSubjects.isEmpty ? null : teacher.taughtSubjects.take(3).join(', '),
            ))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutocompleteField<String>(
          label: 'Docente',
          hint: 'Cerca docente...',
          icon: null,
          options: teacherOptions,
          value: _selectedTeacherTaxCode,
          onSelected: _selectTeacher,
          onCleared: () => _selectTeacher(null),
        ),
        const SizedBox(height: 20),
        _buildDayField(),
      ],
    );
  }

  Widget _buildMode(_Card card)
  {
    final group = card.group;
    final mode = card.mode;

    return BandScheduleField<AvailabilityItem>(
      schedule: _bandsOf(group)[mode]!,
      windowFor: (bucket) => _windowFor(group, mode, bucket),
      offLabel: 'Non disponibile',
      disabledLabelFor: _isOwn ? (bucket) => _shutLabelFor(group, mode, bucket) : null,
      frozen: _isEditing ? _frozen[mode]! : const {},
      onChanged: () => setState(() {}),
    );
  }

  Widget? get _daysHeader
  {
    if (_onAskedCard || _groups.length == 1)
    {
      return null;
    }

    final group = _shownCard.group;

    return AppDialogPill(
      expand: true,
      child: WizardFact(
        label: group.days.length == 1 ? 'Giornata' : 'Giornate',
        value: group.days.map(formatAvailableDayLabel).join(', '),
        maxLines: null,
      ),
    );
  }

  ({String question, String hint}) get _guide
  {
    if (_onAskedCard)
    {
      return _isOwn
          ? (
              question: 'Quando?',
              hint: 'Indica le giornate in cui sei disponibile. Puoi selezionarne anche più di una.',
            )
          : (
              question: 'Per chi e quando?',
              hint: 'Indica il docente per cui stai creando la disponibilità e i giorni. '
                  'Puoi indicare anche più giornate.',
            );
    }

    if (_shownCard.mode == kPresenceMode)
    {
      return _isOwn
          ? (
              question: 'Quando sei disponibile in presenza?',
              hint: 'Indica gli orari in cui puoi essere in Associazione per le lezioni.',
            )
          : (
              question: 'Quando è disponibile in presenza?',
              hint: 'Indica gli orari in cui il docente può essere presente in Associazione '
                  'per le lezioni.',
            );
    }

    return _isOwn
        ? (
            question: 'Quando sei disponibile online?',
            hint: 'Indica gli orari in cui puoi fare lezione a distanza.',
          )
        : (
            question: 'Quando è disponibile online?',
            hint: 'Indica gli orari in cui il docente può effettuare lezioni a distanza.',
          );
  }

  @override
  Widget build(BuildContext context)
  {
    final guide = _guide;

    return AppDialogStack(
      eyebrow: _eyebrow,
      title: _isEditing ? 'Modifica disponibilità' : 'Nuova disponibilità',
      shrinkTitle: true,
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: _isEditing ? 'SALVA' : 'CREA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _save,
        ),
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _wizardMaxWidth),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(question: guide.question, hint: guide.hint),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          header: _daysHeader,
          maxContentWidth: _wizardMaxWidth,
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < _lastCard,
          forwardBlockedReason: _blockedReason,
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(
            expand: true,
            child: _onAskedCard ? _buildAsked() : _buildMode(_shownCard),
          ),
        ),
      ],
    );
  }
}
