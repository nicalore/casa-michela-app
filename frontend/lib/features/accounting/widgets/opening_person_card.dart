import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/layout/dense_text_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/profile_photo_image.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../../shared/widgets/pixel_snap.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../people/widgets/person_card.dart';

// A person of the initial set-up, as the people page draws one: what is on file under the name.
class OpeningPersonCard extends StatefulWidget
{
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String tag;

  // Nothing on file yet: the tag in gold.
  final bool missing;
  final bool confirmed;
  final double width;
  final VoidCallback onTap;

  const OpeningPersonCard({
    super.key,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
    required this.tag,
    required this.missing,
    required this.confirmed,
    required this.width,
    required this.onTap,
  });

  @override
  State<OpeningPersonCard> createState() => _OpeningPersonCardState();
}

class _OpeningPersonCardState extends State<OpeningPersonCard>
{
  bool _hover = false;

  Widget _avatar(bool dense)
  {
    final double size = dense ? PersonCard.denseAvatarSize : PersonCard.avatarSize;
    final String initials = '${widget.firstName.isEmpty ? '' : widget.firstName[0]}'
        '${widget.lastName.isEmpty ? '' : widget.lastName[0]}'.toUpperCase();

    final Widget fallback = Center(
      child: WholeWords(
        child: Text(
          initials,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 16 : 23,
            fontWeight: FontWeight.w700,
            color: AppTheme.trialTealDeep,
          ),
        ),
      ),
    );

    final ProfilePhotoImage? photo = ProfilePhotoImage.of(
      widget.photoUrl,
      cacheWidth: ((size - 4) * MediaQuery.devicePixelRatioOf(context)).round(),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.trialTurquoise.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.trialTurquoise, width: 2),
      ),
      child: PixelSnap(
        child: ClipOval(
          child: photo != null
              ? Image(
                  image: photo,
                  fit: BoxFit.cover,
                  filterQuality: ProfilePhotoImage.filterQuality,
                  errorBuilder: (context, error, stackTrace) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }

  Widget _tag(bool dense)
  {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: widget.missing ? AppTheme.modifiedAccentSurface : AppTheme.trialTurquoise.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.tag,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: widget.missing ? AppTheme.modifiedAccent : AppTheme.trialTealDeep,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: (dense ? PersonCard.denseHeight : PersonCard.height) + largeTextRoom(context, dense ? 33 : 40),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(dense ? 20 : 26),
              border: Border.all(
                color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
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
                  _avatar(dense),
                  SizedBox(width: dense ? 12 : 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OverflowTooltipText(
                          text: '${widget.firstName} ${widget.lastName}',
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: dense ? 15 : 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialOcean,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: dense ? 5 : 7),
                        _tag(dense),
                      ],
                    ),
                  ),
                  if (widget.confirmed) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, size: dense ? 20 : 24, color: AppTheme.trialSeaGreen),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
