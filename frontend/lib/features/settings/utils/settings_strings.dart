import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/language/app_language.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colours.dart';
import '../../../shared/widgets/password_policy_checklist.dart';
import '../models/session_item.dart';

String get kSettingsTitle => tr('Impostazioni', 'Settings');

String get kAppearanceSection => tr('Aspetto', 'Appearance');
String get kAccessSection => tr('Accesso', 'Sign-in');
String get kDevicesSection => tr('Dispositivi', 'Devices');
String get kSystemSection => tr('Sistema', 'System');
String get kInfoSection => tr('Informazioni', 'About');

String get kTutorialTitle => tr('Tutorial', 'Tutorial');
String get kTutorialSubtitle => tr('Riattiva la guida dei menù.', 'Turn the menu guides back on.');
String get kTutorialChoose => tr('Scegli', 'Choose');
String get kTutorialHint => tr('Scegli in quali menù vuoi rivedere la guida.', 'Choose the menus whose guide you want to see again.');
String get kTutorialSections => tr('Sezioni', 'Sections');
String get kTutorialReactivate => tr('Riattiva', 'Turn back on');
String get kTutorialPickASection => tr('Scegli almeno una sezione.', 'Choose at least one section.');

// Shown when any tour is closed with its close button, on the phone and on the computer.
String get kTutorialClosedEarly => tr('Puoi riattivare il tutorial dalle impostazioni.', 'You can turn the tutorial back on in the settings.');

String tutorialsReactivated(int sections) => sections == 1
    ? tr('Tutorial riattivato.', 'Tutorial turned back on.')
    : tr('Tutorial riattivati.', 'Tutorials turned back on.');

String get kAccountGroup => tr('Account', 'Account');

String get kComingSoon => tr('In arrivo', 'Coming soon');

// Same delay as the top bar's sections not built yet.
const Duration kComingSoonWait = Duration(milliseconds: 400);

class AppearanceOption
{
  final String label;

  // False for an option not built yet: shown, muted, and inert.
  final bool available;

  // A palette's colours, drawn as its swatch.
  final List<Color> colors;

  // A language's two letters, drawn beside its name.
  final String? code;

  // A palette's theme; the one in force is ticked.
  final ColourTheme? colourTheme;

  // A language's own; the one in force is ticked.
  final AppLanguage? language;

  const AppearanceOption(
    this.label, {
    this.available = true,
    this.colors = const [],
    this.code,
    this.colourTheme,
    this.language,
  });
}

class AppearanceSetting
{
  final String title;
  final IconData icon;

  // The first is the one in force, but for the theme (light, dark), the palettes and the languages, which name theirs.
  final List<AppearanceOption> options;

  const AppearanceSetting(this.title, this.icon, this.options);
}

AppearanceSetting get kThemeSetting => AppearanceSetting(tr('Tema', 'Theme'), Icons.brightness_6_rounded, [
  AppearanceOption(tr('Chiaro', 'Light')),
  AppearanceOption(tr('Scuro', 'Dark')),
  AppearanceOption(tr('Automatico', 'Automatic')),
]);

String colourThemeLabel(ColourTheme theme)
{
  return switch (theme)
  {
    ColourTheme.casaMichela => 'Casa Michela',
    ColourTheme.cobalto => tr('Cobalto', 'Cobalt'),
    ColourTheme.ardesia => tr('Ardesia', 'Slate'),
    ColourTheme.lavanda => tr('Lavanda', 'Lavender'),
    ColourTheme.confetto => tr('Confetto', 'Confetti'),
    ColourTheme.terracotta => 'Terracotta',
  };
}

// Each theme's own sea top, main colours, gold and violet, whatever the theme in force.
List<Color> _swatch(ColourTheme theme) => ThemeColours.painted(theme, () => [
  ThemeColours.seaTop,
  AppTheme.trialTealDeep,
  AppTheme.trialSeaGreen,
  AppTheme.trialGold,
  AppTheme.trialViolet,
]);

