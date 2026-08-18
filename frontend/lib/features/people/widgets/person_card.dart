import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/person_item.dart';
import 'role_chips_row.dart';

const double _nameFontSize = 18;
const double _nameHeightFactor = 1.2;
const double _nameLineHeight = _nameFontSize * _nameHeightFactor;

// Past this a name is not being read any more, it is being decoded.
const int _maxNameLines = 3;

// A person, drawn like the association cards: white, rounded, a gold outline
// under the pointer.
//
// Upright rather than on its side, which gives the name the whole width instead
// of what is left beside the picture, and is narrow enough that four fit on a
// 1440 window with the rail beside them.
class PersonCard extends StatefulWidget
{
  // The narrowest it is ever drawn, and the width the grid falls back to.
  static const double minWidth = 255;

  // Past this a card is more air than person.
  static const double maxWidth = 420;

  // Room for a name on two lines over two rows of roles, or three over one.
  // The worst case added up: below it, something has to give.
  static const double height = 230;

  // Kept at its size: it is the first thing looked at on a person's card, and
  // shrinking it to make the card fit is shrinking what the card exists for.
  static const double avatarSize = 84;

  final PersonItem person;
  final VoidCallback onTap;

  // Handed down by the grid, which shares the row between four of them.
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

  Widget _buildAvatar()
  {
    final String initials =
        '${widget.person.firstName[0]}${widget.person.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    String? imageUrl = widget.person.profileImageUrl?.trim();

    // Relative paths are stored without host, so prefix the backend base URL.
    if (imageUrl != null && imageUrl.startsWith('/'))
    {
      imageUrl = ApiConfig.buildUrl(imageUrl);
    }

    return Container(
      width: PersonCard.avatarSize,
      height: PersonCard.avatarSize,
      decoration: BoxDecoration(
        // The turquoise laid on white until it is barely a colour, the same
        // ground the entity chips and the roles in the settings stand on.
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace)
                {
                  debugPrint('Errore caricamento immagine per ${widget.person.firstName}: $error');
                  return fallback;
                },
              )
            : fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> processedRoles = RoleLabelMapper.processRoles(widget.person.roles);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.width,
          height: PersonCard.height,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            // Gold under the pointer, the same mark a module card takes on the
            // dashboard and a school card in the association.
            border: Border.all(
              color: _isHovering
                  ? AppTheme.trialGold
                  : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 10),
              // The name stands in the middle of the room between the picture
              // and the roles, which pins the roles to the foot of every card.
              //
              // How many lines it may take is worked out from that room and not
              // fixed: fixed at two, a card whose roles took a second row had
              // space for one and a half and sliced the name through the
              // middle.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints)
                  {
                    final fitting = (constraints.maxHeight / _nameLineHeight).floor();

                    return Center(
                      child: OverflowTooltipText(
                        text: '${widget.person.firstName} ${widget.person.lastName}',
                        maxLines: fitting.clamp(1, _maxNameLines),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: _nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.trialOcean,
                          height: _nameHeightFactor,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Two rows: a row holds two chips and a person here is commonly
              // three things. Green, like every chip that names something a
              // thing is tied to, and one size smaller than they were — which
              // fits one more per row before the overflow counter.
              RoleChipsRow(
                roles: processedRoles,
                centered: true,
                maxLines: 2,
                fontSize: 12,
                horizontalPadding: 10,
                verticalPadding: 4,
                borderRadius: 20,
                // Measured through the reader's own text scale as well, and
                // with a couple of pixels kept back for rounding.
                applyTextScaler: true,
                safetyMargin: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
