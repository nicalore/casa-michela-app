import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../association/notices/notice_format.dart';
import '../update_item.dart';
import '../update_strings.dart';
import 'update_badges.dart';

const double _radius = 24;
const double _authorMaxWidth = 280;
const double _dateGap = 24;

// The version badge, its gap and the least of the title.
const double _headLeast = 220;

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

  TextStyle get _muted => GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

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
  Widget _head(double width)
  {
    final UpdateSummaryItem update = widget.update;
    final String sent = _sentText();
    final bool beside = width - _textWidth(sent, _muted) - _dateGap >= _headLeast;

    final Widget title = Row(
      children: [
        UpdateVersionBadge(update.version),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            update.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
          ),
        ),
        if (beside) ...[
          const SizedBox(width: _dateGap),
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
        const SizedBox(height: 4),
        Text(sent, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final UpdateSummaryItem update = widget.update;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: _hover ? 1 : 0), width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _head(constraints.maxWidth),
                const SizedBox(height: 7),
                Row(
                  children: [
                    ConstrainedBox(
                      // Half the card at most, so the badges keep room beside it.
                      constraints: BoxConstraints(maxWidth: math.min(_authorMaxWidth, constraints.maxWidth / 2)),
                      child: Text(
                        update.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: UpdateRoleBadges(roles: update.recipients, alignment: WrapAlignment.end),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  update.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, height: 1.45, color: const Color(0xFF33495A)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
