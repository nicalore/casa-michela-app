import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/role_switch_dialog.dart';
import 'mobile_glass_panel.dart';
import 'mobile_pill.dart';
import 'mobile_sheet.dart';

const double _grabberWidth = 38;
const double _grabberHeight = 5;

const double _rowHeight = 58;
const double _rowRadius = 16;
const double _rowGap = 10;

// Stays open, the chosen row spinning, until onChoose completes: the new
// role's area is then ready to come in as the sheet closes.
Future<void> showMobileRoleSheet({
  required BuildContext context,
  required String activeRole,
  required List<String> availableRoles,
  required Future<void> Function(String role) onChoose,
})
{
  return showMobileSheet<void>(
    context: context,
    builder: (context) => _RoleSheet(
      activeRole: activeRole,
      availableRoles: availableRoles,
      onChoose: onChoose,
    ),
  );
}

class _RoleSheet extends StatefulWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final Future<void> Function(String role) onChoose;

  const _RoleSheet({required this.activeRole, required this.availableRoles, required this.onChoose});

  @override
  State<_RoleSheet> createState() => _RoleSheetState();
}

class _RoleSheetState extends State<_RoleSheet>
{
  String? _choosing;

  Future<void> _choose(String role) async
  {
    if (_choosing != null)
    {
      return;
    }

    setState(() => _choosing = role);
    await widget.onChoose(role);

    if (mounted)
    {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final String activeRole = widget.activeRole;
    final List<String> roles = widget.availableRoles.where((role) => role != activeRole).toList();
    final double bottom = MediaQuery.paddingOf(context).bottom + 24;

    return MobileGlassPanel.sheet(
      padding: EdgeInsets.fromLTRB(24, 14, 24, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: _grabberWidth,
              height: _grabberHeight,
              decoration: BoxDecoration(
                color: AppTheme.trialOcean.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(_grabberHeight / 2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sei autenticato come'.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.9,
              color: AppTheme.trialTealDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            RoleLabelMapper.toLabel(activeRole),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.25,
              color: AppTheme.trialInk,
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(height: _rowGap),
            _RoleRow(
              role: roles[i],
              choosing: roles[i] == _choosing,
              onTap: _choosing == null ? () => _choose(roles[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleRow extends StatelessWidget
{
  final String role;
  final bool choosing;
  final VoidCallback? onTap;

  const _RoleRow({required this.role, required this.choosing, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    // Roles without a mobile area yet are shown but not offered.
    final bool offered = canSwitchTo(role);
    final Color foreground = offered ? AppTheme.trialInk : AppTheme.trialInk.withValues(alpha: 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: offered ? onTap : null,
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: offered ? 0.55 : 0.3),
          borderRadius: BorderRadius.circular(_rowRadius),
          border: Border.all(color: AppTheme.trialOcean.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Icon(
              roleIconFor(role),
              size: 24,
              color: offered ? AppTheme.trialTealDeep : AppTheme.trialTealDeep.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                RoleLabelMapper.toLabel(role),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
            if (!offered) const MobilePill('In arrivo', tone: MobilePillTone.teal),
            if (choosing)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.trialTealDeep),
              ),
          ],
        ),
      ),
    );
  }
}
