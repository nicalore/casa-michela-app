import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/onboarding/onboarding_steps.dart';
import '../../../features/onboarding/widgets/contacts_card.dart' show ContactsDraft;
import '../../../features/onboarding/widgets/teacher_education_card.dart' show TeacherEducationDraft;
import '../../../features/people/models/person_item.dart';
import '../../../features/people/widgets/school_enrollment_edit_row.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_flow_page.dart';
import '../../shared/widgets/mobile_info_sheet.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_slot_button.dart';
import '../profile/widgets/mobile_report_sheet.dart';
import '../subjects/mobile_subjects_page.dart';
import 'widgets/mobile_first_access_parts.dart';
import 'widgets/mobile_record_step.dart';
import 'widgets/mobile_school_step.dart';

// Before the first step: the welcome page.
const int _welcome = -1;

const double _headGap = 20;
const double _ownButtonGap = 18;
// Matches a section head's offset under the status bar, Discipline's included.
const double _phoneTop = 4;

const String _currentYearReason = "Inserisci l'anno scolastico in corso per proseguire.";
const String _loadFailed = 'Non è stato possibile aprire il primo accesso.';

class MobileOnboardingPage extends StatefulWidget
{
  const MobileOnboardingPage({super.key});

  @override
  State<MobileOnboardingPage> createState() => _MobileOnboardingPageState();
}

class _MobileOnboardingPageState extends State<MobileOnboardingPage>
{
  final ApiService _apiService = ApiService();

  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  bool _leaving = false;

  MeResponse? _me;
  PersonItem? _person;

  // Keyed by tax code.
  final Map<String, PersonItem> _children = {};

  List<OnboardingStep> _steps = const [];

  int _index = _welcome;
  bool _forwards = true;

  ContactsDraft? _contacts;
  TeacherEducationDraft? _education;

  // One per school step: two consecutive school steps are both mounted mid-slide.
  final Map<int, GlobalKey<MobileSchoolStepState>> _schoolKeys = {};

  @override
  void initState()
  {
    super.initState();
    _load().whenComplete(MobileHoldScope.hold(context));
  }

