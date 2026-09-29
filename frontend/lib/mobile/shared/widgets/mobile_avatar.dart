import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import 'mobile_load_switcher.dart';

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

    // Cache buster: an uploaded photo keeps its URL.
    if (url != null && url.isNotEmpty)
    {
      url = '$url?v=${ApiService().profileImageVersion}';
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
                // Twice the width keeps landscape photos up to 2:1 sharp when covering the circle.
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context) * 2).round(),
                frameBuilder: (context, photo, frame, synchronous) => synchronous
                    ? photo
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          fallback,
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 1, end: frame == null ? 1 : 0),
                            duration: kMobileRiseDuration,
                            curve: Curves.easeOutCubic,
                            builder: (context, shift, photo) => FractionalTranslation(
                              translation: Offset(0, shift),
                              child: photo,
                            ),
                            child: photo,
                          ),
                        ],
                      ),
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }
}
