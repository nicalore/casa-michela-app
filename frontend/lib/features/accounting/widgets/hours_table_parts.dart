import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_add_row_button.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/page_density.dart';
import '../models/teacher_hours_items.dart';

// What the daily summaries of teachers and of pupils share.

const double kHoursActionWidth = 60;
const double kHoursNameInset = 20;
const double kHoursFieldWidth = 88;
const double kHoursFieldHeight = 36;
const double kHoursRowHeight = 54;
const double kHoursStackGap = 6;

const double _menuWidth = 140;

// Under the scrolling part, room for its bar.
const double kHoursScrollBarRoom = 12;

const Color kHoursHeadSurface = Color(0xFFF5F8F8);
const Color kHoursRowLine = Color(0xFFEDF2F1);
const Color kHoursDashInk = Color(0xFFA9B7BF);

const Color _groupLine = Color(0xFFDDE3EA);
const Color _cellInk = Color(0xFF33495A);
const Color _offSurface = Color(0xFFFAFBFB);
const Color _menuRest = Color(0xFFF0F5F5);

// A time field's «—»: no time at all.
const int kNoTime = -1;

TextStyle hoursCellStyle({bool strong = false, Color? color}) => GoogleFonts.plusJakartaSans(
  fontSize: 14.5,
  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
  color: color ?? (strong ? AppTheme.trialOcean : _cellInk),
);

TextStyle get hoursHeadStyle => GoogleFonts.plusJakartaSans(
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
  color: AppTheme.trialMutedText,
);

TextStyle get hoursGroupStyle => GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.6,
  color: AppTheme.trialMutedText,
);

const BorderSide _groupSide = BorderSide(color: _groupLine, width: 1.5);

// Several stretches stand one under the other.
Widget hoursStack(List<Widget> fields)
{
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, field) in fields.indexed) ...[
          if (index > 0) const SizedBox(height: kHoursStackGap),
          field,
        ],
      ],
    ),
  );
}

// Tall enough for the stacked fields: a row has to know it for its rules to reach down.
double hoursRowHeight(int stacked, {required bool first})
{
  final int count = math.max(1, stacked);

  // And the rule above it, but on the first.
  return math.max(kHoursRowHeight, 18 + count * kHoursFieldHeight + (count - 1) * kHoursStackGap) + (first ? 0 : 1);
}

List<int> hoursSteps(int from, int to) => [for (var minute = from; minute <= to; minute += kQuarterHour) minute];

// A cell of a row: its width, and a rule on its left when it opens a group.
class HoursCell extends StatelessWidget
{
  final double width;
  final Widget child;
  final bool opensGroup;
  final Alignment alignment;
  final EdgeInsets padding;

  const HoursCell({
    super.key,
    required this.width,
    required this.child,
    this.opensGroup = false,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: width,
      alignment: alignment,
      padding: padding,
      decoration: opensGroup ? const BoxDecoration(border: Border(left: _groupSide)) : null,
      child: child,
    );
  }
}

// A table's least width below the wide window, grown with larger text so the times and the words keep their room.
// The wide window keeps its table as it was: none.
double hoursLeastWidth(BuildContext context, double least)
{
  return AppBreakpoints.of(context).isDense ? MediaQuery.textScalerOf(context).scale(least) : 0;
}

// The day over the table: at least [least] wide so the arrows hold still, wider rather than cut.
double hoursDayLabelWidth(BuildContext context, String text, TextStyle style, double least)
{
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();

  final double width = painter.width.ceilToDouble() + 2;
  painter.dispose();

  return math.max(least, width);
}

// What a line of the table shows: all its cells, or the name alone, or the rest that scrolls beside it.
enum HoursPart { whole, pinned, scrolled }

// A line's cells, the name always first.
Widget hoursCellsOf(List<Widget> cells, HoursPart part)
{
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: switch (part)
    {
      HoursPart.whole => cells,
      HoursPart.pinned => [cells.first],
      HoursPart.scrolled => cells.sublist(1),
    },
  );
}

// The names stay while the rest of the table, [width] in all, scrolls beside them.
class HoursSideScroll extends StatefulWidget
{
  final double nameWidth;
  final double width;
  final Widget Function(HoursPart part) part;

  const HoursSideScroll({super.key, required this.nameWidth, required this.width, required this.part});

  @override
  State<HoursSideScroll> createState() => _HoursSideScrollState();
}

class _HoursSideScrollState extends State<HoursSideScroll>
{
  final ScrollController _controller = ScrollController();

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A rule on the names' edge once the rest has moved: at rest the first group draws its own.
        ListenableBuilder(
          listenable: _controller,
          builder: (context, child) => Container(
            width: widget.nameWidth,
            foregroundDecoration: _controller.hasClients && _controller.offset > 0
                ? const BoxDecoration(border: Border(right: _groupSide))
                : null,
            child: child,
          ),
          child: widget.part(HoursPart.pinned),
        ),
        Expanded(
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: widget.width - widget.nameWidth, child: widget.part(HoursPart.scrolled)),
            ),
          ),
        ),
      ],
    );
  }
}

class HoursNote extends StatelessWidget
{
  final String text;

  const HoursNote({super.key, required this.text});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(kHoursNameInset, 13, kHoursNameInset, 13),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kHoursRowLine))),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 17, color: AppTheme.trialTurquoise),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
            ),
          ),
        ],
      ),
    );
  }
}

