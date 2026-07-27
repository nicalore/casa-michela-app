import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import 'shared_components.dart';

const double _radius = 30;

// The chrome every dialog of the app wears: a small tracked line naming what
// this window is about, the title under it, a close on the other end, and a rule
// separating all that from the body.
//
// The eyebrow is the same device the top bar uses over a name and the rail over
// a group of sections. It is what makes a dialog read as part of the app rather
// than as a window that arrived from somewhere else, which is why it is not
// optional here.
class AppDialogShell extends StatelessWidget
{
  final String eyebrow;
  final String title;

  final double width;

  // Given, the dialog is that tall whatever it holds — which a wizard needs, or
  // its own height would change from step to step. Left out it is as tall as its
  // body, up to the ceiling below.
  final double? height;

  // Ceiling for a body that could grow past the screen. The body is expected to
  // scroll on its own inside it.
  final double? maxHeight;

  final Widget child;

  // The row of buttons at the foot, already built by the caller: only the caller
  // knows how many there are and what they answer for.
  final Widget? footer;

  // Left out, the dialog stands in the middle of the screen like every other.
  // Given, the caller places it: a window that opens beside one already open —
  // the read-only details reached from another dialog — has to sit off centre so
  // that what it was opened from stays visible behind it. It cannot be done from
  // outside, because a Dialog re-centres itself whatever is wrapped around it.
  final Alignment? alignment;

  // Stronger than the usual one for a panel that floats over another panel
  // rather than over the page: without the extra depth the two whites read as
  // one sheet.
  final List<BoxShadow> shadow;

  const AppDialogShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.width = 500,
    this.height,
    this.maxHeight,
    this.footer,
    this.alignment,
    this.shadow = AppTheme.dialogShadow,
  });

  Widget _buildHeader(BuildContext context)
  {
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, left: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    height: 1.2,
                    color: AppTheme.trialMutedText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: AppTheme.trialOcean,
                  ),
                ),
              ],
            ),
          ),
          FadeHoverIconButton(
            icon: Icons.close,
            color: AppTheme.trialTealDeep,
            hoverColor: AppTheme.trialGoldSurface,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget panel = Container(
      width: width,
      height: height,
      constraints: maxHeight != null ? BoxConstraints(maxHeight: maxHeight!) : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretched, or a body narrower than the dialog — a couple of short
        // values with nothing long under them — is laid out at its own width and
        // ends up standing in the middle of the window instead of starting at
        // the left edge like the title above it.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 32, thickness: 1, color: AppTheme.trialLine),
          Flexible(child: child),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 32, top: 24, bottom: 32),
              child: footer!,
            ),
        ],
      ),
    );

    final Alignment? alignment = this.alignment;

    if (alignment == null)
    {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: panel,
      );
    }

    // No Dialog around it: the Material is what the ink and the text styles
    // underneath expect to find, and the Align is what actually places it.
    return Align(
      alignment: alignment,
      child: Material(color: Colors.transparent, child: panel),
    );
  }
}

// The two buttons at the foot of a dialog: back out on the left, go through with
// it on the right. Equal halves, because neither is a footnote to the other.
class AppDialogFooter extends StatelessWidget
{
  final Widget secondary;
  final Widget primary;

  const AppDialogFooter({
    super.key,
    required this.secondary,
    required this.primary,
  });

  @override
  Widget build(BuildContext context)
  {
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: 16),
        Expanded(child: primary),
      ],
    );
  }
}
