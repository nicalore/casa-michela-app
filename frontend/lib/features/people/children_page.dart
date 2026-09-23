import 'package:flutter/material.dart';
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
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../onboarding/onboarding_steps.dart';
import 'edit/person_edit_report_dialog.dart';
import 'models/child_item.dart';
import 'models/person_item.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_personal_stats_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'widgets/person_detail_cards.dart';
import 'widgets/person_detail_widgets.dart';
import 'widgets/profile_avatar.dart';

const String _parentRole = 'PARENT';

const String _module = 'Figli';

const double _cardsWidth = 1200;

// Matches the other sections' action pills.
const double _reportHeight = 50;
const double _reportRadius = 25;
const double _reportFontSize = 14;

// One group per child, each with these sections in this order.
const List<String> _entries = [
  'Informazioni personali',
  'Iscrizioni',
  'Scuola',
  'Altre informazioni',
  'Statistiche personali',
];

const int _infoIndex = 0;
const int _membershipsIndex = 1;
const int _schoolIndex = 2;
const int _otherIndex = 3;

// Payments are not on the page, so not reportable.
List<String> _otherReportableFields(PersonItem child)
{
  final bool isPupil = child.roles.map((role) => role.toUpperCase()).contains('STUDENTE');

  return [
    if (isPupil) 'Certificazioni',
    if (isPupil && !child.isAdult) 'Uscita anticipata',
    if (!child.isAdult) ...['Contatto di emergenza', 'Allergie e farmaci'],
  ];
}

class ParentChildrenPage extends StatefulWidget
{
  const ParentChildrenPage({super.key});

  @override
  State<ParentChildrenPage> createState() => _ParentChildrenPageState();
}

class _ParentChildrenPageState extends State<ParentChildrenPage>
    with SectionVisits, DestinationRefresh
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _failed = false;

  List<PersonItem> _children = [];

  int _selectedSection = 0;

  List<RailGroup> get _sections => [
    for (final child in _children)
      RailGroup(title: child.firstName, entries: _entries),
  ];

  PersonItem get _selectedChild => _children[_selectedSection ~/ _entries.length];

  @override
  void initState()
  {
    super.initState();

    visitedSections.add(_selectedSection);
    _load();
  }

  @override
  void onDestinationShown()
  {
    _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();
      final parent = await _apiService.getPerson(me.taxCode);

      final children = await Future.wait([
        for (final child in parent.children ?? const <ChildItem>[])
          _apiService.getPerson(child.fiscalCode),
      ]);

      children.sort((a, b)
      {
        final int byName = a.firstName.compareTo(b.firstName);

        return byName != 0 ? byName : a.lastName.compareTo(b.lastName);
      });

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _children = children;
        _isLoading = false;
        _failed = false;

        // A child dropped from the register takes their sections with them.
        if (_selectedSection >= children.length * _entries.length)
        {
          _selectedSection = 0;
          visitedSections.add(0);
        }
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento dei figli');

      if (!mounted)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _children.isEmpty;
      });
    }
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
  }

  Widget _buildSection(PersonItem child, int entry)
  {
    final Widget report = Center(child: _buildReportButton(child));

    return switch (entry)
    {
      _infoIndex => _ChildInfoTab(person: child, footer: report),
      _membershipsIndex => PersonMembershipsTab(person: child, footer: report),
      _schoolIndex => PersonSchoolsTab(person: child, footer: report),
      _otherIndex => _ChildOtherInfoTab(person: child, footer: report),
      _ => PersonPersonalStatsTab(person: child, footer: report),
    };
  }

  void _report(PersonItem child)
  {
    showAnagraphicErrorReportDialog(
      context,
      child,
      fields: [
        ...kPersonalReportableFields,
        ...kSchoolReportableFields,
        ..._otherReportableFields(child),
      ],
      eyebrow: 'Dati di ${child.firstName}',
    );
  }

  Widget _buildReportButton(PersonItem child)
  {
    return AppGradientButton(
      label: 'SEGNALA DATO MANCANTE / ERRATO',
      icon: Icons.flag_rounded,
      gradient: AppTheme.dismissGradient,
      accent: AppTheme.trialViolet,
      height: _reportHeight,
      radius: _reportRadius,
      fontSize: _reportFontSize,
      onPressed: () => _report(child),
    );
  }

  // Visited sections stay mounted so each keeps its fetches and filters.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        for (var c = 0; c < _children.length; c++)
          for (var e = 0; e < _entries.length; e++)
            visitedSections.contains(c * _entries.length + e)
                ? _buildSection(_children[c], e)
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

    if (_failed)
    {
      return _buildNotice('Non è stato possibile caricare i dati dei figli.');
    }

    if (_children.isEmpty)
    {
      return _buildNotice('Nessun figlio collegato al tuo profilo.');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (size.hasRail) ...[
          Align(
            alignment: Alignment.topLeft,
            child: PageTransitionItem(
              slot: PageTransitionItem.frame,
              child: AppSectionRail(
                title: _module,
                groups: _sections,
                selectedIndex: _selectedSection,
                onSelected: _selectSection,
              ),
            ),
          ),
          const SizedBox(width: AppSectionRail.gap),
        ],
        Expanded(
          child: size.isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageTransitionItem(
                      slot: PageTransitionItem.frame,
                      child: AppSectionHeading(
                        module: '$_module · ${_selectedChild.firstName}',
                        section: railEntryAt(_sections, _selectedSection),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(child: _buildSectionContent()),
                  ],
                )
              : _buildSectionContent(),
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
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    // Top inset clears the bar overlaid on the content.
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 24,
                    ),
                    child: _buildBody(size),
                  ),
                ),
                // Last in the stack so the bar and its menu stay above the page.
                AppTopBar(
                  currentRoute: '${homeForRole(_parentRole)}/children',
                  sectionTitle: _module,
                  sectionGroups: _sections,
                  selectedSection: _selectedSection,
                  onSectionSelected: _selectSection,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChildInfoTab extends StatelessWidget
{
  final PersonItem person;

  // Rendered under the cards, inside the scroll.
  final Widget footer;

  const _ChildInfoTab({required this.person, required this.footer});

  @override
  Widget build(BuildContext context)
  {
    final Widget face = ProfileAvatar(
      profileImageUrl: person.profileImageUrl,
      firstName: person.firstName,
      lastName: person.lastName,
      canEdit: false,
      onImageUpdated: () {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: pageTransitionBlocks([
              PersonDetailCardPair(
                first: identityCard(person, leading: face),
                second: residenceCard(person),
              ),
              const SizedBox(height: kPersonCardGap),
              PersonDetailCardPair(
                first: birthCard(person),
                second: contactsCard(person),
              ),
              const SizedBox(height: 48),
              footer,
            ]),
          ),
        ),
      ),
    );
  }
}

class _ChildOtherInfoTab extends StatelessWidget
{
  final PersonItem person;

  // Rendered under the cards, inside the scroll.
  final Widget footer;

  const _ChildOtherInfoTab({required this.person, required this.footer});

  @override
  Widget build(BuildContext context)
  {
    final List<PersonDetailCard> cards = [
      ...pupilDetailCards(person),
      if (!person.isAdult) minorSafetyCard(person),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardsWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pageTransitionBlocks([
              if (cards.isEmpty)
                const PersonEmptyState(message: 'Nessuna informazione aggiuntiva.'),
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: kPersonCardGap),
                cards[i],
              ],
              const SizedBox(height: 48),
              footer,
            ]),
          ),
        ),
      ),
    );
  }
}
