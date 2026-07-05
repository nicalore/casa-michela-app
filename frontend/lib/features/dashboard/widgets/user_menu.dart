import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

const double _leadingSpace = 14;

//Returns the specific icon based on the user's role
IconData _getRoleIcon(String role)
{
  switch (role.toUpperCase())
  {
    case 'DOCENTE':
      return Icons.school_outlined;
    case 'STUDENTE':
      return Icons.menu_book_outlined;
    case 'AMMINISTRATORE':
      return Icons.computer_outlined;
    case 'PSICOLOGO':
      return Icons.psychology_outlined;
    case 'CORSISTA':
      return Icons.self_improvement_rounded;
    case 'GENITORE':
      return Icons.family_restroom_outlined;
    default:
      return Icons.badge_outlined;
  }
}

class UserMenu extends StatefulWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final ValueChanged<String> onRoleSelected;
  final VoidCallback onLogout;

  const UserMenu({
    super.key,
    required this.activeRole,
    required this.availableRoles,
    required this.onRoleSelected,
    required this.onLogout,
  });

  @override
  State<UserMenu> createState() => _UserMenuState();
}

class _UserMenuState extends State<UserMenu>
{
  bool _rolesExpanded = false;

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleSection(
              activeRole: widget.activeRole,
              availableRoles: widget.availableRoles,
              expanded: _rolesExpanded,
              onToggle: ()
              {
                if (widget.availableRoles.length > 1)
                {
                  setState(()
                  {
                    _rolesExpanded = !_rolesExpanded;
                  });
                }
              },
              onRoleSelected: widget.onRoleSelected,
            ),
            const Divider(height: 1),
            _HoverMenuItem(
              icon: Icons.settings_outlined,
              text: 'Impostazioni',
              color: const Color(0xFF003C82),
              onTap: ()
              {
                context.go('/settings');
              },
            ),
            _HoverMenuItem(
              icon: Icons.logout_rounded,
              text: 'Logout',
              color: const Color(0xFFC62828),
              onTap: widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSection extends StatelessWidget
{
  final String activeRole;
  final List<String> availableRoles;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onRoleSelected;

  const _RoleSection({
    required this.activeRole,
    required this.availableRoles,
    required this.expanded,
    required this.onToggle,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context)
  {
    final canExpand = availableRoles.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                const SizedBox(width: _leadingSpace),
                SizedBox(
                  width: 18,
                  child: Icon(
                    _getRoleIcon(activeRole),
                    size: 18,
                    color: const Color(0xFF003C82),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeRole,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF003C82),
                    ),
                  ),
                ),
                if (canExpand)
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF003C82),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: expanded
              ? Column(
                  children: availableRoles
                      .where((role) => role != activeRole)
                      .map((role)
                      {
                        return _HoverMenuItem(
                          icon: _getRoleIcon(role),
                          text: role,
                          color: const Color(0xFF003C82),
                          onTap: ()
                          {
                            onRoleSelected(role);
                          },
                        );
                      })
                      .toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// Voce di menù con hover: mostra una barretta laterale animata senza
// spostare icona e testo (nessuno shift orizzontale durante l'hover).
class _HoverMenuItem extends StatefulWidget
{
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _HoverMenuItem({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_)
      {
        setState(()
        {
          _hover = true;
        });
      },
      onExit: (_)
      {
        setState(()
        {
          _hover = false;
        });
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Barretta di hover: posizionata sotto la Row, non ne
              // influenza la larghezza né la posizione degli elementi.
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 2,
                height: _hover ? 20 : 0,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: _leadingSpace),
                  SizedBox(
                    width: 18,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}