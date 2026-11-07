import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_bucket.dart';
import '../../../../core/utils/week_range.dart';
import '../../../../features/home/home_link.dart';
import '../../../../features/home/widgets/home_month_section.dart';
import '../../../../features/home/widgets/role_home_layout.dart';
import '../../../../features/lessons/widgets/calendar_lesson_block.dart';
import '../../../../features/people/models/person_face.dart';
import '../../../../shared/widgets/whole_words.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_pill.dart';
import '../../../shared/widgets/mobile_tour.dart';
import '../mobile_pupil_day.dart';
import 'mobile_link.dart';

const double _iconColumn = 44;
const double _partGap = 11;
const double _groupGap = 8;
const double _cellGap = 12;
const double _valueSize = 25;

const double _cellChevronSize = 16;

const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 14, 18, 16);

// Up to the card's edges and to the divider between the halves.
const EdgeInsets _tourHalfInflate = EdgeInsets.fromLTRB(10, 10, 10, 12);
const double _tourHalfRadius = 16;
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(24));

// An icon for a fact (closed), none for a failed reading.
class MobileCardNote
{
  final String text;
  final IconData? icon;

  const MobileCardNote(this.text, {this.icon});
}

class MobileChildMonth
{
  final PersonFace face;
  final String taxCode;
  final List<HomeFigure> figures;

  const MobileChildMonth({required this.face, required this.taxCode, required this.figures});
}

class MobileChildDayCard extends StatelessWidget
{
  final MobileChildDay child;

  final ValueChanged<HomeLink>? onLink;

  const MobileChildDayCard({super.key, required this.child, this.onLink});

  @override
  Widget build(BuildContext context)
  {
    return _ChildCard(face: child.face, parts: _dayParts(child, onLink));
  }
}

class MobileChildMonthCard extends StatelessWidget
{
  final MobileChildMonth month;

  final ValueChanged<HomeLink>? onLink;

  const MobileChildMonthCard({super.key, required this.month, this.onLink});

  @override
  Widget build(BuildContext context)
  {
    return _ChildCard(face: month.face, parts: [_Figures(month.figures, onLink: onLink)]);
  }
}

List<Widget> _dayParts(MobileChildDay child, ValueChanged<HomeLink>? onLink)
{
  return child.stays.isEmpty
      ? [
          _NoteRow(
            MobileCardNote(emptyBandLabelFor(kParentRole), icon: Icons.event_busy_rounded),
            iconColumn: true,
            onTap: onLink == null ? null : () => onLink(HomeWeekLink(pupil: child.taxCode)),
          ),
        ]
      : [for (final band in child.bands) _BandStays(band, pupil: child.taxCode, onLink: onLink)];
}

Widget _hairline() => Container(height: 1, color: AppTheme.trialInk.withValues(alpha: 0.08));

Widget _divided(List<Widget> parts)
{
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, part) in parts.indexed) ...[
        if (i > 0) ...[
          const SizedBox(height: _partGap),
          _hairline(),
          const SizedBox(height: _partGap),
        ],
        part,
      ],
    ],
  );
}

Widget _head(PersonFace face)
{
  return Text(
    face.firstName,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: AppTheme.trialInk,
    ),
  );
}

class _Figures extends StatelessWidget
{
  final List<HomeFigure> figures;

  final ValueChanged<HomeLink>? onLink;

  const _Figures(this.figures, {this.onLink});

