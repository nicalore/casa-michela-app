import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_carousel_frame.dart';
import '../../../../shared/widgets/app_dialog_footer.dart';
import '../../../../shared/widgets/app_dialog_stack.dart';
import '../../../../shared/widgets/app_gradient_button.dart';
import '../../../../shared/widgets/app_selectable_chip.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../availability/utils/availability_strings.dart';
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

const String _effectiveFromLabel = 'Applica a partire dal';

// Weekdays whose current hours match in both modes: they share one pair of steps.
class _WeekdayGroup
{
  final String key;
  final List<int> weekdays;

  const _WeekdayGroup({required this.key, required this.weekdays});
}

typedef _Card = ({_WeekdayGroup group, String mode});

class StandardHoursWizard extends StatefulWidget
{
  final List<WeeklyTemplateItem> currentTemplates;

  final Future<void> Function() onSaved;

  const StandardHoursWizard({super.key, required this.currentTemplates, required this.onSaved});

  @override
  State<StandardHoursWizard> createState() => _StandardHoursWizardState();
}

class _StandardHoursWizardState extends State<StandardHoursWizard>
{
  final ApiService _apiService = ApiService();

  final TextEditingController _effectiveFromCtrl = TextEditingController(text: formatDateString(DateTime.now()));

  final Set<int> _weekdays = {};

  // Keyed by group, so hours survive adding or removing weekdays.
  final Map<String, Map<String, BandDrafts>> _draftsByGroup = {};

  int _cardIndex = 0;
  bool _movingForward = true;
  bool _isSaving = false;

  @override
  void dispose()
  {
    _effectiveFromCtrl.dispose();
    super.dispose();
  }

  Map<TimeBucket, List<WeeklyTemplateItem>> _rowsOf(int weekday, String mode)
  {
    return standardRowsOf(widget.currentTemplates, weekday, mode);
  }

  String _signatureOf(int weekday)
  {
    return [for (final mode in kHoursModes) rowsSignature(_rowsOf(weekday, mode))].join('/');
  }

  List<_WeekdayGroup> get _groups
  {
    final byKey = <String, List<int>>{};

    for (final weekday in _weekdays.toList()..sort())
    {
      byKey.putIfAbsent(_signatureOf(weekday), () => []).add(weekday);
    }

    return [for (final entry in byKey.entries) _WeekdayGroup(key: entry.key, weekdays: entry.value)];
  }

  Map<String, BandDrafts> _draftsOf(_WeekdayGroup group)
  {
    return _draftsByGroup.putIfAbsent(
      group.key,
      () => {for (final mode in kHoursModes) mode: draftsFromRows(_rowsOf(group.weekdays.first, mode))},
    );
  }

  List<_Card> get _cards
  {
    return [
      for (final group in _groups)
        for (final mode in kHoursModes) (group: group, mode: mode),
    ];
  }

  bool get _onAskedCard => _cardIndex == 0;

  _Card get _shownCard => _cards[_cardIndex - 1];

  String? get _blockedReason => _onAskedCard && _weekdays.isEmpty ? kPickADay : null;

