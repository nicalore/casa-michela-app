import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/show_more_button.dart';
import '../../dashboard/widgets/dashboard_section_card.dart';
import '../device_notifications.dart';
import '../notification_board.dart';
import '../notification_item.dart';
import '../notification_look.dart';
import '../notification_strings.dart';
import 'desktop_notifications_offer.dart';

const double _tileRadius = 16;
const double _tileBorder = 1.5;
// The gold frame of the one under the mouse, drawn over its own border.
const double _hoverBorder = 2;
const double _tileGap = 8;
const double _iconSize = 36;

const double _denseTileRadius = 13;
const double _denseTileGap = 6;
const double _denseIconSize = 28;

// The two buttons under the time.
const double _actionSize = 28;
const double _actionIcon = 17;
const double _actionGap = 6;
const double _denseActionSize = 24;
const double _denseActionIcon = 15;
const double _denseActionGap = 5;
const Color _actionGround = Color(0x0F122438);
const double _actionRim = 1.5;
const Duration _hoverFade = Duration(milliseconds: 150);

const Duration _arrival = Duration(milliseconds: 380);
const Duration _leaving = Duration(milliseconds: 280);

// In a column the card grows with the list up to this, then scrolls.
const double _columnMaxHeight = 5 * 62 + 4 * _tileGap;

class HomeNotificationsSection extends StatelessWidget
{
  final double minHeight;
  final bool fill;

  // Given where the page scrolls: the newest this many, the rest one click away, never a scroll inside.
  final int? limit;

  const HomeNotificationsSection({
    super.key,
    this.minHeight = 0,
    this.fill = false,
    this.limit,
  });

  @override
  Widget build(BuildContext context)
  {
    final NotificationBoard board = NotificationBoard.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([board, DeviceNotifications.state]),
      builder: (context, _) => DashboardSectionCard(
        icon: Icons.notifications_rounded,
        title: kNotificationsTitle,
        minHeight: minHeight,
        fill: fill,
        action: board.unread > 0 ? _NewBadge(count: board.unread) : null,
        child: _body(context, board),
      ),
    );
  }

  Widget _body(BuildContext context, NotificationBoard board)
  {
    final NotificationSwitch device = DeviceNotifications.state.value;
    final bool off = device == NotificationSwitch.off || device == NotificationSwitch.blocked;

    final Widget list = _list(board, showEmpty: !off);
    final Widget? row = off ? const _OffRow() : null;

    // Given its height from outside, the list fills it and scrolls inside.
    if (fill)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (row != null) ...[row, SizedBox(height: AppBreakpoints.of(context).isDense ? _denseTileGap : 12)],
          Expanded(child: list),
        ],
      );
    }

    final int? limit = this.limit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (row != null) ...[row, SizedBox(height: AppBreakpoints.of(context).isDense ? _denseTileGap : 12)],
        if (limit != null)
          _list(board, showEmpty: !off, limit: limit)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _columnMaxHeight),
            child: list,
          ),
      ],
    );
  }

  // While they are off, an empty list says nothing: the row above says enough.
  Widget _list(NotificationBoard board, {required bool showEmpty, int? limit})
  {
    if (board.loading)
    {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: AppTheme.trialTurquoise),
        ),
      );
    }

    final List<NotificationItem>? items = board.items;

    if (items == null || items.isEmpty)
    {
      if (items != null && !showEmpty)
      {
        return const SizedBox.shrink();
      }

      return Text(
        items == null ? kNotificationsUnavailable : kNotificationsEmpty,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    if (limit != null)
    {
      return _CappedNotifications(items: items, limit: limit);
    }

    return _NotificationScroll(items: items);
  }
}

class _CappedNotifications extends StatefulWidget
{
  final List<NotificationItem> items;
  final int limit;

  const _CappedNotifications({required this.items, required this.limit});

  @override
  State<_CappedNotifications> createState() => _CappedNotificationsState();
}

class _CappedNotificationsState extends State<_CappedNotifications>
{
  bool _all = false;

  @override
  Widget build(BuildContext context)
  {
    final DateTime now = romeNow();
    final bool dense = AppBreakpoints.of(context).isDense;
    final double gap = dense ? _denseTileGap : _tileGap;

    final List<NotificationItem> items = widget.items;
    final bool more = items.length > widget.limit;
    final List<NotificationItem> shown = _all || !more ? items : items.take(widget.limit).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, item) in shown.indexed)
          _ListRow(
            key: ValueKey<int>(item.id),
            arriving: false,
            onLeft: () => NotificationBoard.instance.delete(item),
            builder: (leave) => Padding(
              padding: EdgeInsets.only(bottom: index < shown.length - 1 ? gap : 0),
              child: _NotificationTile(item: item, when: notificationWhen(item.createdAt, now: now), onDelete: leave),
            ),
          ),
        if (more) ...[
          const SizedBox(height: 10),
          Center(
            child: ShowMoreButton(
              label: _all ? kNotificationsShowFewer : kNotificationsShowAll,
              open: _all,
              onTap: () => setState(() => _all = !_all),
            ),
          ),
        ],
      ],
    );
  }
}

