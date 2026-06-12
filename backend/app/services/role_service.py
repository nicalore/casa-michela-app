from app.models.person import Person


class RoleService:
    @staticmethod
    def get_available_roles(
        person: Person,
    ) -> list[str]:
        roles: list[str] = []

        if person.parent_profile is not None:
            roles.append("PARENT")

        member = person.member_profile

        if member is None:
            return roles

        if member.student_profile is not None:
            roles.append("STUDENT")

        if member.course_participant_profile is not None:
            roles.append("COURSE_PARTICIPANT")

        staff = member.staff_profile

        if staff is None:
            return roles

        if staff.administrator_profile is not None:
            roles.append("ADMIN")

        if staff.teacher_profile is not None:
            roles.append("TEACHER")

        if staff.psychologist_profile is not None:
            roles.append("PSYCHOLOGIST")

        return roles
