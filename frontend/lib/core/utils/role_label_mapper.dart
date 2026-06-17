class RoleLabelMapper
{
  static String toLabel(String role)
  {
    switch (role)
    {
      case 'ADMIN':
        return 'Amministratore';

      case 'TEACHER':
        return 'Docente';

      case 'PSYCHOLOGIST':
        return 'Psicologo';

      case 'STUDENT':
        return 'Studente';

      case 'PARENT':
        return 'Genitore';

      case 'COURSE_PARTICIPANT':
        return 'Corsista';

      default:
        return role;
    }
  }
}