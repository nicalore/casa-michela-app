import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/state/entity_writes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../services/api_service.dart';
import '../../../shared/utils/day_marks.dart';
import '../../../shared/widgets/app_calendar_button.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import 'notice_card.dart';
import 'notice_composer_dialog.dart';
import 'notice_details_dialog.dart';
import 'notice_embeds.dart';
import 'notice_item.dart';
import 'notice_pin_dialog.dart';
import 'notice_reading.dart';
import 'notice_strings.dart';

const double _cardGap = 14;
const double _buttonWidth = 330;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
// The last card scrolls clear of the floating button.
const double _listBottomRoom = _buttonHeight + 40;
// The scroll area reaches past the cards by this much, so their shadows are not cut.
const double _shadowRoom = 20;
const double _filterSpacing = 12;

const double _yearHeight = 28;
const double _yearGapAbove = 30;
const double _yearGapBelow = 12;

const Duration _jumpDuration = Duration(milliseconds: 500);
const Duration _settleDuration = Duration(milliseconds: 200);
// How long the picked day's cards keep their gold rim.
const Duration _flashDuration = Duration(milliseconds: 1400);

class NoticesTab extends StatefulWidget
{
  // The role whose notices are read, without writing, pinning or filtering by author; null for administrators.
  final String? readerRole;

  const NoticesTab({super.key, this.readerRole});

