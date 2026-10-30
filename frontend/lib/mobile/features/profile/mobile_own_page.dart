import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../features/association/notices/notice_message_view.dart' show noticeTextStyle;
import '../../../features/auth/models/me_response.dart';
import '../../../features/notifications/administrator_notes_seen.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/models/student_note_item.dart';
import '../../../features/people/own_page.dart'
    show OwnPageSection, ownPageSectionsOf, ownReportableFields;
import '../../../features/people/person_jump.dart';
import '../../../features/people/tabs/own_other_info_tab.dart' show ownOtherCards;
import '../../../features/people/utils/student_notes_strings.dart';
import '../../../features/people/widgets/person_detail_cards.dart';
import '../../../features/people/widgets/person_detail_widgets.dart';
import '../../../features/people/widgets/student_note_text.dart';
import '../../../features/people/widgets/student_notes_card.dart' show noteDate;
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_dismiss_button.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_face_editor.dart';
import 'mobile_own_tour.dart';
import 'widgets/mobile_card_grid.dart';
import 'widgets/mobile_criteria_sheet.dart';
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

// Of the account, not of the person: a teacher's parent kept for paperwork wears none.
const String _parentAccountRole = 'PARENT';
const String _studentAccountRole = 'STUDENT';
const String _pupilRole = 'STUDENTE';

final TextStyle _noteStyle = noticeTextStyle(fontSize: 15.5, height: 1.45);

