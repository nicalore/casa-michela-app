import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../dashboard/widgets/dashboard_section_card.dart';
import '../../routing/app_router.dart';
import '../../routing/role_sections.dart';

const double _maxContentWidth = 620;

class SectionPlaceholderPage extends StatelessWidget
{
  final String currentRoute;

  final String eyebrow;
  final String title;
  final String description;

  final bool showNavigation;

  const SectionPlaceholderPage({
    super.key,
    required this.currentRoute,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height) => _Body(page: this, width: width, height: height),
      ),
    );
  }
}

class RoleSectionPage extends StatelessWidget
{
  final String role;
  final RoleSection section;

  const RoleSectionPage({super.key, required this.role, required this.section});

  @override
  Widget build(BuildContext context)
  {
    return SectionPlaceholderPage(
      currentRoute: '${homeForRole(role)}/${section.slug}',
      eyebrow: RoleLabelMapper.toLabel(role),
      title: section.label,
      description: 'Questa sezione non è ancora disponibile.',
    );
  }
}

class _Body extends StatelessWidget
{
  final SectionPlaceholderPage page;
  final double width;
  final double height;

  const _Body({required this.page, required this.width, required this.height});

  @override
  Widget build(BuildContext context)
  {
    final AppWindowSize size = AppBreakpoints.fromWidth(width);
    final double margin = AppBreakpoints.pageMargin(size);

    return Container(
      width: width,
      height: height,
      color: AppTheme.trialPaper,
      child: Stack(
        children: [
          const CornerGlow(
            corner: GlowCorner.topRight,
            tint: AppTheme.trialDeepWater,
            edgeTint: AppTheme.trialOcean,
            intensity: 1.25,
            animated: true,
          ),
          const CornerGlow(
            corner: GlowCorner.bottomLeft,
            tint: AppTheme.trialSeaGreen,
            edgeTint: AppTheme.trialTealDeep,
            animated: true,
          ),
          const PageWatermark(),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                margin,
                AppTopBar.contentTopInsetFor(size),
                margin,
                28,
              ),
              child: Center(
                child: SizedBox(
                  width: math.min(width - 2 * margin, _maxContentWidth),
                  child: PageTransitionItem(
                    slot: PageTransitionItem.header,
                    child: DashboardSectionCard(
                      eyebrow: page.eyebrow,
                      title: page.title,
                      child: DashboardComingSoon(
                        icon: Icons.construction_rounded,
                        description: page.description,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AppTopBar(currentRoute: page.currentRoute, showNavigation: page.showNavigation),
        ],
      ),
    );
  }
}
