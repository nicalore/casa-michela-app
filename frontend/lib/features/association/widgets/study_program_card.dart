import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/study_program_item.dart';
import '../../../shared/widgets/snackbar.dart';
//Shared components
import '../../../shared/widgets/shared_components.dart';

class StudyProgramCard extends StatefulWidget 
{
  final StudyProgramItem program;
  final Function(int id, String name, String description, Function(String) onError) onEdit;
  final VoidCallback onDelete;

  const StudyProgramCard({
    super.key,
    required this.program,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<StudyProgramCard> createState() => _StudyProgramCardState();
}

class _StudyProgramCardState extends State<StudyProgramCard> 
{
  bool _isHovering = false;

  void _showDetailsDialog(BuildContext context) 
  {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'StudyProgramDetails',
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
              scale: CurvedAnimation(
                parent: animation, 
                curve: Curves.easeOutBack, 
                reverseCurve: Curves.easeIn,
              ),
              child: _StudyProgramDetailsDialogContent(
                program: widget.program,
                onEdit: widget.onEdit,
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
          height: 114,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent, 
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000), 
                offset: Offset(0, 4), 
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoResizeText(
                text: widget.program.name,
                maxFontSize: 24,
                minFontSize: 16,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, 
                  color: const Color(0xFF003C82), 
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.program.description.isEmpty ? '' : widget.program.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, 
                  fontWeight: FontWeight.w500, 
                  color: widget.program.description.isEmpty ? const Color(0xFFB3B3B3) : const Color(0xFF8A8A8A),
                  fontStyle: widget.program.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyProgramDetailsDialogContent extends StatefulWidget 
{
  final StudyProgramItem program;
  final Function(int, String, String, Function(String)) onEdit;
  final VoidCallback onDelete;

  const _StudyProgramDetailsDialogContent({
    required this.program, 
    required this.onEdit, 
    required this.onDelete,
  });

  @override
  State<_StudyProgramDetailsDialogContent> createState() => _StudyProgramDetailsDialogContentState();
}

class _StudyProgramDetailsDialogContentState extends State<_StudyProgramDetailsDialogContent> 
{
  bool _isEditingMode = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() 
  {
    super.initState();
    _initControllers();
  }

  void _initControllers() 
  {
    _nameController = TextEditingController(text: widget.program.name);
    _descController = TextEditingController(text: widget.program.description);
  }

  @override
  void dispose() 
  {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _cancelEdit() 
  {
    setState(() 
    {
      _isEditingMode = false;
      _initControllers();
    });
  }

  void _showDeleteConfirmation(BuildContext context) 
  {
    showDialog(
      context: context,
      builder: (BuildContext confirmContext) 
      {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Conferma Eliminazione', 
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, 
              color: const Color(0xFF003C82),
            ),
          ),
          content: Text(
            'Sei sicuro di voler eliminare l\'indirizzo "${widget.program.name}"?', 
            style: GoogleFonts.plusJakartaSans(fontSize: 16),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: () => Navigator.pop(confirmContext),
              child: Text(
                'ANNULLA', 
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF8A8A8A), 
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: () 
              {
                Navigator.pop(confirmContext);
                Navigator.pop(context);
                widget.onDelete();
              },
              child: Text(
                'ELIMINA', 
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFE53935), 
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldLabel(String text) 
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 16),
      child: Text(
        text, 
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF003C82), 
          fontWeight: FontWeight.w700, 
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000), 
              offset: Offset(0, 8), 
              blurRadius: 24,
            ),
          ],
        ),
        //Stretch items to align content properly
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
                    _isEditingMode ? 'Modifica Indirizzo' : 'Dettagli Indirizzo', 
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, 
                      fontWeight: FontWeight.w700, 
                      color: const Color(0xFF003C82),
                    ),
                  ),
                  StaticHoverIconButton(
                    icon: Icons.close, 
                    color: const Color(0xFF003C82), 
                    hoverColor: const Color(0xFFE3F2FD), 
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(
              height: 32, 
              thickness: 1, 
              color: Color(0xFFF0F0F0),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
              child: _isEditingMode 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Nome Indirizzo di Studio'),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, 
                          color: Colors.black, 
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003C82), 
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      _buildFieldLabel('Descrizione (Opzionale)'),
                      TextField(
                        controller: _descController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, 
                          color: Colors.black, 
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Aggiungi una descrizione...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 16, 
                            color: const Color(0xFFB3B3B3),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF003C82), 
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Nome'),
                      Text(
                        widget.program.name, 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, 
                          fontWeight: FontWeight.w600, 
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Descrizione'),
                      Text(
                        widget.program.description.isEmpty ? 'Nessuna descrizione fornita.' : widget.program.description, 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16, 
                          fontWeight: FontWeight.w500, 
                          height: 1.4,
                          color: widget.program.description.isEmpty ? const Color(0xFFB3B3B3) : Colors.black87,
                          fontStyle: widget.program.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
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
                      text: _isEditingMode ? 'SALVA' : 'MODIFICA',
                      icon: _isEditingMode ? Icons.save_outlined : Icons.edit_outlined,
                      baseColor: const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed: () 
                      {
                        if (_isEditingMode) 
                        {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) 
                          {
                            CustomSnackBar.show(
                              context: context, 
                              message: 'Il nome non può essere vuoto.', 
                              isError: true,
                            );
                            return;
                          }
                          widget.onEdit(widget.program.id, name, _descController.text.trim(), (errorMsg) 
                          {
                            CustomSnackBar.show(
                              context: context, 
                              message: errorMsg, 
                              isError: true,
                            );
                          });
                          Navigator.of(context).pop();
                        } 
                        else 
                        {
                          setState(() => _isEditingMode = true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text: _isEditingMode ? 'ANNULLA' : 'ELIMINA',
                      icon: _isEditingMode ? Icons.cancel_outlined : Icons.delete_outline_rounded,
                      baseColor: const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed: () 
                      {
                        if (_isEditingMode) 
                        {
                          _cancelEdit();
                        } 
                        else 
                        {
                          _showDeleteConfirmation(context);
                        }
                      },
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