  @override
  Widget build(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        children: [
          for (var row = 0; row < figures.length; row += 2) ...[
            if (row > 0) const SizedBox(height: _cellGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = row; i < row + 2; i++)
                  Expanded(child: i < figures.length ? _Cell(figures[i], onLink: onLink) : const SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MobileChildRowCard extends StatelessWidget
{
  // Centres the divider in a card padded 16 on the left and 18 on the right.
  static const double _dividerLeft = 29.5;
  static const double _dividerRight = 27.5;

  final PersonFace face;

  final (String, String) titles;

  // A note set stands in for its half's data.
  final MobileChildDay? day;
  final MobileCardNote? dayNote;
  final MobileChildMonth? month;
  final MobileCardNote? monthNote;

  // For a tour to light the two halves.
  final (String, String)? tourTargets;

  final ValueChanged<HomeLink>? onLink;

  const MobileChildRowCard({
    super.key,
    required this.face,
    required this.titles,
    this.day,
    this.dayNote,
    this.month,
    this.monthNote,
    this.tourTargets,
    this.onLink,
  });

  Widget _today()
  {
    if (dayNote case final MobileCardNote note)
    {
      return _NoteRow(note, iconColumn: true);
    }

    return switch (day)
    {
      final MobileChildDay day => _divided(_dayParts(day, onLink)),
      null => const SizedBox(),
    };
  }

  Widget _month()
  {
    if (monthNote case final MobileCardNote note)
    {
      return _NoteRow(note, iconColumn: false);
    }

    return switch (month)
    {
      final MobileChildMonth month => _Figures(month.figures, onLink: onLink),
      null => const SizedBox(),
    };
  }

  Widget _lit(String? id, Widget child)
  {
    if (id == null)
    {
      return child;
    }

    return MobileTourTarget(id: id, inflate: _tourHalfInflate, radius: _tourHalfRadius, child: child);
  }

  Widget _half(String title, Widget child)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppTheme.trialInk.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: _cardPadding,
      borderRadius: _cardRadius,
      child: _divided([
        _head(face),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _lit(tourTargets?.$1, _half(titles.$1, _today()))),
              const SizedBox(width: _dividerLeft),
              Container(width: 1, color: AppTheme.trialInk.withValues(alpha: 0.08)),
              const SizedBox(width: _dividerRight),
              Expanded(child: _lit(tourTargets?.$2, _half(titles.$2, _month()))),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ChildCard extends StatelessWidget
{
  final PersonFace face;
  final List<Widget> parts;

  const _ChildCard({required this.face, required this.parts});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: _cardPadding,
      borderRadius: _cardRadius,
      child: _divided([_head(face), ...parts]),
    );
  }
}

class _BandStays extends StatelessWidget
{
  final MobileBandStays band;

  final String pupil;
  final ValueChanged<HomeLink>? onLink;

  const _BandStays(this.band, {required this.pupil, this.onLink});

  Widget _head()
  {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          bandLabel(band.band).toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppTheme.trialInk.withValues(alpha: 0.6),
          ),
        ),
        if (band.isPublished) const MobilePill('Pubblicato', dense: true),
      ],
    );
  }

  Widget _group(MobileStayGroup group, {required bool headed})
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _iconColumn,
          child: Padding(
            padding: const EdgeInsets.only(top: 3, left: 5),
            child: Align(
              alignment: Alignment.topLeft,
              child: Icon(lessonModeIcon(group.mode), size: 22, color: lessonAccent(group.mode)),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headed) ...[
                _head(),
                const SizedBox(height: 2),
              ],
              for (final stay in group.stays)
                Text(
                  formatMinutesRange(stay.startMinutes, stay.endMinutes),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.trialInk,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                group.detail,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: MobilePalette.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final ValueChanged<HomeLink>? follow = onLink;

    final Widget groups = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, group) in band.groups.indexed) ...[
          if (i > 0) const SizedBox(height: _groupGap),
          _group(group, headed: i == 0),
        ],
      ],
    );

    if (follow == null)
    {
      return groups;
    }

    return MobileLink(
      onTap: () => follow(homeBandLink(band.band, isPublished: band.isPublished, pupil: pupil)),
      child: Row(
        children: [
          Expanded(child: groups),
          const MobileLinkChevron(),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget
{
  final MobileCardNote note;

  final bool iconColumn;

  final VoidCallback? onTap;

  const _NoteRow(this.note, {required this.iconColumn, this.onTap});

  @override
  Widget build(BuildContext context)
  {
    final IconData? icon = note.icon;

    return MobileLink(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: iconColumn ? _iconColumn : 4,
            child: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(icon, size: 22, color: MobilePalette.mutedText),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              note.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                fontStyle: icon == null ? FontStyle.italic : FontStyle.normal,
                color: MobilePalette.mutedText,
              ),
            ),
          ),
          if (onTap != null) const MobileLinkChevron(),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget
{
  final HomeFigure figure;

  final ValueChanged<HomeLink>? onLink;

  const _Cell(this.figure, {this.onLink});

  @override
  Widget build(BuildContext context)
  {
    final HomeLink? link = onLink == null ? null : figure.link;

    final Widget label = WholeWords(
      child: Text(
        figure.label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppTheme.trialInk.withValues(alpha: 0.62),
        ),
      ),
    );

    final Widget cell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              for (final part in figure.parts)
                TextSpan(
                  text: part.text,
                  style: part.isUnit
                      ? GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: MobilePalette.mutedText,
                        )
                      : null,
                ),
            ],
          ),
          // A word is set smaller on the numbers' line, so baselines and labels stay level.
          strutStyle: const StrutStyle(fontSize: _valueSize, height: 1.1, forceStrutHeight: true),
          style: GoogleFonts.plusJakartaSans(
            fontSize: figure.isWord ? 19 : _valueSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
            color: figure.tone == HomeFigureTone.absent ? MobilePalette.mutedText : AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 2),
        if (link == null)
          label
        else
          Row(
            children: [
              Flexible(child: label),
              // Takes no height, or this label would drop below the one beside it.
              const SizedBox(
                width: _cellChevronSize,
                height: 0,
                child: OverflowBox(
                  maxHeight: _cellChevronSize,
                  child: MobileLinkChevron(size: _cellChevronSize),
                ),
              ),
            ],
          ),
      ],
    );

    return MobileLink(onTap: link == null ? null : () => onLink!(link), child: cell);
  }
}
