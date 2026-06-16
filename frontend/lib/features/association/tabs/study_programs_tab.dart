import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/study_program_item.dart';
import '../widgets/study_program_card.dart';
import '../../../shared/widgets/shared_components.dart'; 
import '../../../shared/widgets/snackbar.dart'; 
import '../../../services/api_service.dart';

class StudyProgramsTab extends StatefulWidget {
  const StudyProgramsTab({super.key});

  @override
  State<StudyProgramsTab> createState() => _StudyProgramsTabState();
}

class _StudyProgramsTabState extends State<StudyProgramsTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _ascending = true;
  bool _newProgramHover = false;
  bool _isLoading = true;

  List<StudyProgramItem> _programs = [];

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final data = await _apiService.getStudyPrograms();
      if (mounted) {
        setState(() {
          _programs = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(context: context, message: 'Impossibile caricare gli indirizzi di studio.', isError: true);
      }
    }
  }

  List<StudyProgramItem> get _filteredPrograms {
    var result = _programs.where((p) {
      final query = _searchText.toLowerCase();
      return p.name.toLowerCase().contains(query) || p.description.toLowerCase().contains(query);
    }).toList();

    result.sort((a, b) {
      return _ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name);
    });

    return result;
  }

  void _executeCreate(String name, String desc, Function(String) onError, VoidCallback onSuccess) async {
    try {
      final created = await _apiService.createStudyProgram(name: name, description: desc);
      setState(() => _programs.add(created));
      onSuccess();
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeEdit(int id, String name, String desc, Function(String) onError) async {
    try {
      final updated = await _apiService.updateStudyProgram(id: id, name: name, description: desc);
      setState(() {
        final index = _programs.indexWhere((p) => p.id == id);
        if (index != -1) _programs[index] = updated;
      });
    } catch (e) {
      onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _executeDelete(StudyProgramItem item) async {
    try {
      await _apiService.deleteStudyProgram(item.id);
      setState(() => _programs.removeWhere((p) => p.id == item.id));
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
      barrierLabel: 'CreateStudyProgram',
      barrierColor: Colors.black.withValues(alpha:  0.15),
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
              child: _CreateStudyProgramDialog(
                onCreate: (name, desc, onError) {
                  _executeCreate(name, desc, onError, () => Navigator.of(context).pop());
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
                hintText: 'Cerca indirizzo di studio...',
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _newProgramHover = true),
              onExit: (_) => setState(() => _newProgramHover = false),
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
                    border: Border.all(color: _newProgramHover ? const Color(0xFF003C82) : Colors.transparent, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
                  ),
                  child: Center(
                    child: Text('Nuovo indirizzo', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
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
          _filteredPrograms.length == 1 ? '1 indirizzo trovato' : '${_filteredPrograms.length} indirizzi trovati',
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
              children: _filteredPrograms.map((program) {
                return StudyProgramCard(
                  program: program,
                  onEdit: _executeEdit,
                  onDelete: () => _executeDelete(program),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CreateStudyProgramDialog extends StatefulWidget {
  final Function(String name, String description, Function(String) onError) onCreate;
  const _CreateStudyProgramDialog({required this.onCreate});

  @override
  State<_CreateStudyProgramDialog> createState() => _CreateStudyProgramDialogState();
}

class _CreateStudyProgramDialogState extends State<_CreateStudyProgramDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
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
                  Text('Nuovo Indirizzo', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
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
                  _buildFieldLabel('Nome'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.plusJakartaSans(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(hintText: 'Es. Liceo Scientifico Opzione Scienze Applicate', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 18, color: const Color(0xFFB3B3B3), fontWeight: FontWeight.w500), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
                  ),
                  _buildFieldLabel('Descrizione (Opzionale)'),
                  TextField(
                    controller: _descController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(hintText: 'Aggiungi una descrizione...', hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFFB3B3B3)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2))),
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
                        final name = _nameController.text.trim();
                        if (name.isEmpty) { CustomSnackBar.show(context: context, message: 'Inserisci il nome dell\'indirizzo.', isError: true); return; }

                        setState(() => _isCreating = true);
                        widget.onCreate(name, _descController.text.trim(), (errorMsg) {
                          if (mounted) {
                            setState(() => _isCreating = false);
                            CustomSnackBar.show(context: context, message: errorMsg, isError: true);
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