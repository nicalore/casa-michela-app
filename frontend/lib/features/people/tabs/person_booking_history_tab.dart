import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../core/utils/time_bucket.dart';
import '../../../core/utils/week_range.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_empty_card.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_month_button.dart';
import '../../../shared/widgets/carousel_arrow_button.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/whole_words.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../association/tabs/opening_hours/calendar_bounds.dart';
import '../../bookings/widgets/booking_day_row.dart' show BookingTodayPill;
import '../../lessons/models/lesson_item.dart';
import '../../lessons/utils/opening_window.dart';
import '../../lessons/widgets/booking_fields_section.dart' show bookingTagLabels;
import '../../lessons/widgets/calendar_lesson_block.dart' show lessonModeIcon;
import '../models/booking_history_items.dart';
import '../models/person_item.dart';
import '../utils/booking_history_strings.dart';
import '../widgets/booking_history_lesson_dialog.dart';
import '../widgets/person_detail_widgets.dart';

const double _contentWidth = 1600;

const Duration _fetchFade = Duration(milliseconds: 150);
const double _fetchingOpacity = 0.45;
const Duration _hoverFade = Duration(milliseconds: 150);

const double _oneHeaderLineMinWidth = 560;
const double _figuresOneLineMinWidth = 560;

DateTime _monthOf(DateTime day) => DateTime(day.year, day.month);

String _hours(int minutes) => minutes == 0 ? '0h' : formatMinutes(minutes);

// Every size that steps down with the window, in one place.
class _Sizes
{
  final double radius;
  final double rim;
  final EdgeInsets cardPadding;
  final EdgeInsets figuresPadding;
  final double dayGap;

  // The date beside the bands from this card width, above them below it.
  final double dateBesideFrom;
  final double dateWidth;
  final double dateSize;
  final double dividerGap;

  final double labelSize;
  final double figureSize;
  final double figureLine;

  final double stretchGap;
  final double headingGap;
  final double headingSize;
  final double headingIcon;
  final double chipHeight;
  final double chipSize;
  final double bookerSize;

  final double rowGap;
  final EdgeInsets rowPadding;
  final double rowRadius;
  // Topic and kinds of lesson keep at least this each on one line, else the row folds.
  final double aboutMinWidth;
  final double nameWidth;
  final double nameSize;
  final double subjectSize;
  final double topicSize;
  final double durationWidth;
  final double durationSize;
  final double outcomeWidth;
  final double teacherSize;
  final double timeSize;
  final double columnGap;

  const _Sizes({
    required this.radius,
    required this.rim,
    required this.cardPadding,
    required this.figuresPadding,
    required this.dayGap,
    required this.dateBesideFrom,
    required this.dateWidth,
    required this.dateSize,
    required this.dividerGap,
    required this.labelSize,
    required this.figureSize,
    required this.figureLine,
    required this.stretchGap,
    required this.headingGap,
    required this.headingSize,
    required this.headingIcon,
    required this.chipHeight,
    required this.chipSize,
    required this.bookerSize,
    required this.rowGap,
    required this.rowPadding,
    required this.rowRadius,
    required this.aboutMinWidth,
    required this.nameWidth,
    required this.nameSize,
    required this.subjectSize,
    required this.topicSize,
    required this.durationWidth,
    required this.durationSize,
    required this.outcomeWidth,
    required this.teacherSize,
    required this.timeSize,
    required this.columnGap,
  });

  static const _Sizes wide = _Sizes(
    radius: 26,
    rim: 2.5,
    cardPadding: EdgeInsets.fromLTRB(26, 22, 26, 22),
    figuresPadding: EdgeInsets.fromLTRB(30, 24, 30, 22),
    dayGap: 14,
    dateBesideFrom: 820,
    dateWidth: 150,
    dateSize: 20,
    dividerGap: 22,
    labelSize: 12,
    figureSize: 27,
    figureLine: 36,
    stretchGap: 18,
    headingGap: 8,
    headingSize: 12,
    headingIcon: 16,
    chipHeight: 26,
    chipSize: 13.5,
    bookerSize: 13.5,
    rowGap: 8,
    rowPadding: EdgeInsets.fromLTRB(16, 11, 16, 11),
    rowRadius: 16,
    aboutMinWidth: 110,
    nameWidth: 200,
    nameSize: 16,
    subjectSize: 13,
    topicSize: 13.5,
    durationWidth: 64,
    durationSize: 15,
    outcomeWidth: 230,
    teacherSize: 14.5,
    timeSize: 13,
    columnGap: 16,
  );

