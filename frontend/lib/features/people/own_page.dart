import 'dart:async';

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
import '../../shared/widgets/app_section_tabs.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/page_density.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../notifications/administrator_notes_seen.dart';
import '../onboarding/onboarding_steps.dart';
import 'edit/person_edit_report_dialog.dart';
import 'models/person_item.dart';
import 'own_tour.dart';
import 'person_jump.dart';
import 'tabs/own_info_tab.dart';
import 'tabs/own_observations_tab.dart';
import 'tabs/own_other_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_personal_stats_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'widgets/person_detail_cards.dart';
import 'widgets/person_detail_header.dart';

enum OwnPageSection
{
  info('Informazioni personali'),
  memberships('Iscrizioni'),
  school('Scuola'),
  other('Altre informazioni'),
  stats('Statistiche personali'),
  observations('Osservazioni');

  final String label;

  const OwnPageSection(this.label);
}

Set<String> _rolesOf(PersonItem person)
{
  return person.roles.map((role) => role.toUpperCase()).toSet();
}

// The account's live role, not the record's: a lapsed membership keeps the profile only.
bool _holdsNow(PersonItem person, String profile, String role)
{
  return _rolesOf(person).contains(profile) &&
      !person.isMembershipRevoked &&
      (ApiService().lastKnownIdentity?.availableRoles.contains(role) ?? false);
}

bool _isOwnPupil(PersonItem person) => _holdsNow(person, 'STUDENTE', 'STUDENT');

bool _isOwnTeacher(PersonItem person) => _holdsNow(person, 'DOCENTE', 'TEACHER');

