import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/shared_components.dart';
import '../models/ministry_subject_item.dart';
import '../models/subject_taxonomy.dart';

const Color _levelTextColor = AppTheme.slate500;
const Color _chipBackground = Color(0xFFF5F7FA);

class MinistrySubjectCard extends StatefulWidget
{
  final MinistrySubjectItem subject;
  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const MinistrySubjectCard({
    super.key,
    required this.subject,
    required this.onEditRequested,
    required this.onDelete,
  });

  @override
  State<MinistrySubjectCard> createState() => _MinistrySubjectCardState();
}

class _MinistrySubjectCardState extends State<MinistrySubjectCard>
{
  bool _isHovering = false;

  String get _levelLabel => schoolLevelLabel(widget.subject.level);

  String get _areasLabel => widget.subject.areas.map(subjectAreaLabel).join(', ');

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MinistrySubjectDetails',
      builder: (dialogContext) => _MinistrySubjectDetailsDialogContent(
        subject: widget.subject,
        levelLabel: _levelLabel,
        areasLabel: _areasLabel,
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
                text: widget.subject.name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _levelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _levelTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _areasLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
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

class _MinistrySubjectDetailsDialogContent extends StatelessWidget
{
  final MinistrySubjectItem subject;
  final String levelLabel;
  final String areasLabel;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _MinistrySubjectDetailsDialogContent({
    required this.subject,
    required this.levelLabel,
    required this.areasLabel,
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
            'Sei sicuro di voler eliminare la materia "${subject.name}"?',
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
    final hasDescription = subject.description != null && subject.description!.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SelectionArea(
        child: Container(
          width: 600,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: AppTheme.dialogShadow,
          ),
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
                      'Dettagli Materia',
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
                        subject.name,
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
                                  levelLabel,
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
                                _buildFieldLabel('Area'),
                                Text(
                                  areasLabel,
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
                        hasDescription ? subject.description! : 'Nessuna descrizione fornita.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: hasDescription ? Colors.black87 : AppTheme.hint,
                          fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Discipline interne associate'),
                      if (subject.associationSubjects.isEmpty)
                        Text(
                          'Nessuna disciplina associata.',
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
                          children: subject.associationSubjects.map((discipline)
                          {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _chipBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                discipline.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
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