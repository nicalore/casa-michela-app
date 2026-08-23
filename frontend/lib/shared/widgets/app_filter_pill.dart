import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'filter_menu.dart';
import 'overflow_tooltip_text.dart';

const double _pillHeight = 44;
const double _pillRadius = 22;
const double _borderWidth = 1.5;

const Duration _hoverFade = Duration(milliseconds: 180);
const Duration _menuFade = Duration(milliseconds: 180);

const double _menuRadius = 16;
const double _menuGap = 8;
const double _menuMaxHeight = 350;

const double _markWidth = 2;
const double _markHeight = 16;

const double _clearIcon = 14;
const double _clearDiscPadding = 3;
const double _clearDisc = _clearIcon + 2 * _clearDiscPadding;

const double _clearGap = 8;

const double _clearGrowth = 1.12;
const double _clearHoverRoom = _clearDisc * (_clearGrowth - 1) / 2;

const double kFilterPillLabelMaxWidth = 210;

Widget _pillLabel(Widget label, double maxWidth)
{
  return Flexible(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: label,
    ),
  );
}

const double _sortMenuWidth = 190;

class AppSortPill extends StatelessWidget
{
  final SortCriterion value;
  final ValueChanged<SortCriterion> onChanged;

  const AppSortPill({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppFilterPill<SortCriterion>.setting(
      prefix: 'Ordina',
      hint: 'Ordina per',
      icon: Icons.swap_vert_rounded,
      value: value,
      menuWidth: _sortMenuWidth,
      onChanged: onChanged,
      options: SortCriterion.values
          .map((sort) => FilterOption(value: sort, label: sort.label))
          .toList(),
    );
  }
}

enum _PillKind
{
  setting,
  filter,
}

class AppFilterPill<T> extends StatefulWidget
{
  final String prefix;

  final String hint;
  final IconData icon;
  final T? value;
  final List<FilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback? onClear;
  final double menuWidth;

  final double maxLabelWidth;

  final _PillKind _kind;

  const AppFilterPill.setting({
    super.key,
    required this.prefix,
    required this.hint,
    required this.icon,
    required T this.value,
    required this.options,
    required this.onChanged,
    required this.menuWidth,
    this.maxLabelWidth = kFilterPillLabelMaxWidth,
  })  : _kind = _PillKind.setting,
        onClear = null;

  const AppFilterPill.filter({
    super.key,
    required this.prefix,
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onClear,
    required this.menuWidth,
    this.maxLabelWidth = kFilterPillLabelMaxWidth,
  }) : _kind = _PillKind.filter;

  @override
  State<AppFilterPill<T>> createState() => _AppFilterPillState<T>();
}

class _AppFilterPillState<T> extends State<AppFilterPill<T>>
{
  final GlobalKey _pillKey = GlobalKey();
  final GlobalKey<_FilterMenuState<T>> _menuKey = GlobalKey();

  OverlayEntry? _overlay;
  bool _hover = false;

  bool get _isOpen => _overlay != null;

  bool get _isFilled => widget._kind == _PillKind.filter && widget.value != null;

  String? get _selectedLabel
  {
    if (widget.value == null)
    {
      return null;
    }

    final matches = widget.options.where((option) => option.value == widget.value);

    return matches.isEmpty ? null : matches.first.label;
  }

  Widget _buildLabel(Color contentColor)
  {
    final String? selected = _selectedLabel;

    final TextStyle valueStyle = GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: contentColor,
    );

