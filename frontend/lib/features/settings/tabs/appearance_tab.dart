import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/page_transition.dart';
import '../utils/settings_strings.dart';

// Two columns once each gets the narrower width; below, one.
const double _minColumnWidth = 300;

// As wide as the single column of the other settings tabs.
const double _maxColumnWidth = 560;

const double _cardGap = 24;
const double _chipGap = 10;
const double _hintGap = 18;

const double _comingOpacity = 0.6;

class AppearanceTab extends StatelessWidget
{
  const AppearanceTab({super.key});

  Widget _buildOption(AppearanceOption option, {required bool chosen})
  {
    final Widget chip = AppSelectableChip(
      label: option.label,
      selected: chosen,
      // The sole option cannot be deselected.
      onSelected: (_) {},
    );

    if (option.available)
    {
      return chip;
    }

    return AppTooltip(
      message: kComingSoon,
      waitDuration: const Duration(milliseconds: 400),
      child: IgnorePointer(
        child: Opacity(opacity: _comingOpacity, child: chip),
      ),
    );
  }

  Widget _buildSetting(AppearanceSetting setting)
  {
    return AppCard(
      title: setting.title,
      compact: true,
      selectable: false,
      leading: AppCardBadge(icon: setting.icon, compact: true),
      child: Wrap(
        spacing: _chipGap,
        runSpacing: _chipGap,
        children: [
          for (var i = 0; i < setting.options.length; i++)
            _buildOption(setting.options[i], chosen: i == 0),
        ],
      ),
    );
  }

  Widget _buildEffects(BuildContext context)
  {
    final bool on = VisualEffects.of(context);

    return AppCard(
      title: kEffectsTitle,
      compact: true,
      selectable: false,
      leading: const AppCardBadge(icon: Icons.auto_awesome_rounded, compact: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kEffectsHint,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
              color: AppTheme.trialMutedText,
            ),
          ),
          const SizedBox(height: _hintGap),
          Wrap(
            spacing: _chipGap,
            runSpacing: _chipGap,
            children: [
              AppSelectableChip(
                label: kEffectsOn,
                selected: on,
                onSelected: (_) => VisualEffects.choose(true),
              ),
              AppSelectableChip(
                label: kEffectsOff,
                selected: !on,
                onSelected: (_) => VisualEffects.choose(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cards side by side share the taller one's height.
  Widget _buildGrid(List<Widget> cards, double width)
  {
    final int columns = width >= 2 * _minColumnWidth + _cardGap ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var first = 0; first < cards.length; first += columns) ...[
          if (first > 0) const SizedBox(height: _cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = first; i < first + columns; i++) ...[
                  if (i > first) const SizedBox(width: _cardGap),
                  Expanded(
                    child: i < cards.length
                        ? PageTransitionItem(slot: PageTransitionItem.header + i, child: cards[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<Widget> cards = [
      for (final setting in kAppearanceSettings) _buildSetting(setting),
      _buildEffects(context),
    ];

    return PageTransitionScrollView(
      child: Padding(
        // Side padding adds to the page margin, so it is dropped when compact.
        padding: EdgeInsets.only(
          top: 16,
          left: AppBreakpoints.of(context).isCompact ? 0 : 32,
          right: AppBreakpoints.of(context).isCompact ? 0 : 32,
          bottom: 32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 2 * _maxColumnWidth + _cardGap),
            child: LayoutBuilder(
              builder: (context, constraints) => _buildGrid(cards, constraints.maxWidth),
            ),
          ),
        ),
      ),
    );
  }
}
