abstract final class RoleLabelMapper
{
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

  // Roles that imply membership. "Genitore" is excluded: a parent is not
  // necessarily a member.
  static const Set<String> _memberSubclassLabels = <String>{
    'Amministratore',
    'Docente',
    'Psicologo',
    'Studente',
    'Corsista',
  };

  // Unknown values pass through unchanged, keeping the conversion idempotent.
  static String toLabel(String role) => _labelsByRoleCode[role] ?? role;

  // A plain member only — not everyone who also happens to be a member.
  static bool hasOnlyMemberRole(List<String> labels)
  {
    return labels.contains(memberLabel) && !labels.any(_memberSubclassLabels.contains);
  }

  static List<String> processRoles(List<String> rawRoles)
  {
    final roles = rawRoles.map(toLabel).toList();

    if (roles.contains(memberLabel) &&
        roles.any(_memberSubclassLabels.contains))
    {
      roles.remove(memberLabel);
    }

    return roles;
  }
}