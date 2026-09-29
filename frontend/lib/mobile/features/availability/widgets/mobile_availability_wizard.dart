import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../features/availability/utils/availability_strings.dart';
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../services/api_service.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_height_reporter.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../mobile_availability_draft.dart';
import 'mobile_band_editor.dart';
import 'mobile_day_picker.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

const double _tagRadius = 14;
const double _blockGap = 12;

// Assumed page height until measured.
const double _unmeasured = 360;

// True once something was saved; not drag-dismissible, which would lose the input.
Future<bool> showMobileAvailabilityWizard({
  required BuildContext context,
  required MobileAvailabilityDraft draft,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    dismissible: false,
    builder: (context) => _Wizard(draft: draft),
  );

  return saved ?? false;
}

class _Page
{
  final String key;
  final MobileWizardStep? step;

  const _Page({required this.key, this.step});
}

class _Wizard extends StatefulWidget
{
  final MobileAvailabilityDraft draft;

  const _Wizard({required this.draft});

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard>
{
  final ApiService _apiService = ApiService();
  final PageController _pages = PageController();

  // Keyed by page so heights survive days being added or removed.
  final ValueNotifier<Map<String, double>> _heights = ValueNotifier(const {});

  // The settled page; the controller tracks a swipe in progress.
  int _step = 0;

  bool _busy = false;

  DateTime? _refused;

  MobileAvailabilityDraft get _draft => widget.draft;

  @override
  void dispose()
  {
    _pages.dispose();
    _heights.dispose();

    super.dispose();
  }

  // No steps until days are chosen: the days page stands alone.
  List<_Page> get _pageList
  {
    return [
      if (!_draft.isEditing) const _Page(key: 'days'),
      for (final step in _draft.steps) _Page(key: '${step.group.key}/${step.mode}', step: step),
    ];
  }

  bool get _onDays => !_draft.isEditing && _step == 0;

  bool _isLast(int count) => !_onDays && _step >= count - 1;

  double get _page
  {
    return _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? _step.toDouble() : _step.toDouble();
  }

  void _measured(String key, double height)
  {
    final double? known = _heights.value[key];

    if (known != null && (known - height).abs() < 0.5)
    {
      return;
    }

    _heights.value = {..._heights.value, key: height};
  }

  void _turnTo(int page)
  {
    FocusManager.instance.primaryFocus?.unfocus();
    _pages.animateToPage(page, duration: _turn, curve: _turnCurve);
  }

  void _next(int count)
  {
    if (_busy)
    {
      return;
    }

    if (_onDays && _draft.days.isEmpty)
    {
      MobileNotice.show(context, kPickADay, error: true);

      return;
    }

    if (!_isLast(count))
    {
      _turnTo(_step + 1);

      return;
    }

    _save();
  }

  Future<void> _save() async
  {
    FocusManager.instance.primaryFocus?.unfocus();

    final String? problem = _draft.problem;

    if (problem != null)
    {
      MobileNotice.show(context, problem, error: true);

      return;
    }

    final String done = availabilitySaved(
      clearing: _draft.isClearing,
      editing: _draft.isEditing,
      days: _draft.days.length,
    );

    setState(() => _busy = true);

    try
    {
      await _draft.save(
        delete: (item) => _apiService.deleteAvailability(item.id),
        create: (day, mode, start, end) => _apiService.createAvailability(
          teacherTaxCode: _draft.taxCode,
          date: day,
          mode: mode,
          startTime: start,
          endTime: end,
        ),
        update: (existing, day, mode, start, end) => _apiService.updateAvailability(
          id: existing.id,
          teacherTaxCode: _draft.taxCode,
          date: day,
          mode: mode,
          startTime: start,
          endTime: end,
          expectedUpdatedAt: existing.updatedAt,
        ),
      );
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _busy = false);
        MobileNotice.show(context, readableApiError(e), error: true);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    MobileNotice.show(context, done);
    Navigator.of(context).pop(true);
  }

  AvailabilityGuide _guideFor(String? mode)
  {
    if (mode == null)
    {
      return kOwnDaysGuide;
    }

    return mode == kOnlineMode ? kOwnOnlineGuide : kOwnPresenceGuide;
  }

  List<Widget> _buildDays()
  {
    return [
      _Guide(guide: _guideFor(null)),
      MobileDayPicker(
        draft: _draft,
        refused: _refused,
        onToggle: (day) => setState(()
        {
          _refused = null;
          _draft.toggle(day);
        }),
        onRefused: (day) => setState(() => _refused = day),
      ),
    ];
  }

  List<Widget> _buildMode(MobileWizardStep step)
  {
    return [
      _Guide(guide: _guideFor(step.mode)),
      // Days with different openings get separate steps, each naming its days.
      if (_draft.groups.length > 1) _Days(days: step.group.days),
      const SizedBox(height: 6),
      for (final bucket in TimeBucket.values) ...[
        const SizedBox(height: _blockGap),
        MobileBandEditor(
          draft: _draft,
          group: step.group,
          mode: step.mode,
          bucket: bucket,
          onChanged: () => setState(() {}),
        ),
      ],
    ];
  }

  Widget _buildPage(_Page page)
  {
    final MobileWizardStep? step = page.step;

    return SingleChildScrollView(
      key: PageStorageKey(page.key),
      child: MobileHeightReporter(
        onHeight: (height) => _measured(page.key, height),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(MobileSheet.sidePadding, 20, MobileSheet.sidePadding, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: step == null ? _buildDays() : _buildMode(step),
          ),
        ),
      ),
    );
  }

