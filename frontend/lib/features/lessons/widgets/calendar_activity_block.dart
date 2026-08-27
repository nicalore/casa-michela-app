import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../models/activity_item.dart';
import '../utils/lesson_placement.dart';
import '../utils/opening_window.dart';
import 'calendar_lesson_block.dart';

const IconData kActivityIcon = Icons.event_note_rounded;

const Color kActivityAccent = AppTheme.trialOcean;

const Color kActivitySurface = AppTheme.trialPaper;

const String kActivityWord = 'Attività';

// Below this width the block only fits the hours and the name.
const double _descriptionFrom = 132;

const double _narrowFrom = 110;

String activityHours(ScheduledActivity scheduled)
{
  return formatMinutesRange(scheduled.startMinutes, scheduled.endMinutes);
}

String activityDetails(ScheduledActivity scheduled)
{
  return [
    '${activityHours(scheduled)} · ${formatMinutes(scheduled.minutes)}',
    scheduled.name,
    ?scheduled.description,
  ].join('\n');
}

class CalendarActivityBlock extends StatefulWidget
{
  final ScheduledActivity scheduled;

  final double width;

  final VoidCallback? onTap;

  final bool isMovable;

  final void Function(bool isLeftEdge, Offset globalPosition)? onEdgeDrag;

  final VoidCallback? onEdgeDragEnd;

  final ValueListenable<CarriedPlacement>? carriedAt;

  // Returns the activity to the panel; unlike a lesson, it is not deleted.
  final VoidCallback? onDroppedOutside;

  final void Function(CalendarDragPayload? payload)? onDragChanged;

  const CalendarActivityBlock({
    super.key,
    required this.scheduled,
    required this.width,
    this.onTap,
    this.isMovable = false,
    this.onEdgeDrag,
    this.onEdgeDragEnd,
    this.carriedAt,
    this.onDroppedOutside,
    this.onDragChanged,
  });

  @override
  State<CalendarActivityBlock> createState() => _CalendarActivityBlockState();
}

class _CalendarActivityBlockState extends State<CalendarActivityBlock>
{
  bool _isHovering = false;

  bool _isResizing = false;

  ScheduledActivity get _scheduled => widget.scheduled;

  bool get _isNarrow => widget.width < _narrowFrom;

  bool get _saysDescription
  {
    return _scheduled.description != null && widget.width >= _descriptionFrom;
  }

  // Tooltip only when the block is hiding something.
  bool get _isClipped
  {
    return _isNarrow || (_scheduled.description != null && !_saysDescription);
  }

  bool get _canResize
  {
    return widget.isMovable && widget.onEdgeDrag != null && widget.width >= kMinResizableBlockWidth;
  }

  Widget _withSideGap(Widget child)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kBlockSideGap),
      child: child,
    );
  }

  Widget _buildHandle({required bool isLeft})
  {
    return CalendarBlockHandle(
      isLeft: isLeft,
      onDrag: (position)
      {
        if (!_isResizing)
        {
          setState(() => _isResizing = true);
        }

        widget.onEdgeDrag!(isLeft, position);
      },
      onDragEnd: ()
      {
        if (_isResizing)
        {
          setState(() => _isResizing = false);
        }

        widget.onEdgeDragEnd?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final body = _buildBody();

    if (!widget.isMovable)
    {
      return _withSideGap(body);
    }

    final payload = ActivityDragPayload.of(_scheduled.activity);

    final Widget movable = Draggable<CalendarDragPayload>(
      data: payload,
      onDragStarted: () => widget.onDragChanged?.call(payload),
      onDragEnd: (_) => widget.onDragChanged?.call(null),
      affinity: Axis.horizontal,
      feedback: CalendarDragFeedback(
        title: _scheduled.name,
        mode: kPresenceMode,
        lead: kActivityWord,
        accent: kActivityAccent,
        hours: activityHours(_scheduled),
        width: widget.width,
        awayLabel: kRemoveFromCalendarAwayLabel,
        carriedAt: widget.carriedAt,
      ),
      childWhenDragging: CalendarLeftBehind(child: body),
      onDraggableCanceled: (_, _)
      {
        widget.onDragChanged?.call(null);
        widget.onDroppedOutside?.call();
      },
      child: body,
    );

    if (!_canResize)
    {
      return _withSideGap(movable);
    }

    return Stack(
      children: [
        Positioned.fill(child: _withSideGap(movable)),
        Positioned(left: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: true)),
        Positioned(right: 0, top: 0, bottom: 0, width: kBlockHandleWidth, child: _buildHandle(isLeft: false)),
      ],
    );
  }

  Widget _buildBody()
  {
    final Widget block = MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: _isNarrow ? 6 : 10, vertical: 6),
          decoration: BoxDecoration(
            color: kActivitySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovering ? AppTheme.trialGold : kActivityAccent.withValues(alpha: 0.35),
              width: _isHovering ? 2 : 1.4,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: kActivityAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: _isNarrow ? 4 : 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(kActivityIcon, size: 12, color: kActivityAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _isNarrow
                                ? formatTimeOfDayShort(timeOfDayFromMinutes(_scheduled.startMinutes))
                                : activityHours(_scheduled),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              height: 1.15,
                              color: kActivityAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scheduled.name,
                      maxLines: _saysDescription ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: AppTheme.trialInk,
                      ),
                    ),
                    if (_saysDescription) ...[
                      const SizedBox(height: 1),
                      Text(
                        _scheduled.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: AppTheme.trialMutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget shown = AnimatedOpacity(
      duration: const Duration(milliseconds: 90),
      opacity: _isResizing ? 0 : 1,
      child: block,
    );

    if (!_isClipped)
    {
      return shown;
    }

    return Tooltip(
      message: activityDetails(_scheduled),
      decoration: AppTheme.tooltipDecoration,
      textStyle: AppTheme.tooltipTextStyle,
      waitDuration: kCalendarTooltipWait,
      child: shown,
    );
  }
}
