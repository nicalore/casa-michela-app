import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/widgets/snackbar.dart'; 
import '../../../shared/widgets/shared_components.dart';

class SubjectCard extends StatefulWidget
{
  final String       discipline;
  final List<String> areas;
  final Function(String oldDiscipline, String newDiscipline, List<String> newAreas, Function(String) onError) onEdit;
  final VoidCallback onDelete;

  const SubjectCard(
  {
    super.key,
    required this.discipline,
    required this.areas,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard>
{
  bool _isHovering = false;

  void _showDetailsDialog(BuildContext context)
  {
    showGeneralDialog(
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'SubjectDetails',
      barrierColor:       Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      transitionBuilder:  (context, animation, secondaryAnimation, child)
      {
        final double blurValue = animation.value * 8.0;
        
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child:  FadeTransition(
            opacity: animation,
            child:   ScaleTransition(
              scale: CurvedAnimation(
                parent:       animation,
                curve:        Curves.easeOutBack,
                reverseCurve: Curves.easeIn,
              ),
              child: _DetailsDialogContent(
                discipline: widget.discipline,
                areas:      widget.areas,
                onEdit:     widget.onEdit,
                onDelete:   widget.onDelete,
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
      cursor:  SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(
        ()
        {
          _isHovering = true;
        });
      },
      onExit: (_)
      {
        setState(
        ()
        {
          _isHovering = false;
        });
      },
      child: GestureDetector(
        onTap: () => _showDetailsDialog(context),
        child: AnimatedContainer(
          duration:   const Duration(milliseconds: 180),
          curve:      Curves.easeOut,
          width:      320,
          height:     110,
          padding:    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(30),
            border:       Border.all(
              color: _isHovering ? const Color(0xFF003C82) : Colors.transparent,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisAlignment:  MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children:           [
              _AutoResizeText(
                text:        widget.discipline,
                maxFontSize: 26,
                minFontSize: 16,
                maxLines:    2,
                style:       GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color:      const Color(0xFF003C82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoResizeText extends StatelessWidget
{
  final String    text;
  final double    maxFontSize;
  final double    minFontSize;
  final int       maxLines;
  final TextStyle style;

  const _AutoResizeText(
  {
    required this.text,
    required this.maxFontSize,
    required this.minFontSize,
    required this.maxLines,
    required this.style,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        double           currentFontSize = maxFontSize;
        final TextScaler textScaler      = MediaQuery.textScalerOf(context);
        
        //Buffer to absorb the ellipsis width and prevent premature truncation
        final double     safeMaxWidth    = constraints.maxWidth - 12.0;
        
        final TextPainter textPainter    = TextPainter(
          textDirection: Directionality.of(context),
          locale:        Localizations.maybeLocaleOf(context),
          maxLines:      maxLines,
          textScaler:    textScaler,
        );

        while (currentFontSize > minFontSize)
        {
          textPainter.text = TextSpan(
            text:  text, 
            style: style.copyWith(fontSize: currentFontSize),
          );
          
          textPainter.layout(maxWidth: safeMaxWidth);
          
          if (!textPainter.didExceedMaxLines && textPainter.width <= safeMaxWidth)
          {
            break; 
          }
          
          currentFontSize -= 1;
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style:    style.copyWith(fontSize: currentFontSize),
        );
      }
    );
  }
}

class _DetailsDialogContent extends StatefulWidget
{
  final String       discipline;
  final List<String> areas;
  final Function(String, String, List<String>, Function(String)) onEdit;
  final VoidCallback onDelete;

  const _DetailsDialogContent(
  {
    required this.discipline,
    required this.areas,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DetailsDialogContent> createState() => _DetailsDialogContentState();
}

class _DetailsDialogContentState extends State<_DetailsDialogContent>
{
  bool                        _isEditingMode        = false;
  late TextEditingController  _disciplineController;
  List<TextEditingController> _areaControllers      = [];

  @override
  void initState()
  {
    super.initState();
    _initControllers();
  }

  void _initControllers()
  {
    _disciplineController = TextEditingController(text: widget.discipline);
    _areaControllers      = widget.areas.map((area) => TextEditingController(text: area)).toList();
  }

  void _disposeControllers()
  {
    _disciplineController.dispose();
    
    for (var controller in _areaControllers)
    {
      controller.dispose();
    }
  }

  @override
  void dispose()
  {
    _disposeControllers();
    super.dispose();
  }

  void _cancelEdit()
  {
    setState(
    ()
    {
      _isEditingMode = false;
      _disposeControllers();
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
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:           Text('Conferma Eliminazione', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
          content:         Text('Sei sicuro di voler eliminare la materia "${widget.discipline}" e tutti i suoi ambiti?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          actions:         [
            TextButton(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: () => Navigator.pop(confirmContext),
              child:     Text('ANNULLA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A8A8A), fontWeight: FontWeight.w600)),
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
              child: Text('ELIMINA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:       0,
      child:           Container(
        width:       540,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration:  BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow:    const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:     [
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
              child:   Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children:          [
                  Text(
                    _isEditingMode ? 'Modifica Materia' : 'Dettagli Materia',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82)),
                  ),
                  FadeHoverIconButton(
                    icon:       Icons.close,
                    color:      const Color(0xFF003C82),
                    hoverColor: const Color(0xFFE3F2FD),
                    onTap:      () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
                child:   SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:           [
                      if (_isEditingMode)
                      ...[
                        Text('Disciplina', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                        TextField(
                          controller: _disciplineController,
                          style:      GoogleFonts.plusJakartaSans(fontSize: 20, color: Colors.black, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        Text('Ambiti (${_areaControllers.length})', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        
                        ...List.generate(_areaControllers.length, (index)
                        {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child:   Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _areaControllers[index],
                                    style:      GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.black),
                                    decoration: const InputDecoration(
                                      hintText:       'Nome ambito',
                                      isDense:        true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      focusedBorder:  UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF003C82), width: 1.5)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FadeHoverIconButton(
                                  icon:       Icons.remove_circle_outline,
                                  color:      const Color(0xFFE53935),
                                  hoverColor: const Color(0xFFFFEBEE),
                                  onTap:      ()
                                  {
                                    setState(
                                    ()
                                    {
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
                          onTap: ()
                          {
                            setState(
                            ()
                            {
                              _areaControllers.add(TextEditingController());
                            });
                          },
                        ),
                      ]
                      else
                      ...[
                        Text('Disciplina', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(widget.discipline, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black)),
                        
                        const SizedBox(height: 32),
                        
                        Text('Ambiti (${widget.areas.length})', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        
                        if (widget.areas.isEmpty)
                          Text('Nessun ambito specificato', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF8A8A8A), fontStyle: FontStyle.italic))
                        else
                          Wrap(
                            spacing:    12,
                            runSpacing: 12,
                            alignment:  WrapAlignment.start,
                            children:   widget.areas.map(
                            (area)
                            {
                              return Container(
                                padding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color:        const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(20),
                                  border:       Border.all(color: const Color(0xFFE0E5EC)),
                                ),
                                child: Text(area, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                              );
                            }).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 24),
              child:   Row(
                children: [
                  Expanded(
                    child: AnimatedActionButton(
                      text:       _isEditingMode ? 'SALVA' : 'MODIFICA',
                      icon:       _isEditingMode ? Icons.save_outlined : Icons.edit_outlined,
                      baseColor:  const Color(0xFF003C82),
                      hoverColor: const Color(0xFF004D99),
                      onPressed:  ()
                      {
                        if (_isEditingMode)
                        {
                          final List<String> newAreas = _areaControllers.map((c) => c.text.trim()).where((text) => text.isNotEmpty).toList();
                          bool               hasError = false;

                          widget.onEdit(
                            widget.discipline,
                            _disciplineController.text.trim(),
                            newAreas,
                            (errorMsg)
                            {
                              hasError = true;
                              CustomSnackBar.show(
                                context: context,
                                message: errorMsg,
                                isError: true,
                              );
                            },
                          );
                          
                          if (!hasError)
                          {
                            Navigator.of(context).pop();
                          }
                        }
                        else
                        {
                          setState(
                          ()
                          {
                            _isEditingMode = true;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedActionButton(
                      text:       _isEditingMode ? 'ANNULLA' : 'ELIMINA',
                      icon:       _isEditingMode ? Icons.cancel_outlined : Icons.delete_outline_rounded,
                      baseColor:  const Color(0xFFE53935),
                      hoverColor: const Color(0xFFEF5350),
                      onPressed:  ()
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

class _AddAreaLinkButton extends StatefulWidget
{
  final VoidCallback onTap;
  
  const _AddAreaLinkButton(
  {
    required this.onTap,
  });

  @override
  State<_AddAreaLinkButton> createState() => _AddAreaLinkButtonState();
}

class _AddAreaLinkButtonState extends State<_AddAreaLinkButton>
{
  bool _isHovered = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor:  SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(
        ()
        {
          _isHovered = true;
        });
      },
      onExit: (_)
      {
        setState(
        ()
        {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment:    Alignment.bottomLeft, 
          clipBehavior: Clip.none,
          children:     [
            Padding(
              padding: const EdgeInsets.only(bottom: 2), 
              child:   Row(
                mainAxisSize: MainAxisSize.min,
                children:     [
                  Icon(
                    Icons.add, 
                    color: _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82), 
                    size:  20,
                  ),
                  const SizedBox(width: 8),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style:    GoogleFonts.plusJakartaSans(
                      color:      _isHovered ? const Color(0xFF002244) : const Color(0xFF003C82),
                      fontWeight: FontWeight.w700,
                      fontSize:   15,
                    ),
                    child: const Text('Aggiungi ambito'),
                  ),
                ],
              ),
            ),
            Positioned(
              left:   0,
              bottom: 0,
              right:  0,
              child:  Row( 
                mainAxisAlignment: MainAxisAlignment.start,
                children:          [
                  Flexible(
                    child: AnimatedFractionallySizedBox(
                      duration:    const Duration(milliseconds: 300),
                      curve:       Curves.easeOutQuint,
                      widthFactor: _isHovered ? 1.0 : 0.0, 
                      alignment:   Alignment.centerLeft,
                      child:       Container(
                        height:     2,
                        decoration: BoxDecoration(
                          color:        const Color(0xFF002244),
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