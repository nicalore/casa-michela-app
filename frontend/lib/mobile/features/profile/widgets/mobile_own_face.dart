import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/models/me_response.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_sheet.dart';

enum MobilePhotoAction { gallery, camera, remove }

class MobileOwnFace extends StatelessWidget
{
  final MeResponse user;
  final double size;
  final bool busy;
  final VoidCallback onTap;

  const MobileOwnFace({
    super.key,
    required this.user,
    required this.size,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context)
  {
    final double badge = (size * 0.46).roundToDouble();

    return Semantics(
      button: true,
      label: 'Foto profilo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MobileAvatar(
                firstName: user.firstName,
                lastName: user.lastName,
                imageUrl: user.profileImageUrl,
                size: size,
              ),
              if (busy)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.trialGold, Color(0xFFF3C766)],
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x47000000), offset: Offset(0, 4), blurRadius: 10),
                    ],
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: (badge * 0.52).roundToDouble(),
                    color: AppTheme.trialDeepWater,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<MobilePhotoAction?> showMobilePhotoSheet({
  required BuildContext context,
  required MeResponse user,
})
{
  final bool hasImage = (user.profileImageUrl?.trim() ?? '').isNotEmpty;

  return showMobileSheet<MobilePhotoAction>(
    context: context,
    builder: (context) => MobileSheet(
      eyebrow: 'Foto profilo',
      title: user.fullName,
      body: [
        const SizedBox(height: 22),
        Center(
          child: MobileAvatar(
            firstName: user.firstName,
            lastName: user.lastName,
            imageUrl: user.profileImageUrl,
            size: 104,
          ),
        ),
        const SizedBox(height: 28),
        _ActionRow(
          icon: Icons.photo_library_rounded,
          label: 'Scegli dalla galleria',
          onTap: () => Navigator.of(context).pop(MobilePhotoAction.gallery),
        ),
        const SizedBox(height: 10),
        _ActionRow(
          icon: Icons.photo_camera_rounded,
          label: 'Scatta una foto',
          onTap: () => Navigator.of(context).pop(MobilePhotoAction.camera),
        ),
        if (hasImage) ...[
          const SizedBox(height: 10),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: 'Rimuovi la foto',
            danger: true,
            onTap: () => Navigator.of(context).pop(MobilePhotoAction.remove),
          ),
        ],
        const SizedBox(height: 4),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget
{
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final Color tint = danger ? AppTheme.trialDanger : AppTheme.trialTealDeep;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x0F122438), offset: Offset(0, 4), blurRadius: 14),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 23, color: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: danger ? AppTheme.trialDanger : AppTheme.trialInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