  static const _Sizes dense = _Sizes(
    radius: 20,
    rim: 2,
    cardPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
    figuresPadding: EdgeInsets.fromLTRB(20, 14, 20, 14),
    dayGap: 10,
    dateBesideFrom: 620,
    dateWidth: 120,
    dateSize: 16,
    dividerGap: 16,
    labelSize: 10,
    figureSize: 20,
    figureLine: 28,
    stretchGap: 12,
    headingGap: 5,
    headingSize: 10.5,
    headingIcon: 14,
    chipHeight: 22,
    chipSize: 11.5,
    bookerSize: 12,
    rowGap: 5,
    rowPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
    rowRadius: 12,
    aboutMinWidth: 96,
    nameWidth: 170,
    nameSize: 14,
    subjectSize: 11.5,
    topicSize: 12,
    durationWidth: 58,
    durationSize: 13,
    outcomeWidth: 200,
    teacherSize: 13,
    timeSize: 11.5,
    columnGap: 12,
  );

  // Dense below the wide window, as the person's other tabs.
  static _Sizes of(BuildContext context) => AppBreakpoints.of(context).isDense ? dense : wide;
}

// A pupil's bookings month by month, up to today, and who taught each of them.
class PersonBookingHistoryTab extends StatefulWidget
{
  final PersonItem person;

  const PersonBookingHistoryTab({super.key, required this.person});

  @override
  State<PersonBookingHistoryTab> createState() => _PersonBookingHistoryTabState();
}

class _PersonBookingHistoryTabState extends State<PersonBookingHistoryTab>
{
  final ApiService _api = ApiService();

  final DateTime _lastMonth = _monthOf(romeNow());
  // Older days are deleted: the history stops a year back like every calendar.
  final DateTime _firstMonth = _monthOf(oldestKeptDay());

  late DateTime _month = _lastMonth;

  BookingHistoryMonth? _shown;
  Set<DateTime> _booked = const {};

  bool _fetching = true;

  // Only the last month asked for may land: the arrows can outrun the answers.
  int _asked = 0;

  List<MinistrySubjectItem>? _ministrySubjects;
  bool _opening = false;

  @override
  void initState()
  {
    super.initState();

    _load();
    _loadBookedMonths();
  }

