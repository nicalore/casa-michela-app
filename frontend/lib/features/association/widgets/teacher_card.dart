import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/overflow_tooltip_text.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/models/person_item.dart';

const double _radius = 30;

const double _avatarSize = 56;
const double _avatarGap = 16;

const double _nameFontSize = 17;

const double _markSize = 20;
const double _markGap = 12;

class TeacherCard extends StatefulWidget
{
  static const double width = 320;

  static const double height = 84;

  final PersonItem teacher;

  final bool disliked;

  final VoidCallback onTap;

  const TeacherCard({
    super.key,
    required this.teacher,
    required this.disliked,
    required this.onTap,
  });

  @override
  State<TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<TeacherCard>
{
  bool _isHovering = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: TeacherCard.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: _isHovering ? AppTheme.trialGold : AppTheme.trialGold.withValues(alpha: 0),
              width: 2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              PersonAvatar(person: widget.teacher, size: _avatarSize),
              const SizedBox(width: _avatarGap),
              Expanded(
                child: OverflowTooltipText(
                  text: '${widget.teacher.firstName} ${widget.teacher.lastName}',
                  maxLines: 2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: _nameFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ),
              if (widget.disliked) ...[
                const SizedBox(width: _markGap),
                const Icon(Icons.thumb_down_rounded, size: _markSize, color: AppTheme.trialDanger),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
