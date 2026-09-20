import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_segmented_tabs.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/account_tab.dart';
import 'tabs/appearance_tab.dart';
import 'tabs/info_tab.dart';

const List<String> _sections = ['Aspetto', 'Account', 'Informazioni'];

const int _appearanceIndex = 0;
const int _accountIndex = 1;
const int _infoIndex = 2;

class SettingsPage extends StatefulWidget
{
  // Route the back button returns to; the page is opened from anywhere.
  final String? origin;

  const SettingsPage({super.key, this.origin});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SectionVisits
{
  final ApiService _apiService = ApiService();

  int _selectedSection = _appearanceIndex;

  @override
  void initState()
  {
    super.initState();
    visitedSections.add(_selectedSection);
  }

  // Only in-app paths are accepted; anything else falls back to the home.
  String get _origin
  {
    final String? origin = widget.origin;

    return origin != null && origin.startsWith('/')
        ? origin
        : homeForRole(_apiService.lastKnownIdentity?.activeRole);
  }

  void _selectSection(int index)
  {
    openSection(index, () => _selectedSection = index);
  }

  // Not one transition element: each section times its own cards.
  Widget _buildSectionContent()
  {
    return PageSections(
      index: _selectedSection,
      children: [
        visitedSections.contains(_appearanceIndex)
            ? const AppearanceTab()
            : const SizedBox.shrink(),
        visitedSections.contains(_accountIndex)
            ? const AccountTab()
            : const SizedBox.shrink(),
        visitedSections.contains(_infoIndex)
            ? const InfoTab()
            : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildBody(AppWindowSize size)
  {
    final Widget content = _buildSectionContent();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (size.hasRail) ...[
          Align(
            alignment: Alignment.topLeft,
            child: AppSectionRail(
              title: 'Impostazioni',
              groups: const [RailGroup(entries: _sections)],
              selectedIndex: _selectedSection,
              onSelected: _selectSection,
            ),
          ),
          const SizedBox(width: AppSectionRail.gap),
        ],
        Expanded(
          child: size.hasRail
              ? content
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSegmentedTabs(
                      labels: _sections,
                      selectedIndex: _selectedSection,
                      onSelected: _selectSection,
                    ),
                    Expanded(child: content),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
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
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: 24,
                      bottom: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppBackButton(
                            tooltip: 'Torna indietro',
                            onTap: () => context.go(_origin),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: _buildBody(size)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
