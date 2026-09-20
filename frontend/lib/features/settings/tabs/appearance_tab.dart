import 'package:flutter/material.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/page_transition.dart';

const double _maxWidth = 560;
const double _cardGap = 24;
const double _chipGap = 10;

const double _comingOpacity = 0.6;

class _Option
{
  final String label;

  // False for an option not built yet: muted and inert.
  final bool available;

  const _Option(this.label, {this.available = true});
}

class _Setting
{
  final String title;
  final IconData icon;

  // The first is the one in force.
  final List<_Option> options;

  const _Setting(this.title, this.icon, this.options);
}

const List<_Setting> _settings = [
  _Setting('Tema', Icons.brightness_6_rounded, [
    _Option('Chiaro'),
    _Option('Scuro', available: false),
  ]),
  _Setting('Colori', Icons.palette_rounded, [
    _Option('Casa Michela'),
  ]),
  _Setting('Lingua', Icons.translate_rounded, [
    _Option('Italiano'),
    _Option('Inglese', available: false),
  ]),
];

class AppearanceTab extends StatelessWidget
{
  const AppearanceTab({super.key});

  Widget _buildOption(_Option option, {required bool chosen})
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

    return Tooltip(
      message: 'In arrivo',
      waitDuration: const Duration(milliseconds: 400),
      child: IgnorePointer(
        child: Opacity(opacity: _comingOpacity, child: chip),
      ),
    );
  }

  Widget _buildSetting(_Setting setting)
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

  @override
  Widget build(BuildContext context)
  {
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
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pageTransitionBlocks([
                for (var i = 0; i < _settings.length; i++) ...[
                  if (i > 0) const SizedBox(height: _cardGap),
                  _buildSetting(_settings[i]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
