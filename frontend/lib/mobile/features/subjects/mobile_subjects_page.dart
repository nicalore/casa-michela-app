import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/association/models/association_subject_item.dart';
import '../../../features/association/models/service_item.dart';
import '../../../features/association/models/study_program_item.dart';
import '../../../features/association/models/subject_taxonomy.dart';
import '../../../features/people/models/person_item.dart';
import '../../../features/people/models/teacher_subject_item.dart';
import '../../../features/people/widgets/competence_picker.dart' show kServicesFilterValue;
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_choice_sheet.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_search_field.dart';
import '../../shared/widgets/mobile_tour.dart';
import 'mobile_subjects_tour.dart';
import 'widgets/mobile_programs_sheet.dart';
import 'widgets/mobile_reflow_slot.dart';
import 'widgets/mobile_removable_row.dart';
import 'widgets/mobile_service_sheet.dart';
import 'widgets/mobile_subject_card.dart';

const String _title = 'Discipline';

// Mobile-only copy: the swipe has no desktop counterpart.
const String kMobileSlideToRemove =
    'Per rimuovere una disciplina, fai scorrere la sua riga verso destra.';

const String _updatedMessage = 'Discipline aggiornate con successo!';

const List<String> _pages = ['Scelte', 'Da scegliere'];

const double _phoneMargin = 20;
const double _tabletMargin = 44;

const double _headerGap = 14;
const double _rowGap = 9;
const double _columnGap = 12;

// Narrower than this a card cannot fit a discipline's name and its count.
const double _minCardWidth = 320;
const int _maxColumns = 3;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

// Room above the first card for its shadow.
const double _shadowRoom = 20;

const Duration _pageTurn = Duration(milliseconds: 320);

// A page settles within a tolerance, never exactly on its index.
const double _settled = 0.001;

const double _tourListInflate = 10;
const double _tourListRadius = 30;
const double _tourFiltersInflate = 8;
const double _tourFiltersRadius = 24;
const double _tourCardInflate = 5;

class _Entry
{
  final String name;
  final String detail;

  final int? subjectId;
  final String? area;

  const _Entry({required this.name, required this.detail, this.subjectId, this.area});

  bool get isService => subjectId == null;

  String get tourId => isService ? 'service-$name' : 'subject-$subjectId';

  Key get key => ValueKey(tourId);
}

class _Filters
{
  final TextEditingController controller = TextEditingController();

  String query = '';
  String? area;

  void dispose()
  {
    controller.dispose();
  }

  bool keeps(_Entry entry)
  {
    if (!entry.name.toLowerCase().contains(query.toLowerCase()))
    {
      return false;
    }

    if (area == null)
    {
      return true;
    }

    return area == kServicesFilterValue ? entry.isService : entry.area == area;
  }
}

class MobileSubjectsPage extends StatefulWidget
{
  // First-access step head replacing the title; set, the section intro never auto-opens.
  final Widget? heading;

  // Room for what floats over the lists' end; null means the menu bar.
  final double? endRoom;

  const MobileSubjectsPage({super.key, this.heading, this.endRoom});

  @override
  State<MobileSubjectsPage> createState() => _MobileSubjectsPageState();
}

class _MobileSubjectsPageState extends State<MobileSubjectsPage>
{
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();

  final _Filters _filters = _Filters();

  bool _loading = true;
  bool _failed = false;
  bool _saving = false;

  // Set once the page is in place; from then on every load, page change and closed sheet looks for a tour.
  bool _toured = false;
  int? _pageSeen;

  // Just taken: a tour shows where it went, the first time.
  Key? _moved;

  // A held discipline's sheet just closed: a tour shows the swipe, the first time.
  bool _afterHeldSheet = false;

  // The row showing the swipe while its tour is up.
  Key? _hinted;

  String? _taxCode;
  DateTime? _updatedAt;

  List<TeacherSubjectItem> _held = const [];
  List<String> _heldServices = const [];

  List<AssociationSubjectItem> _subjects = const [];
  List<ServiceItem> _services = const [];

  final Map<int, List<StudyProgramItem>> _programsBySubjectId = {};

