import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/profile_photo_image.dart';
import '../../../shared/widgets/app_badged_face.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_section_rail.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../models/person_item.dart';
import '../own_tour.dart';
import 'profile_avatar.dart';
import 'role_chips_row.dart';

const double _identityWidth = 800;
const double _identityAvatar = 96;
const double _identityRadius = 40;

// The line that stands for the card below the wide window.
const double _headingFace = 40;
const double _headingFaceBadge = 18;
const double _afterBack = 14;
const double _afterFace = 10;
const double _beforeRoles = 10;

const double kPersonHeadingNameSize = 18;

const double _roleFont = 11.5;
const double _rolePadding = 9;
const double _roleSpacing = 6;

List<String> _rolesOf(PersonItem person)
{
  return RoleLabelMapper.processRoles(person.shownRoles, feminine: person.gender == 'F');
}

// The face beside a name on that line, without the back button (a parent's child), and the gap after it.
const double kPersonHeadingFace = _headingFace;
const double kPersonHeadingFaceGap = _afterFace;
const double kPersonHeadingFaceBadge = _headingFaceBadge;

Widget personHeadingFace(BuildContext context, PersonItem person, {double size = _headingFace})
{
  return _staticFace(context, person, size);
}

Widget _staticFace(BuildContext context, PersonItem person, double size)
{
  final String initials = '${person.firstName[0]}${person.lastName[0]}'.toUpperCase();

  final Widget fallback = Center(
    child: Text(
      initials,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size / 3,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialTealDeep,
      ),
    ),
  );

  final ProfilePhotoImage? photo = ProfilePhotoImage.of(
    person.profileImageUrl,
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

// Wide window only; below it the page puts a PersonHeading in its section tabs.
class PersonDetailHeader extends StatelessWidget
{
  final PersonItem? person;

  final String imageVersion;

  final String backTooltip;
  final VoidCallback onBack;

  // Non-null makes the avatar editable (own record only).
  final VoidCallback? onFaceChanged;

  const PersonDetailHeader({
    super.key,
    required this.person,
    required this.imageVersion,
    required this.backTooltip,
    required this.onBack,
    this.onFaceChanged,
  });

  Widget _buildAvatar(BuildContext context, PersonItem person)
  {
    if (onFaceChanged case final VoidCallback onChanged)
    {
      // Keyed on the version: a reload after a change fetches the face anew.
      return DesktopTourTarget(
        id: kTourOwnFace,
        child: ProfileAvatar(
          key: ValueKey(imageVersion),
          profileImageUrl: person.profileImageUrl,
          firstName: person.firstName,
          lastName: person.lastName,
          size: _identityAvatar,
          onImageUpdated: onChanged,
        ),
      );
    }

    return _staticFace(context, person, _identityAvatar);
  }

  Widget _buildIdentityCard(BuildContext context, PersonItem person)
  {
    final Widget nameAndRoles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OverflowTooltipText(
          text: '${person.firstName} ${person.lastName}',
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialOcean,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        RoleChipsRow(
          roles: _rolesOf(person),
          fontSize: 13,
          horizontalPadding: 11,
          verticalPadding: 5,
          borderRadius: 20,
          spacing: 8,
          scrollable: true,
        ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _identityWidth),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_identityRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            _buildAvatar(context, person),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: AppSectionRail.width + AppSectionRail.gap,
          child: Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
        ),
        Expanded(child: Center(child: _buildIdentityCard(context, person))),
      ],
    );
  }
}

// What AppSectionTabs needs to put back, face, name and roles on its title line.
class PersonHeading
{
  final PersonItem person;

  final String imageVersion;

  final String backTooltip;
  final VoidCallback onBack;

  // Non-null makes the face editable (own record only).
  final VoidCallback? onFaceChanged;

  const PersonHeading({
    required this.person,
    required this.imageVersion,
    required this.backTooltip,
    required this.onBack,
    this.onFaceChanged,
  });

  String get name => '${person.firstName} ${person.lastName}';

  Size get _faceExtent
  {
    if (onFaceChanged == null)
    {
      return const Size.square(_headingFace);
    }

    return AppBadgedFace.extentOf(
      _headingFace,
      badgeSize: _headingFaceBadge,
      hasImage: ProfilePhotoImage.of(person.profileImageUrl) != null,
    );
  }

  double get leadingWidth => AppBackButton.denseWidth + _afterBack + _faceExtent.width + _afterFace;

  Widget leading(BuildContext context)
  {
    final Widget face = switch (onFaceChanged)
    {
      final VoidCallback onChanged => DesktopTourTarget(
          id: kTourOwnFace,
          child: ProfileAvatar(
            key: ValueKey(imageVersion),
            profileImageUrl: person.profileImageUrl,
            firstName: person.firstName,
            lastName: person.lastName,
            size: _headingFace,
            badgeSize: _headingFaceBadge,
            onImageUpdated: onChanged,
          ),
        ),
      null => _staticFace(context, person, _headingFace),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBackButton(tooltip: backTooltip, onTap: onBack, dense: true),
        const SizedBox(width: _afterBack),
        face,
        const SizedBox(width: _afterFace),
      ],
    );
  }

  // The chips' natural width, as RoleChipsRow lays them out.
  double rolesWidth(BuildContext context)
  {
    final List<String> roles = _rolesOf(person);

    if (roles.isEmpty)
    {
      return 0;
    }

    final TextStyle style = DefaultTextStyle.of(context).style.merge(
      GoogleFonts.plusJakartaSans(fontSize: _roleFont, fontWeight: FontWeight.w700),
    );

    double width = _beforeRoles + (roles.length - 1) * _roleSpacing;

    for (final role in roles)
    {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: role, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();

      width += painter.width + 2 * _rolePadding;
      painter.dispose();
    }

    // Slack against sub-pixel rounding.
    return width + 1;
  }

  Widget roles()
  {
    return Padding(
      padding: const EdgeInsets.only(left: _beforeRoles),
      child: RoleChipsRow(
        roles: _rolesOf(person),
        fontSize: _roleFont,
        horizontalPadding: _rolePadding,
        verticalPadding: 3,
        borderRadius: 12,
        spacing: _roleSpacing,
        applyTextScaler: true,
      ),
    );
  }
}
