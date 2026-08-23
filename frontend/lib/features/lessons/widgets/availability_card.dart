import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../models/availability_group.dart';
import '../models/availability_item.dart';
import '../utils/booking_window.dart';
import '../utils/opening_window.dart';
import 'person_avatar.dart';

const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

const double _confirmWidth = 480;

String _timeRangeLabel(AvailabilityItem availability)
{
  return formatTimeRange(availability.startTime, availability.endTime);
}

class AvailabilityCard extends StatefulWidget
{
  static const double height = 172;

  final AvailabilityGroup group;

  final void Function(VoidCallback onCancel) onEditRequested;
  final VoidCallback onDelete;

  const AvailabilityCard({
    super.key,
    required this.group,
    required this.onEditRequested,
    required this.onDelete,
  });

  @override
  State<AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends State<AvailabilityCard>
{
  bool _isHovering = false;

  void _showDetailsDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'AvailabilityDetails',
      builder: (dialogContext) => _AvailabilityDetailsDialogContent(
        group: widget.group,
        onEditRequested: ()
        {
          Navigator.of(dialogContext).pop();
          widget.onEditRequested(_showDetailsDialog);
        },
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final group = widget.group;
    final presence = group.slotsFor(kPresenceMode);
    final online = group.slotsFor(kOnlineMode);

    final bothWays = presence.isNotEmpty && online.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _showDetailsDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: EntityCardGrid.preferredWidth,
          height: AvailabilityCard.height,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverflowTooltipText(
                text: group.teacher.fullName,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppTheme.trialOcean,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: bothWays
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _ModeColumn(mode: kPresenceMode, slots: presence)),
                              Container(
                                width: 1,
                                margin: const EdgeInsets.symmetric(horizontal: 14),
                                color: AppTheme.trialLine,
                              ),
                              Expanded(child: _ModeColumn(mode: kOnlineMode, slots: online)),
                            ],
                          ),
                        )
                      : _ModeColumn(
                          mode: presence.isNotEmpty ? kPresenceMode : kOnlineMode,
                          slots: presence.isNotEmpty ? presence : online,
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

class _ModeColumn extends StatelessWidget
{
  static const int maxLines = 3;

  final String mode;
  final List<AvailabilityItem> slots;

  const _ModeColumn({required this.mode, required this.slots});

  @override
  Widget build(BuildContext context)
  {
    final online = mode == kOnlineMode;
    final accent = online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    final fits = slots.length <= maxLines;
    final shown = fits ? slots : slots.take(maxLines - 1).toList();
    final hidden = fits ? const <AvailabilityItem>[] : slots.sublist(maxLines - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              online ? Icons.videocam_outlined : Icons.home_work_outlined,
              size: 15,
              color: AppTheme.trialMutedText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                modeLabel(mode).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (final slot in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _timeRangeLabel(slot),
                maxLines: 1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
        if (hidden.isNotEmpty)
          Tooltip(
            message: hidden.map(_timeRangeLabel).join('\n'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hidden.length == 1 ? '+1 orario' : '+${hidden.length} orari',
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.trialMutedText,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeSlotLabel extends StatelessWidget
{
  final String label;

  const _TimeSlotLabel({required this.label});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }
}

class _AvailabilityDetailsDialogContent extends StatelessWidget
{
  final AvailabilityGroup group;
  final VoidCallback onEditRequested;
  final VoidCallback onDelete;

  const _AvailabilityDetailsDialogContent({
    required this.group,
    required this.onEditRequested,
    required this.onDelete,
  });

  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmAvailabilityDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        showClose: false,
        maxWidth: _confirmWidth,
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
        children: [
          AppDialogPill(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'La disponibilità di '),
                  TextSpan(
                    text: group.teacher.fullName,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' di ${formatAvailableDayLabel(group.date).toLowerCase()} verrà eliminata definitivamente'),
                  TextSpan(
                    text: group.slots.length == 1
                        ? '.'
                        : ', con tutti e ${group.slots.length} i suoi orari.',
                  ),
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
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  Widget _buildModeLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppEyebrow(text),
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
    return AppDialogStack(
      eyebrow: 'Disponibilità',
      title: group.teacher.fullName,
      leading: PersonAvatar(person: group.teacher, size: PersonAvatar.titleSize),
      maxWidth: 560,
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
      children: [
        AppDialogPill(
          expand: true,
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('Giornata', first: true),
                Text(formatAvailableDayLabel(group.date), style: _valueStyle),
              ],
            ),
          ),
        ),
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final mode in const [kPresenceMode, kOnlineMode]) ...[
                _buildModeLabel(modeLabel(mode), first: mode == kPresenceMode),
                if (group.slotsFor(mode).isEmpty)
                  Text(
                    'Nessun orario.',
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
                      children: [
                        for (final slot in group.slotsFor(mode))
                          _TimeSlotLabel(label: _timeRangeLabel(slot)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
