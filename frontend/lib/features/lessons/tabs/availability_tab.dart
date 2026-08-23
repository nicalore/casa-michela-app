import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../../core/utils/time_bucket.dart';
import '../../association/models/opening_day_item.dart';
import '../../people/models/person_item.dart';
import '../models/availability_group.dart';
import '../models/availability_item.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import '../widgets/availability_card.dart';
import '../widgets/band_schedule.dart';
import '../widgets/lesson_day_field.dart';
import '../widgets/lessons_closed_day.dart';
import '../widgets/person_avatar.dart';
import '../widgets/lessons_form_fields.dart';
import '../widgets/lessons_toolbar.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _wizardMaxWidth = 560;
const double _stackMaxWidth =
    _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

class AvailabilityTab extends StatefulWidget
{
  final List<AvailabilityItem> availabilities;
  final List<PersonItem> teachers;

  final List<DateTime> availableDays;
  final DateTime selectedDay;

  final List<OpeningDayItem> openingDays;

  final LessonsDayView view;
  final ValueChanged<LessonsDayView> onViewSelected;

  final Future<bool> Function(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreate;
  final Future<bool> Function(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEdit;

  final Future<bool> Function(AvailabilityItem item, Function(String) onError) onDeleteSlot;
  final void Function(List<AvailabilityItem> slots) onDeleteGroup;

  const AvailabilityTab({
    super.key,
    required this.availabilities,
    required this.teachers,
    required this.availableDays,
    required this.selectedDay,
    required this.openingDays,
    required this.view,
    required this.onViewSelected,
    required this.onCreate,
    required this.onEdit,
    required this.onDeleteSlot,
    required this.onDeleteGroup,
  });

  @override
  State<AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<AvailabilityTab>
{
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String? _filterMode;
  TimeBucket? _filterBucket;

  Set<String> _filterSubjects = {};

  bool get _hasFilters => _filterMode != null || _filterBucket != null || _filterSubjects.isNotEmpty;

  List<AvailabilityGroup> get _dayGroups
  {
    final selectedDay = widget.selectedDay;

    final onTheDay = widget.availabilities
        .where((availability) => isSameDate(availability.date, selectedDay))
        .toList();

    final groups = groupAvailabilities(onTheDay);

    groups.sort((a, b)
    {
      final startComparison = a.startMinutes.compareTo(b.startMinutes);

      if (startComparison != 0)
      {
        return startComparison;
      }

      return a.teacher.fullName.compareTo(b.teacher.fullName);
    });

    return groups;
  }

  List<AvailabilityGroup> get _filteredGroups
  {
    final query = _searchText.toLowerCase();

    return _dayGroups
        .where((group) =>
            group.teacher.fullName.toLowerCase().contains(query) && _matchesFilters(group))
        .toList();
  }

  List<String> _subjectsOf(String teacherTaxCode)
  {
    for (final teacher in widget.teachers)
    {
      if (teacher.fiscalCode == teacherTaxCode)
      {
        return teacher.taughtSubjects;
      }
    }

    return const [];
  }

  List<String> get _subjectOptions
  {
    final subjects = <String>{};

    for (final group in _dayGroups)
    {
      subjects.addAll(_subjectsOf(group.teacherTaxCode));
    }

    final sorted = subjects.toList()..sort();

    return sorted;
  }

  bool _matchesFilters(AvailabilityGroup group)
  {
    if (_filterSubjects.isNotEmpty &&
        !_subjectsOf(group.teacherTaxCode).any(_filterSubjects.contains))
    {
      return false;
    }

    if (_filterMode == null && _filterBucket == null)
    {
      return true;
    }

    return group.slots.any((slot) =>
        (_filterMode == null || slot.mode == _filterMode) &&
        (_filterBucket == null || bucketFor(slot.startTime) == _filterBucket));
  }

  @override
  void didUpdateWidget(AvailabilityTab oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_filterSubjects.isNotEmpty)
    {
      final available = _subjectOptions.toSet();

      _filterSubjects = _filterSubjects.where(available.contains).toSet();
    }
  }

  String get _emptyMessage
  {
    if (_hasFilters)
    {
      return 'Nessuna disponibilità corrisponde ai filtri scelti.';
    }

    if (_searchText.isNotEmpty)
    {
      return 'Nessun docente trovato in questa giornata.';
    }

    return 'Nessuna disponibilità in questa giornata.';
  }

  Widget _buildFilters()
  {
    final subjects = _subjectOptions;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppFilterPill<String>.filter(
          prefix: 'Modalità',
          hint: 'Presenza e online',
          icon: Icons.devices_outlined,
          value: _filterMode,
          menuWidth: 190,
          onChanged: (value) => setState(() => _filterMode = value),
          onClear: () => setState(() => _filterMode = null),
          options: [
            for (final mode in const [kPresenceMode, kOnlineMode])
              FilterOption(value: mode, label: modeLabel(mode)),
          ],
        ),
        AppFilterPill<TimeBucket>.filter(
          prefix: 'Quando',
          hint: 'Tutta la giornata',
          icon: Icons.schedule_rounded,
          value: _filterBucket,
          menuWidth: 190,
          onChanged: (value) => setState(() => _filterBucket = value),
          onClear: () => setState(() => _filterBucket = null),
          options: [
            for (final bucket in TimeBucket.values)
              FilterOption(value: bucket, label: bandLabel(bucket)),
          ],
        ),
        if (subjects.isNotEmpty)
          AppCountFilterPill(
            label: 'Discipline',
            icon: Icons.auto_stories_outlined,
            count: _filterSubjects.length,
            onOpen: () => _showSubjectFilterDialog(subjects),
            onClear: () => setState(() => _filterSubjects = {}),
          ),
      ],
    );
  }

