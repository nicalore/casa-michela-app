import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../shared/widgets/app_custom_tab_bar.dart';
import '../../shared/widgets/app_page_container.dart';

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

  //TieneTracciaDiQualiTabSonoStatiAperti_UnaVoltaVisitatoRestaMontatoNellIndexedStack
  //VieneAzzeratoSoloQuandoSettingsPageVieneDistruttaDaGoRouter_UscendoDaImpostazioni
  final Set<int> _visitedTabs = {0};

  final List<String> _tabs = [
    'Profilo',
    'Account',
    'Informazioni',
  ];

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
            color: const Color(0xFFF4F7F9),
            child: Stack(
              children: [
                Positioned(
                  right: -800,
                  top: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -800,
                  bottom: -800,
                  child: IgnorePointer(
                    child: Container(
                      width: 1600,
                      height: 1600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4D003C82),
                            Color(0x22003C82),
                            Color(0x00003C82),
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewportWidth > 1024)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Opacity(
                          opacity: 0.04,
                          child: Image.asset(
                            'assets/images/house_watermark.png',
                            width: 800,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                  context.go('/dashboard');
                                },
                                child: Container(
                                  width: 88,
                                  height: 54,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(Radius.circular(40)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        offset: Offset(0, 4),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Color(0xFF003C82),
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
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x0A000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Impostazioni',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF003C82),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

                        //IndexedStack_TieneVivoLoStatoDeiTabGiaVisitati_IlPlaceholderVieneSostituitoSoloAllaPrimaVisita
                        //DopoDiCheIlTabRestaMontatoENonSiRicaricaPiuFinoAllaChiusuraDellaPagina
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