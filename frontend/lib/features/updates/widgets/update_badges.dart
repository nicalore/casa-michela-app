import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../update_item.dart';
import '../update_strings.dart';

const double _roleBadgeHeight = 24;

// The version in the greeting's gradient: what an update is filed under.
class UpdateVersionBadge extends StatelessWidget
{
  final String version;
  final double height;
  final double fontSize;

  const UpdateVersionBadge(this.version, {super.key, this.height = 24, this.fontSize = 12.5});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        gradient: AppTheme.greetingGradient,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          updateVersionLabel(version),
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

// As the notices' role badges; every role chosen reads as one badge.
class UpdateRoleBadges extends StatelessWidget
{
  final List<UpdateRole> roles;
  final WrapAlignment alignment;

  const UpdateRoleBadges({super.key, required this.roles, this.alignment = WrapAlignment.start});

  Widget _badge(String label, {required Color background, required Color color})
  {
    return Container(
      height: _roleBadgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(_roleBadgeHeight / 2)),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (roles.length == UpdateRole.values.length)
    {
      return _badge(kUpdateAllRoles, background: const Color(0xFFF4EEF9), color: AppTheme.trialViolet);
    }

    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final role in roles) _badge(role.plural, background: AppTheme.todaySurface, color: AppTheme.trialTealDeep),
      ],
    );
  }
}