  void _showSubjectFilterDialog(List<String> subjects)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => MultiSelectFilterDialog<String>(
        title: 'Filtra per disciplina interna',
        hint: 'Es. Aritmetica',
        options: [
          for (final subject in subjects)
            MultiSelectFilterOption(value: subject, label: subject),
        ],
        initialSelected: _filterSubjects,
        onApply: (selected) => setState(() => _filterSubjects = selected),
      ),
    );
  }

  void _showWizard({AvailabilityGroup? group, VoidCallback? onCancelEdit})
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'AvailabilityWizard',
      builder: (context) => _AvailabilityWizardDialog(
        existingGroup: group,
        teachers: widget.teachers,
        availableDays: widget.availableDays,
        defaultDate: widget.selectedDay,
        availabilities: widget.availabilities,
        openingDays: widget.openingDays,
        onCancelEdit: onCancelEdit,
        onCreate: widget.onCreate,
        onEdit: widget.onEdit,
        onDeleteSlot: widget.onDeleteSlot,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (!isOpenOn(widget.openingDays, widget.selectedDay, kPresenceMode) &&
        !isOpenOn(widget.openingDays, widget.selectedDay, kOnlineMode))
    {
      return LessonsClosedDay(
        day: widget.selectedDay,
        message: '',
        leftovers: [
          for (final group in _dayGroups)
            AvailabilityCard(
              group: group,
              onEditRequested: (onCancel) => _showWizard(group: group, onCancelEdit: onCancel),
              onDelete: () => widget.onDeleteGroup(group.slots),
            ),
        ],
      );
    }

    final groups = _filteredGroups;

    return TabContent(
      header: [
        LessonsToolbar(
          view: widget.view,
          onViewSelected: widget.onViewSelected,
          searchController: _searchController,
          onSearchChanged: (value) => setState(() => _searchText = value),
          searchHint: 'Cerca docente...',
          actionLabel: 'NUOVA DISPONIBILITÀ',
          onAction: _showWizard,
        ),
        const SizedBox(height: 20),
        _buildFilters(),
        const SizedBox(height: 28),
      ],
      body: groups.isEmpty
          ? PageTransitionItem(
              slot: PageTransitionItem.list,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    _emptyMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.trialMutedText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          : EntityCardGrid(
              children: [
                for (final group in groups)
                  AvailabilityCard(
                    group: group,
                    onEditRequested: (onCancel) => _showWizard(group: group, onCancelEdit: onCancel),
                    onDelete: () => widget.onDeleteGroup(group.slots),
                  ),
              ],
            ),
    );
  }
}

class _AvailabilityWizardDialog extends StatefulWidget
{
  final AvailabilityGroup? existingGroup;

  final List<PersonItem> teachers;
  final List<DateTime> availableDays;
  final DateTime defaultDate;

  final List<AvailabilityItem> availabilities;

  final List<OpeningDayItem> openingDays;

