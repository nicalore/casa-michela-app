from typing import Final

from app.core.audit.rules import ActorSource, AuditRule

RouteKey = tuple[str, str]

MUTATING_METHODS: Final[frozenset[str]] = frozenset(
    {"POST", "PUT", "PATCH", "DELETE"}
)


def _crud(
    prefix: str,
    entity: str,
    param: str,
    key: str = "id",
    body_fields: tuple[str, ...] = (),
) -> dict[RouteKey, AuditRule]:
    return {
        ("POST", f"{prefix}/"): AuditRule(
            f"{entity} creation",
            response_field=key,
            body_fields=body_fields,
        ),
        ("PUT", f"{prefix}/{{{param}}}"): AuditRule(
            f"{entity} modification",
            path_params=(param,),
        ),
        ("DELETE", f"{prefix}/{{{param}}}"): AuditRule(
            f"{entity} elimination",
            path_params=(param,),
        ),
    }


AUDIT_RULES: Final[dict[RouteKey, AuditRule]] = {
    # Entities keyed by a surrogate id.
    **_crud(
        "/association-subjects",
        "Association subject",
        "subject_id",
        body_fields=("name",),
    ),
    **_crud(
        "/ministry-subjects",
        "Ministry subject",
        "subject_id",
        body_fields=("name",),
    ),
    **_crud("/schools", "School", "school_id", body_fields=("name",)),
    **_crud("/study-programs", "Study program", "program_id", body_fields=("name",)),
    **_crud("/rooms", "Room", "room_id", body_fields=("name",)),
    **_crud("/lessons", "Lesson", "lesson_id"),
    **_crud("/bookings", "Booking", "booking_id"),
    **_crud(
        "/weekly-templates",
        "Weekly template",
        "template_id",
        body_fields=("weekday",),
    ),
    **_crud(
        "/availabilities",
        "Availability",
        "availability_id",
        body_fields=("date", "teacher_tax_code"),
    ),
    **_crud(
        "/presences",
        "Presence",
        "presence_id",
        body_fields=("date", "student_tax_code"),
    ),
    **_crud(
        "/room-supervisions",
        "Room supervision",
        "supervision_id",
        body_fields=("date", "teacher_tax_code"),
    ),
    **_crud(
        "/calendar-activities",
        "Calendar activity",
        "activity_id",
        body_fields=("date", "band"),
    ),
    # Entities keyed by name: their responses carry no id.
    **_crud("/services", "Service", "name", key="name", body_fields=("name",)),
    **_crud("/courses", "Course", "name", key="name", body_fields=("name",)),
    # Opening days: two routes act on a whole day rather than on one row.
    ("POST", "/opening-days/"): AuditRule(
        "Opening day creation",
        response_field="id",
        body_fields=("date",),
    ),
    ("PUT", "/opening-days/{opening_day_id}"): AuditRule(
        "Opening day modification",
        path_params=("opening_day_id",),
    ),
    ("DELETE", "/opening-days/{opening_day_id}"): AuditRule(
        "Opening day elimination",
        path_params=("opening_day_id",),
    ),
    ("PUT", "/opening-days/day"): AuditRule(
        "Opening day replacement",
        body_fields=("date",),
    ),
    ("POST", "/opening-days/restore-standard"): AuditRule(
        "Standard hours restoration",
        body_fields=("date_from", "date_to"),
    ),
    # Composite natural keys: the target is spelled out field by field.
    ("POST", "/lesson-requests/"): AuditRule(
        "Lesson request creation",
        body_fields=("date", "student_tax_code"),
    ),
    ("POST", "/teacher-room-assignments/"): AuditRule(
        "Teacher room assignment creation",
        body_fields=("date", "teacher_tax_code"),
    ),
    ("PUT", "/teacher-room-assignments/{day}/{teacher_tax_code}"): AuditRule(
        "Teacher room assignment modification",
        path_params=("day", "teacher_tax_code"),
    ),
    ("DELETE", "/teacher-room-assignments/{day}/{teacher_tax_code}"): AuditRule(
        "Teacher room assignment elimination",
        path_params=("day", "teacher_tax_code"),
    ),
    ("POST", "/calendar-publications/"): AuditRule(
        "Band publication",
        body_fields=("date", "band"),
    ),
    ("DELETE", "/calendar-publications/{publication_date}/{band}"): AuditRule(
        "Band unpublication",
        path_params=("publication_date", "band"),
    ),
    ("POST", "/calendar-publications/{publication_date}/{band}/draft"): AuditRule(
        "Band draft reopening",
        path_params=("publication_date", "band"),
    ),
    ("DELETE", "/calendar-publications/{publication_date}/{band}/draft"): AuditRule(
        "Band draft closure",
        path_params=("publication_date", "band"),
    ),
    ("POST", "/calendar-publications/{publication_date}/{band}/discard"): AuditRule(
        "Band draft discard",
        path_params=("publication_date", "band"),
    ),
    ("POST", "/calendar-teacher-exclusions/"): AuditRule(
        "Teacher exclusion creation",
        body_fields=("date", "band", "teacher_tax_code"),
    ),
    (
        "DELETE",
        "/calendar-teacher-exclusions/{exclusion_date}/{band}/{teacher_tax_code}",
    ): AuditRule(
        "Teacher readmission",
        path_params=("exclusion_date", "band", "teacher_tax_code"),
    ),
    # People: one label per operation, where a single "Person creation" and a
    # single "Person modification" used to cover five and six routes.
    ("POST", "/people/wizard/"): AuditRule(
        "Person creation",
        response_field="tax_code",
        body_fields=("general_data.tax_code",),
    ),
    ("POST", "/people/wizard/enrollment-form"): AuditRule(
        "Enrollment form generation",
        body_fields=("person.general_data.tax_code",),
    ),
    ("POST", "/people/wizard/early-exit-form"): AuditRule(
        "Early exit form generation",
        body_fields=("person.general_data.tax_code",),
    ),
    ("GET", "/people/{tax_code}/enrollment-form"): AuditRule(
        "Enrollment form download",
        path_params=("tax_code",),
    ),
    ("GET", "/people/{tax_code}/early-exit-form"): AuditRule(
        "Early exit form download",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}"): AuditRule(
        "Person modification",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}/school-enrollments"): AuditRule(
        "School enrollment modification",
        path_params=("tax_code",),
    ),
    ("POST", "/people/{tax_code}/parents"): AuditRule(
        "Parental responsibility creation",
        path_params=("tax_code",),
        body_fields=("parent_tax_code",),
    ),
    ("PUT", "/people/{tax_code}/parents/{old_parent_tax_code}"): AuditRule(
        "Parental responsibility modification",
        path_params=("tax_code", "old_parent_tax_code"),
    ),
    ("DELETE", "/people/{tax_code}/parents/{parent_tax_code}"): AuditRule(
        "Parental responsibility elimination",
        path_params=("tax_code", "parent_tax_code"),
    ),
    ("POST", "/people/{tax_code}/report-error"): AuditRule(
        "Person data error report",
        path_params=("tax_code",),
    ),
    ("POST", "/people/{tax_code}/image"): AuditRule(
        "Profile image upload",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}/memberships"): AuditRule(
        "Membership modification",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}/revoke-membership"): AuditRule(
        "Enrollment revocation",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}/teacher-competences"): AuditRule(
        "Teacher competences modification",
        path_params=("tax_code",),
    ),
    ("PUT", "/people/{tax_code}/teacher-education"): AuditRule(
        "Teacher education modification",
        path_params=("tax_code",),
    ),
    # Auth: the actor is whoever the request claims to be, since none of these
    # necessarily carry a bearer token.
    ("POST", "/auth/login"): AuditRule(
        "Authentication",
        actor_fallback=ActorSource.BODY_USERNAME,
    ),
    ("POST", "/auth/refresh"): AuditRule(
        "Token refresh",
        actor_fallback=ActorSource.BODY_REFRESH_TOKEN,
    ),
    ("POST", "/auth/logout"): AuditRule(
        "Logout",
        actor_fallback=ActorSource.BODY_REFRESH_TOKEN,
    ),
    ("PUT", "/auth/active-role"): AuditRule(
        "Active role change",
        body_fields=("role",),
    ),
    ("POST", "/auth/complete-onboarding"): AuditRule("Onboarding completion"),
    ("POST", "/auth/profile-image"): AuditRule("Profile image upload"),
    ("DELETE", "/auth/profile-image"): AuditRule("Profile image removal"),
    ("POST", "/auth/change-password"): AuditRule(
        "Password change",
        actor_fallback=ActorSource.BODY_REFRESH_TOKEN,
    ),
    ("POST", "/auth/request-password-reset"): AuditRule(
        "Password reset request",
        actor_fallback=ActorSource.BODY_USERNAME,
    ),
    ("POST", "/auth/reset-password"): AuditRule(
        "Password reset",
        actor_fallback=ActorSource.BODY_RESET_TOKEN,
    ),
}

# The lock is editor bookkeeping on a timer, not an act on the data: auditing
# it would bury every real entry.
IGNORED_ROUTES: Final[frozenset[RouteKey]] = frozenset(
    {
        ("POST", "/calendar-locks/{lock_date}/{band}/heartbeat"),
        ("DELETE", "/calendar-locks/{lock_date}/{band}"),
    }
)

LOCKOUT_ROUTE: Final[RouteKey] = ("POST", "/auth/login")
LOCKOUT_OPERATION: Final[str] = "Account lockout"
