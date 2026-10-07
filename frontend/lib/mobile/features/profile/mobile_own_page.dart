import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/own_page.dart'
    show OwnPageSection, ownPageSectionsOf, ownReportableFields;
import '../../../features/people/tabs/own_other_info_tab.dart' show ownOtherCards;
import '../../../features/people/widgets/person_detail_cards.dart';
import '../../../features/people/widgets/person_detail_widgets.dart';
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import 'mobile_face_editor.dart';
import 'widgets/mobile_card_grid.dart';
import 'widgets/mobile_detail_card.dart';
import 'widgets/mobile_memberships.dart';
import 'widgets/mobile_own_edit_sheets.dart';
import 'widgets/mobile_own_face.dart';
import 'widgets/mobile_personal_stats.dart';
import 'widgets/mobile_report_sheet.dart';
import 'widgets/mobile_school_years.dart';

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _phoneFace = 60;
const double _tabletFace = 76;

const double _stripGap = 18;

const double _statsGap = 24;

// The report button stands this far above the navigation bar.
const double _reportLift = 12;
const double _reportHeight = 58;

// Room above the first card for its shadow.
const double _shadowRoom = 16;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const String _teacherRole = 'DOCENTE';
const String _pupilRole = 'STUDENTE';

class MobileOwnPage extends StatefulWidget
{
  final MeResponse user;

  const MobileOwnPage({super.key, required this.user});

  @override
  State<MobileOwnPage> createState() => _MobileOwnPageState();
}

class _MobileOwnPageState extends State<MobileOwnPage>
{
  final ApiService _apiService = ApiService();
  final PageController _pages = PageController();

  PersonItem? _person;

  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  // They outlive the pages that display them.
  MobileTeacherStatsController? _teacherStats;
  MobilePupilStatsController? _pupilStats;

  bool _faceBusy = false;

  @override
  void initState()
  {
    super.initState();
    _load().then((_) => _loadStats()).whenComplete(MobileHoldScope.hold(context));
  }

