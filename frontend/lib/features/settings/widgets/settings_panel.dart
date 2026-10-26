import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/page_heading.dart';
import '../../../shared/widgets/page_transition.dart';

// Every settings section is one column this wide.
const double kSettingsColumnWidth = 800;

const double kSettingsPanelGap = 28;

// A row's button, as the buttons inside the app's other cards.
const double kSettingsButtonHeight = 40;
const double kSettingsButtonFontSize = 13;

const double _panelRadius = 24;

const double _rowSide = 22;
const double _rowVertical = 16;
const double _rowMinHeight = 76;

const double _tileSize = 44;
const double _tileRadius = 14;
const double _tileGap = 16;

const double _bandTop = 18;
const double _bandBottom = 22;
const double _bandGap = 14;

const double _trailingGap = 16;

// Narrower rows put their control under the text.
const double _stackedBelow = 480;

// Below the wide window (AppPageDensity).
const double _densePanelGap = 18;
const double _densePanelRadius = 20;
const double _denseRowSide = 16;
const double _denseRowVertical = 8;
const double _denseRowMinHeight = 56;
const double _denseTileSize = 34;
const double _denseTileRadius = 11;
const double _denseTileGap = 12;
const double _denseBandTop = 12;
const double _denseBandBottom = 14;
const double _denseBandGap = 10;
const double _denseTrailingGap = 12;

class SettingsColumn extends StatelessWidget
{
  final List<Widget> children;

  const SettingsColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context)
  {
    final bool compact = AppBreakpoints.of(context).isNarrow;
    final double gap = AppPageDensity.of(context) ? _densePanelGap : kSettingsPanelGap;

    return PageTransitionScrollView(
      child: Padding(
        // Side padding adds to the page margin, so it is dropped when compact.
        padding: EdgeInsets.only(top: 16, left: compact ? 0 : 32, right: compact ? 0 : 32, bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSettingsColumnWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  children[i],
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget
{
  final String? heading;
  final List<Widget> rows;

  const SettingsPanel({super.key, this.heading, required this.rows});

  @override
  Widget build(BuildContext context)
  {
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppPageDensity.of(context) ? _densePanelRadius : _panelRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const _Hairline(),
            rows[i],
          ],
        ],
      ),
    );

    final String? heading = this.heading;

    if (heading == null)
    {
      return card;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeading(heading),
        const SizedBox(height: kPageHeadingGap),
        card,
      ],
    );
  }
}

class _Hairline extends StatelessWidget
{
  const _Hairline();

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double side = dense ? _denseRowSide : _rowSide;

    return Container(
      height: 1,
      margin: EdgeInsets.only(
        left: side + (dense ? _denseTileSize + _denseTileGap : _tileSize + _tileGap),
        right: side,
      ),
      color: AppTheme.trialLine,
    );
  }
}

class SettingsRow extends StatelessWidget
{
  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;

  // Beside the title, as the current session's mark.
  final Widget? titleMark;

  final Widget? trailing;

  const SettingsRow({
    super.key,
    required this.icon,
    this.tint = AppTheme.trialTealDeep,
    required this.title,
    this.subtitle,
    this.titleMark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context)
  {
    final String? subtitle = this.subtitle;
    final Widget? titleMark = this.titleMark;
    final Widget? trailing = this.trailing;

    final bool dense = AppPageDensity.of(context);
    final double vertical = dense ? _denseRowVertical : _rowVertical;
    final double tile = dense ? _denseTileSize : _tileSize;
    final double tileGap = dense ? _denseTileGap : _tileGap;

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: settingsTitleStyle(dense: dense)),
            ?titleMark,
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: dense ? 1 : 3),
          Text(subtitle, style: settingsLineStyle(dense: dense)),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? _denseRowSide : _rowSide, vertical: vertical),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final Widget head = ConstrainedBox(
            constraints: BoxConstraints(minHeight: (dense ? _denseRowMinHeight : _rowMinHeight) - 2 * vertical),
            child: Row(
              children: [
                SettingsIconTile(icon: icon, tint: tint),
                SizedBox(width: tileGap),
                Expanded(child: text),
                if (trailing != null && constraints.maxWidth >= _stackedBelow) ...[
                  SizedBox(width: dense ? _denseTrailingGap : _trailingGap),
                  trailing,
                ],
              ],
            ),
          );

          if (trailing == null || constraints.maxWidth >= _stackedBelow)
          {
            return head;
          }

          // Too narrow beside the text: the control goes under it.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head,
              SizedBox(height: dense ? _denseBandGap : _bandGap),
              Padding(
                padding: EdgeInsets.only(left: tile + tileGap),
                child: trailing,
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsBand extends StatelessWidget
{
  final IconData icon;
  final String title;
  final Widget child;

  const SettingsBand({super.key, required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);
    final double side = dense ? _denseRowSide : _rowSide;
    final double tileGap = dense ? _denseTileGap : _tileGap;

    return Padding(
      padding: EdgeInsets.fromLTRB(side, dense ? _denseBandTop : _bandTop, side, dense ? _denseBandBottom : _bandBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconTile(icon: icon),
              SizedBox(width: tileGap),
              Text(title, style: settingsTitleStyle(dense: dense)),
            ],
          ),
          SizedBox(height: dense ? _denseBandGap : _bandGap),
          Padding(
            padding: EdgeInsets.only(left: (dense ? _denseTileSize : _tileSize) + tileGap),
            child: child,
          ),
        ],
      ),
    );
  }
}

class SettingsIconTile extends StatelessWidget
{
  final IconData icon;
  final Color tint;

  const SettingsIconTile({super.key, required this.icon, this.tint = AppTheme.trialTealDeep});

  @override
  Widget build(BuildContext context)
  {
    final bool dense = AppPageDensity.of(context);

    return Container(
      width: dense ? _denseTileSize : _tileSize,
      height: dense ? _denseTileSize : _tileSize,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(dense ? _denseTileRadius : _tileRadius),
      ),
      child: Icon(icon, size: dense ? 18 : 24, color: tint),
    );
  }
}

TextStyle settingsTitleStyle({bool dense = false}) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 14.5 : 16,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOcean,
    );

TextStyle settingsLineStyle({bool dense = false}) => GoogleFonts.plusJakartaSans(
      fontSize: dense ? 12.5 : 13.5,
      fontWeight: FontWeight.w500,
      height: 1.42,
      color: AppTheme.trialMutedText,
    );
