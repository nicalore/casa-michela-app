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

// The mark that opens beside the row under the pointer, as in the rail and in
// the user menu: same gold, same width, same way of growing out of the middle.
const double _markWidth = 2;
const double _markHeight = 16;

// Two things wearing one shape, and they are not the same thing.
//
// A setting always holds a value — a list is always sorted somehow — so it can
// never be "off" and has nothing to clear. It shows what it is set to and stays
// quiet about it.
//
// A filter starts off and, when set, is the reason the list in front of you is
// shorter than the truth. That deserves to be the loudest thing in the row, so a
// filter that is on fills with the brand ramp and carries the cross that turns
// it off again.
enum _PillKind
{
  setting,
  filter,
}

class AppFilterPill<T> extends StatefulWidget
{
  // What the pill is for, written on it: "Ordina", "Città". The value follows in
  // bold, so the two read as one sentence — "Ordina: Nome (A-Z)" — and no one
  // has to work out from an icon whether a pill sorts the list or shortens it.
  final String prefix;

  final String hint;
  final IconData icon;
  final T? value;
  final List<FilterOption<T>> options;
  final ValueChanged<T> onChanged;
  final VoidCallback? onClear;
  final double menuWidth;
  final _PillKind _kind;

  // Sorting, grouping: something that is always set to one of its options.
  const AppFilterPill.setting({
    super.key,
    required this.prefix,
    required this.hint,
    required this.icon,
    required T this.value,
    required this.options,
    required this.onChanged,
    required this.menuWidth,
  })  : _kind = _PillKind.setting,
        onClear = null;

  // Narrowing: off until it is chosen, and loud once it is.
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

  // Only a filter fills, and only once it has something to say.
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

  // Nothing chosen: the pill says what it would narrow if you asked it to, in
  // one weight. Something chosen: the job in front, the answer in bold behind.
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
    // Torn down rather than animated out: the widget owning it is going away,
    // and an overlay outliving it would be left hanging on the screen.
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

    // rootOverlay bypasses any nested Navigator between here and the screen, so
    // the menu is positioned in real screen space: without it a menu opened
    // inside a dialog lands offset by the dialog's own origin.
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
    // Open counts as pointed at: the pill keeps its mark for as long as the menu
    // it opened is on the screen.
    final bool marked = _hover || _isOpen;

    // Two values, because they answer two different questions and can both be
    // halfway through at once: t is whether the filter is on, h whether the
    // pointer is here.
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: _buildLabel(contentColor),
        ),
        const SizedBox(width: 6),
        // The chevron is the part that was missing: without it these read as
        // buttons that do something rather than as something that opens.
        AnimatedRotation(
          turns: _isOpen ? 0.5 : 0,
          duration: _menuFade,
          curve: Curves.easeOut,
          child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: contentColor),
        ),
        // Opens sideways with the ground rather than appearing on top of it, so
        // the pill grows by exactly the width of the cross over the same moment
        // it changes colour.
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

// A filter whose choices are too many for a menu, so it opens a dialog of its
// own and comes back with a count. It is the same pill as the others in every
// visible respect — that is the point: the row must not look like it is made of
// two different kinds of control just because one of them needs more room to ask
// its question.
class AppCountFilterPill extends StatefulWidget
{
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  const AppCountFilterPill({
    super.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.onOpen,
    required this.onClear,
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
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text.rich(
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
        ),
        const SizedBox(width: 6),
        // No chevron: this one opens a window rather than dropping a list under
        // itself, and saying otherwise would be a promise it does not keep.
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

// The ground, the outline and the shadow every pill in the row wears, and the
// one place they are decided.
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

  // Muted with nothing to say, teal once it has an answer or the pointer is on
  // it, white once the ground underneath has gone dark.
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

  // The white is written as a ramp of two whites rather than as a plain colour.
  // It looks like a pointless way to say white, and it is the whole reason the
  // pill can fill smoothly: a decoration carrying a colour and one carrying a
  // gradient cannot be interpolated into each other, so a pill that swapped
  // between the two had nothing to animate through and flashed on the way.
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
            // The card's own shadow while it is white, deepening into the filled
            // one as the ramp arrives.
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

// The cross that turns a filter off. It sits on a filled pill that already
// answers the pointer as a whole, so its own answer has to be louder than the
// pill's or it looks like part of the label: the disc it sits in goes from a
// hint of white to plainly there, and the cross grows with it.
class _ClearButton extends StatefulWidget
{
  final VoidCallback onTap;

  // How far the ground under it has gone dark: a white cross on a pill that is
  // still white would be a hole rather than a button.
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
          child: AnimatedScale(
            scale: _hover ? 1.12 : 1,
            duration: _hoverFade,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: _hoverFade,
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: (_hover ? 0.42 : 0.20) * widget.opacity,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: widget.opacity),
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

    // Expanding on the next frame is what makes the opening animation visible:
    // on the first frame the overlay is laid out collapsed.
    WidgetsBinding.instance.addPostFrameCallback((_)
    {
      if (mounted)
      {
        setState(() => _expanded = true);
      }
    });
  }

  // Awaited by the pill before the overlay is pulled, so the menu folds away
  // instead of vanishing.
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
              // Squeezed by a transform rather than by a height, so the row
              // cannot shift as the mark comes and goes.
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
