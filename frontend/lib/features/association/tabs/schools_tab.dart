import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/school_item.dart';
import '../widgets/school_card.dart';
import '../../../shared/widgets/snackbar.dart'; 
import '../../../services/api_service.dart';
import '../../../shared/widgets/shared_components.dart';

class SchoolsTab extends StatefulWidget {
  const SchoolsTab({super.key});

  @override
  State<SchoolsTab> createState() => _SchoolsTabState();
}

class _SchoolsTabState extends State<SchoolsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _ascending = true;
  bool _newSchoolHover = false;
  bool _isLoading = true;

  List<SchoolItem> _schools = [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final data = await _apiService.getSchools();
      if (mounted) {
        setState(() {
          _schools = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Impossibile caricare le scuole.', isError: true);
      }
    }
  }

  List<SchoolItem> get _filteredSchools {
    var result = _schools.where((school) {
      final query = _searchText.toLowerCase();
      return school.name.toLowerCase().contains(query) ||
          school.mechanographicCode.toLowerCase().contains(query) ||
          school.city.toLowerCase().contains(query) ||
          school.province.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      return _ascending 
          ? a.name.compareTo(b.name) 
          : b.name.compareTo(a.name);
    });

    return result;
  }

  void _executeCreate({
    required String code, 
    required String name, 
    required String city, 
    required String prov, 
    required bool isPrivate, 
    required Function(String) onError, 
    required VoidCallback onSuccess
  }) async {
    try {
      final createdSchool = await _apiService.createSchool(
        code: code, name: name, city: city, province: prov, isPrivate: isPrivate
      );
      setState(() {
        _schools.add(createdSchool);
      });
      onSuccess();
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeEdit({
    required String oldCode, 
    required String newCode, 
    required String name, 
    required String city, 
    required String prov, 
    required bool isPrivate, 
    required Function(String) onError
  }) async {
    try {
      final updatedSchool = await _apiService.updateSchool(
        oldCode: oldCode, newCode: newCode, name: name, city: city, province: prov, isPrivate: isPrivate
      );
      setState(() {
        final index = _schools.indexWhere((s) => s.mechanographicCode == oldCode);
        if (index != -1) {
          _schools[index] = updatedSchool;
        }
      });
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeDelete(SchoolItem item) async {
    try {
      await _apiService.deleteSchool(item.mechanographicCode);
      setState(() {
        _schools.removeWhere((s) => s.mechanographicCode == item.mechanographicCode);
      });
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context: context, message: e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  void _showCreateDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateSchool',
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
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _CreateSchoolDialog(
                onCreate: (code, name, city, prov, isPrivate, onError) {
                  _executeCreate(
                    code: code, name: name, city: city, prov: prov, isPrivate: isPrivate, 
                    onError: onError, onSuccess: () => Navigator.of(context).pop()
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
                hintText: 'Cerca scuola...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newSchoolHover = true),
              onExit: (_) => setState(() => _newSchoolHover = false),
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
                    border: Border.all(color: _newSchoolHover ? const Color(0xFF003C82) : Colors.transparent, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
                  ),
                  child: Center(
                    child: Text('Nuova scuola', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
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
          _filteredSchools.length == 1 ? '1 scuola trovata' : '${_filteredSchools.length} scuole trovate',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF003C82)),
        ),

        const SizedBox(height: 16),

        if (_isLoading)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: Color(0xFF003C82))))
        else
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 20,
              children: _filteredSchools.map((school) {
                return SchoolCard(
                  school: school,
                  onEdit: (oldCode, newCode, name, city, prov, isPrivate, onError) {
                    _executeEdit(oldCode: oldCode, newCode: newCode, name: name, city: city, prov: prov, isPrivate: isPrivate, onError: onError);
                  },
                  onDelete: () => _executeDelete(school),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CreateSchoolDialog extends StatefulWidget {
  final Function(String code, String name, String city, String prov, bool isPrivate, Function(String) onError) onCreate;
  const _CreateSchoolDialog({required this.onCreate});

  @override
  State<_CreateSchoolDialog> createState() => _CreateSchoolDialogState();
}

class _CreateSchoolDialogState extends State<_CreateSchoolDialog> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provController = TextEditingController();
  bool _isCreating = false;
  bool _isPrivate = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _provController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 16),
      child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
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
                  Text('Nuova Scuola', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPrivate = !_isPrivate;
                          if (_isPrivate) _codeController.clear();
                        });
                      },
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _isPrivate ? const Color(0xFF003C82) : Colors.transparent,
                              border: Border.all(color: const Color(0xFF003C82), width: 2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _isPrivate ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Scuola privata', 
                            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  _buildFieldLabel('Codice Meccanografico'),
                  TextField(
                    controller: _codeController,
                    enabled: !_isPrivate, 
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, 
                      color: _isPrivate ? const Color(0xFFB3B3B3) : Colors.black, 
                      fontWeight: FontWeight.w600
                    ),
                    decoration: InputDecoration(
                      hintText: _isPrivate ? 'Non presente' : 'Es. VIPC010004', 
                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), 
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))
                    ),
                  ),
                  _buildFieldLabel('Nome'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(hintText: 'Es. Liceo Statale Francesco Corradini', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Città'),
                            TextField(
                              controller: _cityController,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(hintText: 'Es. Thiene', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Provincia'),
                            TextField(
                              controller: _provController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 2,
                              style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                              decoration: InputDecoration(counterText: "", hintText: 'Es. VI', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 32),
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
                        final code = _codeController.text.trim().toUpperCase();
                        final name = _nameController.text.trim();
                        final city = _cityController.text.trim();
                        final prov = _provController.text.trim().toUpperCase();

                        if (!_isPrivate && code.isEmpty) { CustomSnackBar.show(context: context, message: 'Inserisci il codice meccanografico.', isError: true); return; }
                        if (name.isEmpty || city.isEmpty) { CustomSnackBar.show(context: context, message: 'Compila tutti i campi.', isError: true); return; }
                        if (prov.length != 2) { CustomSnackBar.show(context: context, message: 'La provincia deve essere di 2 lettere.', isError: true); return; }

                        setState(() => _isCreating = true);
                        
                        widget.onCreate(
                          code, name, city, prov, _isPrivate,
                          (errorMsg) {
                            if (mounted) {
                              setState(() => _isCreating = false);
                              CustomSnackBar.show(context: context, message: errorMsg, isError: true);
                            }
                          }
                        );
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