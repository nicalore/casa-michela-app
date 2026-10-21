import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/profile_photo_image.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/person_item.dart';
import 'role_chips_row.dart';

const double _nameFontSize = 18;
const double _nameHeightFactor = 1.2;

const double _denseNameFontSize = 15;

const int _maxNameLines = 2;

const int _maxRoleChips = 2;

class PersonCard extends StatefulWidget
{
  // Leaves room beside the portrait for two role chips and the counter.
  static const double minWidth = 325;

  static const double maxWidth = 420;

  static const double height = 102;

  static const double avatarSize = 68;

  static const double denseHeight = 68;

  static const double denseAvatarSize = 44;

  final PersonItem person;
  final VoidCallback onTap;

  final double width;

  const PersonCard({
    super.key,
    required this.person,
    required this.onTap,
    this.width = minWidth,
  });

  @override
  State<PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<PersonCard>
{
  bool _isHovering = false;

  Widget _buildAvatar(bool dense)
  {
    final double size = dense ? PersonCard.denseAvatarSize : PersonCard.avatarSize;

    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 16 : 23,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    final ProfilePhotoImage? photo = ProfilePhotoImage.of(
      widget.person.profileImageUrl,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      child: ClipOval(
        child: photo != null
            ? Image(
                image: photo,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> processedRoles = RoleLabelMapper.processRoles(
      widget.person.shownRoles,
      feminine: widget.person.gender == 'F',
    );

    final bool dense = AppBreakpoints.of(context).isDense;
    final double nameFontSize = dense ? _denseNameFontSize : _nameFontSize;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: dense ? PersonCard.denseHeight : PersonCard.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dense ? 20 : 26),
              border: Border.all(
                color: _isHovering
                    ? AppTheme.trialGold
                    : AppTheme.trialGold.withValues(alpha: 0),
                width: 2,
              ),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Padding(
              padding: dense
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  _buildAvatar(dense),
                  SizedBox(width: dense ? 12 : 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lines fit the room left: scaled-up text drops a line instead of being sliced.
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints)
                            {
                              final lineHeight = MediaQuery.textScalerOf(context).scale(nameFontSize * _nameHeightFactor);
                              final fitting = (constraints.maxHeight / lineHeight).floor();

                              return OverflowTooltipText(
                                text: '${widget.person.firstName} ${widget.person.lastName}',
                                maxLines: fitting.clamp(1, _maxNameLines),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: nameFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.trialOcean,
                                  height: _nameHeightFactor,
                                ),
                              );
                            },
                          ),
                        ),
                        if (processedRoles.isNotEmpty) ...[
                          SizedBox(height: dense ? 5 : 7),
                          RoleChipsRow(
                            roles: processedRoles,
                            maxChips: _maxRoleChips,
                            fontSize: dense ? 11 : 12,
                            horizontalPadding: dense ? 8 : 10,
                            verticalPadding: dense ? 3 : 4,
                            borderRadius: 20,
                            applyTextScaler: true,
                            safetyMargin: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
