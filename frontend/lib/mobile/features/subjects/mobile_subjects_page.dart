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
import '../../../features/people/teacher_subjects_page.dart' show kTeacherSubjectsIntro;
import '../../../features/people/widgets/competence_picker.dart' show kServicesFilterValue;
import '../../../services/api_service.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/widgets/mobile_choice_chips.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
import '../../shared/widgets/mobile_info_button.dart';
import '../../shared/widgets/mobile_info_sheet.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import '../../shared/widgets/mobile_page_strip.dart';
import '../../shared/widgets/mobile_sheet.dart';
import '../../shared/widgets/mobile_swipe_page.dart';
import '../../shared/widgets/mobile_search_field.dart';
import 'widgets/mobile_programs_sheet.dart';
import 'widgets/mobile_reflow_slot.dart';
import 'widgets/mobile_removable_row.dart';
import 'widgets/mobile_service_sheet.dart';
import 'widgets/mobile_subject_card.dart';

const String _slug = 'subjects';
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

class _Entry
{
  final String name;
  final String detail;

  final int? subjectId;
  final String? area;

  const _Entry({required this.name, required this.detail, this.subjectId, this.area});

  bool get isService => subjectId == null;

  Key get key => isService ? ValueKey('service-$name') : ValueKey('subject-$subjectId');
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

  bool _introduced = false;

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
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    if (!_introduced && widget.heading == null && !MobileHoldScope.waitingOf(context))
    {
      _introduced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _introduceOnce());
    }
  }

  @override
  void dispose()
  {
    _pageController.dispose();
    _filters.dispose();

    super.dispose();
  }

  Future<void> _introduceOnce()
  {
    final String? taxCode = _apiService.lastKnownIdentity?.taxCode;

    if (taxCode == null || !mounted)
    {
      return Future<void>.value();
    }

    return showMobileInfoSheetOnce(
      context: context,
      taxCode: taxCode,
      slug: _slug,
      title: _title,
      paragraphs: const [kTeacherSubjectsIntro, kMobileSlideToRemove],
    );
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

  Future<void> _saveCompetences(Map<int, List<int>> programs, List<String> services) async
  {
    final String? taxCode = _taxCode;

    if (_saving || taxCode == null)
    {
      return;
    }

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
    ).then((chosen) async
    {
      // Empty cancels a new discipline; a held one is given up from the sheet.
      if (chosen == null || chosen.isEmpty || !mounted)
      {
        return;
      }

      await _saveCompetences(
        {..._heldPrograms, subjectId: chosen.toList()},
        _heldServices,
      );
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
      await _addService(entry.name);
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

  Future<void> _takeOnEverything(_Entry entry)
  {
    final int subjectId = entry.subjectId!;
    final List<StudyProgramItem> programs = _programsBySubjectId[subjectId] ?? const [];

    return _saveCompetences(
      {..._heldPrograms, subjectId: [for (final program in programs) program.id]},
      _heldServices,
    );
  }

  Future<void> _addService(String name)
  {
    final List<String> services = [..._heldServices, name];

    setState(() => _heldServices = services);

    return _saveCompetences(_heldPrograms, services);
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
  }

  Widget _buildCard(_Entry entry, {required bool held, double gap = 0})
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
          : (entry.isService ? () => _addService(entry.name) : () => _takeOnEverything(entry)),
    );

    if (!held)
    {
      return Padding(padding: EdgeInsets.only(bottom: gap), child: card);
    }

    return MobileRemovableRow(
      key: entry.key,
      onConfirm: () => _confirmRemoval(context, entry),
      onRemoved: () => _remove(entry),
      gap: gap,
      leaving: _leaving.contains(entry.key),
      child: card,
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
      return _buildGrid(shown, held: held, columns: columns);
    }

    // Each row owns the gap below it, so a removed row closes it up as it goes.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, entry) in shown.indexed)
          _buildCard(entry, held: held, gap: i < shown.length - 1 ? _rowGap : 0),
      ],
    );
  }

  // One Wrap rather than a Row per line, so a card keeps its element as it moves up a line.
  Widget _buildGrid(List<_Entry> shown, {required bool held, required int columns})
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
            for (final entry in shown)
              MobileReflowSlot(
                key: entry.key,
                // Only the list removals happen in; the other gains cards out of sight.
                generation: held ? _removals : 0,
                spacing: _columnGap,
                child: SizedBox(width: width, child: _buildCard(entry, held: held)),
              ),
          ],
        );
      },
    );
  }

  List<MobileChoice> get _areaChoices
  {
    return [
      const MobileChoice(value: null, label: 'Tutte le aree'),
      for (final area in subjectAreas) MobileChoice(value: area.value, label: area.compactLabel),
      const MobileChoice(value: kServicesFilterValue, label: 'Servizi'),
    ];
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
    return MobileChoiceChips(
      choices: _areaChoices,
      value: _filters.area,
      margin: margin,
      // Pressing the filter already on does nothing: only "Tutte le aree" clears.
      onChanged: (value) => setState(() => _filters.area = value),
    );
  }

  Widget _buildTitle({required bool tablet})
  {
    return Row(
      children: [
        Expanded(
          child: Text(
            _title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: tablet ? 36 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.05,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 14),
        MobileInfoButton(
          onTap: () => showMobileInfoSheet(
            context: context,
            title: _title,
            paragraphs: const [kTeacherSubjectsIntro, kMobileSlideToRemove],
          ),
        ),
      ],
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
              ),
              const SizedBox(height: _headerGap),
              _buildSearch(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildChips(margin: margin),
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
            ),
            _scrollable(
              _buildBody(open, held: false, columns: columns),
              side: margin,
              bottom: bottom,
            ),
          ],
        ),
      ),
    );
  }

  // Margin inside the scroll view so card shadows are not clipped while paging.
  Widget _scrollable(Widget child, {required double side, required double bottom})
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
          child: MobileLoadSwitcher(child: child),
        ),
      ),
    );
  }
}
