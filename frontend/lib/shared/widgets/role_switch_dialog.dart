import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../routing/app_router.dart';
import 'app_dialog_stack.dart';
import 'dialog_components.dart';

const double _stackMaxWidth = 560;

const double _rowHeight = 58;
const double _rowRadius = 16;
const double _rowGap = 10;

const Duration _hoverFade = Duration(milliseconds: 150);

// Keyed by the backend role codes, the same values the switch is made of.
const Map<String, IconData> _roleIcons = <String, IconData>{
  'ADMIN': Icons.computer_outlined,
  'TEACHER': Icons.school_outlined,
  'PSYCHOLOGIST': Icons.psychology_outlined,
  'STUDENT': Icons.menu_book_outlined,
  'COURSE_PARTICIPANT': Icons.self_improvement_rounded,
  'PARENT': Icons.family_restroom_outlined,
};

IconData _roleIcon(String role) => _roleIcons[role] ?? Icons.badge_outlined;

Future<void> showRoleSwitchDialog({
  required BuildContext context,
  required String activeRole,
  required List<String> availableRoles,
  required ValueChanged<String> onSelected,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'CambiaRuolo',
    builder: (context) => _RoleSwitchDialog(
      activeRole: activeRole,
      availableRoles: availableRoles,
      onSelected: onSelected,
    ),
  );
}

class _RoleSwitchDialog extends StatelessWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final ValueChanged<String> onSelected;

  const _RoleSwitchDialog({
    required this.activeRole,
    required this.availableRoles,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context)
  {
    final roles = availableRoles.where((role) => role != activeRole).toList();

    return AppDialogStack(
      eyebrow: 'Sei autenticato come',
      title: RoleLabelMapper.toLabel(activeRole),
      maxWidth: _stackMaxWidth,
      children: [
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < roles.length; i++) ...[
                if (i > 0) const SizedBox(height: _rowGap),
                _RoleRow(
                  role: roles[i],
                  onTap: () => _select(context, roles[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _select(BuildContext context, String role)
  {
    Navigator.of(context).pop();
    onSelected(role);
  }
}

class _RoleRow extends StatefulWidget
{
  final String role;
  final VoidCallback onTap;

  const _RoleRow({
    required this.role,
    required this.onTap,
  });

  @override
  State<_RoleRow> createState() => _RoleRowState();
}

class _RoleRowState extends State<_RoleRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    // A role whose area does not exist yet is shown but not offered, rather than hidden.
    if (!canSwitchTo(widget.role))
    {
      return Tooltip(
        message: 'In arrivo',
        child: _buildRow(
          border: AppTheme.trialLine,
          foreground: AppTheme.trialMutedText,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: _buildRow(
          border: _hover ? AppTheme.trialGold : AppTheme.trialLine,
          foreground: AppTheme.trialOcean,
          iconColor: AppTheme.trialTealDeep,
        ),
      ),
    );
  }

  Widget _buildRow({
    required Color border,
    required Color foreground,
    Color? iconColor,
  })
  {
    return AnimatedContainer(
      duration: _hoverFade,
      curve: Curves.easeOut,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_rowRadius),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(_roleIcon(widget.role), size: 20, color: iconColor ?? foreground),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              RoleLabelMapper.toLabel(widget.role),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
