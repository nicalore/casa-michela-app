import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/password_policy_checklist.dart';
import '../models/session_item.dart';

const String kSettingsTitle = 'Impostazioni';

const String kAppearanceSection = 'Aspetto';
const String kAccessSection = 'Accesso';
const String kDevicesSection = 'Dispositivi';
const String kInfoSection = 'Informazioni';

const String kAccountGroup = 'Account';

const String kComingSoon = 'In arrivo';

class AppearanceOption
{
  final String label;

  // False for an option not built yet: shown, muted, and inert.
  final bool available;

  const AppearanceOption(this.label, {this.available = true});
}

class AppearanceSetting
{
  final String title;
  final IconData icon;

  // The first is the one in force.
  final List<AppearanceOption> options;

  const AppearanceSetting(this.title, this.icon, this.options);
}

const AppearanceSetting kThemeSetting = AppearanceSetting('Tema', Icons.brightness_6_rounded, [
  AppearanceOption('Chiaro'),
  AppearanceOption('Scuro', available: false),
]);

const AppearanceSetting kColorsSetting = AppearanceSetting('Colori', Icons.palette_rounded, [
  AppearanceOption('Casa Michela'),
]);

const AppearanceSetting kLanguageSetting = AppearanceSetting('Lingua', Icons.translate_rounded, [
  AppearanceOption('Italiano'),
  AppearanceOption('Inglese', available: false),
]);

const List<AppearanceSetting> kAppearanceSettings = [kThemeSetting, kColorsSetting, kLanguageSetting];

const String kUsernameLabel = 'Nome utente';
const String kLastLoginLabel = 'Ultimo accesso';

const String kAccountLoadFailed = "Errore durante il caricamento dell'account. Riprova più tardi.";

final DateFormat _timestampFormat = DateFormat('dd/MM/yyyy, HH:mm');

// Null only for an account that has never logged in.
String formatLastLogin(DateTime? lastLogin)
{
  return lastLogin == null ? '-' : _timestampFormat.format(lastLogin);
}

const String kChangePasswordLabel = 'Modifica password';

const String kPasswordEyebrow = kAccountGroup;
const String kPasswordTitle = kChangePasswordLabel;

const String kCurrentPasswordLabel = 'Password attuale';
const String kCurrentPasswordHint = 'Inserisci password attuale';
const String kNewPasswordLabel = 'Nuova password';
const String kNewPasswordHint = 'Inserisci nuova password';
const String kConfirmPasswordLabel = 'Conferma password';
const String kConfirmPasswordHint = 'Ripeti nuova password';

const String kPasswordsMatch = 'Le password coincidono';
const String kPasswordsDiffer = 'Le password non coincidono';

const String kSavePasswordLabel = 'Salva';
const String kPasswordChanged = 'Password cambiata con successo!';

// [current] is null on a reset, whose link stands in for the current password.
String? passwordChangeProblem({
  String? current,
  required String next,
  required String confirmation,
})
{
  if (current == '' || next.isEmpty || confirmation.isEmpty)
  {
    return 'Compila tutti i campi';
  }

  if (current == next)
  {
    return 'La nuova password non può coincidere con quella attuale.';
  }

  if (next != confirmation)
  {
    return kPasswordsDiffer;
  }

  if (!PasswordPolicyStatus.of(next).isSatisfied)
  {
    return 'La password non rispetta i criteri di sicurezza';
  }

  return null;
}

const String kSessionsLoadFailed = 'Errore durante il caricamento delle sessioni. Riprova più tardi.';

const String kUnknownDeviceLabel = 'Dispositivo sconosciuto';
const String kCurrentSessionLabel = 'Questa sessione';

const String kSessionLoginLabel = 'Accesso';
const String kSessionLastUsedLabel = 'Ultima attività';

const String kRevokeSessionLabel = 'Disattiva';
const String kRevokeOthersLabel = 'Disattiva le altre sessioni';

const String kSessionEyebrow = 'Sessione';
const String kSessionsEyebrow = 'Sessioni';

const String kSessionRevoked = 'Sessione disattivata';
const String kOtherSessionsRevoked = 'Le altre sessioni sono state disattivate';

const String kRevokeOthersWarning =
    'Tutte le sessioni tranne questa verranno interrotte: '
    "dovrai effettuare nuovamente l'accesso sugli altri dispositivi.";

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
      const TextSpan(text: 'La sessione su '),
      TextSpan(text: sessionDeviceName(session), style: deviceStyle),
      const TextSpan(
        text: " verrà interrotta: dovrai effettuare nuovamente l'accesso su quel dispositivo.",
      ),
    ],
  );
}

const String kStatuteTitle = "Statuto dell'Associazione";
const String kRegulationTitle = "Regolamento dell'Associazione";
const String kTermsTitle = 'Termini e condizioni';
const String kPrivacyTitle = 'Privacy policy';

const String kRegulationOpenFailed = 'Non è stato possibile aprire il regolamento.';

const String kAppVersion = '0.4.0 - Alpha';

const String kDevelopmentWarning =
    'ATTENZIONE: Applicazione attualmente in sviluppo. '
    'Potrebbero verificarsi comportamenti inaspettati.';

String appCredits(int year) => '© $year Nicolò Calore\nVersione $kAppVersion';

const String kReportProblemLabel = 'Segnala un problema';

const String kReportEyebrow = 'Segnalazione';
const String kReportTitle = kReportProblemLabel;
const String kReportDescriptionLabel = 'Descrizione';
const String kReportDescriptionHint = 'Descrivi il problema riscontrato...';
const String kReportEmpty = 'La descrizione non può essere vuota.';
const String kReportSendLabel = 'Invia segnalazione';
const String kReportSent = 'Segnalazione inviata con successo. Grazie!';
