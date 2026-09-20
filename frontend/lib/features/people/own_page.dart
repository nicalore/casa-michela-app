import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_segmented_tabs.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../onboarding/onboarding_steps.dart';
import 'edit/person_edit_report_dialog.dart';
import 'models/person_item.dart';
import 'tabs/own_info_tab.dart';
import 'tabs/own_other_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_personal_stats_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'widgets/person_detail_cards.dart';
import 'widgets/person_detail_header.dart';

// Matches the other sections' action pills.
const double _reportHeight = 50;
const double _reportRadius = 25;
const double _reportFontSize = 14;

enum OwnPageSection
{
  info('Informazioni personali'),
  memberships('Iscrizioni'),
  school('Scuola'),
  other('Altre informazioni'),
  stats('Statistiche personali');

  final String label;

  const OwnPageSection(this.label);
}

Set<String> _rolesOf(PersonItem person)
{
  return person.roles.map((role) => role.toUpperCase()).toSet();
}

// Mirrors the admin detail page: no school nor statistics once the membership is revoked.
List<OwnPageSection> ownPageSectionsOf(PersonItem person)
{
  final Set<String> roles = _rolesOf(person);
  final bool standing = !person.isMembershipRevoked;
  final bool isPupil = roles.contains('STUDENTE') && standing;
  final bool isTeacher = roles.contains('DOCENTE') && standing;

  return [
    OwnPageSection.info,
    if (roles.contains('ASSOCIATO')) OwnPageSection.memberships,
    if (isPupil) OwnPageSection.school,
    if (ownOtherCards(person).isNotEmpty) OwnPageSection.other,
    if (isPupil || isTeacher) OwnPageSection.stats,
  ];
}

// Only fields the owner cannot edit themselves (not contacts nor a teacher's studies).
List<String> ownReportableFields(PersonItem person)
{
  final Set<String> roles = _rolesOf(person);
  final List<OwnPageSection> sections = ownPageSectionsOf(person);
  final bool isPupil = roles.contains('STUDENTE');
  final bool isStaff = roles.contains('DOCENTE') || roles.contains('AMMINISTRATORE');
  final bool isMinorPupil = isPupil && !person.isAdult;

  return [
    ...kPersonalReportableFields,
    if (sections.contains(OwnPageSection.memberships)) ...[
      'Iscrizione attuale',
      'Iscrizioni passate',
    ],
    if (sections.contains(OwnPageSection.school)) ...kSchoolReportableFields,
    if (isPupil) 'Certificazioni',
    if (isMinorPupil) ...['Uscita anticipata', 'Contatto di emergenza', 'Allergie e farmaci'],
    if (isStaff && paymentsCard(person) != null) ...[
      'Modalità di pagamento',
      if (isPupil) 'Tariffa',
    ],
    if (roles.contains('AMMINISTRATORE')) 'Ruolo amministratore',
  ];
}

class OwnPage extends StatefulWidget
{
  // Route the back button returns to; the page is opened from anywhere.
  final String? origin;

  const OwnPage({super.key, this.origin});

  @override
  State<OwnPage> createState() => _OwnPageState();
}

class _OwnPageState extends State<OwnPage> with SectionVisits
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _failed = false;

  PersonItem? _person;

  int _selectedSection = 0;

  late String _imageVersion;

  List<OwnPageSection> get _sections
  {
    final PersonItem? person = _person;

    return person == null ? const [OwnPageSection.info] : ownPageSectionsOf(person);
  }

  @override
  void initState()
  {
    super.initState();

    _imageVersion = DateTime.now().millisecondsSinceEpoch.toString();
    visitedSections.add(_selectedSection);
    _load();
  }

  // The bar reads the face off the identity, so a change reloads that too.
  Future<void> _load({bool refreshIdentity = false}) async
  {
    try
    {
      final me = refreshIdentity
          ? await _apiService.me()
          : _apiService.lastKnownIdentity ?? await _apiService.me();
      final person = await _apiService.getPerson(me.taxCode);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _person = person;
        _imageVersion = DateTime.now().millisecondsSinceEpoch.toString();
        _isLoading = false;
        _failed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento della pagina propria');

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _isLoading = false;
        _failed = true;
      });
    }
  }

  // Only in-app paths are accepted; anything else falls back to the home.
  String get _origin
  {
    final String? origin = widget.origin;

    return origin != null && origin.startsWith('/')
        ? origin
        : homeForRole(_apiService.lastKnownIdentity?.activeRole);
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
  }

  void _report(PersonItem person)
  {
    showAnagraphicErrorReportDialog(
      context,
      person,
      fields: ownReportableFields(person),
      eyebrow: 'I tuoi dati',
    );
  }

  Widget _buildReportButton(PersonItem person)
  {
    return AppGradientButton(
      label: 'SEGNALA DATO MANCANTE / ERRATO',
      icon: Icons.flag_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      height: _reportHeight,
      radius: _reportRadius,
      fontSize: _reportFontSize,
      onPressed: () => _report(person),
    );
  }

  Widget _buildSection(PersonItem person, OwnPageSection section)
  {
    final Widget report = _buildReportButton(person);
    final Widget centred = Center(child: report);

    return switch (section)
    {
      OwnPageSection.info => OwnInfoTab(person: person, onUpdate: _load, footer: report),
      OwnPageSection.memberships => PersonMembershipsTab(person: person, footer: centred),
      OwnPageSection.school => PersonSchoolsTab(person: person, footer: centred),
      OwnPageSection.other => OwnOtherInfoTab(person: person, onUpdate: _load, footer: report),
      OwnPageSection.stats => PersonPersonalStatsTab(
          person: person,
          showAppreciation: false,
          footer: centred,
        ),
    };
  }

  // Visited sections stay mounted so each keeps its fetches and filters.
  Widget _buildSectionContent(PersonItem person, List<OwnPageSection> sections)
  {
    return PageSections(
      index: _selectedSection,
      children: [
        for (var i = 0; i < sections.length; i++)
          visitedSections.contains(i)
              ? _buildSection(person, sections[i])
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildNotice(String message)
  {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildBody(AppWindowSize size)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final PersonItem? person = _person;

    if (_failed || person == null)
    {
      return _buildNotice('Non è stato possibile caricare i tuoi dati.');
    }

    final List<OwnPageSection> sections = _sections;
    final List<String> labels = [for (final section in sections) section.label];

    final Widget content = _buildSectionContent(person, sections);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (size.hasRail) ...[
          Align(
            alignment: Alignment.topLeft,
            child: AppSectionRail(
              title: person.firstName,
              groups: [RailGroup(entries: labels)],
              selectedIndex: _selectedSection,
              onSelected: _selectSection,
            ),
          ),
          const SizedBox(width: AppSectionRail.gap),
        ],
        Expanded(
          child: size.hasRail
              ? content
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSegmentedTabs(
                      labels: labels,
                      selectedIndex: _selectedSection,
                      onSelected: _selectSection,
                    ),
                    Expanded(child: content),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.fromWidth(width);
          final double margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PersonDetailHeader(
                          person: _person,
                          imageVersion: _imageVersion,
                          size: size,
                          backTooltip: 'Torna indietro',
                          onBack: () => context.go(_origin),
                          onFaceChanged: () => _load(refreshIdentity: true),
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: _buildBody(size)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