  @override
  State<NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends State<NoticesTab> with DestinationRefresh, EntityWrites
{
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // Kept in the server's order, newest first.
  List<NoticeSummaryItem> _notices = [];
  bool _loaded = false;
  String _searchText = '';
  bool _onlyMine = false;
  SortCriterion _sort = SortCriterion.dateDesc;

  // Located to scroll to them, by notice id and by year.
  final Map<int, GlobalKey> _cardKeys = {};
  final Map<int, GlobalKey> _yearKeys = {};

  DateTime? _pickedDay;
  DateTime? _flashDay;
  Timer? _flashTimer;

  bool get _reading => widget.readerRole != null;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    _scroll.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  void onDestinationShown() => _load(quiet: true);

  // quiet: a refresh over a list already shown, so a failure says nothing.
  Future<void> _load({bool quiet = false}) async
  {
    try
    {
      final String? role = widget.readerRole;
      final List<NoticeSummaryItem> notices =
          role == null ? await _apiService.getNotices() : await _apiService.getReceivedNotices(role);

      if (mounted)
      {
        setState(()
        {
          _notices = notices;
          _loaded = true;
        });
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _loaded = true);

      if (!quiet)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  List<NoticeSummaryItem> get _filtered
  {
    final String query = _searchText.trim().toLowerCase();
    final String? me = _apiService.lastKnownIdentity?.taxCode;

    return noticeListingOrder(
      _notices.where((notice) =>
          (!_onlyMine || notice.isWrittenBy(me)) &&
          (query.isEmpty ||
              notice.title.toLowerCase().contains(query) ||
              notice.preview.toLowerCase().contains(query) ||
              notice.authorName.toLowerCase().contains(query))),
      oldestFirst: _sort == SortCriterion.dateAsc,
    );
  }

  DateTime _dayOf(NoticeSummaryItem notice) => DateTime(notice.createdAt.year, notice.createdAt.month, notice.createdAt.day);

  DateTime get _today
  {
    final DateTime now = romeNow();

    return DateTime(now.year, now.month, now.day);
  }

  // The calendar reaches back to the first notice sent.
  DateTime get _firstDay
  {
    final DateTime today = _today;
    DateTime first = today;

    for (final notice in _notices)
    {
      final DateTime day = _dayOf(notice);

      if (day.isBefore(first))
      {
        first = day;
      }
    }

    return first;
  }

  // Dotted: the days of the notices listed.
  Future<DayMarks> _marks(DateTime from, DateTime to) async
  {
    return DayMarks(
      busy: {
        for (final notice in _filtered)
          if (!_dayOf(notice).isBefore(from) && !_dayOf(notice).isAfter(to)) _dayOf(notice),
      },
    );
  }

  // Pinned ones first, under no year; then each year's heading before its notices.
  List<_Entry> _entries(List<NoticeSummaryItem> notices)
  {
    final List<_Entry> entries = [];
    int? year;

    for (final notice in notices)
    {
      if (!notice.pinned && notice.createdAt.year != year)
      {
        year = notice.createdAt.year;
        entries.add(_Entry.year(year));
      }

      entries.add(_Entry.notice(notice));
    }

    return entries;
  }

  double _gapAbove(List<_Entry> entries, int index)
  {
    if (index == 0)
    {
      return 0;
    }

    if (entries[index].notice == null)
    {
      return _yearGapAbove;
    }

    return entries[index - 1].notice == null ? _yearGapBelow : _cardGap;
  }

  RenderBox? _boxOf(_Entry entry)
  {
    final NoticeSummaryItem? notice = entry.notice;
    final GlobalKey? key = notice == null ? _yearKeys[entry.year] : _cardKeys[notice.id];
    final RenderObject? box = key?.currentContext?.findRenderObject();

    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  // The scroll offset at which the entry heads the list, the card above just out of sight.
  double? _offsetOf(_Entry entry)
  {
    final RenderBox? box = _boxOf(entry);

    return box == null ? null : RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset - _cardGap;
  }

  // From an entry on screen, adding up those between: cards are as tall as each other unless their badges wrap.
  double? _estimatedOffsetOf(List<_Entry> entries, int target)
  {
    double? cardHeight;

    for (final entry in entries)
    {
      final RenderBox? box = _boxOf(entry);

      if (entry.notice != null && box != null)
      {
        cardHeight = box.size.height;
        break;
      }
    }

    if (cardHeight == null)
    {
      return null;
    }

    for (var index = 0; index < entries.length; index++)
    {
      final double? offset = _offsetOf(entries[index]);

      if (offset == null)
      {
        continue;
      }

      double shift = 0;

      for (var k = math.min(index, target) + 1; k <= math.max(index, target); k++)
      {
        shift += _gapAbove(entries, k) + (entries[k - 1].notice == null ? _yearHeight : cardHeight);
      }

      return offset + (target > index ? shift : -shift);
    }

    return null;
  }

  Future<void> _scrollTo(double offset, Duration duration)
  {
    final ScrollPosition position = _scroll.position;

    return _scroll.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _goToDay(DateTime day) async
  {
    setState(() => _pickedDay = day);

    final List<NoticeSummaryItem> notices = _filtered;
    final int? found = noticeIndexForDay(notices, day, oldestFirst: _sort == SortCriterion.dateAsc);

    if (found == null || !_scroll.hasClients)
    {
      return;
    }

    final List<_Entry> entries = _entries(notices);
    int target = entries.indexWhere((entry) => entry.notice == notices[found]);

    // The first of its year brings its heading along.
    if (target > 0 && entries[target - 1].notice == null)
    {
      target--;
    }

    final double? offset = _offsetOf(entries[target]) ?? _estimatedOffsetOf(entries, target);

    if (offset == null)
    {
      return;
    }

    await _scrollTo(offset, _jumpDuration);

    // Built only now: the estimate is put right if a card above was taller.
    final double? exact = _offsetOf(entries[target]);

    if (mounted && exact != null && (exact.clamp(0, _scroll.position.maxScrollExtent) - _scroll.offset).abs() > 1)
    {
      await _scrollTo(exact, _settleDuration);
    }

    if (!mounted)
    {
      return;
    }

    _flashTimer?.cancel();
    setState(() => _flashDay = day);
    _flashTimer = Timer(_flashDuration, ()
    {
      if (mounted)
      {
        setState(() => _flashDay = null);
      }
    });
  }

  void _put(NoticeSummaryItem notice)
  {
    _notices = noticeListingOrder([notice, ..._notices.where((other) => other.id != notice.id)]);
  }

  Future<bool> _create(NoticeDraft draft, void Function(String) onError)
  {
    return write(
      call: () => _apiService.createNotice(draft),
      apply: _put,
      done: kNoticeSent,
      onError: onError,
    );
  }

  Future<bool> _edit(NoticeItem notice, NoticeDraft draft, void Function(String) onError)
  {
    return write(
      call: () => _apiService.updateNotice(notice, draft),
      apply: _put,
      done: kNoticeEdited,
      onError: onError,
    );
  }

  Future<void> _delete(NoticeSummaryItem notice)
  {
    return erase(
      call: () => _apiService.deleteNotice(notice.id),
      apply: ()
      {
        _notices = _notices.where((other) => other.id != notice.id).toList();
        _cardKeys.remove(notice.id);
      },
      done: kNoticeDeleted,
    );
  }

  void _refuse(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  // A pinned notice is unpinned at once; an unpinned one asks for how long.
  Future<void> _togglePin(NoticeSummaryItem notice) async
  {
    if (notice.pinned)
    {
      await write(
        call: () => _apiService.unpinNotice(notice.id),
        apply: (_) => _put(notice.unpinned()),
        done: kNoticeUnpinned,
        onError: _refuse,
      );

      return;
    }

    final NoticePinChoice? choice = await askNoticePin(context, notice);

    if (choice == null || !mounted)
    {
      return;
    }

    await write(
      call: () => _apiService.pinNotice(notice.id, choice.until),
      apply: _put,
      done: kNoticePinned,
      onError: _refuse,
    );
  }

  Future<void> _open(NoticeSummaryItem summary) async
  {
    final NoticeItem notice;

    try
    {
      notice = await _apiService.getNotice(summary.id);
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }

      return;
    }

    if (!mounted)
    {
      return;
    }

    final NoticeImages images = NoticeImages(noticeId: notice.id);

    try
    {
      await images.preload(context, [for (final image in notice.images) image.key]);
    }
    catch (_)
    {
      // A missing image is fetched again in the message, under a placeholder.
    }

    if (!mounted)
    {
      return;
    }

    await showNoticeDetails(
      context,
      notice,
      images: images,
      own: notice.isWrittenBy(_apiService.lastKnownIdentity?.taxCode),
      // The composer stacks over the details, which close once the edit is saved.
      onEdit: (onSaved) => showNoticeComposer(
        context,
        notice: notice,
        images: images.copy(),
        onSave: (draft, onError) => _edit(notice, draft, onError),
        onEditSaved: onSaved,
      ),
      onDelete: () => _delete(notice),
    );
  }

  void _compose()
  {
    showNoticeComposer(context, onSave: _create);
  }

  List<Widget> _header(int count)
  {
    return [
      PageTransitionItem(
        slot: PageTransitionItem.header,
        child: AppSearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          hintText: kSearchNoticeHint,
        ),
      ),
      const SizedBox(height: 28),
      PageTransitionItem(
        slot: PageTransitionItem.header,
        child: Wrap(
          spacing: _filterSpacing,
          runSpacing: _filterSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSortPill(
              value: _sort,
              criteria: const [SortCriterion.dateDesc, SortCriterion.dateAsc],
              onChanged: (sort) => setState(() => _sort = sort),
            ),
            AppCalendarButton(
              selected: _pickedDay ?? _today,
              today: _today,
              first: _firstDay,
              last: _today,
              onPicked: _goToDay,
              loadMarks: _marks,
            ),
            if (!_reading) ...[
              const FilterGroupDivider(),
              AppTogglePill(
                label: kOnlyMine,
                icon: Icons.person_rounded,
                active: _onlyMine,
                onChanged: (active) => setState(() => _onlyMine = active),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      PageTransitionItem(
        slot: PageTransitionItem.header,
        child: Text(
          noticeCountLabel(count),
          style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _empty()
  {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Text(
          _notices.isEmpty ? (_reading ? kNoReceivedNotices : kNoNotices) : kNoMatchingNotices,
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
        ),
      ),
    );
  }

  Widget _list(List<NoticeSummaryItem> notices)
  {
    if (notices.isEmpty)
    {
      return SliverToBoxAdapter(child: _loaded ? _empty() : const SizedBox.shrink());
    }

    final List<_Entry> entries = _entries(notices);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(_shadowRoom, _shadowRoom, _shadowRoom, _reading ? _shadowRoom : _listBottomRoom),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) => PageTransitionItem(
          slot: PageTransitionItem.list,
          child: Padding(
            padding: EdgeInsets.only(top: _gapAbove(entries, index)),
            child: _entry(entries[index]),
          ),
        ),
      ),
    );
  }

  Widget _entry(_Entry entry)
  {
    final NoticeSummaryItem? notice = entry.notice;

    if (notice == null)
    {
      return SizedBox(
        key: _yearKeys.putIfAbsent(entry.year!, GlobalKey.new),
        height: _yearHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${entry.year}',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.trialOcean),
          ),
        ),
      );
    }

    return NoticeCard(
      key: _cardKeys.putIfAbsent(notice.id, GlobalKey.new),
      notice: notice,
      highlighted: _flashDay != null && _dayOf(notice) == _flashDay,
      onTap: () => _reading ? openNoticeReading(context, notice.id) : _open(notice),
      onPin: _reading ? null : () => _togglePin(notice),
    );
  }

  // Wider and taller than the cards it shows, by the room their shadows need.
  Widget _roomy(Widget child, {bool top = true})
  {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_shadowRoom,
          right: -_shadowRoom,
          top: top ? -_shadowRoom : 0,
          bottom: 0,
          child: child,
        ),
      ],
    );
  }

  Widget _button()
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x2E0B3350), offset: Offset(0, 10), blurRadius: 28)],
      ),
      child: AppGradientButton(
        label: kNewNoticeButton,
        icon: Icons.add_rounded,
        width: _buttonWidth,
        height: _buttonHeight,
        fontSize: _buttonFontSize,
        onPressed: _compose,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<NoticeSummaryItem> notices = _filtered;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool compact = AppBreakpoints.fromWidth(constraints.maxWidth).isCompact;

        final Widget content = compact
            ? _roomy(
                PageTransitionScrollView.slivers(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: _shadowRoom),
                      sliver: SliverToBoxAdapter(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _header(notices.length)),
                      ),
                    ),
                    _list(notices),
                  ],
                ),
                top: false,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._header(notices.length),
                  Expanded(child: _roomy(PageTransitionScrollView.slivers(controller: _scroll, slivers: [_list(notices)]))),
                ],
              );

        if (_reading)
        {
          return content;
        }

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: PageTransitionItem(slot: PageTransitionItem.header, child: _button()),
              ),
            ),
          ],
        );
      },
    );
  }
}

// A year's heading, or one notice of the list.
class _Entry
{
  final int? year;
  final NoticeSummaryItem? notice;

  const _Entry.year(int this.year) : notice = null;

  const _Entry.notice(NoticeSummaryItem this.notice) : year = null;
}
