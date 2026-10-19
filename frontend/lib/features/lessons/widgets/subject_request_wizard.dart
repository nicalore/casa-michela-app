import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/field_limits.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_carousel_frame.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../bookings/bookings_tour.dart';
import 'subject_pick_row.dart';
import '../../people/edit/widgets/person_edit_guide.dart';
import '../../people/models/person_item.dart';
import '../models/band_offer.dart';
import '../models/booking_summary_item.dart';
import '../models/subject_request.dart';
import '../utils/booking_wizard_strings.dart';
import '../utils/opening_window.dart';
import '../utils/teacher_fit.dart';
import 'booking_fields_section.dart';
import 'subject_request_tile.dart';

typedef _Step = SubjectRequestStep;

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _cardWidth = 520;

const double _confirmWidth = 480;

// The guide above the steps, and so the dialog, stay wider than any step.
const double _guideWidth = 880;
const double _stackWidth =
    _guideWidth + 2 * (AppCarouselFrame.arrowSize + AppCarouselFrame.gap) + 64;

class SubjectRequestWizard extends StatefulWidget
{
  final String mode;

  final SubjectRequestDraft draft;

  final List<MinistrySubjectItem> ministrySubjects;

  final List<PersonItem> teachers;

  // The pupil's programme, to put the teachers who could take the lesson first.
  final int? studentStudyProgramId;

  // Copy: named, "lo studente" when null, addressed directly when isSelf; gender for agreement.
  final String? studentName;
  final bool isSelf;
  final String? studentGender;

  final bool isEditing;

  // More than one adds a step to choose the band; empty: no limit to check.
  final List<BandOffer> bands;

  final Future<bool> Function(SubjectRequestDraft draft) onSave;

  // A subject still being booked, which can be taken back out.
  final VoidCallback? onRemove;

  // A parent or a student booking: each card's parts are shown around the first time.
  final bool toured;

  const SubjectRequestWizard({
    super.key,
    required this.mode,
    required this.draft,
    required this.ministrySubjects,
    required this.teachers,
    required this.onSave,
    this.onRemove,
    this.studentStudyProgramId,
    this.studentName,
    this.isSelf = false,
    this.studentGender,
    this.isEditing = false,
    this.bands = const [],
    this.toured = false,
  });

  @override
  State<SubjectRequestWizard> createState() => _SubjectRequestWizardState();
}

class _SubjectRequestWizardState extends State<SubjectRequestWizard>
{
  late final SubjectRequestDraft _draft = widget.draft.copy();

  late final TextEditingController _topicController =
      TextEditingController(text: _draft.topic);
  late final TextEditingController _notesController =
      TextEditingController(text: _draft.notes);

  int _step = 0;
  bool _movingForward = true;
  bool _isSaving = false;

  Animation<double>? _route;