  @override
  void dispose()
  {
    _pages.dispose();
    _teacherStats?.dispose();
    _pupilStats?.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final PersonItem person = await _apiService.getPerson(widget.user.taxCode);

      if (!mounted || request != _request)
      {
        return;
      }

      setState(()
      {
        _person = person;
        _loading = false;
        _failed = false;
      });
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento della pagina propria');

      if (!mounted || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _loading = false;
        _failed = !quiet || _person == null;
      });
    }
  }

  Future<void> _refresh()
  {
    _teacherStats?.load();
    _pupilStats?.load();

    return _load(quiet: true);
  }

  Future<void> _loadStats()
  {
    final PersonItem? person = _person;

    if (person == null)
    {
      return Future<void>.value();
    }

    final List<Future<void>> loads = [];

    if (_isTeacher(person) && _teacherStats == null)
    {
      final MobileTeacherStatsController stats = MobileTeacherStatsController(person.fiscalCode);

      _teacherStats = stats;
      loads.add(stats.load());
    }

    if (_isPupil(person) && _pupilStats == null)
    {
      final MobilePupilStatsController stats = MobilePupilStatsController(person.fiscalCode);

      _pupilStats = stats;
      loads.add(stats.load());
    }

    return Future.wait(loads);
  }

  MobileTeacherStatsController _teacherStatsOf(PersonItem person)
  {
    return _teacherStats ??= MobileTeacherStatsController(person.fiscalCode)..load();
  }

  MobilePupilStatsController _pupilStatsOf(PersonItem person)
  {
    return _pupilStats ??= MobilePupilStatsController(person.fiscalCode)..load();
  }

  Future<void> _editFace() async
  {
    final bool changed = await editMobileFace(
      context: context,
      user: widget.user,
      onBusy: (busy)
      {
        if (mounted)
        {
          setState(() => _faceBusy = busy);
        }
      },
    );

    if (changed && mounted)
    {
      await _load(quiet: true);
    }
  }

  Future<void> _editContacts(PersonItem person) async
  {
    if (await showMobileContactsSheet(context: context, person: person) && mounted)
    {
      await _load(quiet: true);
    }
  }

  Future<void> _editStudies(PersonItem person) async
  {
    if (await showMobileStudiesSheet(context: context, person: person) && mounted)
    {
      await _load(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bar = MobileNavSheet.collapsedHeightFor(context);

    final PersonItem? person = _person;
    final List<OwnPageSection> sections = person == null ? const [] : ownPageSectionsOf(person);

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: _buildTitle(person, tablet: tablet),
        ),
        AnimatedSize(
          duration: mobileRiseDurationOf(context),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          child: sections.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: _stripGap),
                    MobileRiseIn(
                      child: MobilePageStrip(
                        labels: [for (final section in sections) section.label],
                        controller: _pages,
                        scrollMargin: margin,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );

    final double bottom = bar + _reportLift + _reportHeight + _handleClearance;

    // Same layout while loading so the name stays put as the rest rises in.
    final Widget body = person == null
        ? _scrollable(
            bottom: bar + _handleClearance,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: MobileLoadSwitcher(
                  child: _loading
                      ? const MobileWaiting()
                      : _Status(_failed ? 'Non è stato possibile caricare i tuoi dati.' : ''),
                ),
              ),
            ],
          )
        : PageView(
            controller: _pages,
            children: [
              // Not kept alive: a mounted, scrolled page stalls the shared header.
              for (final section in sections)
                _scrollable(
                  bottom: bottom,
                  children: _buildSection(person, section, margin: margin, tablet: tablet),
                ),
            ],
          );

    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
            body: MobileLoadSwitcher(waiting: person == null, child: body),
          ),
        ),
        if (person != null)
          Positioned(
            left: margin,
            right: margin,
            bottom: bar + _reportLift,
            child: MobileRiseIn(
              child: _ReportButton(
                tablet: tablet,
                onTap: () => showMobileReportSheet(
                  context: context,
                  person: person,
                  fields: ownReportableFields(person),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(PersonItem? person, {required bool tablet})
  {
    final List<String> roles =
        person == null ? const [] : RoleLabelMapper.processRoles(person.shownRoles, feminine: person.gender == 'F');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.fullName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: tablet ? 34 : 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.08,
                  color: Colors.white,
                ),
              ),
              AnimatedSize(
                duration: mobileRiseDurationOf(context),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                clipBehavior: Clip.none,
                child: roles.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 9),
                          MobileRiseIn(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [for (final role in roles) _RolePill(role)],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        MobileOwnFace(
          user: widget.user,
          size: tablet ? _tabletFace : _phoneFace,
          busy: _faceBusy,
          onTap: _editFace,
        ),
      ],
    );
  }

  // Edge to edge, inset per block: chip rows may overrun the margin, shadows cross pages.
  Widget _scrollable({required double bottom, required List<Widget> children})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: _refresh,
        child: ListView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: _shadowRoom, bottom: bottom),
          children: children,
        ),
      ),
    );
  }

  List<Widget> _buildSection(
    PersonItem person,
    OwnPageSection section, {
    required double margin,
    required bool tablet,
  })
  {
    Widget inset(Widget child)
    {
      return Padding(padding: EdgeInsets.symmetric(horizontal: margin), child: child);
    }

    switch (section)
    {
      case OwnPageSection.info:
        final Widget identity = MobileDetailCard.of(identityCard(person));
        final Widget birth = MobileDetailCard.of(birthCard(person));
        final Widget residence = MobileDetailCard.of(residenceCard(person));
        final Widget contacts = MobileDetailCard.of(
          contactsCard(person),
          onEdit: () => _editContacts(person),
          editLabel: 'Modifica contatti',
        );

        // Tablet order matches the desktop's pairs.
        return [
          inset(MobileCardGrid(
            tablet: tablet,
            cards: tablet
                ? [identity, residence, birth, contacts]
                : [identity, birth, residence, contacts],
          )),
        ];

      // Stacked on tablets too: paired, the status card stretched tall and empty.
      case OwnPageSection.memberships:
        return [
          inset(MobileCardGrid(
            tablet: false,
            cards: [
              MobileMembershipStatusCard(person: person),
              MobileMembershipYearsCard(person: person),
            ],
          )),
        ];

      case OwnPageSection.other:
        return [
          inset(MobileCardGrid(
            tablet: tablet,
            cards: [for (final card in ownOtherCards(person)) _otherCard(person, card)],
          )),
        ];

      // As on the desktop, a teacher who is also a pupil sees both.
      case OwnPageSection.stats:
        return [
          if (_isTeacher(person))
            MobileTeacherStats(controller: _teacherStatsOf(person), margin: margin),
          if (_isTeacher(person) && _isPupil(person))
            const SizedBox(height: _statsGap),
          if (_isPupil(person))
            MobilePupilStats(controller: _pupilStatsOf(person), margin: margin),
        ];

      // Read-only, as on the desktop.
      case OwnPageSection.school:
        return [inset(MobileSchoolYears(person: person))];
    }
  }

  bool _isTeacher(PersonItem person)
  {
    return person.roles.any((role) => role.toUpperCase() == _teacherRole);
  }

  bool _isPupil(PersonItem person)
  {
    return person.roles.any((role) => role.toUpperCase() == _pupilRole);
  }

  // Teacher studies are the only card the owner can edit here.
  Widget _otherCard(PersonItem person, PersonDetailCard card)
  {
    final bool studies =
        _isTeacher(person) && card.title == teacherDetailsCard(person, forOwner: true).title;

    return MobileDetailCard.of(
      card,
      onEdit: studies ? () => _editStudies(person) : null,
      editLabel: studies ? 'Modifica studi' : null,
    );
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
    final Widget button = MobileDismissButton(
      label: 'Segnala dato mancante / errato',
      icon: Icons.flag_rounded,
      onPressed: onTap,
    );

    return tablet
        ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: button))
        : button;
  }
}

class _RolePill extends StatelessWidget
{
  final String role;

  const _RolePill(this.role);

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Colors.white,
        ),
      ),
    );
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
