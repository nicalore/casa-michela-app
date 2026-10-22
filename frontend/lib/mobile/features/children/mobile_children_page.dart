import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/people/children_page.dart' show childReportEyebrow, childReportableFields;
import '../../../features/people/models/child_item.dart';
import '../../../features/people/models/person_face.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/own_page.dart' show OwnPageSection;
import '../../../features/people/widgets/person_detail_cards.dart';
import '../../../features/people/widgets/person_detail_widgets.dart' show PersonDetailCard;
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import '../profile/mobile_own_tour.dart';
import '../profile/widgets/mobile_card_grid.dart';
import '../profile/widgets/mobile_detail_card.dart';
import '../profile/widgets/mobile_memberships.dart';
import '../profile/widgets/mobile_personal_stats.dart';
import '../profile/widgets/mobile_report_sheet.dart';
import '../profile/widgets/mobile_school_years.dart';
import '../../shared/widgets/mobile_avatar.dart';
import 'widgets/mobile_child_tiles.dart';

const String _title = 'Figli';

const String _pupilRole = 'STUDENTE';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

// Short: the tiles bleed their own room for the faces' halo.
const double _tilesGap = 6;
const double _tilesStripGap = 6;

const double _chipsGap = 12;
const double _chipsStripGap = 14;

const double _stripGap = 18;
const double _phoneFace = 60;
const double _tabletFace = 76;

const double _reportLift = 12;
const double _reportHeight = 58;

const double _shadowRoom = 16;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// The statistics' chips run to the screen's edges; the hole keeps to the cards.
const double _tourStatsInflate = 8;
const double _tourStatsRadius = 26;

// Every child has every section, so switching child keeps the page; a teacher's
// Osservazioni are their own, never their parents'.
const List<OwnPageSection> _sections = [
  OwnPageSection.info,
  OwnPageSection.memberships,
  OwnPageSection.school,
  OwnPageSection.other,
  OwnPageSection.stats,
];

class MobileChildrenPage extends StatefulWidget
{
  final MeResponse user;

  const MobileChildrenPage({super.key, required this.user});

  @override
  State<MobileChildrenPage> createState() => _MobileChildrenPageState();
}

class _MobileChildrenPageState extends State<MobileChildrenPage>
{
  final ApiService _apiService = ApiService();
  final PageController _pages = PageController();

  List<PersonItem> _children = const [];

  // By tax code, so a refresh that reorders the children keeps the one shown.
  String? _shown;

  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  // One controller moved from child to child, so period and ranking are kept.
  MobilePupilStatsController? _stats;

  // Set once the page is in place; from then on every load and closed sheet looks for the tour.
  bool _settledIn = false;

  @override
  void initState()
  {
    super.initState();
    _load().whenComplete(MobileHoldScope.hold(context));
    mobileTourChanges.addListener(_tourLater);
    MobileNavSheet.hidden.addListener(_tourLater);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_settledIn && mobileTourSettled(context))
    {
      _settledIn = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    mobileTourChanges.removeListener(_tourLater);
    MobileNavSheet.hidden.removeListener(_tourLater);
    _pages.dispose();
    _stats?.dispose();
    super.dispose();
  }

  // Asks for the frame too: the page may be still.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  // On the first page, once a child shows.
  Future<void> _tourCheck() async
  {
    final PersonItem? child = _failed ? null : _child;

    if (!mounted ||
        !_settledIn ||
        child == null ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pages.hasClients ||
        (_pages.page ?? 0) != 0)
    {
      return;
    }

    await startMobileTourOnce(
      taxCode: widget.user.taxCode,
      tour: childrenTour(
        pages: _pages,
        sections: [for (final section in _sections) section.name],
        genders: [for (final PersonItem each in _children) each.gender],
        shown: child.gender,
        pupil: _isPupil(child),
      ),
    );
  }

  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final PersonItem parent = await _apiService.getPerson(widget.user.taxCode);

      final List<PersonItem> children = await Future.wait([
        for (final child in parent.children ?? const <ChildItem>[])
          _apiService.getPerson(child.fiscalCode),
      ]);

      children.sort(compareByName);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _children = children;
        _loading = false;
        _failed = false;

