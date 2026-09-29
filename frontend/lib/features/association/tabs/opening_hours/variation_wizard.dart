import 'package:flutter/material.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_carousel_frame.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_segmented_tabs.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../lessons/utils/opening_window.dart';
import '../../../lessons/widgets/lessons_form_fields.dart';
import '../../../people/edit/widgets/person_edit_guide.dart';
import '../../models/weekly_template_item.dart';
import 'calendar_bounds.dart';
import 'combined_hours.dart';
import 'hours_date_field.dart';
import 'hours_drafts.dart';
import 'lost_calendars.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _wizardMaxWidth = 560;
const double _stackMaxWidth = _wizardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

// In the order the tabs show them.
enum _Change { unchanged, closed, varied }

const List<String> _changeLabels = ['Invariato', 'Chiuso', 'Orari diversi'];

class VariationWizard extends StatefulWidget
{
  final List<WeeklyTemplateItem> standardTemplates;

  final Future<void> Function() onSaved;

  final CombinedVariation? initial;

  final DateTime? day;

  const VariationWizard({
    super.key,
    required this.standardTemplates,
    required this.onSaved,
    this.initial,
    this.day,
  });

  @override
  State<VariationWizard> createState() => _VariationWizardState();
}

class _VariationWizardState extends State<VariationWizard>
{
  final ApiService _apiService = ApiService();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  // The end date follows the start date until typed in.
  bool _toTouched = false;

  final Map<String, _Change> _changes = {for (final mode in kHoursModes) mode: _Change.unchanged};

  final Map<String, BandDrafts> _bands = {
    for (final mode in kHoursModes) mode: {for (final bucket in TimeBucket.values) bucket: BandDraft()},
  };

  int _cardIndex = 0;
  bool _movingForward = true;
  bool _isSaving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState()
  {
    super.initState();

    if (widget.day case final day?)
    {
      _fromCtrl.text = formatDateString(day);
      _toCtrl.text = formatDateString(day);
    }

    final initial = widget.initial;

    if (initial == null)
    {
      return;
    }

    _fromCtrl.text = formatDateString(initial.start);
    _toCtrl.text = formatDateString(initial.end);
    _toTouched = true;
    _noteCtrl.text = initial.note ?? '';

    for (final MapEntry(key: mode, value: bands) in initial.bandsByMode.entries)
    {
      _changes[mode] = initial.isClosed(mode) ? _Change.closed : _Change.varied;

      for (final band in bands)
      {
        final bucket = bucketFor(band.startTime);

        if (bucket != null)
        {
          _bands[mode]![bucket]!
            ..start = band.startTime
            ..end = band.endTime;
        }
      }
    }
  }