  // Height interpolates between pages so the sheet follows the finger.
  Widget _buildPager(List<_Page> pages)
  {
    return AnimatedBuilder(
      animation: Listenable.merge([_pages, _heights]),
      builder: (context, child)
      {
        final double page = _page.clamp(0, pages.length - 1).toDouble();
        final int low = page.floor();
        final int high = page.ceil();

        final Map<String, double> heights = _heights.value;
        final double from = heights[pages[low].key] ?? heights[pages[high].key] ?? _unmeasured;
        final double to = heights[pages[high].key] ?? from;

        // Bounded by the Flexible around it in the sheet.
        return SizedBox(height: ui.lerpDouble(from, to, page - low), child: child);
      },
      child: PageView.builder(
        controller: _pages,
        // Keeps the neighbours laid out, so their height is known before a swipe.
        allowImplicitScrolling: true,
        itemCount: pages.length,
        onPageChanged: (index)
        {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _step = index);
        },
        itemBuilder: (context, index) => _buildPage(pages[index]),
      ),
    );
  }

  Widget _buildFooter(int count)
  {
    final bool last = _isLast(count);
    final String label = last ? (_draft.isEditing ? 'Salva' : 'Crea') : 'Avanti';

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          AnimatedSize(
            duration: _turn,
            curve: _turnCurve,
            alignment: Alignment.centerLeft,
            child: _step > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: MobileWizardBackButton(onTap: _busy ? null : () => _turnTo(_step - 1)),
                  )
                : const SizedBox(height: MobileWizardBackButton.size),
          ),
          Expanded(
            child: MobileGoldButton(
              label: label,
              icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
              busy: _busy,
              onPressed: () => _next(count),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<_Page> pages = _pageList;
    final DateTime? edited = _draft.editedDay;

    return MobileSheet(
      eyebrow: edited == null ? 'Disponibilità' : formatAvailableDayLabel(edited),
      title: _draft.isEditing ? kEditAvailabilityTitle : kNewAvailabilityTitle,
      aboveKeyboard: true,
      subhead: MobileWizardDots(count: pages.length, position: _pages, fallback: _step),
      content: _buildPager(pages),
      footer: _buildFooter(pages.length),
    );
  }
}

class _Guide extends StatelessWidget
{
  final AvailabilityGuide guide;

  const _Guide({required this.guide});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          guide.question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            height: 1.2,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          guide.hint,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: MobilePalette.mutedText,
          ),
        ),
      ],
    );
  }
}

class _Days extends StatelessWidget
{
  final List<DateTime> days;

  const _Days({required this.days});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(_tagRadius),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${(days.length == 1 ? 'Giornata' : 'Giornate').toUpperCase()}  ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppTheme.trialTealDeep,
              ),
            ),
            TextSpan(text: days.map(formatAvailableDayLabel).join(', ')),
          ],
        ),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          height: 1.45,
          color: AppTheme.trialInk,
        ),
      ),
    );
  }
}