  Future<void> _load() async
  {
    try
    {
      final MeResponse me = await _apiService.me();
      final PersonItem person = await _apiService.getPerson(me.taxCode);

      final children = person.children ?? const [];

      for (final child in children)
      {
        _children[child.fiscalCode] = await _apiService.getPerson(child.fiscalCode);
      }

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _me = me;
        _person = person;
        _steps = onboardingStepsFor(roles: me.availableRoles, children: children);
        _loading = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento del primo accesso');

      if (mounted)
      {
        setState(()
        {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _reload(String taxCode) async
  {
    try
    {
      final PersonItem person = await _apiService.getPerson(taxCode);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        if (taxCode == _me?.taxCode)
        {
          _person = person;
        }
        else
        {
          _children[taxCode] = person;
        }
      });
    }
    catch (_)
    {
      // Intentionally ignored: what is shown stays.
    }
  }

  OnboardingStep get _step => _steps[_index];

  PersonItem _subjectOf(OnboardingStep step)
  {
    final String? taxCode = step.childTaxCode;

    return taxCode == null ? _person! : _children[taxCode]!;
  }

  bool get _isLast => _index == _steps.length - 1;

  bool _missingCurrentSchoolYear(OnboardingStep step)
  {
    if (step.kind != OnboardingStepKind.childSchool && step.kind != OnboardingStepKind.ownSchool)
    {
      return false;
    }

    final int current = currentSchoolYearStart();

    return !(_subjectOf(step).schoolEnrollments ?? const [])
        .any((enrollment) => enrollment.startYear == current);
  }

  List<String> _paragraphsOf(OnboardingStep step)
  {
    return [
      onboardingStepQuestion(step, arrows: false),
      if (step.kind == OnboardingStepKind.teacherSubjects) kMobileSlideToRemove,
    ];
  }

  void _explain(OnboardingStep step)
  {
    showMobileInfoSheet(
      context: context,
      title: onboardingStepTitle(step),
      paragraphs: _paragraphsOf(step),
    );
  }

  // Once per person and step; a parent's steps are told apart by the child.
  Future<void> _introduceOnce(OnboardingStep step)
  {
    final MeResponse? me = _me;

    if (me == null || !mounted)
    {
      return Future<void>.value();
    }

    final String? child = step.childTaxCode;

    return showMobileInfoSheetOnce(
      context: context,
      taxCode: me.taxCode,
      slug: 'first-access/${step.kind.name}${child == null ? '' : '/$child'}',
      title: onboardingStepTitle(step),
      paragraphs: _paragraphsOf(step),
    );
  }

  void _go(int index)
  {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(()
    {
      _forwards = index > _index;
      _index = index;
      _contacts = null;
      _education = null;
    });

    if (index >= 0)
    {
      final OnboardingStep step = _steps[index];

      // After the slide, not over it.
      Future<void>.delayed(kMobileFlowTurn, ()
      {
        if (mounted && _index == index)
        {
          _introduceOnce(step);
        }
      });
    }
  }

  Future<void> _saveContacts(PersonItem subject) async
  {
    final ContactsDraft? contacts = _contacts;

    if (contacts == null || !contacts.differsFrom(subject))
    {
      return;
    }

    await _apiService.updateContacts(
      taxCode: subject.fiscalCode,
      email: contacts.email,
      phoneNumber: contacts.phoneNumber,
    );

    await _reload(subject.fiscalCode);
  }

  Future<void> _saveEducation(PersonItem subject) async
  {
    final TeacherEducationDraft? education = _education;

    if (education == null ||
        (education.schoolEducation == subject.schoolEducation &&
            education.universityEducation == subject.universityEducation))
    {
      return;
    }

    await _apiService.updateTeacherEducation(
      taxCode: subject.fiscalCode,
      schoolEducation: education.schoolEducation,
      universityEducation: education.universityEducation,
    );

    await _reload(subject.fiscalCode);
  }

  // Refuses on tap with a reason, never through a disabled button.
  Future<void> _forward() async
  {
    if (_busy)
    {
      return;
    }

    if (_index == _welcome)
    {
      _go(0);
      return;
    }

    final OnboardingStep step = _step;

    if (_missingCurrentSchoolYear(step))
    {
      MobileNotice.show(context, _currentYearReason, error: true);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);

    try
    {
      final PersonItem subject = _subjectOf(step);

      await _saveContacts(subject);

      if (step.kind == OnboardingStepKind.ownRecord)
      {
        await _saveEducation(subject);
      }

      if (!_isLast)
      {
        if (mounted)
        {
          setState(() => _busy = false);
          _go(_index + 1);
        }

        return;
      }

      // The returned identity ends the first access; the app routes home by itself.
      await _apiService.completeOnboarding();
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _busy = false);
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
  }

  void _back()
  {
    if (!_busy && _index > _welcome)
    {
      _go(_index - 1);
    }
  }

  // The flag stays unset, so the flow starts over at the next sign-in.
  Future<void> _leave() async
  {
    setState(() => _leaving = true);
    await _apiService.logout();
  }

  // Discipline brings its own buttons.
  bool _hasOwnButton(OnboardingStep step) => step.kind != OnboardingStepKind.teacherSubjects;

  void _report(OnboardingStep step)
  {
    final PersonItem subject = _subjectOf(step);
    final String? name = step.childName;

    showMobileReportSheet(
      context: context,
      person: subject,
      fields: [
        ...kPersonalReportableFields,
        ...associationReportableFields(subject.roles),
      ],
      eyebrow: name == null ? 'I tuoi dati' : 'Dati di $name',
    );
  }

  Widget? _buildOwnButton(OnboardingStep step)
  {
    final int index = _index;

    return switch (step.kind)
    {
      OnboardingStepKind.ownRecord || OnboardingStepKind.childRecord => MobileDismissButton(
          label: 'Segnala dato mancante / errato',
          icon: Icons.flag_rounded,
          onPressed: () => _report(step),
        ),
      OnboardingStepKind.childSchool || OnboardingStepKind.ownSchool => MobileSlotButton(
          label: 'Aggiungi anno',
          icon: Icons.add_rounded,
          onPressed: () => _schoolKeys[index]?.currentState?.add(),
        ),
      OnboardingStepKind.teacherSubjects => null,
    };
  }

  Widget _buildCapsule()
  {
    return MobileFlowCapsule(onTap: _leave, busy: _leaving);
  }

  String get _greeting => onboardingWelcome(_person!.gender);

  List<String> get _stepTitles => [for (final step in _steps) onboardingStepTitle(step)];

  Widget _buildHead(OnboardingStep step, {required bool tablet, required bool rail})
  {
    return MobileFlowHead(
      eyebrow: 'Passo ${_index + 1} di ${_steps.length}',
      title: onboardingStepTitle(step),
      tablet: tablet,
      capsule: rail ? null : _buildCapsule(),
      onInfo: () => _explain(step),
    );
  }

  Widget _buildStep(OnboardingStep step, {required bool tablet, required bool rail})
  {
    final double margin = MobileFlowScaffold.marginOf(tablet: tablet);
    final double endRoom = MobileFlowScaffold.endRoomOf(context);
    final Widget head = _buildHead(step, tablet: tablet, rail: rail);
    final PersonItem subject = _subjectOf(step);

    if (step.kind == OnboardingStepKind.teacherSubjects)
    {
      return MobileSubjectsPage(heading: head, endRoom: endRoom);
    }

    final Widget body = switch (step.kind)
    {
      OnboardingStepKind.ownRecord || OnboardingStepKind.childRecord => MobileRecordStep(
          person: subject,
          owner: step.isAboutAChild ? null : _me,
          accountRoles: step.isAboutAChild ? const [] : _me!.availableRoles,
          onContactsChanged: (draft) => _contacts = draft,
          onEducationChanged: (draft) => _education = draft,
          tablet: tablet,
          margin: margin,
        ),
      _ => MobileSchoolStep(
          key: _schoolKeys.putIfAbsent(_index, GlobalKey<MobileSchoolStepState>.new),
          person: subject,
          onChanged: () => _reload(subject.fiscalCode),
          tablet: tablet,
          margin: margin,
        ),
    };

    return ListView(
      padding: EdgeInsets.only(top: _phoneTop, bottom: endRoom),
      children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: margin), child: head),
        const SizedBox(height: _headGap),
        body,
        if (_hasOwnButton(step)) ...[
          const SizedBox(height: _ownButtonGap),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: tablet
                ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: _buildOwnButton(step)))
                : _buildOwnButton(step),
          ),
        ],
      ],
    );
  }

  Widget _buildPage({required bool tablet, required bool rail})
  {
    if (_index == _welcome)
    {
      return MobileFirstAccessWelcome(
        greeting: _greeting,
        steps: _stepTitles,
        capsule: _buildCapsule(),
        tablet: tablet,
      );
    }

    return _buildStep(_step, tablet: tablet, rail: rail);
  }

  // Slide only: a fade would lay an opacity over the glass.
  Widget _buildSwitcher({required bool tablet, required bool rail})
  {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: kMobileFlowTurn,
        switchInCurve: kMobileFlowTurnCurve,
        switchOutCurve: kMobileFlowTurnCurve,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation)
        {
          final bool incoming = child.key == ValueKey(_index);
          final double side = (incoming == _forwards) ? 1 : -1;

          // Clipped so a deck's overflowing cards do not ride over the incoming page.
          return SlideTransition(
            position: Tween<Offset>(begin: Offset(side, 0), end: Offset.zero).animate(animation),
            child: ClipRect(child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_index),
          child: _buildPage(tablet: tablet, rail: rail),
        ),
      ),
    );
  }

  Widget? _buildFooter()
  {
    if (_index == _welcome)
    {
      return MobileFlowFooter(
        label: kFirstAccessStart,
        icon: Icons.arrow_forward_rounded,
        onPressed: _forward,
      );
    }

    return MobileFlowFooter(
      label: _isLast ? 'Concludi' : 'Avanti',
      icon: _isLast ? Icons.done_all_rounded : Icons.arrow_forward_rounded,
      busy: _busy,
      onPressed: _forward,
      onBack: _back,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final bool ready = !_loading && !_failed && _person != null && _steps.isNotEmpty;

    final bool rail = ready &&
        tablet &&
        _index > _welcome &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // One scaffold across loading so the buttons rise into place instead of jumping.
    final Widget body = MobileLoadSwitcher(
      waiting: _loading,
      child: ready
          ? _buildSwitcher(tablet: tablet, rail: rail)
          : _Status(
              waiting: _loading,
              capsule: _loading ? null : _buildCapsule(),
              tablet: tablet,
            ),
    );

    return PopScope(
      canPop: _index == _welcome,
      onPopInvokedWithResult: (didPop, _)
      {
        if (!didPop)
        {
          _back();
        }
      },
      child: MobileFlowScaffold(
        tablet: tablet,
        footer: ready ? _buildFooter() : null,
        aside: rail
            ? MobileFirstAccessRail(
                greeting: _greeting,
                steps: _stepTitles,
                current: _index,
                capsule: _buildCapsule(),
              )
            : null,
        asideWidth: MobileFirstAccessRail.width,
        body: body,
      ),
    );
  }
}

class _Status extends StatelessWidget
{
  final bool waiting;
  final Widget? capsule;
  final bool tablet;

  const _Status({required this.waiting, required this.capsule, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final Widget? capsule = this.capsule;
    final double margin = MobileFlowScaffold.marginOf(tablet: tablet);

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, _phoneTop, margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (capsule != null) Align(alignment: Alignment.centerRight, child: capsule),
          Expanded(
            child: Center(
              child: waiting
                  ? const SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                    )
                  : Text(
                      _loadFailed,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
