import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/overflow_tooltip_text.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/app_segmented_tabs.dart';
import '../auth/models/me_response.dart';
import 'models/person_item.dart';
import 'edit/person_edit_dialog.dart';
import 'tabs/person_children_tab.dart';
import 'tabs/person_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_parents_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'tabs/person_subjects_tab.dart';
import 'widgets/role_chips_row.dart';

// The card of identity over the sections: it is the same person whichever
// section is open, so it stands outside them rather than being repeated in each.
//
// It is deliberately not as wide as the page. What it holds is a picture, a name
// and two or three roles, and stretched over a 1440 window that is a strip of
// white with everything huddled at its left end.
const double _identityWidth = 800;
const double _identityAvatar = 96;
const double _compactIdentityAvatar = 72;
const double _identityRadius = 40;
const double _compactIdentityRadius = 32;

const double _backButtonWidth = 84;
const double _backButtonHeight = 52;

class PersonDetailPage extends StatefulWidget
{
  final String fiscalCode;

  const PersonDetailPage({super.key, required this.fiscalCode});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage>
{
  int _selectedSection = 0;
  bool _isLoading = true;
  String? _errorMessage;
  PersonItem? _person;
  MeResponse? _currentUser;

  late String _currentFiscalCode;
  late String _cacheBustTimestamp;

  @override
  void initState()
  {
    super.initState();
    _currentFiscalCode = widget.fiscalCode;
    _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _fetchPersonData();
    _fetchCurrentUser();
  }

  // Loads the logged-in account to compare its tax code with the displayed
  // person (see _isOwnProfile). Failure is silent: _currentUser stays null and
  // _isOwnProfile stays false, which is not worth blocking the page over.
  Future<void> _fetchCurrentUser() async
  {
    try
    {
      final me = await ApiService().me();

      if (mounted)
      {
        setState(() => _currentUser = me);
      }
    }
    catch (_) {}
  }

  // True when the logged-in account is the person shown here. Used to hide
  // actions an account must not perform on itself (for example REVOCA ISCRIZIONE).
  bool get _isOwnProfile
  {
    if (_currentUser == null || _person == null)
    {
      return false;
    }

    return _currentUser!.taxCode.toUpperCase() == _person!.fiscalCode.toUpperCase();
  }

  Future<void> _fetchPersonData() async
  {
    setState(()
    {
      _isLoading = true;
      _errorMessage = null;
    });

    try
    {
      final person = await ApiService().getPerson(_currentFiscalCode);

      if (mounted)
      {
        setState(()
        {
          _person = person;
          _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
          _isLoading = false;

          // If the refresh drops the currently selected section — a role lost, a
          // parent unlinked — fall back to the first one instead of leaving the
          // IndexedStack pointed at a child that is no longer there.
          if (_selectedSection >= _sections.length)
          {
            _selectedSection = 0;
          }
        });
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _isLoading = false;
          _errorMessage = readableApiError(e);
        });
      }
    }
  }

  // Called by PersonParentsTab right after the parental responsibilities are
  // removed. The "Genitori" section always disappears then (adult with no linked
  // parents), so the redirect to the first section is explicit and immediate
  // rather than relying only on the generic guard in _fetchPersonData.
  void _onParentalResponsibilityRemoved()
  {
    setState(() => _selectedSection = 0);
    _fetchPersonData();
  }

  bool get _isRevoked
  {
    if (_person == null || _person!.memberships == null || _person!.memberships!.isEmpty)
    {
      return false;
    }

    final memberships = _person!.memberships!.toList();
    memberships.sort((a, b) => b.year.compareTo(a.year));

    return memberships.first.revocation != 'NO';
  }

  // The sections of this page, as the rail groups them and as the stack of
  // views under it orders them. The two are built from one description on
  // purpose: they used to be two lists kept in step by hand, and a role that
  // added a section to one and not to the other pointed the page at the wrong
  // content.
  //
  // A person with linked parents or children gets a heading with one entry per
  // name under it, the way the statistics list their roles: the names are
  // sections of this page, and choosing them belongs in the rail rather than in
  // a second row of chips inside the section.
  List<PersonSection> get _sections
  {
    if (_person == null)
    {
      return [
        PersonSection(label: 'Informazioni personali', view: const SizedBox.shrink()),
      ];
    }

    final person = _person!;
    final roles = person.roles.map((role) => role.toUpperCase()).toSet();
    final isRevoked = _isRevoked;

    final sections = <PersonSection>[
      PersonSection(
        label: 'Informazioni personali',
        view: PersonInfoTab(person: person, onEdit: _openEditDialog),
      ),
    ];

    if (roles.contains('ASSOCIATO'))
    {
      sections.add(PersonSection(
        label: 'Iscrizioni',
        view: PersonMembershipsTab(
          person: person,
          onUpdate: _fetchPersonData,
          isOwnProfile: _isOwnProfile,
        ),
      ));
    }

    if (roles.contains('STUDENTE') && !isRevoked)
    {
      sections.add(PersonSection(
        label: 'Scuola',
        view: PersonSchoolsTab(person: person, onUpdate: _fetchPersonData),
      ));
    }

    final bool isMinor = person.age != null && person.age! < 18;
    final parents = person.parents ?? [];

    if (isMinor || parents.isNotEmpty)
    {
      // With none linked yet there is nothing to name, and the one entry leads
      // to the page that offers to add them.
      if (parents.isEmpty)
      {
        sections.add(PersonSection(
          label: 'Genitori',
          view: PersonParentsTab(
            person: person,
            onUpdate: _fetchPersonData,
            onResponsibilityRemoved: _onParentalResponsibilityRemoved,
          ),
        ));
      }
      else
      {
        for (var i = 0; i < parents.length; i++)
        {
          sections.add(PersonSection(
            group: 'Genitori',
            label: '${parents[i].firstName} ${parents[i].lastName}',
            view: PersonParentsTab(
              person: person,
              onUpdate: _fetchPersonData,
              onResponsibilityRemoved: _onParentalResponsibilityRemoved,
              selectedIndex: i,
            ),
          ));
        }
      }
    }

    if (roles.contains('GENITORE'))
    {
      final children = person.children ?? [];

      if (children.isEmpty)
      {
        sections.add(PersonSection(
          label: 'Figli',
          view: PersonChildrenTab(person: person, onUpdate: _fetchPersonData),
        ));
      }
      else
      {
        for (var i = 0; i < children.length; i++)
        {
          sections.add(PersonSection(
            group: 'Figli',
            label: '${children[i].firstName} ${children[i].lastName}',
            view: PersonChildrenTab(
              person: person,
              onUpdate: _fetchPersonData,
              selectedIndex: i,
            ),
          ));
        }
      }
    }

    if (roles.contains('DOCENTE') && !isRevoked)
    {
      sections.add(PersonSection(
        label: 'Discipline',
        view: PersonSubjectsTab(person: person, onUpdate: _fetchPersonData),
      ));
    }

    return sections;
  }

  void _openEditDialog() async
  {
    if (_person == null)
    {
      return;
    }

    final String? newFiscalCode = await showBlurredDialog<String>(
      context: context,
      barrierLabel: 'PersonEdit',
      builder: (context) => PersonEditDialog(person: _person!),
    );

    if (newFiscalCode != null && mounted)
    {
      if (newFiscalCode != _currentFiscalCode)
      {
        context.go('/people/$newFiscalCode');
      }
      else
      {
        _fetchPersonData();
      }
    }
  }

  Widget _buildAvatar(bool compact)
  {
    final double size = compact ? _compactIdentityAvatar : _identityAvatar;

    final String initials =
        '${_person!.firstName[0]}${_person!.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: compact ? 24 : 32,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    String? imageUrl = _person!.profileImageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty)
    {
      if (imageUrl.startsWith('/'))
      {
        imageUrl = ApiConfig.buildUrl(imageUrl);
      }

      imageUrl = '$imageUrl?v=$_cacheBustTimestamp';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // The same barely-there turquoise the person cards on the list stand
        // their initials on.
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  // Who this page is about, over whichever section is open. It wears the chrome
  // of a card without being one: there is no heading and no rule, because the
  // name is the heading.
  Widget _buildIdentityCard(bool compact)
  {
    final List<String> roles = RoleLabelMapper.processRoles(_person!.roles);

    final Widget nameAndRoles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        OverflowTooltipText(
          text: '${_person!.firstName} ${_person!.lastName}',
          maxLines: 1,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialOcean,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        RoleChipsRow(
          roles: roles,
          fontSize: 13,
          horizontalPadding: 11,
          verticalPadding: 5,
          borderRadius: 20,
          spacing: 8,
          scrollable: true,
          centered: compact,
        ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _identityWidth),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? _compactIdentityRadius : _identityRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatar(true),
                  const SizedBox(height: 16),
                  nameAndRoles,
                ],
              )
            : Row(
                children: [
                  _buildAvatar(false),
                  const SizedBox(width: 28),
                  Expanded(child: nameAndRoles),
                ],
              ),
      ),
    );
  }

  // The way out on the left, the person over the middle of the page.
  //
  // The header is laid out on the same grid as the body below it: the button
  // takes the column the rail takes, and the card is centred in what is left —
  // which is the column the cards of a section stand in. Centred on the window
  // instead, it sat a rail's width to the left of everything under it.
  Widget _buildHeader(AppWindowSize size)
  {
    // Nothing to introduce yet: while the person is being fetched the header is
    // the way out and nothing else.
    if (_person == null)
    {
      return Align(alignment: Alignment.centerLeft, child: _buildBackButton());
    }

    if (size.isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          _buildIdentityCard(true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: AppSectionRail.width + AppSectionRail.gap,
          child: Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
        ),
        Expanded(child: Center(child: _buildIdentityCard(false))),
      ],
    );
  }

  // Back to the list of people. This page hangs off that list rather than
  // standing beside it in the app's navigation, which is why it has an arrow of
  // its own instead of the bar every other page carries: from here the only way
  // out is back the way you came in.
  Widget _buildBackButton()
  {
    return _BackButton(onTap: () => context.go('/people'));
  }

  Widget _buildBody(AppWindowSize size, List<PersonSection> sections)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    if (_errorMessage != null || _person == null)
    {
      return Center(
        child: Text(
          'Errore durante il caricamento. Riprova più tardi.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.trialMutedText,
          ),
        ),
      );
    }

    // Nothing wrapped out here: each section times its own cards, one under the
    // next, the way a list page times its own. Wrapped as one element from this
    // side, a section would leave in a single slab — which is what it did, and
    // what it was told not to.
    final Widget content = PageSections(
      index: _selectedSection,
      children: [for (final section in sections) section.view],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Two hundred and forty pixels of a phone cannot go to a column of
        // section names, so below the breakpoint they become a row of segments
        // over the content instead.
        if (size.hasRail) ...[
          Align(
            alignment: Alignment.topLeft,
            child: AppSectionRail(
              title: 'Persone',
              groups: personRailGroups(sections),
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
                      labels: [for (final section in sections) section.label],
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

  void _selectSection(int index)
  {
    setState(() => _selectedSection = index);
  }

  @override
  Widget build(BuildContext context)
  {
    final sections = _sections;

    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final size = AppBreakpoints.fromWidth(width);
          final margin = AppBreakpoints.pageMargin(size);

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
                        _buildHeader(size),
                        const SizedBox(height: 24),
                        Expanded(child: _buildBody(size, sections)),
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

// Consecutive sections carrying the same heading become one group under it, and
// the ones with no heading become one run of entries standing on their own —
// they have to be gathered rather than left one per group, because the rail
// leaves air before every group and a run broken into three would read as three
// unrelated things.
//
// The order is the order of the page's own IndexedStack, which is what the rail
// counts in: entries only, headings taking no number of their own.
List<RailGroup> personRailGroups(List<PersonSection> sections)
{
  final groups = <RailGroup>[];

  for (final section in sections)
  {
    if (groups.isNotEmpty && groups.last.title == section.group)
    {
      groups[groups.length - 1] = RailGroup(
        title: section.group,
        entries: [...groups.last.entries, section.label],
      );

      continue;
    }

    groups.add(RailGroup(title: section.group, entries: [section.label]));
  }

  return groups;
}

// One section of this page: what the rail calls it, the heading it stands under
// where it has one, and what it shows.
class PersonSection
{
  final String label;
  final String? group;
  final Widget view;

  const PersonSection({required this.label, required this.view, this.group});
}

// The way out, in the shape the app gives a control that goes somewhere: white,
// raised, and gold under the pointer.
class _BackButton extends StatefulWidget
{
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Torna alle anagrafiche',
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: _backButtonWidth,
            height: _backButtonHeight,
            decoration: BoxDecoration(
              color: _hover ? AppTheme.trialGoldSurface : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _hover
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.trialOcean,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
