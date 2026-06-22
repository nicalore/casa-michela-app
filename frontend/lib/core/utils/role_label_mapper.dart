class RoleLabelMapper
{
  static String toLabel(String role)
  {
    switch (role)
    {
      case 'ADMIN':
      case 'Amministratore':
        return 'Amministratore';

      case 'TEACHER':
      case 'Docente':
        return 'Docente';

      case 'PSYCHOLOGIST':
      case 'Psicologo':
        return 'Psicologo';

      case 'STUDENT':
      case 'Studente':
        return 'Studente';

      case 'PARENT':
      case 'Genitore':
        return 'Genitore';

      case 'COURSE_PARTICIPANT':
      case 'Corsista':
        return 'Corsista';

      case 'MEMBER':
      case 'Associato':
      case 'Solo associato':
        return 'Solo associato';

      default:
        return role;
    }
  }

  static List<String> processRoles(List<String> rawRoles)
  {
    List<String> roles = rawRoles.map((r) => toLabel(r)).toList();
    
    final subclasses = ['Amministratore', 'Docente', 'Psicologo', 'Studente', 'Corsista'];
    
    if (roles.contains('Solo associato') && roles.any((r) => subclasses.contains(r)))
    {
      roles.remove('Solo associato');
    }
    
    return roles;
  }
}