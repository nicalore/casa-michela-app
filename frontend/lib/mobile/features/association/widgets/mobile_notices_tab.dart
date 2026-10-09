import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../features/association/association_strings.dart';
import '../../../../features/association/notices/notice_card.dart' show NoticePinnedIcon;
import '../../../../features/association/notices/notice_format.dart';
import '../../../../features/association/notices/notice_item.dart';
import '../../../../features/association/notices/notice_strings.dart';
import '../../../../shared/utils/day_marks.dart';
import '../../../../shared/widgets/filter_menu.dart' show SortCriterion;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_filter_chip.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_load_switcher.dart';
import '../../../shared/widgets/mobile_month_picker.dart';
import '../../../shared/widgets/mobile_nav_sheet.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_sheet.dart';
import '../../../shared/widgets/mobile_swipe_page.dart';
import '../../settings/widgets/mobile_choice_tile.dart';
import '../mobile_notices_board.dart';
import 'mobile_association_status.dart';
import 'mobile_notice_sheet.dart';

const double _radius = 22;
const double _topRoom = 16;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const double _chipsHeight = 32;
const double _chipGap = 8;
const double _cardGap = 10;
const double _columnGap = 12;

// Narrower than this a card wraps most titles onto three lines.
const double _minCardWidth = 340;
const int _maxColumns = 3;

const double _pinSize = 19;

// A picked day's first notice comes to rest this far under the status bar.
const double _restRoom = 12;

const Duration _jumpDuration = Duration(milliseconds: 450);
const Duration _rimFade = Duration(milliseconds: 300);

// How long the picked day's cards keep their gold rim.
const Duration _flashDuration = Duration(milliseconds: 1400);

class MobileNoticesTab extends StatefulWidget
{
  final MobileNoticesBoard board;
  final double margin;
  final bool tablet;

  // The time now; a probe fixes it.
  final DateTime Function() clock;

  const MobileNoticesTab({
    super.key,
    required this.board,
    required this.margin,
    required this.tablet,
    this.clock = romeNow,
  });

  @override
  State<MobileNoticesTab> createState() => _MobileNoticesTabState();
}

class _MobileNoticesTabState extends State<MobileNoticesTab>
{
  MobileNoticesBoard get _board => widget.board;

  // Located to scroll to them, by notice id and by year.
  final Map<int, GlobalKey> _cardKeys = {};
  final Map<int, GlobalKey> _yearKeys = {};

  DateTime? _pickedDay;
  DateTime? _flashDay;
  Timer? _flashTimer;

  // A second tap while one notice is being read is dropped.
  bool _opening = false;

  DateTime get _today
  {
    final DateTime now = widget.clock();

    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState()
  {
    super.initState();
    _board.ensureLoaded();
  }

  @override
  void dispose()
  {
    _flashTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickOrder() async
  {
    final bool? oldestFirst = await showMobileSheet<bool>(
      context: context,
      builder: (context) => MobileSheet(
        eyebrow: kAssociationNoticesLabel,
        title: kNoticesSortTitle,
        body: [
          const SizedBox(height: 16),
          for (final (sort, oldest) in const [(SortCriterion.dateDesc, false), (SortCriterion.dateAsc, true)])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => finishMobileSheet(context, oldest),
                child: MobileChoiceTile(label: sort.label, chosen: oldest == _board.oldestFirst),
              ),
            ),
        ],
      ),
    );

    if (oldestFirst != null)
    {
      _board.orderOldestFirst(oldestFirst);
    }
  }

