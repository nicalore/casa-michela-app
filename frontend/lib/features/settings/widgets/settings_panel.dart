import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
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

class SettingsColumn extends StatelessWidget
{
  final List<Widget> children;

  const SettingsColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context)
  {
    final bool compact = AppBreakpoints.of(context).isCompact;

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
                  if (i > 0) const SizedBox(height: kSettingsPanelGap),
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
        borderRadius: BorderRadius.circular(_panelRadius),
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
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: _rowSide + _tileSize + _tileGap, right: _rowSide),
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

    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: settingsTitleStyle()),
            ?titleMark,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle, style: settingsLineStyle()),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _rowSide, vertical: _rowVertical),
      child: LayoutBuilder(
        builder: (context, constraints)
        {
          final Widget head = ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight - 2 * _rowVertical),
            child: Row(
              children: [
                SettingsIconTile(icon: icon, tint: tint),
                const SizedBox(width: _tileGap),
                Expanded(child: text),
                if (trailing != null && constraints.maxWidth >= _stackedBelow) ...[
                  const SizedBox(width: _trailingGap),
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
              const SizedBox(height: _bandGap),
              Padding(
                padding: const EdgeInsets.only(left: _tileSize + _tileGap),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(_rowSide, _bandTop, _rowSide, _bandBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconTile(icon: icon),
              const SizedBox(width: _tileGap),
              Text(title, style: settingsTitleStyle()),
            ],
          ),
          const SizedBox(height: _bandGap),
          Padding(
            padding: const EdgeInsets.only(left: _tileSize + _tileGap),
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
    return Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_tileRadius),
      ),
      child: Icon(icon, size: 24, color: tint),
    );
  }
}

TextStyle settingsTitleStyle() => GoogleFonts.plusJakartaSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppTheme.trialOcean,
    );

TextStyle settingsLineStyle() => GoogleFonts.plusJakartaSans(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      height: 1.42,
      color: AppTheme.trialMutedText,
    );
