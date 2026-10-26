import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_density.dart';
import '../../association/notices/notice_format.dart';
import '../update_item.dart';
import '../update_strings.dart';
import 'update_badges.dart';

const double _radius = 24;
const double _authorMaxWidth = 280;
const double _dateGap = 24;

// The version badge, its gap and the least of the title.
const double _headLeast = 220;

// Below the wide window (AppPageDensity).
const double _denseRadius = 18;
const double _denseDateGap = 16;
const double _denseBadgeHeight = 22;
const EdgeInsets _densePadding = EdgeInsets.fromLTRB(18, 12, 18, 12);
const EdgeInsets _padding = EdgeInsets.fromLTRB(26, 18, 26, 14);

class UpdateCard extends StatefulWidget
{
  final UpdateSummaryItem update;
  final VoidCallback onTap;

  const UpdateCard({super.key, required this.update, required this.onTap});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard>
{
  bool _hover = false;

  bool get _dense => AppPageDensity.of(context);

  TextStyle get _muted =>
      GoogleFonts.plusJakartaSans(fontSize: _dense ? 12.5 : 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  String _sentText()
  {
    final UpdateSummaryItem update = widget.update;
    final DateTime? editedAt = update.editedAt;
    final String sent = noticeSent(update.createdAt);

    return editedAt == null ? sent : '$sent ${updateEditedLabel(noticeDay(editedAt))}';
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

  // The version and the title, with the date at the end while the title keeps its least room, else under them.
  // On the minimal window the date is under them and the title may take a second line.
  Widget _head(double width)
  {
    final UpdateSummaryItem update = widget.update;
    final String sent = _sentText();
    final bool dense = _dense;
    final double gap = dense ? _denseDateGap : _dateGap;
    final bool under = dense && AppBreakpoints.of(context).isMinimal;
    final bool beside = !under && width - _textWidth(sent, _muted) - gap >= _headLeast;

    final Widget title = Row(
      crossAxisAlignment: under ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        dense
            ? Padding(
                padding: EdgeInsets.only(top: under ? 1 : 0),
                child: UpdateVersionBadge(update.version, height: _denseBadgeHeight, fontSize: 11),
              )
            : UpdateVersionBadge(update.version),
        SizedBox(width: dense ? 9 : 12),
        Expanded(
          child: Text(
            update.title,
            maxLines: under ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: dense ? 15.5 : 19,
              fontWeight: FontWeight.w700,
              height: under ? 1.3 : null,
              color: AppTheme.trialOcean,
            ),
          ),
        ),
        if (beside) ...[
          SizedBox(width: gap),
          Text(sent, maxLines: 1, style: _muted),
        ],
      ],
    );

    if (beside)
    {
      return title;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        SizedBox(height: dense ? 2 : 4),
        Text(sent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final UpdateSummaryItem update = widget.update;
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
                  _head(constraints.maxWidth),
                  SizedBox(height: dense ? 5 : 7),
                  Row(
                    children: [
                      ConstrainedBox(
                        // Half the card at most, so the badges keep room beside it.
                        constraints: BoxConstraints(maxWidth: math.min(_authorMaxWidth, constraints.maxWidth / 2)),
                        child: Text(
                          update.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: dense ? 12.5 : 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialTealDeep,
                          ),
                        ),
                      ),
                      SizedBox(width: dense ? 12 : 16),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: UpdateRoleBadges(roles: update.recipients, alignment: WrapAlignment.end),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: dense ? 3 : 4),
                  Text(
                    update.preview,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