  // Bumped on every fetch so a stale response is dropped.
  int _request = 0;

  final Set<Key> _leaving = {};

  // Bumped per removal: only then do the tablet's cards glide to their new places.
  int _removals = 0;

  @override
  void initState()
  {
    super.initState();
    _load().whenComplete(MobileHoldScope.hold(context));
    _pageController.addListener(_onPage);
    MobileNavSheet.hidden.addListener(_onSheets);
    mobileTourChanges.addListener(_onTours);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    // Not in the first access, which has its own steps.
    if (!_toured && widget.heading == null && mobileTourSettled(context))
    {
      _toured = true;
      _tourLater();
    }
  }

  @override
  void dispose()
  {
    mobileTourChanges.removeListener(_onTours);
    MobileNavSheet.hidden.removeListener(_onSheets);
    _pageController.dispose();
    _filters.dispose();

    super.dispose();
  }

  void _tourLater() => WidgetsBinding.instance.addPostFrameCallback((_) => _tourCheck());

  void _onPage()
  {
    final double page = _pageController.page ?? 0;

    if ((page - page.round()).abs() < _settled && page.round() != _pageSeen)
    {
      _pageSeen = page.round();
      _tourLater();
    }
  }

  void _onSheets()
  {
    if (!MobileNavSheet.hidden.value)
    {
      _tourLater();
    }
  }