class _NewBadge extends StatelessWidget
{
  final int count;

  const _NewBadge({required this.count});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.modifiedAccentSurface,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        notificationsNewLabel(count),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppTheme.modifiedAccent,
        ),
      ),
    );
  }
}

// Below the wide window the button goes under the words, sized like the tiles: beside them it squeezed the title.
class _OffRow extends StatelessWidget
{
  const _OffRow();

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppBreakpoints.of(context).isDense;

    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kNotificationsOffTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 13 : 14.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          kNotificationsOffDesktop,
          style: GoogleFonts.plusJakartaSans(
            fontSize: dense ? 12 : 13.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: AppTheme.modifiedAccent,
          ),
        ),
      ],
    );

    final Widget button = AppGradientButton(
      label: kNotificationsTurnOn.toUpperCase(),
      icon: Icons.notifications_active_rounded,
      height: dense ? 32 : 40,
      fontSize: dense ? 11.5 : 13,
      horizontalPadding: dense ? 14 : 30,
      onPressed: () => turnNotificationsOn(context),
    );

    return Container(
      padding: dense ? const EdgeInsets.fromLTRB(11, 9, 11, 10) : const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.trialGoldSurface,
        borderRadius: BorderRadius.circular(dense ? _denseTileRadius : _tileRadius),
        border: Border.all(color: AppTheme.modifiedAccentSurface, width: _tileBorder),
      ),
      child: Row(
        crossAxisAlignment: dense ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: dense ? 19 : 22, color: AppTheme.modifiedAccent),
          SizedBox(width: dense ? 9 : 12),
          Expanded(
            child: dense
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [words, const SizedBox(height: 8), button],
                  )
                : words,
          ),
          if (!dense) ...[
            const SizedBox(width: 12),
            button,
          ],
        ],
      ),
    );
  }
}

// Owns the controller the always-visible scrollbar needs.
class _NotificationScroll extends StatefulWidget
{
  final List<NotificationItem> items;

  const _NotificationScroll({required this.items});

  @override
  State<_NotificationScroll> createState() => _NotificationScrollState();
}

class _NotificationScrollState extends State<_NotificationScroll>
{
  final ScrollController _controller = ScrollController();

  // Those listed when the card was built come in still; later ones come in from the top.
  final Set<int> _known = {};
  final Set<int> _arrived = {};

  @override
  void initState()
  {
    super.initState();
    _known.addAll(widget.items.map((item) => item.id));
  }

  @override
  void didUpdateWidget(_NotificationScroll oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    for (final item in widget.items)
    {
      if (_known.add(item.id))
      {
        _arrived.add(item.id);
      }
    }
  }

