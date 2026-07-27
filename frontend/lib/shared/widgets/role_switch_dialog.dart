import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'app_gradient_button.dart';
import 'dialog_components.dart';
import 'shared_components.dart';

const double _dialogWidth = 500;
const double _dialogRadius = 30;
const double _rowHeight = 58;
const double _rowRadius = 16;
const double _rowGap = 10;
const double _cancelButtonHeight = 52;

// Past this the list scrolls instead of growing the dialog. Six roles is
// already more than anyone holds, so in practice it never bites.
const double _maxListHeight = 320;

const Duration _hoverFade = Duration(milliseconds: 150);

// Keyed by the Italian labels produced by RoleLabelMapper, not by the backend
// role codes: renaming a label there silently falls back to the default icon.
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: _dialogWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_dialogRadius),
          boxShadow: AppTheme.dialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 32, thickness: 1, color: AppTheme.trialLine),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: _maxListHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Only what you can move to. The role you are wearing
                        // is already the title of this dialog, and listing it
                        // again would offer you the one choice that changes
                        // nothing.
                        for (final role in availableRoles.where((role) => role != activeRole))
                          Padding(
                            padding: const EdgeInsets.only(bottom: _rowGap),
                            child: _RoleRow(
                              label: role,
                              // Selecting a role is inert for now: the pages
                              // the other roles would land on do not exist yet,
                              // so switching would leave you looking at an
                              // interface that is not yours.
                              onTap: () {},
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 22, bottom: 32),
              child: AppGradientButton(
                label: 'ANNULLA',
                icon: Icons.close_rounded,
                gradient: AppTheme.dismissGradient,
                accent: AppTheme.trialViolet,
                width: double.infinity,
                height: _cancelButtonHeight,
                fontSize: 14,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The same small tracked label the header bar uses over a name,
                // so the dialog reads as an extension of the block you clicked
                // to get here rather than as a window from another screen.
                Text(
                  'SEI AUTENTICATO COME',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    height: 1.2,
                    color: AppTheme.trialMutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeRole,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ],
            ),
          ),
          FadeHoverIconButton(
            icon: Icons.close,
            color: AppTheme.trialTealDeep,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
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

