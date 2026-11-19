import 'package:flutter/material.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/theme_choice.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/account_colour_theme.dart';
import '../../../shared/widgets/app_dropdown_field.dart';
import '../../../shared/widgets/app_segmented_switch.dart';
import '../../../shared/widgets/page_density.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/settings_strings.dart';
import '../widgets/appearance_choices.dart';
import '../widgets/settings_panel.dart';

const double _tileGap = 14;
const double _languageWidth = 260;
const double _denseLanguageWidth = 210;
const double _menuCode = 26;

// The language's first option is the one in force; the mode (light, dark, automatic) and the colours are the account's.
class AppearanceTab extends StatelessWidget
{
  const AppearanceTab({super.key});

  // Chiaro, Scuro, Automatico: one row while each tile keeps a usable width, else they wrap at full size.
  Widget _buildThemes(BuildContext context)
  {
    final List<AppearanceOption> options = kThemeSetting.options;

    return ValueListenableBuilder<ThemeChoice>(
      valueListenable: AccountColourTheme.choice,
      builder: (context, chosen, _) => LayoutBuilder(
        builder: (context, constraints)
        {
          final double shared = (constraints.maxWidth - _tileGap * (options.length - 1)) / options.length;

          return Wrap(
            spacing: _tileGap,
            runSpacing: _tileGap,
            children: [
              for (var i = 0; i < options.length; i++)
                ThemePreviewTile(
                  label: options[i].label,
                  dark: ThemeChoice.values[i] == ThemeChoice.dark,
                  split: ThemeChoice.values[i] == ThemeChoice.system,
                  chosen: ThemeChoice.values[i] == chosen,
                  available: options[i].available,
                  sharedWidth: shared,
                  onTap: () => _chooseMode(context, ThemeChoice.values[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPalettes(BuildContext context)
  {
    final ColourTheme inForce = ThemeColours.current.value;

    return Wrap(
      spacing: _tileGap,
      runSpacing: _tileGap,
      children: [
        for (final AppearanceOption option in kColorsSetting.options)
          PaletteTile(
            label: option.label,
            colors: option.colors,
            chosen: option.colourTheme == inForce,
            onTap: () => _choose(context, option.colourTheme!),
          ),
      ],
    );
  }

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
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
  }

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
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
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
            SettingsBand(icon: kThemeSetting.icon, title: kThemeSetting.title, child: _buildThemes(context)),
            SettingsBand(icon: kColorsSetting.icon, title: kColorsSetting.title, child: _buildPalettes(context)),
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
