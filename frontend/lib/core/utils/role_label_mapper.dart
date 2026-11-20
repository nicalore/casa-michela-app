import '../language/app_language.dart';

abstract final class RoleLabelMapper
{
  // The server's label for a plain member: people's roles arrive as Italian labels and are compared as such.
  static const String memberLabel = 'Associato';

  static const Map<String, String> _labelsByRoleCode = <String, String>{
    'ADMIN': 'Amministratore',
    'TEACHER': 'Docente',
    'PSYCHOLOGIST': 'Psicologo',
    'STUDENT': 'Studente',
    'PARENT': 'Genitore',
    'COURSE_PARTICIPANT': 'Corsista',
    'MEMBER': memberLabel,
  };

  static const Map<String, String> _feminineLabelsByRoleCode = <String, String>{
    'ADMIN': 'Amministratrice',
    'PSYCHOLOGIST': 'Psicologa',
    'STUDENT': 'Studentessa',
    'MEMBER': 'Associata',
  };

  static const Map<String, String> _englishLabelsByRoleCode = <String, String>{
    'ADMIN': 'Administrator',
    'TEACHER': 'Teacher',
    'PSYCHOLOGIST': 'Psychologist',
    'STUDENT': 'Student',
    'PARENT': 'Parent',
    'COURSE_PARTICIPANT': 'Course participant',
    'MEMBER': 'Member',
  };

  // Roles that imply membership. A parent is excluded: not necessarily a member.
  static const Set<String> _memberSubclassCodes = <String>{
    'ADMIN',
    'TEACHER',
    'PSYCHOLOGIST',
    'STUDENT',
    'COURSE_PARTICIPANT',
  };

  // A role code, or the server's Italian label in either gender, to its code; null for anything else.
  static String? _codeOf(String role)
  {
    if (_labelsByRoleCode.containsKey(role))
    {
      return role;
    }

    final String upper = role.toUpperCase();

    for (final Map<String, String> labels in [_labelsByRoleCode, _feminineLabelsByRoleCode])
    {
      for (final MapEntry<String, String> entry in labels.entries)
      {
        if (entry.value.toUpperCase() == upper)
        {
          return entry.key;
        }
      }
    }

    return null;
  }

  // Unknown values pass through unchanged, keeping the conversion idempotent.
  static String toLabel(String role, {bool feminine = false})
  {
    final String? code = _codeOf(role);

    if (code == null)
    {
      return role;
    }

    if (isEnglish)
    {
      return _englishLabelsByRoleCode[code]!;
    }

    return feminine ? _feminineLabelsByRoleCode[code] ?? _labelsByRoleCode[code]! : _labelsByRoleCode[code]!;
  }

  // A plain member only - not everyone who also happens to be a member.
  static bool hasOnlyMemberRole(List<String> labels)
  {
    final Iterable<String?> codes = labels.map(_codeOf);

    return codes.contains('MEMBER') && !codes.any(_memberSubclassCodes.contains);
  }

  static List<String> processRoles(List<String> rawRoles, {bool feminine = false})
  {
    final List<String> roles = [...rawRoles];
    final Iterable<String?> codes = roles.map(_codeOf);

    if (codes.contains('MEMBER') && codes.any(_memberSubclassCodes.contains))
    {
      roles.removeWhere((role) => _codeOf(role) == 'MEMBER');
    }

    return roles.map((role) => toLabel(role, feminine: feminine)).toList();
  }
}
