import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_section_rail.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/person_item.dart';
import 'profile_avatar.dart';
import 'role_chips_row.dart';

const double _identityWidth = 800;
const double _identityAvatar = 96;
const double _compactIdentityAvatar = 72;
const double _identityRadius = 40;
const double _compactIdentityRadius = 32;

class PersonDetailHeader extends StatelessWidget
{
  final PersonItem? person;

  final String imageVersion;

  final AppWindowSize size;

  final String backTooltip;
  final VoidCallback onBack;

  // Non-null makes the avatar editable (own record only).
  final VoidCallback? onFaceChanged;

  const PersonDetailHeader({
    super.key,
    required this.person,
    required this.imageVersion,
    required this.size,
    required this.backTooltip,
    required this.onBack,
    this.onFaceChanged,
  });

  Widget _buildAvatar(BuildContext context, PersonItem person, bool compact)
  {
    final double size = compact ? _compactIdentityAvatar : _identityAvatar;

    if (onFaceChanged case final VoidCallback onChanged)
    {
      // Keyed on the version: a reload after a change fetches the face anew.
      return ProfileAvatar(
        key: ValueKey(imageVersion),
        profileImageUrl: person.profileImageUrl,
        firstName: person.firstName,
        lastName: person.lastName,
        size: size,
        onImageUpdated: onChanged,
      );
    }

    final String initials = '${person.firstName[0]}${person.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: compact ? 24 : 32,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    String? imageUrl = person.profileImageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty)
    {
      if (imageUrl.startsWith('/'))
      {
        imageUrl = ApiConfig.buildUrl(imageUrl);
      }

      imageUrl = '$imageUrl?v=$imageVersion';
    }

    return Container(
      width: size,
      height: size,
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
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildIdentityCard(BuildContext context, PersonItem person, bool compact)
  {
    final List<String> roles = RoleLabelMapper.processRoles(person.roles);

    final Widget nameAndRoles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        OverflowTooltipText(
          text: '${person.firstName} ${person.lastName}',
          maxLines: 1,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.plusJakartaSans(
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialOcean,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        RoleChipsRow(
          roles: roles,
          fontSize: 13,
          horizontalPadding: 11,
          verticalPadding: 5,
          borderRadius: 20,
          spacing: 8,
          scrollable: true,
          centered: compact,
        ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _identityWidth),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 24 : 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? _compactIdentityRadius : _identityRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatar(context, person, true),
                  const SizedBox(height: 16),
                  nameAndRoles,
                ],
              )
            : Row(
                children: [
                  _buildAvatar(context, person, false),
                  const SizedBox(width: 28),
                  Expanded(child: nameAndRoles),
                ],
              ),
      ),
    );
  }

  Widget _buildBackButton()
  {
    return AppBackButton(tooltip: backTooltip, onTap: onBack);
  }

  @override
  Widget build(BuildContext context)
  {
    final PersonItem? person = this.person;

    if (person == null)
    {
      return Align(alignment: Alignment.centerLeft, child: _buildBackButton());
    }

    if (size.isCompact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 16),
          _buildIdentityCard(context, person, true),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: AppSectionRail.width + AppSectionRail.gap,
          child: Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
        ),
        Expanded(child: Center(child: _buildIdentityCard(context, person, false))),
      ],
    );
  }
}
