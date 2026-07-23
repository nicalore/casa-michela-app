import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/person_item.dart';
import 'role_chips_row.dart';

class PersonCard extends StatefulWidget
{
  final PersonItem person;
  final VoidCallback onTap;

  const PersonCard({super.key, required this.person, required this.onTap});

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

    final Widget fallbackWidget = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate500,
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
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.slate200,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 2.5),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace)
                {
                  debugPrint('Errore caricamento immagine per ${widget.person.firstName}: $error');
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<String> processedRoles = RoleLabelMapper.processRoles(widget.person.roles);
    final String fullName = '${widget.person.firstName} ${widget.person.lastName}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 420,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovering ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OverflowTooltipText(
                      text: fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RoleChipsRow(roles: processedRoles),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
