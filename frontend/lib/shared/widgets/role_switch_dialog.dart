import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_dialog_stack.dart';
import 'dialog_components.dart';

const double _stackMaxWidth = 560;

const double _rowHeight = 58;
const double _rowRadius = 16;
const double _rowGap = 10;

const Duration _hoverFade = Duration(milliseconds: 150);

// Keyed by the Italian labels from RoleLabelMapper, not backend role codes:
// a renamed label silently falls back to the default icon.
const Map<String, IconData> _roleIcons = <String, IconData>{
  'AMMINISTRATORE': Icons.computer_outlined,
  'DOCENTE': Icons.school_outlined,
  'PSICOLOGO': Icons.psychology_outlined,
  'STUDENTE': Icons.menu_book_outlined,
  'CORSISTA': Icons.self_improvement_rounded,
  'GENITORE': Icons.family_restroom_outlined,
};

IconData _roleIcon(String role) => _roleIcons[role.toUpperCase()] ?? Icons.badge_outlined;

Future<void> showRoleSwitchDialog({
  required BuildContext context,
  required String activeRole,
  required List<String> availableRoles,
})
{
  return showBlurredDialog<void>(
    context: context,
    barrierLabel: 'CambiaRuolo',
    builder: (context) => _RoleSwitchDialog(
      activeRole: activeRole,
      availableRoles: availableRoles,
    ),
  );
}

class _RoleSwitchDialog extends StatelessWidget
{
  final String activeRole;
  final List<String> availableRoles;

  const _RoleSwitchDialog({
    required this.activeRole,
    required this.availableRoles,
  });

  @override
  Widget build(BuildContext context)
  {
    final roles = availableRoles.where((role) => role != activeRole).toList();

    return AppDialogStack(
      eyebrow: 'Sei autenticato come',
      title: activeRole,
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
                  label: roles[i],
                  // Inert for now: the pages the other roles would land on do not exist yet.
                  onTap: () {},
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleRow extends StatefulWidget
{
  final String label;
  final VoidCallback onTap;

  const _RoleRow({
    required this.label,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _hoverFade,
          curve: Curves.easeOut,
          height: _rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_rowRadius),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(_roleIcon(widget.label), size: 20, color: AppTheme.trialTealDeep),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialOcean,
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

