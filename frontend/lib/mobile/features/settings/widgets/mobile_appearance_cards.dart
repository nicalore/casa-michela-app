import 'package:flutter/material.dart';

import '../../../../core/theme/theme_colours.dart';
import '../../../../core/theme/theme_choice.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../features/settings/utils/settings_strings.dart';
import '../../../../services/account_colour_theme.dart';
import '../../../shared/widgets/mobile_choice_tile.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_notice.dart';
import '../../profile/widgets/mobile_detail_card.dart';

const double _cardGap = 12;
const double _tileGap = 10;
const double _headGap = 10;

const double _phonePreview = 112;
const double _tabletPreview = 150;

const EdgeInsets _cardPadding = EdgeInsets.fromLTRB(16, 14, 16, 16);
const double _cardRadius = 22;

class MobileAppearanceCards extends StatelessWidget
{
  final bool tablet;

  const MobileAppearanceCards({super.key, required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final Widget theme = _SettingCard(
      setting: kThemeSetting,
      // The tick follows the account's choice, which may change without the colours changing.
      child: ValueListenableBuilder<ThemeChoice>(
        valueListenable: AccountColourTheme.choice,
        builder: (context, _, _) => _ThemeChoices(previewHeight: tablet ? _tabletPreview : _phonePreview),
      ),
    );

    final Widget colors = _SettingCard(
      setting: kColorsSetting,
      child: _Choices(
        setting: kColorsSetting,
        leading: (option) => MobileSwatches(colors: option.colors),
      ),
    );

    final Widget language = _SettingCard(
      setting: kLanguageSetting,
      child: _Choices(
        setting: kLanguageSetting,
        leading: (option) => MobileLanguageCode(
          code: option.code ?? option.label.substring(0, 2).toUpperCase(),
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

  Future<void> _chooseMode(BuildContext context, ThemeChoice mode) async
  {
    if (mode == AccountColourTheme.choice.value)
    {
      return;
    }

    try
    {
      await AccountColourTheme.chooseMode(mode);
    }
    catch (e)
    {
      if (context.mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final List<AppearanceOption> options = kThemeSetting.options;
    final ThemeChoice chosen = AccountColourTheme.choice.value;

    Widget tile(int i)
    {
      final ThemeChoice mode = ThemeChoice.values[i];

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _chooseMode(context, mode),
        child: MobileThemeTile(
          label: options[i].label,
          dark: mode == ThemeChoice.dark,
          split: mode == ThemeChoice.system,
          chosen: mode == chosen,
          available: options[i].available,
          previewHeight: previewHeight,
        ),
      );
    }

    // Chiaro and Scuro side by side as ever; Automatico under them, centred, as wide as either.
    // Shares, not a LayoutBuilder: on a tablet the card is measured beside Lingua, which a LayoutBuilder refuses.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tile(0)),
              const SizedBox(width: _cardGap),
              Expanded(child: tile(1)),
            ],
          ),
        ),
        const SizedBox(height: _cardGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const SizedBox(width: _cardGap / 2),
              Expanded(flex: 2, child: tile(2)),
              const SizedBox(width: _cardGap / 2),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

// The first option is the one in force, but for palettes, which name their theme.
class _Choices extends StatelessWidget
{
  final AppearanceSetting setting;
  final Widget Function(AppearanceOption option) leading;

  const _Choices({required this.setting, required this.leading});

  Future<void> _choose(BuildContext context, ColourTheme theme) async
  {
    if (theme == ThemeColours.current.value)
    {
      return;
    }

    try
    {
      await AccountColourTheme.choose(theme);
    }
    catch (e)
    {
      if (context.mounted)
      {
        MobileNotice.show(context, readableApiError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final List<AppearanceOption> options = setting.options;

    Widget tile(int i)
    {
      final ColourTheme? theme = options[i].colourTheme;

      final Widget choice = MobileChoiceTile(
        leading: leading(options[i]),
        label: options[i].label,
        chosen: theme == null ? i == 0 : theme == ThemeColours.current.value,
        available: options[i].available,
      );

      if (theme == null)
      {
        return choice;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(context, theme),
        child: choice,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: _tileGap),
          tile(i),
        ],
      ],
    );
  }
}
