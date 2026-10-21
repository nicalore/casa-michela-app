import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/profile_photo_image.dart';
import '../../people/models/person_face.dart';

class PersonAvatar extends StatelessWidget
{
  static const double listSize = 42;

  static const double pickerSize = 56;

  static const double titleSize = 76;

  final PersonFace person;

  final double size;

  const PersonAvatar({super.key, required this.person, this.size = listSize});

  @override
  Widget build(BuildContext context)
  {
    final initials = '${person.firstName[0]}${person.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.38,
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
}
