import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../routing/app_router.dart' show ownPageSlug;
import '../../../routing/role_sections.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_check_mark.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/desktop_tour.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../utils/settings_strings.dart';

const String _home = 'home';
const String _homeLabel = 'Home';

const String _settings = 'settings';

// The own page has a tour for teachers alone so far.
const Set<String> _rolesWithOwnTour = {'TEACHER', 'PARENT', 'STUDENT', 'PSYCHOLOGIST'};

const double _hintGap = 18;
const double _maxWidth = 640;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
const double _pillGap = 26;
const double _rowGap = 8;
const Duration _fade = Duration(milliseconds: 160);

TextStyle _hintStyle() => GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: AppTheme.trialMutedText,
    );

// Every bar section with a tour across the person's roles, the home first, then in bar order; the own page, under the
// first name as in the menu, and the settings last.
List<RoleSection> desktopTourSectionsOf(MeResponse user)
{
  final bool toured = user.availableRoles.any(kDesktopTourRoles.contains);

  final Map<String, RoleSection> sections = {
    if (toured) _home: const RoleSection(_home, _homeLabel, available: true),
  };

  for (final String role in user.availableRoles)
  {
    for (final RoleSection section in sectionsFor(role, hasParentalResponsibility: user.hasParentalResponsibility))
    {
      if (section.available && (kDesktopTourSections[role]?.contains(section.slug) ?? false))
      {
        sections.putIfAbsent(section.slug, () => section);
      }
    }
  }

  if (user.availableRoles.any(_rolesWithOwnTour.contains))
  {
    sections[ownPageSlug] = RoleSection(ownPageSlug, user.firstName, available: true);
  }

  if (toured)
  {
    sections[_settings] = const RoleSection(_settings, kSettingsTitle, available: true);
  }

  return sections.values.toList();
}

// Absent for whoever has no tours, as the administrator.
class TutorialCard extends StatelessWidget
{
  const TutorialCard({super.key});

  static bool shownFor(MeResponse? user) => user != null && desktopTourSectionsOf(user).isNotEmpty;

  @override
  Widget build(BuildContext context)
  {
    final MeResponse? user = ApiService().lastKnownIdentity;

    if (user == null)
    {
      return const SizedBox.shrink();
    }

    return AppCard(
      title: kTutorialTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.school_rounded, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kTutorialSubtitle, style: _hintStyle()),
          const SizedBox(height: _hintGap),
          SizedBox(
            width: double.infinity,
            child: Center(
              child: AppGradientButton(
                label: kTutorialChoose.toUpperCase(),
                icon: Icons.school_rounded,
                onPressed: () => showBlurredDialog<void>(
                  context: context,
                  barrierLabel: 'Tutorial',
                  builder: (_) => _TutorialDialog(user: user),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialDialog extends StatefulWidget
{
  final MeResponse user;

  const _TutorialDialog({required this.user});

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog>
{
  late final List<RoleSection> _sections = desktopTourSectionsOf(widget.user);

  final Set<String> _chosen = {};

  bool _busy = false;

  void _toggle(String slug)
  {
    setState(()
    {
      if (!_chosen.remove(slug))
      {
        _chosen.add(slug);
      }
    });
  }

  // Refuses with a snackbar when nothing is chosen, as every desktop confirm does.
  Future<void> _confirm() async
  {
    if (_busy)
    {
      return;
    }

    if (_chosen.isEmpty)
    {
      CustomSnackBar.show(context: context, message: kTutorialPickASection, isError: true);

      return;
    }

    setState(() => _busy = true);

    await resetDesktopToursOf(widget.user.taxCode, _chosen);

    if (!mounted)
    {
      return;
    }

    CustomSnackBar.show(context: context, message: tutorialsReactivated(_chosen.length));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    return AppDialogStack(
      eyebrow: kSystemSection,
      title: kTutorialTitle,
      maxWidth: _maxWidth,
      footer: AppDialogFooter.single(
        AppGradientButton(
          label: kTutorialReactivate.toUpperCase(),
          icon: Icons.replay_rounded,
          busy: _busy,
          height: _buttonHeight,
          fontSize: _buttonFontSize,
          onPressed: _confirm,
        ),
      ),
      children: [
        AppDialogPill(expand: true, child: Text(kTutorialHint, style: _hintStyle())),
        const SizedBox(height: _pillGap),
        AppDialogPill(
          expand: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, section) in _sections.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index > 0 ? _rowGap : 0),
                  child: _SectionRow(
                    label: section.label,
                    selected: _chosen.contains(section.slug),
                    onTap: () => _toggle(section.slug),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// As the rows of the notification kinds: tick, light green when chosen, gold under the mouse.
class _SectionRow extends StatefulWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SectionRow({required this.label, required this.selected, required this.onTap});

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow>
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
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _fade,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            // Not Colors.transparent: the fade would pass through grey.
            color: widget.selected ? kPickedSurface : kPickedSurface.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              AppCheckMark(selected: widget.selected),
              const SizedBox(width: 14),
              Text(
                widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialOcean,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
