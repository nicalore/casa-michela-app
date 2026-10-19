import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../../../../features/people/models/person_item.dart';
import '../../../../services/api_service.dart';
import '../../../shared/widgets/mobile_band_editor.dart';
import '../../../shared/widgets/mobile_choice_chips.dart';
import '../../../shared/widgets/mobile_choice_sheet.dart' show MobileChoice;
import '../../../shared/widgets/mobile_confirm_sheet.dart';
import '../../../shared/widgets/mobile_day_picker.dart';
import '../../../shared/widgets/mobile_gold_button.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_select_parts.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../../../shared/widgets/mobile_wizard_parts.dart';
import '../mobile_booking_draft.dart';
import '../mobile_bookings_tour.dart';
import 'mobile_booking_parts.dart';
import 'mobile_subject_flow.dart';

const Duration _turn = Duration(milliseconds: 340);
const Curve _turnCurve = Curves.easeInOutCubic;

const int _ministryCategory = 0;
const int _disciplineCategory = 1;

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

// A tour counts the hours as changed once they rest this long.
const Duration _hoursRest = Duration(milliseconds: 700);

const EdgeInsets _tourDaysInflate = EdgeInsets.fromLTRB(8, -6, 8, 8);
const double _tourDaysRadius = 18;
const EdgeInsets _tourListInflate = EdgeInsets.all(4);
const double _tourListRadius = 18;

const EdgeInsets _tourOpenInflate = EdgeInsets.all(4);
const double _tourOpenRadius = 22;
const EdgeInsets _tourFooterInflate = EdgeInsets.all(4);
const double _tourFooterRadius = 22;

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
// [tourFor]: whose tour explains the wizard, null for none.
Future<bool> showMobileBookingWizard({
  required BuildContext context,
  required MobileBookingDraft draft,
  required MobileBookingCatalogue catalogue,
  String? tourFor,
}) async
{
  final bool? saved = await showMobileSheet<bool>(
    context: context,
    draggable: false,
    builder: (context) => _Wizard(draft: draft, catalogue: catalogue, tourFor: tourFor),
  );

  return saved ?? false;
}

class _Wizard extends StatefulWidget
{
  final MobileBookingDraft draft;
  final MobileBookingCatalogue catalogue;
  final String? tourFor;

  const _Wizard({required this.draft, required this.catalogue, required this.tourFor});

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

  // Per band, the subject whose disciplines are listed under it.
  final Map<TimeBucket, int> _openSubject = {};

  bool _categoryForward = true;

  final List<TextEditingController> _searches = [for (var i = 0; i < 3; i++) TextEditingController()];

  final BookingWizardTourPulse _tourPulse = BookingWizardTourPulse();
  Timer? _hoursQuiet;

  MobileBookingDraft get _draft => widget.draft;

  MobileBookingCatalogue get _catalogue => widget.catalogue;

  PersonItem get _pupil => _draft.pupil;

  @override
  void initState()
  {
    super.initState();

    if (widget.tourFor != null)
    {
      _pages.addListener(_onPages);
      mobileTourChanges.addListener(_tourLater);
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    _hoursQuiet?.cancel();
    mobileTourChanges.removeListener(_tourLater);
    _pages.dispose();

    for (final search in _searches)
    {
      search.dispose();
    }

    // Not while the tree is locked: a tour ends, and redraws, on hearing it.
    final BookingWizardTourPulse pulse = _tourPulse;

    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      pulse.leave();
      pulse.dispose();
    });

