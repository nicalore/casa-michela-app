import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/language/app_language.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/role_label_mapper.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_empty_card.dart';
import '../../shared/widgets/app_load_failed.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_section_rail.dart';
import '../../shared/widgets/app_section_tabs.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/desktop_tour.dart';
import '../../shared/widgets/page_density.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'family_payments_tour.dart';
import 'models/child_item.dart';
import 'models/person_face.dart';
import 'models/person_item.dart';
import 'models/student_payments_item.dart';
import 'person_jump.dart';
import 'tabs/person_payments_tab.dart';
import 'utils/payments_strings.dart';
import 'widgets/person_detail_header.dart';
import 'widgets/student_payment_history.dart' show showPaymentDetails;

const double _childrenMenuWidth = 260;
const double _menuFace = 28;

// A parent's children's payments (and their own fees, when a member), or a pupil's own when nobody answers for
// them; read only.
class FamilyPaymentsPage extends StatefulWidget
{
  final String role;

  const FamilyPaymentsPage({super.key, required this.role});

  @override
  State<FamilyPaymentsPage> createState() => _FamilyPaymentsPageState();
}

class _FamilyPaymentsPageState extends State<FamilyPaymentsPage> with SectionVisits
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _failed = false;
  Object? _loadFailure;

  List<PersonItem> _people = [];

  // The parent, when a member: their own fees beside the children's.
  PersonItem? _self;

  int _shown = 0;
  bool _ownShown = false;

  // A child asked for by the home, until the children are read; a jump skips that visit's tour.
  String? _asked;
  bool _jumped = false;

  bool get _parent => widget.role == 'PARENT';

  @override
  void initState()
  {
    super.initState();
    _asked = ChildPaymentsJumps.take();
    _jumped = _asked != null;
    ChildPaymentsJumps.asked.addListener(_onAsked);
    _load();
  }

  @override
  void dispose()
  {
    ChildPaymentsJumps.asked.removeListener(_onAsked);
    super.dispose();
  }

  // Already built: straight to the child.
  void _onAsked()
  {
    final String? asked = ChildPaymentsJumps.take();

    if (asked == null || !mounted)
    {
      return;
    }

    _jumped = true;
    final int child = _people.indexWhere((person) => person.fiscalCode == asked);

    if (_people.isEmpty)
    {
      _asked = asked;
    }
    else if (child >= 0)
    {
      _select(child);
    }
  }

  Future<void> _load() async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();
      final PersonItem self = await _apiService.getPerson(me.taxCode);

      final List<PersonItem> people = _parent
          ? await Future.wait([
              for (final child in self.children ?? const <ChildItem>[]) _apiService.getPerson(child.fiscalCode),
            ])
          : [self];

      people.sort(compareByName);

      final bool member = _parent && self.roles.contains(RoleLabelMapper.memberLabel);

      if (!mounted)
      {
        return;
      }

      final int asked = people.indexWhere((person) => person.fiscalCode == _asked);
      _asked = null;

      setState(()
      {
        _people = people;
        _self = member ? self : null;
        _isLoading = false;
        _failed = false;

        if (asked >= 0)
        {
          _shown = asked;
          _ownShown = false;
        }

        visitedSections.add(_shown);
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _isLoading = false;
        _failed = true;
        _loadFailure = e;
      });
    }
  }

  // Children by index, their own fees after them.
  void _select(int index)
  {
    openSection(index, ()
    {
      _ownShown = index == _people.length;

      if (!_ownShown)
      {
        _shown = index;
      }
    });
    _tellOwn();
  }

  // Told after the frame: a tour waiting for it redraws itself, which a build in progress forbids.
  void _tellOwn()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        familyOwnShown.value = _ownShown;
      }
    });
  }

  // The first person's payments read: the page's tour, or the parts it never told.
  Future<void> _onLoaded(StudentPaymentsItem payments) async
  {
    if (isDesktopTourShown || !mounted || _jumped)
    {
      return;
    }

    final PersonItem shown = _people[0];
    final PaymentHistoryRow? toured = familyTouredRow(payments.history);

    final DesktopTour? tour = await familyPaymentsPageTour(
          genders: [for (final child in _people) child.gender],
          gender: shown.gender,
          tariff: payments.tariff,
          row: toured,
          openRow: ()
          {
            if (toured != null && mounted)
            {
              showPaymentDetails(context: context, person: shown, payments: payments, row: toured, readOnly: true);
            }
          },
          member: _ownFees,
          showChild: () => _select(0),
        ) ??
        await familyPaymentsLateTour(gender: shown.gender, tariff: payments.tariff);

    if (tour != null && mounted && !_ownShown && _shown == 0)
    {
      startFamilyPaymentsTour(context, tour);
    }
  }

  // «Figli» or «Personali».
  void _selectTab(int tab)
  {
    _select(tab == 1 ? _people.length : _shown);
  }

  bool get _several => _parent && _people.length > 1;
  bool get _ownFees => _self != null;

  // Below the rail's width: the child's face and name, the others in its menu.
  Widget _buildHeading()
  {
    final PersonItem shown = _people[_shown];

    return AppSectionTabs(
      title: '${shown.firstName} ${shown.lastName}',
      titleSize: kPersonHeadingNameSize,
      leading: Padding(
        padding: const EdgeInsets.only(right: kPersonHeadingFaceGap),
        child: personHeadingFace(context, shown),
      ),
      leadingWidth: kPersonHeadingFace + kPersonHeadingFaceGap,
      titleMenu: _several ? (context, close) => _buildChildrenMenu(close) : null,
      groups: const [RailGroup(entries: [])],
      selectedIndex: 0,
      onSelected: (_) {},
    );
  }

  Widget _buildChildrenMenu(VoidCallback close)
  {
    return AppMenuCard(
      width: _childrenMenuWidth,
      children: [
        const SizedBox(height: 6),
        for (final (index, child) in _people.indexed)
          AppMenuItem(
            leading: personHeadingFace(context, child, size: _menuFace),
            text: '${child.firstName} ${child.lastName}',
            current: index == _shown,
            dense: true,
            onTap: ()
            {
              close();
              _select(index);
            },
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildContent()
  {
    final PersonItem? self = _self;

    return PageSections(
      index: _ownShown ? _people.length : _shown,
      children: [
        for (final (index, person) in _people.indexed)
          visitedSections.contains(index)
              ? PersonPaymentsTab(
                  key: ValueKey(person.fiscalCode),
                  person: person,
                  family: true,
                  // The tour follows the first person.
                  tour: index == 0 ? FamilyTabTour.child : FamilyTabTour.none,
                  onLoaded: index == 0 ? _onLoaded : null,
                )
              : const SizedBox.shrink(),
        if (self != null)
          visitedSections.contains(_people.length)
              ? PersonPaymentsTab(key: const ValueKey('own'), person: self, family: true, tour: FamilyTabTour.own)
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildBody(AppWindowSize size)
  {
    if (_isLoading)
    {
      return Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    if (_failed)
    {
      return AppLoadFailedRoom(error: _loadFailure, message: kPaymentsLoadFailed, onRetry: _load);
    }

    if (_people.isEmpty)
    {
      return Center(
        child: PageTransitionItem(
          slot: PageTransitionItem.list,
          child: AppEmptyCard(
            icon: Icons.family_restroom_rounded,
            message: tr('Nessun figlio collegato al tuo profilo.', 'No children linked to your profile.'),
          ),
        ),
      );
    }

    // In the rail: the children by first name, «Personali» under them for a member. Below its width: «Figli» and
    // «Personali» beside the title, the child's heading over the children's.
    final bool rail = (_several || _ownFees) && size.hasRail;
    final bool tabs = _ownFees && !rail;
    final bool heading = !rail && !_ownShown && (_several || _ownFees);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rail) ...[
          Align(
            alignment: Alignment.topLeft,
            child: PageTransitionItem(
              slot: PageTransitionItem.frame,
              child: DesktopTourTarget(
                id: _several ? kTourFamilyChildren : null,
                child: AppSectionRail(
                  title: kPaymentsSection,
                  groups: [
                    RailGroup(
                      title: _ownFees ? kChildrenPaymentsTab : null,
                      entries: [for (final child in _people) child.firstName],
                    ),
                    if (_ownFees) RailGroup(entries: [kOwnPaymentsTab]),
                  ],
                  selectedIndex: _ownShown ? _people.length : _shown,
                  onSelected: _select,
                  tours: _ownFees ? {_people.length: kTourFamilyToOwn} : const {},
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSectionRail.gap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tabs) ...[
                PageTransitionItem(
                  slot: PageTransitionItem.frame,
                  child: AppSectionTabs(
                    title: kPaymentsSection,
                    groups: [RailGroup(entries: [kChildrenPaymentsTab, kOwnPaymentsTab])],
                    selectedIndex: _ownShown ? 1 : 0,
                    onSelected: _selectTab,
                    tours: const {1: kTourFamilyToOwn},
                  ),
                ),
                const SizedBox(height: kSectionTabsGap),
              ],
              if (heading) ...[
                PageTransitionItem(
                  slot: PageTransitionItem.frame,
                  child: DesktopTourTarget(id: _several ? kTourFamilyChildren : null, child: _buildHeading()),
                ),
                const SizedBox(height: kSectionTabsGap),
              ],
              Expanded(child: _buildContent()),
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
                    child: AppPageDensity(dense: size.isDense, child: _buildBody(size)),
                  ),
                ),
                AppTopBar(currentRoute: '${homeForRole(widget.role)}/payments'),
              ],
            ),
          );
        },
      ),
    );
  }
}
