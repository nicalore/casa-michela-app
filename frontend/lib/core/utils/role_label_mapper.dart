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

  static const Map<String, String> _feminineLabels = <String, String>{
    'Amministratore': 'Amministratrice',
    'Psicologo': 'Psicologa',
    'Studente': 'Studentessa',
  };

  // Unknown values pass through unchanged, keeping the conversion idempotent.
  static String toLabel(String role, {bool feminine = false})
  {
    final String label = _labelsByRoleCode[role] ?? role;

    return feminine ? _feminineLabels[label] ?? label : label;
  }

  // A plain member only - not everyone who also happens to be a member.
  static bool hasOnlyMemberRole(List<String> labels)
  {
    return labels.contains(memberLabel) && !labels.any(_memberSubclassLabels.contains);
  }

  static List<String> processRoles(List<String> rawRoles, {bool feminine = false})
  {
    final roles = rawRoles.map(toLabel).toList();

    if (roles.contains(memberLabel) &&
        roles.any(_memberSubclassLabels.contains))
    {
      roles.remove(memberLabel);
    }

    return feminine ? roles.map((label) => _feminineLabels[label] ?? label).toList() : roles;
  }
}