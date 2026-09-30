import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mobile_entrance_motion.dart';
import 'mobile_gold_button.dart';
import 'mobile_info_button.dart';
import 'mobile_load_switcher.dart';
import 'mobile_nav_sheet.dart';
import 'mobile_wizard_parts.dart';

const double _footerGap = 16;
const double _footerHeight = 58;

const double _footerClearance = 20;

const double _capsuleHeight = 36;

// A step of the way in turning, and the aside sliding along with it.
const Duration kMobileFlowTurn = Duration(milliseconds: 340);
const Curve kMobileFlowTurnCurve = Curves.easeInOutCubic;

// The keyboard covers the floating buttons instead of lifting them.
class MobileFlowScaffold extends StatelessWidget
{
  final Widget body;
  final Widget? footer;
  final bool tablet;
  final Widget? aside;
  final double asideWidth;

  const MobileFlowScaffold({
    super.key,
    required this.body,
    this.footer,
    this.tablet = false,
    this.aside,
    this.asideWidth = 0,
  });

  // End padding a page needs to clear the floating buttons.
  static double endRoomOf(BuildContext context)
  {
    return MediaQuery.viewPaddingOf(context).bottom + _footerGap + _footerHeight + _footerClearance;
  }

  static double marginOf({required bool tablet}) => tablet ? 44 : 20;

  @override
  Widget build(BuildContext context)
  {
    final Widget? aside = this.aside;
    final Widget footer = MobileEntranceShift(
      part: MobileEntrancePart.foot,
      child: MobileLoadSwitcher(child: this.footer),
    );
    final double bottom = MediaQuery.viewPaddingOf(context).bottom + _footerGap;
    final double margin = marginOf(tablet: false);
    final double left = aside == null ? 0 : asideWidth;

    final Widget page = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(bottom: false, child: body),
    );

    // The buttons lie outside the Scaffold, so their text style comes from here.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileEntranceShift(
            part: MobileEntrancePart.head,
            // Always a row, so the page is not built anew when the aside comes.
            child: Scaffold(
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Aside(width: asideWidth, child: aside),
                  Expanded(child: page),
                ],
              ),
            ),
          ),
          if (tablet)
            AnimatedPositioned(
              duration: kMobileFlowTurn,
              curve: kMobileFlowTurnCurve,
              left: left,
              right: 0,
              bottom: bottom,
              child: Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: footer)),
            )
          else
            Positioned(left: margin, right: margin, bottom: bottom, child: footer),
        ],
      ),
    );
  }
}

// Slides in from the left edge as the page narrows beside it, and back out.
class _Aside extends StatefulWidget
{
  final double width;
  final Widget? child;

  const _Aside({required this.width, required this.child});

  @override
  State<_Aside> createState() => _AsideState();
}

class _AsideState extends State<_Aside>
{
  // Kept while it slides out.
  Widget? _shown;

  @override
  void initState()
  {
    super.initState();
    _shown = widget.child;
  }

  @override
  void didUpdateWidget(_Aside oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (widget.child != null)
    {
      _shown = widget.child;
    }
  }

  void _onEnd()
  {
    if (widget.child == null && _shown != null)
    {
      setState(() => _shown = null);
    }
  }

  @override
  Widget build(BuildContext context)
  {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.child == null ? 0 : 1),
      duration: kMobileFlowTurn,
      curve: kMobileFlowTurnCurve,
      onEnd: _onEnd,
      builder: (context, open, aside) => SizedBox(
        width: widget.width * open,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerRight,
            minWidth: widget.width,
            maxWidth: widget.width,
            child: aside,
          ),
        ),
      ),
      child: _shown ?? const SizedBox.shrink(),
    );
  }
}

class MobileFlowForm extends StatelessWidget
{
  final List<Widget> children;
  final bool tablet;

  const MobileFlowForm({super.key, required this.children, required this.tablet});

  // Matches the sign-in card's top on tablets.
  static const double _tabletTop = 120;
  static const double _phoneTop = 4;

  @override
  Widget build(BuildContext context)
  {
    final double margin = MobileFlowScaffold.marginOf(tablet: tablet);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        margin,
        tablet ? _tabletTop : _phoneTop,
        margin,
        MobileFlowScaffold.endRoomOf(context),
      ),
      children: [
        for (final child in children)
          tablet ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: child)) : child,
      ],
    );
  }
}

class MobileFlowFooter extends StatelessWidget
{
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onBack;
  final bool busy;

  const MobileFlowFooter({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onBack,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final VoidCallback? onBack = this.onBack;

    // Leaving, it spins while the next page loads out of sight, never on the way out.
    final MobileEntranceMotion? entrance = MobileEntranceMotion.maybeOf(context);
    final bool busy = entrance != null && entrance.leaving ? entrance.waiting : this.busy;

    return Row(
      children: [
        if (onBack != null) ...[
          MobileWizardBackButton(onTap: busy ? null : onBack),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: MobileGoldButton(label: label, icon: icon, busy: busy, onPressed: onPressed),
        ),
      ],
    );
  }
}

class MobileFlowCapsule extends StatelessWidget
{
  static const String label = 'Torna al login';

  final VoidCallback onTap;
  final bool busy;

  const MobileFlowCapsule({super.key, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context)
  {
    final Color ink = Colors.white.withValues(alpha: 0.92);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          height: _capsuleHeight,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_capsuleHeight / 2),
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ink),
                )
              else
                Icon(Icons.logout_rounded, size: 16, color: ink),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileFlowHead extends StatelessWidget
{
  final String eyebrow;
  final String title;
  final bool tablet;

  // Null on tablets, where the rail holds it.
  final Widget? capsule;

  final VoidCallback? onInfo;

  const MobileFlowHead({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.tablet,
    this.capsule,
    this.onInfo,
  });

  @override
  Widget build(BuildContext context)
  {
    final Widget? capsule = this.capsule;
    final VoidCallback? onInfo = this.onInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _capsuleHeight),
          child: Row(
            children: [
              Expanded(child: MobileFlowEyebrow(eyebrow, tablet: tablet)),
              ?capsule,
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: MobileFlowTitle(title, tablet: tablet)),
            if (onInfo != null) ...[
              const SizedBox(width: 14),
              MobileInfoButton(onTap: onInfo),
            ],
          ],
        ),
      ],
    );
  }
}

class MobileFlowEyebrow extends StatelessWidget
{
  final String text;
  final bool tablet;

  const MobileFlowEyebrow(this.text, {super.key, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: tablet ? 12.5 : 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: Colors.white.withValues(alpha: 0.62),
      ),
    );
  }
}

class MobileFlowTitle extends StatelessWidget
{
  final String text;
  final bool tablet;
  final double? size;

  const MobileFlowTitle(this.text, {super.key, required this.tablet, this.size});

  @override
  Widget build(BuildContext context)
  {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size ?? (tablet ? 36 : 30),
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.08,
        color: Colors.white,
      ),
    );
  }
}