class HoursAddRow extends StatelessWidget
{
  final String label;
  final VoidCallback onTap;

  const HoursAddRow({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kHoursRowLine))),
      child: AppAddRowButton(label: label, dense: true, alignment: Alignment.center, onTap: onTap),
    );
  }
}

class HoursBadge extends StatelessWidget
{
  final String text;
  final bool online;

  const HoursBadge({super.key, required this.text, this.online = false});

  @override
  Widget build(BuildContext context)
  {
    final Color ink = online ? AppTheme.modifiedAccent : AppTheme.trialMutedText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: online ? AppTheme.modifiedAccentSurface : const Color(0xFFEEF2F4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (online) ...[
            Icon(Icons.videocam_outlined, size: 13, color: ink),
            const SizedBox(width: 4),
          ],
          Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
        ],
      ),
    );
  }
}

class HoursTimeField extends StatelessWidget
{
  final int? value;
  final List<int> options;
  final bool Function(int minute) allowed;
  final int? marked;
  final bool changed;
  final ValueChanged<int> onChanged;

  const HoursTimeField({
    super.key,
    required this.value,
    required this.options,
    required this.allowed,
    required this.marked,
    required this.changed,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context)
  {
    // The page's denser text: a time has to fit beside its arrow.
    return SizedBox(
      width: kHoursFieldWidth,
      child: AppPageDensity(
        dense: true,
        child: AppDropdownField<int>(
          hint: '—',
          value: value,
          hintMuted: true,
          height: kHoursFieldHeight,
          menuWidth: _menuWidth,
          fill: changed ? AppTheme.greetingGradient : null,
          markedValue: marked,
          markIcon: Icons.calendar_month_rounded,
          options: [
            for (final minute in options)
              AppDropdownOption<int>(
                value: minute,
                label: minute == kNoTime ? '—' : clockOf(minute),
                enabled: allowed(minute),
              ),
          ],
          onChanged: (minute)
          {
            if (minute != null && minute != value)
            {
              onChanged(minute);
            }
          },
        ),
      ),
    );
  }
}

// A field that cannot be used: dashed, its text grey and maybe struck.
class HoursOffField extends StatelessWidget
{
  final String text;
  final bool struck;

  const HoursOffField({super.key, required this.text, this.struck = false});

  @override
  Widget build(BuildContext context)
  {
    return CustomPaint(
      painter: const _DashedBox(),
      child: Container(
        width: kHoursFieldWidth,
        height: kHoursFieldHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _offSurface, borderRadius: BorderRadius.circular(12)),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: kHoursDashInk,
            decoration: struck ? TextDecoration.lineThrough : null,
            decorationColor: kHoursDashInk,
          ),
        ),
      ),
    );
  }
}

class _DashedBox extends CustomPainter
{
  const _DashedBox();

  @override
  void paint(Canvas canvas, Size size)
  {
    final Paint paint = Paint()
      ..color = AppTheme.trialLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), const Radius.circular(12)));

    for (final metric in outline.computeMetrics())
    {
      for (var distance = 0.0; distance < metric.length; distance += 7)
      {
        canvas.drawPath(metric.extractPath(distance, math.min(distance + 4, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox oldDelegate) => false;
}

// A confirmed value: plain, or in the greeting's gradient when it differs from the calendar.
class HoursReadOnly extends StatelessWidget
{
  final String text;
  final bool changed;
  final bool struck;

  const HoursReadOnly({super.key, required this.text, this.changed = false, this.struck = false});

  @override
  Widget build(BuildContext context)
  {
    final Widget label = Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: changed ? FontWeight.w800 : FontWeight.w600,
        color: text == '—' || struck ? kHoursDashInk : AppTheme.trialInk,
        decoration: struck ? TextDecoration.lineThrough : null,
        decorationColor: kHoursDashInk,
      ),
    );

    return SizedBox(
      height: kHoursFieldHeight,
      child: Center(
        child: changed
            ? ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => AppTheme.greetingGradient.createShader(bounds),
                child: label,
              )
            : label,
      ),
    );
  }
}

// The «⋯» of a row and its menu.
class HoursRowMenu extends StatelessWidget
{
  final List<(IconData, String, VoidCallback)> entries;

  const HoursRowMenu({super.key, required this.entries});

  @override
  Widget build(BuildContext context)
  {
    return AppAnchoredMenu(
      alignEnd: true,
      gap: 6,
      builder: (context, open, toggle) => _MenuButton(open: open, onTap: toggle),
      menu: (context, close) => AppMenuCard(
        width: 250,
        children: [
          for (final (icon, text, onTap) in entries)
            AppMenuItem(
              icon: icon,
              text: text,
              dense: true,
              onTap: ()
              {
                close();
                onTap();
              },
            ),
        ],
      ),
    );
  }
}

// Gold with its border on hover and while its menu is open.
class _MenuButton extends StatefulWidget
{
  final bool open;
  final VoidCallback onTap;

  const _MenuButton({required this.open, required this.onTap});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool lit = _hover || widget.open;

    // The gold face fades in over the grey one: a hue lerped through grey flickers.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _menuRest),
                child: SizedBox.expand(),
              ),
              AnimatedOpacity(
                opacity: lit ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.trialGoldSurface,
                    border: Border.all(color: AppTheme.trialGold, width: 2),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const Icon(Icons.more_horiz_rounded, size: 20, color: AppTheme.trialTealDeep),
            ],
          ),
        ),
      ),
    );
  }
}
