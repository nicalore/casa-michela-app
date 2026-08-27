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

const int _maxNameLines = 3;

class PersonCard extends StatefulWidget
{
  static const double minWidth = 255;

  static const double maxWidth = 420;

  static const double height = 230;

  static const double avatarSize = 84;

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
              // Line count computed from the room left: fixed at two, a second
              // roles row sliced the name through the middle.
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
              RoleChipsRow(
                roles: processedRoles,
                centered: true,
                maxLines: 2,
                fontSize: 12,
                horizontalPadding: 10,
                verticalPadding: 4,
                borderRadius: 20,
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
