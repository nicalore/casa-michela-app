import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
import '../../models/opening_day_item.dart';
import '../../models/weekly_template_item.dart';
import 'calendar_bounds.dart';
import '../../../../shared/widgets/band_time_range_slider.dart';
import 'hours_date_field.dart';
import '../../../../core/utils/time_bucket.dart';
import 'variation_group.dart';

class _BandDraft
{
  TimeOfDay? start;
  TimeOfDay? end;
}

// Two phases of floating pieces, walked with the arrows beside them the way the
// days of a week are walked in the standard hours: when the variation runs, and
// what the hours are on those days. Three shut bands is how a closure is said —
// there is no separate question for it, because an answer kept beside the three
// switches that decide the same thing is a second place for it to be wrong.
//
// Doubles as the editor for an existing variation: saving already replaces
// whatever sits on the chosen dates, which is exactly what editing one means,
// so [initial] only has to prefill the form and name the span the edit started
// from.
class ExtraordinaryHoursDialog extends StatefulWidget
{
  final String mode;
  final Future<void> Function() onSaved;

  // The standard hours of this mode, week by week: what recognises a variation
  // that varies nothing. See [_variesNothing].
  final List<WeeklyTemplateItem> standardTemplates;

  // The variation being edited, or null when creating a new one.
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
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  // Wide enough for two date fields side by side, and for three bands under
  // each other on the phase after it.
  static const double _contentMaxWidth = 640;
  static const double _stackMaxWidth =
      _contentMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  final ApiService _apiService = ApiService();

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  bool _toTouched = false;

  bool _isSaving = false;

  // Which of the two phases is on screen: what and when, or the hours. The
  // second one exists only while the answer to the question is yes.
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
    // Otherwise editing "Dal" would overwrite the "Al" that was just prefilled.
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

  // The minutes of an hour, the only measure in which two times compare without
  // having to ask how they are written.
  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  // The band the standard hours give a weekday, or null where that band is
  // closed on that day. The first of its own, as the standard-hours editor does:
  // a day can carry several rows in the same band, and the one shown is the
  // earliest.
  WeeklyTemplateItem? _standardBand(int weekday, TimeBucket bucket)
  {
    final rows = widget.standardTemplates
        .where((row) => row.weekday == weekday && bucketFor(row.startTime) == bucket)
        .toList()
      ..sort((a, b) => _minutesOf(a.startTime).compareTo(_minutesOf(b.startTime)));

    return rows.firstOrNull;
  }

  // True where what is being written is, band by band, what that day already
  // does on its own.
  bool _isStandardOn(DateTime day)
  {
    for (final bucket in TimeBucket.values)
    {
      final draft = _bands[bucket]!;
      final standard = _standardBand(day.weekday, bucket);

      if (draft.start == null || draft.end == null)
      {
        // Closed here: it matches only if it is closed on its own too.
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

  // A variation repeating the standard hours on every day it covers varies
  // nothing: the day would open and close at the same times, and all that would
  // be left is one more row in the variations list, claiming a change that never
  // happened.
  //
  // A single different day is enough for the variation to mean something: it
  // goes through, and the days that already agreed end up under it too, which is
  // what whoever picks a whole range is asking for.
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

  // A variation with every band shut is a closure, and one with any band open is
  // an opening. It used to be asked outright — "sarà aperta?" — and then had to
  // agree with the three switches underneath it, which is one truth kept in two
  // places.
  bool get _isOpen
  {
    return TimeBucket.values.any((b) => _bands[b]!.start != null && _bands[b]!.end != null);
  }

  // Puts back the standard hours on the days the edit no longer covers, at
  // either end of the original span. Returns false if any of it failed, in
  // which case the caller stops rather than writing a half-moved variation.
  Future<bool> _releaseDroppedDays(DateTime startDate, DateTime endDate, List<String> errors) async
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
      try
      {
        await _apiService.restoreStandardHours(dateFrom: from, dateTo: to, mode: widget.mode);
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

    // An edit that shrinks the span leaves the dropped days still carrying the
    // old variation: nothing below would touch them, since the writes only
    // cover the new range. Done first, so a later failure cannot leave them
    // half-changed instead of simply untouched.
    if (!await _releaseDroppedDays(startDate, endDate, errors))
    {
      setState(() => _isSaving = false);

      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Impossibile aggiornare i giorni rimossi dalla variazione. Riprova.',
          isError: true,
        );
      }

      return;
    }

    // Both paths replace whatever is already on those dates, so both need to
    // know what is there first; failing to read it means we cannot safely
    // clear, hence the hard stop rather than a partial write.
    List<OpeningDayItem> primaryExisting;

    try
    {
      primaryExisting = await _apiService.getOpeningDays(dateFrom: startDate, dateTo: endDate, mode: widget.mode);
    }
    catch (e)
    {
      setState(() => _isSaving = false);

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: 'Impossibile leggere gli orari esistenti. Riprova.', isError: true);
      }

      return;
    }

    if (!_isOpen)
    {
      for (final date in dates)
      {
        try
        {
          for (final row in primaryExisting.where((d) => isSameDate(d.date, date)))
          {
            await _apiService.deleteOpeningDay(row.id);
          }

          // A row with no hours is what "chiuso" is on this table.
          await _apiService.createOpeningDay(date: date, mode: widget.mode, note: note);
          successCount++;
        }
        catch (e)
        {
          errors.add('${formatDayMonthShort(date)}: ${readableApiError(e)}');
        }
      }
    }
    else
    {
      final filledBands = TimeBucket.values.where((b) => _bands[b]!.start != null && _bands[b]!.end != null).toList();

      for (final date in dates)
      {
        var dateFailed = false;

        for (final row in primaryExisting.where((d) => isSameDate(d.date, date)))
        {
          try
          {
            await _apiService.deleteOpeningDay(row.id);
          }
          catch (e)
          {
            errors.add('${formatDayMonthShort(date)}: ${readableApiError(e)}');
            dateFailed = true;
          }
        }

        for (final bucket in filledBands)
        {
          final band = _bands[bucket]!;

          try
          {
            await _apiService.createOpeningDay(
              date: date,
              mode: widget.mode,
              startTime: band.start,
              endTime: band.end,
              note: note,
            );
          }
          catch (e)
          {
            errors.add('${formatDayMonthShort(date)}: ${readableApiError(e)}');
            dateFailed = true;
          }
        }

        if (!dateFailed)
        {
          successCount++;
        }
      }
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

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

  // When and, if it matters, what to call it.
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
            label: 'Nota (opzionale)',
            hintText: 'Es. Riunione',
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
          // What used to be a question at the top of the dialog. Said here, it
          // is a note about the three switches right above it rather than an
          // answer that then has to agree with them.
          Text(
            _isOpen
                ? 'I giorni scelti apriranno con questi orari.'
                : 'Se tutte e tre le fasce orarie sono chiuse, l\'Associazione sarà chiusa per quel '
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
