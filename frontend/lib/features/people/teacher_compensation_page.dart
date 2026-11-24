import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_load_failed.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_section_tabs.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'models/person_item.dart';
import 'compensation_tour.dart';
import 'person_jump.dart';
import 'tabs/person_compensation_tab.dart';
import 'tabs/person_payments_tab.dart';
import 'utils/compensation_strings.dart';
import 'utils/payments_strings.dart';

const String _teacherRole = 'TEACHER';

const int _pay = kWalletPay;
const int _fees = kWalletFees;

// The teacher's Portafoglio: their pay month by month and their fees, read only.
class TeacherCompensationPage extends StatefulWidget
{
  const TeacherCompensationPage({super.key});

  @override
  State<TeacherCompensationPage> createState() => _TeacherCompensationPageState();
}

class _TeacherCompensationPageState extends State<TeacherCompensationPage> with DestinationRefresh, SectionVisits
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _failed = false;
  Object? _loadFailure;

  PersonItem? _person;

  // Sent here by a notification about that month.
  DateTime? _month = CompensationJumps.take();

  int _section = _pay;

  @override
  void initState()
  {
    super.initState();
    // The fees load from the start, ready when the tour or a click brings them in.
    visitedSections.addAll(const {_pay, _fees});
    walletSection.value = _section;
    walletSection.addListener(_onTourTurn);
    CompensationJumps.asked.addListener(_onJump);
    _load();
  }

  @override
  void dispose()
  {
    CompensationJumps.asked.removeListener(_onJump);
    walletSection.removeListener(_onTourTurn);
    super.dispose();
  }

  // A link or a notification asks for the pay, maybe on a month.
  void _onJump()
  {
    final DateTime? month = CompensationJumps.take();

    if (!mounted)
    {
      return;
    }

    if (month != null)
    {
      setState(() => _month = month);
    }

    if (_section != _pay)
    {
      _select(_pay);
    }
  }

  void _select(int index)
  {
    openSection(index, () => _section = index);

    // After the frame: a waiting tour redraws itself, which a build in progress forbids.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        walletSection.value = _section;
      }
    });
  }

  // A step back in the tour turns back to the pay.
  void _onTourTurn()
  {
    if (mounted && walletSection.value != _section)
    {
      _select(walletSection.value);
    }
  }

  @override
  void onDestinationShown()
  {
    _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();
      final person = await _apiService.getPerson(me.taxCode);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _person = person;
        _isLoading = false;
        _failed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento dei compensi');

      if (!mounted)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _person == null;
        _loadFailure = e;
      });
    }
  }

  List<RailGroup> get _groups => [RailGroup(entries: [kCompensationSection, kPaymentsSection])];

  static const Map<int, String> _tours = {_fees: kTourWalletToFees};

  Widget _buildSection(int index)
  {
    if (!visitedSections.contains(index))
    {
      return const SizedBox.shrink();
    }

    if (_isLoading)
    {
      return Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final PersonItem? person = _person;

    if (_failed || person == null)
    {
      return AppLoadFailedRoom(
        error: _loadFailure,
        message: index == _pay ? kCompensationLoadFailed : kPaymentsLoadFailed,
        onRetry: _load,
      );
    }

    if (index == _fees)
    {
      return PersonPaymentsTab(person: person, ownPage: true, shown: _section == _fees);
    }

    return PersonCompensationTab(
      person: person,
      month: _month,
      readOnly: true,
      shown: _section == _pay,
      onUpdate: () => _load(quiet: true),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        // Below the wide window the page is the window: the cards scroll, not the page.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
          final double margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.pagePaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: margin,
                      right: margin,
                      top: AppTopBar.contentTopInsetFor(size),
                      bottom: 28,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (size.hasRail) ...[
                          Align(
                            alignment: Alignment.topLeft,
                            child: PageTransitionItem(
                              slot: PageTransitionItem.frame,
                              child: AppSectionRail(
                                title: kWalletSection,
                                groups: _groups,
                                selectedIndex: _section,
                                onSelected: _select,
                                tours: _tours,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSectionRail.gap),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!size.hasRail) ...[
                                PageTransitionItem(
                                  slot: PageTransitionItem.frame,
                                  child: AppSectionTabs(
                                    title: kWalletSection,
                                    groups: _groups,
                                    selectedIndex: _section,
                                    onSelected: _select,
                                    tours: _tours,
                                  ),
                                ),
                                const SizedBox(height: kSectionTabsGap),
                              ],
                              Expanded(
                                child: PageSections(
                                  index: _section,
                                  children: [_buildSection(_pay), _buildSection(_fees)],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Last in the stack so the bar and its menu stay above the page.
                AppTopBar(currentRoute: '${homeForRole(_teacherRole)}/compensation'),
              ],
            ),
          );
        },
      ),
    );
  }
}
