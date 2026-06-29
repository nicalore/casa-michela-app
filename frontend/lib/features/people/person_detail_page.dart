import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../services/api_service.dart';

import 'models/person_item.dart';
import 'models/membership_item.dart';
import 'person_edit_dialog.dart';
import 'tabs/person_info_tab.dart';
import 'tabs/person_memberships_tab.dart';
import 'tabs/person_schools_tab.dart';
import 'tabs/person_parents_tab.dart';
import 'tabs/person_children_tab.dart';
import 'tabs/person_subjects_tab.dart';

class PersonDetailPage extends StatefulWidget 
{
  final String fiscalCode;

  const PersonDetailPage
  ({
    super.key,
    required this.fiscalCode,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> 
{
  int         _selectedTab = 0;
  bool        _isLoading   = true;
  String?     _errorMessage;
  PersonItem? _person;
  
  late String _currentFiscalCode;
  late String _cacheBustTimestamp;

  @override
  void initState() 
  {
    super.initState();
    _currentFiscalCode  = widget.fiscalCode;
    _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _fetchPersonData();
  }

  Future<void> _fetchPersonData() async 
  {
    setState(() 
    {
      _isLoading    = true;
      _errorMessage = null;
    });

    try 
    {
      final person = await ApiService().getPerson(_currentFiscalCode);
      
      if (mounted) 
      {
        setState(() 
        {
          _person             = person;
          _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
          _isLoading          = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isLoading    = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
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
      final roles     = _person!.roles.map((r) => r.toUpperCase()).toSet();
      final isRevoked = _isRevoked;
      
      if (roles.contains('ASSOCIATO'))
      {
        tabs.add('Iscrizioni');
      }
      
      if (roles.contains('STUDENTE') && !isRevoked)
      {
        tabs.add('Scuola');
      }

      final bool isMinor    = _person!.age != null && _person!.age! < 18;
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

    final List<Widget> views = 
    [
      PersonInfoTab
      (
        person: _person!,
        onEdit: _openEditDialog,
      ),
    ];

    final roles     = _person!.roles.map((r) => r.toUpperCase()).toSet();
    final isRevoked = _isRevoked;
    
    if (roles.contains('ASSOCIATO'))
    {
      views.add(PersonMembershipsTab
      (
        person:   _person!,
        onUpdate: _fetchPersonData,
      ));
    }

    if (roles.contains('STUDENTE') && !isRevoked)
    {
      views.add(PersonSchoolsTab
      (
        person:   _person!,
        onUpdate: _fetchPersonData,
      ));
    }

    final bool isMinor    = _person!.age != null && _person!.age! < 18;
    final bool hasParents = _person!.parents != null && _person!.parents!.isNotEmpty;

    if (isMinor || hasParents)
    {
      views.add(PersonParentsTab
      (
        person:   _person!,
        onUpdate: _fetchPersonData,
      ));
    }

    if (roles.contains('GENITORE'))
    {
      views.add(PersonChildrenTab
      (
        person: _person!,
      ));
    }

    if (roles.contains('DOCENTE') && !isRevoked)
    {
      views.add(PersonSubjectsTab
      (
        person:   _person!,
        onUpdate: _fetchPersonData,
      ));
    }

    return views;
  }

  void _openEditDialog() async 
  {
    if (_person == null) 
    {
      return;
    }

    final String? newFiscalCode = await showGeneralDialog<String>
    (
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'PersonEdit', 
      barrierColor:       Colors.black.withValues(alpha: .5), 
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child:  FadeTransition
          (
            opacity: animation,
            child:   ScaleTransition
            (
              scale: CurvedAnimation
              (
                parent:       animation, 
                curve:        Curves.easeOutBack, 
                reverseCurve: Curves.easeIn
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

  Widget _buildHeaderCard() 
  {
    if (_person == null) 
    {
      return const SizedBox.shrink();
    }

    final String initials = '${_person!.firstName[0]}${_person!.lastName[0]}'.toUpperCase();
    
    final Widget fallbackWidget = Center
    (
      child: Text
      (
        initials,
        style: GoogleFonts.plusJakartaSans
        (
          fontSize:   30,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF64748B),
        ),
      ),
    );

    String? imageUrl = _person!.profileImageUrl?.trim();
    
    if (imageUrl != null && imageUrl.isNotEmpty) 
    {
      if (imageUrl.startsWith('/')) 
      {
        const String backendBaseUrl = 'http://127.0.0.1:8000'; 
        imageUrl                    = '$backendBaseUrl$imageUrl';
      }
      imageUrl = '$imageUrl?v=$_cacheBustTimestamp';
    }

    final bool         hasImage       = imageUrl != null && imageUrl.isNotEmpty;
    final List<String> processedRoles = RoleLabelMapper.processRoles(_person!.roles);

    return Container
    (
      width:   800,
      height:  180,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration
      (
        color:        Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow:    const 
        [
          BoxShadow
          (
            color:      Color(0x0A000000),
            offset:     Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row
      (
        crossAxisAlignment: CrossAxisAlignment.center,
        children: 
        [
          Container
          (
            width:  100,
            height: 100,
            decoration: BoxDecoration
            (
              color:  const Color(0xFFE2E8F0),
              shape:  BoxShape.circle,
              border: Border.all
              (
                color: const Color(0xFF003C82),
                width: 3.0,
              ),
            ),
            child: ClipOval
            (
              child: hasImage
                  ? Image.network
                    (
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) 
                      {
                        return fallbackWidget;
                      },
                    )
                  : fallbackWidget,
            ),
          ),
          const SizedBox(width: 32),
          Expanded
          (
            child: Column
            (
              mainAxisAlignment:  MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                Text
                (
                  '${_person!.firstName} ${_person!.lastName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans
                  (
                    fontSize:   32,
                    fontWeight: FontWeight.w700,
                    color:      const Color(0xFF003C82),
                    height:     1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap
                (
                  spacing:    8,
                  runSpacing: 8,
                  children: processedRoles.map((role) 
                  {
                    return Container
                    (
                      padding: const EdgeInsets.symmetric
                      (
                        horizontal: 14,
                        vertical:   6,
                      ),
                      decoration: BoxDecoration
                      (
                        color:        const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border:       Border.all(color: const Color(0xFFE0E5EC)),
                      ),
                      child: Text
                      (
                        role,
                        style: GoogleFonts.plusJakartaSans
                        (
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color:      const Color(0xFF64748B),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(double viewportWidth)
  {
    if (_isLoading)
    {
      return const Expanded
      (
        child: Center
        (
          child: CircularProgressIndicator
          (
            color: Color(0xFF003C82),
          ),
        ),
      );
    }

    if (_errorMessage != null || _person == null)
    {
      return Expanded
      (
        child: Center
        (
          child: Text
          (
            'Errore nel caricamento: ${_errorMessage ?? "Dati non disponibili"}',
            style: GoogleFonts.plusJakartaSans
            (
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFFC62828),
            ),
          ),
        ),
      );
    }

    return Expanded
    (
      child: Column
      (
        crossAxisAlignment: CrossAxisAlignment.start,
        children: 
        [
          Row
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              Material
              (
                color:        Colors.white,
                borderRadius: BorderRadius.circular(40),
                child: InkWell
                (
                  borderRadius:  BorderRadius.circular(40),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor:  WidgetStateProperty.all
                  (
                    Colors.transparent,
                  ),
                  onTap: () 
                  {
                    context.go('/people');
                  },
                  child: Container
                  (
                    width:  88,
                    height: 54,
                    decoration: const BoxDecoration
                    (
                      color:        Colors.white,
                      borderRadius: BorderRadius.all
                      (
                        Radius.circular(40),
                      ),
                      boxShadow: 
                      [
                        BoxShadow
                        (
                          color:      Color(0x0A000000),
                          offset:     Offset(0, 4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon
                    (
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF003C82),
                      size:  26,
                    ),
                  ),
                ),
              ),
              Expanded
              (
                child: Center
                (
                  child: _buildHeaderCard(),
                ),
              ),
              const SizedBox(width: 88),
            ],
          ),
          const SizedBox(height: 32),
          AppCustomTabBar
          (
            tabs:          _currentTabs,
            selectedIndex: _selectedTab,
            onTabSelected: (index) 
            {
              setState(() 
              {
                _selectedTab = index;
              });
            },
            maxWidth: viewportWidth - 80,
          ),
          const SizedBox(height: 24),
          Expanded
          (
            child: IndexedStack
            (
              index:    _selectedTab,
              children: _currentTabViews,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      body: AppPageContainer
      (
        minWidth:  AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height) 
        {
          final viewportWidth = MediaQuery.of(context).size.width;

          return Container
          (
            width:  width,
            height: height,
            color:  const Color(0xFFF4F7F9),
            child: Stack
            (
              children: 
              [
                Positioned
                (
                  right: -800,
                  top:   -800,
                  child: IgnorePointer
                  (
                    child: Container
                    (
                      width:  1600,
                      height: 1600,
                      decoration: const BoxDecoration
                      (
                        shape:    BoxShape.circle,
                        gradient: RadialGradient
                        (
                          colors: 
                          [
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
                Positioned
                (
                  left:   -800,
                  bottom: -800,
                  child: IgnorePointer
                  (
                    child: Container
                    (
                      width:  1600,
                      height: 1600,
                      decoration: const BoxDecoration
                      (
                        shape:    BoxShape.circle,
                        gradient: RadialGradient
                        (
                          colors: 
                          [
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
                  Positioned.fill
                  (
                    child: IgnorePointer
                    (
                      child: Center
                      (
                        child: Opacity
                        (
                          opacity: 0.04,
                          child: Image.asset
                          (
                            'assets/images/house_watermark.png',
                            width: 800,
                            fit:   BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea
                (
                  child: Padding
                  (
                    padding: const EdgeInsets.symmetric
                    (
                      horizontal: 40,
                      vertical:   24,
                    ),
                    child: Column
                    (
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: 
                      [
                        _buildBodyContent(viewportWidth),
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