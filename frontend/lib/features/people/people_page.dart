import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_watermark.dart';
import 'tabs/people_search_tab.dart';
import 'tabs/people_statistics_tab.dart';

class PeoplePage extends StatefulWidget
{
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage>
{
  int _mainSelectedTab = 0;

  // Tracks which tabs have been opened: once visited a tab stays mounted in the
  // IndexedStack. Reset only when GoRouter destroys this page.
  final Set<int> _visitedTabs = {};

  final List<String> _mainTabs = ['Ricerca', 'Statistiche'];

  @override
  void initState()
  {
    super.initState();
    _visitedTabs.add(_mainSelectedTab);
  }

  Widget _buildTabContent()
  {
    return IndexedStack(
      index: _mainSelectedTab,
      children: [
        _visitedTabs.contains(0) ? const PeopleSearchTab() : const SizedBox.shrink(),
        _visitedTabs.contains(1) ? const PeopleStatisticsTab() : const SizedBox.shrink(),
      ],
    );
  }

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
            onTap: ()
            {
              PeopleSearchTab.clearSavedState();
              context.go('/dashboard');
            },
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
              'Persone',
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
            height: height,
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
                          tabs: _mainTabs,
                          selectedIndex: _mainSelectedTab,
                          maxWidth: viewportWidth - 80,
                          onTabSelected: (index)
                          {
                            setState(()
                            {
                              _mainSelectedTab = index;
                              _visitedTabs.add(index);
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: _buildTabContent()),
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
