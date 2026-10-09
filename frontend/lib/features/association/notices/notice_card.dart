import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import 'notice_format.dart';
import 'notice_item.dart';
import 'notice_strings.dart';

const double _radius = 24;
const double _badgeHeight = 24;
const double _authorMaxWidth = 280;
const double _pinIconSize = 20;
const double _pinPadding = 4;
const Color _pinBadgeSurface = AppTheme.trialPaper;

class NoticeRoleBadges extends StatelessWidget
{
  final List<NoticeRole> roles;
  final WrapAlignment alignment;

  const NoticeRoleBadges({super.key, required this.roles, this.alignment = WrapAlignment.start});

  Widget _badge(String label, {required Color background, required Color color})
  {
    return Container(
      height: _badgeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(_badgeHeight / 2)),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (roles.length == NoticeRole.values.length)
    {
      return _badge(kAllRoles, background: const Color(0xFFF4EEF9), color: AppTheme.trialViolet);
    }

    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final role in roles) _badge(role.plural, background: AppTheme.todaySurface, color: AppTheme.trialTealDeep),
      ],
    );
  }
}

class NoticeCard extends StatefulWidget
{
  final NoticeSummaryItem notice;
  final VoidCallback onTap;

  // Null for readers: the pin only says it is pinned.
  final VoidCallback? onPin;

  // Rimmed in gold for a moment, as the day picked in the calendar.
  final bool highlighted;

  const NoticeCard({super.key, required this.notice, required this.onTap, required this.onPin, this.highlighted = false});

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard>
{
  bool _hover = false;
  // The pin is a button of its own: over it the card does not light up.
  bool _overPin = false;

  TextStyle get _muted => GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText);

  Widget _sent()
  {
    final NoticeSummaryItem notice = widget.notice;
    final DateTime? editedAt = notice.editedAt;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: noticeSent(notice.createdAt)),
          if (editedAt != null) TextSpan(text: ' ${noticeEditedLabel(noticeDay(editedAt))}'),
        ],
      ),
      maxLines: 1,
      style: _muted,
    );
  }

  Widget _attachments()
  {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: 0.785,
          child: const Icon(Icons.attach_file_rounded, size: 18, color: AppTheme.trialMutedText),
        ),
        const SizedBox(width: 3),
        Text('${widget.notice.attachmentCount}', style: _muted.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _pin(NoticeSummaryItem notice)
  {
    final VoidCallback? onPin = widget.onPin;

    if (onPin != null)
    {
      return _PinButton(
        pinned: notice.pinned,
        until: notice.pinnedUntil,
        onTap: onPin,
        onHover: (over) => setState(() => _overPin = over),
      );
    }

    // Where a bare pin button sits, and as tall: pinned or not, every card is.
    return Transform.translate(
      offset: const Offset(_pinPadding, 0),
      child: SizedBox.square(
        dimension: _pinIconSize + 2 * _pinPadding,
        child: notice.pinned ? const Center(child: NoticePinnedIcon(size: _pinIconSize)) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final NoticeSummaryItem notice = widget.notice;
    final bool lit = (_hover && !_overPin) || widget.highlighted;

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
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit ? 1 : 0), width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: _content(notice),
        ),
      ),
    );
  }

  Widget _content(NoticeSummaryItem notice)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                notice.title,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _authorMaxWidth),
              child: Text(
                notice.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (notice.attachmentCount > 0) _attachments(),
                  // Readers are not told whom it went to.
                  if (notice.recipients.isNotEmpty) ...[
                    if (notice.attachmentCount > 0) const SizedBox(width: 12),
                    Flexible(child: NoticeRoleBadges(roles: notice.recipients, alignment: WrapAlignment.end)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                notice.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, height: 1.45, color: const Color(0xFF33495A)),
              ),
            ),
            const SizedBox(width: 16),
            _pin(notice),
          ],
        ),
      ],
    );
  }
}

// The filled pin in the violet and ocean gradient.
class NoticePinnedIcon extends StatelessWidget
{
  final double size;

  const NoticePinnedIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context)
  {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.greetingGradient.createShader(bounds),
      child: Icon(Icons.push_pin_rounded, size: size, color: Colors.white),
    );
  }
}

// Bare pin, gradient when pinned; a pin with a last day sits in a grey badge with it.
class _PinButton extends StatefulWidget
{
  final bool pinned;
  final DateTime? until;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _PinButton({required this.pinned, required this.until, required this.onTap, required this.onHover});

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton>
{
  bool _hover = false;

  void _setHover(bool hover)
  {
    setState(() => _hover = hover);
    widget.onHover(hover);
  }

  Widget _icon()
  {
    if (!widget.pinned)
    {
      return const Icon(Icons.push_pin_outlined, size: _pinIconSize, color: AppTheme.trialMutedText);
    }

    return const NoticePinnedIcon(size: _pinIconSize);
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime? until = widget.pinned ? widget.until : null;
    final bool badge = until != null;

    // Its hover room reaches into the card's padding, so a bare pin lines up with the badges.
    return Transform.translate(
      offset: Offset(badge ? 0 : _pinPadding, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: widget.pinned ? kUnpinTip : kPinTip,
            waitDuration: const Duration(milliseconds: 400),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: _pinIconSize + 2 * _pinPadding,
              padding: badge ? const EdgeInsets.only(left: 10, right: 6) : const EdgeInsets.all(_pinPadding),
              decoration: BoxDecoration(
                // Opaque ends: a translucent hover lerp flashes dark midway.
                color: _hover ? AppTheme.trialGoldSurface : (badge ? _pinBadgeSurface : Colors.white),
                borderRadius: BorderRadius.circular(badge ? (_pinIconSize + 2 * _pinPadding) / 2 : 10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (badge) ...[
                    Text(
                      pinnedUntilLabel(formatDayMonthShort(until)),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.trialMutedText),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _icon(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
