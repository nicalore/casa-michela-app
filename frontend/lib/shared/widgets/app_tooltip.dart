import 'package:flutter/material.dart';

import '../../core/platform/visual_effects.dart';

// Material's fade, which its Tooltip does not let go.
const AnimationStyle _fade = AnimationStyle(
  curve: Curves.fastOutSlowIn,
  duration: Duration(milliseconds: 150),
  reverseDuration: Duration(milliseconds: 75),
);

const double _verticalOffset = 24;
const Duration _touchDelay = Duration(milliseconds: 1500);
const Duration _exitDelay = Duration(milliseconds: 100);

// Material's Tooltip on RawTooltip: same look and placement, with no fade while effects are off.
class AppTooltip extends StatelessWidget
{
  final String? message;
  final InlineSpan? richMessage;

  final Duration? waitDuration;

  final Decoration? decoration;
  final TextStyle? textStyle;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;

  final Widget? child;

  const AppTooltip({
    super.key,
    this.message,
    this.richMessage,
    this.waitDuration,
    this.decoration,
    this.textStyle,
    this.constraints,
    this.padding,
    this.child,
  }) : assert((message == null) != (richMessage == null));

  Offset _place(TooltipPositionContext context, TooltipThemeData theme)
  {
    return positionDependentBox(
      size: context.overlaySize,
      childSize: context.tooltipSize,
      target: context.target,
      verticalOffset: theme.verticalOffset ?? _verticalOffset,
      preferBelow: theme.preferBelow ?? true,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final String text = message ?? richMessage!.toPlainText();
    final Widget anchor = MouseRegion(cursor: MouseCursor.defer, child: child ?? const SizedBox.shrink());

    if (text.isEmpty || !TooltipVisibility.of(context))
    {
      return text.isEmpty ? child ?? const SizedBox.shrink() : anchor;
    }

    final ThemeData theme = Theme.of(context);
    final TooltipThemeData tooltipTheme = TooltipTheme.of(context);
    final TextAlign align = tooltipTheme.textAlign ?? TextAlign.start;

    // Material's defaults, smaller on desktop platforms.
    final bool desktop = switch (theme.platform)
    {
      TargetPlatform.macOS || TargetPlatform.linux || TargetPlatform.windows => true,
      TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.iOS => false,
    };

    final TextStyle style = textStyle ??
        tooltipTheme.textStyle ??
        theme.textTheme.bodyMedium!.copyWith(color: Colors.white, fontSize: desktop ? 12 : 14);

    final Widget box = ConstrainedBox(
      constraints: constraints ??
          tooltipTheme.constraints ??
          BoxConstraints(minHeight: desktop ? 24 : 32),
      child: DefaultTextStyle(
        style: style,
        textAlign: align,
        child: Container(
          decoration: decoration ??
              tooltipTheme.decoration ??
              BoxDecoration(
                color: Colors.grey[700]!.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
          padding: padding ?? tooltipTheme.padding ?? EdgeInsets.symmetric(horizontal: desktop ? 8 : 16, vertical: 4),
          margin: tooltipTheme.margin ?? EdgeInsets.zero,
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text.rich(richMessage ?? TextSpan(text: message), style: style, textAlign: align),
          ),
        ),
      ),
    );

    return RawTooltip(
      semanticsTooltip: (tooltipTheme.excludeFromSemantics ?? false) ? null : text,
      tooltipBuilder: (context, animation) => FadeTransition(opacity: animation, child: box),
      hoverDelay: waitDuration ?? tooltipTheme.waitDuration ?? Duration.zero,
      touchDelay: tooltipTheme.showDuration ?? _touchDelay,
      dismissDelay: tooltipTheme.exitDuration ?? _exitDelay,
      triggerMode: tooltipTheme.triggerMode ?? TooltipTriggerMode.longPress,
      enableFeedback: tooltipTheme.enableFeedback ?? true,
      // Read when the tooltip first shows: a switch applies to tooltips not yet seen.
      animationStyle: VisualEffects.of(context) ? _fade : AnimationStyle.noAnimation,
      positionDelegate: (position) => _place(position, tooltipTheme),
      ignorePointer: message != null,
      child: anchor,
    );
  }
}