    if (selected == null)
    {
      return Text(
        widget.hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: valueStyle.copyWith(fontWeight: FontWeight.w600),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${widget.prefix}: ',
            style: valueStyle.copyWith(
              fontWeight: FontWeight.w500,
              color: contentColor.withValues(alpha: 0.75),
            ),
          ),
          TextSpan(text: selected, style: valueStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void dispose()
  {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  void _toggleMenu()
  {
    if (_isOpen)
    {
      _closeMenu();

      return;
    }

    final renderBox = _pillKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
            ),
          ),
          Positioned(
            top: offset.dy + renderBox.size.height + _menuGap,
            left: offset.dx,
            child: _FilterMenu<T>(
              key: _menuKey,
              currentValue: widget.value,
              options: widget.options,
              width: widget.menuWidth,
              onSelected: (value)
              {
                widget.onChanged(value);
                _closeMenu();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlay!);
    setState(() {});
  }

  Future<void> _closeMenu() async
  {
    if (!_isOpen)
    {
      return;
    }

    await _menuKey.currentState?.collapse();

    _overlay?.remove();
    _overlay = null;

    if (mounted)
    {
      setState(() {});
    }
  }

  void _clear()
  {
    widget.onClear?.call();

    if (_isOpen)
    {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final bool marked = _hover || _isOpen;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: marked ? 1 : 0),
      duration: _hoverFade,
      curve: Curves.easeOut,
      builder: (context, h, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _isFilled ? 1 : 0),
        duration: _hoverFade,
        curve: Curves.easeOut,
        builder: (context, t, _) => _buildPill(t, h),
      ),
    );
  }

  Widget _buildPill(double t, double h)
  {
    final Color contentColor = _PillSurface.contentColor(
      t: t,
      h: h,
      answered: widget.value != null,
    );

    return _PillSurface(
      t: t,
      h: h,
      anchorKey: _pillKey,
      onEnter: () => setState(() => _hover = true),
      onExit: () => setState(() => _hover = false),
      onTap: _toggleMenu,
      children: [
        Icon(widget.icon, size: 18, color: contentColor),
        const SizedBox(width: 9),
        _pillLabel(_buildLabel(contentColor), widget.maxLabelWidth),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: _isOpen ? 0.5 : 0,
          duration: _menuFade,
          curve: Curves.easeOut,
          child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: contentColor),
        ),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: _ClearButton(onTap: _clear, opacity: t),
          ),
        ),
      ],
    );
  }
}

class AppCountFilterPill extends StatefulWidget
{
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  final double maxLabelWidth;

  const AppCountFilterPill({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.onOpen,
    required this.onClear,
    this.maxLabelWidth = kFilterPillLabelMaxWidth,
  });

  @override
  State<AppCountFilterPill> createState() => _AppCountFilterPillState();
}

class _AppCountFilterPillState extends State<AppCountFilterPill>
{
  bool _hover = false;

  bool get _isFilled => widget.count > 0;

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _hover ? 1 : 0),
      duration: _hoverFade,
      curve: Curves.easeOut,
      builder: (context, h, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _isFilled ? 1 : 0),
        duration: _hoverFade,
        curve: Curves.easeOut,
        builder: (context, t, _) => _buildPill(t, h),
      ),
    );
  }

  Widget _buildPill(double t, double h)
  {
    final Color contentColor = _PillSurface.contentColor(
      t: t,
      h: h,
      answered: _isFilled,
    );

    return _PillSurface(
      t: t,
      h: h,
      onEnter: () => setState(() => _hover = true),
      onExit: () => setState(() => _hover = false),
      onTap: widget.onOpen,
      children: [
        Icon(widget.icon, size: 18, color: contentColor),
        const SizedBox(width: 9),
        _pillLabel(
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: widget.label),
                if (_isFilled)
                  TextSpan(
                    text: ': ${widget.count}',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: contentColor,
            ),
          ),
          widget.maxLabelWidth,
        ),
        const SizedBox(width: 6),
        Icon(Icons.tune_rounded, size: 16, color: contentColor),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: _ClearButton(onTap: widget.onClear, opacity: t),
          ),
        ),
      ],
    );
  }
}

class _PillSurface extends StatelessWidget
{
  final double t;
  final double h;

  final Key? anchorKey;

  final VoidCallback onEnter;
  final VoidCallback onExit;
  final VoidCallback onTap;

  final List<Widget> children;

  const _PillSurface({
    required this.t,
    required this.h,
    required this.onEnter,
    required this.onExit,
    required this.onTap,
    required this.children,
    this.anchorKey,
  });

  static Color contentColor({required double t, required double h, required bool answered})
  {
    return Color.lerp(
      Color.lerp(
        answered ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
        AppTheme.trialTealDeep,
        h,
      )!,
      Colors.white,
      t,
    )!;
  }