AppearanceSetting get kColorsSetting => AppearanceSetting(tr('Colori', 'Colours'), Icons.palette_rounded, [
  for (final ColourTheme theme in ColourTheme.values)
    AppearanceOption(colourThemeLabel(theme), colors: _swatch(theme), colourTheme: theme),
]);

AppearanceSetting get kLanguageSetting => AppearanceSetting(tr('Lingua', 'Language'), Icons.translate_rounded, const [
  // Each language in its own name, whatever the one in force.
  AppearanceOption('Italiano', code: 'IT', language: AppLanguage.italian),
  AppearanceOption('English', code: 'EN', language: AppLanguage.english),
]);

List<AppearanceSetting> get kAppearanceSettings => [kThemeSetting, kColorsSetting, kLanguageSetting];

String get kEffectsTitle => tr('Effetti visivi', 'Visual effects');
String get kEffectsOn => tr('Attivi', 'On');
String get kEffectsOff => tr('Disattivi', 'Off');

String get kEffectsHint => tr(
    "Scegli se attivare le animazioni durante la navigazione nell'app. "
    "Disattivarle può migliorare la fluidità dell'interfaccia, soprattutto sui computer meno potenti.",
    'Choose whether to turn on animations while you move around the app. '
    'Turning them off can make the interface smoother, especially on less powerful computers.',
);

String get kUsernameLabel => tr('Nome utente', 'Username');
String get kLastLoginLabel => tr('Ultimo accesso', 'Last sign-in');

String get kAccountLoadFailed => tr("Errore durante il caricamento dell'account. Riprova più tardi.", "Couldn't load the account. Please try again later.");

final DateFormat _timestampFormat = DateFormat('dd/MM/yyyy, HH:mm');

// Null only for an account that has never logged in.
String formatLastLogin(DateTime? lastLogin)
{
  return lastLogin == null ? '-' : _timestampFormat.format(lastLogin);
}

String get kSecurityHeading => tr('Sicurezza', 'Security');
const String kPasswordLabel = 'Password';

String get kChangePasswordLabel => tr('Modifica password', 'Change password');

String get kPasswordEyebrow => kAccountGroup;
String get kPasswordTitle => kChangePasswordLabel;

String get kCurrentPasswordLabel => tr('Password attuale', 'Current password');
String get kCurrentPasswordHint => tr('Inserisci password attuale', 'Enter current password');
String get kNewPasswordLabel => tr('Nuova password', 'New password');
String get kNewPasswordHint => tr('Inserisci nuova password', 'Enter new password');
String get kConfirmPasswordLabel => tr('Conferma password', 'Confirm password');
String get kConfirmPasswordHint => tr('Ripeti nuova password', 'Repeat new password');

String get kPasswordsMatch => tr('Le password coincidono', 'Passwords match');
String get kPasswordsDiffer => tr('Le password non coincidono', "Passwords don't match");

String get kSavePasswordLabel => tr('Salva', 'Save');
String get kPasswordChanged => tr('Password cambiata con successo!', 'Password changed successfully!');

// [current] is null on a reset, whose link stands in for the current password.
String? passwordChangeProblem({
  String? current,
  required String next,
  required String confirmation,
})
{
  if (current == '' || next.isEmpty || confirmation.isEmpty)
  {
    return tr('Compila tutti i campi', 'Fill in all the fields');
  }

  if (current == next)
  {
    return tr('La nuova password non può coincidere con quella attuale.', 'The new password cannot be the same as the current one.');
  }

  if (next != confirmation)
  {
    return kPasswordsDiffer;
  }

  if (!PasswordPolicyStatus.of(next).isSatisfied)
  {
    return tr('La password non rispetta i criteri di sicurezza', 'The password does not meet the security criteria');
  }

  return null;
}

String get kSessionsLoadFailed => tr('Errore durante il caricamento delle sessioni. Riprova più tardi.', "Couldn't load the sessions. Please try again later.");

String get kUnknownDeviceLabel => tr('Dispositivo sconosciuto', 'Unknown device');
String get kCurrentSessionLabel => tr('Questa sessione', 'This session');

