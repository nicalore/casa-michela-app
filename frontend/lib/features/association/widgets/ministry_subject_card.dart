import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_dialog_shell.dart';
import '../../../shared/widgets/app_entity_chip.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/ministry_subject_item.dart';
import '../models/subject_taxonomy.dart';

const Color _levelTextColor = AppTheme.trialTealDeep;

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

  List<String> get _areaLabels => widget.subject.areas.map(subjectAreaLabel).toList();

  String get _areasLabel => _areaLabels.join(', ');

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'MinistrySubjectDetails',
      builder: (dialogContext) => _MinistrySubjectDetailsDialogContent(
        subject: widget.subject,
        levelLabel: _levelLabel,
        areaLabels: _areaLabels,
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
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a document row in the settings.
            border: Border.all(
              color: _isHovering ? AppTheme.trialGold : Colors.transparent,
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
                  color: AppTheme.trialOcean,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              OverflowTooltipText(
                text: _levelLabel,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _levelTextColor,
                ),
              ),
              const SizedBox(height: 2),
              OverflowTooltipText(
                text: _areasLabel,
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.trialMutedText,
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
  // The height and type size every dialog of the app gives its buttons.
  static const double _dialogButtonHeight = 52;
  static const double _dialogButtonFontSize = 14;

  final MinistrySubjectItem subject;
  final String levelLabel;
  final List<String> areaLabels;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _MinistrySubjectDetailsDialogContent({
    required this.subject,
    required this.levelLabel,
    required this.areaLabels,
    required this.onEditRequested,
    required this.onDelete,
  });

  // Two full buttons rather than two words in a corner: this one throws
  // something away, and the answer that does it should not be quieter than the
  // one that walks away from it.
  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmDeletion',
      builder: (confirmContext) => AppDialogShell(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        width: 460,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label: 'ANNULLA',
            icon: Icons.close_rounded,
            gradient: AppTheme.dismissGradient,
            accent: AppTheme.trialViolet,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: () => Navigator.pop(confirmContext),
          ),
          primary: AppGradientButton(
            label: 'ELIMINA',
            icon: Icons.delete_outline_rounded,
            gradient: AppTheme.dangerGradient,
            accent: AppTheme.trialDanger,
            height: _dialogButtonHeight,
            fontSize: _dialogButtonFontSize,
            onPressed: ()
            {
              Navigator.pop(confirmContext);
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'La materia '),
                TextSpan(
                  text: subject.name,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' verrà eliminata definitivamente.'),
              ],
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialInk,
            ),
          ),
        ),
      ),
    );
  }

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  Widget _buildFieldLabel(String text)
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 20),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.trialMutedText,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  TextStyle get _valueStyle => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialInk,
      );

  @override
  Widget build(BuildContext context)
  {
    final hasDescription = subject.description != null && subject.description!.isNotEmpty;

    return AppDialogShell(
      eyebrow: 'Materia ministeriale',
      title: subject.name,
      // Wider than the other detail windows: the name of a level and a list of
      // areas stand side by side in here, and neither of them is short.
      width: 660,
      maxHeight: MediaQuery.of(context).size.height * 0.85,
      footer: AppDialogFooter(
        secondary: AppGradientButton(
          label: 'ELIMINA',
          icon: Icons.delete_outline_rounded,
          gradient: AppTheme.dangerGradient,
          accent: AppTheme.trialDanger,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: () => _showDeleteConfirmation(context),
        ),
        primary: AppGradientButton(
          label: 'MODIFICA',
          icon: Icons.edit_outlined,
          height: _dialogButtonHeight,
          fontSize: _dialogButtonFontSize,
          onPressed: onEditRequested,
        ),
      ),
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A fixed column rather than a share of the dialog: half of it
                  // is not enough for "Scuola Secondaria di II Grado" (254px at
                  // this size) and a level broken over two lines reads as two
                  // levels. Wide enough that the longest of the three still has
                  // room to spare, and the same width whichever level this is,
                  // so the areas start where they always start instead of
                  // sliding left and right from one subject to the next.
                  SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Livello'),
                        Text(
                          levelLabel,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: _valueStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel(areaLabels.length == 1 ? 'Area' : 'Aree'),
                        // One per line: they are separate things, and a comma
                        // between two of them looked like one long area.
                        for (int i = 0; i < areaLabels.length; i++)
                          Padding(
                            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                            child: Text(areaLabels[i], style: _valueStyle),
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
                  color: hasDescription ? AppTheme.trialInk : AppTheme.trialMutedText,
                  fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                ),
              ),
              _buildFieldLabel('Discipline interne associate'),
              if (subject.associationSubjects.isEmpty)
                Text(
                  'Nessuna disciplina associata.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.trialMutedText,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: subject.associationSubjects.map((discipline)
                    {
                      return AppEntityChip(label: discipline.name);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
