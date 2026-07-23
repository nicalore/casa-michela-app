import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/account_tab.dart';
import 'tabs/info_tab.dart';
import 'tabs/profile_tab.dart';

class SettingsPage extends StatefulWidget
{
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
{
  int _selectedTab = 0;

  // Tracks which tabs have been opened: once visited a tab stays mounted in the
  // IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedTabs = {0};

  final List<String> _tabs = [
    'Profilo',
    'Account',
    'Informazioni',
  ];

  Widget _buildHeader(BuildContext context)
  {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            onTap: () => context.go('/dashboard'),
            child: Container(
              width: 88,
              height: 54,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(40)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(40)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Center(
            child: Text(
              'Impostazioni',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
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
          final viewportWidth = MediaQuery.of(context).size.width;

          return Container(
            width: width,
            color: AppTheme.pageBackground,
            child: Stack(
              children: [
                const CornerGlow(corner: GlowCorner.topRight),
                const CornerGlow(corner: GlowCorner.bottomLeft),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        AppCustomTabBar(
                          tabs: _tabs,
                          selectedIndex: _selectedTab,
                          onTabSelected: (index)
                          {
                            setState(()
                            {
                              _selectedTab = index;
                              _visitedTabs.add(index);
                            });
                          },
                          maxWidth: viewportWidth - 80,
                        ),
                        const SizedBox(height: 24),
                        IndexedStack(
                          index: _selectedTab,
                          children: [
                            _visitedTabs.contains(0) ? const ProfileTab() : const SizedBox.shrink(),
                            _visitedTabs.contains(1) ? const AccountTab() : const SizedBox.shrink(),
                            _visitedTabs.contains(2) ? const InfoTab() : const SizedBox.shrink(),
                          ],
                        ),
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
