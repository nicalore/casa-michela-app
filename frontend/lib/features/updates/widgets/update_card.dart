import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../association/notices/notice_format.dart';
import '../update_item.dart';
import '../update_strings.dart';
import 'update_badges.dart';

const double _radius = 24;
const double _authorMaxWidth = 280;

// A notice's card, the version before the title.
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

  Widget _sent()
  {
    final UpdateSummaryItem update = widget.update;
    final DateTime? editedAt = update.editedAt;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: noticeSent(update.createdAt)),
          if (editedAt != null) TextSpan(text: ' ${updateEditedLabel(noticeDay(editedAt))}'),
        ],
      ),
      maxLines: 1,
      style: _muted,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                  const SizedBox(width: 24),
                  _sent(),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _authorMaxWidth),
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
    );
  }
}