  Future<void> _load() async
  {
    final int asked = ++_asked;

    try
    {
      final BookingHistoryMonth shown = await _api.getBookingHistory(widget.person.fiscalCode, _month);

      if (mounted && asked == _asked)
      {
        setState(()
        {
          _shown = shown;
          _fetching = false;
        });
      }
    }
    catch (error)
    {
      if (!mounted || asked != _asked)
      {
        return;
      }

      setState(()
      {
        _shown = null;
        _fetching = false;
      });
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  // Only the picker's dots: a failure leaves it without them.
  Future<void> _loadBookedMonths() async
  {
    try
    {
      final Set<DateTime> booked = await _api.getBookingHistoryMonths(widget.person.fiscalCode);

      if (mounted)
      {
        setState(() => _booked = booked);
      }
    }
    catch (_)
    {
      return;
    }
  }

  void _go(DateTime month)
  {
    if (month == _month)
    {
      return;
    }

    setState(()
    {
      _month = month;
      _fetching = true;
    });
    _load();
  }

  Future<void> _openLesson(int id) async
  {
    if (_opening)
    {
      return;
    }

    _opening = true;

    try
    {
      final List<MinistrySubjectItem> subjects = _ministrySubjects ?? await _api.getMinistrySubjects();
      final LessonItem lesson = await _api.getLesson(id);

      _ministrySubjects = subjects;

      if (!mounted)
      {
        return;
      }

      await showBookingHistoryLessonDialog(context: context, lesson: lesson, ministrySubjects: subjects);
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
    finally
    {
      _opening = false;
    }
  }

  Widget _buildMonthNav(bool dense, {required bool stretched})
  {
    final double size = dense ? 38 : CarouselArrowButton.defaultSize;
    final double iconSize = dense ? 18 : CarouselArrowButton.defaultIconSize;

    final Widget label = Text(
      formatMonthYear(_month),
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: GoogleFonts.plusJakartaSans(
        fontSize: dense ? 13.5 : 17,
        fontWeight: FontWeight.w700,
        color: AppTheme.trialOcean,
      ),
    );

    // Grown with the text, a tenth larger below the wide window.
    final double labelWidth = MediaQuery.textScalerOf(context).scale(dense ? 130 : 190);

    return Row(
      mainAxisSize: stretched ? MainAxisSize.max : MainAxisSize.min,
      children: [
        AppMonthButton(
          selected: _month,
          first: _firstMonth,
          last: _lastMonth,
          marked: _booked,
          size: size,
          startAligned: stretched,
          onPicked: _go,
        ),
        const SizedBox(width: 12),
        CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          size: size,
          iconSize: iconSize,
          isDisabled: _month == _firstMonth,
          onTap: () => _go(DateTime(_month.year, _month.month - 1)),
        ),
        const SizedBox(width: 8),
        if (stretched)
          Expanded(child: Center(child: label))
        else
          SizedBox(width: labelWidth, child: Center(child: label)),
        const SizedBox(width: 8),
        CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          size: size,
          iconSize: iconSize,
          isDisabled: _month == _lastMonth,
          onTap: () => _go(DateTime(_month.year, _month.month + 1)),
        ),
      ],
    );
  }

  Widget _buildMonth(BookingHistoryMonth shown, _Sizes sizes, double gap)
  {
    if (shown.days.isEmpty)
    {
      return Center(child: AppEmptyCard(icon: Icons.event_busy_rounded, message: noBookingsMessage(_month)));
    }

    final DateTime today = romeNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FiguresCard(shown: shown, sizes: sizes),
        SizedBox(height: gap),
        for (final day in shown.days) ...[
          if (day != shown.days.first) SizedBox(height: sizes.dayGap),
          _DayCard(
            day: day,
            isToday: isSameDate(day.date, today),
            sizes: sizes,
            onOpenLesson: _openLesson,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final BookingHistoryMonth? shown = _shown;
    final bool dense = AppBreakpoints.of(context).isDense;
    final _Sizes sizes = _Sizes.of(context);
    final double gap = personCardGap(context);

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double width = constraints.maxWidth.clamp(0, _contentWidth);
        final bool stretched = width < _oneHeaderLineMinWidth;

        return ScrollEdgeFade(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: pageTransitionBlocks([
                    if (stretched)
                      _buildMonthNav(dense, stretched: true)
                    else
                      Row(
                        children: [
                          const Spacer(),
                          _buildMonthNav(dense, stretched: false),
                        ],
                      ),
                    SizedBox(height: gap),
                    if (shown == null && _fetching)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise)),
                      )
                    else if (shown != null)
                      AnimatedOpacity(
                        duration: _fetchFade,
                        opacity: _fetching ? _fetchingOpacity : 1,
                        child: _buildMonth(shown, sizes, gap),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget
{
  final String label;
  final String value;
  final _Sizes sizes;

  const _Figure({required this.label, required this.value, required this.sizes});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WholeWords(
          child: Text(
            label.toUpperCase(),
            style: PageHeading.style().copyWith(fontSize: sizes.labelSize, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(sizes.figureLine),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: sizes.figureSize,
                fontWeight: FontWeight.w800,
                color: AppTheme.trialOcean,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FiguresCard extends StatelessWidget
{
  final BookingHistoryMonth shown;
  final _Sizes sizes;

  const _FiguresCard({required this.shown, required this.sizes});

  Widget _line(List<Widget> cells)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, cell) in cells.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(child: cell),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> cells = [
      _Figure(label: kBookedDaysLabel, value: '${shown.bookedDays}', sizes: sizes),
      _Figure(label: kBookedHoursLabel, value: _hours(shown.bookedMinutes), sizes: sizes),
      _Figure(label: modeLabel(kPresenceMode), value: _hours(shown.presenceMinutes), sizes: sizes),
      _Figure(label: modeLabel(kOnlineMode), value: _hours(shown.onlineMinutes), sizes: sizes),
    ];

    return Container(
      padding: sizes.figuresPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(sizes.radius + 6),
        boxShadow: AppTheme.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          if (constraints.maxWidth >= _figuresOneLineMinWidth)
          {
            return _line(cells);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line(cells.sublist(0, 2)),
              const SizedBox(height: 12),
              _line(cells.sublist(2)),
            ],
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget
{
  final BookingHistoryDay day;
  final bool isToday;
  final _Sizes sizes;
  final ValueChanged<int> onOpenLesson;

  const _DayCard({required this.day, required this.isToday, required this.sizes, required this.onOpenLesson});

  Widget _buildDayName()
  {
    return DescenderRoom(
      child: Text(
        formatDayMonthFull(day.date),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: sizes.dateSize,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: AppTheme.trialOcean,
        ),
      ),
    );
  }

  Widget _buildDateColumn()
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppEyebrow(weekdayFullName(day.date.weekday)),
            if (isToday) const BookingTodayPill(),
          ],
        ),
        const SizedBox(height: 4),
        _buildDayName(),
      ],
    );
  }

  Widget _buildDateLine()
  {
    return Wrap(
      spacing: 8,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppEyebrow(weekdayFullName(day.date.weekday)),
        _buildDayName(),
        if (isToday) const BookingTodayPill(),
      ],
    );
  }

  Widget _buildStretches()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stretch in day.stretches) ...[
          if (stretch != day.stretches.first) SizedBox(height: sizes.stretchGap),
          _StretchBlock(stretch: stretch, sizes: sizes, onOpenLesson: onOpenLesson),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        if (constraints.maxWidth >= sizes.dateBesideFrom)
        {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: sizes.dateWidth, child: _buildDateColumn()),
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: sizes.dividerGap),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppTheme.trialLine)),
                  ),
                  child: _buildStretches(),
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateLine(),
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(vertical: sizes.stretchGap * 0.75),
              color: AppTheme.trialLine,
            ),
            _buildStretches(),
          ],
        );
      },
    );

    return Container(
      padding: EdgeInsets.all(sizes.rim),
      decoration: BoxDecoration(
        gradient: isToday ? AppTheme.greetingGradient : null,
        borderRadius: BorderRadius.circular(sizes.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Container(
        padding: sizes.cardPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(sizes.radius - sizes.rim),
        ),
        child: content,
      ),
    );
  }
}

