import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../services/api_service.dart';

import '../auth/models/me_response.dart';
import 'models/person_item.dart';
import 'models/membership_item.dart';
import 'person_edit_dialog.dart';
import 'tabs/person_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'tabs/person_parents_tab.dart';
import 'tabs/person_children_tab.dart';
import 'tabs/person_subjects_tab.dart';

const double _kNavCompactBreakpoint = 700.0;

const double _kHeaderCardCompactBreakpoint = 420.0;

class PersonDetailPage extends StatefulWidget {
  final String fiscalCode;

  const PersonDetailPage({super.key, required this.fiscalCode});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _errorMessage;
  PersonItem? _person;
  MeResponse? _currentUser;

  late String _currentFiscalCode;
  late String _cacheBustTimestamp;

  @override
  void initState() {
    super.initState();
    _currentFiscalCode = widget.fiscalCode;
    _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _fetchPersonData();
    _fetchCurrentUser();
  }

  // Recupera l'account attualmente loggato per confrontare il suo tax_code
  // con il fiscal_code della persona visualizzata (vedi _isOwnProfile).
  // Fallimento silenzioso: se la chiamata fallisce, _currentUser resta null
  // e _isOwnProfile resta false, cioè si torna al comportamento precedente
  // a questa modifica (bottone visibile). Non è un dato la cui assenza deve
  // bloccare il caricamento della pagina.
  Future<void> _fetchCurrentUser() async {
    try {
      final me = await ApiService().me();
      if (mounted) {
        setState(() {
          _currentUser = me;
        });
      }
    } catch (_) {}
  }

  // True se l'account loggato è la persona visualizzata in questa pagina.
  // Usato per nascondere azioni che un account non deve poter compiere su
  // se stesso (es. REVOCA ISCRIZIONE).
  bool get _isOwnProfile {
    if (_currentUser == null || _person == null) {
      return false;
    }
    return _currentUser!.taxCode.toUpperCase() ==
        _person!.fiscalCode.toUpperCase();
  }

  Future<void> _fetchPersonData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final person = await ApiService().getPerson(_currentFiscalCode);

