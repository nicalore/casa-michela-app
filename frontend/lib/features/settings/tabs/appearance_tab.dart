import 'package:flutter/material.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/page_density.dart';
import '../utils/settings_strings.dart';
import '../widgets/appearance_choices.dart';
import '../widgets/settings_panel.dart';

const double _tileGap = 14;
const double _languageWidth = 260;
const double _denseLanguageWidth = 210;
const double _menuCode = 26;

// The first option of each setting is the one in force.
class AppearanceTab extends StatelessWidget
{
  const AppearanceTab({super.key});

  Widget _buildThemes()
  {
    final List<AppearanceOption> options = kThemeSetting.options;

    return Wrap(
      spacing: _tileGap,
      runSpacing: _tileGap,
      children: [
        for (var i = 0; i < options.length; i++)
          ThemePreviewTile(
            label: options[i].label,
            dark: i > 0,
            chosen: i == 0,
            available: options[i].available,
          ),
      ],
    );
  }

  Widget _buildPalettes()
  {
    final List<AppearanceOption> options = kColorsSetting.options;

    return Wrap(
      spacing: _tileGap,
      runSpacing: _tileGap,
      children: [
        for (var i = 0; i < options.length; i++)
          PaletteTile(label: options[i].label, colors: options[i].colors, chosen: i == 0),
      ],
    );
  }

  Widget _buildLanguages(bool dense)
  {
    final List<AppearanceOption> options = kLanguageSetting.options;

    LanguageCode code(AppearanceOption option, {double size = 30}) => LanguageCode(
          code: option.code ?? option.label.substring(0, 2).toUpperCase(),
          available: option.available,
          size: size,
        );

    return SizedBox(
      width: dense ? _denseLanguageWidth : _languageWidth,
      child: AppDropdownField<String>(
        hint: kLanguageSetting.title,
        value: options.first.label,
        options: [
          for (final AppearanceOption option in options)
            AppDropdownOption(
              value: option.label,
              label: option.label,
              leading: code(option, size: _menuCode),
              enabled: option.available,
              disabledReason: kComingSoon,
            ),
        ],
        // The sole language in force cannot change yet.
        onChanged: (_) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return SettingsColumn(
      children: [
        SettingsPanel(
          rows: [
            SettingsBand(icon: kThemeSetting.icon, title: kThemeSetting.title, child: _buildThemes()),
            SettingsBand(icon: kColorsSetting.icon, title: kColorsSetting.title, child: _buildPalettes()),
            SettingsRow(
              icon: kLanguageSetting.icon,
              title: kLanguageSetting.title,
              trailing: _buildLanguages(AppPageDensity.of(context)),
            ),
            SettingsRow(
              icon: Icons.auto_awesome_rounded,
              title: kEffectsTitle,
              subtitle: kEffectsHint,
              trailing: AppSegmentedSwitch(
                value: VisualEffects.of(context),
                trueLabel: kEffectsOn,
                falseLabel: kEffectsOff,
                hugContent: true,
                onChanged: VisualEffects.choose,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
