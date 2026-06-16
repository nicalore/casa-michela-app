import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/subject_item.dart';
import '../widgets/subject_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../services/api_service.dart';
import '../../../shared/widgets/shared_components.dart';

class SubjectsTab extends StatefulWidget {
  const SubjectsTab({super.key});

  @override
  State<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<SubjectsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _ascending = true;
  bool _newSubjectHover = false;
  bool _isLoading = true; // Flag per il caricamento dal DB

  // Lista vuota, si popolerà tramite API
  List<SubjectItem> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final data = await _apiService.getSubjects();
      if (mounted) {
        setState(() {
          _subjects = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
          context: context,
          message: 'Impossibile caricare le materie dal server.',
          isError: true,
        );
      }
    }
  }

  List<SubjectItem> get _filteredSubjects {
    var result = _subjects.where((subject) {
      final query = _searchText.toLowerCase();
      return subject.discipline.toLowerCase().contains(query) ||
          subject.areas.any((area) => area.toLowerCase().contains(query));
    }).toList();

    result.sort((a, b) {
      return _ascending 
          ? a.discipline.compareTo(b.discipline) 
          : b.discipline.compareTo(a.discipline);
    });

    return result;
  }

  void _executeCreate(String newDiscipline, List<String> newAreas, Function(String) onError, VoidCallback onSuccess) async {
    if (newDiscipline.isEmpty) {
      onError('Il nome della disciplina non può essere vuoto.');
      return;
    }

    try {
      await _apiService.createSubject(newDiscipline, newAreas);
      setState(() {
        _subjects.add(SubjectItem(discipline: newDiscipline, areas: newAreas));
      });
      onSuccess();
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeEdit(String oldDiscipline, String newDiscipline, List<String> newAreas, Function(String) onError) async {
    if (newDiscipline.isEmpty) {
      onError('Il nome della disciplina non può essere vuoto.');
      return;
    }

    try {
      await _apiService.updateSubject(oldDiscipline, newDiscipline, newAreas);
      setState(() {
        final index = _subjects.indexWhere((s) => s.discipline == oldDiscipline);
        if (index != -1) {
          _subjects[index] = SubjectItem(discipline: newDiscipline, areas: newAreas);
        }
      });
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeDelete(SubjectItem item) async {
    try {
      await _apiService.deleteSubject(item.discipline);
      setState(() {
        _subjects.removeWhere((s) => s.discipline == item.discipline);
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context: context,
          message: e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  void _showCreateDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateSubject',
      barrierColor: Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
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
              child: _CreateSubjectDialog(
                onCreate: (discipline, areas, onError) {
                  _executeCreate(
                    discipline, 
                    areas, 
                    onError, 
                    () => Navigator.of(context).pop(), 
                  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedSearchBar(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                hintText: 'Cerca materia...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newSubjectHover = true),
              onExit: (_) => setState(() => _newSubjectHover = false),
              child: GestureDetector(
                onTap: _showCreateDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: _newSubjectHover ? const Color(0xFF003C82) : Colors.transparent, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
                  ),
                  child: Center(
                    child: Text(
                      'Nuova materia',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        SortDropdownMenu(
          isAscending: _ascending,
          onChanged: (value) => setState(() => _ascending = value),
        ),

        const SizedBox(height: 16),

        Text(
          _filteredSubjects.length == 1 
              ? '1 materia trovata' 
              : '${_filteredSubjects.length} materie trovate',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: const Color(0xFF003C82),
          ),
        ),

        const SizedBox(height: 16),

        // Loader mentre aspetta i dati
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF003C82)),
            ),
          )
        else
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: _filteredSubjects.map((subject) {
                return SubjectCard(
                  discipline: subject.discipline,
                  areas: subject.areas,
                  onEdit: (oldDiscipline, newDiscipline, newAreas, onError) {
                    _executeEdit(oldDiscipline, newDiscipline, newAreas, onError);
                  },
                  onDelete: () => _executeDelete(subject),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CreateSubjectDialog extends StatefulWidget {
  final Function(String discipline, List<String> areas, Function(String) onError) onCreate;

  const _CreateSubjectDialog({required this.onCreate});

  @override
  State<_CreateSubjectDialog> createState() => _CreateSubjectDialogState();
}

class _CreateSubjectDialogState extends State<_CreateSubjectDialog> {
  final TextEditingController _disciplineController = TextEditingController();
  final List<TextEditingController> _areaControllers = []; 
  bool _isCreating = false; // Previeni doppi click

  @override
  void dispose() {
    _disciplineController.dispose();
    for (var c in _areaControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 540,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nuova Materia',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                  ),
                  FadeHoverIconButton(
                    icon: Icons.close,
                    color: const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disciplina', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                      TextField(
                        controller: _disciplineController,
                        style: GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Es. Storia dell\'Arte',
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 20, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      Text('Ambiti (${_areaControllers.length})', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      
                      ...List.generate(_areaControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _areaControllers[index],
                                  style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black),
                                  decoration: const InputDecoration(
                                    hintText: 'Nome ambito',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FadeHoverIconButton(
                                icon: Icons.remove_circle_outline,
                                color: const Color(0xFFE53935),
                                hoverColor: const Color(0xFFFFEBEE),
                                onTap: () {
                                  setState(() {
                                    _areaControllers[index].dispose();
                                    _areaControllers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 12),
                      _AddAreaLinkButton(
                        onTap: () {
                          setState(() {
                            _areaControllers.add(TextEditingController());
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 24),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isCreating ? 'CREAZIONE...' : 'CREA',
                      icon: Icons.check_circle_outline,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed: () {
                        if (_isCreating) return;
                        setState(() => _isCreating = true);

                        final discipline = _disciplineController.text.trim();
                        final areas = _areaControllers.map((c) => c.text.trim()).where((text) => text.isNotEmpty).toList();
                        
                        widget.onCreate(discipline, areas, (errorMsg) {
                          if (mounted) {
                            setState(() => _isCreating = false);
                            CustomSnackBar.show(
                              context: context,
                              message: errorMsg,
                              isError: true,
                            );
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: 'ANNULLA',
                      icon: Icons.cancel_outlined,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () => Navigator.of(context).pop(),
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

class _AddAreaLinkButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddAreaLinkButton({required this.onTap});

  @override
  State<_AddAreaLinkButton> createState() => _AddAreaLinkButtonState();
}

class _AddAreaLinkButtonState extends State<_AddAreaLinkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.bottomLeft, 
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 2), 
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add, 
                    color: _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82), 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.plusJakartaSans(
                      color: _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    child: const Text('Aggiungi ambito'),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: Row( 
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutQuint,
                      widthFactor: _isHovered ? 1.0 : 0.0, 
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFF002244),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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