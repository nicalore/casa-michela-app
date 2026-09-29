import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../profile/widgets/mobile_detail_card.dart';
import 'mobile_choice_tile.dart';

const double _cardGap = 12;
const double _tileGap = 10;
const double _headGap = 10;

const double _phonePreview = 112;
const double _tabletPreview = 150;

const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 14, 16, 16);
const double _cardRadius = 22;

const List<Color> _brandColors = [
  AppTheme.trialDeepWater,
  AppTheme.trialTealDeep,
  AppTheme.trialSeaGreen,
  AppTheme.trialGold,
  AppTheme.trialViolet,
];

const Map<String, String> _languageCodes = {'Italiano': 'IT', 'Inglese': 'EN'};

class MobileAppearanceCards extends StatelessWidget
{
  final bool tablet;

  const MobileAppearanceCards({super.key, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final Widget theme = _SettingCard(
      setting: kThemeSetting,
      child: _ThemeChoices(previewHeight: tablet ? _tabletPreview : _phonePreview),
    );

    final Widget colors = _SettingCard(
      setting: kColorsSetting,
      child: _Choices(
        setting: kColorsSetting,
        leading: (_) => const MobileSwatches(colors: _brandColors),
      ),
    );

    final Widget language = _SettingCard(
      setting: kLanguageSetting,
      child: _Choices(
        setting: kLanguageSetting,
        leading: (option) => MobileLanguageCode(
          code: _languageCodes[option.label] ?? option.label.substring(0, 2).toUpperCase(),
          available: option.available,
        ),
      ),
    );

    if (!tablet)
    {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          theme,
          const SizedBox(height: _cardGap),
          colors,
          const SizedBox(height: _cardGap),
          language,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: theme),
              const SizedBox(width: _cardGap),
              Expanded(child: language),
            ],
          ),
        ),
        const SizedBox(height: _cardGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: colors),
            const SizedBox(width: _cardGap),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget
{
  final AppearanceSetting setting;
  final Widget child;

  const _SettingCard({required this.setting, required this.child});

  @override
  Widget build(BuildContext context)
  {
    return MobileGlassPanel(
      padding: _cardPadding,
      borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileCardHead(icon: setting.icon, title: setting.title),
          const SizedBox(height: _headGap),
          child,
        ],
      ),
    );
  }
}

class _ThemeChoices extends StatelessWidget
{
  final double previewHeight;

  const _ThemeChoices({required this.previewHeight});

  @override
  Widget build(BuildContext context)
  {
    final List<AppearanceOption> options = kThemeSetting.options;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: _cardGap),
          Expanded(
            child: MobileThemeTile(
              label: options[i].label,
              dark: i > 0,
              chosen: i == 0,
              available: options[i].available,
              previewHeight: previewHeight,
            ),
          ),
        ],
      ],
    );
  }
}

class _Choices extends StatelessWidget
{
  final AppearanceSetting setting;
  final Widget Function(AppearanceOption option) leading;

  const _Choices({required this.setting, required this.leading});

  @override
  Widget build(BuildContext context)
  {
    final List<AppearanceOption> options = setting.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: _tileGap),
          MobileChoiceTile(
            leading: leading(options[i]),
            label: options[i].label,
            chosen: i == 0,
            available: options[i].available,
          ),
        ],
      ],
    );
  }
}
