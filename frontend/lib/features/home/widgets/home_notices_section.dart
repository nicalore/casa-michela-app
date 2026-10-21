import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../association/notices/notice_card.dart';
import '../../association/notices/notice_format.dart';
import '../../association/notices/notice_item.dart';
import '../../association/notices/notice_strings.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';

const double _lineBorder = 1.5;
// The gold frame of the one under the mouse, drawn over its own border.
const double _hoverBorder = 2;

class _LineScale
{
  final double height;
  final double radius;
  final double padding;
  final double title;
  final double day;
  final double pin;
  final double gap;

  const _LineScale({
    required this.height,
    required this.radius,
    required this.padding,
    required this.title,
    required this.day,
    required this.pin,
    required this.gap,
  });

  static const _LineScale _wide = _LineScale(height: 36, radius: 16, padding: 16, title: 14.5, day: 13, pin: 18, gap: 8);
  static const _LineScale _dense = _LineScale(height: 30, radius: 13, padding: 12, title: 13, day: 11.5, pin: 15, gap: 6);

  static _LineScale of(BuildContext context) => AppBreakpoints.of(context).isDense ? _dense : _wide;
}

// Mirrors HOME_LIMIT in backend/app/services/notices.py.
const int kHomeNoticesShown = 5;

// Sized for a full list from the start, so nothing moves when the lines arrive.
double _bodyHeight(int shown, int columns, _LineScale scale)
{
  final int rows = (shown / columns).ceil();

  return rows * scale.height + (rows - 1) * scale.gap;
}

class HomeNoticesSection extends StatelessWidget
{
  // Null when they could not be read.
  final List<NoticeHeadlineItem>? notices;

  final bool isLoading;
  final ValueChanged<NoticeHeadlineItem> onOpen;

  final double minHeight;
  final bool fill;

  // Lines side by side, newest first along each row.
  final int columns;

  // The newest this many; the server sends up to five.
  final int shown;

  const HomeNoticesSection({
    super.key,
    required this.notices,
    required this.onOpen,
    this.isLoading = false,
    this.minHeight = 0,
    this.fill = false,
    this.columns = 1,
    this.shown = kHomeNoticesShown,
  });

  @override
  Widget build(BuildContext context)
  {
    final _LineScale scale = _LineScale.of(context);

    return DashboardSectionCard(
      icon: Icons.campaign_rounded,
      title: kHomeNoticesTitle,
      minHeight: minHeight,
      fill: fill,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _bodyHeight(shown, columns, scale)),
        child: _body(scale),
      ),
    );
  }

  Widget _body(_LineScale scale)
  {
    if (isLoading)
    {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<NoticeHeadlineItem>? all = notices;
    final List<NoticeHeadlineItem>? read = all?.take(shown).toList();

    if (read == null || read.isEmpty)
    {
      return Text(
        read == null ? kHomeNoticesUnavailable : kHomeNoNotices,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    final DateTime today = romeNow();

    Widget line(NoticeHeadlineItem notice) =>
        _NoticeLine(notice: notice, day: noticeShortDay(notice.createdAt, today: today), onTap: () => onOpen(notice));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < read.length; start += columns) ...[
          if (start > 0) SizedBox(height: scale.gap),
          Row(
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) SizedBox(width: scale.gap + 2),
                Expanded(child: i < read.length ? line(read[i]) : const SizedBox()),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _NoticeLine extends StatefulWidget
{
  final NoticeHeadlineItem notice;
  final String day;
  final VoidCallback onTap;

  const _NoticeLine({required this.notice, required this.day, required this.onTap});

  @override
  State<_NoticeLine> createState() => _NoticeLineState();
}

class _NoticeLineState extends State<_NoticeLine>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool pinned = widget.notice.pinned;
    final _LineScale scale = _LineScale.of(context);

    // A tile like the home's other panels, a pinned one too: only its pin tells.
    final Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(scale.radius - _lineBorder),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: scale.padding - _lineBorder),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: scale.title, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.day,
              style: GoogleFonts.plusJakartaSans(
                fontSize: scale.day,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (pinned) ...[
              const SizedBox(width: 8),
              NoticePinnedIcon(size: scale.pin),
            ],
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _hover ? 1 : 0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: tile,
          builder: (context, lit, child) => Container(
            height: scale.height,
            padding: const EdgeInsets.all(_lineBorder),
            decoration: BoxDecoration(
              color: AppTheme.trialLine,
              borderRadius: BorderRadius.circular(scale.radius),
            ),
            // Gold kept at full colour, only its alpha fading: no dark tint midway.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(scale.radius),
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _hoverBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