        if (!children.any((child) => child.fiscalCode == _shown))
        {
          _shown = children.isEmpty ? null : children.first.fiscalCode;
        }
      });

      if (_child case final PersonItem child when _isPupil(child))
      {
        _stats?.follow(child.fiscalCode);
      }

      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento dei figli');

      if (!mounted || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _loading = false;
        _failed = !quiet || _children.isEmpty;
      });
    }
  }

  PersonItem? get _child
  {
    for (final child in _children)
    {
      if (child.fiscalCode == _shown)
      {
        return child;
      }
    }

    return null;
  }

  void _show(PersonItem child)
  {
    setState(() => _shown = child.fiscalCode);

    if (_isPupil(child))
    {
      _stats?.follow(child.fiscalCode);
    }
  }

  bool _isPupil(PersonItem child)
  {
    return child.roles.any((role) => role.toUpperCase() == _pupilRole);
  }

  Future<void> _refresh()
  {
    _stats?.load();

    return _load(quiet: true);
  }

  MobilePupilStatsController _statsOf(PersonItem child)
  {
    return _stats ??= MobilePupilStatsController(child.fiscalCode)..load();
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final Size size = MediaQuery.sizeOf(context);
    final bool lying = tablet && size.width > size.height;

    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bar = MobileNavSheet.collapsedHeightFor(context);

    final PersonItem? child = _failed ? null : _child;
    final bool several = child != null && _children.length > 1;

    final bool rail = lying && several;

    const double railRoom = MobileChildRail.width + MobileChildRail.gap;

    final Widget strip = MobilePageStrip(
      labels: [for (final section in _sections) section.label],
      controller: _pages,
      scrollMargin: margin,
      tourTargets: [for (final section in _sections) childrenTourTab(section.name)],
    );

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: _buildTitle(child, tablet: tablet),
        ),
        // Edge to edge: the row scrolls past the margin. Phones show the child as a chip.
        _grow(
          several && !rail
              ? Padding(
                  padding: EdgeInsets.only(top: tablet ? _tilesGap : _chipsGap),
                  child: tablet
                      ? MobileChildTiles(children: _children, shown: child, onShow: _show, margin: margin)
                      : MobileFilterChips(
                          margin: margin,
                          chips: [MobileChildChip(children: _children, shown: child, onShow: _show, eyebrow: _title)],
                        ),
                )
              : null,
        ),
        _grow(
          child == null || rail
              ? null
              : Padding(
                  padding: EdgeInsets.only(top: several ? (tablet ? _tilesStripGap : _chipsStripGap) : _stripGap),
                  child: strip,
                ),
        ),
        if (rail) const SizedBox(height: _stripGap),
      ],
    );

    final double bottom = bar + _reportLift + _reportHeight + _handleClearance;

    final Widget body = child == null
        ? _refreshable(
            MobileEmptyScroll(
              padding: EdgeInsets.only(top: _shadowRoom, bottom: bar + _handleClearance),
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: MobileLoadSwitcher(
                  child: _loading
                      ? const MobileWaiting()
                      : _failed
                          ? const _Status('Non è stato possibile caricare i dati dei figli.')
                          : Center(
                              child: MobileEmptyCard(
                                icon: Icons.family_restroom_rounded,
                                message: 'Nessun figlio collegato al tuo profilo.',
                                tablet: tablet,
                              ),
                            ),
                ),
              ),
              fill: !_loading && !_failed,
            ),
          )
        // Never kept alive, which stalls the header; statistics load with their page.
        : PageView.builder(
            controller: _pages,
            itemCount: _sections.length,
            itemBuilder: (context, index) => _isEmptySection(child, _sections[index])
                ? _refreshable(
                    MobileEmptyScroll(
                      padding: EdgeInsets.only(top: _shadowRoom, bottom: bottom),
                      body: _buildSection(child, _sections[index], margin: margin, tablet: tablet).single,
                      fill: true,
                    ),
                  )
                : _scrollable(
                    bottom: bottom,
                    children: _buildSection(child, _sections[index], margin: margin, tablet: tablet),
                  ),
          );

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
            body: rail
                ? Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: railRoom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            strip,
                            Expanded(
                              child: MobileRailClip(
                                pages: _pages,
                                margin: margin,
                                child: MobileLoadSwitcher(waiting: false, child: body),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: margin,
                        top: 0,
                        bottom: 0,
                        width: MobileChildRail.width,
                        child: MobileChildRail(
                          children: _children,
                          shown: child,
                          onShow: _show,
                          bottom: bar + _handleClearance,
                        ),
                      ),
                    ],
                  )
                : MobileLoadSwitcher(waiting: child == null, child: body),
          ),
        ),
        if (child != null)
          Positioned(
            left: rail ? railRoom + margin : margin,
            right: margin,
            bottom: bar + _reportLift,
            child: MobileRiseIn(
              child: _ReportButton(
                tablet: tablet,
                onTap: () => showMobileReportSheet(
                  context: context,
                  person: child,
                  fields: childReportableFields(child),
                  eyebrow: childReportEyebrow(child),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grow(Widget? child)
  {
    return AnimatedSize(
      duration: mobileRiseDurationOf(context),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: child == null ? const SizedBox(width: double.infinity) : MobileRiseIn(child: child),
    );
  }

  Widget _buildTitle(PersonItem? child, {required bool tablet})
  {
    final bool only = child != null && _children.length == 1;

    final Widget title = Text(
      only ? child.firstName : _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );

    if (!only)
    {
      return title;
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 14),
        MobileAvatar(
          firstName: child.firstName,
          lastName: child.lastName,
          imageUrl: child.profileImageUrl,
          size: tablet ? _tabletFace : _phoneFace,
        ),
      ],
    );
  }

  // Edge to edge, inset per block, so card shadows cross pages.
  Widget _scrollable({required double bottom, required List<Widget> children})
  {
    return _refreshable(
      ListView(
        clipBehavior: Clip.none,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: _shadowRoom, bottom: bottom),
        children: children,
      ),
    );
  }

  Widget _refreshable(Widget scroll)
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: _refresh,
        child: scroll,
      ),
    );
  }

  // Sections holding nothing but the empty card.
  bool _isEmptySection(PersonItem child, OwnPageSection section)
  {
    return switch (section)
    {
      OwnPageSection.other => _otherCards(child).isEmpty,
      OwnPageSection.school => MobileSchoolYears.yearsOf(child).isEmpty,
      OwnPageSection.stats => !_isPupil(child),
      _ => false,
    };
  }

  List<PersonDetailCard> _otherCards(PersonItem child)
  {
    return [
      ...pupilDetailCards(child),
      if (!child.isAdult) minorSafetyCard(child),
    ];
  }

  List<Widget> _buildSection(
    PersonItem child,
    OwnPageSection section, {
    required double margin,
    required bool tablet,
  })
  {
    Widget inset(Widget block)
    {
      return Padding(padding: EdgeInsets.symmetric(horizontal: margin), child: block);
    }

    switch (section)
    {
      case OwnPageSection.info:
        final Widget identity = MobileDetailCard.of(identityCard(child));
        final Widget birth = MobileDetailCard.of(birthCard(child));
        final Widget residence = MobileDetailCard.of(residenceCard(child));
        final Widget contacts = MobileDetailCard.of(contactsCard(child));

        return [
          inset(MobileCardGrid(
            tablet: tablet,
            cards: tablet
                ? [identity, residence, birth, contacts]
                : [identity, birth, residence, contacts],
          )),
        ];

      // Stacked on tablets too, as on the own page.
      case OwnPageSection.memberships:
        return [
          inset(MobileCardGrid(
            tablet: false,
            cards: [
              MobileMembershipStatusCard(person: child),
              MobileMembershipYearsCard(person: child),
            ],
          )),
        ];

      case OwnPageSection.other:
        final List<PersonDetailCard> cards = _otherCards(child);

        return [
          inset(
            cards.isEmpty
                ? Center(
                    child: MobileEmptyCard(
                      icon: Icons.info_outline_rounded,
                      message: 'Nessuna informazione aggiuntiva.',
                      tablet: tablet,
                    ),
                  )
                : MobileCardGrid(
                    tablet: tablet,
                    cards: [for (final card in cards) MobileDetailCard.of(card)],
                  ),
          ),
        ];

      // Read-only.
      case OwnPageSection.school:
        return [inset(MobileSchoolYears(person: child))];

      // Only pupils have figures.
      case OwnPageSection.stats:
        return [
          if (_isPupil(child))
            MobileTourTarget(
              id: kChildrenTourStats,
              inflate: EdgeInsets.fromLTRB(
                _tourStatsInflate - margin,
                _tourStatsInflate,
                _tourStatsInflate - margin,
                _tourStatsInflate,
              ),
              radius: _tourStatsRadius,
              child: MobilePupilStats(controller: _statsOf(child), margin: margin, tourFilters: kChildrenTourFilters),
            )
          else
            inset(Center(child: MobileEmptyCard(icon: Icons.insights_rounded, message: 'Nessun dato', tablet: tablet))),
        ];

      // Not among the sections above.
      case OwnPageSection.observations:
        return const [];
    }
  }
}

class _ReportButton extends StatelessWidget
{
  final bool tablet;
  final VoidCallback onTap;

  const _ReportButton({required this.tablet, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    // Hugging it: it floats over the cards, which a wider hole showed around it.
    final Widget button = MobileTourTarget(
      id: kChildrenTourReport,
      radius: MobileDismissButton.radius,
      child: MobileDismissButton(
        label: 'Segnala dato mancante / errato',
        icon: Icons.flag_rounded,
        onPressed: onTap,
      ),
    );

    return tablet
        ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: button))
        : button;
  }
}

class _Status extends StatelessWidget
{
  final String text;

  const _Status(this.text);

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
