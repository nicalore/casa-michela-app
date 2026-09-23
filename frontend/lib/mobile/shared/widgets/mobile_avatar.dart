import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';

// Profile picture, or initials, in the gold ring of the brand mark.
class MobileAvatar extends StatelessWidget
{
  final String firstName;
  final String lastName;
  final String? imageUrl;

  final double size;

  const MobileAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    this.imageUrl,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context)
  {
    final String initials = [
      if (firstName.isNotEmpty) firstName[0],
      if (lastName.isNotEmpty) lastName[0],
    ].join().toUpperCase();

    String? url = imageUrl?.trim();

    // Images are stored without a host: relative paths need prefixing.
    if (url != null && url.startsWith('/'))
    {
      url = ApiConfig.buildUrl(url);
    }

    final Widget fallback = Center(
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppTheme.trialDeepWater,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Nearly opaque, or the halo underneath tints the initials.
        color: Colors.white.withValues(alpha: 0.9),
        boxShadow: [
          const BoxShadow(color: Color(0x4D000000), offset: Offset(0, 8), blurRadius: 18),
          BoxShadow(color: AppTheme.trialGold.withValues(alpha: 0.16), spreadRadius: 7),
          BoxShadow(color: AppTheme.trialGold.withValues(alpha: 0.85), spreadRadius: 2.5),
        ],
      ),
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }
}
