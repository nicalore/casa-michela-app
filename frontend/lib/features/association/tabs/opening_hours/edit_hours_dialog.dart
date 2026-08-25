import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_carousel_frame.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_field_label.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_selectable_chip.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../models/weekly_template_item.dart';
import 'calendar_bounds.dart';
import '../../../../shared/widgets/band_time_range_slider.dart';
import 'hours_date_field.dart';
import 'lost_calendars.dart';
import '../../../../core/utils/time_bucket.dart';

class _BandDraft
{
  TimeOfDay? start;
  TimeOfDay? end;
}

// Day-by-day editor for the recurring weekly_templates of one mode: one wizard
// step per weekday, navigated with the same arrows the weekly table uses, but
// with a single always-reachable Save rather than a step-gated flow. Save always
// commits the diff across every cell, whichever weekday is on screen.
class EditHoursDialog extends StatefulWidget
{
  final String mode;
  final List<WeeklyTemplateItem> currentTemplates;
  final Future<void> Function() onSaved;

  const EditHoursDialog({
    super.key,
    required this.mode,
    required this.currentTemplates,
    required this.onSaved,
  });

  @override
  State<EditHoursDialog> createState() => _EditHoursDialogState();
}

class _EditHoursDialogState extends State<EditHoursDialog>
{
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  // The day card at its most generous — the width the whole dialog used to be.
  static const double _cardMaxWidth = 760;