const EdgeInsets _tourInflate = EdgeInsets.all(5);
const double _tourCardRadius = 27;
const double _tourRoundRadius = 40;
const double _tourStatsInflate = 8;
const double _tourStatsRadius = 26;
const EdgeInsets _tourInfoInflate = EdgeInsets.all(6);
const double _tourInfoRadius = 30;

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

  // Set once the shell has stopped moving the page in.
  bool _settledIn = false;

  // Asked by a notification: the Osservazioni, once the record is read.
  bool _observationsAsked = false;

  @override
  void initState()
  {
    super.initState();
    _observationsAsked = OwnPageJumps.takeObservations();
    _load().then((_) => _loadStats()).whenComplete(MobileHoldScope.hold(context));
    mobileTourChanges.addListener(_tourLater);
    MobileNavSheet.hidden.addListener(_tourLater);
    OwnPageJumps.asked.addListener(_onObservationsAsked);
  }

  // Already open: read again, as the note announced may be newer than the one shown.
  void _onObservationsAsked()
  {
    if (!mounted || !OwnPageJumps.takeObservations())
    {
      return;
    }

    _observationsAsked = true;
    _load(quiet: true);
  }

  // Before the tour's check, which leaves a page not on its start alone.
  void _showObservations(PersonItem person)
  {
    final int index = ownPageSectionsOf(person).indexOf(OwnPageSection.observations);

    if (index < 0 || !_pages.hasClients)
    {
      return;
    }

    if ((_pages.page ?? 0).round() == index)
    {
      unawaited(markAdministratorNotesSeen());
    }
    else
    {
      _pages.jumpToPage(index);
    }
  }

  void _onPageChanged(int index)
  {
    final PersonItem? person = _person;

    // The administrators' notes on screen: the news of new ones goes.
    if (person != null && ownPageSectionsOf(person).elementAtOrNull(index) == OwnPageSection.observations)
    {
      unawaited(markAdministratorNotesSeen());
    }
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
    OwnPageJumps.asked.removeListener(_onObservationsAsked);
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

      if (_observationsAsked)
      {
        _observationsAsked = false;
        SchedulerBinding.instance.addPostFrameCallback((_)
        {
          if (mounted)
          {
            _showObservations(person);
          }
        });
      }

      _tourLater();
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

  // Asks for the frame too: the page may be still.
  void _tourLater()
  {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _tourCheck())
      ..scheduleFrame();
  }

  // Whatever role is worn: a teacher's tour, else a student's, else a parent's.
  Future<void> _tourCheck() async
  {
    final PersonItem? person = _person;
    final List<String> roles = widget.user.availableRoles;

    if (!mounted ||
        !_settledIn ||
        person == null ||
        !(_isTeacher(person) || roles.contains(_studentAccountRole) || roles.contains(_parentAccountRole)) ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pages.hasClients ||
        (_pages.page ?? 0) != 0)
    {
      return;
    }

    final List<String> sections = [for (final section in ownPageSectionsOf(person)) section.name];

    await startMobileTourOnce(
      taxCode: widget.user.taxCode,
      tour: _isTeacher(person)
          ? ownTour(
              pages: _pages,
              title: widget.user.firstName,
              sections: sections,
              noted: person.administratorNotes?.isNotEmpty ?? false,
            )
          : roles.contains(_studentAccountRole)
              ? studentOwnTour(pages: _pages, title: widget.user.firstName, sections: sections)
              : parentOwnTour(title: widget.user.firstName),
    );
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

    if (person == null || !ownPageSectionsOf(person).contains(OwnPageSection.stats))
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
                        tourTargets: [for (final section in sections) ownTourTab(section.name)],
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
            onPageChanged: _onPageChanged,
            children: [
              // Not kept alive: a mounted, scrolled page stalls the shared header.
              for (final section in sections)
                _scrollable(
                  bottom: bottom,
                  head: _buildHead(person, section, margin: margin),
                  children: _buildSection(person, section, margin: margin, tablet: tablet),
                  // Only the school and the Osservazioni can hold nothing but the empty card.
                  fill: switch (section)
                  {
                    OwnPageSection.school => MobileSchoolYears.yearsOf(person).isEmpty,
                    OwnPageSection.observations => person.administratorNotes?.isEmpty ?? true,
                    _ => false,
                  },
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
                tourId: kOwnTourReport,
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
        MobileTourTarget(
          id: kOwnTourFace,
          inflate: _tourInflate,
          radius: _tourRoundRadius,
          child: MobileOwnFace(
            user: widget.user,
            size: tablet ? _tabletFace : _phoneFace,
            busy: _faceBusy,
            onTap: _editFace,
          ),
        ),
      ],
    );
  }

  // Edge to edge, inset per block: chip rows may overrun the margin, shadows cross pages.
  // [fill]: [children] is the empty card alone, centred in the room.
  Widget _scrollable({
    required double bottom,
    required List<Widget> children,
    List<Widget> head = const [],
    bool fill = false,
  })
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: _refresh,
        // Not lazy: a lazy list guesses its length from what it built, and the tour scrolls by it.
        child: fill
            ? MobileEmptyScroll(
                padding: EdgeInsets.only(top: _shadowRoom, bottom: bottom),
                head: head,
                body: children.single,
                fill: true,
                tail: const [MobileTourRunway()],
              )
            : SingleChildScrollView(
                clipBehavior: Clip.none,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: _shadowRoom, bottom: bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...children, const MobileTourRunway()],
                ),
              ),
      ),
    );
  }

  // Above the empty Osservazioni, whose card holds the (i) once there are notes.
  List<Widget> _buildHead(PersonItem person, OwnPageSection section, {required double margin})
  {
    if (section != OwnPageSection.observations || (person.administratorNotes?.isNotEmpty ?? false))
    {
      return const [];
    }

    return [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: margin),
        child: Align(
          alignment: Alignment.centerRight,
          child: MobileTourTarget(
            id: kOwnTourCriteria,
            inflate: _tourInfoInflate,
            radius: _tourInfoRadius,
            child: MobileInfoButton(onTap: () => showMobileCriteriaSheet(context)),
          ),
        ),
      ),
    ];
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

      // A teacher who is also a pupil sees both.
      case OwnPageSection.stats:
        return [
          if (_isTeacher(person))
            // The chips run to the screen's edges; the hole keeps to the cards.
            MobileTourTarget(
              id: kOwnTourStats,
              inflate: EdgeInsets.fromLTRB(
                _tourStatsInflate - margin,
                _tourStatsInflate,
                _tourStatsInflate - margin,
                _tourStatsInflate,
              ),
              radius: _tourStatsRadius,
              child: MobileTeacherStats(
                controller: _teacherStatsOf(person),
                margin: margin,
                tourFilters: kOwnTourFilters,
              ),
            ),
          if (_isTeacher(person) && _isPupil(person))
            const SizedBox(height: _statsGap),
          // Lit by the student's tour; a teacher's lights their own block alone.
          if (_isPupil(person))
            MobileTourTarget(
              id: _isTeacher(person) ? null : kOwnTourStats,
              inflate: EdgeInsets.fromLTRB(
                _tourStatsInflate - margin,
                _tourStatsInflate,
                _tourStatsInflate - margin,
                _tourStatsInflate,
              ),
              radius: _tourStatsRadius,
              child: MobilePupilStats(
                controller: _pupilStatsOf(person),
                margin: margin,
                tourFilters: _isTeacher(person) ? null : kOwnTourFilters,
              ),
            ),
        ];

      // Read-only.
      case OwnPageSection.school:
        return [inset(MobileSchoolYears(person: person))];

      case OwnPageSection.observations:
        return [inset(_observations(person, tablet: tablet))];
    }
  }

  // Read-only: what the administrators wrote about the teacher, newest first.
  Widget _observations(PersonItem person, {required bool tablet})
  {
    final List<StudentNoteItem> notes = person.administratorNotes ?? const [];

    if (notes.isEmpty)
    {
      return Center(
        child: MobileTourTarget(
          id: kOwnTourObservations,
          inflate: _tourInflate,
          radius: _tourCardRadius,
          child: MobileEmptyCard(icon: Icons.speaker_notes_off_rounded, message: kNoObservations, tablet: tablet),
        ),
      );
    }

    return MobileTourTarget(
      id: kOwnTourObservations,
      inflate: _tourInflate,
      radius: _tourCardRadius,
      child: MobileDetailCard(
        icon: Icons.edit_note_rounded,
        title: kObservationsTitle,
        trailing: MobileTourTarget(
          id: kOwnTourCriteria,
          inflate: _tourInfoInflate,
          radius: _tourInfoRadius,
          child: MobileCardButton(
            icon: Icons.info_outline_rounded,
            label: kCriteriaTitle,
            onTap: () => showMobileCriteriaSheet(context),
          ),
        ),
        rows: [
          for (final StudentNoteItem note in notes)
            DetailRowData.drawn(
              '${noteDate(note.createdAt)} · ${note.authorName}',
              StudentNoteText(
                taxCode: person.fiscalCode,
                kind: StudentNoteKind.administrator,
                note: note,
                style: _noteStyle,
              ),
            ),
        ],
      ),
    );
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

    return MobileTourTarget(
      id: studies ? kOwnTourStudies : null,
      inflate: _tourInflate,
      radius: _tourCardRadius,
      child: MobileDetailCard.of(
        card,
        onEdit: studies ? () => _editStudies(person) : null,
        editLabel: studies ? 'Modifica studi' : null,
      ),
    );
  }
}

class _ReportButton extends StatelessWidget
{
  final bool tablet;
  final String tourId;
  final VoidCallback onTap;

  const _ReportButton({required this.tablet, required this.tourId, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    // Hugging it: it floats over the cards, which a wider hole showed around it.
    final Widget button = MobileTourTarget(
      id: tourId,
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
