import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/rome_clock.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../features/dashboard/widgets/dashboard_birthdays_section.dart';
import '../../../../features/dashboard/widgets/dashboard_today_section.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../shared/mobile_line_breaks.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_current_card.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_opening_hours.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../mobile_home_view.dart';

const double _radius = 24;
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(_radius));

// As the closed days of the other calendars.
const double _closedAlpha = 0.43;

const double _cardGap = 12;

// As the month rows beside or before them.
const double _birthdayGap = 10;
const double _compactBirthdayGap = 8;
const double _partGap = 11;
const double _figureGap = 3;
const double _roomyFigureGap = 5;
const double _numberGap = 12;

const double _faceSize = 60;
const double _compactFaceSize = 40;

const LinearGradient _birthdayGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppTheme.modifiedAccent, AppTheme.trialGold],
);

// A band of the day; one with no opening has no status.
class MobileAdminBand
{
  final TimeBucket band;
  final DashboardBandStatus? status;

  const MobileAdminBand({required this.band, this.status});
}

// Every band, open or not, so the cards never change in number.
List<MobileAdminBand> adminDayBands(List<DashboardBandStatus> open)
{
  return [
    for (final band in TimeBucket.values)
      MobileAdminBand(band: band, status: open.where((status) => status.band == band).firstOrNull),
  ];
}

Widget _rimmed(Widget card, bool current)
{
  if (!current)
  {
    return card;
  }

  return DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: const MobileCurrentCard(_cardRadius),
    child: card,
  );
}

// The day's three bands; the open one under way wears the current rim.
class MobileAdminDayCards extends StatefulWidget
{
  final List<MobileAdminBand> bands;
  final bool roomy;

  const MobileAdminDayCards({super.key, required this.bands, this.roomy = false});

  @override
  State<MobileAdminDayCards> createState() => _MobileAdminDayCardsState();
}

class _MobileAdminDayCardsState extends State<MobileAdminDayCards>
{
  Timer? _timer;

  @override
  void initState()
  {
    super.initState();
    _scheduleTurn();
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    super.dispose();
  }

  // Rebuilds when the present crosses into the next band.
  void _scheduleTurn()
  {
    final DateTime now = romeNow();
    final int minutes = now.hour * 60 + now.minute;

    final List<int> edges = [
      for (final band in TimeBucket.values) ...[bandStartMinutes(band), bandEndMinutes(band)],
    ]..sort();

    final int? next = edges.where((edge) => edge > minutes).firstOrNull;

    _timer?.cancel();

    if (next == null)
    {
      return;
    }

    _timer = Timer(
      Duration(minutes: next - minutes, seconds: -now.second, milliseconds: -now.millisecond),
      ()
      {
        if (mounted)
        {
          setState(_scheduleTurn);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime now = romeNow();
    final int minutes = now.hour * 60 + now.minute;

    return MobileShareColumn(
      gap: _cardGap,
      children: [
        for (final band in widget.bands)
          MobileAdminBandCard(
            band: band,
            roomy: widget.roomy,
            current: band.status != null &&
                minutes >= bandStartMinutes(band.band) &&
                minutes < bandEndMinutes(band.band),
          ),
      ],
    );
  }
}

class MobileAdminBandCard extends StatelessWidget
{
  final MobileAdminBand band;
  final bool current;

  // Tablets: larger type, which the room beside the month asks for anyway.
  final bool roomy;

  const MobileAdminBandCard({super.key, required this.band, this.current = false, this.roomy = false});

  TextStyle get _numberStyle => GoogleFonts.plusJakartaSans(
        fontSize: roomy ? 28 : 25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        height: 1.1,
        color: AppTheme.trialInk,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  Widget _head(DashboardBandStatus? status)
  {
    return Row(
      children: [
        Flexible(
          child: Text(
            bandLabel(band.band),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: roomy ? 18 : 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.trialInk,
            ),
          ),
        ),
        if (status != null && status.isPublished) ...[
          const SizedBox(width: 10),
          status.isDraft
              ? const MobilePill('In bozza', tone: MobilePillTone.muted)
              : const MobilePill('Pubblicato'),
        ],
      ],
    );
  }

  Widget _top(DashboardBandStatus? status)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(status),
        const SizedBox(height: _partGap),
        Container(height: 1, color: AppTheme.trialInk.withValues(alpha: 0.08)),
        const SizedBox(height: _partGap),
      ],
    );
  }

