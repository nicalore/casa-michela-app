import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import '../auth/models/me_response.dart';
import 'models/person_item.dart';
import 'person_edit_dialog.dart';
import 'tabs/person_children_tab.dart';
import 'tabs/person_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_parents_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'tabs/person_subjects_tab.dart';
import 'widgets/role_chips_row.dart';

const double _kNavCompactBreakpoint = 700.0;
const double _kHeaderCardCompactBreakpoint = 420.0;

class PersonDetailPage extends StatefulWidget
{
  final String fiscalCode;

  const PersonDetailPage({super.key, required this.fiscalCode});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage>
{
  int _selectedTab = 0;
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

          // If the refresh drops the currently selected tab (its condition in
          // _currentTabs is no longer met), fall back to the first tab instead
          // of leaving the IndexedStack pointed at a missing child.
          if (_selectedTab >= _currentTabs.length)
          {
            _selectedTab = 0;
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
  // removed. The "Genitori" tab always disappears then (adult with no linked
  // parents), so the redirect to the first tab is explicit and immediate rather
  // than relying only on the generic guard in _fetchPersonData.
  void _onParentalResponsibilityRemoved()
  {
    setState(() => _selectedTab = 0);
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

  List<String> get _currentTabs
  {
    final List<String> tabs = ['Informazioni personali'];

    if (_person != null)
    {
      final roles = _person!.roles.map((r) => r.toUpperCase()).toSet();
      final isRevoked = _isRevoked;

      if (roles.contains('ASSOCIATO'))
      {
        tabs.add('Iscrizioni');
      }

      if (roles.contains('STUDENTE') && !isRevoked)
      {
        tabs.add('Scuola');
      }

      final bool isMinor = _person!.age != null && _person!.age! < 18;
      final bool hasParents = _person!.parents != null && _person!.parents!.isNotEmpty;

      if (isMinor || hasParents)
      {
        tabs.add('Genitori');
      }

      if (roles.contains('GENITORE'))
      {
        tabs.add('Figli');
      }

      if (roles.contains('DOCENTE') && !isRevoked)
      {
        tabs.add('Discipline');
      }
    }

    return tabs;
  }

  List<Widget> get _currentTabViews
  {
    if (_person == null)
    {
      return [const SizedBox.shrink()];
    }

    final List<Widget> views = [
      PersonInfoTab(person: _person!, onEdit: _openEditDialog),
    ];

    final roles = _person!.roles.map((r) => r.toUpperCase()).toSet();
    final isRevoked = _isRevoked;

    if (roles.contains('ASSOCIATO'))
    {
      views.add(
        PersonMembershipsTab(
          person: _person!,
          onUpdate: _fetchPersonData,
          isOwnProfile: _isOwnProfile,
        ),
      );
    }

    if (roles.contains('STUDENTE') && !isRevoked)
    {
      views.add(PersonSchoolsTab(person: _person!, onUpdate: _fetchPersonData));
    }

    final bool isMinor = _person!.age != null && _person!.age! < 18;
    final bool hasParents = _person!.parents != null && _person!.parents!.isNotEmpty;

    if (isMinor || hasParents)
    {
      views.add(
        PersonParentsTab(
          person: _person!,
          onUpdate: _fetchPersonData,
          onResponsibilityRemoved: _onParentalResponsibilityRemoved,
        ),
      );
    }

    if (roles.contains('GENITORE'))
    {
      views.add(PersonChildrenTab(person: _person!));
    }

    if (roles.contains('DOCENTE') && !isRevoked)
    {
      views.add(PersonSubjectsTab(person: _person!, onUpdate: _fetchPersonData));
    }

    return views;
  }

  void _openEditDialog() async
  {
    if (_person == null)
    {
      return;
    }

    final String? newFiscalCode = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PersonEdit',
      barrierColor: Colors.black.withValues(alpha: .5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: PersonEditDialog(person: _person!),
            ),
          ),
        );
      },
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

  Widget _buildBackButton()
  {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: () => context.go('/people'),
        child: Container(
          width: 88,
          height: 54,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(40)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.primary,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard()
  {
    if (_person == null)
    {
      return const SizedBox.shrink();
    }

    final String initials =
        '${_person!.firstName[0]}${_person!.lastName[0]}'.toUpperCase();

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
        ),
      ),
    );

    String? imageUrl = _person!.profileImageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty)
    {
      if (imageUrl.startsWith('/'))
      {
        imageUrl = '${ApiConfig.baseUrl}$imageUrl';
      }
      imageUrl = '$imageUrl?v=$_cacheBustTimestamp';
    }

    final List<String> processedRoles = RoleLabelMapper.processRoles(_person!.roles);

    final Widget avatar = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.slate200,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 3.0),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackWidget,
              )
            : fallbackWidget,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < _kHeaderCardCompactBreakpoint;

        final Widget nameAndRoles = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              '${_person!.firstName} ${_person!.lastName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isCompact ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            RoleChipsRow(
              roles: processedRoles,
              fontSize: 14,
              horizontalPadding: 14,
              verticalPadding: 6,
              borderRadius: 16,
              spacing: 8,
              scrollable: true,
              centered: isCompact,
            ),
          ],
        );

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 140),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: AppTheme.cardShadow,
          ),
          child: isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    avatar,
                    const SizedBox(height: 16),
                    nameAndRoles,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatar,
                    const SizedBox(width: 32),
                    Expanded(child: nameAndRoles),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildBodyContent(double viewportWidth)
  {
    if (_isLoading)
    {
      return const Expanded(
        child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_errorMessage != null || _person == null)
    {
      return Expanded(
        child: Center(
          child: Text(
            'Errore durante il caricamento. Riprova più tardi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate400,
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints)
            {
              final bool isCompact = constraints.maxWidth < _kNavCompactBreakpoint;

              final Widget headerCard = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildHeaderCard(),
              );

              if (isCompact)
              {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackButton(),
                    const SizedBox(height: 16),
                    headerCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  Expanded(child: Center(child: headerCard)),
                  const SizedBox(width: 88),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          AppCustomTabBar(
            tabs: _currentTabs,
            selectedIndex: _selectedTab,
            onTabSelected: (index)
            {
              setState(() => _selectedTab = index);
            },
            maxWidth: viewportWidth - 80,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IndexedStack(index: _selectedTab, children: _currentTabViews),
          ),
        ],
      ),
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
          // Real Flutter canvas width, not the value clamped to the minimum by
          // AppPageContainer. AppCustomTabBar needs it to know the truly visible
          // space and decide whether to paginate.
          final double viewportWidth = MediaQuery.of(context).size.width;

          return Container(
            width: width,
            height: height,
            color: AppTheme.pageBackground,
            child: Stack(
              children: [
                const CornerGlow(corner: GlowCorner.topRight),
                const CornerGlow(corner: GlowCorner.bottomLeft),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_buildBodyContent(viewportWidth)],
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