  void _toggleWeekday(int weekday, bool selected)
  {
    setState(()
    {
      if (selected)
      {
        _weekdays.add(weekday);
      }
      else
      {
        _weekdays.remove(weekday);
      }

      final keys = {for (final group in _groups) group.key};

      _draftsByGroup.removeWhere((key, _) => !keys.contains(key));
    });
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

  bool _validate()
  {
    final text = _effectiveFromCtrl.text.trim();

    if (!isValidDateString(text))
    {
      CustomSnackBar.show(context: context, message: 'Inserisci una data di decorrenza valida.', isError: true);

      return false;
    }

    if (parseDateString(text).isBefore(kAssociationFoundedOn))
    {
      CustomSnackBar.show(context: context, message: kBeforeFoundationError, isError: true);

      return false;
    }

    final horizon = calendarHorizon();

    if (parseDateString(text).isAfter(horizon))
    {
      CustomSnackBar.show(context: context, message: beyondHorizonError(horizon), isError: true);

      return false;
    }

    if (_weekdays.isEmpty)
    {
      CustomSnackBar.show(context: context, message: 'Seleziona almeno una giornata.', isError: true);

      return false;
    }

    return true;
  }

  // Only changed weekdays and modes are written; with no change, all are re-applied from the date.
  List<(int, String, BandDrafts)> get _writes
  {
    final all = [
      for (final group in _groups)
        for (final weekday in group.weekdays)
          for (final mode in kHoursModes) (weekday, mode, _draftsOf(group)[mode]!),
    ];

    final changed = all.where((write)
    {
      final rows = _rowsOf(write.$1, write.$2);

      return !draftsMatchRows(write.$3, rows) || rows.values.any((band) => band.length > 1);
    }).toList();

    return changed.isEmpty ? all : changed;
  }

  Future<void> _save() async
  {
    if (_isSaving || !_validate())
    {
      return;
    }

    setState(() => _isSaving = true);

    final effectiveFrom = parseDateString(_effectiveFromCtrl.text.trim());
    var successCount = 0;
    final errors = <String>[];

    // Asked once for the whole save.
    final confirmation = LossConfirmation();

    for (final (weekday, mode, drafts) in _writes)
    {
      for (final bucket in TimeBucket.values)
      {
        if (confirmation.declined || !mounted)
        {
          break;
        }

        final originals = _rowsOf(weekday, mode)[bucket]!;
        final draft = drafts[bucket]!;

        if (!draft.isOpen && originals.isEmpty)
        {
          continue;
        }

        try
        {
          if (draft.isOpen)
          {
            final written = await confirmation.run(
              context,
              (confirm) => originals.isEmpty
                  ? _apiService.createWeeklyTemplate(
                      weekday: weekday,
                      mode: mode,
                      startTime: draft.start!,
                      endTime: draft.end!,
                      effectiveFrom: effectiveFrom,
                      confirm: confirm,
                    )
                  : _apiService.updateWeeklyTemplate(
                      id: originals.first.id,
                      startTime: draft.start!,
                      endTime: draft.end!,
                      effectiveFrom: effectiveFrom,
                      confirm: confirm,
                    ),
            );

            if (written)
            {
              successCount++;
            }
          }

          // A cleared band loses all rows; a rewritten one keeps only the edited row.
          for (final duplicate in originals.skip(draft.isOpen ? 1 : 0))
          {
            if (confirmation.declined || !mounted)
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
          errors.add('${weekdayFullName(weekday)} ${bandLabel(bucket).toLowerCase()} '
              '${modeLabel(mode).toLowerCase()}: ${readableApiError(e)}');
        }
      }
    }

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (confirmation.declined && successCount == 0 && errors.isEmpty)
    {
      return;
    }

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

  Widget _buildAsked()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: HoursDateField(label: _effectiveFromLabel, controller: _effectiveFromCtrl),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              AppSelectableChip(
                label: weekdayFullName(weekday),
                selected: _weekdays.contains(weekday),
                onSelected: (selected) => _toggleWeekday(weekday, selected),
              ),
          ],
        ),
        if (_weekdays.length > 1) ...[
          const SizedBox(height: 14),
          Text(
            availabilityDaysSummary(_weekdays.length, split: _groups.length > 1),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: AppTheme.trialMutedText,
            ),
          ),
        ],
      ],
    );
  }

  Widget? get _header
  {
    if (_onAskedCard)
    {
      return null;
    }

    final weekdays = _shownCard.group.weekdays;

    return AppDialogPill(
      expand: true,
      child: Wrap(
        spacing: 40,
        runSpacing: 12,
        children: [
          WizardFact(label: _effectiveFromLabel, value: _effectiveFromCtrl.text.trim()),
          WizardFact(
            label: weekdays.length == 1 ? 'Giornata' : 'Giornate',
            value: weekdays.map(weekdayFullName).join(', '),
            maxLines: null,
          ),
        ],
      ),
    );
  }

  PersonEditGuide get _guide
  {
    if (_onAskedCard)
    {
      return const PersonEditGuide(
        question: 'Da quando e per quali giorni?',
        hint: 'Scegli da quando vale il nuovo orario e i giorni della settimana a cui applicarlo.',
      );
    }

    return PersonEditGuide(
      question: _shownCard.mode == kPresenceMode ? 'Quando è aperta in presenza?' : 'Quando è aperta online?',
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: 'Orario standard',
      title: 'Modifica orario',
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
          canGoForward: _cardIndex < _cards.length,
          forwardBlockedReason: _blockedReason,
          onBack: () => _goToCard(_cardIndex - 1),
          onForward: () => _goToCard(_cardIndex + 1),
          child: AppDialogPill(
            expand: true,
            child: _onAskedCard
                ? _buildAsked()
                : BandSliders(
                    drafts: _draftsOf(_shownCard.group)[_shownCard.mode]!,
                    onChanged: () => setState(() {}),
                  ),
          ),
        ),
      ],
    );
  }
}
