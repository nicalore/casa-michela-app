import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/association/models/association_subject_item.dart';
import '../../../../features/association/models/ministry_subject_item.dart';
import '../../../../features/association/models/service_item.dart';
import '../../../../features/association/models/study_program_item.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/lessons/models/band_offer.dart';
import '../../../../features/lessons/models/booking_summary_item.dart';
import '../../../../features/lessons/models/presence_item.dart';
import '../../../../features/lessons/models/subject_request.dart';
import '../../../../features/lessons/utils/booking_wizard_strings.dart';
import '../../../../features/lessons/utils/opening_window.dart';
import '../../../../features/lessons/utils/study_program_lookup.dart';
import '../../../../features/lessons/widgets/subject_request_tile.dart' show disciplineNames;
import '../../../../features/people/models/person_item.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_band_editor.dart';
import '../../../shared/widgets/mobile_choice_chips.dart';
import '../../../shared/widgets/mobile_confirm_sheet.dart';
import '../../../shared/widgets/mobile_day_picker.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../mobile_booking_draft.dart';
import 'mobile_booking_parts.dart';
import 'mobile_subject_flow.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

const int _ministryCategory = 0;
const int _disciplineCategory = 1;

class MobileBookingCatalogue
{
  final List<PersonItem> teachers;
  final List<MinistrySubjectItem> ministrySubjects;
  final List<AssociationSubjectItem> associationSubjects;
  final List<ServiceItem> services;
  final List<StudyProgramItem> studyPrograms;

  const MobileBookingCatalogue({
    required this.teachers,
    required this.ministrySubjects,
    required this.associationSubjects,
    required this.services,
    required this.studyPrograms,
  });
}

// True once something was saved; not drag-dismissible, which would lose the answers.
Future<bool> showMobileBookingWizard({
  required BuildContext context,
  required MobileBookingDraft draft,
  required MobileBookingCatalogue catalogue,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    draggable: false,
    builder: (context) => _Wizard(draft: draft, catalogue: catalogue),
  );

  return saved ?? false;
}

class _Wizard extends StatefulWidget
{
  final MobileBookingDraft draft;
  final MobileBookingCatalogue catalogue;

