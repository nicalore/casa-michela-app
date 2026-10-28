import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../routing/app_router.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/corner_glow.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../../dashboard/widgets/dashboard_greeting.dart';
import '../legal_documents.dart';
import '../../people/edit/person_edit_report_dialog.dart';
import '../../people/models/child_item.dart';
import '../../people/models/person_item.dart';
import '../../people/widgets/person_detail_widgets.dart';
import '../../people/widgets/school_enrollment_edit_row.dart';
import '../../people/widgets/teacher_competences_editor.dart';
import '../onboarding_steps.dart';
import 'contacts_card.dart';
import 'onboarding_record_step.dart';
import 'onboarding_school_step.dart';
import 'onboarding_subjects_step.dart';
import 'onboarding_terms_step.dart';
import 'teacher_education_card.dart';

const double _maxContentWidth = 1240;

// No top bar here, so the flow starts where the bar would sit.
const double _contentTopInset = 44;
const double _compactTopInset = 24;

const double _contentBottomInset = 28;

// Below the wide window (AppPageDensity): a lower heading, the step's buttons pinned under its content.
const double _denseWelcomeSize = 32;
const double _denseTitleSize = 24;
const double _denseQuestionSize = 14;
const double _denseWelcomeGap = 14;
const double _denseHeaderGap = 12;
const double _denseBottomInset = 16;
const double _footerTopGap = 14;

// The wide window's gaps around the step.
const double _headerGap = 20;
const double _wideFooterTopGap = 20;
const double _footerRowGap = 10;

// Between the pinned buttons and a message raised over them.
const double _messageGap = 12;

class OnboardingLayout extends StatefulWidget
{
  final double width;
  final double height;

