import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../mobile_palette.dart';
import 'mobile_glass_panel.dart';
import 'mobile_nav_sheet.dart';

const double _grabberWidth = 38;
const double _grabberHeight = 5;

const double _topPadding = 14;
const double _bottomPadding = 24;

const double _topClearance = 24;

const double _sidePadding = 24;

int _openSheets = 0;

// Hides the nav bar until the last contextual sheet closes.
Future<T?> showMobileSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
})
{
  _openSheets += 1;
  MobileNavSheet.hidden.value = true;

  // The route strips the top inset; captured here to keep tall sheets below the status bar.
  final double statusBar = MediaQuery.paddingOf(context).top;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppTheme.trialDeepWater.withValues(alpha: 0.42),
    constraints: const BoxConstraints(maxWidth: MobileNavSheet.tabletWidth),
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: MediaQuery.paddingOf(context).copyWith(top: statusBar),
      ),
      child: builder(context),
    ),
  ).whenComplete(()
  {
    _openSheets -= 1;

    // Deferred a turn, so a sheet handing over to another keeps the bar down.
    Future<void>.delayed(Duration.zero, ()
    {
      if (_openSheets == 0)
      {
        MobileNavSheet.hidden.value = false;
      }
    });
  });
}

class MobileSheet extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final String? subtitle;

  // Replaces the close button.
  final Widget? trailing;

  final List<Widget> body;

  final Widget? footer;

  final bool closable;

  // Outside the scrolling body.
  final Widget? subhead;

  // Off, the keyboard covers the sheet's end.
  final bool aboveKeyboard;

  // Replaces [body]; runs edge to edge and scrolls itself.
  final Widget? content;

  const MobileSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.body = const [],
    this.footer,
    this.closable = true,
    this.subhead,
    this.aboveKeyboard = false,
    this.content,
  });

  // For [content], which the sheet does not inset.
  static const double sidePadding = _sidePadding;

  static Widget _inset(Widget child)
  {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: _sidePadding), child: child);
  }

  @override
  Widget build(BuildContext context)
  {
    final MediaQueryData media = MediaQuery.of(context);

    final double keyboard = aboveKeyboard ? media.viewInsets.bottom : 0;
    final double bottom = (keyboard > 0 ? keyboard : media.padding.bottom) + _bottomPadding;
    final double maxHeight =
        media.size.height - media.padding.top - _topClearance - _topPadding - bottom;

    final Widget? footer = this.footer;
    final Widget? subhead = this.subhead;

    return MobileGlassPanel.sheet(
      padding: EdgeInsets.fromLTRB(0, _topPadding, 0, bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: _grabberWidth,
                height: _grabberHeight,
                decoration: BoxDecoration(
                  color: AppTheme.trialOcean.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(_grabberHeight / 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _inset(_buildHead(context)),
            if (subhead != null) _inset(subhead),
            // A ListView, so only visible rows lay out: some bodies run to dozens.
            Flexible(
              child: content ??
                  ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: _sidePadding),
                    children: body,
                  ),
            ),
            if (footer != null) _inset(footer),
          ],
        ),
      ),
    );
  }

  Widget _buildHead(BuildContext context)
  {
    final String? subtitle = this.subtitle;
    final Widget? trailing = this.trailing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.9,
                  color: AppTheme.trialTealDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  height: 1.15,
                  color: AppTheme.trialInk,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: MobilePalette.mutedText,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing,
        ]
        else if (closable) ...[
          const SizedBox(width: 12),
          _CloseButton(onTap: () => Navigator.of(context).pop()),
        ],
      ],
    );
  }
}

class _CloseButton extends StatelessWidget
{
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return Semantics(
      button: true,
      label: 'Chiudi',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.trialInk.withValues(alpha: 0.07),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: AppTheme.trialInk.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class MobileSheetCard extends StatelessWidget
{
  static const double radius = 18;

  final Widget child;

  const MobileSheetCard({super.key, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        boxShadow: [BoxShadow(color: Color(0x12122438), offset: Offset(0, 4), blurRadius: 14)],
      ),
      child: child,
    );
  }
}

class MobileSheetText extends StatelessWidget
{
  final String text;

  const MobileSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppTheme.trialInk.withValues(alpha: 0.8),
      ),
    );
  }
}
