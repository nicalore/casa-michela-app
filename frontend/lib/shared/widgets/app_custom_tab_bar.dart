import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

const Color _idleTabText = Color(0xFF6B7A8A);
const Color _indicatorColor = Color(0xFF12A0D7);
const Color _baselineColor = Color(0x22003C82);
const Color _arrowHoverBackground = Color(0x0A003C82);

const double _barHeight = 54;
const double _arrowWidth = 48;
const double _tabFontSize = 18;
const double _indicatorHeight = 3;
const double _baselineHeight = 2;

// Horizontal breathing room added to the measured text width to obtain the
// clickable width of a tab.
const double _tabHorizontalPadding = 44;

// Tabs are always measured at their bold weight, which is the widest state:
// otherwise selecting a tab would make it grow and shift its neighbours.
const FontWeight _measurementFontWeight = FontWeight.w700;

const int _measurementAttempts = 8;
const Duration _measurementRetryDelay = Duration(milliseconds: 200);

// Differences below this threshold are sub pixel noise and must not trigger a
// relayout, or the widget would keep rebuilding itself.
const double _widthTolerance = 0.5;

// Keeps the invisible measuring row far outside any viewport, so it can be laid
// out by Flutter without ever being seen.
const double _offscreenLeft = -100000;

class AppCustomTabBar extends StatefulWidget
{
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double maxWidth;

  const AppCustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.maxWidth,
  });

  @override
  State<AppCustomTabBar> createState() => _AppCustomTabBarState();
}

class _AppCustomTabBarState extends State<AppCustomTabBar>
{
  final List<List<int>> _pages = [];
  final List<double> _pageOffsets = [];

  List<double> _tabWidths = [];
  List<GlobalKey> _measureKeys = [];

  double _totalTabsWidth = 0;
  int _currentPage = 0;
  bool _measurementScheduled = false;

  double get _arrowsTotalWidth => _arrowWidth * 2;

  @override
  void initState()
  {
    super.initState();
    _measureKeys = _buildMeasureKeys();
    _updateLayout(widget.maxWidth, _estimateWidths(widget.tabs));
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(AppCustomTabBar oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    final tabsChanged = !listEquals(oldWidget.tabs, widget.tabs);
    final needsLayout = oldWidget.maxWidth != widget.maxWidth || tabsChanged;
    final needsPageUpdate = oldWidget.selectedIndex != widget.selectedIndex;

    if (tabsChanged)
    {
      _measureKeys = _buildMeasureKeys();
    }

    if (needsLayout)
    {
      // When the labels are unchanged the already measured widths are reused,
      // so a resize does not flash a frame laid out on rough estimates.
      final startingWidths = (!tabsChanged && _tabWidths.length == widget.tabs.length)
          ? _tabWidths
          : _estimateWidths(widget.tabs);

      _updateLayout(widget.maxWidth, startingWidths);
      _scheduleMeasurement();

      return;
    }

    if (needsPageUpdate)
    {
      final newPage = _pages.indexWhere((page) => page.contains(widget.selectedIndex));

      if (newPage != -1 && newPage != _currentPage)
      {
        _currentPage = newPage;
      }
    }
  }

  List<GlobalKey> _buildMeasureKeys() => List.generate(widget.tabs.length, (_) => GlobalKey());

  TextStyle get _measurementStyle => GoogleFonts.plusJakartaSans(
        fontSize: _tabFontSize,
        fontWeight: _measurementFontWeight,
      );

  // Rough estimate used only for the very first frame, before a real
  // measurement exists: it just avoids a zero width tab bar for an instant and
  // is almost always corrected right after.
  List<double> _estimateWidths(List<String> tabs)
  {
    final style = _measurementStyle;

    return tabs.map((tab)
    {
      final painter = TextPainter(
        text: TextSpan(text: tab, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      return painter.size.width + _tabHorizontalPadding;
    }).toList();
  }

  // Reads the real width of every label from the invisible measuring row.
  // Returns null while the render objects are not laid out yet.
  List<double>? _readMeasuredWidths()
  {
    final measured = <double>[];

    for (final key in _measureKeys)
    {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null || !renderBox.hasSize)
      {
        return null;
      }

      measured.add(renderBox.size.width + _tabHorizontalPadding);
    }

    return measured;
  }

  bool _widthsDiffer(List<double> measured)
  {
    for (var i = 0; i < measured.length; i++)
    {
      if ((measured[i] - _tabWidths[i]).abs() > _widthTolerance)
      {
        return true;
      }
    }

    return false;
  }

  void _scheduleMeasurement({int attemptsLeft = _measurementAttempts})
  {
    if (_measurementScheduled)
    {
      return;
    }

    _measurementScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      _measurementScheduled = false;

      if (!mounted)
      {
        return;
      }

      final measured = _readMeasuredWidths();

      // Either not laid out yet, or out of sync with the widths currently in
      // use: retry on the next frame instead of committing a wrong layout.
      if (measured == null || measured.length != _tabWidths.length)
      {
        if (attemptsLeft > 0)
        {
          _scheduleMeasurement(attemptsLeft: attemptsLeft - 1);
        }

        return;
      }

      if (_widthsDiffer(measured))
      {
        setState(() => _updateLayout(widget.maxWidth, measured));
      }

      // Polling continues for a few rounds even after a successful
      // measurement, to absorb a late font swap that changes the text metrics.
      if (attemptsLeft > 0)
      {
        Future.delayed(_measurementRetryDelay, ()
        {
          if (mounted)
          {
            _scheduleMeasurement(attemptsLeft: attemptsLeft - 1);
          }
        });
      }
    });
  }

