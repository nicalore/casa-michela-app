import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/field_limits.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_carousel_frame.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../models/weekly_template_item.dart';
import 'calendar_bounds.dart';
import '../../../../shared/widgets/band_time_range_slider.dart';
import 'hours_date_field.dart';
import 'lost_calendars.dart';
import '../../../../core/utils/time_bucket.dart';
import 'variation_group.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

class _BandDraft
{
  TimeOfDay? start;
  TimeOfDay? end;
}

class ExtraordinaryHoursDialog extends StatefulWidget
{
  final String mode;
  final Future<void> Function() onSaved;

  final List<WeeklyTemplateItem> standardTemplates;

  final VariationGroup? initial;

  const ExtraordinaryHoursDialog({
    super.key,
    required this.mode,
    required this.onSaved,
    this.standardTemplates = const [],
    this.initial,
  });

  @override
  State<ExtraordinaryHoursDialog> createState() => _ExtraordinaryHoursDialogState();
}

class _ExtraordinaryHoursDialogState extends State<ExtraordinaryHoursDialog>
{
  static const double _contentMaxWidth = 640;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  final ApiService _apiService = ApiService();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _toTouched = false;

  bool _isSaving = false;

  int _phase = 0;
  bool _movingForward = true;

  final Map<TimeBucket, _BandDraft> _bands = {
    for (final bucket in TimeBucket.values) bucket: _BandDraft(),
  };

  bool get _isEditing => widget.initial != null;

