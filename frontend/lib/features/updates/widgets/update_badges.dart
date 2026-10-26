import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_density.dart';
import '../update_item.dart';
import '../update_strings.dart';

const double _roleBadgeHeight = 24;
const double _denseRoleBadgeHeight = 22;

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

// All roles chosen show as one badge.
class UpdateRoleBadges extends StatelessWidget
{
  final List<UpdateRole> roles;
  final WrapAlignment alignment;

  const UpdateRoleBadges({super.key, required this.roles, this.alignment = WrapAlignment.start});

  Widget _badge(String label, {required Color background, required Color color, required bool dense})
  {
    final double height = dense ? _denseRoleBadgeHeight : _roleBadgeHeight;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(height / 2)),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: dense ? 11 : 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    if (roles.length == UpdateRole.values.length)
    {
      return _badge(kUpdateAllRoles, background: const Color(0xFFF4EEF9), color: AppTheme.trialViolet, dense: dense);
    }

    return Wrap(
      alignment: alignment,
      spacing: dense ? 5 : 6,
      runSpacing: dense ? 5 : 6,
      children: [
        for (final role in roles)
          _badge(role.plural, background: AppTheme.todaySurface, color: AppTheme.trialTealDeep, dense: dense),
      ],
    );
  }
}
