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

// How far apart in time the pieces arrive, as a fraction of the whole
// transition, and how long each one takes. They come in from the top down; on
// the way out the order reverses on its own, which is what an interval does
// when the animation runs backwards.
const double _staggerStep = 0.13;
const double _staggerSpan = 0.62;

// Room kept around the scrolling middle so the shadows of the pieces inside it
// are not cut off where the viewport clips.
const double _shadowRoom = 12;

const double _pillRadius = 28;
const double _pillPadding = 28;

// The round close standing off the title pill.
const double _closeSize = 44;

// A dialog made of separate pieces floating over the blurred page, instead of
// one white panel holding everything. What belongs together is a piece; the
// paper between the pieces is the page, and it is left to show through.
//
// This is what every window of the app is built from. It takes a list of bodies
// rather than one, and that is the difference the arrangement rests on: a
// panel that took a single body left a window with two things to say running
// them together behind one sheet.
class AppDialogStack extends StatelessWidget
{
  final String eyebrow;
  final String title;

  // Something standing to the left of the two lines of the title, where the
  // title is a person: the face of whoever the window is about. It is read
  // before the name is, so it belongs beside it and not further down among the
  // facts.
  final Widget? leading;

  // Each one floats on its own, in the order given, with air between them.
  final List<Widget> children;

  final Widget? footer;

  // Of the whole stack, arrows and all — not of the widest piece in it.
  final double maxWidth;

  // Left out, the stack stands in the middle of the screen. Given, the caller
  // places it: a window opened beside one already open has to sit off centre so
  // that what it was opened from stays visible behind it.
  final Alignment alignment;

  // The cross is how you leave a window, and it is on by default because every
  // window can be left. What turns it off is a window that is itself a question
  // — throw this away? leave without saving? — where the two buttons at the
  // foot are the two answers and one of them happens to be "no". A cross there
  // would be a third way of saying the same "no", offered in a different place.
  //
  // It cannot be read off the footer: a details window has two buttons down
  // there too and neither of them answers anything.
  final bool showClose;