  final VoidCallback? onCancelEdit;
  final Future<bool> Function(String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onCreate;
  final Future<bool> Function(AvailabilityItem existing, String teacherTaxCode, DateTime date, String mode, TimeOfDay startTime, TimeOfDay endTime, Function(String) onError) onEdit;
  final Future<bool> Function(AvailabilityItem item, Function(String) onError) onDeleteSlot;

  const _AvailabilityWizardDialog({
    this.existingGroup,
    required this.teachers,
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
  State<_AvailabilityWizardDialog> createState() => _AvailabilityWizardDialogState();
}

class _AvailabilityWizardDialogState extends State<_AvailabilityWizardDialog>
{
  String? _selectedTeacherTaxCode;

  Set<DateTime> _days = {};

  final Map<String, BandSchedule<AvailabilityItem>> _bands = {
    for (final mode in const [kPresenceMode, kOnlineMode]) mode: BandSchedule<AvailabilityItem>(),
  };

  bool _isSaving = false;

  int _cardIndex = 0;
  bool _movingForward = true;

  final Set<Object> _saved = {};

  bool get _isEditing => widget.existingGroup != null;

  static const List<String> _modes = [kPresenceMode, kOnlineMode];

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

  OpeningWindow? _windowFor(String mode, TimeBucket bucket)
  {
    if (_days.isEmpty)
    {
      return null;
    }

    return sharedOpeningWindow(widget.openingDays, _sortedDays, mode, bucket);
  }

  List<String> _openModesOn(DateTime day)
  {
    return _modes.where((mode) => isOpenOn(widget.openingDays, day, mode)).toList();
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
    if (_openModesOn(day).isEmpty)
    {
      return "L'associazione è chiusa ${formatAvailableDayLabel(day).toLowerCase()}.";
    }

    final teacher = _selectedTeacher;
    final name = teacher == null ? 'Il docente' : '${teacher.firstName} ${teacher.lastName}';

    return '$name ha già una disponibilità ${formatAvailableDayLabel(day).toLowerCase()}: '
        'aprila per cambiarne gli orari.';
  }

  @override
  void initState()
  {
    super.initState();

    final group = widget.existingGroup;

    if (group != null)
    {
      _selectedTeacherTaxCode = group.teacherTaxCode;
      _days = {group.date};

      for (final slot in group.slots)
      {
        final bucket = bucketFor(slot.startTime);

        if (bucket != null)
        {
          _bands[slot.mode]!.addStored(
            bucket,
            BandStretch<AvailabilityItem>(
              startTime: slot.startTime,
              endTime: slot.endTime,
              existing: slot,
            ),
          );
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
    for (final mode in _modes)
    {
      _bands[mode]!.reconcile((bucket) => _windowFor(mode, bucket));
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
      _selectedTeacherTaxCode = null;
      _days = {widget.defaultDate};

      for (final schedule in _bands.values)
      {
        schedule.clear();
      }

      _saved.clear();
      _cardIndex = 0;
      _movingForward = false;
    });
  }

  String? get _blockedReason
  {
    if (_cardIndex == 0 && _selectedTeacherTaxCode == null)
    {
      return 'Scegli il docente per andare avanti.';
    }

    if (_cardIndex == 0 && !_isEditing && _days.isEmpty)
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

  bool get _hasAnyBand => _modes.any((mode) => _bands[mode]!.isNotEmpty);

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

    if (!_hasAnyBand)
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

    for (final day in _sortedDays)
    {
      for (final mode in _modes)
      {
        final givesBands = _bands[mode]!.isNotEmpty;

        if (givesBands && _isTakenBy(teacherTaxCode, day, mode))
        {
          CustomSnackBar.show(
            context: context,
            message: 'Il docente ha già una disponibilità ${modeLabel(mode).toLowerCase()} '
                '${formatAvailableDayLabel(day).toLowerCase()}: aprila per cambiarne gli orari.',
            isError: true,
          );

          return;
        }
      }
    }

    setState(()
    {
      _isSaving = true;

      for (final schedule in _bands.values)
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

    for (final item in _modes.expand((mode) => _bands[mode]!.dropped))
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

    for (final day in _sortedDays)
    {
      for (final mode in _modes)
      {
        {
          for (final draft in _bands[mode]!.all)
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
      message: _isEditing
          ? 'Disponibilità modificata con successo!'
          : (_days.length == 1
              ? 'Disponibilità creata con successo!'
              : '${_days.length} disponibilità create con successo!'),
      isError: false,
    );

    if (_isEditing)
    {
      Navigator.of(context).pop();
    }
    else
    {
      _resetForm();
    }
  }

  Widget _buildFixedFacts()
  {
    final group = widget.existingGroup!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: WizardFact(label: 'Docente', value: group.teacher.fullName)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: WizardFact(label: 'Giornata', value: formatAvailableDayLabel(group.date))),
      ],
    );
  }

  Widget _buildAsked()
  {
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
        LessonDayField(
          days: widget.availableDays,
          values: _days,
          onChanged: _selectDays,
          summary: (count) => 'Gli orari scelti varranno su tutte e $count le giornate.',
          isEnabled: _isDayOffered,
          disabledTooltip: _dayTooltip,
        ),
      ],
    );
  }

  Widget _buildMode(String mode)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            modeLabel(mode).toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.trialMutedText,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1.4,
            ),
          ),
        ),
        BandScheduleField<AvailabilityItem>(
          schedule: _bands[mode]!,
          windowFor: (bucket) => _windowFor(mode, bucket),
          offLabel: 'Non disponibile',
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Disponibilità',
      title: _isEditing ? 'Modifica disponibilità' : 'Nuova disponibilità',
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
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          maxContentWidth: _wizardMaxWidth,
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < _modes.length,
          forwardBlockedReason: _blockedReason,
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(
            expand: true,
            child: _cardIndex == 0
                ? (_isEditing ? _buildFixedFacts() : _buildAsked())
                : _buildMode(_modes[_cardIndex - 1]),
          ),
        ),
      ],
    );
  }
}