  LinearGradient get _ground
  {
    return LinearGradient(
      begin: AppTheme.brandGradient.begin,
      end: AppTheme.brandGradient.end,
      colors: [
        Color.lerp(Colors.white, AppTheme.trialTealDeep, t)!,
        Color.lerp(Colors.white, AppTheme.trialTurquoise, t)!,
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Color borderColor = Color.lerp(
      Color.lerp(AppTheme.trialLine, Colors.transparent, t)!,
      AppTheme.trialGold,
      h,
    )!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: anchorKey,
          height: _pillHeight,
          padding: const EdgeInsets.only(left: 16, right: 14),
          decoration: BoxDecoration(
            gradient: _ground,
            borderRadius: BorderRadius.circular(_pillRadius),
            border: Border.all(color: borderColor, width: _borderWidth),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(
                  const Color(0x0A000000),
                  AppTheme.trialTealDeep.withValues(alpha: 0.30),
                  t,
                )!,
                offset: Offset(0, 4 + 2 * t),
                blurRadius: 16 - 2 * t,
                spreadRadius: -6 * t,
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget
{
  final VoidCallback onTap;

  final double opacity;

  const _ClearButton({required this.onTap, required this.opacity});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'Rimuovi il filtro',
          waitDuration: const Duration(milliseconds: 400),
          child: Padding(
            padding: const EdgeInsets.only(left: _clearGap, right: _clearHoverRoom),
            child: AnimatedScale(
              scale: _hover ? _clearGrowth : 1,
              duration: _hoverFade,
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: _hoverFade,
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(_clearDiscPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: (_hover ? 0.42 : 0.20) * widget.opacity,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: _clearIcon,
                  color: Colors.white.withValues(alpha: widget.opacity),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatefulWidget
{
  final T? currentValue;
  final List<FilterOption<T>> options;
  final ValueChanged<T> onSelected;
  final double width;

  const _FilterMenu({
    super.key,
    required this.currentValue,
    required this.options,
    required this.onSelected,
    required this.width,
  });

  @override
  State<_FilterMenu<T>> createState() => _FilterMenuState<T>();
}

class _FilterMenuState<T> extends State<_FilterMenu<T>>
{
  bool _expanded = false;

  @override
  void initState()
  {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  Future<void> collapse() async
  {
    if (mounted)
    {
      setState(() => _expanded = false);
    }

    await Future<void>.delayed(_menuFade);
  }

  @override
  Widget build(BuildContext context)
  {
    return Material(
      color: Colors.transparent,
      child: AnimatedOpacity(
        opacity: _expanded ? 1 : 0,
        duration: _menuFade,
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          constraints: const BoxConstraints(maxHeight: _menuMaxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_menuRadius),
            boxShadow: AppTheme.overlayShadow,
          ),
          child: AnimatedSize(
            duration: _menuFade,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final option in widget.options)
                            _FilterMenuRow(
                              label: option.label,
                              selected: widget.currentValue == option.value,
                              onTap: () => widget.onSelected(option.value),
                            ),
                        ],
                      ),
                    ),
                  )
                : SizedBox(width: widget.width),
          ),
        ),
      ),
    );
  }
}

class _FilterMenuRow extends StatefulWidget
{
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterMenuRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterMenuRow> createState() => _FilterMenuRowState();
}

class _FilterMenuRowState extends State<_FilterMenuRow>
{
  bool _hover = false;

  @override
  Widget build(BuildContext context)
  {
    final bool marked = _hover || widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: _markWidth,
                height: _markHeight,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: marked ? 1 : 0),
                  duration: _hoverFade,
                  curve: Curves.easeOut,
                  builder: (context, factor, child) => Transform.scale(
                    scaleY: factor,
                    child: child,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.trialGold,
                      borderRadius: BorderRadius.circular(_markWidth),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OverflowTooltipText(
                  text: widget.label,
                  maxLines: 1,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    color: marked ? AppTheme.trialTealDeep : AppTheme.trialMutedText,
                  ),
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded, size: 16, color: AppTheme.trialTurquoise),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
