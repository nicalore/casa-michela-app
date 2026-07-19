import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';

import '../models/person_item.dart';
import '../models/people_filter_state.dart';
import '../widgets/person_card.dart';
import '../widgets/people_filter_dialog.dart';

class PeopleSearchTab extends StatefulWidget 
{
  const PeopleSearchTab({super.key});

  static void clearSavedState() 
  {
    _PeopleSearchTabState._savedSearchText  = '';
    _PeopleSearchTabState._savedSortBy      = 'name_asc';
    _PeopleSearchTabState._savedFilterState = const PeopleFilterState();
  }

  @override
  State<PeopleSearchTab> createState() => _PeopleSearchTabState();
}

class _PeopleSearchTabState extends State<PeopleSearchTab> 
{
  static String            _savedSearchText  = '';
  static String            _savedSortBy      = 'name_asc';
  static PeopleFilterState _savedFilterState = const PeopleFilterState();

  final ApiService            _apiService       = ApiService();
  final TextEditingController _searchController = TextEditingController();

  late String            _searchText;
  late String            _sortBy;
  late PeopleFilterState _filterState;

  bool _newHover     = false;
  bool _filtersHover = false;
  bool _isLoading    = true;

  List<PersonItem> _people = [];

  List<String> _availableCities        = [];
  List<String> _availableSchools       = [];
  List<String> _availableStudyPrograms = [];
  List<String> _availableSubjects      = [];

  @override
  void initState() 
  {
    super.initState();
    
    _searchText            = _savedSearchText;
    _sortBy                = _savedSortBy;
    _filterState           = _savedFilterState;
    _searchController.text = _searchText;
    
    _loadData();
  }