  @override
  void initState()
  {
    super.initState();

    if (widget.bands.length == 1)
    {
      _draft.band = widget.bands.single.band;
    }

    if (widget.toured)
    {
      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _route = ModalRoute.of(context)?.animation?..addStatusListener(_onRoute);
          bookingsSubjectOpen.value = true;
          desktopTourLit.addListener(_onTourLit);
          _startTour();
        }
      });
    }
  }

  // Closing: the tours waiting on the window learn it at once, not after its fade.
  void _onRoute(AnimationStatus status)
  {
    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed)
    {
      bookingsSubjectOpen.value = false;
    }
  }

  String? _tour(String id) => widget.toured ? id : null;

  // The wizard's tour, ended by the click that opened this window, leaves room for this one's.
  void _onTourLit()
  {
    if (mounted && desktopTourLit.value.isEmpty && bookingsSubjectOpen.value)
    {
      _startTour();
    }
  }

  // The card on show's parts never told, once it has slid in.
  void _startTour()
  {
    final BookingsSubjectCard? card = switch (_stepList[_step])
    {
      _Step.what => BookingsSubjectCard.what,
      _Step.duration => BookingsSubjectCard.duration,
      _Step.teachers => BookingsSubjectCard.teachers,
      _Step.notes => BookingsSubjectCard.notes,
      _Step.band => null,
    };

    final int step = _step;

    if (!widget.toured || card == null)
    {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async
    {
      if (!mounted || isDesktopTourShown)
      {
        return;
      }

      final DesktopTour? tour = await bookingsSubjectTour(
        card: card,
        first: step == (_choosesBand ? 1 : 0),
        editing: widget.isEditing,
        online: widget.mode == kOnlineMode,
        pupil: BookingsTourPupil.of(self: widget.isSelf, gender: widget.studentGender),
      );

      if (tour != null && mounted && _step == step)
      {
        startBookingsTour(context, tour, still: () => mounted && _step == step && !_isSaving);
      }
    });

    WidgetsBinding.instance.scheduleFrame();
  }

  BandOffer? get _offer => widget.bands.where((offer) => offer.band == _draft.band).firstOrNull;

  int? get _minutesAvailable => _offer?.minutes;

  bool get _choosesBand => widget.bands.length > 1;

  List<_Step> get _stepList => [
        if (_choosesBand) _Step.band,
        if (_draft.asksForTopicAndTag) _Step.what,
        _Step.duration,
        _Step.teachers,
        _Step.notes,
      ];

  int get _steps => _stepList.length;

  String? get _discipline => dividedDisciplineName(widget.ministrySubjects, _draft.ministrySubjectId, _draft.associationSubjectIds);

  @override
  void dispose()
  {
    _route?.removeStatusListener(_onRoute);
    desktopTourLit.removeListener(_onTourLit);

    if (widget.toured)
    {
      bookingsSubjectOpen.value = false;
    }

    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _goTo(int step)
  {
    if (step > _step && _blockedReason(_stepList[_step]) != null)
    {
      return;
    }

    setState(()
    {
      _movingForward = step > _step;
      _step = step.clamp(0, _steps - 1);
    });

    _startTour();
  }

  String? _blockedReason(_Step step)
  {
    if (step == _Step.band && _draft.band == null)
    {
      return kPickBandToGoOn;
    }

    if (step == _Step.what && _draft.tags.isEmpty)
    {
      return kPickKindToGoOn;
    }

    if (step == _Step.duration && _draft.duration == null)
    {
      return kPickDurationToGoOn;
    }

    if (step == _Step.duration && _exceeds)
    {
      return durationOverStay(
        _minutesTaken,
        _minutesAvailable ?? 0,
        isSelf: widget.isSelf,
        name: widget.studentName,
        band: _choosesBand ? _draft.band : null,
      );
    }

    return null;
  }

  String? get _saveBlockedReason
  {
    for (final step in _stepList)
    {
      final reason = _blockedReason(step);

      if (reason != null)
      {
        return reason;
      }
    }

    return null;
  }

  bool _canSave()
  {
    final String? reason = _saveBlockedReason;

    if (reason != null)
    {
      CustomSnackBar.show(context: context, message: reason, isError: true);

      return false;
    }

    return true;
  }

  Future<void> _save() async
  {
    if (_isSaving || !_canSave())
    {
      return;
    }

    _draft.topic = _topicController.text.trim();
    _draft.notes = _notesController.text.trim();

    setState(() => _isSaving = true);

    final saved = await widget.onSave(_draft);

    if (!mounted)
    {
      return;
    }

    setState(() => _isSaving = false);

    if (saved)
    {
      Navigator.of(context).pop();
    }
  }

  Widget _buildLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  Widget _buildBandStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final offer in widget.bands)
          SubjectPickRow(
            key: ValueKey(offer.band),
            name: bandLabel(offer.band),
            subtitle: '${offer.hours} · ${minutesLeftLabel(offer.left)}',
            selected: _draft.band == offer.band,
            hasChoice: false,
            onSelected: (_) => setState(() => _draft.band = offer.band),
            onEditDisciplines: () {},
          ),
      ],
    );
  }

  Widget _buildSubjectStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel(kLessonKindLabel, first: true),
        DesktopTourTarget(
          id: _tour(kTourBookingsSubjectKinds),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in bookingTagOptions)
                AppSelectableChip(
                  label: option.label,
                  selected: _draft.tags.contains(option.value),
                  onSelected: (selected) => setState(()
                  {
                    if (selected)
                    {
                      _draft.tags.add(option.value);

                      return;
                    }

                    _draft.tags.remove(option.value);
                  }),
                ),
            ],
          ),
        ),
        _buildLabel(kTopicLabel),
        DesktopTourTarget(
          id: _tour(kTourBookingsSubjectTopic),
          child: AppTextField(
            controller: _topicController,
            label: 'Argomento',
            showLabel: false,
            hintText: kTopicHint,
            maxLength: FieldLimits.topic,
          ),
        ),
      ],
    );
  }

  int get _minutesTaken => (_offer?.takenByOthers ?? 0) + (_draft.duration ?? 0);

  bool get _exceeds
  {
    final available = _minutesAvailable;

    return available != null && _minutesTaken > available;
  }

  Widget _buildDurationStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppFieldLabel(kDurationLabel),
              if (_minutesAvailable != null)
                DesktopTourTarget(
                  id: _tour(kTourBookingsSubjectCount),
                  child: Text(
                    '${formatMinutes(_minutesTaken)} di '
                    '${formatMinutes(_minutesAvailable!)}',
                    style: GoogleFonts.plusJakartaSans(
                      color: _exceeds ? AppTheme.trialDanger : AppTheme.trialTealDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
        DesktopTourTarget(
          id: _tour(kTourBookingsSubjectDurations),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final minutes in bookingDurationOptions)
                AppSelectableChip(
                  label: formatMinutes(minutes),
                  selected: _draft.duration == minutes,
                  onSelected: (_) => setState(() => _draft.duration = minutes),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeachersStep()
  {
    return DesktopTourTarget(
      id: _tour(kTourBookingsSubjectTeachers),
      child: AppDialogPill(
        expand: true,
        child: TeacherPicker(
          label: preferredTeachersLabel(widget.studentGender),
          icon: Icons.thumb_up_outlined,
          chosen: _draft.preferredTeacherTaxCodes,
          offered: teachersFitFirst(
            widget.teachers,
            disciplineIds: _draft.disciplineIds,
            studyProgramId: widget.studentStudyProgramId,
          ),
          max: SubjectRequestDraft.maxPreferredTeachers,
          onChanged: () => setState(() {}),
          searchTour: _tour(kTourBookingsSubjectSearch),
        ),
      ),
    );
  }

  Widget _buildNotesStep()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLabel(kTeacherNotesLabel, first: true),
        DesktopTourTarget(
          id: _tour(kTourBookingsSubjectNotes),
          child: AppTextField(
            controller: _notesController,
            label: 'Note',
            showLabel: false,
            hintText: kTeacherNotesHint,
            maxLength: FieldLimits.notes,
            maxLines: 4,
            minLines: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildStep()
  {
    return switch (_stepList[_step])
    {
      _Step.band => AppDialogPill(expand: true, child: _buildBandStep()),
      _Step.what => AppDialogPill(expand: true, child: _buildSubjectStep()),
      _Step.duration => AppDialogPill(expand: true, child: _buildDurationStep()),
      _Step.teachers => _buildTeachersStep(),
      _Step.notes => AppDialogPill(expand: true, child: _buildNotesStep()),
    };
  }

  void _remove()
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmSubjectRemoval',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: kRemovalEyebrow,
        title: 'Confermi?',
        showClose: false,
        maxWidth: _confirmWidth,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'RIMUOVI',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              Navigator.pop(context);
              widget.onRemove?.call();
            },
          ),
        ),
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: switch (_discipline)
                {
                  final String discipline => [
                      TextSpan(
                        text: disciplineLabel(_draft.displayName, discipline),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: kDisciplineRemovalAfter),
                    ],
                  null => [
                      const TextSpan(text: kSubjectRemovalBefore),
                      TextSpan(
                        text: _draft.displayName,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: kSubjectRemovalAfter),
                    ],
                },
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget save = DesktopTourTarget(
      id: _tour(kTourBookingsSubjectSave),
      child: AppGradientButton(
        label: widget.isEditing ? 'SALVA' : 'AGGIUNGI',
        icon: Icons.check_rounded,
        busy: _isSaving,
        height: _dialogButtonHeight,
        fontSize: _dialogButtonFontSize,
        onPressed: _save,
      ),
    );

    final String? discipline = _discipline;

    // Divided subject: the discipline is the title, its subject goes in the eyebrow.
    return AppDialogStack(
      eyebrow: [
        'Passo ${_step + 1} di $_steps',
        if (discipline != null) _draft.displayName,
        modeLabel(widget.mode).toLowerCase(),
      ].join(' · '),
      title: discipline ?? (widget.isEditing ? kEditSubjectTitle : kAddSubjectTitle),
      maxWidth: _stackWidth,
      footer: widget.onRemove == null
          ? AppDialogFooter.single(save)
          : AppDialogFooter(
              secondary: AppGradientButton(
                label: 'RIMUOVI',
                icon: Icons.delete_outline_rounded,
                gradient: AppTheme.dangerGradient,
                accent: AppTheme.trialDanger,
                height: _dialogButtonHeight,
                fontSize: _dialogButtonFontSize,
                onPressed: _remove,
              ),
              primary: save,
            ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _guideWidth),
            child: AppDialogPill(
              expand: true,
              child: PersonEditGuide(
                question: _stepList[_step].questionFor(isSelf: widget.isSelf),
                hint: _stepList[_step].hintFor(studentName: widget.studentName, isSelf: widget.isSelf),
              ),
            ),
          ),
        ),
        AppCarouselFrame(
          index: _step,
          movingForward: _movingForward,
          maxContentWidth: _cardWidth,
          canGoBack: _step > 0,
          canGoForward: _step < _steps - 1,
          forwardBlockedReason: _blockedReason(_stepList[_step]),
          onBack: () => _goTo(_step - 1),
          onForward: () => _goTo(_step + 1),
          forwardTour: _tour(kTourBookingsSubjectForward),
          child: _buildStep(),
        ),
      ],
    );
  }
}