  Widget _closed()
  {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const Icon(Icons.event_busy_rounded, size: 22, color: MobilePalette.mutedText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              kMobileClosedTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: MobilePalette.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // One figure a line; the number column holds two digits in every band, so labels line up.
  Widget _figures(BuildContext context, DashboardBandStatus status)
  {
    final TextStyle numberStyle = _numberStyle;
    final double between = roomy ? _roomyFigureGap : _figureGap;
    final double twoDigits = (TextPainter(
      text: TextSpan(text: '00', style: numberStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).width;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Table(
        columnWidths: {
          0: MaxColumnWidth(const IntrinsicColumnWidth(), FixedColumnWidth(twoDigits + _numberGap)),
          1: const FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (i, figure) in status.figures.indexed)
            TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : between, right: _numberGap),
                  child: Text('${figure.value}', textAlign: TextAlign.right, style: numberStyle),
                ),
                Text(
                  figure.label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: roomy ? 11.5 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppTheme.trialInk.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _openings(DashboardBandStatus status)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4),
      child: MobileOpeningHours(
        openings: [for (final opening in status.openings) (opening.mode, opening.hours)],
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: roomy ? 10.5 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppTheme.trialInk.withValues(alpha: 0.55),
        ),
        hoursStyle: GoogleFonts.plusJakartaSans(
          fontSize: roomy ? 13.5 : 12.5,
          fontWeight: FontWeight.w700,
          color: MobilePalette.mutedText,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        iconSize: roomy ? 17 : 16,
        iconColor: MobilePalette.mutedText,
        iconColorOf: lessonAccent,
        iconGap: 5,
        gap: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final DashboardBandStatus? status = band.status;

    // Height given beyond the content goes either side of the figures, or of the closed note.
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: status == null
          ? [_top(null), _closed(), const SizedBox()]
          : [_top(status), _figures(context, status), _openings(status)],
    );

    return _rimmed(
      MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 18, 16),
        borderRadius: _cardRadius,
        whiteAlpha: status == null ? _closedAlpha : MobileGlassPanel.cardAlpha,
        child: content,
      ),
      current,
    );
  }
}

// Phones: two to a row, a face over each name; tablets: one low row each, beside the month.
class MobileBirthdayCards extends StatelessWidget
{
  final List<DashboardBirthday> birthdays;
  final bool compact;

  const MobileBirthdayCards({super.key, required this.birthdays, this.compact = false});

  @override
  Widget build(BuildContext context)
  {
    if (compact)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, birthday) in birthdays.indexed) ...[
            if (i > 0) const SizedBox(height: _compactBirthdayGap),
            MobileBirthdayCard(birthday: birthday),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < birthdays.length; start += 2) ...[
          if (start > 0) const SizedBox(height: _birthdayGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: MobileBirthdayTile(birthday: birthdays[start])),
                const SizedBox(width: _birthdayGap),
                Expanded(
                  child: start + 1 < birthdays.length
                      ? MobileBirthdayTile(birthday: birthdays[start + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Widget _initials(DashboardBirthday birthday, double size)
{
  final String first = birthday.person.firstName;
  final String last = birthday.person.lastName;

  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: birthday.isToday ? _birthdayGradient : AppTheme.brandGradient,
    ),
    child: Text(
      '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: size * 0.33,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: Colors.white,
      ),
    ),
  );
}

// Tablets: initials only, as low as a month row.
class MobileBirthdayCard extends StatelessWidget
{
  final DashboardBirthday birthday;

  const MobileBirthdayCard({super.key, required this.birthday});

  @override
  Widget build(BuildContext context)
  {
    final bool today = birthday.isToday;

    return _rimmed(
      MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(10, 7, 16, 7),
        borderRadius: _cardRadius,
        child: Row(
          children: [
            _initials(birthday, _compactFaceSize),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${birthday.person.firstName} ${birthday.person.lastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      height: 1.2,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    birthdayCaption(birthday),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: today ? FontWeight.w700 : FontWeight.w600,
                      color: today ? AppTheme.modifiedAccent : MobilePalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      today,
    );
  }
}

// Phones: the profile photo when there is one, the initials otherwise.
class MobileBirthdayTile extends StatelessWidget
{
  final DashboardBirthday birthday;

  const MobileBirthdayTile({super.key, required this.birthday});

  @override
  Widget build(BuildContext context)
  {
    final bool today = birthday.isToday;
    final PersonItem person = birthday.person;

    return _rimmed(
      MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        borderRadius: _cardRadius,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MobileAvatar(
              firstName: person.firstName,
              lastName: person.lastName,
              imageUrl: person.profileImageUrl,
              size: _faceSize,
              gold: today,
              fallback: _initials(birthday, _faceSize),
            ),
            const SizedBox(height: 10),
            Text(
              '${person.firstName} ${person.lastName}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                height: 1.2,
                color: AppTheme.trialInk,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              withoutOrphans(birthdayCaption(birthday)),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: today ? FontWeight.w700 : FontWeight.w600,
                color: today ? AppTheme.modifiedAccent : MobilePalette.mutedText,
              ),
            ),
          ],
        ),
      ),
      today,
    );
  }
}

// A column whose children keep their own heights and share any height given beyond them.
class MobileShareColumn extends MultiChildRenderObjectWidget
{
  final double gap;

