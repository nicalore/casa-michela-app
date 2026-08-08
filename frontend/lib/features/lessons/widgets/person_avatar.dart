import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../people/models/person_face.dart';

// A person's face next to their name, as on the person cards: the photo where
// there is one, the initials where there is not.
//
// Large enough to recognise who it is: in person pickers the face is often the
// real handle — whoever books remembers the teacher's face before the surname —
// and the rows grow to hold it rather than squeezing it.
class PersonAvatar extends StatelessWidget
{
  // The size for inside a scrolling list.
  static const double listSize = 42;

  // The one for the list where the face is what is being looked for.
  static const double pickerSize = 56;

  // The one next to a detail dialog's title, where the face sits beside a name
  // set large and is the first thing looked at: taller than the two lines
  // alongside it, so the circle is the person being read about and not a button
  // resting next to them.
  static const double titleSize = 76;

  // Anyone with a name and — perhaps — a photo: the full person record and the
  // minimal one travelling with an availability or a request are drawn the same
  // way.
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
          // Le iniziali crescono con il cerchio, o in un cerchio grande
          // galleggiano in mezzo al vuoto.
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );

    String? imageUrl = person.profileImageUrl?.trim();

    // The images are stored without a host: the relative path needs prefixing.
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
