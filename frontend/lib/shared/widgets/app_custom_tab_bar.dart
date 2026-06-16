import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppCustomTabBar extends StatefulWidget {
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

class _AppCustomTabBarState extends State<AppCustomTabBar> {
  int _currentPage = 0;
  List<List<int>> _pages = [];
  List<double> _pageOffsets = [];
  List<double> _tabWidths = [];
  double _totalTabsWidth = 0;

  @override
  void initState() {
    super.initState();
    _updateLayout(widget.maxWidth);
  }

  @override
  void didUpdateWidget(AppCustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsLayout = oldWidget.maxWidth != widget.maxWidth;
    bool needsPageUpdate = oldWidget.selectedIndex != widget.selectedIndex;

    if (needsLayout) {
      _updateLayout(widget.maxWidth);
    } else if (needsPageUpdate) {
      int newPage = _pages.indexWhere((p) => p.contains(widget.selectedIndex));
      if (newPage != -1 && newPage != _currentPage) {
        _currentPage = newPage;
      }
    }
  }

  void _updateLayout(double maxWidth) {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );

    _tabWidths = widget.tabs.map((tab) {
      final tp = TextPainter(
        text: TextSpan(text: tab, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.size.width + 44; 
    }).toList();

    _totalTabsWidth = _tabWidths.fold(0.0, (a, b) => a + b);
    _pages.clear();
    _pageOffsets.clear();

    if (_totalTabsWidth <= maxWidth) {
      _pages.add(List.generate(widget.tabs.length, (i) => i));
      _pageOffsets.add(0.0);
    } else {
      final availableWidthForTabs = (maxWidth - 96).clamp(1.0, double.infinity);
      List<int> currentPage = [];
      double currentWidth = 0;
      double currentOffset = 0;

      for (int i = 0; i < widget.tabs.length; i++) {
        if (currentPage.isEmpty) {
          currentPage.add(i);
          currentWidth = _tabWidths[i];
        } else if (currentWidth + _tabWidths[i] <= availableWidthForTabs) {
          currentPage.add(i);
          currentWidth += _tabWidths[i];
        } else {
          _pages.add(currentPage);
          _pageOffsets.add(currentOffset);
          currentOffset += currentWidth;
          currentPage = [i];
          currentWidth = _tabWidths[i];
        }
      }
      if (currentPage.isNotEmpty) {
        _pages.add(currentPage);
        _pageOffsets.add(currentOffset);
      }
    }

    int validPage = _pages.indexWhere((p) => p.contains(widget.selectedIndex));
    _currentPage = validPage != -1 ? validPage : 0;
  }

  @override
  Widget build(BuildContext context) {
    bool needsArrows = _pages.length > 1;
    double indicatorLeft = 0;
    double indicatorWidth = 0;

    for (int i = 0; i < widget.selectedIndex; i++) {
      indicatorLeft += _tabWidths[i];
    }
    if (widget.selectedIndex >= 0 && widget.selectedIndex < _tabWidths.length) {
      indicatorWidth = _tabWidths[widget.selectedIndex];
    }

    final allTabsWidgets = List.generate(widget.tabs.length, (tabIndex) {
      final title = widget.tabs[tabIndex];
      final isSelected = tabIndex == widget.selectedIndex;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onTabSelected(tabIndex),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: _tabWidths[tabIndex],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF003C82) : const Color(0xFF6B7A8A),
                  ),
                  child: Text(title, overflow: TextOverflow.visible),
                ),
              ),
            ),
          ),
        ),
      );
    });

    return SizedBox(
      width: widget.maxWidth,
      height: 54, 
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Container(
            height: 2,
            width: double.infinity,
            color: const Color(0x22003C82),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (needsArrows)
                _AppCustomArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
              Expanded(
                child: SizedBox(
                  height: 54, 
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: allTabsWidgets,
                              ),
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                left: indicatorLeft,
                                bottom: 0,
                                width: indicatorWidth,
                                height: 3,
                                child: Container(
                                  color: const Color(0xFF12A0D7),
                                ),
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

class _AppCustomArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _AppCustomArrowButton({required this.icon, this.onPressed});

  @override
  State<_AppCustomArrowButton> createState() => _AppCustomArrowButtonState();
}

class _AppCustomArrowButtonState extends State<_AppCustomArrowButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;

    return MouseRegion(
      onEnter: (_) => !isDisabled ? setState(() => _isHovered = true) : null,
      onExit: (_) => !isDisabled ? setState(() => _isHovered = false) : null,
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => !isDisabled ? setState(() => _isPressed = true) : null,
        onTapUp: (_) => !isDisabled ? setState(() => _isPressed = false) : null,
        onTapCancel: () => !isDisabled ? setState(() => _isPressed = false) : null,
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 54, 
            decoration: BoxDecoration(
              color: _isHovered && !isDisabled ? const Color(0x0A003C82) : Colors.transparent,
              borderRadius: BorderRadius.circular(12), 
            ),
            child: Icon(
              widget.icon,
              color: isDisabled ? const Color(0xFF6B7A8A).withValues(alpha: 0.4) : const Color(0xFF003C82),
            ),
          ),
        ),
      ),
    );
  }
}