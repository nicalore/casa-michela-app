import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/teaching_offering_item.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';

class TeachingOfferingsTab extends StatefulWidget {
  const TeachingOfferingsTab({super.key});

  @override
  State<TeachingOfferingsTab> createState() => _TeachingOfferingsTabState();
}

class _TeachingOfferingsTabState extends State<TeachingOfferingsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _ascending = true;
  
  String? _filterSchoolCode;
  int? _filterProgramId;
  String? _filterLevel;

  bool _newOfferingHover = false;
  bool _isLoading = true;

  List<TeachingOfferingItem> _offerings = [];
  OfferingOptions? _options;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final offerings = await _apiService.getTeachingOfferings();
      final options = await _apiService.getOfferingOptions();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _options = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Errore caricamento dati.', isError: true);
      }
    }
  }

  List<TeachingOfferingItem> get _filteredOfferings {
    var result = _offerings.where((o) {
      final query = _searchText.toLowerCase();
      final matchesSearch = o.schoolName.toLowerCase().contains(query) || 
                            o.studyProgramName.toLowerCase().contains(query);
      
      final matchesSchool = _filterSchoolCode == null || o.schoolCode == _filterSchoolCode;
      final matchesProgram = _filterProgramId == null || o.studyProgramId == _filterProgramId;
      final matchesLevel = _filterLevel == null || o.level == _filterLevel;

      return matchesSearch && matchesSchool && matchesProgram && matchesLevel;
    }).toList();

    result.sort((a, b) {
      return _ascending 
          ? a.schoolName.compareTo(b.schoolName) 
          : b.schoolName.compareTo(a.schoolName);
    });

    return result;
  }

  String _getItalianLevel(String level) {
    switch (level) {
      case 'PRIMARY_SCHOOL': return 'Primaria';
      case 'MIDDLE_SCHOOL': return 'Secondaria I Grado';
      case 'HIGH_SCHOOL': return 'Secondaria II Grado';
      default: return level;
    }
  }

  void _showWizard({TeachingOfferingItem? offering}) {
    if (_options == null) return;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'OfferingWizard',
      barrierColor: Colors.black.withOpacity(0.15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: animation.value * 8.0, sigmaY: animation.value * 8.0),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _OfferingWizardDialog(
                options: _options!,
                existingOffering: offering,
                onSave: (schoolCode, programId, level, years, subjectIds, onError) async {
                  try {
                    if (offering == null) {
                      final created = await _apiService.createTeachingOffering(
                        schoolCode: schoolCode, studyProgramId: programId, level: level, years: years, subjectIds: subjectIds
                      );
                      setState(() => _offerings.add(created));
                    } else {
                      final updated = await _apiService.updateTeachingOffering(
                        id: offering.id, schoolCode: schoolCode, studyProgramId: programId, level: level, years: years, subjectIds: subjectIds
                      );
                      setState(() {
                        final index = _offerings.indexWhere((o) => o.id == offering.id);
                        if (index != -1) _offerings[index] = updated;
                      });
                    }
                    Navigator.of(context).pop();
                  } catch (e) {
                    onError(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDetailsDialog(TeachingOfferingItem offering) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'OfferingDetails',
      barrierColor: Colors.black.withOpacity(0.15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: animation.value * 8.0, sigmaY: animation.value * 8.0),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _OfferingDetailsDialogContent(
                offering: offering,
                levelItalian: _getItalianLevel(offering.level),
                onEditRequested: () {
                  Navigator.of(context).pop();
                  _showWizard(offering: offering);
                },
                onDelete: () async {
                  try {
                    await _apiService.deleteTeachingOffering(offering.id);
                    setState(() => _offerings.removeWhere((o) => o.id == offering.id));
                  } catch (e) {
                    if (mounted) CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Liste per i filtri custom
    final schoolItems = _options?.schools.map((s) => _FilterOption(value: s.mechanographicCode, label: s.name)).toList() ?? [];
    final programItems = _options?.studyPrograms.map((p) => _FilterOption(value: p.id, label: p.name)).toList() ?? [];
    final levelItems = [
      _FilterOption(value: 'PRIMARY_SCHOOL', label: 'Primaria'),
      _FilterOption(value: 'MIDDLE_SCHOOL', label: 'Secondaria I Grado'),
      _FilterOption(value: 'HIGH_SCHOOL', label: 'Secondaria II Grado'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca per scuola o indirizzo...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newOfferingHover = true),
              onExit: (_) => setState(() => _newOfferingHover = false),
              child: GestureDetector(
                onTap: () => _showWizard(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _newOfferingHover ? const Color(0xFF003C82) : Colors.transparent, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
                  ),
                  child: Center(
                    child: Text('Nuova Offerta', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // --- BARRA ORDINAMENTO E FILTRI CUSTOM ---
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SortDropdownMenu(
              isAscending: _ascending,
              onChanged: (value) => setState(() => _ascending = value),
            ),
            _CustomFilterMenu<String>(
              hint: 'Tutte le scuole',
              icon: Icons.account_balance_outlined,
              value: _filterSchoolCode,
              options: schoolItems,
              menuWidth: 320, // Più largo per leggere i nomi
              onChanged: (val) => setState(() => _filterSchoolCode = val),
              onClear: () => setState(() => _filterSchoolCode = null),
            ),
            _CustomFilterMenu<int>(
              hint: 'Tutti gli indirizzi',
              icon: Icons.menu_book_rounded,
              value: _filterProgramId,
              options: programItems,
              menuWidth: 280, // Più largo per leggere i nomi
              onChanged: (val) => setState(() => _filterProgramId = val),
              onClear: () => setState(() => _filterProgramId = null),
            ),
            _CustomFilterMenu<String>(
              hint: 'Tutti i livelli',
              icon: Icons.layers_outlined,
              value: _filterLevel,
              options: levelItems,
              menuWidth: 220,
              onChanged: (val) => setState(() => _filterLevel = val),
              onClear: () => setState(() => _filterLevel = null),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Text(
          _filteredOfferings.length == 1 ? '1 offerta trovata' : '${_filteredOfferings.length} offerte trovate',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82)),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
        else
          Center(
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _filteredOfferings.map((o) {
                return _OfferingCard(
                  offering: o,
                  onTap: () => _showDetailsDialog(o),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// COMPONENTI DEL FILTRO CUSTOM (STILE IDENTICO AL SORT MENU)
// ============================================================================

class _FilterOption<T> {
  final T value;
  final String label;
  _FilterOption({required this.value, required this.label});
}

class _CustomFilterMenu<T> extends StatefulWidget {
  final String hint;
  final IconData icon;
  final T? value;
  final List<_FilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback onClear;
  final double menuWidth;

  const _CustomFilterMenu({
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
  });

  @override
  State<_CustomFilterMenu<T>> createState() => _CustomFilterMenuState<T>();
}

class _CustomFilterMenuState<T> extends State<_CustomFilterMenu<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  final GlobalKey<_FilterOverlayContentState> _menuKey = GlobalKey();
  bool _isHovered = false;

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }
    
    final renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
              child: Container(),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 8,
            left: offset.dx,
            child: _FilterOverlayContent<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              menuWidth: widget.menuWidth,
              onSelected: (val) {
                widget.onChanged(val);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeMenu() async {
    if (_overlayEntry != null) {
      await _menuKey.currentState?.hide();
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.value != null;
    String displayText = widget.hint;
    
    if (isActive) {
      final selectedOption = widget.options.firstWhere((o) => o.value == widget.value, orElse: () => _FilterOption(value: widget.value!, label: ''));
      displayText = selectedOption.label;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: AnimatedContainer(
          key: _buttonKey,
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: EdgeInsets.only(left: 16, right: isActive ? 12 : 16),
          decoration: BoxDecoration(
            color: _isHovered || isActive ? const Color(0xFFF5F8FC) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _isHovered || isActive ? const Color(0xFF003C82) : const Color(0xFFE0E5EC), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 8)],
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600, 
                    color: isActive ? const Color(0xFF003C82) : const Color(0xFF8A8A8A)
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    widget.onClear();
                    if (_overlayEntry != null) _closeMenu();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE53935)),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOverlayContent<T> extends StatefulWidget {
  final T? currentValue;
  final List<_FilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final double menuWidth;

  const _FilterOverlayContent({super.key, required this.currentValue, required this.options, required this.onSelected, required this.menuWidth});

  @override
  State<_FilterOverlayContent<T>> createState() => _FilterOverlayContentState<T>();
}

class _FilterOverlayContentState<T> extends State<_FilterOverlayContent<T>> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _expanded = true);
    });
  }

  Future<void> hide() async {
    if (mounted) setState(() => _expanded = false);
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.menuWidth,
        constraints: const BoxConstraints(maxHeight: 350), // Evita menu infiniti
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, spreadRadius: 2)],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.options.map((option) {
                      return _FilterMenuItem(
                        text: option.label,
                        isSelected: widget.currentValue == option.value,
                        onTap: () => widget.onSelected(option.value),
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

class _FilterMenuItem extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterMenuItem({required this.text, required this.isSelected, required this.onTap});

  @override
  State<_FilterMenuItem> createState() => _FilterMenuItemState();
}

class _FilterMenuItemState extends State<_FilterMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.transparent, 
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: (_hover || widget.isSelected) ? 16 : 0,
                decoration: BoxDecoration(color: const Color(0xFF003C82), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF003C82),
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

// ============================================================================
// RESTO DEL CODICE (Card, Dettaglio, Wizard)
// ============================================================================

/// CHIP CUSTOM
class CustomChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const CustomChip({required this.label, required this.isSelected, required this.onSelected, super.key});

  @override
  State<CustomChip> createState() => _CustomChipState();
}

class _CustomChipState extends State<CustomChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onSelected(!widget.isSelected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), // Reso leggermente più rapido e scattante
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFF003C82) : (_isHovered ? const Color(0xFFF5F8FC) : Colors.white),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFF003C82) : const Color(0xFFE0E5EC),
              width: 1.0, // <-- Fissato a 1.0 per impedire i ricalcoli di layout sui sub-pixel
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : const Color(0xFF003C82),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

/// LA CARD DELL'OFFERTA
class _OfferingCard extends StatefulWidget {
  final TeachingOfferingItem offering;
  final VoidCallback onTap;

  const _OfferingCard({required this.offering, required this.onTap});

  @override
  State<_OfferingCard> createState() => _OfferingCardState();
}

class _OfferingCardState extends State<_OfferingCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 320,
          height: 114,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _isHovering ? const Color(0xFF003C82) : Colors.transparent, width: 2), // Hover blu
            boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoResizeText(
                text: widget.offering.schoolName, maxFontSize: 24, minFontSize: 16, maxLines: 2,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82), height: 1.1),
              ),
              const SizedBox(height: 6),
              Text(
                widget.offering.studyProgramName, 
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF8A8A8A))
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LA FINESTRA DI DETTAGLIO
class _OfferingDetailsDialogContent extends StatelessWidget {
  final TeachingOfferingItem offering;
  final String levelItalian;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _OfferingDetailsDialogContent({
    required this.offering, required this.levelItalian, required this.onEditRequested, required this.onDelete
  });

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Conferma Eliminazione', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
          content: Text('Sei sicuro di voler eliminare questa offerta didattica?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          actions: [
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(confirmContext),
              child: Text('ANNULLA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A8A8A), fontWeight: FontWeight.w600)),
            ),
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () {
                Navigator.pop(confirmContext);
                Navigator.pop(context); // Chiude i dettagli
                onDelete();
              },
              child: Text('ELIMINA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueDisciplines = offering.subjects.map((s) => s.discipline).toSet().toList()..sort();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dettagli Offerta', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Scuola'),
                    Text(offering.schoolName, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
                    _buildFieldLabel('Indirizzo di Studio'),
                    Text(offering.studyProgramName, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Livello'), Text(levelItalian, style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600))])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Anni Scolastici'), Text(offering.years.join(', '), style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600))])),
                      ],
                    ),
                    _buildFieldLabel('Discipline Trattate'),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: uniqueDisciplines.map((d) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE0E5EC)),
                          ),
                          child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'MODIFICA',
                      icon: Icons.edit_outlined,
                      baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99),
                      onPressed: onEditRequested,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'ELIMINA',
                      icon: Icons.delete_outline_rounded,
                      baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350),
                      onPressed: () => _showDeleteConfirmation(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// IL WIZARD A 5 STEP (INSERIMENTO / MODIFICA)
class _OfferingWizardDialog extends StatefulWidget {
  final OfferingOptions options;
  final TeachingOfferingItem? existingOffering; 
  final Function(String, int, String, List<int>, List<int>, Function(String)) onSave;

  const _OfferingWizardDialog({required this.options, this.existingOffering, required this.onSave});

  @override
  State<_OfferingWizardDialog> createState() => _OfferingWizardDialogState();
}

class _OfferingWizardDialogState extends State<_OfferingWizardDialog> {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  bool _isSaving = false;

  final TextEditingController _schoolSearchCtrl = TextEditingController();
  final TextEditingController _programSearchCtrl = TextEditingController();
  final TextEditingController _disciplineSearchCtrl = TextEditingController();

  String? _selectedSchoolCode;
  int? _selectedProgramId;
  String? _selectedLevel;
  List<int> _selectedYears = [];
  List<String> _selectedDisciplines = [];

  final Map<String, List<int>> _disciplineToIds = {};
  List<String> _allDisciplines = [];

  @override
  void initState() {
    super.initState();
    for (var s in widget.options.subjects) {
      if (!_disciplineToIds.containsKey(s.discipline)) {
        _disciplineToIds[s.discipline] = [];
      }
      _disciplineToIds[s.discipline]!.add(s.id);
    }
    _allDisciplines = _disciplineToIds.keys.toList()..sort();

    if (widget.existingOffering != null) {
      _selectedSchoolCode = widget.existingOffering!.schoolCode;
      _selectedProgramId = widget.existingOffering!.studyProgramId;
      _selectedLevel = widget.existingOffering!.level;
      _selectedYears = List.from(widget.existingOffering!.years);
      
      Set<String> disciplines = {};
      for (var s in widget.existingOffering!.subjects) {
        disciplines.add(s.discipline);
      }
      _selectedDisciplines = disciplines.toList();
    }
  }

  @override
  void dispose() {
    _schoolSearchCtrl.dispose();
    _programSearchCtrl.dispose();
    _disciplineSearchCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedSchoolCode == null) {
      CustomSnackBar.show(context: context, message: 'Seleziona una scuola.', isError: true); return;
    } else if (_currentStep == 1 && _selectedProgramId == null) {
      CustomSnackBar.show(context: context, message: 'Seleziona un indirizzo.', isError: true); return;
    } else if (_currentStep == 2 && _selectedLevel == null) {
      CustomSnackBar.show(context: context, message: 'Seleziona un livello.', isError: true); return;
    } else if (_currentStep == 3) {
      if (_selectedYears.isEmpty) { CustomSnackBar.show(context: context, message: 'Seleziona almeno un anno.', isError: true); return; }
      _selectedYears.sort();
      if (_selectedYears.last - _selectedYears.first + 1 != _selectedYears.length) { CustomSnackBar.show(context: context, message: 'Gli anni devono essere consecutivi.', isError: true); return; }
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      if (_selectedDisciplines.isEmpty) { CustomSnackBar.show(context: context, message: 'Seleziona almeno una disciplina.', isError: true); return; }
      setState(() => _isSaving = true);

      List<int> finalSubjectIds = [];
      for (var d in _selectedDisciplines) {
        finalSubjectIds.addAll(_disciplineToIds[d]!);
      }

      widget.onSave(_selectedSchoolCode!, _selectedProgramId!, _selectedLevel!, _selectedYears, finalSubjectIds, (err) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomSnackBar.show(context: context, message: err, isError: true);
        }
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.existingOffering != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 650,
        height: 550,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Modifica Offerta (${_currentStep + 1}/5)' : 'Creazione Offerta (${_currentStep + 1}/5)', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), 
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(child: _OutlinedActionButton(text: 'INDIETRO', icon: Icons.arrow_back_rounded, onPressed: _prevStep))
                  else 
                    const Spacer(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isSaving ? 'SALVATAGGIO...' : (_currentStep == 4 ? (isEditing ? 'SALVA MODIFICHE' : 'CREA OFFERTA') : 'AVANTI'),
                      icon: _currentStep == 4 ? (isEditing ? Icons.save_outlined : Icons.check_circle_outline) : Icons.arrow_forward_rounded,
                      baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99),
                      onPressed: _isSaving ? () {} : _nextStep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final query = _schoolSearchCtrl.text.toLowerCase();
    final filteredSchools = widget.options.schools.where((s) => s.name.toLowerCase().contains(query) || s.mechanographicCode.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona la Scuola', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _schoolSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca scuola...'),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: filteredSchools.map((s) => CustomChip(label: s.name, isSelected: _selectedSchoolCode == s.mechanographicCode, onSelected: (v) => setState(() => _selectedSchoolCode = v ? s.mechanographicCode : null))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final query = _programSearchCtrl.text.toLowerCase();
    final filteredPrograms = widget.options.studyPrograms.where((p) => p.name.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona l\'Indirizzo di Studio', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _programSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca indirizzo...'),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: filteredPrograms.map((p) => CustomChip(label: p.name, isSelected: _selectedProgramId == p.id, onSelected: (v) => setState(() => _selectedProgramId = v ? p.id : null))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona il Livello Scolastico', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              CustomChip(label: 'Primaria', isSelected: _selectedLevel == 'PRIMARY_SCHOOL', onSelected: (v) => setState(() { _selectedLevel = v ? 'PRIMARY_SCHOOL' : null; _selectedYears.clear(); })),
              CustomChip(label: 'Secondaria I Grado', isSelected: _selectedLevel == 'MIDDLE_SCHOOL', onSelected: (v) => setState(() { _selectedLevel = v ? 'MIDDLE_SCHOOL' : null; _selectedYears.clear(); })),
              CustomChip(label: 'Secondaria II Grado', isSelected: _selectedLevel == 'HIGH_SCHOOL', onSelected: (v) => setState(() { _selectedLevel = v ? 'HIGH_SCHOOL' : null; _selectedYears.clear(); })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    int maxYears = _selectedLevel == 'MIDDLE_SCHOOL' ? 3 : 5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona gli Anni (Consecutivi)', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: List.generate(maxYears, (i) {
              final y = i + 1;
              return CustomChip(label: '$y° Anno', isSelected: _selectedYears.contains(y), onSelected: (v) => setState(() { if (v) { _selectedYears.add(y); } else { _selectedYears.remove(y); } }));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    final query = _disciplineSearchCtrl.text.toLowerCase();
    final filteredDisciplines = _allDisciplines.where((d) => d.toLowerCase().contains(query)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona le Discipline', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF003C82), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AnimatedSearchBar(controller: _disciplineSearchCtrl, onChanged: (_) => setState((){}), hintText: 'Cerca disciplina...'),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: filteredDisciplines.map((d) => CustomChip(label: d, isSelected: _selectedDisciplines.contains(d), onSelected: (v) => setState(() { if (v) { _selectedDisciplines.add(d); } else { _selectedDisciplines.remove(d); } }))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottone "Indietro" stilizzato
class _OutlinedActionButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const _OutlinedActionButton({required this.text, required this.icon, required this.onPressed});

  @override
  State<_OutlinedActionButton> createState() => _OutlinedActionButtonState();
}

class _OutlinedActionButtonState extends State<_OutlinedActionButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) { setState(() => _isPressed = false); widget.onPressed(); },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuint,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutQuint,
            height: 56,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFF5F8FC) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF003C82), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: const Color(0xFF003C82), size: 20),
                const SizedBox(width: 8),
                Text(widget.text, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF003C82), letterSpacing: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}