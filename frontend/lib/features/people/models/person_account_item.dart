import '../../../core/utils/json_parsing.dart';
import '../../settings/models/session_item.dart';

class PersonAccountItem
{
  final String username;

  // ACTIVE, DISABLED (suspended by an administrator) or REVOKED (with the membership, for good).
  final String status;

  // MEMBERSHIP or CHILDREN while no enrollment stands behind the account; re-enrolling lifts it.
  final String? lapse;

  // A pupil the parents answer for; only then can autonomous bookings be set.
  final bool answeredFor;
  final bool autonomousBookings;

  // All in the local clock.
  final DateTime? lastLogin;

  final bool passwordChangeRequired;

  // Null unless the lock still holds.
  final DateTime? lockedUntil;

  final int failedLoginAttempts;
  final DateTime? lastFailedLoginAttempt;

  final List<SessionItem> sessions;

  const PersonAccountItem({
    required this.username,
    required this.status,
    required this.lapse,
    required this.answeredFor,
    required this.autonomousBookings,
    required this.lastLogin,
    required this.passwordChangeRequired,
    required this.lockedUntil,
    required this.failedLoginAttempts,
    required this.lastFailedLoginAttempt,
    required this.sessions,
  });

  bool get isLocked => lockedUntil != null;

  bool get isSuspended => status != 'ACTIVE' || lapse != null;

  bool get isDisabled => status == 'DISABLED';

  bool get isRevoked => status == 'REVOKED';

  factory PersonAccountItem.fromJson(Map<String, dynamic> json)
  {
    return PersonAccountItem(
      username: json['username'],
      status: json['status'] ?? 'ACTIVE',
      lapse: json['lapse'],
      answeredFor: json['answered_for'] == true,
      autonomousBookings: json['autonomous_bookings'] == true,
      lastLogin: parseInstant(json['last_login'])?.toLocal(),
      passwordChangeRequired: json['password_change_required'] == true,
      lockedUntil: parseInstant(json['locked_until'])?.toLocal(),
      failedLoginAttempts: json['failed_login_attempts'] ?? 0,
      lastFailedLoginAttempt: parseInstant(json['last_failed_login_attempt'])?.toLocal(),
      sessions: parseList(json['sessions'], SessionItem.fromJson),
    );
  }
}
