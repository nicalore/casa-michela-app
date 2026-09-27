import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../models/person_face.dart';
import 'role_chips_row.dart';

const double _cardRadius = 36;
const double _avatarSize = 128;
const double _factGap = 12;
const double _sectionGap = 20;

String ageLabel(int age) => age == 1 ? '1 anno' : '$age anni';

class RelativeFact
{
  final IconData icon;
  final String text;

  final bool isWarning;

  const RelativeFact(this.icon, this.text, {this.isWarning = false});
}

// A parent or a child shown from the other's record; the whole card opens theirs.
class RelativeCard extends StatefulWidget
{
  static const double minWidth = 320;
  static const double maxWidth = 400;

  final PersonFace person;
  final List<String> roles;
  final List<RelativeFact> facts;

  // Null hides the pickup band: it only concerns minors.
  final bool? authorizedPickup;
  final String? pickupRestrictionReason;

  final VoidCallback onTap;

  const RelativeCard({
    super.key,
    required this.person,
    required this.roles,
    required this.facts,
    required this.onTap,
    this.authorizedPickup,
    this.pickupRestrictionReason,
  });

  @override
  State<RelativeCard> createState() => _RelativeCardState();
}

class _RelativeCardState extends State<RelativeCard>
{
  bool _hover = false;

  Widget _buildRoles()
  {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialTealDeep,
    );

    // A plain Wrap, not RoleChipsRow: its LayoutBuilder cannot sit inside the
    // grid's IntrinsicHeight.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final role in RoleLabelMapper.processRoles(widget.roles))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleChipBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(role, style: style),
          ),
      ],
    );
  }

  Widget _buildFact(RelativeFact fact)
  {
    // Two lines before the ellipsis: three cards to a row leave little room.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          fact.icon,
          size: 21,
          color: fact.isWarning ? AppTheme.trialDanger : AppTheme.trialTealDeep,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OverflowTooltipText(
            text: fact.text,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: fact.isWarning ? AppTheme.trialDanger : AppTheme.trialInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickupPill(bool authorized)
  {
    final Color color = authorized ? AppTheme.trialTealDeep : AppTheme.trialDanger;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: authorized
            ? AppTheme.trialTurquoise.withValues(alpha: 0.12)
            : AppTheme.trialDanger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            authorized ? Icons.check_circle_rounded : Icons.block_rounded,
            size: 19,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            authorized ? 'Ritiro autorizzato' : 'Ritiro non autorizzato',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickup(bool authorized)
  {
    final String? reason = widget.pickupRestrictionReason?.trim();
    final bool showsReason = !authorized && reason != null && reason.isNotEmpty;

    final labelStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppTheme.trialMutedText,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.trialLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPickupPill(authorized),
          if (showsReason) ...[
            const SizedBox(height: 6),
            OverflowTooltipText(
              text: 'Motivo: $reason',
              maxLines: 2,
              style: labelStyle,
              textSpan: TextSpan(
                text: 'Motivo: ',
                style: labelStyle,
                children: [
                  TextSpan(
                    text: reason,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.trialInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool? authorizedPickup = widget.authorizedPickup;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              PersonAvatar(person: widget.person, size: _avatarSize),
              const SizedBox(height: 16),
              OverflowTooltipText(
                text: '${widget.person.firstName} ${widget.person.lastName}',
                maxLines: 2,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialOcean,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              _buildRoles(),
              if (widget.facts.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: _sectionGap),
                  child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
                ),
                for (var i = 0; i < widget.facts.length; i++) ...[
                  if (i > 0) const SizedBox(height: _factGap),
                  _buildFact(widget.facts[i]),
                ],
              ],
              // Pinned to the bottom, so the bands of a row line up.
              if (authorizedPickup != null) ...[
                const SizedBox(height: _sectionGap),
                const Spacer(),
                _buildPickup(authorizedPickup),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Cards in rows of equal height, as many per row as fit and centred.
class RelativeCardGrid extends StatelessWidget
{
  static const double _gap = 24;

  final List<Widget> cards;

  const RelativeCardGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double available = constraints.maxWidth;
        final int perRow = math.max(1, ((available + _gap) / (RelativeCard.minWidth + _gap)).floor());
        final double width =
            math.min(RelativeCard.maxWidth, (available - _gap * (perRow - 1)) / perRow);

        return Column(
          children: [
            for (var start = 0; start < cards.length; start += perRow) ...[
              if (start > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = start; i < math.min(start + perRow, cards.length); i++) ...[
                      if (i > start) const SizedBox(width: _gap),
                      SizedBox(width: width, child: cards[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
