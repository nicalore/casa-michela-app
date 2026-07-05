import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/foundation.dart';

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

  List<GlobalKey> _measureKeys = [];
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    _measureKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    _updateLayout(widget.maxWidth, _estimateWidths(widget.tabs));
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(AppCustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool tabsChanged = !listEquals(oldWidget.tabs, widget.tabs);
    final bool needsLayout = oldWidget.maxWidth != widget.maxWidth || tabsChanged;
    final bool needsPageUpdate = oldWidget.selectedIndex != widget.selectedIndex;

    if (tabsChanged) {
      _measureKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }

    if (needsLayout) {
      // Se i tab non sono cambiati, riparti dalle larghezze già misurate
      // (evita un frame "sballato" ad ogni resize). Altrimenti stima
      // provvisoriamente in attesa della prima misura reale.
      final List<double> startingWidths =
          (!tabsChanged && _tabWidths.length == widget.tabs.length)
              ? _tabWidths
              : _estimateWidths(widget.tabs);
      _updateLayout(widget.maxWidth, startingWidths);
      _scheduleMeasurement();
    } else if (needsPageUpdate) {
      final int newPage = _pages.indexWhere((p) => p.contains(widget.selectedIndex));
      if (newPage != -1 && newPage != _currentPage) {
        _currentPage = newPage;
      }
    }
  }

  // Stima grezza usata SOLO per il primissimo frame, prima che la misura
  // reale sia disponibile: serve solo a evitare una tab bar a larghezza
  // zero per un istante. Verrà quasi certamente corretta subito dopo.
  List<double> _estimateWidths(List<String> tabs) {
    final style = GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700);
    return tabs.map((tab) {
      final tp = TextPainter(
        text: TextSpan(text: tab, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.size.width + 44;
    }).toList();
  }

  // Dopo ogni frame, legge la larghezza VERA di ogni tab dalla riga ombra.
  // Se differisce da quella assunta finora, ricalcola pagine e frecce.
  // Riprova per un certo numero di round (con piccola pausa tra uno e
  // l'altro) per assorbire un eventuale caricamento tardivo del font,
  // qualunque sia il motivo del ritardo.
  void _scheduleMeasurement({int attemptsLeft = 8}) {
    if (_measurementScheduled) return;
    _measurementScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;

      final List<double> measured = [];
      for (final key in _measureKeys) {
        final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          if (attemptsLeft > 0) _scheduleMeasurement(attemptsLeft: attemptsLeft - 1);
          return;
        }
        measured.add(renderBox.size.width + 44);
      }

      if (measured.length != _tabWidths.length) {
        if (attemptsLeft > 0) _scheduleMeasurement(attemptsLeft: attemptsLeft - 1);
        return;
      }

      bool changed = false;
      for (int i = 0; i < measured.length; i++) {
        if ((measured[i] - _tabWidths[i]).abs() > 0.5) {
          changed = true;
          break;
        }
      }

      if (changed) {
        setState(() {
          _updateLayout(widget.maxWidth, measured);
        });
      }

      if (attemptsLeft > 0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _scheduleMeasurement(attemptsLeft: attemptsLeft - 1);
        });
      }
    });
  }

  void _updateLayout(double maxWidth, List<double> tabWidths) {
    _tabWidths = tabWidths;
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

    final int validPage = _pages.indexWhere((p) => p.contains(widget.selectedIndex));
    _currentPage = validPage != -1 ? validPage : 0;
  }

  @override
  Widget build(BuildContext context) {
    // Rete di sicurezza: se per qualche motivo le chiavi non sono ancora
    // allineate al numero di tab correnti, rigenerale e pianifica subito
    // una misura, invece di rischiare un mismatch di lunghezza in build().
    if (_measureKeys.length != widget.tabs.length) {
      _measureKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleMeasurement();
      });
    }

    final bool needsArrows = _pages.length > 1;
    double indicatorLeft = 0;
    double indicatorWidth = 0;

    for (int i = 0; i < widget.selectedIndex && i < _tabWidths.length; i++) {
      indicatorLeft += _tabWidths[i];
    }
    if (widget.selectedIndex >= 0 && widget.selectedIndex < _tabWidths.length) {
      indicatorWidth = _tabWidths[widget.selectedIndex];
    }

    final allTabsWidgets = List.generate(widget.tabs.length, (tabIndex) {
      final title = widget.tabs[tabIndex];
      final isSelected = tabIndex == widget.selectedIndex;
      final double tabWidth = tabIndex < _tabWidths.length ? _tabWidths[tabIndex] : 0;

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

    // Riga "ombra": stesso testo, stesso font/peso usato per la misura,
    // ma invisibile (opacity 0) e posizionata fuori dall'area visibile.
    // Serve solo a far sì che Flutter la disegni davvero, cosicché
    // possiamo leggerne la vera dimensione dal RenderBox dopo il frame.
    final Widget shadowRow = Positioned(
      left: -100000,
      top: 0,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(widget.tabs.length, (i) {
                if (i >= _measureKeys.length) return const SizedBox.shrink();
                return Text(
                  widget.tabs[i],
                  key: _measureKeys[i],
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700),
                );
              }),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: widget.maxWidth,
      height: 54,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          shadowRow,
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
                              OverflowBox(
                                minWidth: 0,
                                maxWidth: double.infinity,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: allTabsWidgets,
                                ),
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