  Future<void> _pickDay() async
  {
    if (_board.loading || _board.failed)
    {
      return;
    }

    final DateTime today = _today;
    final DateTime? picked = await showMobileMonthPicker(
      context: context,
      selected: _pickedDay ?? today,
      today: today,
      first: _board.firstDay(today),
      last: today,
      loadMarks: _board.marks,
    );

    if (picked == null || !mounted)
    {
      return;
    }

    _pickedDay = picked;
    await _goToDay(DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _goToDay(DateTime day) async
  {
    final List<NoticeSummaryItem> notices = _board.shown;
    final int? found = noticeIndexForDay(notices, day, oldestFirst: _board.oldestFirst);

    if (found == null)
    {
      return;
    }

    final NoticeSummaryItem notice = notices[found];
    final bool firstOfYear = !notice.pinned &&
        notices.indexWhere((other) => !other.pinned && other.createdAt.year == notice.createdAt.year) == found;

    // The first of its year brings its heading along.
    await _reveal(firstOfYear ? _yearKeys[notice.createdAt.year] : _cardKeys[notice.id]);

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

  // By hand: ensureVisible also scrolls the outer view, whose jump resets the page.
  Future<void> _reveal(GlobalKey? key) async
  {
    final BuildContext? target = key?.currentContext;
    final NestedScrollViewState? nested = context.findAncestorStateOfType<NestedScrollViewState>();

    if (target == null || nested == null)
    {
      return;
    }

    final RenderBox box = target.findRenderObject()! as RenderBox;
    final double top = box.localToGlobal(Offset.zero).dy;

    // Under the status bar: below the SafeArea the inset reads zero, so the view's own top is used.
    final RenderBox view = nested.context.findRenderObject()! as RenderBox;
    final double wanted = view.localToGlobal(Offset.zero).dy + _restRoom;

    // The header scrolls away first, then the page.
    final ScrollPosition outer = nested.outerController.position;
    final ScrollPosition inner = Scrollable.of(target).position;
    final double scrolled = outer.pixels + inner.pixels + top - wanted;

    await Future.wait([
      outer.animateTo(scrolled.clamp(0, outer.maxScrollExtent), duration: _jumpDuration, curve: Curves.easeInOutCubic),
      inner.animateTo(
        (scrolled - outer.maxScrollExtent).clamp(0, inner.maxScrollExtent),
        duration: _jumpDuration,
        curve: Curves.easeInOutCubic,
      ),
    ]);
  }

  Future<void> _open(NoticeSummaryItem notice) async
  {
    if (_opening)
    {
      return;
    }

    _opening = true;

    try
    {
      await showMobileNotice(context, notice.id);
    }
    finally
    {
      _opening = false;
    }
  }

  Widget _buildChips()
  {
    final SortCriterion order = _board.oldestFirst ? SortCriterion.dateAsc : SortCriterion.dateDesc;

    return SizedBox(
      height: _chipsHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.margin),
        children: [
          // An order is no filter: the chip never lights up.
          MobileFilterChip(
            icon: Icons.swap_vert_rounded,
            label: order.label,
            active: false,
            onTap: _pickOrder,
          ),
          const SizedBox(width: _chipGap),
          MobileFilterChip(
            icon: Icons.calendar_month_rounded,
            label: kPickDayLabel,
            active: false,
            onTap: _pickDay,
          ),
        ],
      ),
    );
  }

  Widget _card(NoticeSummaryItem notice)
  {
    return _NoticeCard(
      key: _cardKeys.putIfAbsent(notice.id, GlobalKey.new),
      notice: notice,
      highlighted: _flashDay != null && noticeDayOf(notice) == _flashDay,
      onTap: () => _open(notice),
    );
  }

  Widget _heading(int year, {required bool first})
  {
    return Padding(
      key: _yearKeys.putIfAbsent(year, GlobalKey.new),
      padding: EdgeInsets.fromLTRB(2, first ? 0 : (widget.tablet ? 34 : 26), 2, widget.tablet ? 14 : 12),
      child: Text(
        '$year',
        style: GoogleFonts.plusJakartaSans(
          fontSize: widget.tablet ? 20 : 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: Colors.white,
        ),
      ),
    );
  }

  // Pinned ones first, under no year; then each year's heading before its notices.
  List<Widget> _sections(List<NoticeSummaryItem> notices, int columns)
  {
    final List<Widget> out = [];
    List<NoticeSummaryItem> run = [];

    void close()
    {
      if (run.isNotEmpty)
      {
        out.add(_Grid(cards: [for (final notice in run) _card(notice)], columns: columns));
        run = [];
      }
    }

    int? year;

    for (final notice in notices)
    {
      if (!notice.pinned && notice.createdAt.year != year)
      {
        close();
        year = notice.createdAt.year;
        out.add(_heading(year, first: out.isEmpty));
      }

      run.add(notice);
    }

    close();

    return out;
  }

  Widget _buildBody()
  {
    if (_board.loading)
    {
      return const MobileWaiting();
    }

    if (_board.failed)
    {
      return const MobileAssociationStatus(kAssociationLoadFailed);
    }

    final List<NoticeSummaryItem> notices = _board.shown;

    if (notices.isEmpty)
    {
      return MobileAssociationStatus(_board.isEmpty ? kNoReceivedNotices : kMobileNoSearchMatch);
    }

    final double room = MediaQuery.sizeOf(context).width - widget.margin * 2;
    final int columns = widget.tablet ? (room / _minCardWidth).floor().clamp(1, _maxColumns) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text(
            noticeCountLabel(notices.length),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        ..._sections(notices, columns),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    // Margin inside the scroll view so card shadows are not clipped while paging.
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _board.load(quiet: true),
        child: ListView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: _topRoom, bottom: bottom),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.margin),
              child: MobileSearchField(
                controller: _board.search,
                hintText: kSearchNoticeHint,
                onChanged: (_) => _board.searched(),
              ),
            ),
            const SizedBox(height: 12),
            // One child: every card is laid out, so a picked day can be reached.
            ListenableBuilder(
              listenable: _board,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChips(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: widget.margin),
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget
{
  final List<Widget> cards;
  final int columns;

  const _Grid({required this.cards, required this.columns});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i += columns) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          if (columns == 1)
            cards[i]
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: _columnGap),
                    Expanded(child: i + j < cards.length ? cards[i + j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget
{
  final NoticeSummaryItem notice;
  final bool highlighted;
  final VoidCallback onTap;

  const _NoticeCard({super.key, required this.notice, required this.highlighted, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));
    final DateTime? editedAt = notice.editedAt;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // The gold rim fades in and out: only its alpha moves, never its width.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: highlighted ? 1 : 0),
        duration: _rimFade,
        curve: Curves.easeInOut,
        builder: (context, lit, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: lit == 0
                ? null
                : Border.fromBorderSide(
                    BorderSide(
                      color: AppTheme.trialGold.withValues(alpha: lit),
                      width: MobileCurrentCard.rimWidth,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
          ),
          child: child,
        ),
        child: MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notice.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.1,
                        color: AppTheme.trialInk,
                      ),
                    ),
                  ),
                  if (notice.pinned) ...[
                    const SizedBox(width: 10),
                    const NoticePinnedIcon(size: _pinSize),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                notice.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
              ),
              const SizedBox(height: 6),
              Text(
                notice.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: AppTheme.trialInk.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editedAt == null
                          ? noticeSent(notice.createdAt)
                          : '${noticeSent(notice.createdAt)} ${noticeEditedLabel(noticeDay(editedAt))}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
                    ),
                  ),
                  if (notice.attachmentCount > 0) ...[
                    const SizedBox(width: 10),
                    Transform.rotate(
                      angle: 0.785,
                      child: const Icon(Icons.attach_file_rounded, size: 16, color: MobilePalette.mutedText),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${notice.attachmentCount}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: MobilePalette.mutedText),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