  @override
  void dispose() 
  {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async 
  {
    try 
    {
      final data = await _apiService.getPeople();

      if (mounted) 
      {
        setState(() 
        {
          _people = data;
          
          _availableCities        = _people.map((p) => p.city).where((c) => c != null && c.isNotEmpty).cast<String>().toSet().toList();
          _availableSchools       = _people.map((p) => p.schoolName).where((s) => s != null && s.isNotEmpty).cast<String>().toSet().toList();
          _availableStudyPrograms = _people.map((p) => p.studyProgram).where((s) => s != null && s.isNotEmpty).cast<String>().toSet().toList();
          _availableSubjects      = _people.expand((p) => p.taughtSubjects).where((s) => s.isNotEmpty).toSet().toList();
          
          _availableCities.sort();
          _availableSchools.sort();
          _availableStudyPrograms.sort();
          _availableSubjects.sort();

          _isLoading = false;
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
        });
        
        CustomSnackBar.show(context: context, message: 'Impossibile caricare le anagrafiche dal server.', isError: true);
      }
    }
  }

  List<PersonItem> get _filteredPeople 
  {
    var result = _people.where((person) 
    {
      final query         = _searchText.toLowerCase();
      final fullName      = '${person.firstName} ${person.lastName}'.toLowerCase();
      final matchesSearch = fullName.contains(query);
      
      if (!matchesSearch)
      {
        return false;
      }

      final selectedRoles = _filterState.selectedRoles;
      
      if (selectedRoles.isNotEmpty)
      {
        bool matches = false;
        
        final standardSelected = selectedRoles.where((r) => r != 'Associato').toList();
        
        if (standardSelected.isNotEmpty)
        {
          if (person.roles.any((r) => standardSelected.contains(r)))
          {
            matches = true;
          }
        }

        if (!matches && selectedRoles.contains('Associato'))
        {
          final specificRoles = ['Amministratore', 'Docente', 'Psicologo', 'Studente', 'Corsista'];
          
          if (person.roles.contains('Associato') && !person.roles.any((r) => specificRoles.contains(r)))
          {
            matches = true;
          }
        }

        if (!matches)
        {
          return false;
        }
      }

      if (_filterState.city != null && _filterState.city!.isNotEmpty) 
      {
        if (person.city?.toLowerCase() != _filterState.city!.toLowerCase())
        {
          return false;
        }
      }

      if (_filterState.ageRange != null) 
      {
        if (person.age == null)
        {
          return false;
        }
        
        if (person.age! < _filterState.ageRange!.start || person.age! > _filterState.ageRange!.end) 
        {
          if (!(_filterState.ageRange!.end == 99 && person.age! >= 99)) 
          {
            return false;
          }
        }
      }

      if (_filterState.childrenCount != null) 
      {
        if (person.childrenCount == null)
        {
          return false;
        }
        
        if (_filterState.childrenCount == '4+' && person.childrenCount! < 4)
        {
          return false;
        }

        if (_filterState.childrenCount != '4+' && person.childrenCount.toString() != _filterState.childrenCount)
        {
          return false;
        }
      }

      if (_filterState.isActiveCollaborator != null) 
      {
        if (person.isActiveCollaborator != _filterState.isActiveCollaborator)
        {
          return false;
        }
      }

      if (_filterState.enrollmentYear != null) 
      {
        if (person.enrollmentYear != _filterState.enrollmentYear)
        {
          return false;
        }
      }

      if (_filterState.educationLevel != null) 
      {
        if (person.educationLevel != _filterState.educationLevel)
        {
          return false;
        }
      }

      if (_filterState.schoolName != null && _filterState.schoolName!.isNotEmpty) 
      {
        if (person.schoolName?.toLowerCase() != _filterState.schoolName!.toLowerCase())
        {
          return false;
        }
      }

      if (_filterState.schoolClass != null) 
      {
        if (person.schoolClass != _filterState.schoolClass)
        {
          return false;
        }
      }

      if (_filterState.studyProgram != null && _filterState.studyProgram!.isNotEmpty) 
      {
        if (person.studyProgram?.toLowerCase() != _filterState.studyProgram!.toLowerCase())
        {
          return false;
        }
      }

      if (_filterState.earlyExit != null) 
      {
        if (person.earlyExit != _filterState.earlyExit)
        {
          return false;
        }
      }

      if (_filterState.collaborationType != null) 
      {
        if (person.collaborationType != _filterState.collaborationType)
        {
          return false;
        }
      }

      if (_filterState.taughtSubjects.isNotEmpty) 
      {
        bool teachesAll = _filterState.taughtSubjects.every((s) => person.taughtSubjects.contains(s));
        if (!teachesAll)
        {
          return false;
        }
      }

      if (_filterState.taughtSubjectsCount != null) 
      {
        int count = person.taughtSubjects.length;
        
        if (count < _filterState.taughtSubjectsCount!.start || count > _filterState.taughtSubjectsCount!.end) 
        {
          if (!(_filterState.taughtSubjectsCount!.end == 15 && count >= 15)) 
          {
            return false;
          }
        }
      }

      if (_filterState.courseType != null && _filterState.courseType!.isNotEmpty) 
      {
        if (person.courseType?.toLowerCase() != _filterState.courseType!.toLowerCase())
        {
          return false;
        }
      }

      if (_filterState.isMedicalCertificateValid != null) 
      {
        if (person.isMedicalCertificateValid != _filterState.isMedicalCertificateValid)
        {
          return false;
        }
      }

      return true;
    }).toList();

    result.sort((a, b) 
    {
      if (_sortBy == 'name_asc')
      {
        return a.firstName.compareTo(b.firstName);
      }

      if (_sortBy == 'name_desc')
      {
        return b.firstName.compareTo(a.firstName);
      }

      if (_sortBy == 'surname_asc')
      {
        return a.lastName.compareTo(b.lastName);
      }

      if (_sortBy == 'surname_desc')
      {
        return b.lastName.compareTo(a.lastName);
      }

      if (_sortBy == 'date_desc')
      {
        return b.createdAt.compareTo(a.createdAt);
      }

      if (_sortBy == 'date_asc')
      {
        return a.createdAt.compareTo(b.createdAt);
      }
      
      return 0;
    });

    return result;
  }

  void _showFilterDialog() 
  {
    showGeneralDialog(
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'PeopleFilter',
      barrierColor:       Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child) 
      {
        final blurValue = animation.value * 8.0;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent:       animation,
                curve:        Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: PeopleFilterDialog(
                initialState:           _filterState,
                availableCities:        _availableCities,
                availableSchools:       _availableSchools,
                availableStudyPrograms: _availableStudyPrograms,
                availableSubjects:      _availableSubjects,
                onApply:                (newState) 
                {
                  setState(() 
                  {
                    _filterState      = newState;
                    _savedFilterState = newState;
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showWizard() 
  {
    context.go('/people/new');
  }

  @override
  Widget build(BuildContext context) 
  {
    final bool isFilterActive = _filterState.hasActiveFilters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSearchBar(
                controller: _searchController,
                hintText:   'Cerca persona...',
                onChanged:  (value) 
                {
                  setState(() 
                  {
                    _searchText      = value;
                    _savedSearchText = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor:  SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newHover = true),
              onExit:  (_) => setState(() => _newHover = false),
              child: GestureDetector(
                onTap: _showWizard,
                child: AnimatedContainer(
                  duration:   const Duration(milliseconds: 180),
                  curve:      Curves.easeOut,
                  height:     50,
                  padding:    const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border:       Border.all(
                      color: _newHover ? const Color(0xFF003C82) : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:      Color(0x0A000000),
                        offset:     Offset(0, 4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Nuova persona',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   16,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing:            16, 
          runSpacing:         16, 
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CustomFilterMenu<String>(
              hint:          'Ordina per', 
              icon:          Icons.sort_rounded, 
              value:         _sortBy, 
              menuWidth:     200, 
              showClearIcon: false, 
              onChanged:     (val) 
              {
                setState(() 
                {
                  _sortBy      = val;
                  _savedSortBy = val;
                });
              },
              onClear: () {}, 
              options: [
                _FilterOption(value: 'name_asc',     label: 'Nome (A-Z)'), 
                _FilterOption(value: 'name_desc',    label: 'Nome (Z-A)'), 
                _FilterOption(value: 'surname_asc',  label: 'Cognome (A-Z)'), 
                _FilterOption(value: 'surname_desc', label: 'Cognome (Z-A)'), 
                _FilterOption(value: 'date_desc',    label: 'Più recente'), 
                _FilterOption(value: 'date_asc',     label: 'Meno recente'),
              ],
            ),
            
            MouseRegion(
              cursor:  SystemMouseCursors.click,
              onEnter: (_) => setState(() => _filtersHover = true),
              onExit:  (_) => setState(() => _filtersHover = false),
              child: GestureDetector(
                onTap: _showFilterDialog,
                child: AnimatedContainer(
                  duration:   const Duration(milliseconds: 200),
                  height:     42,
                  padding:    EdgeInsets.only(left: 16, right: isFilterActive ? 12 : 16),
                  decoration: BoxDecoration(
                    color:        _filtersHover || isFilterActive ? const Color(0xFFF5F8FC) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                      color: _filtersHover || isFilterActive ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), 
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:      Color(0x05000000), 
                        offset:     Offset(0, 2), 
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xFF003C82), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Filtri',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color:      isFilterActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
                        ),
                      ),
                      if (isFilterActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:        const Color(0xFF003C82).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _filterState.activeFiltersCount.toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize:   12,
                              fontWeight: FontWeight.w800,
                              color:      const Color(0xFF003C82),
                              height:     1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () 
                            {
                              setState(() 
                              {
                                _filterState      = const PeopleFilterState();
                                _savedFilterState = const PeopleFilterState();
                              });
                            },
                            child: Container(
                              padding:    const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _filteredPeople.length == 1 ? '1 persona trovata' : '${_filteredPeople.length} persone trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize:   18,
            fontWeight: FontWeight.w600,
            color:      const Color(0xFF003C82),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF003C82),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Wrap(
                  alignment:  WrapAlignment.center,
                  spacing:    20,
                  runSpacing: 20,
                  children:   _filteredPeople.map((person) 
                  {
                    return PersonCard(
                      person: person,
                      onTap:  () 
                      {
                        context.go('/people/${person.fiscalCode}');
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterOption<T> 
{
  final T      value;
  final String label;

  _FilterOption({
    required this.value, 
    required this.label
  });
}

class _CustomFilterMenu<T> extends StatefulWidget 
{
  final String                 hint;
  final IconData               icon;
  final T?                     value;
  final List<_FilterOption<T>> options;
  final ValueChanged<T>        onChanged;
  final VoidCallback           onClear;
  final double                 menuWidth;
  final bool                   showClearIcon;

  const _CustomFilterMenu({
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
    required this.showClearIcon,
  });

  @override
  State<_CustomFilterMenu<T>> createState() => _CustomFilterMenuState<T>();
}

class _CustomFilterMenuState<T> extends State<_CustomFilterMenu<T>> 
{
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry?   _overlayEntry;
  
  final GlobalKey<_FilterOverlayContentState> _menuKey = GlobalKey();
  
  bool _isHovered = false;

  void _toggleMenu() 
  {
    if (_overlayEntry != null) 
    {
      _closeMenu();
      return;
    }
    
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size      = renderBox.size;
    final offset    = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap:    _closeMenu,
              child:    Container(),
            ),
          ),
          Positioned(
            top:  offset.dy + size.height + 8,
            left: offset.dx,
            child: _FilterOverlayContent<T>(
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              menuWidth:    widget.menuWidth,
              onSelected:   (val) 
              {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          )
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() async 
  {
    if (_overlayEntry != null) 
    {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final bool isActive = widget.value != null;
    String displayText  = widget.hint;

    if (isActive) 
    {
      final selectedOption = widget.options.firstWhere(
        (o) => o.value == widget.value,
        orElse: () => _FilterOption(value: widget.value!, label: ''),
      );
      displayText = selectedOption.label;
    }

    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key:        _buttonKey,
          duration:   const Duration(milliseconds: 200),
          height:     42,
          padding:    EdgeInsets.only(left: 16, right: (isActive && widget.showClearIcon) ? 12 : 16),
          decoration: BoxDecoration(
            color:        _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(
              color: _isHovered || isActive ? const Color(0xFF003C82) : const Color(0xFFE0E5EC),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x05000000),
                offset:     Offset(0, 2),
                blurRadius: 8,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: const Color(0xFF003C82), size: 18),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  style:    GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color:      isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A),
                  ),
                ),
              ),
              if (isActive && widget.showClearIcon) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () 
                  {
                    widget.onClear();
                    
                    if (_overlayEntry != null)
                    {
                      _closeMenu();
                    }
                  },
                  child: Container(
                    padding:    const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOverlayContent<T> extends StatefulWidget 
{
  final T?                     currentValue;
  final List<_FilterOption<T>> options;
  final ValueChanged<T>        onSelected;
  final double                 menuWidth;

  const _FilterOverlayContent({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.menuWidth,
  });

  @override
  State<_FilterOverlayContent<T>> createState() => _FilterOverlayContentState<T>();
}

class _FilterOverlayContentState<T> extends State<_FilterOverlayContent<T>> 
{
  bool _expanded = false;

  @override
  void initState() 
  {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) 
    {
      if (mounted)
      {
        setState(() 
        {
          _expanded = true;
        });
      }
    });
  }

  Future<void> hide() async 
  {
    if (mounted)
    {
      setState(() 
      {
        _expanded = false;
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) 
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width:       widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350),
        decoration:  BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    const [
            BoxShadow(
              color:        Color(0x14000000),
              blurRadius:   20,
              spreadRadius: 2,
            )
          ],
        ),
        child: AnimatedSize(
          duration:  const Duration(milliseconds: 180),
          curve:     Curves.easeOut,
          alignment: Alignment.topCenter,
          child:     _expanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:       MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:           widget.options.map((option) 
                      {
                        return _FilterMenuItem(
                          text:       option.label,
                          isSelected: widget.currentValue == option.value,
                          onTap:      () => widget.onSelected(option.value),
                        );
                      }).toList(),
                    ),
                  ),
                )
              : SizedBox(width: widget.menuWidth, height: 0),
        ),
      ),
    );
  }
}

class _FilterMenuItem extends StatefulWidget 
{
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const _FilterMenuItem({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterMenuItem> createState() => _FilterMenuItemState();
}

class _FilterMenuItemState extends State<_FilterMenuItem> 
{
  bool _hover = false;

  @override
  Widget build(BuildContext context) 
  {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color:   Colors.transparent,
          child: Row(
            children: [
              AnimatedContainer(
                duration:   const Duration(milliseconds: 150),
                width:      2,
                height:     (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(
                  color:        const Color(0xFF003C82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style:    GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color:      const Color(0xFF003C82),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}