import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../association/notices/notice_card.dart';
import '../../association/notices/notice_format.dart';
import '../../association/notices/notice_item.dart';
import '../../association/notices/notice_strings.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';

const double _lineHeight = 36;
const double _lineRadius = 16;
const double _lineBorder = 1.5;
// The gold frame of the one under the mouse, drawn over its own border.
const double _hoverBorder = 2;
const double _linePadding = 16;
const double _pinSize = 18;
const double _lineGap = 8;

// Mirrors HOME_LIMIT in backend/app/services/notices.py.
const int _shown = 5;

// Sized for a full list from the start, so nothing moves when the lines arrive.
double _bodyHeight(int columns)
{
  final int rows = (_shown / columns).ceil();

  return rows * _lineHeight + (rows - 1) * _lineGap;
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

  const HomeNoticesSection({
    super.key,
    required this.notices,
    required this.onOpen,
    this.isLoading = false,
    this.minHeight = 0,
    this.fill = false,
    this.columns = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    return DashboardSectionCard(
      icon: Icons.campaign_rounded,
      title: kHomeNoticesTitle,
      minHeight: minHeight,
      fill: fill,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _bodyHeight(columns)),
        child: _body(),
      ),
    );
  }

  Widget _body()
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

    final List<NoticeHeadlineItem>? read = notices;

    if (read == null || read.isEmpty)
    {
      return Text(
        read == null ? kHomeNoticesUnavailable : kHomeNoNotices,
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
          if (start > 0) const SizedBox(height: _lineGap),
          Row(
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) const SizedBox(width: _lineGap + 2),
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

    // A tile like the home's other panels, a pinned one too: only its pin tells.
    final Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(_lineRadius - _lineBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _linePadding - _lineBorder),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.notice.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.day,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (pinned) ...[
              const SizedBox(width: 8),
              const NoticePinnedIcon(size: _pinSize),
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
            height: _lineHeight,
            padding: const EdgeInsets.all(_lineBorder),
            decoration: BoxDecoration(
              color: AppTheme.trialLine,
              borderRadius: BorderRadius.circular(_lineRadius),
            ),
            // Gold kept at full colour, only its alpha fading: no dark tint midway.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_lineRadius),
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _hoverBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
