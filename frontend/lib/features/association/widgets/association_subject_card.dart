import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/association_subject_item.dart';
import '../../../shared/widgets/shared_components.dart';

class AssociationSubjectCard extends StatefulWidget
{
  final AssociationSubjectItem subject;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const AssociationSubjectCard
  ({
    super.key,
    required this.subject,
    required this.onEditRequested,
    required this.onDelete,
  });

  @override
  State<AssociationSubjectCard> createState() => _AssociationSubjectCardState();
}

class _AssociationSubjectCardState extends State<AssociationSubjectCard>
{
  bool _isHovering = false;

  String _translateArea(String area)
  {
    switch (area)
    {
      case 'HUMANITIES':  return 'Area Umanistica';
      case 'LINGUISTICS': return 'Area Linguistica';
      case 'SCIENCES':    return 'Area Scientifica';
      default:            return area;
    }
  }

  void _showDetailsDialog(BuildContext context)
  {
    //StableReferenceToTheCardsOwnContext_MustSurviveTheDialogsOpenCloseCycle
    //DoNotLetThisGetShadowedByTransitionBuildersOwnContextParamBelow
    final BuildContext cardContext = context;

    showGeneralDialog
    (
      context:            cardContext,
      barrierDismissible: true,
      barrierLabel:       'AssociationSubjectDetails',
      barrierColor:       Colors.black.withValues(alpha: .15),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder:        (animation, secondaryAnimation, child) => const SizedBox.shrink(),
      //RenamedFrom"context"ToAvoidShadowingTheOuterCardContext_ThisIsTheDialogsOwnContext
      //ItBecomesInvalidAssoonAsThisSpecificDialogIsPopped_NeverStoreItInALongLivedClosure
      transitionBuilder:  (dialogContext, animation, secondaryAnimation, child)
      {
        final blurValue = animation.value * 8.0;
        return BackdropFilter
        (
          filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
          child: FadeTransition
          (
            opacity: animation,
            child: ScaleTransition
            (
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
              child: _AssociationSubjectDetailsDialogContent
              (
                subject:         widget.subject,
                areaItalian:     _translateArea(widget.subject.area),
                onEditRequested: ()
                {
                  //PopsTheCurrentDialogUsingItsOwnStillValidContext
                  Navigator.of(dialogContext).pop();
                  //ButHandsTheReopenCallbackTheCard'sStableContext_NotTheSoonToBeDefunctDialogOne
                  widget.onEditRequested(() => _showDetailsDialog(cardContext));
                },
                onDelete:        widget.onDelete,
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
    return MouseRegion
    (
      cursor:  SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit:  (_) => setState(() => _isHovering = false),
      child: GestureDetector
      (
        onTap: () => _showDetailsDialog(context),
        child: AnimatedContainer
        (
          duration:   const Duration(milliseconds: 180),
          curve:      Curves.easeOut,
          width:      360,
          height:     140,
          padding:    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          decoration: BoxDecoration
          (
            color:        Colors.white,
            borderRadius: BorderRadius.circular(30),
            border:       Border.all(color: _isHovering ? const Color(0xFF003C82) : Colors.transparent, width: 2),
            boxShadow:    const [BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 16)],
          ),
          child: Column
          (
            mainAxisAlignment:  MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [
              _CardOverflowTooltipText
              (
                text:  widget.subject.name,
                style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: const Color(0xFF003C82), height: 1.15),
              ),
              const SizedBox(height: 6),
              Text
              (
                _translateArea(widget.subject.area), 
                maxLines:   1, 
                overflow:   TextOverflow.ellipsis,
                style:      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF8A8A8A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssociationSubjectDetailsDialogContent extends StatelessWidget
{
  final AssociationSubjectItem subject;
  final String                 areaItalian;
  final VoidCallback           onEditRequested;
  final VoidCallback           onDelete;

  const _AssociationSubjectDetailsDialogContent
  ({
    required this.subject, 
    required this.areaItalian, 
    required this.onEditRequested, 
    required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showDialog
    (
      context: context,
      builder: (BuildContext confirmContext)
      {
        return AlertDialog
        (
          backgroundColor: Colors.white, 
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:           Text('Conferma Eliminazione', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
          content:         Text('Sei sicuro di voler eliminare la disciplina "${subject.name}"?', style: GoogleFonts.plusJakartaSans(fontSize: 16)),
          actions: 
          [
            TextButton
            (
              style:     ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () => Navigator.pop(confirmContext),
              child:     Text('ANNULLA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8A8A8A), fontWeight: FontWeight.w600)),
            ),
            TextButton
            (
              style:     ButtonStyle(overlayColor: WidgetStateProperty.all(Colors.transparent)),
              onPressed: () 
              { 
                Navigator.pop(confirmContext); 
                Navigator.pop(context); 
                onDelete(); 
              },
              child:     Text('ELIMINA', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFieldLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 20), child: Text(text, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF003C82), fontWeight: FontWeight.w700, fontSize: 16)));

  @override
  Widget build(BuildContext context)
  {
    final bool hasDescription = subject.description != null && subject.description!.isNotEmpty;
    return Dialog
    (
      backgroundColor: Colors.transparent, 
      elevation:       0,
      child: SelectionArea
      (
        child: Container
        (
          width:       600, 
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration:  BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24)]),
          child: Column
          (
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              Padding
              (
                padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
                child:   Row
                (
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: 
                  [
                    Text('Dettagli Disciplina Interna', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF003C82))),
                    StaticHoverIconButton(icon: Icons.close, color: const Color(0xFF003C82), hoverColor: const Color(0xFFE3F2FD), onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              const Divider(height: 32, thickness: 1, color: Color(0xFFF0F0F0)),
              Flexible
              (
                child: SingleChildScrollView
                (
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16),
                  child:   Column
                  (
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: 
                    [
                      _buildFieldLabel('Nome'),
                      Text(subject.name, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black)),
                      _buildFieldLabel('Area'),
                      Text(areaItalian, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
                      _buildFieldLabel('Descrizione'),
                      Text(hasDescription ? subject.description! : 'Nessuna descrizione fornita.', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4, color: hasDescription ? Colors.black87 : const Color(0xFFB3B3B3), fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              SelectionContainer.disabled
              (
                child: Padding
                (
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 32, top: 16),
                  child:   Row
                  (
                    children: 
                    [
                      Expanded(child: AnimatedActionButton(text: 'MODIFICA', icon: Icons.edit_outlined, baseColor: const Color(0xFF003C82), hoverColor: const Color(0xFF004D99), onPressed: onEditRequested)),
                      const SizedBox(width: 16),
                      Expanded(child: AnimatedActionButton(text: 'ELIMINA', icon: Icons.delete_outline_rounded, baseColor: const Color(0xFFE53935), hoverColor: const Color(0xFFEF5350), onPressed: () => _showDeleteConfirmation(context))),
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

class _CardOverflowTooltipText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;

  const _CardOverflowTooltipText({
    required this.text,
    required this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        )..layout(maxWidth: constraints.maxWidth);

        final Widget textWidget = Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

        if (!painter.didExceedMaxLines) return textWidget;

        return Tooltip(
          message: text,
          waitDuration: const Duration(milliseconds: 600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: .98),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x4A000000), offset: Offset(0, 6), blurRadius: 16),
            ],
          ),
          child: textWidget,
        );
      },
    );
  }
}