class _StretchBlock extends StatelessWidget
{
  final BookingHistoryStretch stretch;
  final _Sizes sizes;
  final ValueChanged<int> onOpenLesson;

  const _StretchBlock({required this.stretch, required this.sizes, required this.onOpenLesson});

  bool get _online => stretch.mode == kOnlineMode;

  Widget _buildHeading()
  {
    final Widget name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(lessonModeIcon(stretch.mode), size: sizes.headingIcon, color: AppTheme.trialMutedText),
        const SizedBox(width: 5),
        Flexible(
          child: WholeWords(
            child: Text(
              '${modeLabel(stretch.mode)} · ${bandLabel(stretch.band)}'.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: sizes.headingSize,
                fontWeight: FontWeight.w700,
                letterSpacing: sizes == _Sizes.dense ? 1.1 : 1.4,
                height: 1.2,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
        ),
      ],
    );

    final Widget chip = Container(
      height: sizes.chipHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes == _Sizes.dense ? 8 : 11),
      decoration: BoxDecoration(
        color: _online ? AppTheme.modifiedAccentSurface : AppTheme.todaySurface,
        borderRadius: BorderRadius.circular(sizes.chipHeight / 2),
      ),
      child: Align(
        widthFactor: 1,
        child: Text(
          formatTimeRange(stretch.startTime, stretch.endTime),
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.plusJakartaSans(
            fontSize: sizes.chipSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: _online ? AppTheme.modifiedAccent : AppTheme.trialTealDeep,
          ),
        ),
      ),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [name, chip],
    );
  }

  Widget _buildBooker()
  {
    final TextStyle muted = GoogleFonts.plusJakartaSans(
      fontSize: sizes.bookerSize,
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: AppTheme.trialMutedText,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_rounded, size: sizes.bookerSize + 3, color: AppTheme.trialMutedText.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Flexible(
          child: WholeWords(
            child: Text.rich(
              TextSpan(
                style: muted,
                children: [
                  const TextSpan(text: '$kBookedByLabel '),
                  TextSpan(
                    text: stretch.booker.fullName,
                    style: muted.copyWith(fontWeight: FontWeight.w700, color: AppTheme.trialInk),
                  ),
                  TextSpan(text: ' · ${bookedAtText(stretch.bookedAt)}'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The booker at the far end while both fit on the line, else under the band's name.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildHeading(),
            _buildBooker(),
          ],
        ),
        for (final booking in stretch.bookings) ...[
          SizedBox(height: booking == stretch.bookings.first ? sizes.headingGap : sizes.rowGap),
          _BookingRow(booking: booking, sizes: sizes, onOpenLesson: onOpenLesson),
        ],
      ],
    );
  }
}

// A booked discipline and the lessons that taught it; a tap opens the lesson.
class _BookingRow extends StatefulWidget
{
  final BookingHistoryBooking booking;
  final _Sizes sizes;
  final ValueChanged<int> onOpenLesson;

  const _BookingRow({required this.booking, required this.sizes, required this.onOpenLesson});

  @override
  State<_BookingRow> createState() => _BookingRowState();
}

class _BookingRowState extends State<_BookingRow>
{
  bool _hover = false;

  BookingHistoryBooking get _booking => widget.booking;

  _Sizes get _sizes => widget.sizes;

  bool get _opens => _booking.lessons.isNotEmpty;

  String? get _second => _booking.kind == BookingHistoryKind.service ? kServiceLabel : _booking.subject;

  String get _topic => _booking.topic?.trim() ?? '';

  String get _kinds => bookingTagLabels(_booking.tags).join(', ');

  Widget _buildName()
  {
    final String? second = _second;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WholeWords(
          child: Text(
            _booking.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _sizes.nameSize,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        if (second != null)
          WholeWords(
            child: Text(
              second,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _sizes.subjectSize,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppTheme.trialMutedText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMuted(String text)
  {
    return WholeWords(
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: _sizes.topicSize,
          fontWeight: FontWeight.w500,
          height: 1.35,
          color: AppTheme.trialMutedText,
        ),
      ),
    );
  }

  Widget _buildDuration({TextAlign align = TextAlign.right})
  {
    return Text(
      formatMinutes(_booking.duration),
      maxLines: 1,
      softWrap: false,
      textAlign: align,
      style: GoogleFonts.plusJakartaSans(
        fontSize: _sizes.durationSize,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppTheme.trialInk,
      ),
    );
  }

  Widget _buildLessonLine(BookingHistoryLesson lesson)
  {
    final Widget line = Row(
      children: [
        Expanded(
          child: DescenderRoom(
            child: Text(
              lesson.teacher.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: _sizes.teacherSize,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: AppTheme.trialInk,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatTimeRange(lesson.startTime, lesson.endTime),
          maxLines: 1,
          softWrap: false,
          style: GoogleFonts.plusJakartaSans(
            fontSize: _sizes.timeSize,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: AppTheme.trialMutedText,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    // With several lessons each line opens its own; the row opens the first.
    if (_booking.lessons.length < 2)
    {
      return line;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onOpenLesson(lesson.id),
      child: line,
    );
  }

  Widget _buildOutcome()
  {
    if (!_booking.published)
    {
      return Row(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: _sizes.teacherSize + 1, color: AppTheme.trialMutedText.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Expanded(
            child: WholeWords(
              child: Text(
                kAwaitingCalendar,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: _sizes.teacherSize - 0.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_booking.lessons.isEmpty)
    {
      return Text('—', style: GoogleFonts.plusJakartaSans(fontSize: _sizes.teacherSize, color: AppTheme.trialMutedText));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lesson in _booking.lessons) ...[
          if (lesson != _booking.lessons.first) const SizedBox(height: 3),
          _buildLessonLine(lesson),
        ],
      ],
    );
  }

  Widget _buildOneLine()
  {
    final double gap = _sizes.columnGap;

    return Row(
      children: [
        SizedBox(width: _sizes.nameWidth, child: _buildName()),
        SizedBox(width: gap),
        Expanded(child: _buildMuted(_topic)),
        SizedBox(width: gap),
        Expanded(child: _buildMuted(_kinds)),
        SizedBox(width: gap),
        SizedBox(width: _sizes.durationWidth, child: _buildDuration()),
        SizedBox(width: gap),
        SizedBox(width: _sizes.outcomeWidth, child: _buildOutcome()),
      ],
    );
  }

  Widget _buildFolded()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildName()),
            const SizedBox(width: 12),
            _buildDuration(),
          ],
        ),
        // Narrow: the kinds of lesson on a line of their own, under the topic.
        if (_topic.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildMuted(_topic),
        ],
        if (_kinds.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildMuted(_kinds),
        ],
        const SizedBox(height: 8),
        _buildOutcome(),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget content = LayoutBuilder(
      builder: (context, constraints)
      {
        final _Sizes s = _sizes;
        final double fixed = s.nameWidth + s.durationWidth + s.outcomeWidth + 5 * s.columnGap;

        return constraints.maxWidth - fixed >= 2 * s.aboutMinWidth ? _buildOneLine() : _buildFolded();
      },
    );

    final Widget row = AnimatedContainer(
      duration: _hoverFade,
      padding: _sizes.rowPadding,
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(_sizes.rowRadius),
        border: Border.all(
          color: AppTheme.trialGold.withValues(alpha: _hover && _opens ? 1 : 0),
          width: 1.5,
        ),
      ),
      child: content,
    );

    if (!_opens)
    {
      return row;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onOpenLesson(_booking.lessons.first.id),
        child: row,
      ),
    );
  }
}