      if (mounted) {
        setState(() {
          _person = person;
          _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch
              .toString();
          _isLoading = false;

          // Guardia generale: se il refresh dei dati fa sparire la tab
          // attualmente selezionata (qualsiasi condizione in _currentTabs
          // non sia più soddisfatta), si torna alla prima tab invece di
          // lasciare l'IndexedStack puntato su un indice non più esistente
          // tra i children visibili.
          if (_selectedTab >= _currentTabs.length) {
            _selectedTab = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // Chiamato da PersonParentsTab subito dopo la rimozione delle
  // responsabilità genitoriali. In quel caso la tab "Genitori" sparisce
  // sempre (persona maggiorenne + zero genitori associati), quindi il
  // redirect alla tab "Informazioni personali" è esplicito e immediato,
  // invece di affidarsi solo alla guardia generica di _fetchPersonData.
  void _onParentalResponsibilityRemoved() {
    setState(() {
      _selectedTab = 0;
    });
    _fetchPersonData();
  }

  bool get _isRevoked {
    if (_person == null ||
        _person!.memberships == null ||
        _person!.memberships!.isEmpty) {
      return false;
    }

    final memberships = _person!.memberships!.toList();
    memberships.sort((a, b) => b.year.compareTo(a.year));

    return memberships.first.revocation != 'NO';
  }

  List<String> get _currentTabs {
    final List<String> tabs = ['Informazioni personali'];

    if (_person != null) {
      final roles = _person!.roles.map((r) => r.toUpperCase()).toSet();
      final isRevoked = _isRevoked;

      if (roles.contains('ASSOCIATO')) {
        tabs.add('Iscrizioni');
      }

      if (roles.contains('STUDENTE') && !isRevoked) {
        tabs.add('Scuola');
      }

      final bool isMinor = _person!.age != null && _person!.age! < 18;
      final bool hasParents =
          _person!.parents != null && _person!.parents!.isNotEmpty;

      if (isMinor || hasParents) {
        tabs.add('Genitori');
      }

      if (roles.contains('GENITORE')) {
        tabs.add('Figli');
      }

      if (roles.contains('DOCENTE') && !isRevoked) {
        tabs.add('Discipline');
      }
    }

    return tabs;
  }

  List<Widget> get _currentTabViews {
    if (_person == null) {
      return [const SizedBox.shrink()];
    }

    final List<Widget> views = [
      PersonInfoTab(person: _person!, onEdit: _openEditDialog),
    ];

    final roles = _person!.roles.map((r) => r.toUpperCase()).toSet();
    final isRevoked = _isRevoked;

    if (roles.contains('ASSOCIATO')) {
      views.add(
        PersonMembershipsTab(
          person: _person!,
          onUpdate: _fetchPersonData,
          isOwnProfile: _isOwnProfile,
        ),
      );
    }

    if (roles.contains('STUDENTE') && !isRevoked) {
      views.add(PersonSchoolsTab(person: _person!, onUpdate: _fetchPersonData));
    }

    final bool isMinor = _person!.age != null && _person!.age! < 18;
    final bool hasParents =
        _person!.parents != null && _person!.parents!.isNotEmpty;

    if (isMinor || hasParents) {
      views.add(
        PersonParentsTab(
          person: _person!,
          onUpdate: _fetchPersonData,
          onResponsibilityRemoved: _onParentalResponsibilityRemoved,
        ),
      );
    }

    if (roles.contains('GENITORE')) {
      views.add(PersonChildrenTab(person: _person!));
    }

    if (roles.contains('DOCENTE') && !isRevoked) {
      views.add(
        PersonSubjectsTab(person: _person!, onUpdate: _fetchPersonData),
      );
    }

    return views;
  }

  void _openEditDialog() async {
    if (_person == null) {
      return;
    }

    final String? newFiscalCode = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'PersonEdit',
      barrierColor: Colors.black.withValues(alpha: .5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (animation, secondaryAnimation, child) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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

    if (newFiscalCode != null && mounted) {
      if (newFiscalCode != _currentFiscalCode) {
        context.go('/people/$newFiscalCode');
      } else {
        _fetchPersonData();
      }
    }
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        onTap: () {
          context.go('/people');
        },
        child: Container(
          width: 88,
          height: 54,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF003C82),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    if (_person == null) {
      return const SizedBox.shrink();
    }

    final String initials = '${_person!.firstName[0]}${_person!.lastName[0]}'
        .toUpperCase();

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = _person!.profileImageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('/')) {
        imageUrl = '${ApiConfig.baseUrl}$imageUrl';
      }
      imageUrl = '$imageUrl?v=$_cacheBustTimestamp';
    }

    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final List<String> processedRoles = RoleLabelMapper.processRoles(
      _person!.roles,
    );

    final Widget avatar = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF003C82), width: 3.0),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < _kHeaderCardCompactBreakpoint;

        final Widget nameAndRoles = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isCompact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              '${_person!.firstName} ${_person!.lastName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: isCompact ? TextAlign.center : TextAlign.start,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF003C82),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            _HeaderRoleChipsRow(
              roles: processedRoles,
              centered: isCompact,
            ),
          ],
        );

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 140),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 32,
            vertical: 24,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 16,
              ),
            ],
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

  Widget _buildBodyContent(double viewportWidth) {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF003C82)),
        ),
      );
    }

    if (_errorMessage != null || _person == null) {
      return Expanded(
        child: Center(
          child: Text(
            'Errore durante il caricamento. Riprova più tardi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color( 0xFF94A3B8),
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
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < _kNavCompactBreakpoint;

              final Widget headerCard = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _buildHeaderCard(),
              );

              if (isCompact) {
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
            onTabSelected: (index) {
              setState(() {
                _selectedTab = index;
              });
            },
            maxWidth: viewportWidth - 80,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: _currentTabViews,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height) {
          //LarghezzaVERADelCanvasFlutter_NonQuellaClampataAlMinimoDaAppPageContainer
          //ServeAdAppCustomTabBarPerSapereQuantoSpazioEDAVVEROVisibile_EQuindiSePaginare
          final double viewportWidth = MediaQuery.of(context).size.width;

          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF4F7F9),
            child: Stack(
              children: [
                Positioned(
                  right: -800,
                  top: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -800,
                  bottom: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewportWidth > 1024)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.04,
                          child: Image.asset(
                            'assets/images/house_watermark.png',
                            width: 800,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
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

class _HeaderRoleChipsRow extends StatelessWidget {
  final List<String> roles;
  final bool centered;

  const _HeaderRoleChipsRow({required this.roles, this.centered = false});

  static const double _chipHorizontalPadding = 28;
  static const double _chipBorderAllowance = 2;
  static const double _chipSpacing = 8;

  double _measureChipWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + _chipHorizontalPadding + _chipBorderAllowance;
  }

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final chipStyle = GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        );
        final extraStyle = GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        );

        int visibleCount = roles.length;
        while (visibleCount > 1) {
          double totalWidth = 0;
          for (int i = 0; i < visibleCount; i++) {
            totalWidth += _measureChipWidth(roles[i], chipStyle);
            if (i > 0) totalWidth += _chipSpacing;
          }

          final int remaining = roles.length - visibleCount;
          if (remaining > 0) {
            totalWidth += _chipSpacing + _measureChipWidth('+$remaining', extraStyle);
          }

          if (totalWidth <= constraints.maxWidth) break;
          visibleCount--;
        }

        final int extraCount = roles.length - visibleCount;
        final List<String> hiddenRoles = roles.sublist(visibleCount);

        final List<Widget> chips = [];
        for (int i = 0; i < visibleCount; i++) {
          if (i > 0) chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_HeaderRoleChip(label: roles[i], style: chipStyle));
        }
        if (extraCount > 0) {
          chips.add(const SizedBox(width: _chipSpacing));
          chips.add(_HeaderRoleChip(
            label: '+$extraCount',
            style: extraStyle,
            hiddenRoles: hiddenRoles,
          ));
        }

        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Align(
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: chips),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRoleChip extends StatelessWidget {
  final String label;
  final TextStyle style;
  final List<String>? hiddenRoles;

  const _HeaderRoleChip({required this.label, required this.style, this.hiddenRoles});

  @override
  Widget build(BuildContext context) {
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Text(label, style: style),
    );

    if (hiddenRoles == null || hiddenRoles!.isEmpty) return chip;

    return Tooltip(
      waitDuration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: .98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: 'Altri ruoli:\n',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          TextSpan(
            text: hiddenRoles!.join('\n'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
      child: chip,
    );
  }
}