  // A tour ending may let the next one come, and stops the swipe shown.
  void _onTours()
  {
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (!mounted || isMobileTourShown)
      {
        return;
      }

      if (_hinted != null)
      {
        setState(() => _hinted = null);
      }

      _tourCheck();
    });
  }

  List<_Entry> get _shownHeld => _heldEntries.where(_filters.keeps).toList();

  // The first discipline's + rather than a service's, which has no programmes.
  _Entry? get _firstAddable
  {
    final List<_Entry> shown = _openEntries.where(_filters.keeps).toList();

    return shown.where((entry) => !entry.isService).firstOrNull ?? shown.firstOrNull;
  }

  // The main tour on the first visit; then where a discipline just taken went, and the swipe after a held one's sheet.
  Future<void> _tourCheck() async
  {
    final String? taxCode = _taxCode;

    if (!mounted ||
        !_toured ||
        taxCode == null ||
        _loading ||
        _failed ||
        _saving ||
        _leaving.isNotEmpty ||
        isMobileTourShown ||
        MobileNavSheet.hidden.value ||
        !_pageController.hasClients)
    {
      return;
    }

    final double page = _pageController.page ?? 0;

    if ((page - page.round()).abs() >= _settled)
    {
      return;
    }

    final bool onHeld = page.round() == 0;

    if (!await isMobileTourSeen(taxCode: taxCode, tour: subjectsMainTour(_pageController)))
    {
      if (mounted && onHeld)
      {
        await startMobileTourOnce(
          taxCode: taxCode,
          tour: subjectsTour(pages: _pageController, canAdd: () => _firstAddable != null),
        );
      }

      return;
    }

    final Key? movedKey = _moved;

    if (movedKey != null)
    {
      final _Entry? moved = _shownHeld.where((entry) => entry.key == movedKey).firstOrNull;
      final bool seen = moved == null || await isMobileTourSeen(taxCode: taxCode, tour: subjectsMovedTour(moved.tourId));

      if (!mounted)
      {
        return;
      }

      if (moved != null && !seen)
      {
        // Shown in the list it went to.
        if (!onHeld)
        {
          _pageController.animateToPage(0, duration: _pageTurn, curve: Curves.easeInOutCubic);

          return;
        }

        _moved = null;
        await startMobileTourOnce(taxCode: taxCode, tour: subjectsMovedTour(moved.tourId));

        return;
      }

      _moved = null;
    }

    if (_afterHeldSheet && onHeld)
    {
      _afterHeldSheet = false;

      final _Entry? first = _shownHeld.firstOrNull;

      if (first == null || await isMobileTourSeen(taxCode: taxCode, tour: subjectsSwipeTour(first.tourId)))
      {
        return;
      }

      await startMobileTourOnce(taxCode: taxCode, tour: subjectsSwipeTour(first.tourId));

      if (mounted && isMobileTourShown)
      {
        setState(() => _hinted = first.key);
      }
    }
  }

  Future<void> _load({bool quiet = false}) async
  {
    final int request = ++_request;

    try
    {
      final String taxCode =
          (_apiService.lastKnownIdentity ?? await _apiService.me()).taxCode;

      final List<dynamic> results = await Future.wait([
        _apiService.getPerson(taxCode),
        _apiService.getAssociationSubjects(),
        _apiService.getStudyPrograms(),
        _apiService.getServices(),
      ]);

      if (!mounted || request != _request)
      {
        return;
      }

      final PersonItem person = results[0] as PersonItem;
      final List<AssociationSubjectItem> subjects = results[1] as List<AssociationSubjectItem>;
      final List<StudyProgramItem> programs = results[2] as List<StudyProgramItem>;

      setState(()
      {
        _taxCode = taxCode;
        _updatedAt = person.teacherUpdatedAt;
        _held = person.teacherSubjects ?? const [];
        _heldServices = person.teacherServices ?? const [];
        _subjects = subjects;
        _services = results[3] as List<ServiceItem>;

        _programsBySubjectId
          ..clear()
          ..addEntries(subjects.map((subject) => MapEntry(
                subject.id,
                programs.where((program) => program.teaches(subject.id)).toList(),
              )));

        _loading = false;
        _failed = false;
      });

      _tourLater();
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle discipline');

      if (!mounted || request != _request)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _loading = false;
        _failed = !quiet || _taxCode == null;
      });
    }
  }

  Map<int, List<int>> get _heldPrograms
  {
    return {
      for (final subject in _held) subject.subjectId: subject.studyProgramIds,
    };
  }

  int _totalProgramsOf(TeacherSubjectItem subject)
  {
    final List<StudyProgramItem>? all = _programsBySubjectId[subject.subjectId];

    return all == null || all.isEmpty ? subject.studyPrograms.length : all.length;
  }

  List<_Entry> get _heldEntries
  {
    final List<_Entry> entries = [
      for (final subject in _held)
        _Entry(
          name: subject.subjectName,
          detail: programsSummary(subject.studyPrograms.length, _totalProgramsOf(subject)),
          subjectId: subject.subjectId,
          area: subject.subjectArea,
        ),
      for (final service in _heldServices) _Entry(name: service, detail: 'Servizio'),
    ];

    return entries..sort((a, b) => a.name.compareTo(b.name));
  }

  // A discipline no programme teaches cannot be assigned, so it is not offered.
  List<_Entry> get _openEntries
  {
    final Set<int> heldIds = {for (final subject in _held) subject.subjectId};

    final List<_Entry> entries = [
      for (final subject in _subjects)
        if (!heldIds.contains(subject.id) && (_programsBySubjectId[subject.id] ?? const []).isNotEmpty)
          _Entry(
            name: subject.name,
            detail: subjectAreaLabel(subject.area),
            subjectId: subject.id,
            area: subject.area,
          ),
      for (final service in _services)
        if (!_heldServices.contains(service.name)) _Entry(name: service.name, detail: 'Servizio'),
    ];

    return entries..sort((a, b) => a.name.compareTo(b.name));
  }

  // True once saved.
  Future<bool> _saveCompetences(Map<int, List<int>> programs, List<String> services) async
  {
    final String? taxCode = _taxCode;

    if (_saving || taxCode == null)
    {
      return false;
    }

    bool saved = false;

    setState(() => _saving = true);

    try
    {
      await _apiService.updateTeacherCompetences(
        taxCode,
        [
          for (final entry in programs.entries)
            <String, dynamic>{'subject_id': entry.key, 'study_program_ids': entry.value},
        ],
        services,
        _updatedAt,
      );

      saved = true;

      if (mounted)
      {
        MobileNotice.show(context, _updatedMessage);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _saving = false);
      }
    }

    // Reload either way: the next save must send the server's fresh updated_at.
    await _load(quiet: true);

    return saved;
  }

  // A discipline or service just taken: its tour follows the first time.
  void _taken(_Entry entry, bool saved)
  {
    if (saved && mounted)
    {
      _moved = entry.key;
      _tourLater();
    }
  }

  Future<void> _editPrograms(_Entry entry, {required bool held})
  {
    final int subjectId = entry.subjectId!;
    final List<StudyProgramItem> programs = _programsBySubjectId[subjectId] ?? const [];

    final TeacherSubjectItem? current = held
        ? _held.where((subject) => subject.subjectId == subjectId).firstOrNull
        : null;

    return showMobileProgramsSheet(
      context: context,
      subjectName: entry.name,
      description: _describeSubject(subjectId),
      programs: programs,
      initialSelected:
          current?.studyProgramIds.toSet() ?? {for (final program in programs) program.id},
      onRemove: held ? (sheet) => _removeFrom(sheet, entry) : null,
      taxCode: widget.heading == null ? _taxCode : null,
    ).then((chosen) async
    {
      // Leaving a held one's sheet, the swipe is shown once the page is quiet.
      if (held)
      {
        _afterHeldSheet = true;
        _tourLater();
      }

      // Empty cancels a new discipline; a held one is given up from the sheet.
      if (chosen == null || chosen.isEmpty || !mounted)
      {
        return;
      }

      final bool saved = await _saveCompetences(
        {..._heldPrograms, subjectId: chosen.toList()},
        _heldServices,
      );

      if (!held)
      {
        _taken(entry, saved);
      }
    });
  }

  String? _describeSubject(int subjectId)
  {
    final AssociationSubjectItem? known =
        _subjects.where((item) => item.id == subjectId).firstOrNull;

    return descriptionOrNull(known?.description);
  }

  String? _describeService(String service)
  {
    final ServiceItem? known =
        _services.where((item) => item.name == service).firstOrNull;

    return descriptionOrNull(known?.description);
  }

  Future<void> _openService(_Entry entry, {required bool held}) async
  {
    final bool? taken = await showMobileServiceSheet(
      context: context,
      name: entry.name,
      description: _describeService(entry.name),
      onRemove: held ? (sheet) => _removeFrom(sheet, entry) : null,
    );

    if (taken == true && mounted)
    {
      await _addService(entry);
    }
  }

  Future<void> _removeFrom(BuildContext sheet, _Entry entry) async
  {
    if (!await _confirmRemoval(sheet, entry) || !mounted)
    {
      return;
    }

    if (sheet.mounted)
    {
      final Future<void> gone = _sheetGone(ModalRoute.of(sheet)?.animation);

      closeMobileSheet(sheet);

      await gone;
    }

    if (mounted)
    {
      setState(() => _leaving.add(entry.key));
    }
  }

  // Bounded, should the route go without ever settling.
  Future<void> _sheetGone(Animation<double>? animation)
  {
    if (animation == null || animation.isDismissed)
    {
      return Future<void>.value();
    }

    final Completer<void> gone = Completer<void>();

    void listen(AnimationStatus status)
    {
      if (status.isDismissed && !gone.isCompleted)
      {
        animation.removeStatusListener(listen);
        gone.complete();
      }
    }

    animation.addStatusListener(listen);

    return gone.future.timeout(const Duration(seconds: 1), onTimeout: () {});
  }

  Future<void> _takeOnEverything(_Entry entry) async
  {
    final int subjectId = entry.subjectId!;
    final List<StudyProgramItem> programs = _programsBySubjectId[subjectId] ?? const [];

    _taken(
      entry,
      await _saveCompetences(
        {..._heldPrograms, subjectId: [for (final program in programs) program.id]},
        _heldServices,
      ),
    );
  }

  Future<void> _addService(_Entry entry) async
  {
    final List<String> services = [..._heldServices, entry.name];

    setState(() => _heldServices = services);

    _taken(entry, await _saveCompetences(_heldPrograms, services));
  }

  TextSpan _warning(String before, String name, String after)
  {
    return TextSpan(
      children: [
        TextSpan(text: before),
        TextSpan(text: name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        TextSpan(text: after),
      ],
    );
  }

  Future<bool> _confirmRemoval(BuildContext from, _Entry entry)
  {
    return showMobileConfirmSheet(
      context: from,
      eyebrow: 'Rimozione',
      title: 'Confermi?',
      message: entry.isService
          ? _warning('Il servizio ', entry.name, ' verrà rimosso da quelli seguiti.')
          : _warning('La disciplina ', entry.name, ' verrà rimossa.'),
      confirmLabel: 'Rimuovi',
      confirmIcon: Icons.delete_outline_rounded,
    );
  }

  void _remove(_Entry entry)
  {
    final Map<int, List<int>> programs = Map<int, List<int>>.from(_heldPrograms);
    final List<String> services = [..._heldServices];

    if (entry.isService)
    {
      services.remove(entry.name);
    }
    else
    {
      programs.remove(entry.subjectId);
    }

    setState(()
    {
      _held = _held.where((subject) => subject.subjectId != entry.subjectId).toList();
      _heldServices = services;
      _leaving.remove(entry.key);
      _removals += 1;
    });

    _saveCompetences(programs, services);
    _tourLater();
  }

  // [lit] marks the + a tour lights.
  Widget _buildCard(_Entry entry, {required bool held, double gap = 0, double? sideGap, bool lit = false})
  {
    final MobileSubjectCard card = MobileSubjectCard(
      name: entry.name,
      detail: entry.detail,
      held: held,
      onTap: entry.isService
          ? () => _openService(entry, held: held)
          : () => _editPrograms(entry, held: held),
      onAdd: held
          ? null
          : (entry.isService ? () => _addService(entry) : () => _takeOnEverything(entry)),
      addTourId: lit ? kSubjectsTourAdd : null,
    );

    if (!held)
    {
      return Padding(padding: EdgeInsets.only(bottom: gap), child: card);
    }

    // Keyed outside, so the row keeps its state as the target wraps it.
    return MobileTourTarget(
      key: entry.key,
      id: subjectsTourCard(entry.tourId),
      inflate: EdgeInsets.fromLTRB(_tourCardInflate, _tourCardInflate, _tourCardInflate, _tourCardInflate - gap),
      radius: MobileSubjectCard.radius + _tourCardInflate,
      child: MobileRemovableRow(
        onConfirm: () => _confirmRemoval(context, entry),
        onRemoved: () => _remove(entry),
        gap: gap,
        leaving: _leaving.contains(entry.key),
        hinting: _hinted == entry.key,
        sideGap: sideGap,
        child: card,
      ),
    );
  }

  Widget _buildStatus(String text)
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

  Widget _buildBody(List<_Entry> entries, {required bool held, required int columns})
  {
    if (_loading)
    {
      return const MobileWaiting();
    }

    if (_failed)
    {
      return _buildStatus('Non è stato possibile caricare le discipline.');
    }

    final List<_Entry> shown = entries.where(_filters.keeps).toList();
    final _Entry? addable = held ? null : _firstAddable;

    if (shown.isEmpty)
    {
      if (entries.isEmpty)
      {
        return _buildStatus(held
            ? 'Nessuna disciplina o servizio a sistema.'
            : 'Nessuna disciplina o servizio da aggiungere.');
      }

      return _buildStatus(kMobileNoSearchMatch);
    }

    if (columns > 1)
    {
      return _buildGrid(shown, held: held, columns: columns, addable: addable);
    }

    // Each row owns the gap below it, so a removed row closes it up as it goes.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in shown.indexed)
          _buildCard(entry, held: held, gap: i < shown.length - 1 ? _rowGap : 0, lit: entry.key == addable?.key),
      ],
    );
  }

  // One Wrap rather than a Row per line, so a card keeps its element as it moves up a line.
  Widget _buildGrid(List<_Entry> shown, {required bool held, required int columns, _Entry? addable})
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        // A hair under the share, or rounding pushes a line's last card onto the next.
        final double width = (constraints.maxWidth - _columnGap * (columns - 1)) / columns - 0.01;

        return Wrap(
          spacing: _columnGap,
          runSpacing: _rowGap,
          children: [
            for (final (i, entry) in shown.indexed)
              MobileReflowSlot(
                key: entry.key,
                // Only the list removals happen in; the other gains cards out of sight.
                generation: held ? _removals : 0,
                spacing: _columnGap,
                child: SizedBox(
                  width: width,
                  child: _buildCard(
                    entry,
                    held: held,
                    sideGap: i % columns < columns - 1 && i < shown.length - 1 ? _columnGap : null,
                    lit: entry.key == addable?.key,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // A null value keeps every area.
  List<MobileChoice<String?>> get _areaChoices
  {
    return [
      const MobileChoice(value: null, label: 'Tutte le aree'),
      for (final area in subjectAreas) MobileChoice(value: area.value, label: area.label),
      const MobileChoice(value: kServicesFilterValue, label: 'Servizi'),
    ];
  }

  Future<void> _pickArea() async
  {
    final MobileChoice<String?>? picked = await showMobileChoiceSheet(
      context: context,
      eyebrow: _title,
      title: 'Filtra per area',
      choices: _areaChoices,
      value: _filters.area,
    );

    if (picked != null && mounted)
    {
      setState(() => _filters.area = picked.value);
    }
  }

  Widget _buildSearch()
  {
    return MobileSearchField(
      controller: _filters.controller,
      hintText: 'Cerca disciplina o servizio...',
      onChanged: (value) => setState(() => _filters.query = value),
    );
  }

  Widget _buildChips({required double margin})
  {
    final String? area = _filters.area;

    return MobileFilterChips(
      margin: margin,
      chips: [
        MobileFilterChip(
          icon: Icons.category_rounded,
          label: _areaChoices.firstWhere((choice) => choice.value == area).label,
          active: area != null,
          onTap: _pickArea,
        ),
      ],
    );
  }

  Widget _buildTitle({required bool tablet})
  {
    return Text(
      _title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 36 : 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.05,
        color: Colors.white,
      ),
    );
  }

  String _label(int index, int count) => '${_pages[index]} ($count)';

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom =
        widget.endRoom ?? MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    final double room = MediaQuery.sizeOf(context).width - margin * 2;
    final int columns =
        tablet ? (room / _minCardWidth).floor().clamp(1, _maxColumns) : 1;

    final List<_Entry> held = _heldEntries;
    final List<_Entry> open = _openEntries;

    // One header over both lists so it keeps its shape while swiping between them.
    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 4, margin, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.heading ?? _buildTitle(tablet: tablet),
              const SizedBox(height: _headerGap),
              MobilePageStrip(
                labels: [_label(0, held.length), _label(1, open.length)],
                controller: _pageController,
                tourTargets: [subjectsTourTab(0), subjectsTourTab(1)],
              ),
              const SizedBox(height: _headerGap),
            ],
          ),
        ),
        // The search and the chips lit as one; the chips run to the screen's edges.
        MobileTourTarget(
          id: kSubjectsTourFilters,
          inflate: EdgeInsets.fromLTRB(
            _tourFiltersInflate - margin,
            _tourFiltersInflate,
            _tourFiltersInflate - margin,
            _tourFiltersInflate,
          ),
          radius: _tourFiltersRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(padding: EdgeInsets.symmetric(horizontal: margin), child: _buildSearch()),
              const SizedBox(height: 12),
              _buildChips(margin: margin),
            ],
          ),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [SliverToBoxAdapter(child: header)],
        body: PageView(
          controller: _pageController,
          children: [
            _scrollable(
              _buildBody(held, held: true, columns: columns),
              side: margin,
              bottom: bottom,
              tourId: kSubjectsTourHeld,
            ),
            _scrollable(
              _buildBody(open, held: false, columns: columns),
              side: margin,
              bottom: bottom,
              tourId: kSubjectsTourOpen,
            ),
          ],
        ),
      ),
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom, required String tourId})
  {
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _load(quiet: true),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(side, _shadowRoom, side, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MobileTourTarget(
                id: tourId,
                inflate: const EdgeInsets.all(_tourListInflate),
                radius: _tourListRadius,
                child: MobileLoadSwitcher(child: child),
              ),
              const MobileTourRunway(),
            ],
          ),
        ),
      ),
    );
  }
}