  @override
  void dispose()
  {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _onAskedCard => _cardIndex == 0;

  String get _shownMode => kHoursModes[_cardIndex - 1];

  DateTime? get _from => isValidDateString(_fromCtrl.text.trim()) ? parseDateString(_fromCtrl.text.trim()) : null;

  DateTime? get _to => isValidDateString(_toCtrl.text.trim()) ? parseDateString(_toCtrl.text.trim()) : null;

  List<DateTime> get _dates
  {
    final from = _from;
    final to = _to;

    if (from == null || to == null)
    {
      return const [];
    }

    return [for (var day = from; !day.isAfter(to); day = addDays(day, 1)) day];
  }

  void _onFromChanged(String value)
  {
    if (!_toTouched)
    {
      _toCtrl.text = value;
    }
  }

  void _goToCard(int index)
  {
    setState(()
    {
      _movingForward = index > _cardIndex;
      _cardIndex = index;
    });
  }

  // "Orari diversi" starts from the first day's standard hours.
  void _choose(String mode, _Change change)
  {
    setState(()
    {
      _changes[mode] = change;

      final bands = _bands[mode]!;

      if (change == _Change.varied && !bands.values.any((band) => band.isOpen))
      {
        final from = _from;

        if (from != null)
        {
          final standard = draftsFromRows(standardRowsOf(widget.standardTemplates, from.weekday, mode));

          for (final bucket in TimeBucket.values)
          {
            bands[bucket]!
              ..start = standard[bucket]!.start
              ..end = standard[bucket]!.end;
          }
        }
      }
    });
  }

  // Null leaves the mode unchanged; an empty list, even from all bands closed, is a closure.
  List<(TimeOfDay, TimeOfDay)>? _bandsToWrite(String mode)
  {
    return switch (_changes[mode]!)
    {
      _Change.unchanged => null,
      _Change.closed => const [],
      _Change.varied => [
          for (final bucket in TimeBucket.values)
            if (_bands[mode]![bucket]!.isOpen) (_bands[mode]![bucket]!.start!, _bands[mode]![bucket]!.end!),
        ],
    };
  }

  bool _isStandardOn(DateTime day, String mode, List<(TimeOfDay, TimeOfDay)> bands)
  {
    final rows = standardRowsOf(widget.standardTemplates, day.weekday, mode);

    return TimeBucket.values.every((bucket)
    {
      final band = bands.where((band) => bucketFor(band.$1) == bucket).firstOrNull;
      final row = rows[bucket]!.firstOrNull;

      return BandDraft(start: band?.$1, end: band?.$2).matches(row?.startTime, row?.endTime);
    });
  }

  // A change matching the standard hours on every chosen day is no change.
  Map<String, List<(TimeOfDay, TimeOfDay)>> get _variedModes
  {
    final dates = _dates;

    return {
      for (final mode in kHoursModes)
        if (_bandsToWrite(mode) case final bands?)
          if (!dates.every((day) => _isStandardOn(day, mode, bands))) mode: bands,
    };
  }

  // Modes the edited variation touched that now keep their standard hours.
  List<String> get _releasedModes
  {
    final initial = widget.initial;

    if (initial == null)
    {
      return const [];
    }

    final varied = _variedModes;

    return [for (final mode in initial.bandsByMode.keys) if (!varied.containsKey(mode)) mode];
  }

  bool _validateDates()
  {
    final fromDate = _fromCtrl.text.trim();
    final toDate = _toCtrl.text.trim();

    if (!isValidDateString(fromDate))
    {
      CustomSnackBar.show(context: context, message: 'Inserisci una data di inizio valida.', isError: true);
      return false;
    }

    if (!isValidDateString(toDate))
    {
      CustomSnackBar.show(context: context, message: 'Inserisci una data di fine valida.', isError: true);
      return false;
    }

    if (parseDateString(toDate).isBefore(parseDateString(fromDate)))
    {
      CustomSnackBar.show(
        context: context,
        message: 'La data di fine deve essere uguale o successiva alla data di inizio.',
        isError: true,
      );
      return false;
    }

    if (parseDateString(fromDate).isBefore(kAssociationFoundedOn))
    {
      CustomSnackBar.show(context: context, message: kBeforeFoundationError, isError: true);
      return false;
    }

    final horizon = calendarHorizon();

    if (parseDateString(toDate).isAfter(horizon))
    {
      CustomSnackBar.show(context: context, message: beyondHorizonError(horizon), isError: true);
      return false;
    }

    return true;
  }

  bool _validate()
  {
    if (!_validateDates())
    {
      return false;
    }

    if (_variedModes.isNotEmpty || _releasedModes.isNotEmpty)
    {
      return true;
    }

    CustomSnackBar.show(
      context: context,
      message: _dates.length == 1
          ? 'Questi sono già gli orari standard del giorno scelto.'
          : 'Questi sono già gli orari standard di tutti i giorni scelti.',
      isError: true,
    );

    return false;
  }

  // Days the edited variation stops covering: all for a released mode, else the trimmed ends.
  List<(String, DateTime, DateTime)> _restorations(DateTime start, DateTime end)
  {
    final initial = widget.initial;

    if (initial == null)
    {
      return const [];
    }

    final released = _releasedModes;

    return [
      for (final mode in initial.bandsByMode.keys)
        if (released.contains(mode))
          (mode, initial.start, initial.end)
        else ...[
          if (initial.start.isBefore(start))
            (mode, initial.start, addDays(start, -1).isBefore(initial.end) ? addDays(start, -1) : initial.end),
          if (initial.end.isAfter(end))
            (mode, addDays(end, 1).isAfter(initial.start) ? addDays(end, 1) : initial.start, initial.end),
        ],
    ];
  }

  Future<void> _save() async
  {
    if (_isSaving || !_validate())
    {
      return;
    }

    setState(() => _isSaving = true);

    final dates = _dates;
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final varied = _variedModes;
    final closes = varied.values.any((bands) => bands.isEmpty);

    // Asked once for the whole save.
    final confirmation = LossConfirmation(confirmLabel: closes ? 'CHIUDI COMUNQUE' : 'SALVA COMUNQUE');

    for (final (mode, from, to) in _restorations(dates.first, dates.last))
    {
      try
      {
        final done = await confirmation.run(
          context,
          (confirm) => _apiService.restoreStandardHours(dateFrom: from, dateTo: to, mode: mode, confirm: confirm),
        );

        if (!done)
        {
          if (mounted)
          {
            setState(() => _isSaving = false);
          }

          return;
        }
      }
      catch (e)
      {
        if (mounted)
        {
          setState(() => _isSaving = false);
          CustomSnackBar.show(
            context: context,
            message: 'Impossibile aggiornare i giorni rimossi dalla variazione. Riprova.',
            isError: true,
          );
        }

        return;
      }

      if (!mounted)
      {
        return;
      }
    }

    final written = <DateTime>{};
    final errors = <String>[];

    // One call per day: delete-then-create would briefly close it, dropping its lessons and calendar.
    outer:
    for (final date in dates)
    {
      for (final MapEntry(key: mode, value: bands) in varied.entries)
      {
        if (!mounted)
        {
          return;
        }

        try
        {
          final done = await confirmation.run(
            context,
            (confirm) => _apiService.replaceOpeningDay(
              date: date,
              mode: mode,
              bands: bands,
              note: note,
              confirm: confirm,
            ),
          );

          if (done)
          {
            written.add(date);
          }
          else if (confirmation.declined)
          {
            break outer;
          }
        }
        catch (e)
        {
          errors.add('${formatDayMonthShort(date)}: ${readableApiError(e)}');
        }
      }
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (confirmation.declined && written.isEmpty && errors.isEmpty && varied.isNotEmpty)
    {
      return;
    }

    final String message;

    if (errors.isNotEmpty)
    {
      message = '${written.length}/${dates.length} giorni salvati, ${errors.length} operazioni non riuscite.';
    }
    else if (varied.isEmpty)
    {
      message = 'Variazione eliminata.';
    }
    else
    {
      final closesAll = varied.values.every((bands) => bands.isEmpty);
      final action = _isEditing ? 'Variazione' : (closesAll ? 'Chiusura' : 'Apertura');

      message = '$action applicata a ${written.length} giorn${written.length == 1 ? 'o' : 'i'}.';
    }

    CustomSnackBar.show(context: context, message: message, isError: errors.isNotEmpty);

    await widget.onSaved();

    if (mounted)
    {
      Navigator.of(context).pop();
    }
  }

  Widget _buildAsked()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HoursDateField(label: 'Dal', controller: _fromCtrl, onChanged: _onFromChanged),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HoursDateField(label: 'Al', controller: _toCtrl, onChanged: (_) => _toTouched = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _noteCtrl,
          label: 'Motivazione (opzionale)',
          hintText: 'Es. Riunione',
          maxLength: FieldLimits.notes,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildMode(String mode)
  {
    final change = _changes[mode]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedTabs(
          labels: _changeLabels,
          selectedIndex: change.index,
          padding: EdgeInsets.zero,
          onSelected: (index) => _choose(mode, _Change.values[index]),
        ),
        if (change == _Change.varied) ...[
          const SizedBox(height: 24),
          BandSliders(drafts: _bands[mode]!, onChanged: () => setState(() {})),
        ],
      ],
    );
  }

  Widget? get _header
  {
    final dates = _dates;

    if (_onAskedCard || dates.isEmpty)
    {
      return null;
    }

    return AppDialogPill(
      expand: true,
      child: WizardFact(
        label: dates.length == 1 ? 'Giornata' : 'Giornate',
        value: dates.length == 1 ? formatWeekdayColumnLabel(dates.first) : formatDateSpan(dates.first, dates.last),
      ),
    );
  }

  PersonEditGuide get _guide
  {
    if (_onAskedCard)
    {
      return const PersonEditGuide(
        question: 'Quando e perché?',
        hint: 'Indica il giorno o i giorni della variazione e, se vuoi, il motivo.',
      );
    }

    return PersonEditGuide(
      question: _shownMode == kPresenceMode ? 'Cosa cambia in presenza?' : 'Cosa cambia online?',
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: _isEditing ? 'Variazione' : 'Chiusura o apertura straordinaria',
      title: _isEditing ? 'Modifica variazione' : 'Crea variazione',
      shrinkTitle: true,
      onClose: () => Navigator.of(context).pop(),
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
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
            child: AppDialogPill(expand: true, child: _guide),
          ),
        ),
        AppCarouselFrame(
          index: _cardIndex,
          movingForward: _movingForward,
          header: _header,
          maxContentWidth: _wizardMaxWidth,
          canGoBack: _cardIndex > 0,
          canGoForward: _cardIndex < kHoursModes.length,
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(
            expand: true,
            child: _onAskedCard ? _buildAsked() : _buildMode(_shownMode),
          ),
        ),
      ],
    );
  }
}
