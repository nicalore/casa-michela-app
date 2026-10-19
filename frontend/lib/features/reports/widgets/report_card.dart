import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../association/notices/notice_format.dart';
import '../report_item.dart';
import '../report_strings.dart';

const double _radius = 24;
const double _badgeHeight = 24;
const double _dotSize = 10;
const double _reporterMaxWidth = 280;

class ReportUnreadDot extends StatelessWidget
{
  const ReportUnreadDot({super.key});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      width: _dotSize,
      height: _dotSize,
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
    return Container(
      height: _badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppTheme.todaySurface, borderRadius: BorderRadius.circular(_badgeHeight / 2)),
      child: Center(
        widthFactor: 1,
        child: Text(
          kind.label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
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

  TextStyle get _muted => GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  // A problem has no title: its first words stand in for one, over two lines.
  Widget _head(ReportItem report)
  {
    final bool words = report.kind == ReportKind.appProblem;
    final String text = words ? report.description ?? '' : reportTitle(report);

    return Row(
      crossAxisAlignment: words ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        if (!report.read) ...[
          Padding(
            padding: EdgeInsets.only(top: words ? 8 : 0),
            child: const ReportUnreadDot(),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            maxLines: words ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: words
                ? GoogleFonts.plusJakartaSans(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.45, color: AppTheme.trialOcean)
                : GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
          ),
        ),
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: _hover ? 1 : 0), width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _head(report)),
                  const SizedBox(width: 24),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(noticeSent(report.createdAt), maxLines: 1, style: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _reporterMaxWidth),
                    child: Text(
                      report.reporterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
                    ),
                  ),
                  if (role != null) ...[
                    const SizedBox(width: 8),
                    Text('·', style: _muted),
                    const SizedBox(width: 8),
                    Text(role, maxLines: 1, style: _muted),
                  ],
                  const Spacer(),
                  ReportKindBadge(kind: report.kind),
                ],
              ),
              if (preview != null) ...[
                const SizedBox(height: 6),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, height: 1.45, color: const Color(0xFF33495A)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
