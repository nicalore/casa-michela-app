import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../models/activity_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import 'calendar_activity_block.dart';
import 'calendar_booking_card.dart';
import 'calendar_lesson_block.dart';

const double _cardRadius = 16;

const double _accentBarWidth = 4;
const double _accentBarInset = 9;

// An activity waiting to be assigned; it can go to any teacher.
class CalendarActivityCard extends StatefulWidget
{
  final ActivityItem activity;

  final BookingDragMode dragMode;

  final VoidCallback? onOpen;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  final ValueListenable<CarriedPlacement>? carriedAt;

  const CalendarActivityCard({
    super.key,
    required this.activity,
    this.dragMode = BookingDragMode.immediate,
    this.onOpen,
    this.onDragChanged,
    this.carriedAt,
  });

  @override
  State<CalendarActivityCard> createState() => _CalendarActivityCardState();
}

class _CalendarActivityCardState extends State<CalendarActivityCard>
{
  bool _hover = false;

  ActivityItem get _activity => widget.activity;

  bool get _canDrag => widget.dragMode != BookingDragMode.none && !_activity.isLocked;

  String get _status
  {
    if (_activity.isLocked)
    {
      return 'Calendario pubblicato: riportalo in bozza';
    }

    return switch (widget.dragMode)
    {
      BookingDragMode.immediate => 'Trascinala su un docente per assegnarla',
      BookingDragMode.longPress => 'Tieni premuto e trascinala su un docente',
      BookingDragMode.none => 'Aprila per assegnarla a un docente',
    };
  }

  Widget _wrapDraggable(Widget card)
  {
    if (!_canDrag)
    {
      return card;
    }

    final payload = ActivityDragPayload.of(_activity);

    void started() => widget.onDragChanged?.call(payload);
    void ended(_) => widget.onDragChanged?.call(null);
    void canceled(_, _) => widget.onDragChanged?.call(null);

    final feedback = CalendarDragFeedback(
      title: _activity.name,
      mode: kPresenceMode,
      lead: kActivityWord,
      accent: kActivityAccent,
      hours: formatMinutes(kDefaultActivityMinutes),
      carriedAt: widget.carriedAt,
    );

    final faded = CalendarLeftBehind(opacity: 0.35, child: card);

    if (widget.dragMode == BookingDragMode.longPress)
    {
      return LongPressDraggable<CalendarDragPayload>(
        data: payload,
        onDragStarted: started,
        onDragEnd: ended,
        onDraggableCanceled: canceled,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: faded,
        child: card,
      );
    }

    return Draggable<CalendarDragPayload>(
      data: payload,
      onDragStarted: started,
      onDragEnd: ended,
      onDraggableCanceled: canceled,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: faded,
      child: card,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final description = _activity.description;
    final onOpen = widget.onOpen;

    final Widget card = MouseRegion(
      cursor: onOpen == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: _hover ? AppTheme.trialGold : AppTheme.trialLine,
              width: 1.5,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                bottom: 12,
                left: _accentBarInset,
                width: _accentBarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kActivityAccent,
                    borderRadius: BorderRadius.circular(_accentBarWidth / 2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_accentBarInset + _accentBarWidth + 9, 11, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_canDrag) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.drag_indicator, size: 16, color: kActivityAccent),
                          ),
                          const SizedBox(width: 4),
                        ]
                        else ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(kActivityIcon, size: 15, color: kActivityAccent),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            _activity.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: AppTheme.trialOcean,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: AppTheme.trialInk,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppTheme.trialMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return _wrapDraggable(card);
  }
}