  // What the cross does. Left out it simply closes the window, which is what
  // nearly all of them want.
  //
  // A window with something to ask before it goes passes its own way out here —
  // the edit wizard checks for unsaved work first, a wizard opened to edit a row
  // tells the page behind it to let the row go. That errand used to hang off the
  // ANNULLA at the foot, and when the ANNULLA went the errand would have gone
  // with it: the cross has to be the same way out, not merely another one.
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
    this.footer,
    this.maxWidth = 720,
    this.alignment = Alignment.center,
    this.showClose = true,
    this.onClose,
    this.fillLast = false,
  });

  Widget _buildTitleRow(BuildContext context)
  {
    // One line each, and the pill measured from them: a title is read as a
    // name, and a name broken across two lines reads as two things. The pill
    // takes the width the words need and no more, which is why both lines are
    // measured by their longest — the usual measure hands a paragraph the whole
    // of the room it was allowed, and the pill would come out stretched to the
    // window with the words sitting at one end of it.
    //
    // The room the title gets is the window rather than the width the caller
    // asked for its pieces: a filter window is 520 wide and its own name did
    // not fit in that, which is what used to fold "Filtra per disciplina
    // interna" onto a second line. See the piece widths in build().
    //
    // Narrower than the words even so — a phone, a name of a school with its
    // town in it — and the title is cut with the tooltip carrying the rest, the
    // same answer the cards of the app give. Cut and silent it stopped saying
    // which of them had been opened, which is the one question a title is there
    // to answer.
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
      ],
    );

    final Widget pill = AppDialogPill(
      // A round face wants the same air all around it, so where there is one
      // the left inset comes in to meet it and the pill is a touch shallower:
      // the two lines of words are shorter than the circle beside them, and
      // kept at the old height the pill grew a band of white under them.
      padding: leading == null
          ? const EdgeInsets.fromLTRB(36, 22, 36, 24)
          : const EdgeInsets.fromLTRB(22, 20, 36, 20),
      child: leading == null
          ? heading
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                leading!,
                const SizedBox(width: 18),
                // Loose, so a name longer than the window is cut at its own end
                // rather than pushing the face out of the pill.
                Flexible(child: heading),
              ],
            ),
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
          // stays centred on the stack rather than on what is left of it.
          padding: const EdgeInsets.symmetric(horizontal: _closeSize + 16),
          child: pill,
        ),
        Positioned(
          right: 0,
          child: CarouselArrowButton(
            icon: Icons.close_rounded,
            hoverColor: AppTheme.trialGoldSurface,
            hoverIconColor: AppTheme.trialTealDeep,
            onTap: onClose ?? () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // The pieces between the title and the footer.
  //
  // Normally they scroll together: a window taller than the screen is scrolled
  // as one, pieces and paper included. A window whose last piece is a list is
  // built the other way round — everything above it stays where it is and only
  // the list moves, which is what fillLast asks for. What scrolls inside that
  // last piece is the caller's business; all this does is hand it the height
  // that is left.
  List<Widget> _buildBody(double width)
  {
    if (!fillLast)
    {
      return [
        Flexible(
          child: _atMost(width, SingleChildScrollView(
            // The scroll view must not answer for the paper around the pieces:
            // its own default is opaque, which would swallow every tap in the
            // gaps — and a tap on the gaps reaching the barrier is the whole
            // idea of a dialog made of separate pieces.
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
      // Full screen on purpose. The BackdropFilter of showBlurredDialog sizes
      // itself to its child, so a stack that shrink-wrapped here would blur only
      // the rectangle the pieces happen to occupy.
      // A dialog on its way out answers to nothing any more. It takes a quarter
      // of a second to fade, and for that long its buttons stay drawn where they
      // were: a second tap — a double click, or impatience — used to land on a
      // dialog already gone, closing whatever was left underneath or redoing what
      // the first tap had already done.
      //
      // isCurrent is true only while this dialog is the topmost one, and turns
      // false the instant it starts leaving. It lives here and not on every
      // button because it is a property of the dialog, and remembering it at
      // every one of the buttons is the same as not remembering it.
      child: _WhileItIsThere(
        child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Never the full width of the window: the pieces at the top and the
            // bottom are outside the scrolling middle and have no padding of
            // their own, so without this the round close button and the buttons
            // would stand against the edge of the screen with their shadows cut
            // off by it.
            //
            // The room, and not maxWidth, because that one is what the pieces
            // are worth and not what the window is: the title is a name and
            // takes the width of its own words, which are regularly longer than
            // the 520 a filter window gives what it holds. It is capped below,
            // piece by piece.
            maxWidth: room,
            // Measured against the window rather than against the constraints
            // coming down, because those are unbounded wherever this is pumped
            // inside a scroll view, and the Flexible below would have nothing
            // to be flexible in.
            maxHeight: window.height - keyboard - 2 * _windowMargin,
          ),
          // Transparent on purpose, and load-bearing twice: text outside a
          // Material is painted with the yellow underline of an unstyled
          // paragraph, which is what the two buttons at the foot were wearing —
          // and a transparent Material, unlike an opaque one, does not answer
          // the hit test, so the paper between the pieces stays paper.
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

// Answers to a tap only while the dialog holding it is still the topmost one.
// Outside a dialog — the login page uses this same stack — there is nothing to
// switch off and it lets everything through.
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

// A piece arriving on its own beat: the title first, then whatever is under it,
// the footer last. The route's own animation drives it, so closing plays the
// same thing backwards without a second controller to keep in step — and a
// dialog that builds its own pieces deeper down, as the filters do inside a
// card, can carry the count on rather than having them all arrive at once.
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

    return FadeTransition(
      // Named so a test can ask a piece how far along it is, which is the only
      // way to see an order that exists in time rather than in space.
      key: named ? ValueKey('appDialogPiece$index') : null,
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

// One floating piece of a dialog: the title, a field or two, a card of content.
//
// The Material inside it is doing two jobs at once. It is the ancestor the text
// fields go looking for, which used to come from the Dialog this layout no
// longer has; and it absorbs the tap, so that a tap on a piece stays in the
// piece while a tap on the paper between two of them travels through to the
// barrier and closes the window. Nothing may wrap the stack in a second one, or
// the gaps stop being gaps.
class AppDialogPill extends StatelessWidget
{
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  // Set where several pieces stand one over the other and reading them as one
  // window matters more than each being as wide as what it holds: the values of
  // a school and the programmes under them are the same window, and a narrower
  // second piece read as a footnote to the first.
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
