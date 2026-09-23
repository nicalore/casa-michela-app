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
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/page_watermark.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../../dashboard/widgets/dashboard_greeting.dart';
import '../../people/edit/person_edit_report_dialog.dart';
import '../../people/models/person_item.dart';
import '../../people/widgets/person_detail_widgets.dart';
import '../../people/widgets/school_enrollment_edit_row.dart';
import '../../people/widgets/teacher_competences_editor.dart';
import '../onboarding_steps.dart';
import 'contacts_card.dart';
import 'onboarding_record_step.dart';
import 'onboarding_school_step.dart';
import 'onboarding_subjects_step.dart';
import 'teacher_education_card.dart';

const double _maxContentWidth = 1240;

// No top bar here, so the flow starts where the bar used to sit.
const double _contentTopInset = 44;
const double _compactTopInset = 24;

const double _contentBottomInset = 28;

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

      final children = person.children ?? const [];

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

  // All steps are built at once for the handover; set while a page is being built
  // so the getters read its step rather than the current one.
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

  Future<void> _forward() async
  {
    if (_missingCurrentSchoolYear)
    {
      CustomSnackBar.show(context: context, message: _currentYearReason, isError: true);

      return;
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
          CustomSnackBar.show(
            context: context,
            message: readableApiError(e),
            isError: true,
          );
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
          CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
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
          isHighSchoolStudent: _education!.isHighSchoolStudent,
          schoolEducation: _education!.schoolEducation,
          universityEducation: _education!.universityEducation,
        );
      }
      catch (e)
      {
        if (mounted)
        {
          CustomSnackBar.show(
            context: context,
            message: readableApiError(e),
            isError: true,
          );
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
        CustomSnackBar.show(
          context: context,
          message: readableApiError(e),
          isError: true,
        );
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
        ...associationReportableFields(_subject.roles),
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

  Widget _buildBody(Widget footer)
  {
    switch (_step.kind)
    {
      case OnboardingStepKind.ownRecord:
        return OnboardingRecordStep(
          key: const ValueKey('own-record'),
          person: _person!,
          isOwnRecord: true,
          accountRoles: _me!.availableRoles,
          onEducationChanged: (draft) => _education = draft,
          onContactsChanged: (draft) => _contacts = draft,
          onUpdated: () => _reload(_me!.taxCode),
          footer: footer,
        );

      case OnboardingStepKind.childRecord:
        return OnboardingRecordStep(
          key: ValueKey('record-${_step.childTaxCode}'),
          person: _subject,
          isOwnRecord: false,
          onContactsChanged: (draft) => _contacts = draft,
          accountRoles: const [],
          onUpdated: () => _reload(_subject.fiscalCode),
          footer: footer,
        );

      case OnboardingStepKind.childSchool:
      case OnboardingStepKind.ownSchool:
        return OnboardingSchoolStep(
          key: ValueKey('school-${_subject.fiscalCode}'),
          person: _subject,
          onUpdate: () => _reload(_subject.fiscalCode),
          footer: footer,
        );

      case OnboardingStepKind.teacherSubjects:
        return OnboardingSubjectsStep(
          key: ValueKey('subjects-${_subject.fiscalCode}'),
          person: _subject,
          onChanged: (draft) => _competences = draft,
          footer: footer,
        );
    }
  }

  // 'M' and 'F' as the register stores them; anything else gets both endings.
  String get _welcome
  {
    return switch (_person!.gender?.toUpperCase())
    {
      'M' => 'Benvenuto',
      'F' => 'Benvenuta',
      _ => 'Benvenuto/a',
    };
  }

  String get _title
  {
    final String? name = _step.childName;

    return switch (_step.kind)
    {
      OnboardingStepKind.ownRecord => 'I tuoi dati',
      OnboardingStepKind.childRecord => 'I dati di $name',
      OnboardingStepKind.childSchool => 'Il percorso scolastico di $name',
      OnboardingStepKind.ownSchool => 'Il tuo percorso scolastico',
      OnboardingStepKind.teacherSubjects => 'Le tue discipline',
    };
  }

  String get _question
  {
    final String? name = _step.childName;

    return switch (_step.kind)
    {
      OnboardingStepKind.ownRecord =>
        'Scorri le schede con le frecce e verifica che le informazioni siano corrette. '
            'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente la foto profilo e i dati di contatto.',
      OnboardingStepKind.childRecord =>
        'Scorri le schede con le frecce e verifica che le informazioni di $name siano corrette. '
            'Se trovi un errore, ti preghiamo di segnalarlo utilizzando il bottone in fondo. Puoi modificare direttamente i dati di contatto.',
      OnboardingStepKind.childSchool =>
        'Verifica che il percorso scolastico di $name sia corretto e, se necessario, modificalo. '
            'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul suo percorso. Non sarà possibile modificare questi dati una volta confermati.',
      OnboardingStepKind.ownSchool =>
        'Verifica che il tuo percorso scolastico sia corretto e, se necessario, modificalo. '
            'Puoi anche aggiungere altri anni scolastici per fornirci maggiori informazioni sul tuo percorso. Non sarà possibile modificare questi dati una volta confermati.',
      OnboardingStepKind.teacherSubjects =>
        'Indica le discipline che desideri insegnare e, per ognuna, i percorsi di studio per cui sei disponibile. '
            'Ti consigliamo di prestare attenzione a questo passaggio, perché le informazioni inserite verranno utilizzate per assegnarti le lezioni. Potrai modificare questi dati anche in un secondo momento.',
    };
  }

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
      fontSize: size.isCompact ? 40 : 58,
    );
  }

  Widget _buildHeader(AppWindowSize size)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSO ${_shown + 1} DI ${_steps.length}',
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
            fontSize: size.isCompact ? 28 : 38,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: AppTheme.trialOcean,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _question,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTransitionItem(
            slot: PageTransitionItem.frame,
            child: _buildHeader(size),
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildBody(_buildFooter())),
        ],
      );
    }
    finally
    {
      _building = null;
    }
  }

  Widget _buildFooter()
  {
    final Widget exit = AppGradientButton(
      label: 'TORNA AL LOGIN',
      icon: Icons.logout_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      busy: _isLeaving,
      height: kPersonDialogButtonHeight,
      fontSize: kPersonDialogButtonFontSize,
      onPressed: _backToLogin,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: _shown > 0
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
                : const SizedBox.shrink(),
          ),
        ),
        // Stacked, the two take the width of the wider one.
        IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canReport) ...[
                AppGradientButton(
                  label: 'SEGNALA ERRORE',
                  icon: Icons.report_gmailerrorred_rounded,
                  gradient: AppTheme.dangerGradient,
                  accent: AppTheme.trialDanger,
                  height: kPersonDialogButtonHeight,
                  fontSize: kPersonDialogButtonFontSize,
                  onPressed: _report,
                ),
                const SizedBox(height: 14),
              ],
              exit,
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: AppGradientButton(
              label: _isLast ? 'CONCLUDI' : 'AVANTI',
              icon: _isLast
                  ? Icons.done_all_rounded
                  : Icons.chevron_right_rounded,
              busy: _isFinishing,
              disabledReason: _missingCurrentSchoolYear ? _currentYearReason : null,
              height: kPersonDialogButtonHeight,
              fontSize: kPersonDialogButtonFontSize,
              onPressed: _forward,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.fromWidth(widget.width);
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
                size.isCompact ? _compactTopInset : _contentTopInset,
                margin,
                _contentBottomInset,
              ),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: _buildContent(size),
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
        const SizedBox(height: 28),
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
