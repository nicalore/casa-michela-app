import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/person_item.dart';
import '../models/school_enrollment_item.dart';
import '../person_wizard_components.dart';
import '../../../shared/widgets/shared_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../services/api_service.dart';
import '../../association/models/school_item.dart';
import '../../association/models/study_program_item.dart';

class PersonSchoolsTab extends StatelessWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const PersonSchoolsTab({
    super.key,
    required this.person,
    required this.onUpdate,
  });

  int _getCurrentSchoolYearStart() 
  {
    final now = DateTime.now();
    return now.month < 9 ? now.year - 1 : now.year;
  }

  bool _isRipetente(SchoolEnrollmentItem current, List<SchoolEnrollmentItem> all) 
  {
    final previous = all.where((e) => e.startYear == current.startYear - 1).firstOrNull;
    if (previous == null) 
    {
      return false;
    }
    return current.grade == previous.grade && current.educationLevel == previous.educationLevel;
  }

  String _getRomanGrade(int grade) 
  {
    const map = 
    {
      1: 'I', 
      2: 'II', 
      3: 'III', 
      4: 'IV', 
      5: 'V',
    };
    return map[grade] ?? grade.toString();
  }

  void _showEditDialog(BuildContext context) 
  {
    showGeneralDialog(
      context:            context, 
      barrierDismissible: true, 
      barrierLabel:       'EditSchools', 
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
              child: _EditSchoolsDialog(
                person:   person, 
                onUpdate: onUpdate,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final List<SchoolEnrollmentItem> enrollments = List<SchoolEnrollmentItem>.from(person.schoolEnrollments ?? []);
    enrollments.sort((a, b) => b.startYear.compareTo(a.startYear));

    final currentYear                     = _getCurrentSchoolYearStart();
    final SchoolEnrollmentItem? current   = enrollments.where((e) => e.startYear == currentYear).firstOrNull;
    final List<SchoolEnrollmentItem> past = enrollments.where((e) => e.startYear < currentYear).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current != null) ...[
            Text(
              'Iscrizione scolastica attuale',
              style: GoogleFonts.plusJakartaSans(
                fontSize:   24,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF003C82),
              ),
            ),
            const SizedBox(height: 16),
            _buildEnrollmentCard(current, enrollments, isCurrent: true),
            const SizedBox(height: 48),
          ],
          if (past.isNotEmpty) ...[
            Text(
              'Iscrizioni scolastiche passate',
              style: GoogleFonts.plusJakartaSans(
                fontSize:   24,
                fontWeight: FontWeight.w700,
                color:      const Color(0xFF003C82),
              ),
            ),
            const SizedBox(height: 16),
            ...past.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child:   _buildEnrollmentCard(m, enrollments, isCurrent: false),
            )),
          ],
          if (current == null && past.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Nessuna iscrizione scolastica registrata.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize:   16,
                  fontWeight: FontWeight.w500,
                  color:      const Color(0xFF64748B),
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          Center(
            child: SizedBox(
              width: 360,
              child: AnimatedActionButton(
                text:       'MODIFICA ISCRIZIONI SCOLASTICHE',
                icon:       Icons.edit_rounded,
                baseColor:  const Color(0xFF003C82),
                hoverColor: const Color(0xFF004D99),
                onPressed:  () => _showEditDialog(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentCard(SchoolEnrollmentItem item, List<SchoolEnrollmentItem> all, {required bool isCurrent}) 
  {
    final bool isRipetente = _isRipetente(item, all);

    return SelectionArea(
      child: Container(
        width:      double.infinity,
        padding:    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: const Color(0xFF003C82).withValues(alpha: 0.3),
            width: 2.0,
          ),
          boxShadow: isCurrent 
            ? const [
                BoxShadow(
                  color:      Color(0x0A000000),
                  offset:     Offset(0, 4),
                  blurRadius: 16,
                ),
              ] 
            : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCurrent) ...[
                  const SizedBox(width: 12),
                ],
                Text(
                  'Anno scolastico ${item.startYear}/${item.startYear + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   24,
                    fontWeight: FontWeight.w800,
                    color:      const Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildInfoItem('Scuola',   item.schoolName)),
                Expanded(child: _buildInfoItem('Livello',  item.educationLevel)),
                Expanded(child: _buildInfoItem('Percorso', item.studyProgramName)),
                Expanded(child: _buildInfoItem('Classe',   _getRomanGrade(item.grade))),
                Expanded(child: _buildInfoItem('Ripetente', isRipetente ? 'Sì' : 'No', highlight: isRipetente)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool highlight = false}) 
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize:   14,
            fontWeight: FontWeight.w600,
            color:      const Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize:   18,
            fontWeight: FontWeight.w700,
            color:      highlight ? const Color(0xFFE53935) : const Color(0xFF334155),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EditSchoolsDialog extends StatefulWidget 
{
  final PersonItem   person;
  final VoidCallback onUpdate;

  const _EditSchoolsDialog({
    required this.person, 
    required this.onUpdate,
  });

  @override
  State<_EditSchoolsDialog> createState() => _EditSchoolsDialogState();
}

class _EditSchoolsDialogState extends State<_EditSchoolsDialog> 
{
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  bool _isSaving  = false;
  
  List<SchoolItem>       _allSchools  = [];
  List<StudyProgramItem> _allPrograms = [];
  
  final List<_SchoolRowData> _rows   = [];
  final Map<String, String>  _errors = {};

  @override
  void initState() 
  {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async 
  {
    try 
    {
      final results = await Future.wait([
        _apiService.getSchools(),
        _apiService.getStudyPrograms(),
      ]);
      
      _allSchools  = results[0] as List<SchoolItem>;
      _allPrograms = results[1] as List<StudyProgramItem>;
      
      final enrollments = widget.person.schoolEnrollments ?? [];
      
      for (var e in enrollments) 
      {
        final school  = _allSchools.where((s) => s.mechanographicCode == e.schoolMechanographicCode).firstOrNull;
        final program = _allPrograms.where((p) => p.id == e.studyProgramId).firstOrNull;
        
        String? gradeString;
        if (program != null)
        {
          const map = 
          {
            1: 'I', 
            2: 'II', 
            3: 'III', 
            4: 'IV', 
            5: 'V',
          };
          gradeString = map[e.grade];
        }

        _rows.add(_SchoolRowData(
          yearCtrl:        TextEditingController(text: e.startYear.toString()),
          selectedSchool:  school,
          selectedProgram: program,
          selectedGrade:   gradeString,
        ));
      }
      
      if (mounted) 
      {
        setState(() => _isLoading = false);
      }
    } 
    catch (_) 
    {
      if (mounted) 
      {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() 
  {
    for (var r in _rows) 
    {
      r.yearCtrl.dispose();
    }
    super.dispose();
  }

  int _getCurrentSchoolYearStart() 
  {
    final now = DateTime.now();
    return now.month < 9 ? now.year - 1 : now.year;
  }

  void _addEmptyRow() 
  {
    int lastYear = DateTime.now().year;
    if (_rows.isNotEmpty) 
    {
      int maxYear = 0;
      for (var r in _rows)
      {
        int y = int.tryParse(r.yearCtrl.text) ?? 0;
        if (y > maxYear) 
        {
          maxYear = y;
        }
      }
      lastYear = maxYear > 0 ? maxYear : lastYear;
    }
    
    setState(() 
    {
      _rows.add(_SchoolRowData(
        yearCtrl: TextEditingController(text: (lastYear - 1).toString()),
      ));
    });
  }

  int _romanToNumeric(String roman) 
  {
    const map = 
    {
      'I':   1, 
      'II':  2, 
      'III': 3, 
      'IV':  4, 
      'V':   5,
    };
    return map[roman] ?? 1;
  }

  Future<void> _save() async 
  {
    if (_rows.isEmpty) 
    {
      CustomSnackBar.show(
        context: context, 
        message: 'Lo studente deve avere almeno un anno scolastico.', 
        isError: true,
      );
      return;
    }

    setState(() => _errors.clear());
    bool hasErrors           = false;
    bool showFutureYearError = false;
    
    List<Map<String, dynamic>> payloadEnrollments = [];
    final Set<int>             distinctYears      = {};

    for (int i = 0; i < _rows.length; i++) 
    {
      final r = _rows[i];
      
      if (r.yearCtrl.text.isEmpty || !RegExp(r'^\d{4}$').hasMatch(r.yearCtrl.text)) 
      {
        _errors['year_$i'] = 'Errore';
        hasErrors          = true;
      }
      else
      {
        int parsedYear = int.parse(r.yearCtrl.text);
        if (parsedYear > _getCurrentSchoolYearStart())
        {
           _errors['year_$i']  = 'Anno futuro';
           hasErrors           = true;
           showFutureYearError = true;
        }
        else if (distinctYears.contains(parsedYear))
        {
          _errors['year_$i'] = 'Duplicato';
          hasErrors          = true;
        }
        else
        {
          distinctYears.add(parsedYear);
        }
      }
      
      if (r.selectedSchool == null)
      {
        _errors['school_$i'] = 'Obbligatorio';
        hasErrors            = true;
      }
      
      if (r.selectedProgram == null)
      {
        _errors['program_$i'] = 'Obbligatorio';
        hasErrors             = true;
      }
      
      if (r.selectedGrade == null)
      {
        _errors['grade_$i'] = 'Obbligatorio';
        hasErrors           = true;
      }

      if (!hasErrors) 
      {
        payloadEnrollments.add({
          "start_year":                 int.parse(r.yearCtrl.text),
          "school_mechanographic_code": r.selectedSchool!.mechanographicCode,
          "study_program_id":           r.selectedProgram!.id,
          "grade":                      _romanToNumeric(r.selectedGrade!),
        });
      }
    }

    if (hasErrors) 
    {
      setState(() {});
      if (showFutureYearError)
      {
        CustomSnackBar.show(context: context, message: 'Non è possibile inserire iscrizioni per anni scolastici futuri.', isError: true);
      }
      else
      {
        CustomSnackBar.show(context: context, message: 'Correggi gli errori prima di salvare.', isError: true);
      }
      return;
    }

    setState(() => _isSaving = true);
    
    try 
    {
      await _apiService.updatePersonSchoolEnrollments(
        widget.person.fiscalCode,
        payloadEnrollments,
      );
      
      if (mounted) 
      {
        CustomSnackBar.show(
          context: context, 
          message: 'Iscrizioni scolastiche aggiornate!', 
          isError: false,
        );
        Navigator.of(context).pop();
        widget.onUpdate();
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        CustomSnackBar.show(
          context: context, 
          message: e.toString().replaceAll('Exception: ', ''), 
          isError: true,
        );
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFieldLabel(String text) 
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize:   12,
          fontWeight: FontWeight.w700,
          color:      const Color(0xFF64748B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Dialog(
      backgroundColor: Colors.transparent, 
      elevation:       0,
      child: Container(
        width:       980, 
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration:  BoxDecoration(
          color:        Colors.white, 
          borderRadius: BorderRadius.circular(30), 
          boxShadow:    const [
            BoxShadow(
              color:      Color(0x1A000000), 
              offset:     Offset(0, 8), 
              blurRadius: 24,
            ),
          ],
        ),
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF003C82)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Modifica Iscrizioni Scolastiche', 
                          style: GoogleFonts.plusJakartaSans(
                            fontSize:   22, 
                            fontWeight: FontWeight.w700, 
                            color:      const Color(0xFF003C82),
                          ),
                        ),
                        WizardHoverCloseButton(onTap: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(_rows.length, (i) 
                            {
                              final r = _rows[i];
                              
                              final List<String> schoolNames = _allSchools.map((s) => '${s.name} (${s.city})').toList();
                              
                              List<String> programNames = [];
                              if (r.selectedSchool != null)
                              {
                                try 
                                {
                                  dynamic progs;
                                  try { progs = (r.selectedSchool as dynamic).studyPrograms; } catch (_) {}
                                  if (progs == null) { try { progs = (r.selectedSchool as dynamic).study_programs; } catch (_) {} }
                                  
                                  if (progs != null && progs is Iterable) 
                                  {
                                    for (var p in progs) 
                                    {
                                      String? pName;
                                      if (p is Map) 
                                      {
                                        pName = p['name'] as String?;
                                      }
                                      else 
                                      { 
                                        try { pName = (p as dynamic).name as String?; } catch (_) {} 
                                      }
                                      
                                      if (pName != null && pName.isNotEmpty) 
                                      {
                                        if (_allPrograms.any((allP) => allP.name == pName) && !programNames.contains(pName)) 
                                        {
                                          programNames.add(pName);
                                        }
                                      }
                                    }
                                  }
                                } 
                                catch (_) {}
                              }
                              
                              List<String> gradeOptions = [];
                              if (r.selectedProgram != null)
                              {
                                final level = r.selectedProgram!.level;
                                if (level == 'MIDDLE_SCHOOL' || level == 'Scuola secondaria di primo grado' || level == 'Medie' || level == 'MEDIE') 
                                {
                                  gradeOptions = ['I', 'II', 'III'];
                                }
                                else 
                                {
                                  gradeOptions = ['I', 'II', 'III', 'IV', 'V'];
                                }
                              }
                              
                              return Container(
                                margin:     const EdgeInsets.only(bottom: 16),
                                padding:    const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border:       Border.all(color: const Color(0xFFE2E8F0)),
                                  color:        const Color(0xFFF8FAFC),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Anno inizio'),
                                          WizardAnimatedTextField(
                                            controller:   r.yearCtrl,
                                            hint:         'Es. 2024',
                                            errorText:    _errors['year_$i'],
                                            keyboardType: TextInputType.number,
                                            onChanged:    (_) => setState(() => _errors.remove('year_$i')),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Scuola'),
                                          _FormOverlayDropdown(
                                            value:      r.selectedSchool != null ? '${r.selectedSchool!.name} (${r.selectedSchool!.city})' : null,
                                            options:    schoolNames,
                                            hint:       'Seleziona scuola',
                                            errorText:  _errors['school_$i'],
                                            onSelected: (val) 
                                            {
                                              setState(() 
                                              {
                                                r.selectedSchool  = _allSchools.firstWhere((s) => '${s.name} (${s.city})' == val);
                                                r.selectedProgram = null;
                                                r.selectedGrade   = null;
                                                _errors.remove('school_$i');
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Percorso'),
                                          _FormOverlayDropdown(
                                            value:      r.selectedProgram?.name,
                                            options:    programNames,
                                            hint:       'Seleziona percorso',
                                            errorText:  _errors['program_$i'],
                                            onSelected: (val) 
                                            {
                                              setState(() 
                                              {
                                                r.selectedProgram = _allPrograms.firstWhere((p) => p.name == val);
                                                r.selectedGrade   = null;
                                                _errors.remove('program_$i');
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildFieldLabel('Classe'),
                                          _FormOverlayDropdown(
                                            value:      r.selectedGrade,
                                            options:    gradeOptions,
                                            hint:       'Classe',
                                            errorText:  _errors['grade_$i'],
                                            onSelected: (val) => setState(() 
                                            {
                                              r.selectedGrade = val;
                                              _errors.remove('grade_$i');
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 28, left: 16),
                                      child: WizardRemoveRowButton(
                                        onTap: () => setState(() => _rows.removeAt(i)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: WizardTextLinkButton(
                                text:  'AGGIUNGI ANNO',
                                icon:  Icons.add_rounded,
                                onTap: _addEmptyRow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: WizardAnimatedActionButton(
                            text:       'ANNULLA', 
                            icon:       Icons.cancel_outlined, 
                            baseColor:  const Color(0xFFE53935), 
                            hoverColor: const Color(0xFFEF5350), 
                            onPressed:  () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: WizardAnimatedActionButton(
                            text:       _isSaving ? 'SALVATAGGIO...' : 'SALVA MODIFICHE', 
                            icon:       Icons.save_outlined, 
                            baseColor:  const Color(0xFF003C82), 
                            hoverColor: const Color(0xFF004D99),
                            onPressed:  _isSaving ? () {} : _save,
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

class _SchoolRowData 
{
  TextEditingController yearCtrl;
  SchoolItem?           selectedSchool;
  StudyProgramItem?     selectedProgram;
  String?               selectedGrade;

  _SchoolRowData({
    required this.yearCtrl,
    this.selectedSchool,
    this.selectedProgram,
    this.selectedGrade,
  });
}

class _FormOverlayDropdown extends StatefulWidget 
{
  final String?              value;
  final List<String>         options;
  final String               hint;
  final String?              errorText;
  final ValueChanged<String> onSelected;

  const _FormOverlayDropdown({
    required this.value, 
    required this.options, 
    required this.hint, 
    this.errorText,
    required this.onSelected,
  });

  @override
  State<_FormOverlayDropdown> createState() => _FormOverlayDropdownState();
}

class _FormOverlayDropdownState extends State<_FormOverlayDropdown> 
{
  final GlobalKey                           _buttonKey = GlobalKey();
  OverlayEntry?                             _overlayEntry;
  final GlobalKey<_FormOverlayContentState> _menuKey   = GlobalKey();
  bool                                      _isHovered = false;

  void _toggleMenu() 
  {
    if (_overlayEntry != null || widget.options.isEmpty) 
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
            top:  offset.dy + size.height + 4,
            left: offset.dx,
            child: _FormOverlayContent(
              key:          _menuKey,
              currentValue: widget.value,
              options:      widget.options,
              width:        size.width,
              onSelected:   (val) 
              { 
                widget.onSelected(val); 
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
    final bool hasError = widget.errorText != null;
    final bool disabled = widget.options.isEmpty;

    return MouseRegion(
      cursor:  disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: disabled ? null : _toggleMenu,
        child: AnimatedContainer(
          key:        _buttonKey,
          duration:   const Duration(milliseconds: 200),
          height:     50,
          padding:    EdgeInsets.only(left: 16, right: hasError ? 8 : 16),
          decoration: BoxDecoration(
            color:        disabled ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(
              color: hasError ? const Color(0xFFE53935) : (_isHovered ? const Color(0xFF003C82) : const Color(0xFFE2E8F0)), 
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.value ?? widget.hint,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   16, 
                    fontWeight: widget.value != null ? FontWeight.w600 : FontWeight.w500, 
                    color:      disabled ? const Color(0xFFCBD5E1) : (widget.value != null ? const Color(0xFF2A2A2A) : const Color(0xFFB3B3B3)),
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message:   widget.errorText!,
                    textStyle: GoogleFonts.plusJakartaSans(
                      color:      Colors.white, 
                      fontSize:   13, 
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFE53935), 
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded, 
                      color: Color(0xFFE53935), 
                      size:  22,
                    ),
                  ),
                ),
              Icon(
                Icons.keyboard_arrow_down_rounded, 
                color: disabled ? const Color(0xFFCBD5E1) : (_isHovered ? const Color(0xFF003C82) : const Color(0xFF8A8A8A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOverlayContent extends StatefulWidget 
{
  final String?              currentValue;
  final List<String>         options;
  final ValueChanged<String> onSelected;
  final double               width;

  const _FormOverlayContent({
    super.key, 
    required this.currentValue, 
    required this.options, 
    required this.onSelected, 
    required this.width,
  });

  @override
  State<_FormOverlayContent> createState() => _FormOverlayContentState();
}

class _FormOverlayContentState extends State<_FormOverlayContent> 
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
        setState(() => _expanded = true); 
      }
    });
  }

  Future<void> hide() async 
  {
    if (mounted) 
    {
      setState(() => _expanded = false);
    }
    await Future.delayed(const Duration(milliseconds: 180));
  }

  @override
  Widget build(BuildContext context) 
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width:       widget.width,
        constraints: const BoxConstraints(maxHeight: 250),
        decoration:  BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow:    const [
            BoxShadow(
              color:        Color(0x14000000), 
              blurRadius:   20, 
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSize(
          duration:  const Duration(milliseconds: 180),
          curve:     Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded 
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:       MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.options.map((option) 
                    {
                      return _FormOverlayMenuItem(
                        text:       option,
                        isSelected: widget.currentValue == option,
                        onTap:      () => widget.onSelected(option),
                      );
                    }).toList(),
                  ),
                ),
              ) 
            : SizedBox(
                width:  widget.width, 
                height: 0,
              ),
        ),
      ),
    );
  }
}

class _FormOverlayMenuItem extends StatefulWidget 
{
  final String       text;
  final bool         isSelected;
  final VoidCallback onTap;

  const _FormOverlayMenuItem({
    required this.text, 
    required this.isSelected, 
    required this.onTap,
  });

  @override
  State<_FormOverlayMenuItem> createState() => _FormOverlayMenuItemState();
}

class _FormOverlayMenuItemState extends State<_FormOverlayMenuItem> 
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: (widget.isSelected || _hover) ? FontWeight.w700 : FontWeight.w500,
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