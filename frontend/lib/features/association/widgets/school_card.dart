import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/ministry_subject_chip.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../models/ministry_subject_item.dart';
import '../models/school_item.dart';
import '../models/study_program_item.dart';
import '../models/subject_taxonomy.dart';

const Color _chipBackground = Color(0xFFF5F7FA);
const Color _chipHover = AppTheme.slate200;

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

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SchoolDetails',
      builder: (dialogContext) => _SchoolDetailsDialogContent(
        school: widget.school,
        availableStudyPrograms: widget.availableStudyPrograms,
        availableMinistrySubjects: widget.availableMinistrySubjects,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          // The reopen callback reuses the card state, not the dialog context
          // that is about to become invalid.
          widget.onEditRequested(_showDetailsDialog);
        },
        onDelete: widget.onDelete,
      ),
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
        onTap: _showDetailsDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 360,
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OverflowTooltipText(
                text: widget.school.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.school.city} (${widget.school.province})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText,
                ),
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
    required this.school,
    required this.availableStudyPrograms,
    required this.availableMinistrySubjects,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showDialog(
      context: context,
      builder: (confirmContext)
      {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Conferma Eliminazione',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          content: Text(
            'Sei sicuro di voler eliminare la scuola "${school.name}"?',
            style: GoogleFonts.plusJakartaSans(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(confirmContext),
              child: Text(
                'ANNULLA',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              style: ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: ()
              {
                Navigator.pop(confirmContext);
                Navigator.pop(context);
                onDelete();
              },
              child: Text(
                'ELIMINA',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // The program id carried by a SchoolStudyProgramOption is resolved against
  // the full StudyProgramItem list loaded elsewhere, so the read only dialog
  // can show ministry subjects and years that the option does not carry.
  void _openReadOnlyProgramDialog(BuildContext context, int programId)
  {
    final fullProgram = availableStudyPrograms.firstWhere(
      (program) => program.id == programId,
      orElse: () => throw Exception('Percorso non trovato nei dati caricati'),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ReadOnlyProgramDetails',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child)
      {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
            child: Align(
              alignment: const Alignment(0.5, 0.0),
              child: _ReadOnlyStudyProgramDialogContent(
                program: fullProgram,
                availableMinistrySubjects: availableMinistrySubjects,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final hasCode = school.mechanographicCode != null && school.mechanographicCode!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dettagli Scuola',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    StaticHoverIconButton(
                      icon: Icons.close,
                      color: AppTheme.primary,
                      hoverColor: AppTheme.iconHover,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32, thickness: 1, color: AppTheme.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Nome'),
                      Text(
                        school.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Città'),
                                Text(
                                  school.city,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
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
                                Text(
                                  school.province,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _buildFieldLabel('Codice Meccanografico'),
                      Text(
                        hasCode ? school.mechanographicCode! : 'Non presente',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: hasCode ? Colors.black : AppTheme.mutedText,
                          fontStyle: hasCode ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Percorsi di Studio Attivi'),
                      if (school.studyPrograms.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Nessun percorso associato a questa scuola.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: AppTheme.mutedText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: school.studyPrograms.map((program)
                            {
                              return _HoverableProgramChip(
                                name: program.name,
                                onTap: () => _openReadOnlyProgramDialog(context, program.id),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SelectionContainer.disabled(
                child: Padding(
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedActionButton(
                          text: 'ELIMINA',
                          icon: Icons.delete_outline_rounded,
                          baseColor: AppTheme.danger,
                          hoverColor: AppTheme.dangerHover,
                          onPressed: () => _showDeleteConfirmation(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AnimatedActionButton(
                          text: 'MODIFICA',
                          icon: Icons.edit_outlined,
                          baseColor: AppTheme.primary,
                          hoverColor: AppTheme.primaryHover,
                          onPressed: onEditRequested,
                        ),
                      ),
                    ],
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
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovering ? _chipHover : _chipBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            widget.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyStudyProgramDialogContent extends StatelessWidget
{
  final StudyProgramItem program;
  final List<MinistrySubjectItem> availableMinistrySubjects;

  const _ReadOnlyStudyProgramDialogContent({
    required this.program,
    required this.availableMinistrySubjects,
  });

  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 20),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final hasDescription = program.description.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Color(0x2A000000), offset: Offset(0, 12), blurRadius: 36),
          ],
        ),
        child: SelectionArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dettagli Percorso',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    StaticHoverIconButton(
                      icon: Icons.close,
                      color: AppTheme.primary,
                      hoverColor: AppTheme.iconHover,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32, thickness: 1, color: AppTheme.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Nome'),
                      Text(
                        program.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Livello'),
                                Text(
                                  schoolLevelLabel(program.level),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Anni di corso'),
                                Text(
                                  '${program.minYear} - ${program.maxYear}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _buildFieldLabel('Descrizione'),
                      Text(
                        hasDescription ? program.description : 'Nessuna descrizione fornita.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: hasDescription ? Colors.black87 : AppTheme.hint,
                          fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Materie ministeriali incluse'),
                      if (program.ministrySubjects.isEmpty)
                        Text(
                          'Nessuna materia associata.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: AppTheme.mutedText,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: program.ministrySubjects.map((option)
                        {
                          return MinistrySubjectChip(
                            option: option,
                            availableMinistrySubjects: availableMinistrySubjects,
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
      ),
    );
  }
}