  @override
  void initState()
  {
    super.initState();

    final initial = widget.initial;

    if (initial == null)
    {
      return;
    }

    _fromCtrl.text = formatDateString(initial.start);
    _toCtrl.text = formatDateString(initial.end);
    _toTouched = true;
    _noteCtrl.text = initial.note ?? '';

    for (final band in initial.bands)
    {
      final bucket = bucketFor(band.startTime);

      if (bucket != null)
      {
        _bands[bucket]!.start = band.startTime;
        _bands[bucket]!.end = band.endTime;
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

  void _closeDialog()
  {
    Navigator.of(context).pop();
  }

  void _onFromChanged(String value)
  {
    if (!_toTouched)
    {
      _toCtrl.text = value;
    }
  }

  void _onToChanged(String value)
  {
    _toTouched = true;
  }

  bool _validate()
  {
    return _validateDates() && _validateVariesSomething();
  }

  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  WeeklyTemplateItem? _standardBand(int weekday, TimeBucket bucket)
  {
    final rows = widget.standardTemplates
        .where((row) => row.weekday == weekday && bucketFor(row.startTime) == bucket)
        .toList()
      ..sort((a, b) => _minutesOf(a.startTime).compareTo(_minutesOf(b.startTime)));

    return rows.firstOrNull;
  }

  bool _isStandardOn(DateTime day)
  {
    for (final bucket in TimeBucket.values)
    {
      final draft = _bands[bucket]!;
      final standard = _standardBand(day.weekday, bucket);

      if (draft.start == null || draft.end == null)
      {
        if (standard != null)
        {
          return false;
        }

        continue;
      }

      if (standard == null ||
          _minutesOf(draft.start!) != _minutesOf(standard.startTime) ||
          _minutesOf(draft.end!) != _minutesOf(standard.endTime))
      {
        return false;
      }
    }

    return true;
  }

  bool _variesNothing(DateTime from, DateTime to)
  {
    var cursor = from;

    while (!cursor.isAfter(to))
    {
      if (!_isStandardOn(cursor))
      {
        return false;
      }

      cursor = addDays(cursor, 1);
    }

    return true;
  }

  bool _validateVariesSomething()
  {
    final DateTime from = parseDateString(_fromCtrl.text.trim());
    final DateTime to = parseDateString(_toCtrl.text.trim());

    if (!_variesNothing(from, to))
    {
      return true;
    }

    CustomSnackBar.show(
      context: context,
      message: isSameDate(from, to)
          ? 'Questi sono già gli orari standard del giorno scelto.'
          : 'Questi sono già gli orari standard di tutti i giorni scelti.',
      isError: true,
    );

    return false;
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

  void _goToPhase(int phase)
  {
    setState(()
    {
      _movingForward = phase > _phase;
      _phase = phase;
    });
  }

  Future<void> _submit() async
  {
    if (!_validate())
    {
      return;
    }

    await _save();
  }

  bool get _isOpen
  {
    return TimeBucket.values.any((b) => _bands[b]!.start != null && _bands[b]!.end != null);
  }

  // Restores standard hours on days the edited variation no longer covers.
  // Shares the caller's LossConfirmation so the question is asked only once.
  Future<bool> _releaseDroppedDays(
    DateTime startDate,
    DateTime endDate,
    List<String> errors,
    LossConfirmation confirmation,
  ) async
  {
    final initial = widget.initial;

    if (initial == null)
    {
      return true;
    }

    final dropped = <(DateTime, DateTime)>[
      if (initial.start.isBefore(startDate))
        (initial.start, addDays(startDate, -1).isBefore(initial.end) ? addDays(startDate, -1) : initial.end),
      if (initial.end.isAfter(endDate))
        (addDays(endDate, 1).isAfter(initial.start) ? addDays(endDate, 1) : initial.start, initial.end),
    ];

    for (final (from, to) in dropped)
    {
      if (!mounted)
      {
        return false;
      }

      try
      {
        final done = await confirmation.run(
          context,
          (confirm) => _apiService.restoreStandardHours(
            dateFrom: from,
            dateTo: to,
            mode: widget.mode,
            confirm: confirm,
          ),
        );

        if (!done)
        {
          return false;
        }
      }
      catch (e)
      {
        errors.add(readableApiError(e));

        return false;
      }
    }

    return true;
  }

  Future<void> _save() async
  {
    setState(() => _isSaving = true);

    final startDate = parseDateString(_fromCtrl.text.trim());
    final endDate = parseDateString(_toCtrl.text.trim());
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    final dates = <DateTime>[];
    var cursor = startDate;

    while (!cursor.isAfter(endDate))
    {
      dates.add(cursor);
      cursor = addDays(cursor, 1);
    }

    var successCount = 0;
    final errors = <String>[];

    // A closure is a day with no bands.
    final List<(TimeOfDay, TimeOfDay)> bands = !_isOpen
        ? const []
        : [
            for (final bucket in TimeBucket.values)
              if (_bands[bucket]!.start != null && _bands[bucket]!.end != null)
                (_bands[bucket]!.start!, _bands[bucket]!.end!),
          ];

    // The server refuses writes that would drop published calendars or given
    // hours until confirmed — asked once for the whole save.
    final confirmation = LossConfirmation(
      confirmLabel: _isOpen ? 'SALVA COMUNQUE' : 'CHIUDI COMUNQUE',
    );

    if (!await _releaseDroppedDays(startDate, endDate, errors, confirmation))
    {
      setState(() => _isSaving = false);

      if (mounted && !confirmation.declined)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Impossibile aggiornare i giorni rimossi dalla variazione. Riprova.',
          isError: true,
        );
      }

      return;
    }

    // Each day is written whole in one call: delete-then-create would leave it
    // momentarily closed, taking its lessons and published calendar with it.
    for (final date in dates)
    {
      if (!mounted)
      {
        return;
      }

      try
      {
        final written = await confirmation.run(
          context,
          (confirm) => _apiService.replaceOpeningDay(
            date: date,
            mode: widget.mode,
            bands: bands,
            note: note,
            confirm: confirm,
          ),
        );

        if (written)
        {
          successCount++;
        }
        else if (confirmation.declined)
        {
          break;
        }
      }
      catch (e)
      {
        errors.add('${formatDayMonthShort(date)}: ${readableApiError(e)}');
      }
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    // Declined before anything was written: nothing to report, dialog stays open.
    if (confirmation.declined && successCount == 0 && errors.isEmpty)
    {
      return;
    }

    final actionLabel = _isEditing ? 'Variazione' : (_isOpen ? 'Apertura' : 'Chiusura');
    final baseMessage = errors.isEmpty
        ? '$actionLabel applicata a $successCount giorn${successCount == 1 ? 'o' : 'i'}.'
        : '$successCount/${dates.length} giorni salvati, ${errors.length} operazioni non riuscite.';

    CustomSnackBar.show(
      context: context,
      message: baseMessage,
      isError: errors.isNotEmpty,
    );

    if (successCount > 0)
    {
      await widget.onSaved();
    }

    if (mounted)
    {
      Navigator.of(context).pop();
    }
  }

  Widget _buildWhenPill()
  {
    return AppDialogPill(
      child: Column(
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
                child: HoursDateField(label: 'Al', controller: _toCtrl, onChanged: _onToChanged),
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
      ),
    );
  }

  Widget _buildBandsPill()
  {
    return AppDialogPill(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bucket in TimeBucket.values) ...[
            BandTimeRangeSlider(
              bucket: bucket,
              startTime: _bands[bucket]!.start,
              endTime: _bands[bucket]!.end,
              onChanged: (start, end) => setState(()
              {
                _bands[bucket]!.start = start;
                _bands[bucket]!.end = end;
              }),
            ),
            if (bucket != TimeBucket.values.last)
              const Divider(height: 33, thickness: 1, color: AppTheme.trialLine),
          ],
          const SizedBox(height: 20),
          Text(
            _isOpen
                ? 'I giorni scelti apriranno con questi orari.'
                : 'Se mattina, pomeriggio e sera sono tutte chiuse, l\'Associazione sarà chiusa per quel '
                    'giorno.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhases()
  {
    return AppCarouselFrame(
      index: _phase,
      movingForward: _movingForward,
      maxContentWidth: _contentMaxWidth,
      canGoBack: _phase > 0,
      canGoForward: _phase == 0,
      onBack: () => _goToPhase(0),
      onForward: () => _goToPhase(1),
      child: _phase == 0 ? _buildWhenPill() : _buildBandsPill(),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final modeLabel = widget.mode == 'presence' ? 'In presenza' : 'Online';

    return AppDialogStack(
      eyebrow: _isEditing ? 'Variazione' : 'Chiusura o apertura straordinaria',
      title: _isEditing
          ? 'Modifica variazione — $modeLabel'
          : 'Crea variazione — $modeLabel',
      onClose: _closeDialog,
      maxWidth: _stackMaxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: 'SALVA',
          icon: Icons.check_rounded,
          busy: _isSaving,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: _submit,
        ),
      ),
      children: [_buildPhases()],
    );
  }
}