String get kSessionLoginLabel => tr('Accesso', 'Sign-in');
String get kSessionLastUsedLabel => tr('Ultima attività', 'Last activity');

String get kRevokeSessionLabel => tr('Disattiva', 'Deactivate');
String get kRevokeOthersLabel => tr('Disattiva le altre sessioni', 'Deactivate the other sessions');

String get kOtherSessionsHeading => tr('Altre sessioni', 'Other sessions');

String get kSessionEyebrow => tr('Sessione', 'Session');
String get kSessionsEyebrow => tr('Sessioni', 'Sessions');

String get kSessionRevoked => tr('Sessione disattivata', 'Session deactivated');
String get kOtherSessionsRevoked => tr('Le altre sessioni sono state disattivate', 'The other sessions have been deactivated');

String get kRevokeOthersWarning => tr(
    'Tutte le sessioni tranne questa verranno interrotte: '
    "dovrai effettuare nuovamente l'accesso sugli altri dispositivi.",
    'All sessions except this one will be ended: '
    'you will need to sign in again on the other devices.',
);

String sessionDeviceName(SessionItem session) => session.deviceName ?? kUnknownDeviceLabel;

String formatSessionTime(DateTime time) => _timestampFormat.format(time);

IconData sessionDeviceIcon(SessionDeviceType type)
{
  return switch (type)
  {
    SessionDeviceType.desktop => Icons.computer_rounded,
    SessionDeviceType.phone => Icons.smartphone_rounded,
    SessionDeviceType.tablet => Icons.tablet_mac_rounded,
    SessionDeviceType.unknown => Icons.devices_other_rounded,
  };
}

TextSpan revokeSessionWarning(SessionItem session, {required TextStyle deviceStyle})
{
  return TextSpan(
    children: [
      TextSpan(text: tr('La sessione su ', 'The session on ')),
      TextSpan(text: sessionDeviceName(session), style: deviceStyle),
      TextSpan(
        text: tr(
          " verrà interrotta: dovrai effettuare nuovamente l'accesso su quel dispositivo.",
          ' will be ended: you will need to sign in again on that device.',
        ),
      ),
    ],
  );
}

String get kStatuteTitle => tr("Statuto dell'Associazione", 'Statute of the Association');
String get kRegulationTitle => tr("Regolamento dell'Associazione", 'Regulations of the Association');
String get kTermsTitle => tr('Termini e condizioni', 'Terms and conditions');
String get kPrivacyTitle => tr('Privacy policy', 'Privacy policy');
String get kCookieTitle => tr('Cookie policy', 'Cookie policy');

String get kDocumentOpenFailed => tr('Non è stato possibile aprire il documento.', "Couldn't open the document.");

const String kAppVersion = '0.8.3 - Alpha';

String get kDevelopmentWarning => tr(
    'ATTENZIONE: Applicazione attualmente in sviluppo. '
    'Potrebbero verificarsi comportamenti inaspettati.',
    'WARNING: the app is currently in development. '
    'Unexpected behaviour may occur.',
);

String appCredits(int year) => '${appCopyright(year)}\n$kAppVersionLabel';

String appCopyright(int year) => '© $year Nicolò Calore';

String get kAppVersionLabel => tr('Versione $kAppVersion', 'Version $kAppVersion');

const String kAssociationName = 'Associazione Casa Michela';

String get kDocumentsHeading => tr('Documenti', 'Documents');

String get kReportProblemLabel => tr('Segnala un problema', 'Report a problem');

String get kReportEyebrow => tr('Segnalazione', 'Report');
String get kReportTitle => kReportProblemLabel;
String get kReportDescriptionLabel => tr('Descrizione', 'Description');
String get kReportDescriptionHint => tr('Descrivi il problema riscontrato...', 'Describe the problem you ran into...');
String get kReportEmpty => tr('La descrizione non può essere vuota.', 'The description cannot be empty.');
String get kReportSendLabel => tr('Invia segnalazione', 'Send report');
String get kReportSent => tr('Segnalazione inviata con successo. Grazie!', 'Report sent successfully. Thank you!');
