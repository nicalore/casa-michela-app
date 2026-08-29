import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import '../../shared/export/pdf_tab.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/dialog_components.dart';
import '../../shared/widgets/overflow_tooltip_text.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../../shared/widgets/app_segmented_tabs.dart';
import '../auth/models/me_response.dart';
import 'models/person_item.dart';
import 'edit/person_edit_dialog.dart';
import 'tabs/person_children_tab.dart';
import 'tabs/person_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_parents_tab.dart';
import 'tabs/person_personal_stats_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'tabs/person_subjects_tab.dart';
import 'widgets/role_chips_row.dart';

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

  // Route the back button returns to; a record can be opened from several pages.
  final String? origin;

  const PersonDetailPage({super.key, required this.fiscalCode, this.origin});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage>
{
  int _selectedSection = 0;
  bool _isLoading = true;
  bool _isGeneratingForm = false;
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

  // Failure is silent: _isOwnProfile just stays false.
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

  // Hides actions an account must not perform on itself (e.g. revocation).
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

          // A refresh can drop the selected section; fall back to the first.
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

  // The "Genitori" section disappears after removal, so jump back to the first one.
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
        view: PersonInfoTab(
          person: person,
          onEdit: _openEditDialog,
          onGenerateForm: roles.contains('ASSOCIATO') ? _generateEnrollmentForm : null,
          isGeneratingForm: _isGeneratingForm,
        ),
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

    if ((roles.contains('DOCENTE') || roles.contains('STUDENTE')) && !isRevoked)
    {
      sections.add(PersonSection(
        label: 'Statistiche personali',
        view: PersonPersonalStatsTab(person: person),
      ));
    }

    return sections;
  }

  Future<void> _generateEnrollmentForm() async
  {
    final PersonItem? person = _person;

    if (_isGeneratingForm || person == null)
    {
      return;
    }

    final String name = '${person.firstName} ${person.lastName}';

    // The tab must open before the first await, or the browser blocks it as a popup.
    final PdfTab? tab = openPdfTab(title: 'Modulo di iscrizione · $name');
    final String day = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final String fileName = 'Modulo di iscrizione $name $day.pdf';

    setState(() => _isGeneratingForm = true);

    try
    {
      final Uint8List bytes = await ApiService().fetchEnrollmentForm(person.fiscalCode);

      if (tab != null)
      {
        tab.present(bytes, fileName: fileName);
      }
      else if (downloadPdf(bytes, fileName: fileName) && mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Il browser ha bloccato la scheda: il modulo è stato scaricato.',
          isError: false,
        );
      }
    }
    catch (e)
    {
      tab?.fail('Non è stato possibile generare il modulo.');

      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _isGeneratingForm = false);
      }
    }
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
        context.go('/people/$newFiscalCode?from=$_origin');
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

  Widget _buildHeader(AppWindowSize size)
  {
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

  // Only in-app paths are accepted; anything else falls back to /people.
  String get _origin
  {
    final String? origin = widget.origin;

    return origin != null && origin.startsWith('/') ? origin : '/people';
  }

  Widget _buildBackButton()
  {
    return _BackButton(onTap: () => context.go(_origin));
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

    // Sections animate their own transitions; wrapping here would animate them as one block.
    final Widget content = PageSections(
      index: _selectedSection,
      children: [for (final section in sections) section.view],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

// Consecutive sections sharing a heading merge; entry order must match the IndexedStack.
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

class PersonSection
{
  final String label;
  final String? group;
  final Widget view;

  const PersonSection({required this.label, required this.view, this.group});
}

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
