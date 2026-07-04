import csv
import random
from itertools import cycle
from pathlib import Path

from locust import HttpUser, between, task

_CREDENTIALS_PATH = Path(__file__).parent / "load_test_credentials.csv"

with open(_CREDENTIALS_PATH) as f:
    _credentials_pool = cycle(list(csv.DictReader(f)))

ROLES = ["administrator", "psychologist", "teacher", "student", "course_participant"]


class CasaMichelaUser(HttpUser):
    wait_time = between(2, 5)

    def on_start(self):
        creds = next(_credentials_pool)
        with self.client.post(
            "/auth/login",
            json={"username": creds["username"], "password": creds["password"]},
            catch_response=True,
            name="/auth/login",
        ) as response:
            if response.status_code != 200:
                response.failure(f"Login fallito: {response.status_code}")
                return

            data = response.json()
            if "access_token" not in data:
                response.failure("Login 200 ma senza access_token nel body")
                return

            self.access_token = data["access_token"]
            self.refresh_token = data["refresh_token"]
            self.client.headers.update({"Authorization": f"Bearer {self.access_token}"})
        self.known_tax_codes = []

    def on_stop(self):
        if hasattr(self, "refresh_token"):
            self.client.post(
                "/auth/logout",
                json={"refresh_token": self.refresh_token},
                name="/auth/logout",
            )

    # ==========================
    # NAVIGAZIONE ANAGRAFICHE
    # ==========================

    @task(5)
    def browse_people_list(self):
        with self.client.get("/people/", name="/people/ [list]", catch_response=True) as response:
            if response.status_code == 200:
                tax_codes = [p["fiscal_code"] for p in response.json()]
                if tax_codes:
                    self.known_tax_codes = random.sample(tax_codes, min(20, len(tax_codes)))
            else:
                response.failure(f"Status {response.status_code}")

    @task(3)
    def view_person_detail(self):
        if not self.known_tax_codes:
            return
        tax_code = random.choice(self.known_tax_codes)
        self.client.get(f"/people/{tax_code}", name="/people/{tax_code}")

    # ==========================
    # CONSULTAZIONE ANAGRAFICA ASSOCIAZIONE
    # ==========================

    @task(3)
    def browse_schools(self):
        self.client.get("/schools/", name="/schools/")

    @task(3)
    def browse_association_subjects(self):
        self.client.get("/association-subjects/", name="/association-subjects/")

    @task(2)
    def browse_ministry_subjects(self):
        self.client.get("/ministry-subjects/", name="/ministry-subjects/")

    @task(2)
    def browse_study_programs(self):
        self.client.get("/study-programs/", name="/study-programs/")

    # ==========================
    # STATISTICHE (dashboard)
    # ==========================

    @task(4)
    def view_general_dashboard(self):
        self.client.get("/statistics/general/current-totals", name="/statistics/general/current-totals")
        self.client.get(
            "/statistics/general/members-trend",
            params={"resolution": "year"},
            name="/statistics/general/members-trend",
        )

    @task(2)
    def view_role_statistics(self):
        role = random.choice(ROLES)
        self.client.get(
            "/statistics/role/current-totals",
            params={"role": role},
            name="/statistics/role/current-totals",
        )
        self.client.get(
            "/statistics/role/age-distribution",
            params={"role": role},
            name="/statistics/role/age-distribution",
        )
        self.client.get(
            "/statistics/role/city-distribution",
            params={"role": role},
            name="/statistics/role/city-distribution",
        )

    @task(1)
    def view_teacher_subject_statistics(self):
        # Query analitica più complessa: aggrega su TeachingCompetence
        # con più join e raggruppamenti in Python lato server.
        self.client.get(
            "/statistics/teachers/subjects-statistics",
            name="/statistics/teachers/subjects-statistics",
        )

    @task(1)
    def view_student_education_distribution(self):
        self.client.get(
            "/statistics/students/education-distribution",
            params={"distribution_type": random.choice(["school", "program", "level"])},
            name="/statistics/students/education-distribution",
        )

    @task(1)
    def view_course_distribution(self):
        self.client.get(
            "/statistics/course-participants/course-distribution",
            name="/statistics/course-participants/course-distribution",
        )

    # ==========================
    # SESSIONE / PROFILO
    # ==========================

    @task(2)
    def check_profile(self):
        self.client.get("/auth/me", name="/auth/me")

    @task(1)
    def refresh_access_token(self):
        with self.client.post(
            "/auth/refresh",
            json={"refresh_token": self.refresh_token},
            catch_response=True,
            name="/auth/refresh",
        ) as response:
            if response.status_code == 200:
                data = response.json()
                self.access_token = data["access_token"]
                self.refresh_token = data["refresh_token"]
                self.client.headers.update({"Authorization": f"Bearer {self.access_token}"})
            else:
                response.failure(f"Refresh fallito: {response.status_code}")