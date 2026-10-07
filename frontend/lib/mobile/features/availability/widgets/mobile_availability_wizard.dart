import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../features/availability/utils/availability_strings.dart';
import '../../../../features/lessons/models/availability_item.dart';
import '../../../../features/lessons/utils/booking_window.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_height_reporter.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_band_editor.dart';
import '../../../shared/widgets/mobile_day_picker.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../mobile_availability_draft.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

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
    draggable: false,
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
    finishMobileSheet(context, true);
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
      MobileWizardGuide(question: _guideFor(null).question, hint: _guideFor(null).hint),
      MobileDayPicker(
        days: _draft.availableDays,
        isOffered: _draft.isOffered,
        isPicked: _draft.isPicked,
        refusalFor: _draft.refusalFor,
        summary: _draft.days.length > 1
            ? availabilityDaysSummary(_draft.days.length, split: _draft.groups.length > 1)
            : null,
        onToggle: (day) => setState(() => _draft.toggle(day)),
      ),
    ];
  }

  List<Widget> _buildMode(MobileWizardStep step)
  {
    return [
      MobileWizardGuide(question: _guideFor(step.mode).question, hint: _guideFor(step.mode).hint),
      // Days with different openings get separate steps, each naming its days.
      if (_draft.groups.length > 1) MobileDaysTag(days: step.group.days),
      const SizedBox(height: 6),
      for (final bucket in TimeBucket.values) ...[
        const SizedBox(height: _blockGap),
        MobileBandEditor<AvailabilityItem>(
          schedule: _draft.bandsOf(step.group)[step.mode]!,
          mode: step.mode,
          bucket: bucket,
          window: _draft.windowFor(step.group, step.mode, bucket),
          shutLabel: _draft.shutLabelFor(step.group, step.mode, bucket),
          held: _draft.isEditing ? _draft.frozen[step.mode]![bucket]! : const [],
          offLabel: kNotAvailable,
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

    final VoidCallback? back = _step > 0 ? () => _turnTo(_step - 1) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          MobileWizardBackSlot(onBack: back, busy: _busy),
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

