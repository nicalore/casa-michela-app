import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_density.dart';
import '../../association/notices/notice_format.dart';
import '../report_item.dart';
import '../report_strings.dart';

const double _radius = 24;
const double _badgeHeight = 24;
const double _dotSize = 10;
const double _reporterMaxWidth = 280;
const double _dateGap = 24;
const double _headLeast = 220;

// Below the wide window (AppPageDensity).
const double _denseRadius = 18;
const double _denseBadgeHeight = 22;
const double _denseDotSize = 8;
const double _denseDateGap = 16;
const EdgeInsets _densePadding = EdgeInsets.fromLTRB(18, 12, 18, 13);
const EdgeInsets _padding = EdgeInsets.fromLTRB(26, 18, 26, 16);

class ReportUnreadDot extends StatelessWidget
{
  const ReportUnreadDot({super.key});

  @override
  Widget build(BuildContext context)
  {
    final double size = AppPageDensity.of(context) ? _denseDotSize : _dotSize;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppTheme.trialGold, shape: BoxShape.circle),
    );
  }
}

class ReportKindBadge extends StatelessWidget
{
  final ReportKind kind;

  const ReportKindBadge({super.key, required this.kind});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double height = dense ? _denseBadgeHeight : _badgeHeight;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10),
      decoration: BoxDecoration(color: AppTheme.todaySurface, borderRadius: BorderRadius.circular(height / 2)),
      child: Center(
        widthFactor: 1,
        child: Text(
          kind.label,
          style: GoogleFonts.plusJakartaSans(fontSize: dense ? 11 : 12.5, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
        ),
      ),
    );
  }
}

class ReportCard extends StatefulWidget
{
  final ReportItem report;
  final VoidCallback onTap;

  const ReportCard({super.key, required this.report, required this.onTap});

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard>
{
  bool _hover = false;

  bool get _dense => AppPageDensity.of(context);

  TextStyle get _muted =>
      GoogleFonts.plusJakartaSans(fontSize: _dense ? 12.5 : 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  // A problem has no title: its first words stand in for one, over two lines.
  Widget _head(ReportItem report)
  {
    final bool words = report.kind == ReportKind.appProblem;
    final String text = words ? report.description ?? '' : reportTitle(report);

    final bool dense = _dense;

    return Row(
      crossAxisAlignment: words ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (!report.read) ...[
          Padding(
            padding: EdgeInsets.only(top: words ? (dense ? 6 : 8) : 0),
            child: const ReportUnreadDot(),
          ),
          SizedBox(width: dense ? 8 : 10),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: words ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: words ? (dense ? 14.5 : 16.5) : (dense ? 15.5 : 19),
              fontWeight: FontWeight.w700,
              height: words ? (dense ? 1.4 : 1.45) : null,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
      ],
    );
  }

  double _textWidth(String text, TextStyle style)
  {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();

    final double width = painter.width;
    painter.dispose();

    return width;
  }

  // The date at the end while the head keeps its least room, else under it; under it always on the minimal window.
  Widget _top(ReportItem report, double width)
  {
    final String sent = noticeSent(report.createdAt);
    final bool dense = _dense;
    final double gap = dense ? _denseDateGap : _dateGap;
    final bool under = dense && AppBreakpoints.of(context).isMinimal;

    if (!under && width - _textWidth(sent, _muted) - gap >= _headLeast)
    {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _head(report)),
          SizedBox(width: gap),
          Padding(
            padding: EdgeInsets.only(top: dense ? 2 : 3),
            child: Text(sent, maxLines: 1, style: _muted),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(report),
        SizedBox(height: dense ? 2 : 4),
        Text(sent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted),
      ],
    );
  }

  String? _preview(ReportItem report)
  {
    return switch (report.kind)
    {
      ReportKind.appProblem => null,
      ReportKind.personalData => reportCorrectionsPreview(report),
      ReportKind.missingSubject => report.description,
    };
  }

  @override
  Widget build(BuildContext context)
  {
    final ReportItem report = widget.report;
    final String? preview = _preview(report);
    final String? role = report.reporterRole;
    final bool dense = _dense;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Only the border fades: the padding follows the window and must not animate.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(dense ? _denseRadius : _radius),
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: _hover ? 1 : 0), width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: dense ? _densePadding : _padding,
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _top(report, constraints.maxWidth),
                  SizedBox(height: dense ? 5 : 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: _reporterMaxWidth),
                                child: Text(
                                  report.reporterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: dense ? 12.5 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.trialTealDeep,
                                  ),
                                ),
                              ),
                            ),
                            if (role != null) ...[
                              const SizedBox(width: 8),
                              Text('·', style: _muted),
                              const SizedBox(width: 8),
                              Flexible(child: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ReportKindBadge(kind: report.kind),
                    ],
                  ),
                  if (preview != null) ...[
                    SizedBox(height: dense ? 4 : 6),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: dense ? 13.5 : 15,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: const Color(0xFF33495A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