  const MobileShareColumn({super.key, required this.gap, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMobileShareColumn(gap);

  @override
  void updateRenderObject(BuildContext context, RenderMobileShareColumn renderObject)
  {
    renderObject.gap = gap;
  }
}

class _ShareParentData extends ContainerBoxParentData<RenderBox> {}

class RenderMobileShareColumn extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _ShareParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ShareParentData>
{
  RenderMobileShareColumn(this._gap);

  double _gap;

  set gap(double value)
  {
    if (value != _gap)
    {
      _gap = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child)
  {
    if (child.parentData is! _ShareParentData)
    {
      child.parentData = _ShareParentData();
    }
  }

  List<RenderBox> get _children
  {
    final List<RenderBox> children = [];
    RenderBox? child = firstChild;

    while (child != null)
    {
      children.add(child);
      child = childAfter(child);
    }

    return children;
  }

  double get _gaps => _gap * math.max(0, childCount - 1);

  @override
  double computeMinIntrinsicWidth(double height)
  {
    return _children.fold(0.0, (widest, child) => math.max(widest, child.getMinIntrinsicWidth(double.infinity)));
  }

  @override
  double computeMaxIntrinsicWidth(double height)
  {
    return _children.fold(0.0, (widest, child) => math.max(widest, child.getMaxIntrinsicWidth(double.infinity)));
  }

  @override
  double computeMinIntrinsicHeight(double width)
  {
    return _children.fold(_gaps, (sum, child) => sum + child.getMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width)
  {
    return _children.fold(_gaps, (sum, child) => sum + child.getMaxIntrinsicHeight(width));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline)
  {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints)
  {
    final double width = constraints.maxWidth;
    final double natural = _children.fold(_gaps, (sum, child) => sum + child.getMaxIntrinsicHeight(width));

    return constraints.constrain(Size(width, natural));
  }

  // Each child gets its natural height plus an equal share; a child needing more takes it.
  @override
  void performLayout()
  {
    final double width = constraints.maxWidth;
    final List<RenderBox> children = _children;
    final List<double> naturals = [for (final child in children) child.getMaxIntrinsicHeight(width)];
    final double natural = naturals.fold(_gaps, (sum, height) => sum + height);
    final double share = children.isEmpty ? 0 : math.max(0.0, constraints.minHeight - natural) / children.length;

    double y = 0;

    for (final (i, child) in children.indexed)
    {
      if (i > 0)
      {
        y += _gap;
      }

      child.layout(
        BoxConstraints(minWidth: width, maxWidth: width, minHeight: naturals[i] + share),
        parentUsesSize: true,
      );
      (child.parentData! as _ShareParentData).offset = Offset(0, y);
      y += child.size.height;
    }

    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset)
  {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position})
  {
    return defaultHitTestChildren(result, position: position);
  }
}
