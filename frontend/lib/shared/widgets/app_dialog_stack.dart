import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'carousel_arrow_button.dart';
import 'overflow_tooltip_text.dart';

// Air between one floating piece and the next, and between the stack and the
// edges of the window. Generous on purpose: what tells the pieces apart is the
// page showing between them, and at sixteen they read as one panel with seams.
const double _pieceGap = 26;
const double _windowMargin = 16;

// Each piece starts a beat later than the one before, as a fraction of the
// transition. The clamp below caps the last beat at 1 - span, so past six
// pieces they share it: one starting later could not finish before the window.
const double _staggerStep = 0.11;
const double _staggerSpan = 0.54;

// How small a piece starts. It grows about its own centre and never translates,
// so a card at the foot of the window grows at the foot of the window.
const double _pieceScale = 0.92;

// Room kept around the scrolling middle so the shadows of the pieces inside it
// are not cut off where the viewport clips.
const double _shadowRoom = 12;

const double _pillRadius = 28;
const double _pillPadding = 28;

// The round close standing off the title pill.
const double _closeSize = 44;

// Under this, a dialog head cannot afford both the face and symmetrical room
// for the close. From what a title needs, not from a device: 214 for the close
// and the face, 58 of pill insets, 180 for the words. See _buildTitleRow.
const double _titleRowRoom = 460;

// A dialog made of separate pieces over the blurred page, rather than one white
// panel. What belongs together is a piece, and the page shows between them.
//
// It takes a list of bodies and not one: that is what the arrangement rests on.
class AppDialogStack extends StatelessWidget
{
  final String eyebrow;
  final String title;

  // The face of whoever the window is about, where the title is a person. It is
  // read before the name, so it belongs beside it.
  final Widget? leading;

  // The one or two facts the window is bounded by. In the title's own piece:
  // they are read with the name, not after it.
  final Widget? subtitle;

  // Each one floats on its own, in the order given, with air between them.
  final List<Widget> children;

  final Widget? footer;

  // Of the whole stack, arrows and all — not of the widest piece in it.
  final double maxWidth;

  // Left out, the stack stands in the middle of the screen. Given, the caller
  // places it: a window opened beside one already open has to sit off centre so
  // that what it was opened from stays visible behind it.
  final Alignment alignment;

  // Off only for a window that is itself a question, where the two buttons at
  // the foot are the answers and a cross would be a third way of saying "no".
  // It cannot be read off the footer: a details window has two buttons too.
  final bool showClose;

  // Left out it simply closes. A window with something to ask before it goes —
  // unsaved work, a row to release — passes its own way out here: the cross has
  // to be the same way out and not merely another one.
  final VoidCallback? onClose;

  // Set where the last piece is a list: everything above it stays put and only
  // that piece takes the height left over, scrolling whatever the caller put
  // inside it. Left off, the whole stack scrolls as one.
  final bool fillLast;

  const AppDialogStack({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.children,
    this.leading,
    this.subtitle,
    this.footer,
    this.maxWidth = 720,
    this.alignment = Alignment.center,
    this.showClose = true,
    this.onClose,
    this.fillLast = false,
  });