// Pupil and teacher sections only while the role is held: the server refuses their figures after.
List<OwnPageSection> ownPageSectionsOf(PersonItem person)
{
  final Set<String> roles = _rolesOf(person);
  final bool isPupil = _isOwnPupil(person);
  final bool isTeacher = _isOwnTeacher(person);

  return [
    OwnPageSection.info,
    if (roles.contains('ASSOCIATO')) OwnPageSection.memberships,
    if (isPupil) OwnPageSection.school,
    if (ownOtherCards(person).isNotEmpty) OwnPageSection.other,
    if (isPupil || isTeacher) OwnPageSection.stats,
    if (isTeacher) OwnPageSection.observations,
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

  // Asked by a notification: the Osservazioni, once the record is read.
  bool _observationsAsked = false;

  List<OwnPageSection> get _sections
  {
    final PersonItem? person = _person;

    return person == null ? const [OwnPageSection.info] : ownPageSectionsOf(person);
  }

  @override
  void initState()
  {
    super.initState();

    visitedSections.add(_selectedSection);
    ownPageSection.value = null;
    _observationsAsked = OwnPageJumps.takeObservations();
    OwnPageJumps.asked.addListener(_onObservationsAsked);
    _load();
  }

  @override
  void dispose()
  {
    OwnPageJumps.asked.removeListener(_onObservationsAsked);
    super.dispose();
  }

  // Read again first: the note announced may be newer than the record shown.
  void _onObservationsAsked()
  {
    if (!mounted || !OwnPageJumps.takeObservations())
    {
      return;
    }

    _observationsAsked = true;
    _load();
  }

  // Straight on it when the record first shows; a record already shown turns to it.
  void _showObservations()
  {
    final int index = _sections.indexOf(OwnPageSection.observations);

    if (index < 0)
    {
      return;
    }

    if (index != _selectedSection)
    {
      _selectSection(index);
    }
    else
    {
      unawaited(markAdministratorNotesSeen());
    }
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
        _isLoading = false;
        _failed = false;
      });

      _tellSection();

      // A tour would take the page back to its start: it waits for the next visit.
      if (_observationsAsked)
      {
        _observationsAsked = false;
        _showObservations();
      }
      else
      {
        _startTour();
      }
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
    _tellSection();

    // The administrators' notes on screen: the news of new ones goes.
    if (_sections[index] == OwnPageSection.observations)
    {
      unawaited(markAdministratorNotesSeen());
    }
  }

  // Told after the frame: a tour waiting for it redraws itself, which a build in progress forbids.
  void _tellSection()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      final List<OwnPageSection> sections = _sections;

      if (mounted && _selectedSection < sections.length)
      {
        ownPageSection.value = sections[_selectedSection].name;
      }
    });
  }

  void _show(String name)
  {
    final int index = _sections.indexWhere((section) => section.name == name);

    if (index >= 0)
    {
      _selectSection(index);
    }
  }

  DesktopTour? _tourOf(PersonItem person)
  {
    final Set<String> roles = _rolesOf(person);

    if (_isOwnTeacher(person))
    {
      return teacherOwnTour(
        title: person.firstName,
        show: _show,
        noted: person.administratorNotes?.isNotEmpty ?? false,
      );
    }

    if (_isOwnPupil(person))
    {
      return studentOwnTour(title: person.firstName, show: _show);
    }

    if (roles.contains('GENITORE'))
    {
      return parentOwnTour(title: person.firstName);
    }

    return roles.contains('PSICOLOGO') ? psychologistOwnTour(title: person.firstName) : null;
  }

  Future<void> _startTour() async
  {
    final PersonItem? person = _person;
    final DesktopTour? tour = person == null ? null : _tourOf(person);

    if (tour == null || isDesktopTourShown)
    {
      return;
    }

    if (!await ownTourSeen(tour) && mounted)
    {
      if (_selectedSection != 0)
      {
        _selectSection(0);
      }

      startOwnTour(context, tour);
    }
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

  // [tour]: the one a tour lights, under the personal information.
  Widget _buildReportButton(PersonItem person, {bool tour = false})
  {
    return DesktopTourTarget(
      id: tour ? kTourOwnReport : null,
      child: AppGradientButton(
        label: 'SEGNALA DATO MANCANTE / ERRATO',
        icon: Icons.flag_rounded,
        gradient: AppTheme.dismissGradient,
        accent: AppTheme.trialViolet,
        onPressed: () => _report(person),
      ),
    );
  }

  Widget _buildSection(PersonItem person, OwnPageSection section)
  {
    final Widget report = _buildReportButton(person, tour: section == OwnPageSection.info);
    final Widget centred = Center(child: report);

    return switch (section)
    {
      OwnPageSection.info => OwnInfoTab(person: person, onUpdate: _load, footer: report),
      OwnPageSection.memberships => PersonMembershipsTab(person: person, footer: centred),
      OwnPageSection.school => PersonSchoolsTab(person: person, footer: centred),
      OwnPageSection.other => OwnOtherInfoTab(person: person, onUpdate: _load, footer: report),
      OwnPageSection.stats => PersonPersonalStatsTab(
          person: person,
          forOwner: true,
          footer: centred,
        ),
      OwnPageSection.observations => OwnObservationsTab(person: person),
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

    final PersonHeading heading = PersonHeading(
      person: person,
      imageVersion: '${_apiService.profileImageVersion}',
      backTooltip: 'Torna indietro',
      onBack: () => context.go(_origin),
      onFaceChanged: () => _load(refreshIdentity: true),
    );

    final Map<int, String> tours = {
      for (final (int index, OwnPageSection section) in sections.indexed)
        if (section == OwnPageSection.other)
          index: kTourOwnToOther
        else if (section == OwnPageSection.stats)
          index: kTourOwnToStats
        else if (section == OwnPageSection.observations)
          index: kTourOwnToObservations,
    };

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
              tours: tours,
            ),
          ),
          const SizedBox(width: AppSectionRail.gap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!size.hasRail) ...[
                AppSectionTabs(
                  title: heading.name,
                  titleSize: kPersonHeadingNameSize,
                  leading: heading.leading(context),
                  leadingWidth: heading.leadingWidth,
                  titleTrailing: heading.roles(),
                  titleTrailingWidthOf: heading.rolesWidth,
                  groups: [RailGroup(entries: labels)],
                  selectedIndex: _selectedSection,
                  onSelected: _selectSection,
                  tours: tours,
                ),
                const SizedBox(height: kSectionTabsGap),
              ],
              Expanded(key: const ValueKey('own-sections'), child: content),
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
        // Below the wide window the page is the window: its sections scroll, not the page.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
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
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: size.isDense ? 16 : 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Below the wide window back, face and name share the line of the tabs.
                        if (!size.isDense || _person == null) ...[
                          PersonDetailHeader(
                            person: size.isDense ? null : _person,
                            imageVersion: '${_apiService.profileImageVersion}',
                            backTooltip: 'Torna indietro',
                            onBack: () => context.go(_origin),
                            onFaceChanged: () => _load(refreshIdentity: true),
                          ),
                          SizedBox(height: size.isDense ? 16 : 24),
                        ],
                        Expanded(
                          child: AppPageDensity(dense: size.isDense, child: _buildBody(size)),
                        ),
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