  const _Wizard({required this.draft, required this.catalogue});

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard>
{
  final ApiService _apiService = ApiService();

  final PageController _pages = PageController();

  // The settled page; the controller tracks a swipe in progress.
  int _step = 0;

  bool _busy = false;

  int _category = _ministryCategory;

  bool _categoryForward = true;

  final List<TextEditingController> _searches = [for (var i = 0; i < 3; i++) TextEditingController()];

  MobileBookingDraft get _draft => widget.draft;

  MobileBookingCatalogue get _catalogue => widget.catalogue;

  PersonItem get _pupil => _draft.pupil;

  @override
  void dispose()
  {
    _pages.dispose();

    for (final search in _searches)
    {
      search.dispose();
    }

    super.dispose();
  }

  String _keyOf(MobileBookingStep step) => '${step.kind.name}/${step.group?.key ?? ''}/${step.band?.name ?? ''}';

  void _turnTo(int page)
  {
    FocusManager.instance.primaryFocus?.unfocus();
    _pages.animateToPage(page, duration: _turn, curve: _turnCurve);
  }

  void _next(List<MobileBookingStep> steps)
  {
    if (_busy)
    {
      return;
    }

    final int step = _step.clamp(0, steps.length - 1);
    final String? reason = _draft.blockedReason(steps[step]);

    if (reason != null)
    {
      MobileNotice.show(context, reason, error: true);

      return;
    }

    if (step < steps.length - 1)
    {
      _turnTo(step + 1);

      return;
    }

    _save();
  }

  Future<void> _save() async
  {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_draft.isUntouched)
    {
      finishMobileSheet(context, false);

      return;
    }

    final String? problem = _draft.problem;

    if (problem != null)
    {
      MobileNotice.show(context, problem, error: true);

      return;
    }

    final String done = _draft.savedMessage;
    final String taxCode = _pupil.fiscalCode;

    setState(() => _busy = true);

    try
    {
      await _draft.save(
        createRequest: (day, modes) => _apiService.createLessonRequest(studentTaxCode: taxCode, date: day, modes: modes),
        replaceRequest: (day, modes) => _apiService.replaceLessonRequest(studentTaxCode: taxCode, date: day, modes: modes),
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

  // The pupil is named in the question of the first step after the days.
  bool _named(List<MobileBookingStep> steps, int index) => index == (steps.first.kind == MobileBookingStepKind.days ? 1 : 0);

  List<Widget> _buildDays()
  {
    final int count = _draft.days.length;

    return [
      MobileWizardGuide(question: kOwnBookingDaysGuide.question, hint: kOwnBookingDaysGuide.hint),
      MobileDayPicker(
        days: _draft.availableDays,
        isOffered: _draft.isOffered,
        isPicked: _draft.isPicked,
        refusalFor: _draft.refusalFor,
        summary: count > 1 ? bookingDaysSummary(count, split: _draft.groups.length > 1) : null,
        onToggle: (day) => setState(() => _draft.toggle(day)),
      ),
    ];
  }

  List<Widget> _buildHours(MobileBookingGroup group, {required bool named})
  {
    final WizardGuide guide = presenceHoursGuide(
      _draft.mode,
      isSelf: _draft.isSelf,
      name: _pupil.firstName,
      named: named,
      female: _pupil.gender == 'F',
    );

    return [
      MobileWizardGuide(question: guide.question, hint: guide.hint),
      if (_draft.groups.length > 1) MobileDaysTag(days: group.days),
      const SizedBox(height: 6),
      for (final bucket in _draft.bands) ...[
        const SizedBox(height: 12),
        MobileBandEditor<PresenceItem>(
          schedule: _draft.hoursOf(group),
          mode: _draft.mode,
          bucket: bucket,
          window: _draft.windowFor(group, bucket),
          shutLabel: _draft.shutLabelFor(group, bucket),
          held: _draft.isEditing ? _draft.frozen[bucket]! : const [],
          offLabel: kNotPresent,
          onChanged: () => setState(_draft.dropRequestsWithoutHours),
        ),
      ],
    ];
  }

  List<MinistrySubjectItem> get _programmeSubjects
  {
    final Set<int> allowed = allowedMinistrySubjectIds(_pupil, _catalogue.studyPrograms);

    return _catalogue.ministrySubjects.where((subject) => allowed.contains(subject.id)).toList();
  }

  List<AssociationSubjectItem> get _standaloneDisciplines
  {
    final Set<int> covered = {
      for (final subject in _programmeSubjects)
        for (final discipline in subject.associationSubjects) discipline.id,
    };

    return _catalogue.associationSubjects.where((discipline) => !covered.contains(discipline.id)).toList();
  }

  bool _hasSeveralDisciplines(SubjectRequestDraft request)
  {
    for (final subject in _catalogue.ministrySubjects)
    {
      if (subject.id == request.ministrySubjectId)
      {
        return subject.associationSubjects.length > 1;
      }
    }

    return false;
  }

  String _summaryOf(SubjectRequestDraft request, {bool withBand = false})
  {
    final TimeBucket? band = request.band;

    return [
      if (withBand && band != null) bandLabel(band),
      if (request.asksForDisciplines && _hasSeveralDisciplines(request))
        disciplineNames(_catalogue.ministrySubjects, request).join(', '),
      if (request.duration != null) formatMinutes(request.duration!),
    ].join(' · ');
  }

  String? _subtitle(SubjectRequestDraft? chosen, String? description)
  {
    final String summary = chosen == null ? '' : _summaryOf(chosen);

    final String said = [
      if (summary.isNotEmpty) summary,
      ?descriptionOrNull(description),
    ].join(' · ');

    return said.isEmpty ? null : said;
  }

  Future<void> _openFlow(MobileBookingGroup group, TimeBucket band, SubjectRequestDraft request, {required bool editing})
  {
    FocusManager.instance.primaryFocus?.unfocus();

    final MobileSubjectFlow flow = MobileSubjectFlow(
      from: request,
      replacing: editing ? request : null,
      mode: _draft.mode,
      pupil: _pupil,
      isSelf: _draft.isSelf,
      isEditing: editing,
      ministrySubjects: _catalogue.ministrySubjects,
      offered: askableTeachers(_catalogue.teachers, _pupil.notPreferredTeacherTaxCodes),
      studyProgramId: currentStudyProgramId(_pupil),
      bands: [
        for (final offer in _draft.bandOffers(group, skip: editing ? request : null))
          if (offer.band == band) offer,
      ],
      minutesByDisciplineTakenByOthers: _draft.minutesByDiscipline(group, band: band, skip: editing ? request : null),
    );

    return showMobileSheet<void>(
      context: context,
      builder: (_) => MobileSubjectPage(
        flow: flow,
        onDone: (draft) async
        {
          if (mounted)
          {
            setState(() => _draft.keepRequest(group, draft, replacing: flow.replacing));
            returnToMobileSheetPage(context);
          }

          return true;
        },
        onRemove: editing ? (page) => _confirmRemoval(page, group, flow) : null,
      ),
    );
  }

  Future<void> _confirmRemoval(BuildContext page, MobileBookingGroup group, MobileSubjectFlow flow) async
  {
    final bool confirmed = await showMobileConfirmSheet(
      context: page,
      eyebrow: kRemovalEyebrow,
      title: 'Confermi?',
      message: TextSpan(
        children: [
          const TextSpan(text: kSubjectRemovalBefore),
          TextSpan(
            text: flow.draft.displayName,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          const TextSpan(text: kSubjectRemovalAfter),
        ],
      ),
      confirmLabel: 'Rimuovi',
      confirmIcon: Icons.delete_outline_rounded,
    );

    final SubjectRequestDraft? replacing = flow.replacing;

    if (!confirmed || !mounted || replacing == null)
    {
      return;
    }

    setState(()
    {
      final int at = _draft.requestsOf(group).indexOf(replacing);

      if (at >= 0)
      {
        _draft.dropRequest(group, at);
      }
    });

    returnToMobileSheetPage(context);
  }

  // The page's band only: the same subject may be booked in another band too.
  SubjectRequestDraft? _chosen(MobileBookingGroup group, TimeBucket band, bool Function(SubjectRequestDraft request) matches)
  {
    return _draft.requestsOf(group).where((request) => request.band == band && matches(request)).firstOrNull;
  }

  // Lists only what the band has not booked yet; booked lessons change from their own sheet.
  bool _listed(MobileBookingGroup group, TimeBucket band, bool Function(SubjectRequestDraft request) matches)
  {
    return !_draft.subjectsOnly || _chosen(group, band, matches)?.existing == null;
  }

  // A subject already chosen opens to be changed or removed, never dropped by a stray tap.
  Widget _pickRow(
    MobileBookingGroup group,
    TimeBucket band, {
    required String name,
    String? description,
    required bool Function(SubjectRequestDraft request) matches,
    required SubjectRequestDraft Function() pick,
  })
  {
    final SubjectRequestDraft? picked = _chosen(group, band, matches);

    return MobileSelectRow(
      title: name,
      subtitle: _subtitle(picked, description),
      selected: picked != null,
      onTap: ()
      {
        final String? full = picked == null ? _draft.noTimeLeftIn(group, band) : null;

        if (full != null)
        {
          MobileNotice.show(context, full, error: true);

          return;
        }

        _openFlow(group, band, picked ?? pick(), editing: picked != null);
      },
    );
  }

  bool _matches(String name) => name.toLowerCase().contains(_searches[_category].text.trim().toLowerCase());

  List<Widget> _buildCategory(MobileBookingGroup group, TimeBucket band)
  {
    final String whose = 'di ${_pupil.firstName}';

    switch (_category)
    {
      case _ministryCategory:
        final List<MinistrySubjectItem> all = _programmeSubjects;

        if (all.isEmpty)
        {
          return [MobileQuietLine(noProgrammeSubjects(isSelf: _draft.isSelf, whose: whose))];
        }

        final List<MinistrySubjectItem> shown = all
            .where((subject) => _matches(subject.name) && _listed(group, band, (request) => request.ministrySubjectId == subject.id))
            .toList();

        return [
          if (shown.isEmpty) MobileQuietLine(kSubjectNoMatch[_category]),
          for (final subject in shown)
            _pickRow(
              group,
              band,
              name: subject.name,
              matches: (request) => request.ministrySubjectId == subject.id,
              pick: () => SubjectRequestDraft(
                kind: BookingRequestKind.ministrySubject,
                ministrySubjectId: subject.id,
                associationSubjectIds: {
                  if (subject.associationSubjects.length == 1) subject.associationSubjects.single.id,
                },
              )..ministrySubjectName = subject.name,
            ),
        ];

      case _disciplineCategory:
        final List<AssociationSubjectItem> all = _standaloneDisciplines;

        if (all.isEmpty)
        {
          return [MobileQuietLine(allDisciplinesCovered(isSelf: _draft.isSelf, whose: whose))];
        }

        final List<AssociationSubjectItem> shown = all
            .where((discipline) =>
                _matches(discipline.name) && _listed(group, band, (request) => request.associationSubjectId == discipline.id))
            .toList();

        return [
          if (shown.isEmpty) MobileQuietLine(kSubjectNoMatch[_category]),
          for (final discipline in shown)
            _pickRow(
              group,
              band,
              name: discipline.name,
              description: discipline.description,
              matches: (request) => request.associationSubjectId == discipline.id,
              pick: () => SubjectRequestDraft(
                kind: BookingRequestKind.associationSubject,
                associationSubjectId: discipline.id,
                associationSubjectName: discipline.name,
              ),
            ),
        ];

      default:
        if (_catalogue.services.isEmpty)
        {
          return const [MobileQuietLine(kNoServices)];
        }

        final List<ServiceItem> shown = _catalogue.services
            .where((service) => _matches(service.name) && _listed(group, band, (request) => request.serviceName == service.name))
            .toList();

        return [
          if (shown.isEmpty) MobileQuietLine(kSubjectNoMatch[_category]),
          for (final service in shown)
            _pickRow(
              group,
              band,
              name: service.name,
              description: service.description,
              matches: (request) => request.serviceName == service.name,
              pick: () => SubjectRequestDraft(kind: BookingRequestKind.service, serviceName: service.name),
            ),
        ];
    }
  }

  List<Widget> _buildSubjects(MobileBookingGroup group, TimeBucket band, {required bool named})
  {
    final WizardGuide guide = presenceSubjectsGuide(_draft.mode, isSelf: _draft.isSelf, name: _pupil.firstName, named: named);
    final BandOffer? offer = _draft.bandOffers(group).where((offer) => offer.band == band).firstOrNull;

    return [
      MobileWizardGuide(question: guide.question, hint: guide.hint),
      if (_draft.groups.length > 1) MobileDaysTag(days: group.days),
      if (offer != null) MobileBandTag(offer: offer),
      const SizedBox(height: 16),
      MobileChoiceChips(
        choices: [
          for (final (i, label) in kSubjectCategoryLabels.indexed) MobileChoice(value: '$i', label: label),
        ],
        value: '$_category',
        onChanged: (value)
        {
          final int chosen = int.parse(value ?? '0');

          FocusManager.instance.primaryFocus?.unfocus();
          setState(()
          {
            _categoryForward = chosen > _category;
            _category = chosen;
          });
        },
        margin: MobileSheet.sidePadding,
        onLight: true,
      ),
      const SizedBox(height: 12),
      MobileSideSwitcher(
        forward: _categoryForward,
        child: Column(
          key: ValueKey('category/$_category'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileSearchField(
              controller: _searches[_category],
              hintText: kSubjectSearchHints[_category],
              onChanged: (_) => setState(() {}),
              onGlass: true,
            ),
            const SizedBox(height: 12),
            ..._buildCategory(group, band),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPage(List<MobileBookingStep> steps, int index)
  {
    final MobileBookingStep step = steps[index];
    final MobileBookingGroup? group = step.group;

    return switch (step.kind)
    {
      MobileBookingStepKind.days => _buildDays(),
      MobileBookingStepKind.hours => _buildHours(group!, named: _named(steps, index)),
      MobileBookingStepKind.subjects => _buildSubjects(group!, step.band!, named: _named(steps, index)),
    };
  }

  Widget _buildFooter(List<MobileBookingStep> steps)
  {
    final int step = _step.clamp(0, steps.length - 1);
    // The hours page is never last: the subjects pages follow once bands have hours.
    final bool last = step == steps.length - 1 && (_draft.hoursOnly || steps[step].kind != MobileBookingStepKind.hours);
    final String label = last ? (_draft.isEditing ? 'Salva' : 'Crea') : 'Avanti';

    final VoidCallback? back = step > 0 ? () => _turnTo(step - 1) : null;

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
              onPressed: () => _next(steps),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildWizardSheet();

  MobileSheet _buildWizardSheet()
  {
    final List<MobileBookingStep> steps = _draft.steps;

    if (steps.isEmpty)
    {
      return MobileSheet(
        eyebrow: _eyebrow(),
        title: _draft.isEditing ? kEditBookingTitle : kNewBookingTitle,
        body: [MobileQuietLine(modeShutAllDay(_draft.mode))],
      );
    }

    return MobileSheet(
      eyebrow: _eyebrow(),
      title: _draft.isEditing ? kEditBookingTitle : kNewBookingTitle,
      aboveKeyboard: true,
      subhead: steps.length > 1 ? MobileWizardDots(count: steps.length, position: _pages, fallback: _step) : null,
      content: MobileStepPager(
        controller: _pages,
        keys: [for (final step in steps) _keyOf(step)],
        pageBuilder: (index) => _buildPage(steps, index),
        onPageChanged: (index) => setState(() => _step = index),
      ),
      footer: _buildFooter(steps),
    );
  }

  String _modeWord() => modeLabel(_draft.mode).toLowerCase();

  String _eyebrow() => _draft.isSelf ? _modeWord() : '${_pupil.firstName} · ${_modeWord()}';
}
