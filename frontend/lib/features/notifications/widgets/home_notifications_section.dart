import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
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

const Duration _arrival = Duration(milliseconds: 380);

// In a column the card grows with the list up to this, then scrolls.
const double _columnMaxHeight = 5 * 62 + 4 * _tileGap;

// The home card listing the notifications, newest first; every one is read by scrolling.
class HomeNotificationsSection extends StatelessWidget
{
  // Given in a row of cards: the list scrolls inside it. Null in a column.
  final double? bodyHeight;

  final double minHeight;
  final bool fill;

  // With fill and no bodyHeight: the list takes all the height the card is given.
  final bool expands;

  final Widget? heading;

  // Mockup: tiles side by side in a wide card.
  final int columns;

  const HomeNotificationsSection({
    super.key,
    this.bodyHeight,
    this.minHeight = 0,
    this.fill = false,
    this.expands = false,
    this.heading,
    this.columns = 1,
  });

  @override
  Widget build(BuildContext context)
  {
    final NotificationBoard board = NotificationBoard.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([board, DeviceNotifications.state]),
      builder: (context, _) => DashboardSectionCard(
        eyebrow: kNotificationsEyebrow,
        title: kNotificationsTitle,
        minHeight: minHeight,
        fill: fill,
        heading: heading,
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

    final double? height = bodyHeight;

    if (height == null && fill && expands)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (row != null) ...[row, const SizedBox(height: 12)],
          Expanded(child: list),
        ],
      );
    }

    if (height != null)
    {
      return SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (row != null) ...[row, const SizedBox(height: 12)],
            Expanded(child: list),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (row != null) ...[row, const SizedBox(height: 12)],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _columnMaxHeight),
          child: list,
        ),
      ],
    );
  }

  // While they are off, an empty list says nothing: the row above says enough.
  Widget _list(NotificationBoard board, {required bool showEmpty})
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.trialMutedText,
        ),
      );
    }

    return _NotificationScroll(items: items, columns: columns);
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

class _OffRow extends StatelessWidget
{
  const _OffRow();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.trialGoldSurface,
        borderRadius: BorderRadius.circular(_tileRadius),
        border: Border.all(color: AppTheme.modifiedAccentSurface, width: _tileBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_rounded, size: 22, color: AppTheme.modifiedAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kNotificationsOffTitle,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.trialInk),
                ),
                const SizedBox(height: 2),
                Text(
                  kNotificationsOffDesktop,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.modifiedAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppGradientButton(
            label: kNotificationsTurnOn.toUpperCase(),
            icon: Icons.notifications_active_rounded,
            height: 40,
            fontSize: 13,
            onPressed: () => turnNotificationsOn(context),
          ),
        ],
      ),
    );
  }
}

// Owns the controller the always-visible scrollbar needs.
class _NotificationScroll extends StatefulWidget
{
  final List<NotificationItem> items;
  final int columns;

  const _NotificationScroll({required this.items, this.columns = 1});

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
          child: widget.columns > 1 ? _grid(now) : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in widget.items.indexed)
                _ArrivingRow(
                  key: ValueKey<int>(item.id),
                  arriving: _arrived.contains(item.id),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: index < widget.items.length - 1 ? _tileGap : 0),
                    child: _NotificationTile(item: item, when: notificationWhen(item.createdAt, now: now)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// A row that arrives while the card is on show opens its room from the top and slides down into it.
extension on _NotificationScrollState
{
  Widget _grid(DateTime now)
  {
    final List<NotificationItem> items = widget.items;
    final int columns = widget.columns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var start = 0; start < items.length; start += columns)
          Padding(
            padding: EdgeInsets.only(bottom: start + columns < items.length ? _tileGap : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: _tileGap),
                    Expanded(
                      child: i < items.length
                          ? _NotificationTile(item: items[i], when: notificationWhen(items[i].createdAt, now: now))
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ArrivingRow extends StatefulWidget
{
  final bool arriving;
  final Widget child;

  const _ArrivingRow({super.key, required this.arriving, required this.child});

  @override
  State<_ArrivingRow> createState() => _ArrivingRowState();
}

class _ArrivingRowState extends State<_ArrivingRow> with SingleTickerProviderStateMixin
{
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: VisualEffects.on ? _arrival : VisualEffects.plainFade,
    value: widget.arriving ? 0 : 1,
  );

  late final Animation<double> _eased = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);

  @override
  void initState()
  {
    super.initState();

    if (widget.arriving)
    {
      _entrance.forward();
    }
  }

  @override
  void dispose()
  {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    if (!VisualEffects.of(context))
    {
      return FadeTransition(opacity: _entrance, child: widget.child);
    }

    // Bottom edge first: the row seems to come down from above the list.
    return SizeTransition(
      sizeFactor: _eased,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(opacity: _eased, child: widget.child),
    );
  }
}

class _NotificationTile extends StatefulWidget
{
  final NotificationItem item;
  final String when;

  const _NotificationTile({required this.item, required this.when});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final NotificationItem item = widget.item;

    final Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.trialPaper,
        borderRadius: BorderRadius.circular(_tileRadius - _tileBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NotificationIcon(kind: item.kind, unread: !item.read, size: _iconSize, surface: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: item.read ? FontWeight.w700 : FontWeight.w800,
                      color: item.read ? AppTheme.trialOcean : AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item.desktopBody,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppTheme.trialMutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              widget.when,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.trialMutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
          tween: Tween<double>(end: _hover ? 1 : 0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: tile,
          builder: (context, lit, child) => Container(
            padding: const EdgeInsets.all(_tileBorder),
            decoration: BoxDecoration(
              color: AppTheme.trialLine,
              borderRadius: BorderRadius.circular(_tileRadius),
            ),
            // Gold kept at full colour, only its alpha fading: no dark tint midway.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_tileRadius),
              border: Border.all(color: AppTheme.trialGold.withValues(alpha: lit), width: _hoverBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
