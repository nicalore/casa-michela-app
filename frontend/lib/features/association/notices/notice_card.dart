import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/page_density.dart';
import 'notice_format.dart';
import 'notice_item.dart';
import 'notice_strings.dart';

const double _radius = 24;
const double _badgeHeight = 24;
const double _authorMaxWidth = 280;
const double _pinIconSize = 20;
const double _pinPadding = 4;
const Color _pinBadgeSurface = AppTheme.trialPaper;

// Inside a dense page (AppPageDensity), as the other compact lists.
const double _denseBadgeHeight = 22;
const double _densePinIconSize = 18;
const double _densePinPadding = 3;

class NoticeRoleBadges extends StatelessWidget
{
  final List<NoticeRole> roles;
  final WrapAlignment alignment;

  const NoticeRoleBadges({super.key, required this.roles, this.alignment = WrapAlignment.start});

  Widget _badge(String label, {required Color background, required Color color, required bool dense})
  {
    // Grown with the text below the wide window, where it is a tenth larger.
    return Container(
      height: dense ? null : _badgeHeight,
      constraints: dense ? const BoxConstraints(minHeight: _denseBadgeHeight) : null,
      padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular((dense ? _denseBadgeHeight : _badgeHeight) / 2),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: dense ? 1 : null,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: dense ? 11.5 : 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    if (roles.length == NoticeRole.values.length)
    {
      return _badge(kAllRoles, background: const Color(0xFFF4EEF9), color: AppTheme.trialViolet, dense: dense);
    }

    return Wrap(
      alignment: alignment,
      spacing: dense ? 5 : 6,
      runSpacing: dense ? 5 : 6,
      children: [
        for (final role in roles)
          _badge(role.plural, background: AppTheme.todaySurface, color: AppTheme.trialTealDeep, dense: dense),
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

  bool get _dense => AppPageDensity.of(context);

  TextStyle get _muted => GoogleFonts.plusJakartaSans(
        fontSize: _dense ? 12.5 : 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.trialMutedText,
      );

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
          child: Icon(Icons.attach_file_rounded, size: _dense ? 16 : 18, color: AppTheme.trialMutedText),
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
        dense: _dense,
        onTap: onPin,
        onHover: (over) => setState(() => _overPin = over),
      );
    }

    final double icon = _dense ? _densePinIconSize : _pinIconSize;
    final double padding = _dense ? _densePinPadding : _pinPadding;

    // Same room as a bare pin button, so every card is as tall, pinned or not.
    return Transform.translate(
      offset: Offset(padding, 0),
      child: SizedBox.square(
        dimension: icon + 2 * padding,
        child: notice.pinned ? Center(child: NoticePinnedIcon(size: icon)) : null,
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
        // Only the hover frame fades: the window's sizes stay out of the animation.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit ? 1 : 0), width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: _dense ? const EdgeInsets.fromLTRB(18, 12, 18, 11) : const EdgeInsets.fromLTRB(26, 18, 26, 14),
            child: _content(notice),
          ),
        ),
      ),
    );
  }

  Widget _content(NoticeSummaryItem notice)
  {
    final bool dense = _dense;

    final Widget title = Text(
      notice.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: dense ? 16.5 : 19, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
    );

    // In the smallest window the date goes under the title, which then keeps the whole line.
    final bool under = dense && AppBreakpoints.of(context).isMinimal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (under) ...[
          title,
          const SizedBox(height: 2),
          _sent(),
        ]
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              SizedBox(width: dense ? 16 : 24),
              _sent(),
            ],
          ),
        SizedBox(height: dense ? 5 : 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _authorMaxWidth),
              child: Text(
                notice.authorName,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (notice.attachmentCount > 0) _attachments(),
                  // Readers are not told whom it went to.
                  if (notice.recipients.isNotEmpty) ...[
                    if (notice.attachmentCount > 0) SizedBox(width: dense ? 10 : 12),
                    Flexible(child: NoticeRoleBadges(roles: notice.recipients, alignment: WrapAlignment.end)),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: dense ? 3 : 4),
        Row(
          children: [
            Expanded(
              child: Text(
                notice.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: dense ? 13.5 : 15,
                  fontWeight: FontWeight.w500,
                  height: dense ? 1.4 : 1.45,
                  color: const Color(0xFF33495A),
                ),
              ),
            ),
            SizedBox(width: dense ? 12 : 16),
            _pin(notice),
          ],
        ),
      ],
    );
  }
}

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

class _PinButton extends StatefulWidget
{
  final bool pinned;
  final DateTime? until;
  final bool dense;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _PinButton({
    required this.pinned,
    required this.until,
    required this.dense,
    required this.onTap,
    required this.onHover,
  });

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

  double get _iconSize => widget.dense ? _densePinIconSize : _pinIconSize;

  Widget _icon()
  {
    if (!widget.pinned)
    {
      return Icon(Icons.push_pin_outlined, size: _iconSize, color: AppTheme.trialMutedText);
    }

    return NoticePinnedIcon(size: _iconSize);
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime? until = widget.pinned ? widget.until : null;
    final bool badge = until != null;
    final double padding = widget.dense ? _densePinPadding : _pinPadding;
    final double height = _iconSize + 2 * padding;

    // Its hover room reaches into the card's padding, so a bare pin lines up with the badges.
    return Transform.translate(
      offset: Offset(badge ? 0 : padding, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AppTooltip(
            message: widget.pinned ? kUnpinTip : kPinTip,
            waitDuration: const Duration(milliseconds: 400),
            // Sizes outside the animation: only the hover colour fades.
            child: SizedBox(
              height: height,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  // Opaque ends: a translucent hover lerp flashes dark midway.
                  color: _hover ? AppTheme.trialGoldSurface : (badge ? _pinBadgeSurface : Colors.white),
                  borderRadius: BorderRadius.circular(badge ? (_pinIconSize + 2 * _pinPadding) / 2 : 10),
                ),
                child: Padding(
                  padding: badge ? EdgeInsets.only(left: widget.dense ? 8 : 10, right: 6) : EdgeInsets.all(padding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badge) ...[
                        Text(
                          pinnedUntilLabel(formatDayMonthShort(until)),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: widget.dense ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trialMutedText,
                          ),
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
        ),
      ),
    );
  }
}