    super.dispose();
  }

  double get _page
  {
    return _pages.hasClients && _pages.position.haveDimensions ? _pages.page ?? _step.toDouble() : _step.toDouble();
  }

  void _tourLater()
  {
    if (widget.tourFor == null)
    {
      return;
    }

    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  void _onPages()
  {
    final double page = _page;
    final List<MobileBookingStep> steps = _draft.steps;
    final bool settled = (page - page.round()).abs() < _settled && page.round() < steps.length;

    _tourPulse.rest(settled ? _keyOf(steps[page.round()]) : null);

    if (settled)
    {
      _tourLater();
    }
  }

  // Once the sheet stands still on a page, the marks of that page never seen.
  Future<void> _tourCheck() async
  {
    final String? taxCode = widget.tourFor;

    if (!mounted || taxCode == null || _busy || isMobileTourShown)
    {
      return;
    }

    if (isMobileSheetMoving(context))
    {
      _tourLater();

      return;
    }

    final List<MobileBookingStep> steps = _draft.steps;
    final double page = _page;

    if (steps.isEmpty || (page - page.round()).abs() >= _settled || page.round() != _step || _step >= steps.length)
    {
      return;
    }

    final MobileBookingStep step = steps[_step];
    final MobileBookingGroup? group = step.group;
    final String key = _keyOf(step);

    _tourPulse.rest(key);

    Iterable<TimeBucket> open() =>
        group == null ? const [] : _draft.bands.where((bucket) => _draft.windowFor(group, bucket) != null);
    int stretches(TimeBucket bucket) => group == null ? 0 : _draft.hoursOf(group).of(bucket).length;

    await startBookingWizardTour(
      taxCode: taxCode,
      kind: switch (step.kind)
      {
        MobileBookingStepKind.days => BookingWizardPage.days,
        MobileBookingStepKind.hours => BookingWizardPage.hours,
        MobileBookingStepKind.subjects => BookingWizardPage.subjects,
      },
      page: key,
      online: _draft.mode == kOnlineMode,
      pupil: BookingTourPupil.of(self: _draft.isSelf, gender: _pupil.gender),
      pulse: _tourPulse,
      anyOpen: () => mounted && open().isNotEmpty,
      anyGiven: () => mounted && open().any((bucket) => stretches(bucket) > 0),
      anyBins: () => mounted && open().any((bucket) => stretches(bucket) > 1),
      band: () => mounted && group != null && _draft.bandOffers(group).any((offer) => offer.band == step.band),
      creates: () => _finishesWith(BookingWizardMark.create),
      saves: () => _finishesWith(BookingWizardMark.save),
      savesHours: () => _finishesWith(BookingWizardMark.saveHours),
      toSubjects: ()
      {
        if (mounted && _category != _ministryCategory)
        {
          setState(()
          {
            _categoryForward = false;
            _category = _ministryCategory;
          });
        }
      },
    );
  }

  void _tourUse(BookingWizardMark mark)
  {
    _tourPulse.use(mark);
    _tourLater();
  }

  void _onBandUsed(MobileBandPart part)
  {
    switch (part)
    {
      case MobileBandPart.hours:
        _hoursQuiet?.cancel();
        _hoursQuiet = Timer(_hoursRest, _hoursRested);

      case MobileBandPart.yesNo:
        _tourUse(BookingWizardMark.yesNo);

      case MobileBandPart.add || MobileBandPart.bin:
        _tourLater();
    }
  }

  // Not while an hour is being typed: it counts once confirmed.
  void _hoursRested()
  {
    if (!mounted)
    {
      return;
    }

    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;

    if (focused != null && focused.findAncestorStateOfType<EditableTextState>() != null)
    {
      _hoursQuiet = Timer(_hoursRest, _hoursRested);

      return;
    }

    _tourUse(BookingWizardMark.hours);
  }

  // The band whose add button a tour lights: the first one given.
  TimeBucket? _addBand(MobileBookingGroup group)
  {
    for (final TimeBucket bucket in _draft.bands)
    {
      if (_draft.windowFor(group, bucket) != null && _draft.hoursOf(group).of(bucket).isNotEmpty)
      {
        return bucket;
      }
    }

    return null;
  }

  String _keyOf(MobileBookingStep step) => '${step.kind.name}/${step.group?.key ?? ''}/${step.band?.name ?? ''}';

  // The hours page is never last: the subjects pages follow once bands have hours.
  bool _isLast(List<MobileBookingStep> steps, int step)
  {
    return step == steps.length - 1 && (_draft.hoursOnly || steps[step].kind != MobileBookingStepKind.hours);
  }

  // Last page's button: subjects of a new or edited booking, or the hours when only they change.
  BookingWizardMark? _finish(List<MobileBookingStep> steps, int step)
  {
    if (step >= steps.length || !_isLast(steps, step))
    {
      return null;
    }

    return switch (steps[step].kind)
    {
      MobileBookingStepKind.subjects => _draft.isEditing ? BookingWizardMark.save : BookingWizardMark.create,
      MobileBookingStepKind.hours => BookingWizardMark.saveHours,
      MobileBookingStepKind.days => null,
    };
  }

  // Its tour step shows with the wizard's page on top; on subjects, once one comes back chosen.
  bool _finishesWith(BookingWizardMark mark)
  {
    return mounted &&
        _finish(_draft.steps, _step) == mark &&
        isMobileSheetPageOnTop(context) &&
        (mark == BookingWizardMark.saveHours ||
            _draft.groups.any((group) => _draft.requestsOf(group).any((request) => request.existing == null)));
  }

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

  List<Widget> _buildDays(String page)
  {
    final int count = _draft.days.length;

    return [
      MobileWizardGuide(question: kOwnBookingDaysGuide.question, hint: kOwnBookingDaysGuide.hint),
      MobileTourTarget(
        id: bookingWizardTourTarget(BookingWizardMark.days, page),
        inflate: _tourDaysInflate,
        radius: _tourDaysRadius,
        child: MobileDayPicker(
          days: _draft.availableDays,
          isOffered: _draft.isOffered,
          isPicked: _draft.isPicked,
          refusalFor: _draft.refusalFor,
          summary: count > 1 ? bookingDaysSummary(count, split: _draft.groups.length > 1) : null,
          onToggle: (day)
          {
            setState(() => _draft.toggle(day));
            _tourUse(BookingWizardMark.days);
          },
          onRefused: (_) => _tourUse(BookingWizardMark.days),
        ),
      ),
    ];
  }

  List<Widget> _buildHours(MobileBookingGroup group, String page, {required bool named})
  {
    final TimeBucket? addBand = _addBand(group);

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
          tour: MobileBandTour(
            yesNo: bookingWizardTourTarget(BookingWizardMark.yesNo, page),
            hours: bookingWizardTourTarget(BookingWizardMark.hours, page),
            add: bucket == addBand ? bookingWizardTourTarget(BookingWizardMark.add, page) : null,
            bin: bookingWizardTourTarget(BookingWizardMark.bin, page),
            onUsed: _onBandUsed,
          ),
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

  String? _subtitle(SubjectRequestDraft? chosen, String? description)
  {
    final int? duration = chosen?.duration;
    final String summary = duration == null ? '' : formatMinutes(duration);

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
      tourFor: widget.tourFor,
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
            _tourLater();
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
        children: switch (flow.discipline)
        {
          final String discipline => [
              TextSpan(
                text: disciplineLabel(flow.draft.displayName, discipline),
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: kDisciplineRemovalAfter),
            ],
          null => [
              const TextSpan(text: kSubjectRemovalBefore),
              TextSpan(
                text: flow.draft.displayName,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
              const TextSpan(text: kSubjectRemovalAfter),
            ],
        },
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

  SubjectRequestDraft? _bookedDiscipline(MobileBookingGroup group, TimeBucket band, int subject, int discipline)
  {
    return _chosen(
      group,
      band,
      (request) =>
          request.kind == BookingRequestKind.ministrySubject &&
          request.ministrySubjectId == subject &&
          request.associationSubjectIds.contains(discipline),
    );
  }

  // Adding a lesson to a booked day lists only the disciplines still free.
  bool _offersSome(MobileBookingGroup group, TimeBucket band, MinistrySubjectItem subject)
  {
    return !_draft.subjectsOnly ||
        subject.associationSubjects.any((discipline) => _bookedDiscipline(group, band, subject.id, discipline.id)?.existing == null);
  }

  void _pickDiscipline(MobileBookingGroup group, TimeBucket band, MinistrySubjectItem subject, AssociationSubjectOption discipline)
  {
    final String? full = _draft.noTimeLeftIn(group, band);

    if (full != null)
    {
      MobileNotice.show(context, full, error: true);

      return;
    }

    _openFlow(
      group,
      band,
      SubjectRequestDraft(
        kind: BookingRequestKind.ministrySubject,
        ministrySubjectId: subject.id,
        associationSubjectIds: {discipline.id},
      )..ministrySubjectName = subject.name,
      editing: false,
    );
  }

  // A subject divided in disciplines opens in place: each discipline is booked on its own.
  Widget _subjectGroup(MobileBookingGroup group, TimeBucket band, MinistrySubjectItem subject, String page)
  {
    final bool open = _openSubject[band] == subject.id;

    final Widget built = MobileSubjectGroup(
      title: subject.name,
      booked: [
        for (final discipline in subject.associationSubjects)
          if (_bookedDiscipline(group, band, subject.id, discipline.id) != null) discipline.name,
      ],
      open: open,
      onToggle: ()
      {
        setState(()
        {
          if (open)
          {
            _openSubject.remove(band);
          }
          else
          {
            _openSubject[band] = subject.id;
          }
        });
        _tourLater();
      },
      children: [
        for (final discipline in subject.associationSubjects)
          if (_bookedDiscipline(group, band, subject.id, discipline.id) case final SubjectRequestDraft request?)
            if (!_draft.subjectsOnly || request.existing == null)
              MobileSelectRow(
                key: ValueKey(discipline.id),
                title: discipline.name,
                subtitle: request.duration == null ? null : formatMinutes(request.duration!),
                selected: true,
                onTap: () => _openFlow(group, band, request, editing: true),
              )
            else
              const SizedBox.shrink()
          else
            MobileSelectRow(
              key: ValueKey(discipline.id),
              title: discipline.name,
              subtitle: descriptionOrNull(discipline.description),
              selected: false,
              onTap: () => _pickDiscipline(group, band, subject, discipline),
            ),
      ],
    );

    // Always wrapped, lit only open: the group keeps its state, and its unfolding, either way.
    return MobileTourTarget(
      key: ValueKey(subject.id),
      id: open ? bookingWizardTourTarget(BookingWizardMark.open, page) : null,
      inflate: _tourOpenInflate,
      radius: _tourOpenRadius,
      clipped: true,
      child: built,
    );
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

  List<Widget> _buildCategory(MobileBookingGroup group, TimeBucket band, String page)
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

        final List<MinistrySubjectItem> shown =
            all.where((subject) => _matches(subject.name) && _offersSome(group, band, subject)).toList();

        return [
          if (shown.isEmpty) MobileQuietLine(kSubjectNoMatch[_category]),
          for (final subject in shown)
            if (subject.associationSubjects.length > 1)
              _subjectGroup(group, band, subject, page)
            else
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

  List<Widget> _buildSubjects(MobileBookingGroup group, TimeBucket band, String page, {required bool named})
  {
    final WizardGuide guide = presenceSubjectsGuide(_draft.mode, isSelf: _draft.isSelf, name: _pupil.firstName, named: named);
    final BandOffer? offer = _draft.bandOffers(group).where((offer) => offer.band == band).firstOrNull;

    return [
      MobileWizardGuide(question: guide.question, hint: guide.hint),
      if (_draft.groups.length > 1) MobileDaysTag(days: group.days),
      if (offer != null)
        MobileBandTag(
          offer: offer,
          mode: _draft.mode,
          tourBand: bookingWizardTourTarget(BookingWizardMark.band, page),
          tourLeft: bookingWizardTourTarget(BookingWizardMark.left, page),
        ),
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
        tourTargets: [for (final BookingWizardMark tab in kBookingWizardTabs) bookingWizardTourTarget(tab, page)],
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
            MobileTourTarget(
              id: bookingWizardTourTarget(BookingWizardMark.list, page),
              inflate: _tourListInflate,
              radius: _tourListRadius,
              clipped: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildCategory(group, band, page),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPage(List<MobileBookingStep> steps, int index)
  {
    final MobileBookingStep step = steps[index];
    final MobileBookingGroup? group = step.group;
    final String page = _keyOf(step);

    return switch (step.kind)
    {
      MobileBookingStepKind.days => _buildDays(page),
      MobileBookingStepKind.hours => _buildHours(group!, page, named: _named(steps, index)),
      MobileBookingStepKind.subjects => _buildSubjects(group!, step.band!, page, named: _named(steps, index)),
    };
  }

  Widget _buildFooter(List<MobileBookingStep> steps)
  {
    final int step = _step.clamp(0, steps.length - 1);
    final bool last = _isLast(steps, step);
    final String label = last ? (_draft.isEditing ? 'Salva' : 'Crea') : 'Avanti';

    final VoidCallback? back = step > 0 ? () => _turnTo(step - 1) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          MobileWizardBackSlot(onBack: back, busy: _busy),
          Expanded(
            child: MobileTourTarget(
              id: switch (_finish(steps, step))
              {
                final BookingWizardMark mark => bookingWizardTourTarget(mark, _keyOf(steps[step])),
                null => null,
              },
              inflate: _tourFooterInflate,
              radius: _tourFooterRadius,
              child: MobileGoldButton(
                label: label,
                icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                busy: _busy,
                onPressed: () => _next(steps),
              ),
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
        blockedReason: (index) => _draft.blockedReason(steps[index]),
      ),
      footer: _buildFooter(steps),
    );
  }

  String _modeWord() => modeLabel(_draft.mode).toLowerCase();

  String _eyebrow() => _draft.isSelf ? _modeWord() : '${_pupil.firstName} · ${_modeWord()}';
}
