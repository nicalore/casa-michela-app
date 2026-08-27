import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../people/models/person_face.dart';

// A person's photo, or their initials when there is none.
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

    String? imageUrl = person.profileImageUrl?.trim();

    // Images are stored without a host: relative paths need prefixing.
    if (imageUrl != null && imageUrl.startsWith('/'))
    {
      imageUrl = ApiConfig.buildUrl(imageUrl);
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
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }
}