  const OnboardingLayout({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<OnboardingLayout> createState() => _OnboardingLayoutState();
}

class _OnboardingLayoutState extends State<OnboardingLayout>
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isFinishing = false;
  bool _isLeaving = false;
  String? _errorMessage;

  MeResponse? _me;
  PersonItem? _person;

  // Keyed by tax code.
  final Map<String, PersonItem> _children = {};

  List<OnboardingStep> _steps = const [];
  int _index = 0;
  bool _movingForward = true;

  TeacherEducationDraft? _education;
  ContactsDraft? _contacts;
  TeacherCompetencesDraft? _competences;

  bool _termsAccepted = false;
  bool _termsSaved = false;

  @override
  void initState()
  {
    super.initState();

    _load();
  }

  Future<void> _load() async
  {
    try
    {
      final me = await _apiService.me();
      final person = await _apiService.getPerson(me.taxCode);

      // Past the flow only the terms are left, and they ask nothing about the children.
      final children = me.onboardingRequired ? person.children ?? const [] : const <ChildItem>[];

      for (final child in children)
      {
        _children[child.fiscalCode] = await _apiService.getPerson(
          child.fiscalCode,
        );
      }

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _me = me;
        _person = person;
        _steps = onboardingStepsFor(
          roles: me.availableRoles,
          children: children,
          terms: me.termsRequired,
          onboarding: me.onboardingRequired,
        );
        _isLoading = false;
      });
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _errorMessage = readableApiError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reload(String taxCode) async
  {
    try
    {
      final person = await _apiService.getPerson(taxCode);

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
      // Intentionally ignored: the screen keeps the copy it already has.
    }
  }

  // Set while a page builds (all steps build for the handover), so getters read its step.
  int? _building;

  int get _shown => _building ?? _index;

  OnboardingStep get _step => _steps[_shown];

  PersonItem get _subject
  {
    final taxCode = _step.childTaxCode;

    return taxCode == null ? _person! : _children[taxCode]!;
  }

  bool get _isLast => _shown == _steps.length - 1;

  bool get _isSchoolStep =>
      _step.kind == OnboardingStepKind.childSchool || _step.kind == OnboardingStepKind.ownSchool;

  // Lesson planning runs on the current school year, so the step requires one.
  bool get _missingCurrentSchoolYear
  {
    if (!_isSchoolStep)
    {
      return false;
    }

    final int current = currentSchoolYearStart();

    return !(_subject.schoolEnrollments ?? const [])
        .any((enrollment) => enrollment.startYear == current);
  }

  static const String _currentYearReason =
      "Inserisci l'anno scolastico in corso per proseguire.";

  // On the pinned buttons: the shown step's, keyed so a message can be raised above them.
  final GlobalKey _footerKey = GlobalKey();

  // An error raised over the step's buttons, which sit at the window's bottom.
  void _refuse(String message)
  {
    final RenderObject? footer = _footerKey.currentContext?.findRenderObject();
    double above = 0;

    if (footer is RenderBox && footer.hasSize)
    {
      above = MediaQuery.sizeOf(context).height - footer.localToGlobal(Offset.zero).dy + _messageGap;
    }

    CustomSnackBar.show(context: context, message: message, isError: true, above: above);
  }

  Future<void> _forward() async
  {
    if (_missingCurrentSchoolYear)
    {
      _refuse(_currentYearReason);

      return;
    }

    if (_step.kind == OnboardingStepKind.terms)
    {
      if (!_termsAccepted)
      {
        _refuse(kTermsRefusal);

        return;
      }

      if (!_termsSaved)
      {
        try
        {
          await _apiService.acceptTerms();
          _termsSaved = true;
        }
        catch (e)
        {
          if (mounted)
          {
            _refuse(readableApiError(e));
          }

          return;
        }
      }
    }

    final ContactsDraft? contacts = _contacts;

    if (contacts != null && contacts.differsFrom(_subject))
    {
      try
      {
        await _apiService.updateContacts(
          taxCode: _subject.fiscalCode,
          email: contacts.email,
          phoneNumber: contacts.phoneNumber,
        );
      }
      catch (e)
      {
        if (mounted)
        {
          _refuse(readableApiError(e));
        }

        return;
      }

      await _reload(_subject.fiscalCode);
    }

    final TeacherCompetencesDraft? competences = _competences;

    if (_step.kind == OnboardingStepKind.teacherSubjects &&
        competences != null &&
        !competences.isEmpty)
    {
      try
      {
        await _apiService.updateTeacherCompetences(
          _subject.fiscalCode,
          competences.competences,
          competences.services,
          _subject.teacherUpdatedAt,
        );
      }
      catch (e)
      {
        if (mounted)
        {
          _refuse(readableApiError(e));
        }

        return;
      }

      await _reload(_subject.fiscalCode);
    }

    if (_step.kind == OnboardingStepKind.ownRecord && _education != null)
    {
      try
      {
        await _apiService.updateTeacherEducation(
          taxCode: _me!.taxCode,
          schoolEducation: _education!.schoolEducation,
          universityEducation: _education!.universityEducation,
        );
      }
      catch (e)
      {
        if (mounted)
        {
          _refuse(readableApiError(e));
        }

        return;
      }
    }

    if (!_isLast)
    {
      setState(()
      {
        _index++;
        _movingForward = true;
        _education = null;
        _contacts = null;
        _competences = null;
      });

      return;
    }

    setState(() => _isFinishing = true);

    try
    {
      final me = await _apiService.completeOnboarding();

      if (!mounted)
      {
        return;
      }

      context.go(homeForRole(me.activeRole));
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _isFinishing = false);
        _refuse(readableApiError(e));
      }
    }
  }

  void _report()
  {
    showAnagraphicErrorReportDialog(
      context,
      _subject,
      fields: [
        ...kPersonalReportableFields,
        ...associationReportableFields(_subject.roles, forOwner: !_step.isAboutAChild),
      ],
      eyebrow: _step.isAboutAChild
          ? 'Dati di ${_step.childName}'
          : 'I tuoi dati',
    );
  }

  // The flag stays unset, so the flow starts over next login.
  Future<void> _backToLogin() async
  {
    setState(() => _isLeaving = true);

    await _apiService.logout();

    if (!mounted)
    {
      return;
    }

    context.go('/login');
  }

  Widget _buildBody()
  {
    switch (_step.kind)
    {
      case OnboardingStepKind.terms:
        return OnboardingTermsStep(
          key: const ValueKey('terms'),
          accepted: _termsAccepted,
          onChanged: (accepted) => setState(() => _termsAccepted = accepted),
        );

      case OnboardingStepKind.ownRecord:
        return OnboardingRecordStep(
          key: const ValueKey('own-record'),
          person: _person!,
          isOwnRecord: true,
          accountRoles: _me!.availableRoles,
          onEducationChanged: (draft) => _education = draft,
          onContactsChanged: (draft) => _contacts = draft,
          onUpdated: () => _reload(_me!.taxCode),
        );

      case OnboardingStepKind.childRecord:
        return OnboardingRecordStep(
          key: ValueKey('record-${_step.childTaxCode}'),
          person: _subject,
          isOwnRecord: false,
          onContactsChanged: (draft) => _contacts = draft,
          accountRoles: const [],
          onUpdated: () => _reload(_subject.fiscalCode),
        );

      case OnboardingStepKind.childSchool:
      case OnboardingStepKind.ownSchool:
        return OnboardingSchoolStep(
          key: ValueKey('school-${_subject.fiscalCode}'),
          person: _subject,
          onUpdate: () => _reload(_subject.fiscalCode),
        );

      case OnboardingStepKind.teacherSubjects:
        return OnboardingSubjectsStep(
          key: ValueKey('subjects-${_subject.fiscalCode}'),
          person: _subject,
          onChanged: (draft) => _competences = draft,
        );
    }
  }

  // Set when the documents changed after an acceptance: the only step, with its own words.
  DateTime? get _termsUpdate => _me?.termsUpdate;

  String get _welcome
  {
    return _termsUpdate == null ? onboardingWelcome(_person!.gender) : onboardingWelcomeBack(_person!.gender);
  }

  String get _eyebrow
  {
    final DateTime? update = _termsUpdate;

    return update == null ? 'PASSO ${_shown + 1} DI ${_steps.length}' : termsUpdateEyebrow(update).toUpperCase();
  }

  String get _title => _termsUpdate == null ? onboardingStepTitle(_step) : kTermsUpdateTitle;

  String get _question => _termsUpdate == null ? onboardingStepQuestion(_step) : kTermsUpdateText;

  bool get _canReport
  {
    return switch (_step.kind)
    {
      OnboardingStepKind.ownRecord || OnboardingStepKind.childRecord => true,
      _ => false,
    };
  }

  Widget _buildWelcome(AppWindowSize size)
  {
    return DashboardGreeting(
      firstName: _person!.firstName,
      text: _welcome,
      alignment: Alignment.center,
      fontSize: size.isDense ? _denseWelcomeSize : 58,
    );
  }

  Widget _buildHeader(AppWindowSize size)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _eyebrow,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size.isDense ? _denseTitleSize : 38,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: AppTheme.trialOcean,
          ),
        ),
        SizedBox(height: size.isDense ? 6 : 10),
        Text(
          _question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size.isDense ? _denseQuestionSize : 15,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: AppTheme.trialMutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildStepPage(int index, AppWindowSize size)
  {
    _building = index;

    try
    {
      // The step's buttons stay in sight under it at every size; only the step scrolls.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.frame,
            child: _buildHeader(size),
          ),
          SizedBox(height: size.isDense ? _denseHeaderGap : _headerGap),
          Expanded(child: _buildBody()),
          SizedBox(height: size.isDense ? _footerTopGap : _wideFooterTopGap),
          PageTransitionItem(
            slot: PageTransitionItem.frame,
            child: KeyedSubtree(
              key: index == _index ? _footerKey : null,
              child: size.isMinimal ? _buildTwoRowFooter() : _buildFooter(),
            ),
          ),
        ],
      );
    }
    finally
    {
      _building = null;
    }
  }

  Widget get _exitButton
  {
    return AppGradientButton(
      label: 'TORNA AL LOGIN',
      icon: Icons.logout_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      busy: _isLeaving,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _backToLogin,
    );
  }

  Widget get _backButton
  {
    return _shown > 0
        ? AppGradientButton(
            label: 'INDIETRO',
            icon: Icons.chevron_left_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: kPersonDialogButtonHeight,
            fontSize: kPersonDialogButtonFontSize,
            onPressed: () => setState(()
            {
              _index--;
              _movingForward = false;
              _education = null;
              _contacts = null;
              _competences = null;
            }),
          )
        : const SizedBox.shrink();
  }

  Widget get _reportButton
  {
    return AppGradientButton(
      label: 'SEGNALA ERRORE',
      icon: Icons.flag_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _report,
    );
  }

  Widget get _forwardButton
  {
    return AppGradientButton(
      label: _isLast ? 'CONCLUDI' : 'AVANTI',
      icon: _isLast
          ? Icons.done_all_rounded
          : Icons.chevron_right_rounded,
      busy: _isFinishing,
      disabledReason: _missingCurrentSchoolYear ? _currentYearReason : null,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _forward,
    );
  }

  Widget _buildFooter()
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: _backButton,
          ),
        ),
        // Stacked, the two take the width of the wider one.
        IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canReport) ...[
                _reportButton,
                const SizedBox(height: 14),
              ],
              _exitButton,
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: _forwardButton,
          ),
        ),
      ],
    );
  }

  // Minimal windows: back and forward on one line, report and exit on the next.
  Widget _buildTwoRowFooter()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _backButton,
            const Spacer(),
            _forwardButton,
          ],
        ),
        const SizedBox(height: _footerRowGap),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: _footerRowGap,
          runSpacing: _footerRowGap,
          children: [
            if (_canReport) _reportButton,
            _exitButton,
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.of(context);
    final double margin = AppBreakpoints.pageMargin(size);

    final double contentWidth = math.min(
      widget.width - 2 * margin,
      _maxContentWidth,
    );

    return Container(
      width: widget.width,
      height: widget.height,
      color: AppTheme.trialPaper,
      child: Stack(
        children: [
          const CornerGlow(
            corner: GlowCorner.topRight,
            tint: AppTheme.trialDeepWater,
            edgeTint: AppTheme.trialOcean,
            intensity: 1.25,
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
          ),
          const PageWatermark(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                margin,
                size.isDense ? _compactTopInset : _contentTopInset,
                margin,
                size.isDense ? _denseBottomInset : _contentBottomInset,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: AppPageDensity(dense: size.isDense, child: _buildContent(size)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTealDeep));
    }

    if (_errorMessage != null || _person == null || _steps.isEmpty)
    {
      return Center(
        child: Text(
          _errorMessage ?? 'Non è stato possibile aprire il primo accesso.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWelcome(size),
        SizedBox(height: size.isDense ? _denseWelcomeGap : 28),
        Expanded(
          child: ShellDestinations(
            currentIndex: _index,
            reversed: !_movingForward,
            children: [
              for (var i = 0; i < _steps.length; i++) _buildStepPage(i, size),
            ],
          ),
        ),
      ],
    );
  }
}