  Widget _buildTitleRow(BuildContext context)
  {
    // One line each, measured by their longest: the usual measure hands a
    // paragraph all the room it was allowed, and the pill would come out
    // stretched with the words at one end of it.
    //
    // The room is the window and not the width the caller asked for its pieces,
    // which is regularly narrower than the name. Narrower than the words even
    // so, the title is cut with the tooltip carrying the rest.
    final Widget heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textWidthBasis: TextWidthBasis.longestLine,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            height: 1.2,
            color: AppTheme.trialMutedText,
          ),
        ),
        const SizedBox(height: 2),
        OverflowTooltipText(
          text: title,
          maxLines: 1,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppTheme.trialOcean,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          subtitle!,
        ],
      ],
    );

    // On a phone the close answered on both sides plus the face leave the words
    // thirty-nine pixels, which is not a narrow heading but a heading one letter
    // wide and taller than the window.
    //
    // So below this the face steps out and the close is answered on its own side
    // only: the name is written again in the eyebrow just above.
    final bool tight = MediaQuery.sizeOf(context).width < _titleRowRoom;
    final bool besideAFace = leading != null && !tight;

    final Widget pill = AppDialogPill(
      // A round face wants the same air all round, and the two lines beside it
      // are shorter than the circle: at the old height the pill grew a band of
      // white under them.
      padding: besideAFace
          ? const EdgeInsets.fromLTRB(22, 20, 36, 20)
          : EdgeInsets.fromLTRB(tight ? 20 : 36, 22, tight ? 20 : 36, 24),
      child: besideAFace
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading!,
                const SizedBox(width: 18),
                // Loose, so a name longer than the window is cut at its own end
                // rather than pushing the face out of the pill.
                Flexible(child: heading),
              ],
            )
          : heading,
    );

    if (!showClose)
    {
      return pill;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          // Room for the close at the right end, kept on both sides so the pill
          // stays centred on the stack rather than on what is left of it — until
          // the window is too narrow to buy that symmetry twice.
          padding: tight
              ? const EdgeInsets.only(right: _closeSize + 8)
              : const EdgeInsets.symmetric(horizontal: _closeSize + 16),
          child: pill,
        ),
        Positioned(
          right: 0,
          child: CarouselArrowButton(
            icon: Icons.close_rounded,
            hoverColor: AppTheme.trialGoldSurface,
            hoverIconColor: AppTheme.trialTealDeep,
            hoverBorderColor: AppTheme.trialGold,
            onTap: onClose ?? () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // The pieces between the title and the footer. Normally they scroll as one,
  // paper included; under [fillLast] everything above the last piece stays put
  // and that piece is handed the height that is left.
  List<Widget> _buildBody(double width)
  {
    if (!fillLast)
    {
      return [
        Flexible(
          child: _atMost(width, SingleChildScrollView(
            // The default is opaque, which would swallow every tap in the
            // gaps — and a tap on the gaps reaching the barrier is the idea.
            hitTestBehavior: HitTestBehavior.deferToChild,
            padding: const EdgeInsets.all(_shadowRoom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: _pieceGap),
                  AppDialogPiece(index: i + 1, child: children[i]),
                ],
              ],
            ),
          )),
        ),
      ];
    }

    return [
      for (var i = 0; i < children.length - 1; i++) ...[
        if (i > 0) const SizedBox(height: _pieceGap),
        _atMost(width, AppDialogPiece(index: i + 1, child: children[i])),
      ],
      if (children.length > 1) const SizedBox(height: _pieceGap),
      // Loose, so a short list is still only as tall as it is: the piece takes
      // the room that is left only when it needs it.
      Flexible(
        fit: FlexFit.loose,
        child: _atMost(
          width,
          AppDialogPiece(index: children.length, child: children.last),
        ),
      ),
    ];
  }

  static Widget _atMost(double width, Widget child)
  {
    return ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child);
  }

  @override
  Widget build(BuildContext context)
  {
    final window = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    // All the stack may take, and what each piece under the title is held to
    // inside it.
    final double room = window.width - 2 * _windowMargin;
    final double pieceWidth = math.min(maxWidth, room);

    return Padding(
      // What Dialog used to do for us: lift the stack off a keyboard that has
      // taken the bottom of the screen.
      padding: EdgeInsets.only(bottom: keyboard),
      // A dialog on its way out answers to nothing: for the quarter second it
      // takes to fade, its buttons are still drawn where they were.
      child: _WhileItIsThere(
        // Full screen on purpose. The BackdropFilter of showBlurredDialog sizes
        // itself to its child, so a stack that shrink-wrapped here would blur
        // only the rectangle the pieces happen to occupy.
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Never the full width: the top and bottom pieces are outside the
              // scrolling middle and have no padding of their own.
              //
              // The room and not maxWidth, which is what the pieces are worth
              // and not what the window is. Capped below, piece by piece.
              maxWidth: room,
              // Against the window and not the incoming constraints, which are
              // unbounded inside a scroll view.
              maxHeight: window.height - keyboard - 2 * _windowMargin,
            ),
            // Load-bearing twice: text outside a Material wears the yellow
            // underline of an unstyled paragraph, and a transparent Material,
            // unlike an opaque one, does not answer the hit test.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppDialogPiece(index: 0, child: _buildTitleRow(context)),
                  const SizedBox(height: _pieceGap),
                  ..._buildBody(pieceWidth),
                  if (footer != null) ...[
                    const SizedBox(height: _pieceGap),
                    _atMost(
                      pieceWidth,
                      AppDialogPiece(index: children.length + 1, child: footer!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Answers to a tap only while its dialog is the topmost one. Here and not on
// every button, because it is a property of the dialog. Outside a dialog it
// lets everything through.
class _WhileItIsThere extends StatelessWidget
{
  final Widget child;

  const _WhileItIsThere({required this.child});

  @override
  Widget build(BuildContext context)
  {
    final ModalRoute<dynamic>? window = ModalRoute.of(context);

    if (window == null)
    {
      return child;
    }

    // The animation is the only place the change announces itself: isCurrent is
    // a question, not something that can be subscribed to.
    return AnimatedBuilder(
      animation: window.animation ?? kAlwaysCompleteAnimation,
      builder: (context, _) => IgnorePointer(
        ignoring: !window.isCurrent,
        child: child,
      ),
    );
  }
}

// A piece arriving on its own beat: title first, footer last. Driven by the
// route's own animation, so closing plays it backwards for free.
class AppDialogPiece extends StatelessWidget
{
  final int index;
  final Widget child;

  // The key below is there for the tests, and two pieces on the same beat would
  // make it ambiguous: a piece nested inside another one carries the timing
  // without the name.
  final bool named;

  const AppDialogPiece({
    super.key,
    required this.index,
    required this.child,
    this.named = true,
  });

  @override
  Widget build(BuildContext context)
  {
    final route = ModalRoute.of(context)?.animation;

    if (route == null)
    {
      return child;
    }

    final start = (index * _staggerStep).clamp(0.0, 1.0 - _staggerSpan);

    final animation = CurvedAnimation(
      parent: route,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutCubic),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    // The overshoot the window used to do as a whole, on this piece's beat. It
    // is kept off the fade because easeOutBack goes past 1 on its way to
    // settling, and an opacity may not.
    final pop = CurvedAnimation(
      parent: route,
      curve: Interval(start, start + _staggerSpan, curve: Curves.easeOutBack),
      reverseCurve: Interval(start, start + _staggerSpan, curve: Curves.easeIn),
    );

    // Fading and growing in place, and travelling nowhere. The way out is the
    // same thing backwards: a piece shrinks and fades where it stands rather
    // than being drawn back to the middle of the screen.
    return FadeTransition(
      // Named so a test can ask a piece how far along it is, which is the only
      // way to see an order that exists in time rather than in space.
      key: named ? ValueKey('appDialogPiece$index') : null,
      opacity: animation,
      // Centred by default, and it must stay that way: about any other corner
      // the piece would slide as it grew, which is the travelling this is here
      // to be rid of.
      child: ScaleTransition(
        scale: Tween<double>(begin: _pieceScale, end: 1).animate(pop),
        child: child,
      ),
    );
  }
}

// One floating piece: the title, a field or two, a card of content.
//
// Its Material does two jobs — it is the ancestor the text fields look for, and
// it absorbs the tap so a tap on the paper between pieces reaches the barrier.
// Nothing may wrap the stack in a second one, or the gaps stop being gaps.
class AppDialogPill extends StatelessWidget
{
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  // Set where several pieces stand one over the other and reading them as one
  // window matters more than each being as wide as what it holds.
  final bool expand;

  // Surfaces take the deeper of the two shadows and round controls the lighter
  // one, so a piece reads as a sheet standing over the page and a button as a
  // button lying on it.
  final List<BoxShadow> shadow;

  const AppDialogPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(_pillPadding),
    this.radius = _pillRadius,
    this.shadow = AppTheme.dialogShadow,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final borderRadius = BorderRadius.circular(radius);

    final Widget piece = Container(
      // Decoration only: a DecoratedBox does not answer a hit test, so the
      // shadow around the piece does not become part of it.
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: Material(
        color: Colors.white,
        borderRadius: borderRadius,
        elevation: 0,
        child: Padding(padding: padding, child: child),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: piece) : piece;
  }
}
