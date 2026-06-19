import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/ministry_subject_item.dart';
import '../../../shared/widgets/shared_components.dart';

class SchoolCard extends StatefulWidget
{
  final SchoolItem school;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const SchoolCard({
    super.key,
    required this.school,
    required this.availableStudyPrograms,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  @override
  State<SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<SchoolCard>
{
  bool _isHovering = false;

  void _showDetailsDialog(BuildContext context)
  {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SchoolDetails',
      barrierColor: Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _SchoolDetailsDialogContent(
                school: widget.school,
                availableStudyPrograms: widget.availableStudyPrograms,
                availableMinistrySubjects: widget.availableMinistrySubjects,
                onEditRequested: ()
                {
                  Navigator.of(context).pop();
                  widget.onEditRequested(() => _showDetailsDialog(context));
                },
                onDelete: widget.onDelete,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: () => _showDetailsDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 320,
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _isHovering ? const Color(0xFF003C82) : Colors.transparent, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AutoResizeText(
                text: widget.school.name, maxFontSize: 22, minFontSize: 16, maxLines: 2,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82), height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                widget.school.city, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF8A8A8A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolDetailsDialogContent extends StatelessWidget
{
  final SchoolItem school;
  final List<StudyProgramItem> availableStudyPrograms;
  final List<MinistrySubjectItem> availableMinistrySubjects;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _SchoolDetailsDialogContent({
    required this.school, required this.availableStudyPrograms, required this.availableMinistrySubjects, required this.onEditRequested, required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showDialog(
      context: context,
      builder: (BuildContext confirmContext)
      {
        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Conferma Eliminazione', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
          content: Text('Sei sicuro di voler eliminare la scuola "${school.name}"?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          actions: [
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(confirmContext),
              child: Text('ANNULLA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A8A8A), fontWeight: FontWeight.w600)),
            ),
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () { Navigator.pop(confirmContext); Navigator.pop(context); onDelete(); },
              child: Text('ELIMINA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _openReadOnlyProgramDialog(BuildContext context, int programId)
  {
    final fullProgram = availableStudyPrograms.firstWhere((p) => p.id == programId, orElse: () => throw Exception('Percorso non trovato nei dati caricati'));
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'ReadOnlyProgramDetails', barrierColor: Colors.transparent, transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        return FadeTransition(opacity: animation, child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
          child: Align(alignment: const Alignment(0.5, 0.0), child: _ReadOnlyStudyProgramDialogContent(program: fullProgram, availableMinistrySubjects: availableMinistrySubjects)),
        ));
      },
    );
  }

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 20), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    final bool isPrivate = school.mechanographicCode.startsWith('PRIV-');
    return Dialog(
      backgroundColor: Colors.transparent, elevation: 0,
      child: Container(
        width: 500, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dettagli Scuola', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Codice Meccanografico'),
                    Text(isPrivate ? 'Generato automaticamente (${school.mechanographicCode})' : school.mechanographicCode, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: isPrivate ? const Color(0xFF8A8A8A) : Colors.black, fontStyle: isPrivate ? FontStyle.italic : FontStyle.normal)),
                    _buildFieldLabel('Nome'),
                    Text(school.name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Città'), Text(school.city, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black))])),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Provincia'), Text(school.province, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black))])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Percorsi di Studio Attivi'),
                    if (school.studyPrograms.isEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Nessun percorso associato a questa scuola.', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic)))
                    else Padding(padding: const EdgeInsets.only(top: 8.0), child: Wrap(spacing: 10, runSpacing: 10, children: school.studyPrograms.map((program) => _HoverableProgramChip(name: program.name, onTap: () => _openReadOnlyProgramDialog(context, program.id))).toList())),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
              child: Row(
                children: [
                  Expanded(child: AnimatedActionButton(text: 'MODIFICA', icon: Icons.edit_outlined, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: onEditRequested)),
                  const SizedBox(width: 16),
                  Expanded(child: AnimatedActionButton(text: 'ELIMINA', icon: Icons.delete_outline_rounded, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () => _showDeleteConfirmation(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverableProgramChip extends StatefulWidget
{
  final String name;
  final VoidCallback onTap;
  const _HoverableProgramChip({required this.name, required this.onTap});
  @override
  State<_HoverableProgramChip> createState() => _HoverableProgramChipState();
}

class _HoverableProgramChipState extends State<_HoverableProgramChip>
{
  bool _isHovering = false;
  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click, onEnter: (_) => setState(() => _isHovering = true), onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: _isHovering ? const Color(0xFFE2E8F0) : const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E5EC))),
          child: Text(widget.name, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF003C82))),
        ),
      ),
    );
  }
}

class _ReadOnlyStudyProgramDialogContent extends StatelessWidget
{
  final StudyProgramItem program;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  const _ReadOnlyStudyProgramDialogContent({required this.program, required this.availableMinistrySubjects});

  String _translateLevel(String level)
  {
    switch (level) { case 'PRIMARY_SCHOOL': return 'Scuola Primaria'; case 'MIDDLE_SCHOOL': return 'Scuola Secondaria di I Grado'; case 'HIGH_SCHOOL': return 'Scuola Secondaria di II Grado'; default: return level; }
  }

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 20), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 500, constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x2A000000), offset: Offset(0, 12), blurRadius: 36)]),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dettagli Percorso', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                  StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Nome Percorso'),
                    Text(program.name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                    Row(
                      children: [
                        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Livello'), Text(_translateLevel(program.level), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87))])),
                        Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildFieldLabel('Anni di corso'), Text('${program.minYear} - ${program.maxYear}', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87))])),
                      ],
                    ),
                    _buildFieldLabel('Descrizione'),
                    Text(program.description.isEmpty ? 'Nessuna descrizione fornita.' : program.description, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4, color: program.description.isEmpty ? const Color(0xFFB3B3B3) : Colors.black87, fontStyle: program.description.isEmpty ? FontStyle.italic : FontStyle.normal)),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Materie ministeriali incluse'),
                    if (program.ministrySubjects.isEmpty) Text('Nessuna materia associata.', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic))
                    else Wrap(
                      spacing: 12, runSpacing: 12,
                      children: program.ministrySubjects.map((subj)
                      {
                        final fullSubject = availableMinistrySubjects.firstWhere((s) => s.id == subj.id, orElse: () => MinistrySubjectItem(id: subj.id, name: subj.name, level: '', area: '', description: '', createdAt: DateTime.now(), associationSubjects: const []));
                        return Tooltip(
                          constraints: const BoxConstraints(maxWidth: 400),
                          richMessage: TextSpan(
                            children: [
                              TextSpan(text: 'Discipline interne:\n', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700, height: 1.5)),
                              if (fullSubject.associationSubjects.isEmpty) TextSpan(text: 'Nessuna disciplina associata', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white60, fontStyle: FontStyle.italic, height: 1.4))
                              else WidgetSpan(child: Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: List.generate(fullSubject.associationSubjects.length * 2 - 1, (index) { if (index.isOdd) return Text('•', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B))); return Text(fullSubject.associationSubjects[index ~/ 2].name, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)); })))),
                            ],
                          ),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B).withValues(alpha: .98), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF334155), width: 1.5), boxShadow: const [BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16)]),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), waitDuration: const Duration(milliseconds: 200),
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E5EC))), child: Text(subj.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87))),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoResizeText extends StatelessWidget
{
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final int maxLines;
  final TextStyle style;

  const _AutoResizeText({required this.text, required this.maxFontSize, required this.minFontSize, required this.maxLines, required this.style});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        double currentFontSize = maxFontSize;
        final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: maxLines);
        while (currentFontSize > minFontSize)
        {
          textPainter.text = TextSpan(text: text, style: style.copyWith(fontSize: currentFontSize));
          textPainter.layout(maxWidth: constraints.maxWidth);
          if (!textPainter.didExceedMaxLines) break; 
          currentFontSize -= 1;
        }
        return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style.copyWith(fontSize: currentFontSize));
      }
    );
  }
}