  // Splits the tabs into pages that fit the available width. A page break is
  // introduced as soon as the next tab would overflow, and the offset of each
  // page is the cumulative width of the pages before it.
  void _updateLayout(double maxWidth, List<double> tabWidths)
  {
    _tabWidths = tabWidths;
    _totalTabsWidth = _tabWidths.fold(0.0, (sum, width) => sum + width);
    _pages.clear();
    _pageOffsets.clear();

    if (_totalTabsWidth <= maxWidth)
    {
      _pages.add(List.generate(widget.tabs.length, (index) => index));
      _pageOffsets.add(0.0);
    }
    else
    {
      // Paging means the arrows are shown, and they eat into the width left
      // for the tabs themselves.
      final availableWidthForTabs =
          (maxWidth - _arrowsTotalWidth).clamp(1.0, double.infinity);

      var currentPage = <int>[];
      var currentWidth = 0.0;
      var currentOffset = 0.0;

      for (var i = 0; i < widget.tabs.length; i++)
      {
        if (currentPage.isEmpty)
        {
          currentPage.add(i);
          currentWidth = _tabWidths[i];
        }
        else if (currentWidth + _tabWidths[i] <= availableWidthForTabs)
        {
          currentPage.add(i);
          currentWidth += _tabWidths[i];
        }
        else
        {
          _pages.add(currentPage);
          _pageOffsets.add(currentOffset);
          currentOffset += currentWidth;
          currentPage = [i];
          currentWidth = _tabWidths[i];
        }
      }

      if (currentPage.isNotEmpty)
      {
        _pages.add(currentPage);
        _pageOffsets.add(currentOffset);
      }
    }

    final validPage = _pages.indexWhere((page) => page.contains(widget.selectedIndex));
    _currentPage = validPage != -1 ? validPage : 0;
  }

  double get _indicatorLeft
  {
    var left = 0.0;

    for (var i = 0; i < widget.selectedIndex && i < _tabWidths.length; i++)
    {
      left += _tabWidths[i];
    }

    return left;
  }

  double get _indicatorWidth
  {
    if (widget.selectedIndex < 0 || widget.selectedIndex >= _tabWidths.length)
    {
      return 0;
    }

    return _tabWidths[widget.selectedIndex];
  }

  Widget _buildTab(int tabIndex)
  {
    final isSelected = tabIndex == widget.selectedIndex;
    final tabWidth = tabIndex < _tabWidths.length ? _tabWidths[tabIndex] : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTabSelected(tabIndex),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: tabWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: _tabFontSize,
                  fontWeight: isSelected ? _measurementFontWeight : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : _idleTabText,
                ),
                child: Text(widget.tabs[tabIndex], overflow: TextOverflow.visible),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Invisible twin of the tab row: same text and same font as the measurement
  // style, but transparent and pushed off screen. It exists only so that
  // Flutter actually lays it out, letting the real size be read from its
  // RenderBox after the frame.
  Widget _buildMeasuringRow()
  {
    return Positioned(
      left: _offscreenLeft,
      top: 0,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(widget.tabs.length, (i)
              {
                if (i >= _measureKeys.length)
                {
                  return const SizedBox.shrink();
                }

                return Text(
                  widget.tabs[i],
                  key: _measureKeys[i],
                  style: _measurementStyle,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    // Safety net: if the keys are somehow out of sync with the current tabs,
    // regenerate them and schedule a measurement rather than risking a length
    // mismatch while building.
    if (_measureKeys.length != widget.tabs.length)
    {
      _measureKeys = _buildMeasureKeys();

      WidgetsBinding.instance.addPostFrameCallback((_)
      {
        if (mounted)
        {
          _scheduleMeasurement();
        }
      });
    }

    final needsArrows = _pages.length > 1;

    return SizedBox(
      width: widget.maxWidth,
      height: _barHeight,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          _buildMeasuringRow(),
          Container(
            height: _baselineHeight,
            width: double.infinity,
            color: _baselineColor,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (needsArrows)
                _AppCustomArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
              Expanded(
                child: SizedBox(
                  height: _barHeight,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          left: _pages.isNotEmpty ? -_pageOffsets[_currentPage] : 0.0,
                          top: 0,
                          bottom: 0,
                          width: _totalTabsWidth,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              OverflowBox(
                                minWidth: 0,
                                maxWidth: double.infinity,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(widget.tabs.length, _buildTab),
                                ),
                              ),
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                left: _indicatorLeft,
                                bottom: 0,
                                width: _indicatorWidth,
                                height: _indicatorHeight,
                                child: Container(color: _indicatorColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (needsArrows)
                _AppCustomArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _currentPage < _pages.length - 1
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppCustomArrowButton extends StatefulWidget
{
  final IconData icon;
  final VoidCallback? onPressed;

  const _AppCustomArrowButton({required this.icon, this.onPressed});

  @override
  State<_AppCustomArrowButton> createState() => _AppCustomArrowButtonState();
}

class _AppCustomArrowButtonState extends State<_AppCustomArrowButton>
{
  bool _isHovered = false;
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: _isDisabled ? null : (_) => setState(() => _isHovered = true),
      onExit: _isDisabled ? null : (_) => setState(() => _isHovered = false),
      cursor: _isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: _isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: _isDisabled ? null : () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _arrowWidth,
            height: _barHeight,
            decoration: BoxDecoration(
              color: _isHovered && !_isDisabled ? _arrowHoverBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: _isDisabled
                  ? _idleTabText.withValues(alpha: 0.4)
                  : AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}