  @override
  void dispose()
  {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final DateTime now = romeNow();

    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: ScrollEdgeFade(
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in widget.items.indexed)
                _ListRow(
                  key: ValueKey<int>(item.id),
                  arriving: _arrived.contains(item.id),
                  onLeft: () => NotificationBoard.instance.delete(item),
                  builder: (leave) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index < widget.items.length - 1
                          ? (AppBreakpoints.of(context).isDense ? _denseTileGap : _tileGap)
                          : 0,
                    ),
                    child: _NotificationTile(
                      item: item,
                      when: notificationWhen(item.createdAt, now: now),
                      onDelete: leave,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A row arriving while the card shows opens its room from the top and slides down into it;
// one deleted closes its room before it leaves the list.
class _ListRow extends StatefulWidget
{
  final bool arriving;
  final VoidCallback onLeft;
  final Widget Function(VoidCallback leave) builder;

  const _ListRow({super.key, required this.arriving, required this.onLeft, required this.builder});

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> with SingleTickerProviderStateMixin
{
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: VisualEffects.on ? _arrival : VisualEffects.plainFade,
    reverseDuration: VisualEffects.on ? _leaving : VisualEffects.plainFade,
    value: widget.arriving ? 0 : 1,
  );

  late final Animation<double> _eased = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);

  bool _leavingList = false;
  bool _left = false;

  @override
  void initState()
  {
    super.initState();

    if (widget.arriving)
    {
      _entrance.forward();
    }
  }

  void _leave()
  {
    if (_leavingList)
    {
      return;
    }

    setState(() => _leavingList = true);
    _entrance.reverse().then((_) => _done());
  }

  void _done()
  {
    if (!_left)
    {
      _left = true;
      widget.onLeft();
    }
  }

  @override
  void dispose()
  {
    // Taken off the screen midway: the deletion still goes through.
    if (_leavingList && !_left)
    {
      scheduleMicrotask(_done);
    }

    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget child = IgnorePointer(ignoring: _leavingList, child: widget.builder(_leave));

    if (!VisualEffects.of(context))
    {
      return FadeTransition(opacity: _entrance, child: child);
    }

    // Arriving, bottom edge first: the row seems to come down from above the list.
    // Leaving, the rows below rise into its room.
    return SizeTransition(
      sizeFactor: _eased,
      alignment: _leavingList ? Alignment.topCenter : Alignment.bottomCenter,
      child: FadeTransition(opacity: _eased, child: child),
    );
  }
}

class _NotificationTile extends StatefulWidget
{
  final NotificationItem item;
  final String when;
  final VoidCallback onDelete;

  const _NotificationTile({required this.item, required this.when, required this.onDelete});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile>
{
  bool _hover = false;

  // Over one of its buttons the tile is not lit: a click there does not open it.
  bool _overAction = false;

  void _actionHover(bool over) => setState(() => _overAction = over);

  @override
  Widget build(BuildContext context)
  {
    final NotificationItem item = widget.item;
    final bool dense = AppBreakpoints.of(context).isDense;
    final double radius = dense ? _denseTileRadius : _tileRadius;

    final Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(radius - _tileBorder),
      ),
      child: Padding(
        padding: dense ? const EdgeInsets.fromLTRB(8, 7, 11, 8) : const EdgeInsets.fromLTRB(10, 10, 14, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationIcon(
              kind: item.kind,
              unread: !item.read,
              size: dense ? _denseIconSize : _iconSize,
              surface: Colors.white,
            ),
            SizedBox(width: dense ? 9 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: dense ? 13 : 15,
                      fontWeight: item.read ? FontWeight.w700 : FontWeight.w800,
                      color: item.read ? AppTheme.trialOcean : AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.desktopBody,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: dense ? 11.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: dense ? 9 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.when,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: dense ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.trialMutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: dense ? 5 : 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TileAction(
                      icon: item.read ? Icons.remove_done_rounded : Icons.done_all_rounded,
                      tip: item.read ? kNotificationMarkUnread : kNotificationMarkRead,
                      color: AppTheme.trialTealDeep,
                      dense: dense,
                      onHover: _actionHover,
                      onTap: () => NotificationBoard.instance.toggleRead(item),
                    ),
                    SizedBox(width: dense ? _denseActionGap : _actionGap),
                    _TileAction(
                      icon: Icons.delete_outline_rounded,
                      tip: kNotificationDelete,
                      color: AppTheme.trialDanger,
                      dense: dense,
                      onHover: _actionHover,
                      onTap: widget.onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => NotificationBoard.instance.open(item),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _hover && !_overAction ? 1 : 0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: tile,
          builder: (context, lit, child) => Container(
            padding: const EdgeInsets.all(_tileBorder),
            decoration: BoxDecoration(
              color: AppTheme.trialLine,
              borderRadius: BorderRadius.circular(radius),
            ),
            // Gold kept at full colour, only its alpha fading: no dark tint midway.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _hoverBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TileAction extends StatefulWidget
{
  final IconData icon;
  final String tip;
  final Color color;
  final bool dense;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  const _TileAction({
    required this.icon,
    required this.tip,
    required this.color,
    required this.dense,
    required this.onHover,
    required this.onTap,
  });

  @override
  State<_TileAction> createState() => _TileActionState();
}

class _TileActionState extends State<_TileAction>
{
  bool _hover = false;

  void _setHover(bool hover)
  {
    setState(() => _hover = hover);
    widget.onHover(hover);
  }

  @override
  Widget build(BuildContext context)
  {
    final double size = widget.dense ? _denseActionSize : _actionSize;

    return AppTooltip(
      message: widget.tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _hover ? 1 : 0),
            duration: _hoverFade,
            curve: Curves.easeOut,
            // Gold as every hover, laid over the grey: no muddy shade midway.
            builder: (context, lit, child) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.alphaBlend(AppTheme.trialGoldSurface.withValues(alpha: lit), _actionGround),
                border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _actionRim),
              ),
              child: child,
            ),
            child: Icon(widget.icon, size: widget.dense ? _denseActionIcon : _actionIcon, color: widget.color),
          ),
        ),
      ),
    );
  }
}
