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

// The height and type size every dialog of the app gives its buttons.
const double _dialogButtonHeight = 52;
const double _dialogButtonFontSize = 14;

// Narrow: a question of one sentence, and the two answers under it.
const double _confirmWidth = 480;

// Written the way every other hour of the app is written: twenty-four hour,
// with the dash the association's opening bands use.
String _timeRangeLabel(AvailabilityItem availability)
{
  return formatTimeRange(availability.startTime, availability.endTime);
}

class AvailabilityCard extends StatefulWidget
{
  // Room for a name over three lines of hours. A day can hold more than three
  // stretches — a band can be answered several times over — so the column
  // counts what it cannot show rather than making the card grow.
  static const double height = 172;

  // One teacher on one day, with every stretch of hours they gave for it.
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
    final group = widget.group;
    final presence = group.slotsFor(kPresenceMode);
    final online = group.slotsFor(kOnlineMode);

    // Both ways stand side by side, each with its own hours under it; one way
    // alone has nothing to be compared against, so it takes the middle instead
    // of leaving an empty half.
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
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a person takes in the anagrafiche.
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
              // Centred in the room the name leaves rather than hung from the
              // top of it: the card is the same height whatever the day holds,
              // and a day with one stretch on it would otherwise be a line of
              // hours with a hole underneath. The name stays where it is, so
              // the names of a row still line up.
              Expanded(
                child: Center(
                  child: bothWays
                      // Sized to the taller of the two columns, which is what
                      // gives the line between them something to be as tall as.
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

// One way of being there, with the hours given for it stacked underneath.
class _ModeColumn extends StatelessWidget
{
  // What the card is tall enough to hold. A band can now be answered with more
  // than one stretch, so a day has no ceiling of three — but the card does, and
  // it is the same height whatever is on it.
  static const int maxLines = 3;

  final String mode;
  final List<AvailabilityItem> slots;

  const _ModeColumn({required this.mode, required this.slots});

  @override
  Widget build(BuildContext context)
  {
    final online = mode == kOnlineMode;
    final accent = online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep;

    // Past what fits, the last line counts what it is standing in front of
    // rather than letting the column run off the bottom of the card. The window
    // that opens off it has all of them.
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
            // Brought down to the column rather than cut short by it: the hours
            // are eleven characters whatever happens, and a column narrowed by a
            // phone must still show all eleven.
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
            // The ones left off, in full: the count says how many there are,
            // and the pointer says which.
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

// One stretch of hours, in the window that opens off the card.
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

  // Two full buttons rather than two words in a corner: this one throws a whole
  // day's availability away, and the answer that does it should not be quieter
  // than the one that walks away from it.
  void _showDeleteConfirmation(BuildContext context)
  {
    showBlurredDialog<void>(
      context: context,
      barrierLabel: 'ConfirmAvailabilityDeletion',
      builder: (confirmContext) => AppDialogStack(
        eyebrow: 'Eliminazione',
        title: 'Confermi?',
        // ANNULLA is already the way out of this one.
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
                        : ', con tutte e ${group.slots.length} le sue fasce orarie.',
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

  // Small, tracked and muted over the value it names: the same pairing the
  // settings cards use, and the same the top bar uses over a role.
  Widget _buildFieldLabel(String text, {bool first = false})
  {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: first ? 0 : 20),
      child: AppFieldLabel(text),
    );
  }

  // The two ways of being there are two blocks of the same shape, one under the
  // other: what names them is an eyebrow and not a field's label.
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
      // Who they are, before when they are there: the day and the stretches
      // below belong to somebody, and the face is recognised before the surname
      // is read.
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
          // Selection stops at the body: the buttons underneath are not text
          // you would ever want to drag a cursor through.
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
        // Both ways of being there on the one window, each with the stretches
        // given for it. A way that was not given says so rather than being
        // left out: its absence is an answer too.
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
                    'Nessuna fascia oraria.',
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