  // The stack is the card plus an arrow and its gap on either side.
  static const double _stackMaxWidth =
      _cardMaxWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap);

  final ApiService _apiService = ApiService();

  // Seeded once in initState, read-only afterwards — the diff baseline.
  //
  // A list per band, not one entry: nothing stops a weekday from carrying two
  // templates that fall in the same one. Keeping only the last left the others
  // invisible here and therefore never deleted, so they went on materialising
  // their old hours next to the new ones — a day moved from afternoon to
  // morning came back showing both.
  final Map<int, Map<TimeBucket, List<WeeklyTemplateItem>>> _originals = {};
  final Map<int, Map<TimeBucket, _BandDraft>> _drafts = {};

  final TextEditingController _effectiveFromCtrl = TextEditingController();

  int _currentWeekday = 1;
  bool _movingForward = true;
  bool _isSaving = false;

  // Days ticked to receive a copy of the one on screen. Cleared once the copy
  // has been made, and whenever the carousel moves: they were chosen against
  // the day that was showing.
  final Set<int> _copyTargets = {};

  @override
  void initState()
  {
    super.initState();
    _seedFromCurrentTemplates();

    _effectiveFromCtrl.text = formatDateString(DateTime.now());
  }

  @override
  void dispose()
  {
    _effectiveFromCtrl.dispose();
    super.dispose();
  }

  void _seedFromCurrentTemplates()
  {
    for (var weekday = 1; weekday <= 7; weekday++)
    {
      final byBucket = {for (final bucket in TimeBucket.values) bucket: <WeeklyTemplateItem>[]};

      for (final template in widget.currentTemplates.where((t) => t.weekday == weekday))
      {
        final bucket = bucketFor(template.startTime);

        if (bucket != null)
        {
          byBucket[bucket]!.add(template);
        }
      }

      for (final templates in byBucket.values)
      {
        templates.sort((a, b) => _minutesOf(a.startTime).compareTo(_minutesOf(b.startTime)));
      }

      _originals[weekday] = byBucket;

      // The earliest of a band is the one the field shows and the one an edit
      // rewrites; any others are duplicates the save clears out.
      _drafts[weekday] = {
        for (final bucket in TimeBucket.values)
          bucket: _BandDraft()
            ..start = byBucket[bucket]!.firstOrNull?.startTime
            ..end = byBucket[bucket]!.firstOrNull?.endTime,
      };
    }
  }

  void _closeDialog()
  {
    Navigator.of(context).pop();
  }

  bool _validate()
  {
    if (!isValidDateString(_effectiveFromCtrl.text.trim()))
    {
      CustomSnackBar.show(
        context: context,
        message: 'Inserisci una data di decorrenza valida.',
        isError: true,
      );

      return false;
    }

    if (parseDateString(_effectiveFromCtrl.text.trim()).isBefore(kAssociationFoundedOn))
    {
      CustomSnackBar.show(context: context, message: kBeforeFoundationError, isError: true);

      return false;
    }

    final horizon = calendarHorizon();

    if (parseDateString(_effectiveFromCtrl.text.trim()).isAfter(horizon))
    {
      CustomSnackBar.show(context: context, message: beyondHorizonError(horizon), isError: true);

      return false;
    }

    for (var weekday = 1; weekday <= 7; weekday++)
    {
      for (final bucket in TimeBucket.values)
      {
        final draft = _drafts[weekday]![bucket]!;

        if ((draft.start == null) != (draft.end == null))
        {
          CustomSnackBar.show(
            context: context,
            message:
                'Completa sia l\'orario di inizio sia quello di fine per ${weekdayFullName(weekday)} – ${bandLabel(bucket)}.',
            isError: true,
          );

          return false;
        }
      }
    }

    return true;
  }

  Future<void> _save() async
  {
    if (!_validate())
    {
      return;
    }

    setState(() => _isSaving = true);

    final effectiveFrom = parseDateString(_effectiveFromCtrl.text.trim());
    var successCount = 0;
    final errors = <String>[];

    // A decorrenza reaches days that may already have their calendar out, and a
    // band the new hours no longer open loses it. The server refuses those
    // writes until the cost has been put to whoever asked for them — once for
    // the whole save, however many rows it is made of.
    final confirmation = LossConfirmation();

    for (var weekday = 1; weekday <= 7 && !confirmation.declined; weekday++)
    {
      for (final bucket in TimeBucket.values)
      {
        if (confirmation.declined || !mounted)
        {
          break;
        }

        final originals = _originals[weekday]![bucket]!;
        final draft = _drafts[weekday]![bucket]!;
        final hasEdit = draft.start != null && draft.end != null;

        try
        {
          if (!hasEdit && originals.isEmpty)
          {
            continue;
          }

          if (hasEdit && originals.isEmpty)
          {
            if (await confirmation.run(
              context,
              (confirm) => _apiService.createWeeklyTemplate(
                weekday: weekday,
                mode: widget.mode,
                startTime: draft.start!,
                endTime: draft.end!,
                effectiveFrom: effectiveFrom,
                confirm: confirm,
              ),
            ))
            {
              successCount++;
            }
          }
          else if (hasEdit)
          {
            // Sent even when the hours are untouched: the decorrenza is an
            // input too, so "these hours, from this date" must be re-applied
            // to materialise the days that date now covers. Skipping the call
            // when only the date changed left the calendar untouched while
            // still reporting success.
            if (await confirmation.run(
              context,
              (confirm) => _apiService.updateWeeklyTemplate(
                id: originals.first.id,
                startTime: draft.start!,
                endTime: draft.end!,
                effectiveFrom: effectiveFrom,
                confirm: confirm,
              ),
            ))
            {
              successCount++;
            }
          }

          // Whatever the band still holds beyond the one row the field edits.
          // Withdrawn in both branches: a band cleared has to lose all of them,
          // and a band rewritten keeps only the row it was rewritten into.
          for (final duplicate in originals.skip(hasEdit ? 1 : 0))
          {
            if (!mounted)
            {
              break;
            }

            if (await confirmation.run(
              context,
              (confirm) => _apiService.deleteWeeklyTemplate(
                duplicate.id,
                effectiveFrom: effectiveFrom,
                confirm: confirm,
              ),
            ))
            {
              successCount++;
            }
          }
        }
        catch (e)
        {
          errors.add('${weekdayFullName(weekday)} ${bandLabel(bucket)}: ${readableApiError(e)}');
        }
      }
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    // Turned back at the question about what the change would take away, with
    // nothing written: there is nothing to report, and the window stays open on
    // the hours that were typed into it.
    if (confirmation.declined && successCount == 0 && errors.isEmpty)
    {
      return;
    }

    // A bare count says nothing about what went wrong, so the first failure
    // travels with it — the rest are only summarised. And an empty schedule
    // saved over an empty schedule is not a success worth claiming.
    final message = errors.isNotEmpty
        ? '$successCount modifiche salvate, ${errors.length} non riuscite. ${errors.first}'
            '${errors.length > 1 ? ' (e altre ${errors.length - 1})' : ''}'
        : successCount == 0
            ? 'Nessun orario da salvare.'
            : 'Orario aggiornato con successo.';

    CustomSnackBar.show(context: context, message: message, isError: errors.isNotEmpty);

    if (successCount > 0)
    {
      await widget.onSaved();
    }

    if (mounted)
    {
      Navigator.of(context).pop();
    }
  }

  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  void _goToPreviousDay()
  {
    setState(()
    {
      _movingForward = false;
      _currentWeekday--;
      _copyTargets.clear();
    });
  }

  void _goToNextDay()
  {
    setState(()
    {
      _movingForward = true;
      _currentWeekday++;
      _copyTargets.clear();
    });
  }

  // The three bands of the day on screen, written over the days ticked below
  // it. A week is usually one timetable said seven times, and typing it out
  // seven times is what made this dialog long.
  void _copyToSelectedDays()
  {
    final source = _drafts[_currentWeekday]!;
    final count = _copyTargets.length;

    setState(()
    {
      for (final target in _copyTargets)
      {
        for (final bucket in TimeBucket.values)
        {
          _drafts[target]![bucket]!.start = source[bucket]!.start;
          _drafts[target]![bucket]!.end = source[bucket]!.end;
        }
      }

      _copyTargets.clear();
    });

    CustomSnackBar.show(
      context: context,
      message: count == 1 ? 'Orario copiato in 1 giorno.' : 'Orario copiato in $count giorni.',
      isError: false,
    );
  }

  Widget _buildCopyRow(int weekday)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 33, thickness: 1, color: AppTheme.trialLine),
        const AppFieldLabel('Copia questo giorno in'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var day = 1; day <= 7; day++)
              if (day != weekday)
                AppSelectableChip(
                  label: weekdayShortName(day),
                  selected: _copyTargets.contains(day),
                  onSelected: (selected) => setState(()
                  {
                    if (selected)
                    {
                      _copyTargets.add(day);

                      return;
                    }

                    _copyTargets.remove(day);
                  }),
                ),
            // Off until something is ticked: with nothing chosen it would be a
            // button that does nothing, which is worse than a button that is
            // plainly not ready.
            if (_copyTargets.isNotEmpty)
              AppGradientButton(
                label: 'COPIA',
                icon: Icons.content_copy_rounded,
                height: 40,
                radius: 20,
                fontSize: 12,
                onPressed: _copyToSelectedDays,
              ),
          ],
        ),
      ],
    );
  }

  // One day, one card. The name of the day is its heading rather than a label
  // standing outside it, so what the arrows move is the day itself.
  Widget _buildWeekdayCard(int weekday, {required bool compact})
  {
    return AppDialogPill(
      radius: 32,
      // Tighter on a narrow window, and by exactly the amount that keeps the
      // two time fields inside as wide as they are today.
      padding: EdgeInsets.all(compact ? 20 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            weekdayFullName(weekday),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppTheme.trialOcean,
            ),
          ),
          const SizedBox(height: 20),
          for (final bucket in TimeBucket.values) ...[
            BandTimeRangeSlider(
              bucket: bucket,
              startTime: _drafts[weekday]![bucket]!.start,
              endTime: _drafts[weekday]![bucket]!.end,
              onChanged: (start, end) => setState(()
              {
                _drafts[weekday]![bucket]!.start = start;
                _drafts[weekday]![bucket]!.end = end;
              }),
            ),
            if (bucket != TimeBucket.values.last)
              const Divider(height: 33, thickness: 1, color: AppTheme.trialLine),
          ],
          const SizedBox(height: 8),
          _buildCopyRow(weekday),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final modeLabel = widget.mode == 'presence' ? 'In presenza' : 'Online';

    return AppDialogStack(
      eyebrow: 'Orario standard',
      title: 'Modifica orario — $modeLabel',
      onClose: _closeDialog,
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
        // Applies to the whole save, not to the weekday on screen, so it is a
        // piece of its own rather than something inside the day card.
        AppDialogPill(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: SizedBox(
            width: 240,
            child: HoursDateField(
              label: 'Applica a partire dal',
              controller: _effectiveFromCtrl,
            ),
          ),
        ),
        _buildCarousel(),
      ],
    );
  }

  Widget _buildCarousel()
  {
    return AppCarouselFrame(
      index: _currentWeekday,
      movingForward: _movingForward,
      maxContentWidth: _cardMaxWidth,
      canGoBack: _currentWeekday > 1,
      canGoForward: _currentWeekday < 7,
      onBack: _goToPreviousDay,
      onForward: _goToNextDay,
      child: LayoutBuilder(
        builder: (context, constraints) => _buildWeekdayCard(
          _currentWeekday,
          compact: constraints.maxWidth < AppCarouselFrame.minContentWidth,
        ),
      ),
    );
  }
}
